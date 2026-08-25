class_name ProductionResolver
extends RefCounted
## La résolution d'un soir : qui a travaillé, ce que ça rapporte, ce que ça coûte.
##
## Fonction pure au sens du domaine — tout lui est fourni, elle ne lit ni GameDatabase
## ni le moindre Node. Elle mute le Ledger, ce qui n'est pas une entorse : le ledger est
## l'état **interne** de l'Économie, exactement comme CityState l'est de Construction,
## et CityState.place() a déjà le même profil — valider, muter, rendre le résultat. La
## ligne de contrat de DESIGN.md 3.3 énumère les entrées inter-systèmes, et c'est
## précisément pour ça que le ledger n'y figure pas.
##
## Ce qu'elle ne fait pas : aucune XP — combien vaut une soirée est un chiffre des
## Effectifs, et le journal de travail est là pour qu'ils le calculent —, aucune
## conséquence de famine, et aucun modificateur d'adjacence. Ce dernier est le sujet de
## C3 : il entrera comme un argument de plus, appliqué au rendement d'un slot juste
## avant le multiplicateur de l'ouvrier.

## Capacité de la réserve pour cette ville : la base, plus ce que les entrepôts
## ajoutent.
##
## Publique et appelable seule, parce que le HUD de E2 doit afficher « 47 / 200 » sans
## résoudre quoi que ce soit.
static func capacity_for(city: CitySnapshot, balance: EconomyBalance) -> int:
	assert(city != null, "capacité demandée sans ville")
	assert(balance != null, "capacité demandée sans équilibrage")
	var capacity := balance.base_storage_cap
	for building in city.buildings():
		capacity += building.data().storage_bonus
	return capacity

## Résout un soir de production : dépose la récolte, prélève l'upkeep, rend le rapport.
##
## Ordre imposé par DESIGN.md 2 : production, puis plafond, puis upkeep. Il n'est pas
## indifférent — nourrir avant d'écrêter rendrait la réserve pleine inoffensive, alors
## que c'est justement là qu'elle doit faire mal.
##
## La capacité est recalculée à chaque soir, entrepôts du moment compris. Si elle a
## baissé — un entrepôt détruit —, l'écrêtage qui suit n'apparaît pas dans le rapport :
## ce n'est pas une perte de production, et c'est au DamageReport de F1 de la porter.
static func resolve(city: CitySnapshot, assign: Assignment, labor: LaborForce,
		ledger: Ledger, balance: EconomyBalance) -> ProductionReport:
	assert(city != null, "résolution sans ville")
	assert(assign != null, "résolution sans affectation")
	assert(labor != null, "résolution sans main-d'œuvre")
	assert(ledger != null, "résolution sans réserve")
	assert(balance != null, "résolution sans équilibrage")
	assert(balance.upkeep_per_worker > 0,
		"upkeep par ouvrier non renseigné : %d" % balance.upkeep_per_worker)

	ledger.set_capacity(capacity_for(city, balance))

	var work := _work_lines(city, assign, labor)
	var produced := _harvest(city, work, labor)
	var stored := ledger.deposit(produced)

	var upkeep := labor.size() * balance.upkeep_per_worker
	var consumed := ledger.take(balance.upkeep_resource, upkeep)
	var unfed := _unfed(upkeep - consumed, balance.upkeep_per_worker)

	return ProductionReport.create(produced, stored, work, _idle(labor, work),
		upkeep, consumed, unfed)

## Qui tient effectivement un poste, et où.
##
## Les slots se remplissent dans l'ordre de l'affectation : sur un bâtiment
## sur-affecté, les premiers arrivés travaillent et les autres chôment. Trois cas
## ne produisent aucune ligne et se retrouvent donc oisifs — une ancre qui ne porte
## plus rien, un bâtiment sans bloc de production, et un slot déjà pris.
##
## C'est ici, et nulle part ailleurs, que se teste l'existence du bloc : toute ligne
## de travail en sort, donc tout ce qui consomme une ligne sait que le bâtiment
## produit. Un entrepôt reste un bâtiment parfaitement valide où personne ne travaille.
##
## Un ouvrier que l'affectation nomme mais que la main-d'œuvre ne connaît pas est
## ignoré sans un mot, et ne compte même pas comme oisif : une affectation peut avoir
## survécu à celui qui la portait, et un mort ne chôme pas.
static func _work_lines(city: CitySnapshot, assign: Assignment,
		labor: LaborForce) -> Array[WorkLine]:
	var lines: Array[WorkLine] = []
	for anchor in assign.anchors():
		var building := city.at_anchor(anchor)
		if building == null:
			continue
		var data := building.data()
		if not data.produces():
			continue
		var production := data.production
		var filled := 0
		for worker in assign.workers_at(anchor):
			if filled >= production.slots:
				break
			if not labor.has(worker):
				continue
			lines.append(WorkLine.create(worker, anchor, production.skill_family))
			filled += 1
	return lines

## Ce que ces postes rapportent, multiplicateur de l'ouvrier compris.
##
## Le produit est tronqué vers le bas : un ouvrier ne rend jamais plus que ce que la
## data promet, et un multiplicateur sous 1.0 se paie vraiment. Un rendement tombé à
## zéro laisse quand même sa ligne de travail — l'ouvrier a occupé le poste et mérite
## son XP, il a juste mal produit.
##
## Le bloc de production est lu sans garde : une ligne de travail n'existe que pour un
## bâtiment qui produit, _work_lines() s'en est déjà assuré.
static func _harvest(city: CitySnapshot, work: Array[WorkLine],
		labor: LaborForce) -> Dictionary[StringName, int]:
	var produced: Dictionary[StringName, int] = {}
	for line in work:
		var production := city.at_anchor(line.anchor()).data().production
		var efficiency := labor.efficiency(line.worker(), line.family())
		for resource in production.yield_per_slot:
			var gained := floori(production.yield_per_slot[resource] * efficiency)
			if gained > 0:
				var running: int = produced.get(resource, 0)
				produced[resource] = running + gained
	return produced

## Le roster moins ceux qui ont travaillé, dans l'ordre du roster.
##
## Se déduire du roster plutôt que se collecter au fil des refus couvre d'un coup les
## quatre façons de ne rien produire — non affecté, ancre vide, bâtiment sans bloc de
## production, slot déjà pris — sans qu'aucune ait à être énumérée ici.
static func _idle(labor: LaborForce, work: Array[WorkLine]) -> Array[StringName]:
	var worked: Dictionary[StringName, bool] = {}
	for line in work:
		worked[line.worker()] = true
	var resting: Array[StringName] = []
	for worker in labor.workers():
		if not worked.has(worker):
			resting.append(worker)
	return resting

## Combien d'ouvriers la réserve n'a pas nourris, pour ce manque.
##
## Arrondi vers le haut : une ration entamée n'est pas une ration. Un ouvrier à moitié
## servi compte comme non nourri, ce qui ne sous-déclare jamais une famine.
static func _unfed(shortfall: int, per_worker: int) -> int:
	if shortfall <= 0:
		return 0
	return ceili(float(shortfall) / float(per_worker))
