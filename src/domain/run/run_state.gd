class_name RunState
extends RefCounted
## Tout ce qu'un run possède : le relief, la ville, la réserve, le roster, le deck, ce
## qui est posé, qui le tient, et où l'on en est dans la journée.
##
## C'est le seul objet du projet qui tienne les états internes de plusieurs systèmes à la
## fois, et `DESIGN.md` 3.8 l'autorise nommément : le Cycle de jour est « le seul système
## qui connaît tous les autres. C'est volontaire : il orchestre, les autres s'ignorent ».
## Rien ne remonte dans l'autre sens — ni le `Ledger` ni le `CityState` ne savent qu'un run
## existe.
##
## **Il porte son équilibrage**, à l'inverse de tous les autres objets du domaine, qui le
## reçoivent en argument. La raison est le déterminisme : `CLAUDE.md` promet qu'« un seed
## plus une liste d'actions doit rejouer un run à l'identique », et cela n'est vrai que si
## le run rejoue sur **les chiffres avec lesquels il s'est ouvert**. Les tenir ici les fige
## avec le seed, au lieu de les laisser arriver à chaque appel. C'est le même geste que
## `Deck`, qui garde son catalogue.
##
## Il ne contient **aucune règle**. Ouvrir, projeter, tenir un brouillon d'affectation :
## ce qui décide appartient à `RunOrchestrator`, ce qui calcule aux résolveurs. La seule
## chose qui ressemble à une règle ici est la pose du Cœur, et c'est parce qu'un run sans
## son Cœur n'est pas un état valide de run.

## Valeur qu'aucune action posée ne porte, reprise d'`Assignment` et d'`ActionBoard`.
const NO_ACTION := 0

## Cellule rendue quand aucune ne convient.
const NO_CELL := Vector2i(-1, -1)

var _run_seed: int
var _rng: RandomNumberGenerator
var _balance: BalanceData
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState
var _ledger: Ledger
var _roster: Roster
var _deck: Deck
var _board: ActionBoard
var _cycle: DayCycle
var _catalogue: CardCatalogue

## Identifiant -> données du bâtiment. Ce que les cartes de bâtiment peuvent poser.
var _buildings: Dictionary[StringName, BuildingData] = {}

## Ouvrier -> action qu'il tient, dans l'ordre où on les y a envoyés.
##
## C'est le **brouillon** dont `Assignment` parle : « l'UI d'affectation tient son propre
## brouillon et en fabrique une quand la phase se résout ». Il vit ici et non dans un
## adapter depuis `I1`, ce qui le rend testable — et ce qui garantit que l'ordre
## d'affectation, dont dépend le remplissage des postes, est le même à chaque rejeu.
var _staffing: Dictionary[StringName, int] = {}

## Ouvre un run sur ce seed, ce relief et ce roster.
##
## Le roster est **reçu** et non fabriqué. `DESIGN.md` 3.4 garde le recrutement sous un
## `OUVERT` — « le plafond de places existe, ce qui le remplit non » —, et inventer ici
## des ouvriers de départ trancherait cette question par accident.
##
## Le catalogue de bâtiments arrive de la même façon, en table plutôt qu'en index maison :
## `GameDatabase` est un autoload que le domaine ne lit jamais, et une classe
## `BuildingCatalogue` qui ne ferait qu'indexer douze `.tres` serait un fichier de plus
## pour un `Dictionary` typé.
static func open(run_seed: int, grid: HeightGrid, roster: Roster,
		catalogue: CardCatalogue, buildings: Dictionary[StringName, BuildingData],
		balance: BalanceData) -> RunState:
	assert(grid != null, "run ouvert sans relief")
	assert(roster != null, "run ouvert sans roster")
	assert(catalogue != null, "run ouvert sans catalogue de cartes")
	assert(balance != null, "run ouvert sans équilibrage")
	assert(balance.missing_fields().is_empty(),
		"run ouvert sur un équilibrage incomplet : %s"
			% ", ".join(balance.missing_fields()))

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
	state._roster = roster
	state._board = ActionBoard.new()
	state._cycle = DayCycle.create(balance.run.phases, balance.run.days)
	state._buildings = buildings.duplicate()
	state._catalogue = catalogue
	state._deck = Deck.create(catalogue, balance.deck.starting_deck)
	for pool in CardData.POOLS:
		state._deck.shuffle(pool, state._rng)
	state._place_starting_building()
	state.draw_phase()
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

## Le relief, mutable — c'est ce qu'un terrassement déplace.
func grid() -> HeightGrid:
	return _grid

## Le relief en lecture seule, tel que les autres systèmes le voient.
##
## Une vue et non une copie : un terrassement appliqué à la grille se lit immédiatement à
## travers elle, sans invalidation.
func terrain() -> TerrainQuery:
	return _terrain

## La ville.
func city() -> CityState:
	return _city

## La réserve.
func ledger() -> Ledger:
	return _ledger

## Le roster.
func roster() -> Roster:
	return _roster

## Le deck.
func deck() -> Deck:
	return _deck

## Ce qui est posé dans la phase courante.
func board() -> ActionBoard:
	return _board

## Le catalogue de cartes. C'est lui qui dit d'une carte si elle pose un bâtiment.
func catalogue() -> CardCatalogue:
	return _catalogue

## Où l'on en est dans la journée.
func cycle() -> DayCycle:
	return _cycle

## Données de ce bâtiment, ou null si le catalogue ne le connaît pas.
func building(id: StringName) -> BuildingData:
	if not _buildings.has(id):
		return null
	return _buildings[id]

## Ce que l'Économie voit du roster, à l'instant.
##
## Reprojetée à chaque appel plutôt que gardée : une soirée d'XP change les
## multiplicateurs, et une projection tenue à côté vieillirait sans que rien ne le dise.
func labor() -> LaborForce:
	return _roster.to_labor(_balance.workforce)

## Pioche la main de la phase, dans les trois pools, aux tailles de `data/balance/`.
##
## Le seul endroit où la politique de pioche est écrite. `D1` avait laissé ce moment
## dehors en toutes lettres — « le Deck offre les gestes, la journée choisit quand les
## faire » — et la journée, c'est ce dossier.
func draw_phase() -> void:
	for pool in CardData.POOLS:
		var size: int = _balance.deck.hand_size.get(pool, 0)
		if size > 0:
			_deck.draw(pool, size, _rng)

## Envoie cet ouvrier sur cette action. Aucune règle n'est vérifiée ici : c'est
## `RunOrchestrator.staff()` qui pose les questions, comme `ActionBoard.post()` passe par
## `ActionTargeting`.
func assign_worker(worker: StringName, action: int) -> void:
	assert(not worker.is_empty(), "affectation d'un ouvrier sans identifiant")
	assert(action != NO_ACTION, "affectation à aucune action")
	_staffing[worker] = action

## Rappelle cet ouvrier. Rend faux s'il n'était affecté à rien.
func release_worker(worker: StringName) -> bool:
	return _staffing.erase(worker)

## Rappelle tous les ouvriers de cette action et rend leurs identifiants.
func release_action(action: int) -> Array[StringName]:
	var recalled := staffed_on(action)
	for worker in recalled:
		_staffing.erase(worker)
	return recalled

## Vide le brouillon d'affectation.
func clear_staffing() -> void:
	_staffing.clear()

## Cet ouvrier est-il déjà quelque part ?
func is_staffed(worker: StringName) -> bool:
	return _staffing.has(worker)

## Ouvriers envoyés sur cette action, dans l'ordre d'affectation.
func staffed_on(action: int) -> Array[StringName]:
	var held: Array[StringName] = []
	for worker in _staffing:
		if _staffing[worker] == action:
			held.append(worker)
	return held

## Ouvriers présents que rien n'occupe, dans l'ordre du roster.
func free_workers() -> Array[StringName]:
	var free: Array[StringName] = []
	for worker in _roster.present():
		if not _staffing.has(worker.id()):
			free.append(worker.id())
	return free

## L'affectation figée, telle que les résolveurs la consomment.
func to_assignment() -> Assignment:
	return Assignment.create(_staffing)

## Pose le bâtiment d'ouverture au plus près du centre, s'il y en a un.
##
## Automatique, et c'est un bouchon assumé : `DESIGN.md` 2 fait de la pose du Cœur une
## étape que le joueur franchira, et l'écran qui la lui demande appartient à `I2`. Le
## poser au centre est ce qui s'en approche le plus sans rien inventer.
func _place_starting_building() -> void:
	var id := _balance.run.starting_building
	if id.is_empty():
		return
	var data := building(id)
	assert(data != null,
		"balance/run_balance.tres → starting_building nomme un bâtiment inconnu : %s" % id)
	if data == null:
		return
	var anchor := _nearest_anchor_to_the_middle(data)
	assert(anchor != NO_CELL, "aucune place pour %s sur ce relief" % id)
	if anchor == NO_CELL:
		return
	_city.place(_terrain, data, anchor)

## La première ancre acceptée en balayant du centre vers les bords.
##
## L'ordre est totalement déterministe : à distance égale du centre, c'est le balayage en
## y puis en x qui départage. Deux runs partis du même seed posent donc leur Cœur sur la
## même case.
func _nearest_anchor_to_the_middle(data: BuildingData) -> Vector2i:
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
