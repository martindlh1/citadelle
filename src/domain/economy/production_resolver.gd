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
## **Elle part des actions posées, plus des bâtiments.** C'est ce que D2 change, et c'est
## DESIGN.md 2 qui l'exigeait : « La production n'est plus une étape passive qui balaye
## les bâtiments : c'est le résultat des actions que le joueur a posées. Un bâtiment dont
## aucun slot n'a reçu d'action ne rend rien. » À E1 cette phrase n'était pas vraie —
## le résolveur balayait les ancres de l'affectation et servait le rendement du bâtiment
## qu'il y trouvait, sans qu'aucune carte n'ait eu à être jouée. Elle l'est maintenant
## par construction : rien ne produit qui ne figure au plan.
##
## Deux entrées de plus qu'à E1, et elles se justifient l'une l'autre. L'**ActionPlan**
## est le pilote. Le **TerrainQuery** vient avec la seconde lecture de DESIGN.md 3.5 :
## une action jouée à cru rend ce que le **tag de la cellule** dicte, donc l'Économie
## doit voir le relief. Elle ne voit toujours pas la grille — TerrainQuery est le
## contrat, pas la HeightGrid —, ce que 3.3 exigeait vraiment.
##
## Ce qu'elle ne fait toujours pas : aucune XP — combien vaut une soirée est un chiffre
## des Effectifs, et le journal de travail est là pour qu'ils le calculent —, aucune
## conséquence de famine, et aucun modificateur d'adjacence. Ce dernier est le sujet de
## C3 : il entrera comme un argument de plus, appliqué au rendement d'un poste juste
## avant le multiplicateur de l'ouvrier.
##
## Ce qu'elle ne fait **pas encore**, et c'est le périmètre assumé de D2 : *Construire*
## et *Terraformer*. Les deux se posent et s'affectent, mais leur effet mute le CityState
## et la HeightGrid, donc l'état de deux autres systèmes. Un résolveur d'Économie qui les
## muterait violerait la règle de dépendance ; le chemin propre est qu'il les rapporte et
## que l'orchestrateur les applique, ce qui veut dire RunOrchestrator, donc I1. En
## attendant, leurs ouvriers ne produisent rien et comptent comme oisifs.

## Capacité de la réserve pour cette ville : la base, plus ce que les entrepôts
## **achevés** ajoutent.
##
## Publique et appelable seule, parce que le HUD de E2 doit afficher « 47 / 200 » sans
## résoudre quoi que ce soit.
##
## completed() et non buildings() : un entrepôt en chantier a payé son coût et occupe
## ses cellules, mais il n'a pas de toit. Le laisser relever la réserve ne casserait
## rien — c'est bien pour ça qu'il faut le dire ici plutôt que de compter dessus.
static func capacity_for(city: CitySnapshot, balance: EconomyBalance) -> int:
	assert(city != null, "capacité demandée sans ville")
	assert(balance != null, "capacité demandée sans équilibrage")
	var capacity := balance.base_storage_cap
	for building in city.completed():
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
static func resolve(terrain: TerrainQuery, city: CitySnapshot, plan: ActionPlan,
		assign: Assignment, labor: LaborForce, ledger: Ledger,
		balance: EconomyBalance, actions: ActionBalance) -> ProductionReport:
	assert(terrain != null, "résolution sans terrain")
	assert(city != null, "résolution sans ville")
	assert(plan != null, "résolution sans plan d'actions")
	assert(assign != null, "résolution sans affectation")
	assert(labor != null, "résolution sans main-d'œuvre")
	assert(ledger != null, "résolution sans réserve")
	assert(balance != null, "résolution sans équilibrage")
	assert(actions != null, "résolution sans équilibrage des actions")
	assert(balance.upkeep_per_worker > 0,
		"upkeep par ouvrier non renseigné : %d" % balance.upkeep_per_worker)

	ledger.set_capacity(capacity_for(city, balance))

	var work := _work_lines(terrain, city, plan, assign, labor, actions)
	var produced := _produce(terrain, city, plan, assign, labor, actions)
	var stored := ledger.deposit(produced)

	var upkeep := labor.size() * balance.upkeep_per_worker
	var consumed := ledger.take(balance.upkeep_resource, upkeep)
	var unfed := _unfed(upkeep - consumed, balance.upkeep_per_worker)

	return ProductionReport.create(produced, stored, work, _idle(labor, work),
		upkeep, consumed, unfed)

## Qui tient effectivement un poste, et sur quelle cellule.
##
## Les postes se remplissent dans l'ordre de l'affectation : sur une action
## sur-affectée, les premiers arrivés travaillent et les autres chôment. Cinq cas ne
## produisent aucune ligne et se retrouvent donc oisifs — une action retirée depuis
## qu'on y a mis quelqu'un, une ancre qui ne porte plus rien, un chantier inachevé, un
## bâtiment sans bloc de production, et un poste déjà pris. Un sixième s'y ajoute à D2 :
## une action que rien ne fait produire, ce que sont *Construire* et *Terraformer* tant
## que I1 ne les exécute pas.
##
## C'est _family_of() qui tranche tout cela, en un seul endroit, et rien ne consomme une
## ligne de travail sans savoir que son poste produit vraiment.
##
## Un ouvrier que l'affectation nomme mais que la main-d'œuvre ne connaît pas est
## ignoré sans un mot, et ne compte même pas comme oisif : une affectation peut avoir
## survécu à celui qui la portait, et un mort ne chôme pas.
static func _work_lines(terrain: TerrainQuery, city: CitySnapshot, plan: ActionPlan,
		assign: Assignment, labor: LaborForce,
		actions: ActionBalance) -> Array[WorkLine]:
	var lines: Array[WorkLine] = []
	for action in plan.actions():
		var family := _family_of(action, terrain, city, actions)
		if family.is_empty():
			continue
		for worker in _manned(action, assign, labor):
			lines.append(WorkLine.create(worker, action.target(), family))
	return lines

## Ce que ces postes rapportent, multiplicateur de l'ouvrier compris.
##
## Seconde passe sur le même plan plutôt qu'un calcul mené avec le journal de travail, et
## il faut dire pourquoi : une ligne de travail ne porte que sa **cellule**, et deux
## actions peuvent viser la même — *Récolter* et *Chasser* sur une même forêt. Repartir
## des lignes obligerait donc à retrouver de quelle action chacune vient. Les deux passes
## posent les mêmes questions aux mêmes fonctions pures, sur les mêmes entrées, donc
## elles ne peuvent pas répondre différemment.
##
## Le produit est tronqué vers le bas : un ouvrier ne rend jamais plus que ce que la
## data promet, et un multiplicateur sous 1.0 se paie vraiment. Un rendement tombé à
## zéro laisse quand même sa ligne de travail — l'ouvrier a occupé le poste et mérite
## son XP, il a juste mal produit.
static func _produce(terrain: TerrainQuery, city: CitySnapshot, plan: ActionPlan,
		assign: Assignment, labor: LaborForce,
		actions: ActionBalance) -> Dictionary[StringName, int]:
	var produced: Dictionary[StringName, int] = {}
	for action in plan.actions():
		var family := _family_of(action, terrain, city, actions)
		if family.is_empty():
			continue
		var per_worker := _yield_of(action, terrain, city, actions)
		for worker in _manned(action, assign, labor):
			var efficiency := labor.efficiency(worker, family)
			for resource in per_worker:
				var gained := floori(per_worker[resource] * efficiency)
				if gained > 0:
					var running: int = produced.get(resource, 0)
					produced[resource] = running + gained
	return produced

## Famille de compétence que cette action emploie, ou &"" si elle ne fait produire
## personne.
##
## Le seul juge de « cette action rapporte-t-elle quelque chose ». La question est posée
## ici et nulle part ailleurs, et sa réponse vaut pour les deux passes.
##
## Aucun nom de carte n'apparaît, et c'est le point. *Construire* est écarté parce qu'un
## chantier n'est pas achevé — le ciblage lui interdit toute autre cible —, et
## *Terraformer* parce que data/balance/ ne lui donne aucune table de sources. Les deux
## sont ignorés pour des raisons **structurelles**, de sorte qu'un cinquième verbe entre
## sans qu'on ait à venir l'exclure d'une liste.
static func _family_of(action: PlayedAction, terrain: TerrainQuery, city: CitySnapshot,
		actions: ActionBalance) -> StringName:
	if action.is_on_building():
		var building := city.at_anchor(action.target())
		if building == null:
			return &""
		if not building.is_complete():
			return &""
		if not building.data().produces():
			return &""
		return building.data().production.skill_family
	if _bare_resource(action, terrain, actions).is_empty():
		return &""
	return actions.bare_skill_family

## Ce qu'un poste de cette action rend en un soir, avant le multiplicateur de l'ouvrier.
##
## Lu sans garde : _family_of() a déjà établi que le bâtiment produit, ou que la cellule
## porte un tag que la carte sait exploiter.
static func _yield_of(action: PlayedAction, terrain: TerrainQuery, city: CitySnapshot,
		actions: ActionBalance) -> Dictionary[StringName, int]:
	if action.is_on_building():
		return city.at_anchor(action.target()).data().production.yield_per_slot
	var bare: Dictionary[StringName, int] = {}
	bare[_bare_resource(action, terrain, actions)] = actions.bare_yield
	return bare

## Ressource qu'une action à cru tire de sa cellule, ou &"" si aucun tag ne convient.
##
## La table consultée est celle-là même que le ciblage a lue pour accepter la pose, ce
## qui garantit qu'une cible acceptée rend vraiment quelque chose. Elle répond &"" pour
## une carte qui ne se joue pas à cru, ce qui est le chemin par lequel *Terraformer*
## sort de la production sans être nommé.
static func _bare_resource(action: PlayedAction, terrain: TerrainQuery,
		actions: ActionBalance) -> StringName:
	var sources := actions.sources_for(action.card())
	for tag in sources:
		if terrain.has_tag(action.target(), tag):
			return sources[tag]
	return &""

## Les ouvriers qui tiennent effectivement un poste de cette action, dans l'ordre
## d'affectation et jusqu'à sa capacité.
##
## La capacité est celle que l'action porte, figée à la pose par le ciblage. La relire
## depuis la ville rouvrirait la porte à ce que l'écran ait promis trois postes et que
## le soir n'en serve que deux.
static func _manned(action: PlayedAction, assign: Assignment,
		labor: LaborForce) -> Array[StringName]:
	var held: Array[StringName] = []
	for worker in assign.workers_on(action.id()):
		if held.size() >= action.capacity():
			break
		if not labor.has(worker):
			continue
		held.append(worker)
	return held

## Le roster moins ceux qui ont travaillé, dans l'ordre du roster.
##
## Se déduire du roster plutôt que se collecter au fil des refus couvre d'un coup toutes
## les façons de ne rien produire — non affecté, action retirée, ancre vide, bâtiment
## sans bloc de production, poste déjà pris, verbe que D2 n'exécute pas — sans qu'aucune
## ait à être énumérée ici.
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
