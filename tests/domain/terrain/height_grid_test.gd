class_name HeightGridTest
extends GdUnitTestSuite
## La grille elle-même : remplissage, bornes, écritures.
##
## Les terrains sont construits en code et non chargés depuis data/ : ces cas ne
## doivent pas casser à la prochaine passe d'équilibrage.

const SIZE := Vector2i(4, 3)

var _plain: TerrainData
var _water: TerrainData

func before_test() -> void:
	_plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED)
	_water = _make_terrain(&"water", TerrainData.Build.BLOCKED, &"water")

func test_create_fills_every_cell() -> void:
	var grid := HeightGrid.create(SIZE, 2, _plain)
	assert_vector(grid.size()).is_equal(SIZE)
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			assert_int(grid.height_at(cell)).is_equal(2)
			assert_object(grid.terrain_at(cell)).is_same(_plain)

## C'est cette hauteur qui fixe le dessous de la carte, pour le rendu comme pour le
## picking.
func test_lowest_height_finds_the_bottom_of_the_map() -> void:
	var grid := HeightGrid.create(SIZE, 4, _plain)
	assert_int(grid.lowest_height()).is_equal(4)
	grid.set_height(Vector2i(2, 1), -2)
	assert_int(grid.lowest_height()).is_equal(-2)

## Elle suit les écritures dans les deux sens : relever la cellule la plus basse ne doit
## pas laisser la carte croire qu'elle descend encore aussi bas.
func test_lowest_height_follows_writes_back_up() -> void:
	var grid := HeightGrid.create(SIZE, 4, _plain)
	grid.set_height(Vector2i(0, 0), 1)
	assert_int(grid.lowest_height()).is_equal(1)
	grid.set_height(Vector2i(0, 0), 6)
	assert_int(grid.lowest_height()).is_equal(4)

func test_in_bounds_accepts_the_corners() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	assert_bool(grid.in_bounds(Vector2i.ZERO)).is_true()
	assert_bool(grid.in_bounds(Vector2i(SIZE.x - 1, SIZE.y - 1))).is_true()

func test_in_bounds_rejects_just_outside() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	assert_bool(grid.in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(grid.in_bounds(Vector2i(0, -1))).is_false()
	assert_bool(grid.in_bounds(Vector2i(SIZE.x, 0))).is_false()
	assert_bool(grid.in_bounds(Vector2i(0, SIZE.y))).is_false()

func test_set_cell_round_trips() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var cell := Vector2i(2, 1)
	grid.set_cell(cell, 5, _water)
	assert_int(grid.height_at(cell)).is_equal(5)
	assert_object(grid.terrain_at(cell)).is_same(_water)

func test_set_cell_leaves_its_neighbours_alone() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	grid.set_cell(Vector2i(2, 1), 5, _water)
	assert_int(grid.height_at(Vector2i(1, 1))).is_equal(0)
	assert_int(grid.height_at(Vector2i(3, 1))).is_equal(0)
	assert_int(grid.height_at(Vector2i(2, 0))).is_equal(0)
	assert_int(grid.height_at(Vector2i(2, 2))).is_equal(0)

## Déblayer une forêt ne doit pas raboter la colline qui la porte.
func test_set_terrain_leaves_the_height_alone() -> void:
	var grid := HeightGrid.create(SIZE, 3, _plain)
	var cell := Vector2i(1, 2)
	grid.set_terrain(cell, _water)
	assert_int(grid.height_at(cell)).is_equal(3)
	assert_object(grid.terrain_at(cell)).is_same(_water)

func test_set_height_leaves_the_terrain_alone() -> void:
	var grid := HeightGrid.create(SIZE, 0, _water)
	var cell := Vector2i(0, 0)
	grid.set_height(cell, 7)
	assert_int(grid.height_at(cell)).is_equal(7)
	assert_object(grid.terrain_at(cell)).is_same(_water)

## L'indexation est y * largeur + x : une grille non carrée attrape une inversion
## des deux axes, ce qu'une grille carrée laisserait passer.
func test_a_non_square_grid_does_not_swap_its_axes() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	grid.set_height(Vector2i(3, 0), 9)
	assert_int(grid.height_at(Vector2i(3, 0))).is_equal(9)
	assert_int(grid.height_at(Vector2i(0, 2))).is_equal(0)

func _make_terrain(id: StringName, build: TerrainData.Build, tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	if not tag.is_empty():
		data.tags.append(tag)
	return data
