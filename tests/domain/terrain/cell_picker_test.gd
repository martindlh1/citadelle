class_name CellPickerTest
extends GdUnitTestSuite
## La marche DDA : quelle cellule un rayon rencontre-t-il ?
##
## C'est le premier code du projet qui met vraiment à l'épreuve les deux conventions
## figées à T2 — origine du monde au COIN de la carte, face supérieure d'une cellule
## à h * step_height. La moitié des cas ci-dessous ne testent qu'elles.
##
## Les dimensions sont volontairement bancales, 2.0 et 0.25 et jamais 1.0 : à
## tile_size 1 un picker qui oublierait un de ses deux facteurs passerait vert.
##
## Les terrains sont construits en code plutôt que chargés depuis data/ : ces cas ne
## doivent pas casser à la prochaine passe d'équilibrage.

const TILE := 2.0
const STEP := 0.25
const SIZE := Vector2i(4, 3)
const EPSILON := 0.0001

## Hauteur de la colonne haute des cas d'occlusion. Son sommet est à 2.0.
const TALL := 8

var _metrics: TerrainMetrics
var _plain: TerrainData
var _water: TerrainData

func before_test() -> void:
	_metrics = TerrainMetrics.create(TILE, STEP)
	_plain = _make_terrain(&"plain", TerrainData.Build.ALLOWED)
	_water = _make_terrain(&"water", TerrainData.Build.BLOCKED)

# --- Le cas nominal : un tir vertical -----------------------------------------

## Le tir qui compte : celui que fait une caméra pointée vers le bas.
func test_a_ray_straight_down_hits_the_cell_under_it() -> void:
	var grid := HeightGrid.create(SIZE, 2, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, 10.0, 5.0), Vector3.DOWN)
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(1, 2))
	assert_int(result.height()).is_equal(2)

## L'invariant de T2 : le point d'impact atterrit sur la face supérieure, et son y
## vaut EXACTEMENT h * step_height. L'égalité est stricte à dessein — c'est la valeur
## sur laquelle un bâtiment se posera, elle n'a pas à traîner d'ulp de flottant.
func test_the_impact_lands_exactly_on_the_top_face() -> void:
	var grid := HeightGrid.create(SIZE, 2, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, 10.0, 5.0), Vector3.DOWN)
	assert_float(result.position().y).is_equal(2 * STEP)
	assert_vector(result.position()) \
		.is_equal_approx(Vector3(3.0, 0.5, 5.0), Vector3.ONE * EPSILON)

## Un tir pile sur une arête prend la cellule du dessus, comme cell_at() : les deux
## découpages doivent raconter la même histoire, sans quoi le survol sauterait d'une
## cellule au moment de la pose.
func test_a_ray_on_an_exact_edge_takes_the_upper_cell() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(4.0, 10.0, 5.0), Vector3.DOWN)
	assert_vector(result.cell()).is_equal(Vector2i(2, 2))
	assert_vector(result.cell()).is_equal(_metrics.cell_at(Vector3(4.0, 0.0, 5.0)))

## Une carte peut descendre sous le niveau 0 : min_height accepte des négatifs.
func test_a_negative_height_is_picked_where_it_really_is() -> void:
	var grid := HeightGrid.create(SIZE, -3, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, 10.0, 5.0), Vector3.DOWN)
	assert_int(result.height()).is_equal(-3)
	assert_float(result.position().y).is_equal(-3 * STEP)

## Le picker désigne, il ne juge pas. L'eau est inconstructible, elle reste survolable
## — c'est Construction qui refusera d'y bâtir, à C2.
func test_an_unbuildable_cell_is_picked_all_the_same() -> void:
	var grid := HeightGrid.create(SIZE, 1, _plain)
	grid.set_terrain(Vector2i(1, 2), _water)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, 10.0, 5.0), Vector3.DOWN)
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(1, 2))

# --- Les tirs qui ne touchent rien --------------------------------------------

func test_a_ray_pointing_away_from_the_map_misses() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, 5.0, 5.0), Vector3.UP)
	assert_bool(result.is_hit()).is_false()

## Le curseur pointé à côté de la carte : le rayon passe au large en Z.
func test_a_ray_beside_the_footprint_misses() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var result := CellPicker.pick(grid, _metrics,
		Vector3(-1.0, 1.0, 20.0), Vector3(1.0, 0.0, 0.0))
	assert_bool(result.is_hit()).is_false()

## La carte est bien traversée par la DROITE du rayon, mais entièrement derrière son
## origine. Sans le contrôle de signe, le point d'entrée négatif serait ramené dans la
## grille par le clamp et rendrait une cellule inventée.
func test_a_map_entirely_behind_the_ray_misses() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var result := CellPicker.pick(grid, _metrics,
		Vector3(12.0, 1.0, 3.0), Vector3(1.0, 0.0, 0.0))
	assert_bool(result.is_hit()).is_false()

## Un rayon qui survole toute la carte sans jamais descendre en ressort par l'autre
## bord. Ce cas-là mène la marche jusqu'à la sortie de l'emprise.
func test_a_ray_skimming_over_every_column_misses() -> void:
	var grid := _grid_with_tall_column(Vector2i(2, 1))
	var result := CellPicker.pick(grid, _metrics,
		Vector3(-1.0, 3.0, 3.0), Vector3(1.0, 0.0, 0.0))
	assert_bool(result.is_hit()).is_false()

# --- Occlusion : ce qui est devant gagne --------------------------------------

## Le cas qui justifie la marche plutôt qu'une simple projection : une colonne haute
## masque ce qui est derrière elle. Même rayon sur deux cartes, deux réponses.
func test_a_tall_column_hides_what_is_behind_it() -> void:
	var origin := Vector3(-1.0, 3.0, 3.0)
	var direction := Vector3(2.0, -1.0, 0.0)

	var flat := HeightGrid.create(SIZE, 0, _plain)
	var far := CellPicker.pick(flat, _metrics, origin, direction)
	assert_vector(far.cell()).is_equal(Vector2i(2, 1))

	var blocked := _grid_with_tall_column(Vector2i(1, 1))
	var near := CellPicker.pick(blocked, _metrics, origin, direction)
	assert_vector(near.cell()).is_equal(Vector2i(1, 1))
	assert_int(near.height()).is_equal(TALL)

## Le flanc est touché là où le rayon FRANCHIT l'arête de la cellule, pas plus loin :
## une colonne commence à son bord, pas à son centre.
func test_a_side_hit_lands_on_the_cell_edge() -> void:
	var grid := _grid_with_tall_column(Vector2i(2, 1))
	var result := CellPicker.pick(grid, _metrics,
		Vector3(-1.0, 1.0, 3.0), Vector3(1.0, 0.0, 0.0))
	assert_vector(result.cell()).is_equal(Vector2i(2, 1))
	# La cellule (2, 1) commence à x = 2 * TILE, et le rayon garde son altitude.
	assert_vector(result.position()) \
		.is_equal_approx(Vector3(4.0, 1.0, 3.0), Vector3.ONE * EPSILON)

# --- Les axes dégénérés -------------------------------------------------------

## Rayon parallèle à Z : dir.z vaut zéro, et la période de franchissement sur cet axe
## part à l'infini. Rien ne doit y diviser par zéro ni rendre NaN.
func test_a_ray_with_no_z_component_still_walks() -> void:
	var grid := _grid_with_tall_column(Vector2i(2, 1))
	var result := CellPicker.pick(grid, _metrics,
		Vector3(-1.0, 1.0, 3.0), Vector3(1.0, 0.0, 0.0))
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(2, 1))

## Le symétrique sur l'autre axe, parce qu'une marche peut très bien n'en traiter
## correctement qu'un des deux.
func test_a_ray_with_no_x_component_still_walks() -> void:
	var grid := _grid_with_tall_column(Vector2i(1, 2))
	var result := CellPicker.pick(grid, _metrics,
		Vector3(3.0, 1.0, -1.0), Vector3(0.0, 0.0, 1.0))
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(1, 2))
	assert_vector(result.position()) \
		.is_equal_approx(Vector3(3.0, 1.0, 4.0), Vector3.ONE * EPSILON)

## Une colonne est une boîte FERMÉE : un tir parti de sous la carte rencontre son
## dessous, à l'altitude du socle, et non l'intérieur de la première colonne venue.
func test_a_ray_from_under_the_map_hits_its_base() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var result := CellPicker.pick(grid, _metrics, Vector3(3.0, -5.0, 5.0), Vector3.UP)
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(1, 2))
	assert_float(result.position().y).is_equal(_metrics.base_y(0))

# --- Sous le bord de la carte -------------------------------------------------

## La régression qui a motivé le fond des colonnes.
##
## Un rayon visant SOUS le bord proche de la carte y entrait par en dessous et
## accrochait la première rangée qu'il croisait : le survol collait à la bande du bas,
## alors qu'il sortait bien de la carte par les bords du haut, où le rayon passe
## au-dessus de tout. Le tir part ici du ras du socle, hors emprise, et descend : il ne
## doit plus rien rencontrer.
func test_a_ray_passing_under_the_map_misses() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var direction := _isometric_direction()
	# Hors de l'emprise en x comme en z, exactement au niveau du socle. Tout ce qui
	# suit sur ce rayon est plus bas encore.
	var under := Vector3(9.0, _metrics.base_y(0), 7.0)
	var result := CellPicker.pick(grid, _metrics, under - direction * 20.0, direction)
	assert_bool(result.is_hit()).is_false()

## Le pendant, qui empêche la correction d'aller trop loin : le flanc du socle reste
## désignable. La rangée du bord se survole encore, et sur sa vraie cellule.
func test_the_skirt_of_the_near_edge_is_still_pickable() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var direction := _isometric_direction()
	# Sur la face du socle du bord +X, à mi-hauteur entre le socle et la surface.
	var flank := Vector3(SIZE.x * TILE, _metrics.base_y(0) * 0.5, 3.0)
	var result := CellPicker.pick(grid, _metrics, flank - direction * 20.0, direction)
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(SIZE.x - 1, 1))

# --- La géométrie réelle du rig -----------------------------------------------

## Le vrai vecteur de la caméra du jeu, reconstruit par la même composition d'Euler
## que CameraRig : piqué de l'isométrique vrai, lacet à 45°, ordre YXZ. C'est ce tir-là
## que le curseur enverra, et lui seul prouve que les conventions tiennent bout à bout.
func test_the_real_isometric_ray_hits_the_cell_it_points_at() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var target := Vector3(3.0, 0.0, 5.0)
	var direction := _isometric_direction()
	assert_float(direction.y).is_less(0.0)
	var result := CellPicker.pick(grid, _metrics, target - direction * 20.0, direction)
	assert_vector(result.cell()).is_equal(Vector2i(1, 2))
	assert_vector(result.position()).is_equal_approx(target, Vector3.ONE * EPSILON)

# --- La métrique n'est pas décorative -----------------------------------------

## Le même tir sur la même grille, à deux tailles de cellule : la cellule désignée
## change. Un picker qui aurait figé tile_size à 1 passerait tous les cas ci-dessus.
##
## Le point est choisi dans l'emprise des DEUX métriques : diviser tile_size par deux
## divise aussi l'emprise au sol de la carte, et un tir plus loin que 4 x 3 unités
## manquerait la petite — un miss correct, mais qui ne prouverait rien ici.
func test_the_tile_size_changes_which_cell_is_picked() -> void:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	var origin := Vector3(3.0, 10.0, 2.5)
	var wide := CellPicker.pick(grid, _metrics, origin, Vector3.DOWN)
	var tight := CellPicker.pick(grid, TerrainMetrics.create(1.0, STEP), origin, Vector3.DOWN)
	assert_vector(wide.cell()).is_equal(Vector2i(1, 1))
	assert_vector(tight.cell()).is_equal(Vector2i(3, 2))

## Et le cran de relief déplace l'impact d'autant.
func test_the_step_height_moves_the_impact() -> void:
	var grid := HeightGrid.create(SIZE, 4, _plain)
	var origin := Vector3(3.0, 10.0, 5.0)
	var shallow := CellPicker.pick(grid, _metrics, origin, Vector3.DOWN)
	var steep := CellPicker.pick(grid, TerrainMetrics.create(TILE, 1.0), origin, Vector3.DOWN)
	assert_float(shallow.position().y).is_equal(4 * STEP)
	assert_float(steep.position().y).is_equal(4.0)

## Deux tirs identiques rendent le même résultat : rien ne traîne d'un appel à l'autre.
func test_two_identical_shots_agree() -> void:
	var grid := _grid_with_tall_column(Vector2i(1, 1))
	var origin := Vector3(-1.0, 3.0, 3.0)
	var direction := Vector3(2.0, -1.0, 0.0)
	var first := CellPicker.pick(grid, _metrics, origin, direction)
	var second := CellPicker.pick(grid, _metrics, origin, direction)
	assert_vector(first.cell()).is_equal(second.cell())
	assert_vector(first.position()).is_equal_approx(second.position(), Vector3.ONE * EPSILON)

# --- Le résultat lui-même -----------------------------------------------------

func test_a_miss_carries_nothing() -> void:
	assert_bool(PickResult.miss().is_hit()).is_false()

func test_a_hit_carries_what_it_was_given() -> void:
	var result := PickResult.hit_at(Vector2i(2, 7), 3, Vector3(1.0, 2.0, 3.0))
	assert_bool(result.is_hit()).is_true()
	assert_vector(result.cell()).is_equal(Vector2i(2, 7))
	assert_int(result.height()).is_equal(3)
	assert_vector(result.position()) \
		.is_equal_approx(Vector3(1.0, 2.0, 3.0), Vector3.ONE * EPSILON)

# --- Fixtures -----------------------------------------------------------------

## Grille plate au niveau 0, avec une seule colonne haute dont le sommet est à 2.0.
func _grid_with_tall_column(cell: Vector2i) -> HeightGrid:
	var grid := HeightGrid.create(SIZE, 0, _plain)
	grid.set_height(cell, TALL)
	return grid

## La direction dans laquelle regarde CameraRig, reconstruite sans Node : le rig porte
## ISO_PITCH_DEGREES en x et ISO_YAW_DEGREES en y, dans l'ordre YXZ, et la caméra
## regarde vers -basis.z.
func _isometric_direction() -> Vector3:
	var orientation := Basis.from_euler(Vector3(
		deg_to_rad(CameraRig.ISO_PITCH_DEGREES),
		deg_to_rad(CameraRig.ISO_YAW_DEGREES),
		0.0), EULER_ORDER_YXZ)
	return -orientation.z

func _make_terrain(id: StringName, build: TerrainData.Build) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.color = Color(0.5, 0.5, 0.5)
	return data
