class_name RunState
extends RefCounted
## Tout ce qu'un run possède : le relief, la ville, la réserve, la population, le tour où
## l'on en est, et comment il s'est terminé.
##
## C'est le seul objet du projet qui tienne les états internes de plusieurs systèmes à la
## fois, et DESIGN.md 3.7 l'autorise nommément : le Cycle de tour est « le seul système qui
## connaît tous les autres. C'est volontaire : il orchestre, les autres s'ignorent ». Rien
## ne remonte dans l'autre sens — ni le Ledger, ni la Population, ni le CityState ne savent
## qu'un run existe.
##
## **Il porte son équilibrage**, à l'inverse de tous les autres objets du domaine, qui le
## reçoivent en argument. La raison est le déterminisme : CLAUDE.md promet qu'« un seed plus
## une liste d'actions doit rejouer un run à l'identique », et cela n'est vrai que si le run
## rejoue sur **les chiffres avec lesquels il s'est ouvert**.
##
## Il ne contient **aucune règle**. Ouvrir, projeter, compter ce qui est ouvert : ce qui
## décide appartient à RunOrchestrator, ce qui calcule aux résolveurs. La frontière se lit
## sur deux voisines — open_sites() compte les chantiers, et c'est l'orchestrateur qui les
## compare à build_slots ; suggested_heart_anchor() propose une case, et c'est
## l'orchestrateur qui décide si on la prend.
##
## ---
##
## **Ce que la réécriture d'I3 lui retire, et ce n'est pas mince.** Le RunState d'avant R0
## portait un deck, un roster, un plateau d'actions, un brouillon d'affectation, une machine
## à phases, une vague en attente et une coupure de fin de journée : sept états dont six
## appartenaient à des systèmes supprimés, et le septième — l'attente de bataille — n'existait
## que parce qu'une bataille attendait une entrée du joueur. DESIGN.md 3.5 a défait ça en une
## phrase : « la fin de tour reste atomique ». Il ne reste ni attente, ni seconde porte.
##
## Ce qui survit intact : le seed et son RNG, l'équilibrage porté, le relief mutable, la
## ville, la réserve, et l'attente du Cœur — parce que DESIGN.md 2 en fait toujours une
## étape, « génération de carte → pose du Cœur → suite de tours ».

## Cellule rendue quand aucune ne convient.
const NO_CELL := Vector2i(-1, -1)

var _run_seed: int
var _rng: RandomNumberGenerator
var _balance: BalanceData
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState
var _ledger: Ledger
var _people: Population

## Identifiant -> données du bâtiment. Ce que le run peut poser.
##
## Reçu en table plutôt que construit en index maison : GameDatabase est un autoload que le
## domaine ne lit jamais, et une classe BuildingCatalogue qui ne ferait qu'indexer neuf .tres
## serait un fichier de plus pour un Dictionary typé.
var _buildings: Dictionary[StringName, BuildingData] = {}

## Tour courant. Le premier est 1, et il l'est avant même la fondation.
var _turn := 1

## Ancre du Cœur, ou NO_CELL tant qu'il n'est pas fondé.
##
## Retenue plutôt que retrouvée en balayant la ville à la recherche d'un identifiant : le nom
## du bâtiment d'ouverture vit dans data/balance/, et le chercher demanderait de le comparer
## bâtiment par bâtiment à chaque question de défaite.
var _heart := NO_CELL

## Ce que le dernier tour a rendu, ou null avant le premier.
##
## Retenu **ici** et non dans une vue, par l'argument que I1 employait déjà pour le brouillon
## d'affectation : ce qui persiste d'un run est du run, et une accumulation d'adapter ne se
## rejouerait pas d'un seed à l'autre. C'est la première ligne de la boucle de DESIGN.md 2 —
## « on lit ce que le tour précédent a rendu » — et elle a besoin que quelqu'un s'en souvienne.
var _last: TurnReport = null

## Comment le run s'est terminé, ou null tant qu'il tourne.
var _outcome: RunOutcome = null

## Ouvre un run sur ce seed, ce relief et ce catalogue.
##
## La réserve et la population partent des chiffres d'ouverture de data/balance/, écrêtés à
## leur plafond de base — les deux plafonds, à ce moment, sont ceux d'une ville vide, ce qui
## est exactement ce qu'elle est. C'est la fondation qui les relèvera.
static func open(run_seed: int, grid: HeightGrid,
		buildings: Dictionary[StringName, BuildingData], balance: BalanceData) -> RunState:
	assert(grid != null, "run ouvert sans relief")
	assert(balance != null, "run ouvert sans équilibrage")
	assert(balance.missing_fields().is_empty(),
		"run ouvert sur un équilibrage incomplet : %s"
			% ", ".join(balance.missing_fields()))
	var opener := balance.run.starting_building
	assert(opener.is_empty() or buildings.has(opener),
		"balance/run_balance.tres → starting_building nomme un bâtiment inconnu : %s" % opener)

	var state := RunState.new()
	state._run_seed = run_seed
	state._rng = RandomNumberGenerator.new()
	state._rng.seed = run_seed
	state._balance = balance
	state._grid = grid
	state._terrain = grid.to_query()
	state._city = CityState.new()
	state._ledger = Ledger.from_stock(balance.economy.starting_stock,
		balance.economy.base_storage_cap)
	state._people = Population.from_headcount(balance.economy.starting_population,
		balance.economy.base_housing)
	state._buildings = buildings.duplicate()
	return state

## Seed du run. Ce seed plus la même suite de gestes rejoue le run à l'identique.
func run_seed() -> int:
	return _run_seed

## RNG du run. Tout l'aléatoire du jeu passe par lui.
func rng() -> RandomNumberGenerator:
	return _rng

## L'équilibrage sur lequel ce run s'est ouvert.
func balance() -> BalanceData:
	return _balance

## Le relief, mutable — c'est ce qu'un terrassement déplacera à C5.
func grid() -> HeightGrid:
	return _grid

## Le relief en lecture seule, tel que les autres systèmes le voient.
##
## Une vue et non une copie : un terrassement appliqué à la grille se lira immédiatement à
## travers elle, sans invalidation.
func terrain() -> TerrainQuery:
	return _terrain

## La ville.
func city() -> CityState:
	return _city

## La réserve.
func ledger() -> Ledger:
	return _ledger

## La population.
func people() -> Population:
	return _people

## Données de ce bâtiment, ou null si le catalogue ne le connaît pas.
func building(id: StringName) -> BuildingData:
	if not _buildings.has(id):
		return null
	return _buildings[id]

## Qui tourne et qui dort, pour la ville et l'effectif de **cet instant**.
##
## Reprojeté à chaque appel et jamais gardé, ce qui est la décision qui porte N1 : « le
## sommeil n'est pas un état, c'est un calcul ». Un plan tenu à côté vieillirait à la
## première famille de gestes qu'on aurait oublié d'énumérer, et il vieillirait **en
## silence** — un bâtiment endormi par erreur ne plante pas, il cesse de produire.
##
## C'est aussi ce qui rend le repeuplement automatique gratuit : il n'y a rien à repeupler,
## puisqu'il n'y avait rien d'éteint.
func staffing() -> StaffingPlan:
	return Staffing.resolve(_city.to_snapshot(), _people.headcount())

## Tour courant. Le premier est 1.
func turn() -> int:
	return _turn

## Tours qu'il reste à jouer après celui-ci. 0 sur le dernier.
func turns_left() -> int:
	return maxi(0, _balance.run.turns - _turn)

## Est-ce le dernier tour du run ?
func is_last_turn() -> bool:
	return _turn >= _balance.run.turns

## Passe au tour suivant. Aucune règle n'est vérifiée ici : c'est l'orchestrateur qui décide
## qu'un tour est fini, comme set_heart_anchor() le laisse décider d'une fondation.
func advance_turn() -> void:
	_turn += 1

## Chantiers ouverts, c'est-à-dire posés et pas encore achevés.
##
## C'est ce que la file de DESIGN.md 3.2 borne, et la comparaison à build_slots se fait chez
## l'orchestrateur : compter est une projection, plafonner est une règle.
##
## Il passe par les PlacedBuilding et non par un CitySnapshot : la question se pose à chaque
## image dans un HUD, et projeter la ville entière pour compter serait une allocation par
## image pour un entier.
func open_sites() -> int:
	var open := 0
	for building in _city.buildings():
		if not building.is_complete():
			open += 1
	return open

## Le run attend-il qu'on pose son Cœur ?
##
## Vrai avant la fondation, et **seulement** si data/balance/ nomme un bâtiment d'ouverture.
## Un starting_building vide n'est pas un oubli mais le run d'un harnais qui veut une carte
## nue : celui-là n'attend rien et joue son premier tour aussitôt.
func awaits_its_heart() -> bool:
	return _heart == NO_CELL and not _balance.run.starting_building.is_empty()

## Ancre du Cœur, ou NO_CELL s'il n'est pas posé — ou s'il n'y en a pas.
##
## C'est par elle que la défaite de DESIGN.md 5 se lit : le Cœur est tombé quand la ville ne
## porte plus cette ancre. Un run sans bâtiment d'ouverture rend NO_CELL pour toujours, et ne
## peut donc pas perdre son Cœur — ce qui est la bonne réponse et non un trou.
func heart_anchor() -> Vector2i:
	return _heart

## Retient où le Cœur vient d'être posé. Aucune règle n'est vérifiée ici.
func set_heart_anchor(anchor: Vector2i) -> void:
	assert(anchor != NO_CELL, "Cœur fondé nulle part")
	_heart = anchor

## Le Cœur est-il encore debout ? Faux dès qu'il est tombé.
##
## Vrai aussi sur un run sans bâtiment d'ouverture, et c'est voulu : un run qui n'a pas de
## Cœur ne peut pas le perdre. Le seul cas qui rend faux est un Cœur posé puis détruit.
func has_its_heart() -> bool:
	return _heart == NO_CELL or _city.has_anchor(_heart)

## Points de vie qu'il reste au Cœur. 0 s'il est tombé, ou si le run n'en a pas.
##
## Terme du score de DESIGN.md 5, et rien ne l'entame avant V4 : il vaudra les PV pleins du
## Cœur à chaque verdict jusque-là.
func heart_hit_points() -> int:
	if _heart == NO_CELL or not _city.has_anchor(_heart):
		return 0
	return _city.building_at(_heart).hit_points_left()

## Où poser le Cœur si l'on ne veut pas choisir : la première ancre acceptée en balayant du
## centre vers les bords, ou NO_CELL si aucune ne convient.
##
## Une **suggestion** et non une règle : c'est l'orchestrateur qui fonde, et rien n'oblige à
## prendre cette case. Elle existe pour qu'un harnais et une capture aient une réponse sans
## piloter de clic, et pour que I3 n'ait pas à demander au joueur avant d'avoir un écran.
##
## L'ordre est totalement déterministe — à distance égale du centre, le balayage en y puis en
## x départage —, donc deux runs partis du même seed proposent la même case.
func suggested_heart_anchor() -> Vector2i:
	var data := building(_balance.run.starting_building)
	if data == null:
		return NO_CELL
	var extent := _terrain.size()
	var middle := extent / 2
	var cells: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var near := (first - middle).length_squared()
		var far := (second - middle).length_squared()
		if near != far:
			return near < far
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	for anchor in cells:
		if PlacementValidator.validate(_city, _terrain, data, anchor).is_ok():
			return anchor
	return NO_CELL

## Ce que le dernier tour a rendu, ou null avant le premier.
func last_report() -> TurnReport:
	return _last

## Retient ce que le tour vient de rendre.
func record_turn(report: TurnReport) -> void:
	assert(report != null, "tour retenu sans rapport")
	_last = report

## Le run est-il fini ?
##
## Le **si** d'une fin ; le **pourquoi** est outcome(), et il n'y en a qu'un. Les deux sont
## posés d'un seul geste par l'orchestrateur : un run qui porterait une issue en continuant
## d'avancer, ou qui s'arrêterait sans dire pourquoi, seraient deux moitiés de la même
## incohérence.
func is_over() -> bool:
	return _outcome != null

## Comment le run s'est terminé, ou null tant qu'il tourne.
func outcome() -> RunOutcome:
	return _outcome

## Referme le run sur cette issue.
func set_outcome(outcome: RunOutcome) -> void:
	assert(outcome != null, "run refermé sans issue")
	assert(_outcome == null, "run refermé deux fois")
	_outcome = outcome
