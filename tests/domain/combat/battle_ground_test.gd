class_name BattleGroundTest
extends GdUnitTestSuite
## Où la vague entre, et où les défenseurs se postent.
##
## `DESIGN.md` 3.6 : « Le champ de bataille est le village, entier. La contrepartie est que
## **la vague entre à la lisière du bâti et non au bord de la carte** — seize cases de
## marche avant le premier contact seraient quatre tours où personne ne décide rien. »
## Cette suite vérifie cette phrase, et rien d'autre.
##
## **Village de travail** sur un relief 12×12 plat en plaine : trois cabanes 1×1 en
## `(5, 5)`, `(6, 5)` et `(5, 6)`, la dernière **en chantier**. La lisière est donc
## `Rect2i(5, 5, 2, 2)`, et le centre du bâti tombe en `6` sur les deux axes.
##
## La marge d'entrée vaut 3 : la vague arrive à trois cases de la lisière.

const HUT := Vector2i(5, 5)
const SHED := Vector2i(6, 5)
const SITE := Vector2i(5, 6)

const EXTENT := Vector2i(12, 12)
const MARGIN := 3
const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const WEST := Vector2i(-1, 0)
const EAST := Vector2i(1, 0)

var _grid: HeightGrid
var _board: CombatBoard

func before_test() -> void:
	_grid = _make_grid()
	_board = _open()

# --- la lisière ------------------------------------------------------------------------

## Le rectangle englobant tout ce qui est bâti.
func test_the_built_area_encloses_everything_raised() -> void:
	assert_that(BattleGround.built_area(_board.city())).is_equal(Rect2i(5, 5, 2, 2))

## **Chantiers compris.** Ils occupent leurs cellules depuis `C4` et ils se font casser ;
## faire entrer la vague à la lisière du seul bâti fini la ferait apparaître au milieu des
## travaux. Le cas le prouve en retirant la seule cabane achevée qui tienne la ligne du bas.
func test_the_built_area_counts_building_sites() -> void:
	var alone := CitySnapshot.create([_placed(SITE, false)] as Array[BuildingSnapshot])
	assert_that(BattleGround.built_area(alone)).is_equal(Rect2i(SITE, Vector2i.ONE))

# --- par où la vague entre -------------------------------------------------------------

## À trois cases de la lisière, du centre du bâti vers les bords.
##
## Le cas épingle **les deux** décisions d'un coup : la marge, et l'ordre centre-sortant qui
## fait qu'une vague arrive groupée plutôt qu'étalée sur toute la largeur de la carte.
func test_a_wave_enters_at_the_margin_and_clusters() -> void:
	assert_array(BattleGround.entry_cells(_board, NORTH, 3)) \
		.contains_exactly([Vector2i(6, 2), Vector2i(5, 2), Vector2i(7, 2)])

## Les quatre côtés, et chacun de son côté. Sans ce cas, une erreur de signe ferait entrer
## la vague **dans** le village, ce que rien d'autre ne dirait.
func test_each_side_enters_from_its_own_side() -> void:
	assert_vector(BattleGround.entry_cells(_board, NORTH, 1)[0]).is_equal(Vector2i(6, 2))
	assert_vector(BattleGround.entry_cells(_board, SOUTH, 1)[0]).is_equal(Vector2i(6, 9))
	assert_vector(BattleGround.entry_cells(_board, WEST, 1)[0]).is_equal(Vector2i(2, 6))
	assert_vector(BattleGround.entry_cells(_board, EAST, 1)[0]).is_equal(Vector2i(9, 6))

## Une ligne d'entrée noyée repousse la recherche d'une case, et pas d'avantage. La vague
## arrive donc au plus près de ce que le terrain permet, ce qui est ce que la marge veut
## dire — un minimum, pas une distance exacte.
func test_a_drowned_line_pushes_the_entry_one_step_out() -> void:
	for column in EXTENT.x:
		_grid.set_terrain(Vector2i(column, 2), _make_water())
	assert_vector(BattleGround.entry_cells(_open(), NORTH, 1)[0]).is_equal(Vector2i(6, 1))

## Aucune case rendue n'est une case où l'on ne peut pas se tenir.
func test_no_entry_cell_is_one_a_body_could_not_stand_on() -> void:
	_grid.set_terrain(Vector2i(6, 2), _make_water())
	var board := _open()
	for cell in BattleGround.entry_cells(board, NORTH, 4):
		assert_bool(board.can_stand(cell)) \
			.override_failure_message("%s n'est pas tenable" % cell).is_true()

## **Rendre moins que demandé est une réponse et non un échec.** Un village adossé au bord
## nord n'offre aucune place à une vague qui viendrait du nord : il n'y a pas de carte
## au-delà. C'est à l'appelant de dire ce qu'il en fait, et `F2b` le dira.
##
## Le cas d'abord écrit ici prenait une carte **étroite**, et il était faux : une bande de
## deux cases de large offre autant d'entrées qu'on veut dès qu'on s'éloigne. C'est la
## profondeur qui manque à un village acculé, jamais la largeur.
func test_a_cramped_side_returns_what_it_can() -> void:
	var placed: Array[BuildingSnapshot] = [_placed(Vector2i(5, 0))]
	var edged := CombatBoard.open(_grid.to_query(), CitySnapshot.create(placed),
		_make_balance(), _make_rng())
	assert_array(BattleGround.entry_cells(edged, NORTH, 5)).is_empty()

## Zéro assaillant, zéro case. Le cas existe parce qu'une vague vide est légitime — un
## calendrier sans vague est le run paisible de `DESIGN.md` 2.
func test_an_empty_wave_asks_for_no_ground() -> void:
	assert_array(BattleGround.entry_cells(_board, NORTH, 0)).is_empty()

# --- où les défenseurs se postent ------------------------------------------------------

## Les défenseurs se postent **entre le village et la vague**, jamais dans les murs.
func test_defenders_land_on_ground_they_can_hold() -> void:
	for cell in BattleGround.landing_cells(_board, NORTH, 3):
		assert_bool(_board.can_stand(cell)) \
			.override_failure_message("%s n'est pas tenable" % cell).is_true()

## **Et jamais là où la vague arrive.** Les deux jeux de cases ne se recoupent pas, sans
## quoi le premier assaillant posé trouverait la place prise et la mise en place échouerait
## sur un `assert` au lieu de se voir.
func test_landing_and_entry_never_collide() -> void:
	var landing := BattleGround.landing_cells(_board, NORTH, 6)
	for cell in BattleGround.entry_cells(_board, NORTH, 6):
		assert_bool(landing.has(cell)) \
			.override_failure_message("%s sert des deux côtés" % cell).is_false()

## Ils se postent **plus près** du village que la vague. C'est ce qui donne son sens au mot
## « défendre » : le cas compare les deux distances plutôt que de figer des cases, donc il
## survit à un changement de marge.
func test_defenders_stand_closer_than_the_wave() -> void:
	var area := BattleGround.built_area(_board.city())
	var landing := BattleGround.landing_cells(_board, NORTH, 1)[0]
	var entry := BattleGround.entry_cells(_board, NORTH, 1)[0]
	assert_int(area.position.y - landing.y).is_less(area.position.y - entry.y)

# --- fabrique --------------------------------------------------------------------------

func _open() -> CombatBoard:
	return CombatBoard.open(_grid.to_query(), _make_city(), _make_balance(), _make_rng())

func _make_city() -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		_placed(HUT), _placed(SHED), _placed(SITE, false)]
	return CitySnapshot.create(placed)

func _placed(anchor: Vector2i, complete := true) -> BuildingSnapshot:
	var data := BuildingData.new()
	data.id = &"hut"
	data.hit_points = 6
	data.build_actions = 2
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return BuildingSnapshot.create(data, anchor, 0, 0, data.build_actions if complete else 0)

func _make_grid() -> HeightGrid:
	return HeightGrid.create(EXTENT, 0, _make_plain())

func _make_plain() -> TerrainData:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	return plain

func _make_water() -> TerrainData:
	var water := TerrainData.new()
	water.id = &"water"
	water.build = TerrainData.Build.BLOCKED
	water.tags.append(&"water")
	return water

func _make_balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.climb_cost = 1
	balance.impassable_tags = [&"water"] as Array[StringName]
	balance.spawn_margin = MARGIN
	return balance

func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4413
	return rng
