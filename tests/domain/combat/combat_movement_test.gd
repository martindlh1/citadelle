class_name CombatMovementTest
extends GdUnitTestSuite
## Où un corps peut aller, et ce que le relief lui coûte pour y aller.
##
## `DESIGN.md` 3.6 : « Le relief joue, et c'est la première chose qui l'emploie autrement
## que comme contrainte de pose. Monter coûte, une marche trop haute bloque. » Cette suite
## vérifie les deux moitiés de cette phrase, plus ce que les obstacles en font.
##
## **Terrain de travail**, 7×7, plaine à hauteur 0, sauf :
##   - `(4, 3)` à hauteur **1** — une marche que tout le monde franchit ;
##   - `(5, 3)` à hauteur **3** — une falaise, deux crans au-dessus de sa voisine ;
##   - `(2, 3)` en **eau** — infranchissable ;
##   - `(2, 2)` en **rocher** — infranchissable.
##
## Un corps de référence part de `(3, 3)` avec 3 points, une marche de 1, et un cran de
## montée qui coûte 1. Ces chiffres sont ceux de la suite et non ceux de `data/` : ils sont
## choisis pour que chaque seuil tombe sur un cas qu'on peut lire à la main.

const START := Vector2i(3, 3)
const STEP_UP := Vector2i(4, 3)
const CLIFF := Vector2i(5, 3)
const WATER := Vector2i(2, 3)
const ROCK := Vector2i(2, 2)

const EXTENT := Vector2i(7, 7)
const MOVE := 3
const CLIMB := 1
const CLIMB_COST := 1

var _grid: HeightGrid
var _terrain: TerrainQuery
var _balance: CombatBalance

func before_test() -> void:
	_grid = _make_grid()
	_terrain = _grid.to_query()
	_balance = _make_balance()

# --- la case de départ, et le plat -----------------------------------------------------

## La case de départ est atteignable à zéro. Ce n'est pas un artefact : « rester sur
## place » est un déplacement légal, et l'écran qui allume les cases atteignables doit
## pouvoir montrer celle qu'on quitte.
func test_the_starting_cell_costs_nothing() -> void:
	assert_int(_reach()[START]).is_equal(0)

## À plat, le coût est la distance en pas orthogonaux, et rien d'autre.
func test_flat_ground_costs_one_per_step() -> void:
	assert_int(_reach()[START + Vector2i(0, 1)]).is_equal(1)
	assert_int(_reach()[START + Vector2i(0, 3)]).is_equal(3)
	assert_int(_reach()[START + Vector2i(1, 2)]).is_equal(3)

## Ce qui est au-delà des points ne figure pas. La borne est sur le **coût**, pas sur la
## distance : c'est la même règle qui rend une montée plus courte qu'un plat.
func test_what_lies_beyond_the_points_is_absent() -> void:
	assert_bool(_reach().has(START + Vector2i(0, 4))).is_false()

## La diagonale coûte deux pas, puisque le déplacement est orthogonal. Le cas l'épingle
## parce que c'est la moitié du choix de métrique — l'autre moitié est la portée, et les
## deux doivent rester d'accord.
func test_a_diagonal_costs_two_steps() -> void:
	assert_int(_reach()[START + Vector2i(1, 1)]).is_equal(2)

# --- le relief -------------------------------------------------------------------------

## Monter coûte le pas **plus** le cran. C'est la première moitié de `DESIGN.md` 3.6.
func test_climbing_costs_the_step_and_the_rise() -> void:
	assert_int(_reach()[STEP_UP]).is_equal(1 + CLIMB_COST)

## **Descendre ne coûte que le pas.** L'asymétrie est délibérée et se discute : elle fait
## d'une hauteur une position qu'on tient — longue à gagner, facile à quitter — plutôt
## qu'un mur qui enferme aussi celui qui est dessus.
func test_going_down_costs_only_the_step() -> void:
	assert_int(_step_cost(STEP_UP, Vector2i(4, 2))).is_equal(1)

## Une marche trop haute bloque, ce qui est la seconde moitié de la phrase. Deux crans
## au-dessus d'un corps qui en franchit un : il n'y a pas de prix, il n'y a pas de passage.
func test_too_high_a_step_blocks() -> void:
	assert_int(_step_cost(STEP_UP, CLIFF)).is_equal(CombatMovement.BLOCKED)

## Et la falaise reste absente de tout ce qu'on peut atteindre, quel que soit le chemin :
## elle est à trois crans du plat, donc chacune de ses voisines est trop basse pour elle.
func test_a_cliff_is_reachable_from_nowhere() -> void:
	assert_bool(_reach(9).has(CLIFF)).is_false()

## **Un corps qui ne grimpe pas ne monte pas d'un seul cran.** C'est ce qui fait d'un
## plateau une forteresse pour qui n'a pas les jambes, et c'est réglable par corps.
func test_a_body_that_cannot_climb_stays_on_the_flat() -> void:
	assert_bool(_reach(MOVE, 0).has(STEP_UP)).is_false()

## À `climb_cost` nul, monter ne coûte que le pas — mais la marche trop haute bloque
## toujours. Les deux moitiés de la règle sont bien indépendantes, et un équilibrage qui
## annule l'une garde l'autre.
func test_a_free_climb_still_obeys_the_step_limit() -> void:
	_balance.climb_cost = 0
	assert_int(_reach()[STEP_UP]).is_equal(1)
	assert_int(_step_cost(STEP_UP, CLIFF)).is_equal(CombatMovement.BLOCKED)

# --- ce qui barre ----------------------------------------------------------------------

## L'eau et le rocher ne se traversent pas, et les tags viennent de `data/balance/` : le
## domaine n'écrit jamais `&"water"`.
func test_impassable_terrain_is_never_entered() -> void:
	assert_bool(_reach().has(WATER)).is_false()
	assert_bool(_reach().has(ROCK)).is_false()

## Un équilibrage qui ne barre rien laisse marcher partout. Le cas prouve que la liste est
## bien la seule source de cette règle — sans quoi un terrain resterait barré par du code.
func test_nothing_is_impassable_without_the_tags() -> void:
	_balance.impassable_tags = [] as Array[StringName]
	assert_bool(_reach().has(WATER)).is_true()

## Un corps barre sa case comme un mur. C'est ce qui rend le blocage de passage une
## tactique plutôt qu'un effet de bord.
func test_an_occupied_cell_is_never_entered() -> void:
	var here := START + Vector2i(0, 1)
	var barred: Dictionary[Vector2i, bool] = {}
	barred[here] = true
	assert_bool(_reach(MOVE, CLIMB, barred).has(here)).is_false()

## **Un obstacle ne se traverse pas, il se contourne, et ça coûte.** Le cas qui porte le
## fichier : `(1, 3)` est à deux pas en ligne droite, l'eau et le rocher en font quatre.
## Sans lui, un parcours qui ignorerait les obstacles passerait tous les cas ci-dessus.
func test_an_obstacle_is_walked_around_at_a_price() -> void:
	var far := Vector2i(1, 3)
	assert_int(absi(far.x - START.x) + absi(far.y - START.y)).is_equal(2)
	assert_int(_reach(9)[far]).is_equal(4)

## Hors carte n'est jamais atteignable, et n'a pas besoin d'être barré pour ça.
func test_the_map_edge_holds() -> void:
	var corner := CombatMovement.reachable(_terrain, {}, Vector2i.ZERO, _stats(9, CLIMB),
		_balance)
	assert_bool(corner.has(Vector2i(-1, 0))).is_false()
	assert_bool(corner.has(Vector2i(0, -1))).is_false()

## Une case barrée n'est pas franchissable non plus pour y **passer** : le corps enfermé
## par quatre obstacles ne va nulle part, et rend quand même sa propre case.
func test_a_body_boxed_in_still_reports_its_own_cell() -> void:
	var barred: Dictionary[Vector2i, bool] = {}
	for step in CombatMovement.NEIGHBOURS:
		barred[START + step] = true
	var within := _reach(MOVE, CLIMB, barred)
	assert_int(within.size()).is_equal(1)
	assert_int(within[START]).is_equal(0)

# --- déterminisme ----------------------------------------------------------------------

## Deux explorations identiques rendent les mêmes cases **dans le même ordre**. L'ordre
## n'a aucune conséquence sur le coût rendu ; il en a une sur ce que `F2b` en tirera, où
## deux cibles également proches se départageront par lui.
func test_two_identical_walks_explore_in_the_same_order() -> void:
	assert_array(_reach(9).keys()).is_equal(_reach(9).keys())

# --- fabrique --------------------------------------------------------------------------

func _reach(move := MOVE, climb := CLIMB,
		barred: Dictionary[Vector2i, bool] = {}) -> Dictionary[Vector2i, int]:
	return CombatMovement.reachable(_terrain, barred, START, _stats(move, climb), _balance)

func _step_cost(from: Vector2i, to: Vector2i) -> int:
	return CombatMovement.step_cost(_terrain, from, to, _stats(MOVE, CLIMB), _balance)

func _stats(move: int, climb: int) -> CombatStats:
	return CombatStats.create(10, 2, 4, CombatStats.CONTACT, move, climb)

func _make_grid() -> HeightGrid:
	var grid := HeightGrid.create(EXTENT, 0, _make_terrain(&"plain"))
	grid.set_height(STEP_UP, 1)
	grid.set_height(CLIFF, 3)
	grid.set_terrain(WATER, _make_terrain(&"water", &"water"))
	grid.set_terrain(ROCK, _make_terrain(&"rock", &"blocker"))
	return grid

func _make_terrain(id: StringName, tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	if not tag.is_empty():
		data.tags.append(tag)
	return data

func _make_balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.climb_cost = CLIMB_COST
	balance.impassable_tags = [&"water", &"blocker"] as Array[StringName]
	balance.spawn_margin = 3
	return balance
