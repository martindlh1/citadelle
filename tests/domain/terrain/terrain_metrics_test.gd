class_name TerrainMetricsTest
extends GdUnitTestSuite
## Le passage grille <-> monde.
##
## Les dimensions sont choisies volontairement bancales — 2.0 et 0.25, jamais 1.0 —
## pour qu'une métrique qui ignorerait un de ses deux facteurs se voie. À tile_size 1
## la moitié des bugs d'échelle passent inaperçus.

const TILE := 2.0
const STEP := 0.25
const EPSILON := 0.0001

var _metrics: TerrainMetrics

func before_test() -> void:
	_metrics = TerrainMetrics.create(TILE, STEP)

func test_create_keeps_its_dimensions() -> void:
	assert_float(_metrics.tile_size()).is_equal_approx(TILE, EPSILON)
	assert_float(_metrics.step_height()).is_equal_approx(STEP, EPSILON)

## Deux métriques différentes coexistent : rien n'est caché en statique.
func test_two_metrics_do_not_share_state() -> void:
	var other := TerrainMetrics.create(1.0, 1.0)
	assert_float(_metrics.tile_size()).is_equal_approx(TILE, EPSILON)
	assert_float(other.tile_size()).is_equal_approx(1.0, EPSILON)

func test_from_balance_reads_both_fields() -> void:
	var balance := TerrainBalance.new()
	balance.tile_size = TILE
	balance.step_height = STEP
	var metrics := TerrainMetrics.from_balance(balance)
	assert_float(metrics.tile_size()).is_equal_approx(TILE, EPSILON)
	assert_float(metrics.step_height()).is_equal_approx(STEP, EPSILON)

## L'invariant du système : la face du dessus est à h * step_height.
func test_surface_y_is_the_height_in_steps() -> void:
	assert_float(_metrics.surface_y(0)).is_equal_approx(0.0, EPSILON)
	assert_float(_metrics.surface_y(4)).is_equal_approx(4.0 * STEP, EPSILON)

## Une carte peut descendre sous le niveau 0 : min_height accepte des négatifs.
func test_surface_y_goes_below_zero() -> void:
	assert_float(_metrics.surface_y(-3)).is_equal_approx(-3.0 * STEP, EPSILON)

## L'origine du monde est au coin de la carte, pas à son centre.
func test_the_first_cell_starts_at_the_origin() -> void:
	assert_vector(_metrics.cell_center_xz(Vector2i.ZERO)) \
		.is_equal_approx(Vector3(TILE * 0.5, 0.0, TILE * 0.5), Vector3.ONE * EPSILON)

## Grille +y va vers monde +Z, et pas vers -Z ni vers X.
func test_grid_y_maps_to_world_z() -> void:
	var center := _metrics.cell_center_xz(Vector2i(3, 5))
	assert_float(center.x).is_equal_approx(3.5 * TILE, EPSILON)
	assert_float(center.z).is_equal_approx(5.5 * TILE, EPSILON)

func test_cell_surface_center_stacks_the_two_conventions() -> void:
	assert_vector(_metrics.cell_surface_center(Vector2i(1, 2), 4)) \
		.is_equal_approx(Vector3(1.5 * TILE, 4.0 * STEP, 2.5 * TILE), Vector3.ONE * EPSILON)

## L'aller-retour est exact sur toute une grille, pas seulement à l'origine.
func test_cell_at_round_trips_every_centre() -> void:
	for y in 6:
		for x in 6:
			var cell := Vector2i(x, y)
			assert_vector(_metrics.cell_at(_metrics.cell_center_xz(cell))) \
				.is_equal(cell)

## La hauteur du point n'entre pas dans le calcul : cell_at projette sur XZ.
func test_cell_at_ignores_the_y_of_the_point() -> void:
	var high := Vector3(3.0, 42.0, 5.0)
	var low := Vector3(3.0, -42.0, 5.0)
	assert_vector(_metrics.cell_at(high)).is_equal(_metrics.cell_at(low))

## Sur une arête exacte, le point appartient à la cellule supérieure. Sans règle
## explicite, deux cellules voisines revendiqueraient le même point.
func test_a_point_on_an_edge_belongs_to_the_higher_cell() -> void:
	assert_vector(_metrics.cell_at(Vector3(TILE, 0.0, TILE))).is_equal(Vector2i(1, 1))
	assert_vector(_metrics.cell_at(Vector3(TILE - EPSILON, 0.0, TILE - EPSILON))) \
		.is_equal(Vector2i.ZERO)

## Le piège : int() tronque vers zéro, donc -0.3 / 2.0 y donnerait 0 et la cellule -1
## se confondrait avec la cellule 0. floori() découpe pour de vrai.
func test_cell_at_floors_on_the_negative_side() -> void:
	assert_vector(_metrics.cell_at(Vector3(-0.3, 0.0, -0.3))).is_equal(Vector2i(-1, -1))
	assert_vector(_metrics.cell_at(Vector3(-TILE, 0.0, -TILE))).is_equal(Vector2i(-1, -1))
	assert_vector(_metrics.cell_at(Vector3(-TILE - EPSILON, 0.0, -TILE - EPSILON))) \
		.is_equal(Vector2i(-2, -2))

func test_world_extent_scales_both_axes() -> void:
	assert_vector(_metrics.world_extent(Vector2i(16, 24))) \
		.is_equal_approx(Vector2(32.0, 48.0), Vector2.ONE * EPSILON)

func test_world_centre_is_half_the_extent_at_ground_level() -> void:
	assert_vector(_metrics.world_center(Vector2i(16, 24))) \
		.is_equal_approx(Vector3(16.0, 0.0, 24.0), Vector3.ONE * EPSILON)

## Le centre du monde tombe bien au milieu de la carte : à la jonction des quatre
## cellules centrales d'une grille paire.
func test_world_centre_lands_between_the_middle_cells() -> void:
	var size := Vector2i(4, 4)
	var center := _metrics.world_center(size)
	assert_vector(_metrics.cell_at(center)).is_equal(Vector2i(2, 2))
	assert_vector(_metrics.cell_at(center - Vector3(EPSILON, 0.0, EPSILON))) \
		.is_equal(Vector2i(1, 1))
