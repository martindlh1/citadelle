class_name RunStateTest
extends GdUnitTestSuite
## Ce qu'un run possède à son ouverture, et ce qu'il sait dire de lui-même.
##
## Ce fichier teste des **projections**, jamais des règles : ce qui décide est chez
## RunOrchestrator et a sa propre suite. On vérifie ici qu'un run naît avec les bons états,
## qu'il compte juste, et qu'il ne cache rien de ce dont l'orchestrateur aura besoin.
##
## ---
##
## **L'équilibrage est chargé depuis data/ puis surchargé**, et c'est un choix qui mérite un
## mot. RunState.open() refuse un BalanceData incomplet, donc un cas de test devrait sinon
## remplir à la main les blocs terrain, génération et caméra, qui ne le regardent en rien —
## une trentaine de champs de bruit autour des deux qui comptent. Il part donc du fichier
## réel, en **remplace entièrement** les blocs economy et run, et n'assert jamais rien qui
## vienne des trois autres. Aucun chiffre d'équilibrage n'est donc figé ici.

const SIZE := Vector2i(8, 8)
const BASE_STORAGE := 100
const BASE_HOUSING := 6
const STARTING_POPULATION := 4
const RUN_TURNS := 20

var _grid: HeightGrid
var _balance: BalanceData

func before_test() -> void:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	plain.color = Color(0.4, 0.6, 0.3)
	_grid = HeightGrid.create(SIZE, 0, plain)
	_balance = _make_balance()

func _make_balance() -> BalanceData:
	var balance := (load("res://data/balance/balance.tres") as BalanceData).duplicate()
	balance.economy = _economy()
	balance.run = _run()
	return balance

func _economy() -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = BASE_STORAGE
	economy.base_housing = BASE_HOUSING
	economy.starting_population = STARTING_POPULATION
	economy.upkeep_per_inhabitant = 1
	economy.upkeep_resource = &"food"
	economy.starting_stock = {&"food": 20, &"wood": 50} as Dictionary[StringName, int]
	return economy

func _run(starting_building := &"heart") -> RunBalance:
	var run := RunBalance.new()
	run.turns = RUN_TURNS
	run.starting_building = starting_building
	run.score_per_resource = 1
	run.score_per_building = 5
	run.score_per_inhabitant = 10
	run.score_per_heart_hit_point = 2
	return run

func _building(id: StringName, footprint: Array[Vector2i], site_turns := 0,
		housing := 0) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.footprint = footprint
	data.hit_points = 40
	data.site_turns = site_turns
	data.housing = housing
	return data

func _catalogue() -> Dictionary[StringName, BuildingData]:
	var square: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1)]
	var single: Array[Vector2i] = [Vector2i.ZERO]
	return {
		&"heart": _building(&"heart", square, 0, 4),
		&"hut": _building(&"hut", single, 1),
	} as Dictionary[StringName, BuildingData]

func _open(seed_value := 1234) -> RunState:
	return RunState.open(seed_value, _grid, _catalogue(), _balance)

# --- ce qu'un run reçoit à l'ouverture --------------------------------------

func test_a_run_opens_on_its_seed_and_its_first_turn() -> void:
	var state := _open(4242)
	assert_int(state.run_seed()).is_equal(4242)
	assert_int(state.rng().seed).is_equal(4242)
	assert_int(state.turn()).is_equal(1)
	assert_bool(state.is_over()).is_false()
	assert_object(state.outcome()).is_null()
	assert_object(state.last_report()).is_null()

func test_a_run_opens_on_an_empty_city_and_the_starting_stock() -> void:
	var state := _open()
	assert_int(state.city().count()).is_equal(0)
	assert_int(state.ledger().amount(&"wood")).is_equal(50)
	assert_int(state.ledger().capacity()).is_equal(BASE_STORAGE)

## Les deux plafonds de l'ouverture sont ceux d'une ville vide, ce qui est exactement ce
## qu'elle est. C'est la fondation qui les relèvera.
func test_a_run_opens_on_the_base_housing_and_its_starting_population() -> void:
	var state := _open()
	assert_int(state.people().headcount()).is_equal(STARTING_POPULATION)
	assert_int(state.people().places()).is_equal(BASE_HOUSING)

func test_a_run_carries_the_balance_it_opened_on() -> void:
	var state := _open()
	assert_object(state.balance()).is_same(_balance)

## Le relief est mutable — c'est ce qu'un terrassement déplacera à C5 — et la vue en lecture
## seule le suit sans invalidation.
func test_the_terrain_view_follows_the_grid() -> void:
	var state := _open()
	state.grid().set_height(Vector2i(3, 3), 5)
	assert_int(state.terrain().height_at(Vector2i(3, 3))).is_equal(5)

func test_an_unknown_building_gives_null_rather_than_an_error() -> void:
	assert_object(_open().building(&"cathedral")).is_null()

# --- l'attente du Cœur -------------------------------------------------------

func test_a_run_awaits_its_heart_before_anything_is_placed() -> void:
	assert_bool(_open().awaits_its_heart()).is_true()
	assert_vector(_open().heart_anchor()).is_equal(RunState.NO_CELL)

## Un starting_building vide n'est pas un oubli : c'est le run d'un harnais qui veut une
## carte nue. Celui-là n'attend rien.
func test_a_run_without_a_starting_building_awaits_nothing() -> void:
	_balance.run = _run(&"")
	assert_bool(_open().awaits_its_heart()).is_false()

## Un run sans Cœur ne peut pas le perdre — c'est la bonne réponse et non un trou. La
## défaite par Cœur ne guette que celui qui en a posé un.
func test_a_run_without_a_heart_cannot_lose_it() -> void:
	_balance.run = _run(&"")
	var state := _open()
	assert_bool(state.has_its_heart()).is_true()
	assert_int(state.heart_hit_points()).is_equal(0)

func test_a_placed_heart_is_standing_and_carries_its_hit_points() -> void:
	var state := _open()
	state.city().place(state.terrain(), state.building(&"heart"), Vector2i(2, 2))
	state.set_heart_anchor(Vector2i(2, 2))
	assert_bool(state.awaits_its_heart()).is_false()
	assert_bool(state.has_its_heart()).is_true()
	assert_int(state.heart_hit_points()).is_equal(40)

func test_a_heart_torn_down_is_no_longer_standing() -> void:
	var state := _open()
	state.city().place(state.terrain(), state.building(&"heart"), Vector2i(2, 2))
	state.set_heart_anchor(Vector2i(2, 2))
	state.city().remove(Vector2i(2, 2))
	assert_bool(state.has_its_heart()).is_false()
	assert_int(state.heart_hit_points()).is_equal(0)

# --- la case suggérée --------------------------------------------------------

## Une suggestion, jamais une règle : elle existe pour qu'un harnais et une capture aient
## une réponse sans piloter de clic. Ce qui compte est qu'elle soit **acceptable** et
## **reproductible**.
func test_the_suggested_anchor_is_a_placement_the_validator_accepts() -> void:
	var state := _open()
	var anchor := state.suggested_heart_anchor()
	assert_vector(anchor).is_not_equal(RunState.NO_CELL)
	assert_bool(PlacementValidator.validate(state.city(), state.terrain(),
		state.building(&"heart"), anchor).is_ok()).is_true()

func test_two_runs_on_the_same_map_suggest_the_same_cell() -> void:
	assert_vector(_open(1).suggested_heart_anchor()) \
		.is_equal(_open(2).suggested_heart_anchor())

## Aucune case ne convient : la grille entière est inconstructible. NO_CELL est une
## réponse, pas une erreur.
func test_a_map_where_nothing_fits_suggests_nothing() -> void:
	var water := TerrainData.new()
	water.id = &"water"
	water.build = TerrainData.Build.BLOCKED
	water.color = Color(0.2, 0.3, 0.7)
	_grid = HeightGrid.create(SIZE, 0, water)
	assert_vector(_open().suggested_heart_anchor()).is_equal(RunState.NO_CELL)

# --- ce que le run compte ----------------------------------------------------

## Plus rien ne borne ce compte depuis que la file de chantiers est retirée : c'est une
## lecture d'écran, et ce sont les bras qui plafonnent, à l'ouverture.
func test_open_sites_counts_what_is_not_finished_yet() -> void:
	var state := _open()
	state.city().place(state.terrain(), state.building(&"heart"), Vector2i(0, 0))
	assert_int(state.open_sites()).is_equal(0)
	state.city().place(state.terrain(), state.building(&"hut"), Vector2i(4, 4))
	assert_int(state.open_sites()).is_equal(1)
	state.city().advance(Vector2i(4, 4))
	assert_int(state.open_sites()).is_equal(0)

func test_a_run_counts_down_to_its_last_turn() -> void:
	var state := _open()
	assert_int(state.turns_left()).is_equal(RUN_TURNS - 1)
	assert_bool(state.is_last_turn()).is_false()
	for _turn in RUN_TURNS - 1:
		state.advance_turn()
	assert_int(state.turn()).is_equal(RUN_TURNS)
	assert_int(state.turns_left()).is_equal(0)
	assert_bool(state.is_last_turn()).is_true()

## Le sommeil est un calcul et non un état mémorisé : le plan se redérive à chaque appel, de
## la ville et de l'effectif du moment. C'est la décision qui porte N1, vue depuis le run.
func test_the_staffing_plan_is_recomputed_from_the_city_of_the_moment() -> void:
	var state := _open()
	assert_int(state.staffing().committed()).is_equal(0)
	var hut := state.building(&"hut")
	hut.workers = 3
	state.city().place(state.terrain(), hut, Vector2i(4, 4))
	assert_int(state.staffing().committed()).is_equal(3)
	assert_int(state.staffing().available()).is_equal(STARTING_POPULATION - 3)
	state.city().remove(Vector2i(4, 4))
	assert_int(state.staffing().committed()).is_equal(0)
