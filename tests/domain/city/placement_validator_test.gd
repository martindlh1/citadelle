class_name PlacementValidatorTest
extends GdUnitTestSuite
## Les quatre règles de placement, et l'ordre dans lequel elles se prononcent.
##
## Grille de travail, 6 x 6. Plaine à hauteur 0 partout, sauf :
##   - (4, 0) eau, (5, 1) rocher — les deux terrains sur lesquels on ne bâtit pas ;
##   - la colonne x = 2 montée à 1 — la marche qui casse la planéité.
##
## Aucun test ne passe par CityState.place() : ce qui est éprouvé ici, c'est la
## décision, pas le rangement.

const SIZE := Vector2i(6, 6)
const WATER_CELL := Vector2i(4, 0)
const ROCK_CELL := Vector2i(5, 1)
const RAISED_X := 2

var _plain: TerrainData
var _water: TerrainData
var _rock: TerrainData
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState

func before_test() -> void:
	_plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED)
	_water = _make_terrain(&"water", TerrainData.Build.BLOCKED, &"water")
	_rock = _make_terrain(&"rock", TerrainData.Build.BLOCKED, &"blocker")
	_grid = HeightGrid.create(SIZE, 0, _plain)
	_grid.set_cell(WATER_CELL, 0, _water)
	_grid.set_cell(ROCK_CELL, 0, _rock)
	for y in SIZE.y:
		_grid.set_height(Vector2i(RAISED_X, y), 1)
	_terrain = _grid.to_query()
	_city = CityState.new()

func test_a_clear_flat_patch_is_accepted() -> void:
	var result := _validate(_keep(), Vector2i(0, 3))
	assert_bool(result.is_ok()).is_true()
	assert_str(result.reason()).is_equal(PlacementResult.REASON_NONE)

## Les cellules rendues sont celles de l'empreinte, dans son ordre.
func test_an_accepted_placement_reports_its_cells_in_footprint_order() -> void:
	var result := _validate(_keep(), Vector2i(0, 3))
	assert_array(result.cells()).contains_exactly([
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4)])

func test_an_accepted_placement_reports_the_ground_height() -> void:
	assert_int(_validate(_hut(), Vector2i(0, 0)).height()).is_equal(0)
	assert_int(_validate(_hut(), Vector2i(RAISED_X, 0)).height()).is_equal(1)

func test_a_footprint_that_overruns_the_map_is_refused() -> void:
	var result := _validate(_keep(), Vector2i(SIZE.x - 1, 3))
	assert_str(result.reason()).is_equal(PlacementResult.REASON_OUT_OF_BOUNDS)

func test_a_negative_anchor_is_refused() -> void:
	assert_str(_validate(_hut(), Vector2i(-1, 0)).reason()) \
		.is_equal(PlacementResult.REASON_OUT_OF_BOUNDS)

func test_water_and_rock_are_refused() -> void:
	assert_str(_validate(_hut(), WATER_CELL).reason()) \
		.is_equal(PlacementResult.REASON_NOT_BUILDABLE)
	assert_str(_validate(_hut(), ROCK_CELL).reason()) \
		.is_equal(PlacementResult.REASON_NOT_BUILDABLE)

## Une seule cellule suffit à faire tomber toute l'empreinte.
func test_one_unbuildable_cell_refuses_the_whole_footprint() -> void:
	assert_str(_validate(_keep(), Vector2i(4, 1)).reason()) \
		.is_equal(PlacementResult.REASON_NOT_BUILDABLE)

func test_an_occupied_cell_is_refused() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 3))
	assert_str(_validate(_keep(), Vector2i(0, 3)).reason()) \
		.is_equal(PlacementResult.REASON_OCCUPIED)

## La règle de DESIGN.md 3.1 : toutes les cellules à la même hauteur, sans exception
## ni réglage par bâtiment.
func test_a_footprint_straddling_a_step_is_refused() -> void:
	assert_str(_validate(_keep(), Vector2i(RAISED_X - 1, 3)).reason()) \
		.is_equal(PlacementResult.REASON_UNEVEN_GROUND)

## Une empreinte d'une seule cellule est plate par construction : la règle ne mord que
## sur les bâtiments à plusieurs cellules, y compris en haut de la marche.
func test_a_single_cell_is_flat_anywhere() -> void:
	assert_bool(_validate(_hut(), Vector2i(RAISED_X, 4)).is_ok()).is_true()

## Un plateau à hauteur non nulle reste constructible : c'est la PLANÉITÉ qui est
## exigée, pas le niveau de la mer.
func test_a_raised_plateau_is_buildable() -> void:
	for y in SIZE.y:
		_grid.set_height(Vector2i(RAISED_X + 1, y), 1)
	var result := _validate(_keep(), Vector2i(RAISED_X, 3))
	assert_bool(result.is_ok()).is_true()
	assert_int(result.height()).is_equal(1)

## Le trou d'un L n'appartient pas au bâtiment : de l'eau au milieu de son enveloppe
## ne l'empêche pas de se poser. C'est ce cas qui prouve que la validation marche sur
## l'empreinte et non sur bounds_at().
func test_the_hole_of_an_l_shape_is_not_validated() -> void:
	_grid.set_cell(Vector2i(1, 4), 0, _water)
	assert_bool(_validate(_ell(), Vector2i(0, 3)).is_ok()).is_true()

## Et le trou reste libre pour autre chose.
func test_the_hole_of_an_l_shape_stays_placeable() -> void:
	_city.place(_terrain, _ell(), Vector2i(0, 3))
	assert_bool(_validate(_hut(), Vector2i(1, 4)).is_ok()).is_true()

## Deux règles échouent d'un coup : c'est l'ordre des règles qui tranche, jamais
## l'ordre dans lequel le .tres a écrit l'empreinte.
func test_out_of_bounds_wins_over_unbuildable() -> void:
	# L'empreinte tombe sur de l'eau ET déborde : les deux règles échouent.
	_grid.set_cell(Vector2i(SIZE.x - 1, 0), 0, _water)
	var result := _validate(_wide(), Vector2i(SIZE.x - 1, 0))
	assert_str(result.reason()).is_equal(PlacementResult.REASON_OUT_OF_BOUNDS)

func test_occupied_wins_over_uneven_ground() -> void:
	_city.place(_terrain, _hut(), Vector2i(RAISED_X - 1, 3))
	assert_str(_validate(_keep(), Vector2i(RAISED_X - 1, 3)).reason()) \
		.is_equal(PlacementResult.REASON_OCCUPIED)

## Une empreinte qui déborde peut rentrer une fois pivotée. C'est tout l'intérêt de
## l'orientation, et la preuve que les règles voient des cellules DÉJÀ tournées : pas
## une ligne du validateur ne parle de rotation.
func test_a_rotation_can_rescue_a_footprint_that_overruns() -> void:
	var anchor := Vector2i(SIZE.x - 1, 3)
	assert_str(_validate(_wide(), anchor).reason()) \
		.is_equal(PlacementResult.REASON_OUT_OF_BOUNDS)
	assert_bool(PlacementValidator.validate(_city, _terrain, _wide(), anchor, 1).is_ok()) \
		.is_true()

## Et elle peut de la même façon fuir une marche, en se rangeant le long du dénivelé
## au lieu de le traverser.
func test_a_rotation_can_rescue_a_footprint_on_uneven_ground() -> void:
	var anchor := Vector2i(RAISED_X - 1, 3)
	assert_str(_validate(_wide(), anchor).reason()) \
		.is_equal(PlacementResult.REASON_UNEVEN_GROUND)
	assert_bool(PlacementValidator.validate(_city, _terrain, _wide(), anchor, 1).is_ok()) \
		.is_true()

## Le fantôme de C2 appellera la validation à chaque image : elle ne doit rien
## engager, ni sur la ville ni sur le terrain.
func test_validate_mutates_nothing() -> void:
	var first := _validate(_keep(), Vector2i(0, 3))
	var second := _validate(_keep(), Vector2i(0, 3))
	assert_bool(first.is_ok()).is_true()
	assert_bool(second.is_ok()).is_true()
	assert_int(_city.count()).is_equal(0)
	assert_bool(_city.is_occupied(Vector2i(0, 3))).is_false()

func _validate(data: BuildingData, anchor: Vector2i) -> PlacementResult:
	return PlacementValidator.validate(_city, _terrain, data, anchor)

## Une cellule.
func _hut() -> BuildingData:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	return _building(&"hut", offsets)

## Un carré de deux sur deux.
func _keep() -> BuildingData:
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	return _building(&"keep", offsets)

## Un L, dont l'enveloppe couvre une cellule qu'il n'occupe pas : (1, 1).
func _ell() -> BuildingData:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	return _building(&"ell", offsets)

## Deux cellules côte à côte, pour poser une empreinte à cheval sur un bord.
func _wide() -> BuildingData:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	return _building(&"wide", offsets)

func _building(id: StringName, offsets: Array[Vector2i]) -> BuildingData:
	var building := BuildingData.new()
	building.id = id
	building.footprint = offsets
	return building

func _make_terrain(id: StringName, build: TerrainData.Build, tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	if not tag.is_empty():
		data.tags.append(tag)
	return data
