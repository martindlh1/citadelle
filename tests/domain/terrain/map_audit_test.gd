class_name MapAuditTest
extends GdUnitTestSuite
## L'audit d'une carte, sur des cartes **fabriquées à la main**.
##
## C'est la consigne de `CLAUDE.md` pour tout ce qui marche sur une grille, et elle vaut ici
## plus qu'ailleurs : l'audit existe pour vérifier la génération, donc le tester sur des
## cartes générées reviendrait à demander à chacun des deux de confirmer l'autre. Toutes les
## mesas de ce fichier sont posées à la main, en quelques lignes, et l'on sait donc ce que
## l'audit **devrait** répondre avant de le lui demander.
##
## Le montage de base, en hauteurs, pour une carte de 9 x 9 et une enjambée de 1 :
##
##     1 1 1 1 1 1 1 1 1        La plaine est à 1, le plateau à 3 : deux crans, donc
##     1 1 1 1 1 1 1 1 1        hors d'enjambée. Sans rampe, personne ne monte.
##     1 1 3 3 3 3 3 1 1
##     1 1 3 3 3 3 3 1 1        Une rampe est une case à 2 posée contre le plateau :
##     1 1 3 3 3 3 3 1 1        on y monte depuis la plaine, et de là sur le plateau.
##     1 1 3 3 3 3 3 1 1
##     1 1 3 3 3 3 3 1 1
##     1 1 1 1 1 1 1 1 1
##     1 1 1 1 1 1 1 1 1

const SIZE := Vector2i(9, 9)
const LOWLAND := 1
const PLATEAU := 3
const CLIMB := 1
const CENTRE := Vector2i(4, 4)

## Le plateau, en cellules : le carré [2, 6] dans les deux axes.
const SHELF_SIDE := 5

var _plain: TerrainData
var _stone: TerrainData
var _water: TerrainData
var _rock: TerrainData
var _grid: HeightGrid

func before_test() -> void:
	_plain = _terrain(&"plain", TerrainData.Build.ALLOWED, TerrainData.Walk.ALLOWED)
	_stone = _terrain(&"stone", TerrainData.Build.ALLOWED, TerrainData.Walk.ALLOWED,
		&"stone")
	_water = _terrain(&"water", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED,
		&"water")
	_rock = _terrain(&"rock", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED,
		&"blocker")
	_grid = HeightGrid.create(SIZE, LOWLAND, _plain)
	for y in range(2, 2 + SHELF_SIDE):
		for x in range(2, 2 + SHELF_SIDE):
			_grid.set_height(Vector2i(x, y), PLATEAU)

# --- le plateau -------------------------------------------------------------

func test_the_shelf_is_everything_at_the_centre_height() -> void:
	var report := _inspect()
	assert_int(report.shelf()).is_equal(SHELF_SIDE * SHELF_SIDE)
	assert_int(report.plateau()).is_equal(SHELF_SIDE * SHELF_SIDE)

## Un rocher retire une case à bâtir et **n'ampute pas le replat** : on le contourne. Couper
## le plateau en deux pour un caillou aurait rejeté des cartes correctes.
func test_a_rock_costs_a_buildable_cell_and_not_the_shelf() -> void:
	_grid.set_terrain(Vector2i(4, 3), _rock)
	var report := _inspect()
	assert_int(report.shelf()).is_equal(SHELF_SIDE * SHELF_SIDE)
	assert_int(report.plateau()).is_equal(SHELF_SIDE * SHELF_SIDE - 1)

func test_deposits_are_counted_on_the_plateau_only() -> void:
	_grid.set_terrain(Vector2i(3, 3), _stone)
	_grid.set_terrain(Vector2i(0, 0), _stone)
	assert_int(_inspect().deposits()).is_equal(1)

# --- le site ----------------------------------------------------------------

## **Le cas qui porte la règle du jalon.** Un centre qui dépasse d'un cran est un replat d'une
## seule case : fonder là revenait à noter la carte sur un pixel, et c'est très exactement ce
## que le bruit en crêtes produit au milieu d'une carte sur deux. Le village descend donc d'une
## case et s'installe sur le replat d'à côté.
func test_the_village_steps_off_a_peak_to_the_shelf_beside_it() -> void:
	_grid.set_height(CENTRE, PLATEAU + 1)
	# La prémisse : le milieu est bien un pic. Sans ce relevé, un montage raté rendrait le
	# même « le village n'est pas au centre » en prouvant autre chose.
	var peak := _inspect()
	assert_int(peak.shelf()) 		.override_failure_message("le milieu n'est pas un pic : le cas ne prouve rien") 		.is_equal(1)
	assert_vector(peak.site()).is_equal(CENTRE)

	var report := _inspect(2)
	assert_vector(report.site()) 		.override_failure_message("le village est resté sur le pic") 		.is_not_equal(CENTRE)
	assert_int(report.drift()).is_equal(1)
	assert_int(report.shelf()).is_equal(SHELF_SIDE * SHELF_SIDE - 1)

## **Le plus proche, et non le plus grand.** Un replat de quatre cases posé sous le milieu suffit
## tant qu'on ne demande que quatre places ; dès qu'on en demande cinq, le village descend sur
## le grand plateau. Une recherche qui aurait classé par taille serait descendue dans les deux
## cas, et aurait donné la même réponse pour une autre raison.
func test_the_nearest_shelf_wins_over_the_largest() -> void:
	for cell in [CENTRE, CENTRE + Vector2i(1, 0), CENTRE + Vector2i(0, 1),
			CENTRE + Vector2i(1, 1)]:
		_grid.set_height(cell, PLATEAU + 1)

	var small := _inspect(4)
	assert_vector(small.site()) 		.override_failure_message("quatre places suffisaient : le village n'avait pas à bouger") 		.is_equal(CENTRE)
	assert_int(small.shelf()).is_equal(4)

	var large := _inspect(5)
	assert_int(large.shelf()) 		.override_failure_message("cinq places : le village devait descendre") 		.is_equal(SHELF_SIDE * SHELF_SIDE - 4)
	assert_int(large.drift()).is_equal(1)

## Quand aucun replat n'offre la place demandée, on s'installe sur le plus grand qu'il y ait et
## le rapport dit de combien on manque. Rendre « rien » aurait obligé l'appelant à distinguer
## deux cas pour arriver à la même conclusion : ce seed ne vaut rien.
func test_an_impossible_requirement_falls_back_to_the_largest_shelf() -> void:
	var report := _inspect(999)
	assert_int(report.shelf()) 		.override_failure_message("le repli devait prendre la plaine, plus grande que le plateau") 		.is_equal(SIZE.x * SIZE.y - SHELF_SIDE * SHELF_SIDE)
	assert_array(MapAudit.shortcomings(report, _promises(1, 9, 999, 0, 0, 9))) 		.contains(["plateau"])

## Un village trop loin du milieu se nomme, comme le reste. C'est le seuil qui **mord** sur les
## réglages du jour : les trois autres promesses protègent d'une molette tournée demain.
func test_a_village_too_far_from_the_middle_is_named() -> void:
	var report := _inspect(999)
	assert_int(report.drift()) 		.override_failure_message("le repli devait éloigner le village du milieu") 		.is_equal(3)
	assert_array(MapAudit.shortcomings(report, _promises(1, 9, 1, 0, 0, 2))) 		.contains(["site_drift"])

# --- les accès --------------------------------------------------------------

## Le montage nu : deux crans d'écart, donc rien ne monte. C'est la moitié structurelle de la
## garantie de DESIGN.md 3.1, et c'est ce que toute la suite fait varier.
func test_a_mesa_without_a_ramp_has_no_access_at_all() -> void:
	var report := _inspect()
	assert_int(report.accesses()).is_equal(0)
	assert_bool(report.is_reachable()).is_false()

func test_one_ramp_gives_one_access() -> void:
	_ramp(Vector2i(4, 1))
	var report := _inspect()
	assert_int(report.accesses()).is_equal(1)
	assert_array(report.entries()).is_equal([Vector2i(4, 2)])

func test_two_ramps_on_opposite_sides_give_two_accesses() -> void:
	_ramp(Vector2i(4, 1))
	_ramp(Vector2i(4, 7))
	assert_int(_inspect().accesses()).is_equal(2)

## Deux cases d'entrée qui se touchent sont **un** col : une rampe large de deux n'ouvre pas
## deux passages.
func test_two_neighbouring_entries_are_one_access() -> void:
	_ramp(Vector2i(3, 1))
	_ramp(Vector2i(4, 1))
	assert_int(_inspect().accesses()).is_equal(1)

## **Le cas qui fixe le regroupement en huit voisins.** Deux entrées qui ne se touchent que
## par un coin restent un seul col : une tour posée là les couvre toutes les deux, et c'est
## ce que le mot veut dire pour un joueur. En quatre voisins ce cas rendrait deux, et une
## rampe qui aborde le plateau en biais compterait double.
func test_two_entries_touching_by_a_corner_are_one_access() -> void:
	# La prémisse d'abord : chacune des deux rampes ouvre bien **sa** case, et les deux cases
	# ne se touchent que par un coin. Sans ce relevé, un cas où la seconde rampe n'ouvrirait
	# rien rendrait « un accès » lui aussi, et prouverait le contraire de ce qu'il annonce.
	_ramp(Vector2i(1, 3))
	assert_array(_inspect().entries()) \
		.override_failure_message("la rampe ouest n'ouvre pas (2,3) : le cas ne prouve rien") \
		.is_equal([Vector2i(2, 3)])
	_ramp(Vector2i(3, 1))
	var report := _inspect()
	# Le représentant passe à (3,2), la première du groupe au balayage : la case n'aurait pas
	# bougé si la rampe nord n'avait rien ouvert.
	assert_array(report.entries()).is_equal([Vector2i(3, 2)])
	assert_int(report.accesses()) \
		.override_failure_message("(2,3) et (3,2) se touchent par un coin : un seul col") \
		.is_equal(1)

## Un rocher sur une rampe d'une case la ferme. C'est le premier des deux défauts que la
## décoration peut encore causer, et donc la première vraie raison de rejeter un seed.
func test_a_rock_on_the_only_ramp_closes_it() -> void:
	_ramp(Vector2i(4, 1))
	_grid.set_terrain(Vector2i(4, 1), _rock)
	assert_int(_inspect().accesses()).is_equal(0)

## Le second : une rampe intacte dont le **pied** est coupé de la lisière. Rien ne se voit
## sur la rampe elle-même, et pourtant personne n'y arrive.
func test_a_ramp_cut_off_from_the_edge_opens_nothing() -> void:
	_ramp(Vector2i(4, 1))
	for cell in [Vector2i(4, 0), Vector2i(3, 1), Vector2i(5, 1)]:
		_grid.set_cell(cell, LOWLAND, _water)
	var report := _inspect()
	assert_int(report.accesses()).is_equal(0)
	assert_bool(report.is_reachable()).is_false()

## Un marcheur entré par un col ne doit pas **ressortir** par un autre et se faire compter
## une seconde fois : le parcours du dehors s'arrête au pied du plateau.
func test_walking_across_the_plateau_does_not_invent_accesses() -> void:
	_ramp(Vector2i(4, 1))
	_ramp(Vector2i(4, 7))
	_ramp(Vector2i(1, 4))
	assert_int(_inspect().accesses()).is_equal(3)

# --- la place à bâtir et la profondeur --------------------------------------

## Les assises comptent des ancres d'empreinte 2x2, pas des cellules plates. Sur ce montage :
## 4 x 4 sur le plateau, plus ce que la plaine offre autour de lui.
func test_pads_count_where_a_two_by_two_footprint_fits() -> void:
	var report := _inspect()
	assert_int(report.pads()) \
		.override_failure_message("le montage nu doit offrir les 16 assises du plateau") \
		.is_greater_equal(16)

func test_a_rock_costs_the_pads_that_covered_it() -> void:
	var before := _inspect().pads()
	_grid.set_terrain(CENTRE, _rock)
	assert_int(_inspect().pads()).is_equal(before - 4)

## La profondeur se mesure jusqu'au **plateau**, donc un rocher posé sur la case du milieu ne
## la fait pas passer à -1 : une carte reste jouable quand le Cœur se pose une case à côté.
func test_the_depth_survives_a_rock_on_the_very_centre() -> void:
	_ramp(Vector2i(4, 1))
	_grid.set_terrain(CENTRE, _rock)
	assert_int(_inspect().edge_distance()).is_equal(2)

func test_the_depth_is_minus_one_when_nothing_reaches_the_plateau() -> void:
	assert_int(_inspect().edge_distance()).is_equal(-1)

# --- le verdict -------------------------------------------------------------

func test_a_map_that_keeps_its_promises_lacks_nothing() -> void:
	_ramp(Vector2i(4, 1))
	_ramp(Vector2i(4, 7))
	assert_array(MapAudit.shortcomings(_inspect(), _promises(2, 4, 25, 0, 0, 9))).is_empty()

func test_each_broken_promise_is_named() -> void:
	_ramp(Vector2i(4, 1))
	var missing := MapAudit.shortcomings(_inspect(), _promises(2, 4, 999, 999, 9, 9))
	assert_array(missing).contains(["plateau", "accesses_too_few", "pads", "deposits"])

func test_too_many_accesses_is_a_different_name_from_too_few() -> void:
	for foot in [Vector2i(4, 1), Vector2i(4, 7), Vector2i(1, 4)]:
		_ramp(foot)
	assert_array(MapAudit.shortcomings(_inspect(), _promises(1, 2, 1, 0, 0, 9))) \
		.contains(["accesses_too_many"])

# --- le montage -------------------------------------------------------------

## L'audit du montage courant, pour un site qui exige `need` cases à bâtir.
##
## Une case par défaut, parce que la plupart des cas de ce fichier parlent d'autre chose que
## du site : une exigence forte les ferait tous porter sur la recherche plutôt que sur leur
## sujet, et un montage dont le milieu est bâtissable rend alors le milieu.
func _inspect(need := 1) -> MapReport:
	return MapAudit.inspect(_grid.to_query(), CENTRE, CLIMB, need)

## Pose une case de rampe : une marche à mi-hauteur, contre le plateau.
func _ramp(cell: Vector2i) -> void:
	_grid.set_cell(cell, PLATEAU - CLIMB, _plain)

func _promises(low: int, high: int, cells: int, pads: int, deposits: int,
		drift: int) -> TerrainGenBalance:
	var params := TerrainGenBalance.new()
	params.min_accesses = low
	params.max_accesses = high
	params.min_plateau_cells = cells
	params.min_build_pads = pads
	params.min_plateau_deposits = deposits
	params.max_site_drift = drift
	return params

func _terrain(id: StringName, build: TerrainData.Build, walk: TerrainData.Walk,
		tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.walk = walk
	if not tag.is_empty():
		data.tags.append(tag)
	return data
