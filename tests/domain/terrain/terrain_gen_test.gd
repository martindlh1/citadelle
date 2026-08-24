class_name TerrainGenTest
extends GdUnitTestSuite
## La génération : déterminisme d'abord, invariants ensuite.
##
## Les réglages sont construits en code plutôt que chargés depuis data/balance/ :
## aucun de ces cas ne fige un chiffre d'équilibrage, et aucun ne cassera à la
## prochaine passe de réglage. Ce qui est vérifié, ce sont les invariants et le fait
## que les molettes sont réellement câblées.

const SEED := 1234
const SIZE := Vector2i(16, 16)

func test_the_same_seed_gives_an_identical_grid() -> void:
	var first := TerrainGen.generate(SEED, SIZE, _params())
	var second := TerrainGen.generate(SEED, SIZE, _params())
	assert_bool(_grids_match(first, second)) \
		.override_failure_message("même seed, grilles différentes") \
		.is_true()

func test_different_seeds_give_different_grids() -> void:
	var first := TerrainGen.generate(SEED, SIZE, _params())
	var second := TerrainGen.generate(SEED + 1, SIZE, _params())
	assert_bool(_grids_match(first, second)) \
		.override_failure_message("seeds différents, grilles identiques") \
		.is_false()

## La génération ne consomme aucun flux partagé : ce qui a été généré avant elle ne
## doit rien changer à son résultat.
func test_generation_does_not_depend_on_call_order() -> void:
	var reference := TerrainGen.generate(SEED, SIZE, _params())
	TerrainGen.generate(SEED + 7, SIZE, _params())
	TerrainGen.generate(SEED + 99, Vector2i(8, 5), _params())
	var again := TerrainGen.generate(SEED, SIZE, _params())
	assert_bool(_grids_match(reference, again)).is_true()

func test_grid_has_the_requested_size() -> void:
	var size := Vector2i(9, 4)
	var grid := TerrainGen.generate(SEED, size, _params())
	assert_vector(grid.size()).is_equal(size)

func test_every_cell_carries_a_terrain() -> void:
	var grid := TerrainGen.generate(SEED, SIZE, _params())
	for cell in _cells(grid):
		assert_object(grid.terrain_at(cell)) \
			.override_failure_message("terrain null en %s" % cell) \
			.is_not_null()

func test_heights_stay_within_the_configured_bounds() -> void:
	var params := _params()
	var grid := TerrainGen.generate(SEED, SIZE, params)
	for cell in _cells(grid):
		var height := grid.height_at(cell)
		assert_int(height) \
			.override_failure_message("hauteur %d hors bornes en %s" % [height, cell]) \
			.is_between(params.min_height, params.max_height)

## Une nappe est plate, et rien n'est immergé sans être de l'eau.
func test_water_sits_exactly_at_the_water_level() -> void:
	var params := _params()
	var grid := TerrainGen.generate(SEED, SIZE, params)
	for cell in _cells(grid):
		var height := grid.height_at(cell)
		if grid.terrain_at(cell) == params.water:
			assert_int(height) \
				.override_failure_message("eau à %d en %s" % [height, cell]) \
				.is_equal(params.water_level)
		else:
			assert_int(height) \
				.override_failure_message("terre à %d sous la nappe en %s" % [height, cell]) \
				.is_greater(params.water_level)

func test_the_generated_map_actually_has_water() -> void:
	var params := _params()
	var grid := TerrainGen.generate(SEED, SIZE, params)
	assert_int(_count(grid, params.water)) \
		.override_failure_message("aucune eau : le cas d'eau ne prouverait rien") \
		.is_greater(0)

func test_zero_forest_density_places_no_forest() -> void:
	var params := _params()
	params.forest_density = 0.0
	var grid := TerrainGen.generate(SEED, SIZE, params)
	assert_int(_count(grid, params.forest)).is_equal(0)

func test_zero_stone_density_places_no_stone() -> void:
	var params := _params()
	params.stone_density = 0.0
	var grid := TerrainGen.generate(SEED, SIZE, params)
	assert_int(_count(grid, params.stone)).is_equal(0)

func test_zero_rock_density_places_no_rock() -> void:
	var params := _params()
	params.rock_density = 0.0
	var grid := TerrainGen.generate(SEED, SIZE, params)
	assert_int(_count(grid, params.rock)).is_equal(0)

## Densité à fond, plafond bas : la forêt doit s'arrêter net à l'altitude dite.
func test_forest_never_grows_above_its_ceiling() -> void:
	var params := _params()
	params.forest_density = 1.0
	params.stone_density = 0.0
	params.rock_density = 0.0
	params.forest_max_height = 2
	var grid := TerrainGen.generate(SEED, SIZE, params)
	for cell in _cells(grid):
		if grid.terrain_at(cell) == params.forest:
			assert_int(grid.height_at(cell)) \
				.override_failure_message("forêt à %d en %s" % [grid.height_at(cell), cell]) \
				.is_less_equal(params.forest_max_height)
	assert_int(_count(grid, params.forest)) \
		.override_failure_message("aucune forêt : le plafond ne prouverait rien") \
		.is_greater(0)

## Relever le plafond de la forêt ne doit pas décaler le flux de dispersion : les
## gisements, tirés dans une bande suivante, restent aux mêmes cellules.
func test_the_forest_ceiling_does_not_shift_the_scatter_stream() -> void:
	var low := _params()
	low.forest_max_height = 0
	var high := _params()
	high.forest_max_height = 99
	var low_grid := TerrainGen.generate(SEED, SIZE, low)
	var high_grid := TerrainGen.generate(SEED, SIZE, high)
	for cell in _cells(low_grid):
		var low_is_stone := low_grid.terrain_at(cell) == low.stone
		var high_is_stone := high_grid.terrain_at(cell) == high.stone
		assert_bool(low_is_stone) \
			.override_failure_message("gisement décalé en %s" % cell) \
			.is_equal(high_is_stone)

func _params() -> TerrainGenBalance:
	var params := TerrainGenBalance.new()
	params.map_size = SIZE
	params.min_height = 0
	params.max_height = 5
	params.water_level = 1
	params.noise_frequency = 0.1
	params.noise_octaves = 3
	params.forest_density = 0.3
	params.stone_density = 0.1
	params.rock_density = 0.05
	params.forest_max_height = 4
	params.plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED)
	params.forest = _make_terrain(&"forest", TerrainData.Build.ALLOWED, &"forest")
	params.stone = _make_terrain(&"stone", TerrainData.Build.ALLOWED, &"stone")
	params.water = _make_terrain(&"water", TerrainData.Build.BLOCKED, &"water")
	params.rock = _make_terrain(&"rock", TerrainData.Build.BLOCKED, &"blocker")
	return params

func _make_terrain(id: StringName, build: TerrainData.Build, tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	if not tag.is_empty():
		data.tags.append(tag)
	return data

func _cells(grid: HeightGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid.size().y:
		for x in grid.size().x:
			cells.append(Vector2i(x, y))
	return cells

func _count(grid: HeightGrid, terrain: TerrainData) -> int:
	var total := 0
	for cell in _cells(grid):
		if grid.terrain_at(cell) == terrain:
			total += 1
	return total

## Deux grilles portent-elles exactement les mêmes hauteurs et les mêmes terrains ?
## Comparaison par identifiant : deux appels rendent des TerrainData distincts.
func _grids_match(first: HeightGrid, second: HeightGrid) -> bool:
	if first.size() != second.size():
		return false
	for cell in _cells(first):
		if first.height_at(cell) != second.height_at(cell):
			return false
		if first.terrain_at(cell).id != second.terrain_at(cell).id:
			return false
	return true
