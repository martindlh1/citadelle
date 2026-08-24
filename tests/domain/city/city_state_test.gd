class_name CityStateTest
extends GdUnitTestSuite
## La ville : ses deux index, et la porte unique par laquelle un bâtiment y entre.
##
## Grille de travail 6 x 6, plaine partout, plate à hauteur 0 sauf la colonne x = 4,
## montée à 2 pour éprouver la hauteur que la pose enregistre.
##
## Ce fichier teste le RANGEMENT. Les règles qui acceptent ou refusent un placement
## ont leur propre suite — ici on ne se sert d'un refus que pour vérifier qu'il ne
## laisse aucune trace.

const SIZE := Vector2i(6, 6)
const RAISED_X := 4
const RAISED_HEIGHT := 2

var _plain: TerrainData
var _water: TerrainData
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState

func before_test() -> void:
	_plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED)
	_water = _make_terrain(&"water", TerrainData.Build.BLOCKED)
	_grid = HeightGrid.create(SIZE, 0, _plain)
	for y in SIZE.y:
		_grid.set_height(Vector2i(RAISED_X, y), RAISED_HEIGHT)
	_terrain = _grid.to_query()
	_city = CityState.new()

func test_a_new_city_is_empty() -> void:
	assert_int(_city.count()).is_equal(0)
	assert_array(_city.buildings()).is_empty()
	assert_bool(_city.is_occupied(Vector2i(0, 0))).is_false()
	assert_object(_city.building_at(Vector2i(0, 0))).is_null()

## La ville ne connaît pas les bornes de la carte : une cellule qui n'existe pas est
## simplement libre. C'est le contrat Terrain qui tranche l'existence.
func test_a_cell_outside_the_map_is_free_rather_than_an_error() -> void:
	assert_bool(_city.is_occupied(Vector2i(-3, 99))).is_false()
	assert_object(_city.building_at(Vector2i(-3, 99))).is_null()

func test_placing_a_single_cell_building_registers_it() -> void:
	var result := _city.place(_terrain, _hut(), Vector2i(1, 1))
	assert_bool(result.is_ok()).is_true()
	assert_int(_city.count()).is_equal(1)
	assert_bool(_city.is_occupied(Vector2i(1, 1))).is_true()
	assert_bool(_city.has_anchor(Vector2i(1, 1))).is_true()

## Les quatre cellules d'un 2x2 renvoient toutes au même bâtiment : c'est la
## « référence vers l'ancre » de DESIGN.md 3.2.
func test_every_cell_of_a_footprint_points_back_to_the_anchor() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		assert_bool(_city.is_occupied(cell)).is_true()
		assert_vector(_city.anchor_at(cell)).is_equal(Vector2i(1, 1))

## Et c'est bien la même instance qu'on retrouve depuis n'importe laquelle d'entre
## elles, pas une copie par cellule.
func test_every_cell_of_a_footprint_yields_the_same_instance() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	var from_anchor := _city.building_at(Vector2i(1, 1))
	assert_object(_city.building_at(Vector2i(2, 2))).is_same(from_anchor)

## Une cellule couverte sans être l'ancre n'ancre rien : remove() passe par
## anchor_at(), pas par la cellule cliquée.
func test_a_covered_cell_is_not_an_anchor() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	assert_bool(_city.has_anchor(Vector2i(2, 2))).is_false()
	assert_bool(_city.has_anchor(Vector2i(1, 1))).is_true()

## Le trou d'un L reste libre : la ville range l'empreinte, jamais son enveloppe.
func test_the_hole_of_an_l_shape_stays_free() -> void:
	_city.place(_terrain, _ell(), Vector2i(1, 1))
	assert_bool(_city.is_occupied(Vector2i(2, 2))).is_false()
	assert_bool(_city.place(_terrain, _hut(), Vector2i(2, 2)).is_ok()).is_true()
	assert_int(_city.count()).is_equal(2)

func test_a_placed_building_keeps_its_anchor_and_footprint() -> void:
	_city.place(_terrain, _ell(), Vector2i(1, 1))
	var building := _city.building_at(Vector2i(1, 1))
	assert_vector(building.anchor()).is_equal(Vector2i(1, 1))
	assert_str(building.data().id).is_equal(&"ell")
	assert_array(building.cells()) \
		.contains_exactly([Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])

## La hauteur est enregistrée à la pose : c'est le y auquel C2 dessinera la boîte,
## sans avoir à réinterroger la grille.
func test_a_placed_building_records_the_ground_height() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 0))
	_city.place(_terrain, _hut(), Vector2i(RAISED_X, 0))
	assert_int(_city.building_at(Vector2i(0, 0)).height()).is_equal(0)
	assert_int(_city.building_at(Vector2i(RAISED_X, 0)).height()).is_equal(RAISED_HEIGHT)

func test_overlapping_a_placed_building_is_refused() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	var result := _city.place(_terrain, _hut(), Vector2i(2, 2))
	assert_bool(result.is_ok()).is_false()
	assert_str(result.reason()).is_equal(PlacementResult.REASON_OCCUPIED)

## Un refus ne laisse aucune trace, ni dans la liste ni dans l'index de cellules.
func test_a_refused_placement_mutates_nothing() -> void:
	_grid.set_cell(Vector2i(3, 3), 0, _water)
	var result := _city.place(_terrain, _hut(), Vector2i(3, 3))
	assert_bool(result.is_ok()).is_false()
	assert_int(_city.count()).is_equal(0)
	assert_bool(_city.is_occupied(Vector2i(3, 3))).is_false()

func test_removing_frees_every_cell_of_the_footprint() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	_city.remove(Vector2i(1, 1))
	assert_int(_city.count()).is_equal(0)
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		assert_bool(_city.is_occupied(cell)).is_false()

## Et ce qui est libéré redevient constructible, sans quoi une démolition ne servirait
## à rien.
func test_a_removed_footprint_can_be_built_on_again() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	_city.remove(Vector2i(1, 1))
	assert_bool(_city.place(_terrain, _keep(), Vector2i(1, 1)).is_ok()).is_true()

## Un retrait ne touche qu'un bâtiment. Sur un index cellule -> ancre, effacer trop
## large est l'erreur naturelle : ce cas l'attrape.
func test_removing_leaves_the_other_buildings_alone() -> void:
	_city.place(_terrain, _keep(), Vector2i(0, 0))
	_city.place(_terrain, _keep(), Vector2i(2, 0))
	_city.remove(Vector2i(0, 0))
	assert_int(_city.count()).is_equal(1)
	assert_bool(_city.is_occupied(Vector2i(2, 0))).is_true()
	assert_bool(_city.is_occupied(Vector2i(3, 1))).is_true()
	assert_bool(_city.is_occupied(Vector2i(0, 0))).is_false()

## L'ordre de buildings() est l'ordre de pose. Un même seed et une même suite
## d'actions doivent rendre la même liste, sinon rien de ce qui itère dessus n'est
## reproductible.
func test_buildings_come_back_in_placement_order() -> void:
	_city.place(_terrain, _building(&"first", _single()), Vector2i(3, 3))
	_city.place(_terrain, _building(&"second", _single()), Vector2i(0, 0))
	_city.place(_terrain, _building(&"third", _single()), Vector2i(1, 5))
	var ids: Array[StringName] = []
	for building in _city.buildings():
		ids.append(building.data().id)
	assert_array(ids).contains_exactly([&"first", &"second", &"third"])

func _single() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	return offsets

func _hut() -> BuildingData:
	return _building(&"hut", _single())

func _keep() -> BuildingData:
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	return _building(&"keep", offsets)

## Un L, dont l'enveloppe couvre une cellule qu'il n'occupe pas : (1, 1).
func _ell() -> BuildingData:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	return _building(&"ell", offsets)

func _building(id: StringName, offsets: Array[Vector2i]) -> BuildingData:
	var building := BuildingData.new()
	building.id = id
	building.footprint = offsets
	return building

func _make_terrain(id: StringName, build: TerrainData.Build) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	return data
