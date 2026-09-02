class_name TerrainQueryTest
extends GdUnitTestSuite
## Le contrat lu à travers son implémentation sur grille.
##
## C'est ici que se jouent les conventions de bornes : les requêtes de
## constructibilité répondent hors carte, les mesures non.
##
## Grille de travail, 4 x 3. Hauteurs :        Terrains :
##   0 0 0 0                                     plain  plain water plain
##   1 1 2 0                                     plain  rock  plain plain
##   0 0 0 0                                     forest plain plain plain

const SIZE := Vector2i(4, 3)
const WATER_CELL := Vector2i(2, 0)
const ROCK_CELL := Vector2i(1, 1)
const FOREST_CELL := Vector2i(0, 2)

var _plain: TerrainData
var _forest: TerrainData
var _water: TerrainData
var _rock: TerrainData
var _grid: HeightGrid
var _query: TerrainQuery

func before_test() -> void:
	_plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED, TerrainData.Walk.ALLOWED)
	_forest = _make_terrain(&"forest", TerrainData.Build.ALLOWED, TerrainData.Walk.ALLOWED,
		&"forest")
	_water = _make_terrain(&"water", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED,
		&"water")
	_rock = _make_terrain(&"rock", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED,
		&"blocker")
	_grid = HeightGrid.create(SIZE, 0, _plain)
	_grid.set_cell(WATER_CELL, 0, _water)
	_grid.set_cell(ROCK_CELL, 1, _rock)
	_grid.set_cell(FOREST_CELL, 0, _forest)
	_grid.set_height(Vector2i(0, 1), 1)
	_grid.set_height(Vector2i(2, 1), 2)
	_query = _grid.to_query()

func test_query_reflects_the_grid() -> void:
	assert_vector(_query.size()).is_equal(SIZE)
	assert_int(_query.height_at(Vector2i(2, 1))).is_equal(2)
	assert_object(_query.terrain_at(FOREST_CELL)).is_same(_forest)

func test_is_buildable_follows_the_terrain() -> void:
	assert_bool(_query.is_buildable(Vector2i(0, 0))).is_true()
	assert_bool(_query.is_buildable(FOREST_CELL)).is_true()
	assert_bool(_query.is_buildable(WATER_CELL)).is_false()
	assert_bool(_query.is_buildable(ROCK_CELL)).is_false()

## Construction teste couramment des cellules hors carte : c'est une question
## légitime, pas un bug d'appelant.
func test_is_buildable_is_false_outside_the_grid() -> void:
	assert_bool(_query.is_buildable(Vector2i(-1, 0))).is_false()
	assert_bool(_query.is_buildable(Vector2i(0, -1))).is_false()
	assert_bool(_query.is_buildable(Vector2i(SIZE.x, 0))).is_false()
	assert_bool(_query.is_buildable(Vector2i(0, SIZE.y))).is_false()

# --- ce qui se marche, et ce qui s'enjambe ----------------------------------

func test_is_walkable_follows_the_terrain() -> void:
	assert_bool(_query.is_walkable(Vector2i(0, 0))).is_true()
	assert_bool(_query.is_walkable(FOREST_CELL)).is_true()
	assert_bool(_query.is_walkable(WATER_CELL)).is_false()
	assert_bool(_query.is_walkable(ROCK_CELL)).is_false()

func test_is_walkable_is_false_outside_the_grid() -> void:
	assert_bool(_query.is_walkable(Vector2i(-1, 0))).is_false()
	assert_bool(_query.is_walkable(Vector2i(0, SIZE.y))).is_false()

## **Le cas qui justifie le second champ.** Les cinq terrains de `data/` répondent la même
## chose aux deux questions, si bien qu'une franchissabilité déduite de la constructibilité
## passerait toute la suite. Un marécage — qu'on traverse et sur quoi l'on ne bâtit pas — la
## fait tomber, et c'est le seul cas de ce fichier qui distingue vraiment les deux colonnes
## de DESIGN.md 3.1.
func test_walking_and_building_are_two_questions() -> void:
	var marsh := _make_terrain(&"marsh", TerrainData.Build.BLOCKED,
		TerrainData.Walk.ALLOWED)
	_grid.set_terrain(FOREST_CELL, marsh)
	assert_bool(_query.is_buildable(FOREST_CELL)).is_false()
	assert_bool(_query.is_walkable(FOREST_CELL)).is_true()

## Monter coûte et une marche trop haute bloque ; descendre ne coûte que le pas.
func test_a_step_up_is_capped_and_a_step_down_is_not() -> void:
	var low := Vector2i(1, 0)
	var high := Vector2i(1, 1)
	_grid.set_cell(high, 3, _plain)
	assert_bool(_query.can_step(low, high, 1)).is_false()
	assert_bool(_query.can_step(low, high, 3)).is_true()
	assert_bool(_query.can_step(high, low, 0)).is_true()

func test_a_step_onto_or_off_a_blocker_is_refused() -> void:
	var beside_rock := Vector2i(0, 1)
	assert_bool(_query.can_step(beside_rock, ROCK_CELL, 9)).is_false()
	assert_bool(_query.can_step(ROCK_CELL, beside_rock, 9)).is_false()

func test_a_step_outside_the_grid_is_refused() -> void:
	assert_bool(_query.can_step(Vector2i(0, 0), Vector2i(-1, 0), 9)).is_false()

func test_has_tag_reads_the_terrain_tags() -> void:
	assert_bool(_query.has_tag(FOREST_CELL, &"forest")).is_true()
	assert_bool(_query.has_tag(WATER_CELL, &"water")).is_true()
	assert_bool(_query.has_tag(ROCK_CELL, &"blocker")).is_true()
	assert_bool(_query.has_tag(Vector2i(0, 0), &"forest")).is_false()

func test_has_tag_is_false_outside_the_grid() -> void:
	assert_bool(_query.has_tag(Vector2i(-1, -1), &"forest")).is_false()

func test_is_area_buildable_accepts_a_clear_patch() -> void:
	assert_bool(_query.is_area_buildable(Rect2i(0, 0, 2, 1))).is_true()

func test_is_area_buildable_rejects_a_blocked_cell() -> void:
	assert_bool(_query.is_area_buildable(Rect2i(1, 0, 2, 1))).is_false()

## Une empreinte posée trop près du bord déborde : refusée, sans assert.
func test_is_area_buildable_rejects_an_area_that_overruns() -> void:
	assert_bool(_query.is_area_buildable(Rect2i(3, 0, 2, 1))).is_false()
	assert_bool(_query.is_area_buildable(Rect2i(0, 2, 1, 2))).is_false()
	assert_bool(_query.is_area_buildable(Rect2i(-1, 0, 2, 1))).is_false()

func test_is_area_buildable_rejects_an_empty_area() -> void:
	assert_bool(_query.is_area_buildable(Rect2i(0, 0, 0, 0))).is_false()

func test_is_area_flat_on_a_plateau() -> void:
	assert_bool(_query.is_area_flat(Rect2i(0, 0, 4, 1))).is_true()

func test_is_area_flat_rejects_a_step() -> void:
	assert_bool(_query.is_area_flat(Rect2i(0, 0, 2, 2))).is_false()

func test_is_area_flat_rejects_an_area_that_overruns() -> void:
	assert_bool(_query.is_area_flat(Rect2i(0, 2, 4, 2))).is_false()

func test_height_span_is_highest_minus_lowest() -> void:
	assert_int(_query.height_span(Rect2i(0, 0, 3, 2))).is_equal(2)

func test_height_span_is_zero_on_a_single_cell() -> void:
	assert_int(_query.height_span(Rect2i(2, 1, 1, 1))).is_equal(0)

## La query est une vue, pas une copie : déblayer une forêt en construction doit se
## voir immédiatement, sans reconstruire quoi que ce soit.
func test_the_query_is_a_live_view() -> void:
	assert_bool(_query.has_tag(FOREST_CELL, &"forest")).is_true()
	_grid.set_terrain(FOREST_CELL, _plain)
	assert_bool(_query.has_tag(FOREST_CELL, &"forest")).is_false()
	_grid.set_height(FOREST_CELL, 9)
	assert_int(_query.height_at(FOREST_CELL)).is_equal(9)

## Les deux verdicts sont passés séparément, jamais déduits l'un de l'autre : c'est ce qui
## permet au cas du marécage ci-dessus d'exister, et c'est la raison d'être du second champ.
func _make_terrain(id: StringName, build: TerrainData.Build, walk: TerrainData.Walk,
		tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.walk = walk
	if not tag.is_empty():
		data.tags.append(tag)
	return data
