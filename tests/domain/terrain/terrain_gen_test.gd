class_name TerrainGenTest
extends GdUnitTestSuite
## La génération : déterminisme d'abord, **structure** ensuite, décoration en dernier.
##
## Les réglages sont construits en code plutôt que chargés depuis data/balance/ :
## aucun de ces cas ne fige un chiffre d'équilibrage, et aucun ne cassera à la
## prochaine passe de réglage. Ce qui est vérifié, ce sont les invariants et le fait
## que les molettes sont réellement câblées.
##
## **Deux portes et non une, et les cas choisissent.** `draft()` rend un essai brut, `generate()`
## rejette jusqu'à ce que les promesses tiennent. Les cas qui parlent de décoration passent par
## la première : ils veulent l'essai qu'ils nomment, pas celui que l'audit a fini par garder.
## Ceux qui parlent des promesses passent par la seconde, qui est leur sujet.

const SEED := 1234
const SIZE := Vector2i(20, 20)

# --- le déterminisme --------------------------------------------------------

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
	TerrainGen.draft(SEED + 99, Vector2i(8, 5), _params())
	var again := TerrainGen.generate(SEED, SIZE, _params())
	assert_bool(_grids_match(reference, again)).is_true()

## Deux essais voisins doivent donner des cartes **sans rapport** : le rang de l'essai passe
## par un pas large, pas par un « +1 ». Sans ça, un seed rejeté se ferait rejeter à nouveau
## pour le même motif autant de fois qu'il y a d'essais.
func test_two_attempts_of_one_run_are_unrelated() -> void:
	var first := TerrainGen.draft(TerrainGen.seed_for(SEED, 0), SIZE, _params())
	var second := TerrainGen.draft(TerrainGen.seed_for(SEED, 1), SIZE, _params())
	assert_bool(_grids_match(first, second)).is_false()

## Le harnais rejoue la même suite d'essais pour la mesurer : elle doit être la même à chaque
## appel, et propre à ce run.
func test_the_attempt_seeds_are_stable_and_per_run() -> void:
	assert_int(TerrainGen.seed_for(SEED, 3)).is_equal(TerrainGen.seed_for(SEED, 3))
	assert_int(TerrainGen.seed_for(SEED, 3)).is_not_equal(TerrainGen.seed_for(SEED, 4))
	assert_int(TerrainGen.seed_for(SEED, 3)).is_not_equal(TerrainGen.seed_for(SEED + 1, 3))

# --- la forme --------------------------------------------------------------

## Un brouillon ne promet rien, donc il accepte n'importe quelle taille — y compris une carte
## trop petite pour qu'un plateau y tienne ses accès.
func test_a_draft_has_the_requested_size() -> void:
	var size := Vector2i(9, 4)
	assert_vector(TerrainGen.draft(SEED, size, _params()).size()).is_equal(size)

func test_every_cell_carries_a_terrain() -> void:
	var grid := TerrainGen.generate(SEED, SIZE, _params())
	for cell in _cells(grid):
		assert_object(grid.terrain_at(cell)) \
			.override_failure_message("terrain null en %s" % cell) \
			.is_not_null()

## Rien ne doit sortir de l'amplitude déclarée, quelle que soit la technique : les règles qui
## penchent le bruit s'ajoutent AVANT le découpage en crans, donc elles ne peuvent pas le
## déborder.
func test_heights_stay_within_the_declared_bounds() -> void:
	var params := _params()
	var grid := TerrainGen.generate(SEED, SIZE, params)
	for cell in _cells(grid):
		var height := grid.height_at(cell)
		assert_int(height) \
			.override_failure_message("hauteur %d hors structure en %s" % [height, cell]) \
			.is_between(params.water_level, params.max_height)

# --- les promesses ---------------------------------------------------------

func test_a_generated_map_keeps_every_promise() -> void:
	var params := _params()
	var grid := TerrainGen.generate(SEED, SIZE, params)
	var report := MapAudit.inspect(grid.to_query(), TerrainGen.centre_of(SIZE),
		params.max_climb)
	assert_array(MapAudit.shortcomings(report, params)).is_empty()

## Le rejet du seed, joué pour de vrai. La promesse est serrée **d'après ce que le premier
## essai rend**, donc le cas ne peut pas se périmer sur un chiffre écrit à la main : il
## fabrique son propre échec, puis vérifie que la carte rendue n'est pas celui-là.
func test_a_draft_that_breaks_a_promise_is_rejected_for_the_next() -> void:
	var params := _params()
	var centre := TerrainGen.centre_of(SIZE)
	var first := TerrainGen.draft(TerrainGen.seed_for(SEED, 0), SIZE, params)
	var refused := MapAudit.inspect(first.to_query(), centre, params.max_climb)
	params.min_plateau_deposits = refused.deposits() + 1
	assert_array(MapAudit.shortcomings(refused, params)) \
		.override_failure_message("le premier essai devait manquer sa promesse") \
		.is_not_empty()

	var kept := TerrainGen.generate(SEED, SIZE, params)
	assert_bool(_grids_match(kept, first)) \
		.override_failure_message("generate() a rendu l'essai qu'il devait rejeter") \
		.is_false()
	assert_array(MapAudit.shortcomings(
		MapAudit.inspect(kept.to_query(), centre, params.max_climb), params)).is_empty()

# --- la décoration ---------------------------------------------------------

## Une nappe est plate, et rien n'est immergé sans être de l'eau.
func test_water_sits_exactly_at_the_water_level() -> void:
	var params := _params()
	var grid := TerrainGen.draft(SEED, SIZE, params)
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

func test_zero_forest_density_places_no_forest() -> void:
	var params := _params()
	params.forest_density = 0.0
	assert_int(_count(TerrainGen.draft(SEED, SIZE, params), params.forest)).is_equal(0)

func test_zero_stone_density_places_no_stone() -> void:
	var params := _params()
	params.stone_density = 0.0
	assert_int(_count(TerrainGen.draft(SEED, SIZE, params), params.stone)).is_equal(0)

func test_zero_rock_density_places_no_rock() -> void:
	var params := _params()
	params.rock_density = 0.0
	assert_int(_count(TerrainGen.draft(SEED, SIZE, params), params.rock)).is_equal(0)

## Densité à fond, plafond bas : la forêt doit s'arrêter net à l'altitude dite.
func test_forest_never_grows_above_its_ceiling() -> void:
	var params := _params()
	params.forest_density = 1.0
	params.stone_density = 0.0
	params.rock_density = 0.0
	params.forest_max_height = 2
	var grid := TerrainGen.draft(SEED, SIZE, params)
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
	var low_grid := TerrainGen.draft(SEED, SIZE, low)
	var high_grid := TerrainGen.draft(SEED, SIZE, high)
	for cell in _cells(low_grid):
		var low_is_stone := low_grid.terrain_at(cell) == low.stone
		var high_is_stone := high_grid.terrain_at(cell) == high.stone
		assert_bool(low_is_stone) \
			.override_failure_message("gisement décalé en %s" % cell) \
			.is_equal(high_is_stone)

# --- le montage -------------------------------------------------------------

func _params() -> TerrainGenBalance:
	var params := TerrainGenBalance.new()
	params.map_size = SIZE
	params.shape = TerrainGenBalance.Shape.CLEARING
	params.min_height = 0
	params.max_height = 6
	params.water_level = 1
	params.max_climb = 1
	params.detail_share = 0.35
	params.detail_scale = 3.0
	params.dome_rise = 1.6
	params.dome_radius = 12
	params.clearing_radius = 7
	params.clearing_flatten = 0.55
	params.clearing_calm = 0.3
	params.noise_frequency = 0.1
	params.noise_octaves = 3
	params.forest_density = 0.3
	params.stone_density = 0.1
	params.rock_density = 0.05
	params.forest_max_height = 4
	params.min_plateau_cells = 1
	params.min_accesses = 2
	params.max_accesses = 3
	params.min_build_pads = 0
	params.min_plateau_deposits = 0
	# Large : plusieurs cas resserrent une promesse exprès pour voir le rejet jouer, et un
	# plafond court les ferait échouer sur le plafond plutôt que sur ce qu'ils mesurent.
	params.max_attempts = 64
	params.plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED,
		TerrainData.Walk.ALLOWED)
	params.forest = _make_terrain(&"forest", TerrainData.Build.ALLOWED,
		TerrainData.Walk.ALLOWED, &"forest")
	params.stone = _make_terrain(&"stone", TerrainData.Build.ALLOWED,
		TerrainData.Walk.ALLOWED, &"stone")
	params.water = _make_terrain(&"water", TerrainData.Build.BLOCKED,
		TerrainData.Walk.BLOCKED, &"water")
	params.rock = _make_terrain(&"rock", TerrainData.Build.BLOCKED,
		TerrainData.Walk.BLOCKED, &"blocker")
	return params

func _make_terrain(id: StringName, build: TerrainData.Build, walk: TerrainData.Walk,
		tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.walk = walk
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
