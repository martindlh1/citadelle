class_name AdjacencyTest
extends GdUnitTestSuite
## Ce que le voisinage rapporte, sur des cartes **posées à la main**.
##
## C'est la consigne de `CLAUDE.md` pour tout ce qui marche sur une grille, et elle vaut ici
## pour une raison de plus : le chiffre que ce fichier vérifie est celui qu'une fiche promet
## sous le curseur *avant* que le bâtiment existe. Le tester sur une carte générée reviendrait
## à vérifier une promesse contre un terrain que personne n'a lu.
##
## Le montage de base est une plaine nue de 12 x 12 sans un seul tag : chaque cas pose les
## cases qui l'intéressent et sait donc ce que l'audit **devrait** répondre avant de le lui
## demander.

const SIZE := Vector2i(12, 12)
const ANCHOR := Vector2i(5, 5)

var _plain: TerrainData
var _forest: TerrainData
var _water: TerrainData
var _grid: HeightGrid

func before_test() -> void:
	_plain = _terrain(&"plain")
	_forest = _terrain(&"forest", &"forest")
	_water = _terrain(&"water", &"water")
	_grid = HeightGrid.create(SIZE, 0, _plain)

# --- ce que la zone couvre --------------------------------------------------

## **Le cas qui porte la décision du jalon.** Une case taggée sous l'empreinte compte : bâtir
## une carrière *sur* le gisement est le geste qu'un joueur essaie en premier, et le terrain
## n'est pas consommé par la pose.
func test_a_tagged_cell_under_the_footprint_counts() -> void:
	_grid.set_terrain(ANCHOR, _forest)
	assert_int(_inspect(_hut()).cells(0)) \
		.override_failure_message("la case sous la cabane ne compte pas") \
		.is_equal(1)

## Le rayon se mesure en anneaux, donc une diagonale est à un pas. En quatre voisins ce cas
## rendrait zéro, et une cabane posée dans un coin de bosquet ne verrait rien.
func test_a_diagonal_neighbour_is_one_ring_away() -> void:
	_grid.set_terrain(ANCHOR + Vector2i(1, 1), _forest)
	assert_int(_inspect(_hut()).cells(0)).is_equal(1)

func test_a_cell_beyond_the_radius_does_not_count() -> void:
	_grid.set_terrain(ANCHOR + Vector2i(2, 0), _forest)
	assert_int(_inspect(_hut()).cells(0)).is_equal(0)

## La distance se prend à la case la plus proche de l'**empreinte**, pas à l'ancre : sur un
## bâtiment de deux cases, l'autre bout voit aussi loin que l'ancre.
func test_the_far_end_of_a_footprint_sees_as_far_as_the_anchor() -> void:
	_grid.set_terrain(ANCHOR + Vector2i(2, 0), _forest)
	assert_int(_inspect(_gallery()).cells(0)) \
		.override_failure_message("la seconde case de l'empreinte ne regarde pas autour d'elle") \
		.is_equal(1)

## Une zone qui déborde de la carte ne compte rien et ne casse rien : c'est le cas normal d'un
## fantôme promené jusqu'au bord.
func test_a_zone_that_overruns_the_map_counts_nothing_extra() -> void:
	var corner := Vector2i(0, 0)
	_grid.set_terrain(corner, _forest)
	assert_int(Adjacency.inspect(_hut(), corner, 0, _grid.to_query()).cells(0)).is_equal(1)

## L'orientation déplace la zone, parce qu'elle déplace l'empreinte. Sans ça, un bâtiment
## pivoté promettrait le bonus de son orientation d'origine.
func test_turning_the_building_moves_the_zone() -> void:
	_grid.set_terrain(ANCHOR + Vector2i(2, 0), _forest)
	# La prémisse : à plat, l'empreinte s'étend en x et la case est à portée. Sans ce relevé,
	# un montage où elle ne compterait jamais rendrait « 0 après rotation » en le prouvant pas.
	assert_int(_inspect(_gallery()).cells(0)) \
		.override_failure_message("la case n'est pas à portée à plat : le cas ne prouve rien") \
		.is_equal(1)
	var turned := Adjacency.inspect(_gallery(), ANCHOR, 1, _grid.to_query())
	assert_int(turned.cells(0)) \
		.override_failure_message("l'empreinte pivotée regarde toujours vers l'est") \
		.is_equal(0)

# --- ce que ça rapporte -----------------------------------------------------

func test_each_cell_pays_what_the_rule_says() -> void:
	for cell in [ANCHOR, ANCHOR + Vector2i(1, 0)]:
		_grid.set_terrain(cell, _forest)
	var report := _inspect(_hut())
	assert_int(report.cells(0)).is_equal(2)
	assert_int(report.award(0)).is_equal(2)
	assert_dict(report.total()).is_equal({&"wood": 2} as Dictionary[StringName, int])

## **Le plafond, joué pour de vrai.** Une cabane au milieu d'un bosquet a ses huit voisines
## boisées : sans plafond elle rendrait huit fois le bonus, et le placement cesserait d'être un
## choix pour devenir un gros lot.
func test_the_cap_holds_against_a_full_grove() -> void:
	for y in range(ANCHOR.y - 1, ANCHOR.y + 2):
		for x in range(ANCHOR.x - 1, ANCHOR.x + 2):
			_grid.set_terrain(Vector2i(x, y), _forest)
	var report := _inspect(_hut())
	assert_int(report.cells(0)) \
		.override_failure_message("le bosquet ne remplit pas la zone : le plafond ne prouve rien") \
		.is_equal(9)
	assert_int(report.award(0)).is_equal(_hut().adjacency[0].at_most)
	assert_bool(report.is_capped(0)).is_true()

func test_a_rule_that_finds_nothing_pays_nothing() -> void:
	var report := _inspect(_hut())
	assert_int(report.cells(0)).is_equal(0)
	assert_int(report.award(0)).is_equal(0)
	assert_bool(report.is_capped(0)).is_false()

## Les lignes creuses restent au rapport, et c'est la moitié de son intérêt : « 0 forêt » sous
## un curseur dit pourquoi cet emplacement-ci ne vaut rien. C'est `total()` qui les écarte.
func test_an_empty_rule_stays_in_the_report_and_out_of_the_total() -> void:
	var report := _inspect(_hut())
	assert_int(report.count()).is_equal(1)
	assert_bool(report.is_empty()) \
		.override_failure_message("une règle qui ne trouve rien n'est pas une absence de règle") \
		.is_false()
	assert_dict(report.total()).is_empty()

## Deux règles qui versent la même ressource s'additionnent, **chacune sous son plafond**. Un
## plafond commun aurait demandé un sixième nombre.
func test_two_rules_on_one_resource_add_up_under_their_own_caps() -> void:
	for y in range(ANCHOR.y - 1, ANCHOR.y + 2):
		for x in range(ANCHOR.x - 1, ANCHOR.x + 2):
			_grid.set_terrain(Vector2i(x, y), _forest)
	_grid.set_terrain(ANCHOR + Vector2i(1, 1), _water)
	var data := _hut()
	data.adjacency.append(_rule(&"water", 1, &"wood", 3, 3))
	var report := Adjacency.inspect(data, ANCHOR, 0, _grid.to_query())
	assert_int(report.award(0)).is_equal(2)
	assert_int(report.award(1)).is_equal(3)
	assert_dict(report.total()).is_equal({&"wood": 5} as Dictionary[StringName, int])

# --- le bâtiment sans règle -------------------------------------------------

func test_a_building_without_rules_reports_nothing_at_all() -> void:
	_grid.set_terrain(ANCHOR, _forest)
	var report := Adjacency.inspect(_bare(), ANCHOR, 0, _grid.to_query())
	assert_bool(report.is_empty()).is_true()
	assert_int(report.count()).is_equal(0)
	assert_dict(report.total()).is_empty()

## Le raccourci du résolveur rend exactement ce que le rapport totalise. Deux chemins vers le
## même chiffre sont deux occasions de diverger, et celui qui ment est celui qu'on regarde le
## moins.
func test_the_shortcut_agrees_with_the_report() -> void:
	_grid.set_terrain(ANCHOR, _forest)
	var query := _grid.to_query()
	assert_dict(Adjacency.bonus(_hut(), ANCHOR, 0, query)) \
		.is_equal(Adjacency.inspect(_hut(), ANCHOR, 0, query).total())

# --- le montage -------------------------------------------------------------

func _inspect(data: BuildingData) -> AdjacencyReport:
	return Adjacency.inspect(data, ANCHOR, 0, _grid.to_query())

## Une cabane d'une case : +1 bois par forêt à 1 anneau, au plus 2.
func _hut() -> BuildingData:
	var data := _bare()
	data.adjacency = [_rule(&"forest", 1, &"wood", 1, 2)] as Array[AdjacencyRule]
	return data

## Une galerie de deux cases en x, même règle. Elle sert aux cas de portée et de rotation :
## une empreinte carrée ne dirait rien de l'une ni de l'autre.
func _gallery() -> BuildingData:
	var data := _hut()
	data.footprint = [Vector2i.ZERO, Vector2i(1, 0)] as Array[Vector2i]
	return data

func _bare() -> BuildingData:
	var data := BuildingData.new()
	data.id = &"hut"
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = 1
	return data

func _rule(tag: StringName, radius: int, resource: StringName, per_cell: int,
		at_most: int) -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	rule.tag = tag
	rule.radius = radius
	rule.resource = resource
	rule.per_cell = per_cell
	rule.at_most = at_most
	return rule

func _terrain(id: StringName, tag: StringName = &"") -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	data.walk = TerrainData.Walk.ALLOWED
	if not tag.is_empty():
		data.tags.append(tag)
	return data
