class_name InstantCombatResolver
extends RefCounted
## Ce qu'une vague ordonne : ce qu'elle casse, qui elle emporte, ce qu'elle vole.
##
## **C'est un bouchon, et il est écrit pour être jeté.** DESIGN.md 3.6 : « Une première
## implémentation InstantCombatResolver, purement arithmétique et sans vue, sert de bouchon
## pour boucler la boucle de jeu au plus tôt. Le jour où [le vrai combat] est prêt, on
## échange l'implémentation dans l'orchestrateur : une ligne. » Ce qui doit survivre à
## l'échange est le DamageReport, pas ce fichier.
##
## Il en découle une discipline précise : tout ce qui est ici est de l'arithmétique sur des
## chiffres de data/, et **rien n'y est un état**. Aucune règle du jeu ne s'appuie sur lui
## en dehors de ce que le rapport dit.
##
## **Il ordonne, il ne mute rien**, profil de SiteResolver et pour une raison trois fois
## plus forte : son effet touche la ville, le roster et la réserve. RunOrchestrator
## applique — c'est le seul à tenir les trois, donc le seul qui **puisse** les appliquer
## sans casser la règle de dépendance.
##
## Il ne voit d'ailleurs jamais le stock. Une vague dit **combien** elle emporte, jamais
## quoi : répartir demanderait de lire un interne de l'Économie. Voir DamageReport.plunder().

## Places de déploiement de cette ville : la base, plus ce que les bâtiments **achevés**
## ajoutent.
##
## Troisième plafond du jeu bâti sur ce modèle, et miroir exact de
## ProductionResolver.capacity_for() et de Roster.capacity_for() — jusque dans le filtre :
## une caserne en chantier n'ouvre aucune place, pour la raison qui vaut depuis C4.
##
## Publique et sans résolution, comme staffing_refusal() à I1 et family_of() à W2 : un
## écran qui veut annoncer « 3 / 5 engagés » avant la bataille pose exactement cette
## question, et une seconde liste de règles serait une liste de trop.
static func slots_for(city: CitySnapshot, balance: CombatBalance) -> int:
	assert(city != null, "places de déploiement demandées sans ville")
	assert(balance != null, "places de déploiement demandées sans équilibrage")
	var slots := balance.base_deployment_slots
	for building in city.completed():
		slots += building.data().deployment_slots
	return slots

## Qui monte sur la ligne : les plus aguerris, jusqu'à la borne.
##
## **C'est un bouchon dans le bouchon**, et le seul endroit de ce fichier qui décide de
## quelque chose que le joueur devrait décider. DESIGN.md 3.6 fait du déploiement un
## geste ; F1 ne l'écrit pas, exactement comme I1 pose le Cœur au centre plutôt que de
## demander à un écran qui n'existe pas. La règle survivra à cet écran comme bouton par
## défaut, de la même façon que l'auto-affectation de W2.
##
## À efficacité égale, c'est l'ordre de la force qui départage — donc celui du roster.
## Sans cette clause, deux runs partis du même seed enverraient deux personnes différentes
## mourir, et ni la ville ni la réserve ne le montreraient. C'est le piège que W2 a épinglé
## sur le classement des ouvriers, et il se repose ici mot pour mot.
##
## Le tri est fait sur une copie indexée plutôt que sur les identifiants seuls : trier des
## StringName compare leurs pointeurs internes, ce que les conventions interdisent.
static func deploy(force: CombatForce, slots: int) -> Array[StringName]:
	assert(force != null, "déploiement sans force de combat")
	assert(slots >= 0, "places de déploiement négatives : %d" % slots)
	var ranks: Array[int] = []
	var fighters := force.fighters()
	for rank in fighters.size():
		ranks.append(rank)
	ranks.sort_custom(func(first: int, second: int) -> bool:
		var strong := force.efficiency(fighters[first])
		var weak := force.efficiency(fighters[second])
		if strong != weak:
			return strong > weak
		return first < second)
	var line: Array[StringName] = []
	for rank in ranks:
		if line.size() >= slots:
			break
		line.append(fighters[rank])
	return line

## Ce que le village oppose à une vague : ses murs, et les hommes qu'il a pu déployer.
##
## Publique pour la même raison que slots_for() : c'est le chiffre qu'un écran affiche
## avant la bataille, et le lire ailleurs qu'ici le ferait diverger de ce qui se passera.
##
## Seuls les bâtiments **achevés** défendent — une palissade en chantier ne retient rien —,
## et seuls les **déployés** comptent : un homme resté au village n'est pas sur la ligne.
## C'est là que la borne de 3.6 mord vraiment, et c'est tout ce qui la rend intéressante.
static func defense_of(city: CitySnapshot, force: CombatForce,
		balance: CombatBalance) -> int:
	assert(city != null, "défense demandée sans ville")
	assert(force != null, "défense demandée sans force de combat")
	assert(balance != null, "défense demandée sans équilibrage")
	var walls := 0
	for building in city.completed():
		walls += building.data().defense
	var line := deploy(force, slots_for(city, balance))
	var men := 0.0
	for fighter in line:
		men += balance.defense_per_fighter * force.efficiency(fighter)
	return walls + int(men)

## Ce qui passe la ligne : la puissance de la vague moins ce qu'on lui oppose.
##
## Publique pour la même raison que slots_for() et defense_of(), et pour une de plus depuis
## F2b : ce chiffre a **quitté le DamageReport**, où il décrivait l'arithmétique de ce
## fichier et non un fait du combat. Le seul lecteur qui reste est le harnais qui calibre ce
## bouchon, et c'est exactement là qu'il doit être demandé — au bouchon lui-même, qui
## disparaîtra avec lui, plutôt que recalculé ailleurs à partir de deux chiffres publics.
static func breach_of(city: CitySnapshot, force: CombatForce, wave: WaveDef,
		balance: CombatBalance) -> int:
	assert(wave != null, "brèche demandée sans vague")
	return maxi(0, wave.power - defense_of(city, force, balance))

## Résout une vague et rend ce qu'elle ordonne.
##
## Toute l'arithmétique du bouchon tient dans les cinq lignes qui suivent, et c'est le
## signe qu'un bouchon est bien un bouchon : puissance moins défense donne une **brèche**,
## et la brèche casse, tue et vole.
##
## Les trois conséquences lisent la **même** brèche, sans se la disputer : les pertes ne
## réduisent pas les dégâts aux bâtiments, et les murs n'épargnent pas les hommes. C'est
## faux pour un vrai combat et parfaitement suffisant pour un bouchon — un partage serait
## un arbitrage d'équilibrage, donc I3, sur une arithmétique que F2 remplacera de toute
## façon.
##
## Les hommes tiennent la ligne **même quand la vague est contenue** : le journal de
## travail sort dans les deux cas, donc l'XP de combat se gagne en défendant et non en
## saignant. L'inverse rendrait une bonne défense punitive à la progression.
static func resolve(city: CitySnapshot, force: CombatForce, wave: WaveDef,
		balance: CombatBalance) -> DamageReport:
	assert(city != null, "résolution de vague sans ville")
	assert(force != null, "résolution de vague sans force de combat")
	assert(wave != null, "résolution de vague sans vague")
	assert(balance != null, "résolution de vague sans équilibrage")
	assert(not balance.combat_skill_family.is_empty(),
		"piste du combat non renseignée dans data/balance/")
	assert(balance.breach_per_casualty > 0,
		"coût d'un mort non renseigné dans data/balance/")

	var line := deploy(force, slots_for(city, balance))
	var work := _work_lines(line, balance)
	var defense := defense_of(city, force, balance)
	var breach := maxi(0, wave.power - defense)
	if breach <= 0:
		return DamageReport.held(work, false)

	var damaged: Dictionary[Vector2i, int] = {}
	var destroyed: Array[Vector2i] = []
	var interrupted: Array[Vector2i] = []
	var left := breach
	for building in _under_fire(city):
		if left <= 0:
			break
		var taken := mini(left, building.hit_points_left())
		if taken <= 0:
			continue
		damaged[building.anchor()] = taken
		left -= taken
		if taken < building.hit_points_left():
			continue
		destroyed.append(building.anchor())
		if not building.is_complete():
			interrupted.append(building.anchor())

	return DamageReport.create(damaged, destroyed, interrupted,
		_casualties(line, breach, balance), breach * balance.plunder_per_breach, work,
		false)

## Les bâtiments dans l'ordre où la vague les frappe.
##
## **Ce qui la retenait casse d'abord, puis ce qui cède le plus vite.** La seule règle de ce
## fichier qui se discute, et elle est écrite dans DESIGN.md 3.6 pour cette raison. Deux
## vertus : la palissade sert vraiment à quelque chose, et le Cœur se retrouve en dernier
## sans qu'une ligne n'écrive son nom, puisqu'il est le plus solide du tableau de 4.1.
##
## La défense d'un chantier compte pour **zéro** : une palissade qu'on n'a pas finie ne se
## dresse devant rien, donc rien ne justifie qu'elle prenne le premier coup. C'est la même
## lecture que defense_of(), et les faire diverger mettrait des bâtiments en première ligne
## pour une protection qu'ils n'apportent pas.
##
## L'ancre départage en dernier ressort, ce qui rend l'ordre **indépendant de la pose** :
## deux villes aux mêmes bâtiments posés dans un ordre différent perdent exactement la même
## chose. C'est ce que E1 exige déjà de l'écrêtage d'une récolte, et pour le même motif.
##
## Tout est frappé, chantiers compris — c'est la porte que C4 a laissée ouverte en faisant
## rendre à buildings() autre chose qu'à completed(), et F1 en est le consommateur annoncé.
static func _under_fire(city: CitySnapshot) -> Array[BuildingSnapshot]:
	var targets := city.buildings()
	targets.sort_custom(func(first: BuildingSnapshot, second: BuildingSnapshot) -> bool:
		var front := _standing_defense(first)
		var back := _standing_defense(second)
		if front != back:
			return front > back
		if first.hit_points_left() != second.hit_points_left():
			return first.hit_points_left() < second.hit_points_left()
		if first.anchor().y != second.anchor().y:
			return first.anchor().y < second.anchor().y
		return first.anchor().x < second.anchor().x)
	return targets

## Ce qu'un bâtiment oppose vraiment : sa défense s'il est debout, zéro s'il est en
## chantier.
static func _standing_defense(building: BuildingSnapshot) -> int:
	if not building.is_complete():
		return 0
	return building.data().defense

## Qui tombe, et dans quel ordre.
##
## **Les moins aguerris d'abord**, ce qui est exactement la fin de la liste déployée
## puisque deploy() range les meilleurs devant. Ce choix est thématique autant que
## mécanique : les bleus tombent, la piste Combat protège celui qui l'a montée, et
## l'investissement d'un roguelite n'est pas effacé par un tirage. Il rend aussi les pertes
## prévisibles, donc jouables — c'est l'argument qui a écarté la pondération du bouton de
## W2, et il vaut ici pour la même raison.
##
## Le nombre est borné par la ligne : une brèche énorme n'emporte pas plus de monde qu'il
## n'y en avait dessus. Ceux qui sont restés au village ne sont pas concernés — DESIGN.md
## 3.6 parle des « effectifs **engagés** ».
##
## L'ordre rendu est celui du déploiement et non celui de la chute, ce qui n'a aucune
## conséquence — un mort est un mort — mais garde deux runs du même seed identiques jusque
## dans les listes.
static func _casualties(line: Array[StringName], breach: int,
		balance: CombatBalance) -> Array[StringName]:
	var toll := mini(line.size(), breach / balance.breach_per_casualty)
	var fallen: Array[StringName] = []
	for rank in line.size():
		if rank < line.size() - toll:
			continue
		fallen.append(line[rank])
	return fallen

## Le journal de ceux qui ont tenu la ligne.
##
## Des WorkLine sans cellule : on ne défend pas le village *en* une case. C'est le troisième
## producteur de lignes du projet et le premier pour lequel la question ne se pose pas, ce
## qui a valu à WorkLine sa constante NO_CELL.
##
## La famille vient de data/balance/ et n'est écrite nulle part dans le code, comme celle
## d'un chantier depuis I1 : DESIGN.md 3.4 pose que la liste des familles n'est pas close.
## Le Combat y entre donc sans une ligne de GDScript de plus que la Construction n'en a
## coûté.
static func _work_lines(line: Array[StringName],
		balance: CombatBalance) -> Array[WorkLine]:
	var work: Array[WorkLine] = []
	for fighter in line:
		work.append(WorkLine.create(fighter, WorkLine.NO_CELL,
			balance.combat_skill_family))
	return work
