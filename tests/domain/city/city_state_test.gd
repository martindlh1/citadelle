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

## PV de tous les bâtiments de travail de ce fichier. Un seul chiffre : les cas de dégâts
## parlent de la porte, jamais de l'équilibrage.
const HIT_POINTS := 5

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

## La ville range les cellules PIVOTÉES, et le bâtiment se souvient de son orientation.
## Les deux index, eux, ne voient que des cellules et ignorent qu'une rotation existe.
func test_a_rotated_building_occupies_its_rotated_cells() -> void:
	_city.place(_terrain, _ell(), Vector2i(2, 2), 1)
	var building := _city.building_at(Vector2i(2, 2))
	assert_int(building.turns()).is_equal(1)
	assert_array(building.cells()) \
		.contains_exactly([Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 2)])
	assert_bool(_city.is_occupied(Vector2i(1, 2))).is_true()
	# Et la cellule que l'empreinte NON pivotée aurait prise reste libre.
	assert_bool(_city.is_occupied(Vector2i(3, 2))).is_false()

## Un retrait libère l'empreinte pivotée, pas celle d'origine.
func test_removing_a_rotated_building_frees_its_rotated_cells() -> void:
	_city.place(_terrain, _ell(), Vector2i(2, 2), 1)
	_city.remove(Vector2i(2, 2))
	assert_int(_city.count()).is_equal(0)
	for cell in [Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 2)]:
		assert_bool(_city.is_occupied(cell)).is_false()

## Les crans sont repliés dans un tour : la ville ne garde pas un compteur qui monte.
func test_turns_are_folded_into_a_single_circle() -> void:
	_city.place(_terrain, _ell(), Vector2i(2, 2), 5)
	assert_int(_city.building_at(Vector2i(2, 2)).turns()).is_equal(1)

func test_a_placed_building_keeps_its_anchor_and_footprint() -> void:
	_city.place(_terrain, _ell(), Vector2i(1, 1))
	var building := _city.building_at(Vector2i(1, 1))
	assert_vector(building.anchor()).is_equal(Vector2i(1, 1))
	assert_str(building.data().id).is_equal(&"ell")
	assert_array(building.cells()) \
		.contains_exactly([Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])

## La hauteur est enregistrée à la pose : c'est le y auquel C2 dessinera la boîte,
## sans avoir à réinterroger la grille.
##
## Les deux poses sont voisines parce que la seconde doit tomber dans l'emprise de la
## première *(C7)* : c'est le sujet d'un autre fichier, mais toute ville montée à la main s'y
## plie désormais.
func test_a_placed_building_records_the_ground_height() -> void:
	var low := Vector2i(RAISED_X - 2, 0)
	_city.place(_terrain, _hut(), low)
	_city.place(_terrain, _hut(), Vector2i(RAISED_X, 0))
	assert_int(_city.building_at(low).height()).is_equal(0)
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

## L'instantané est la seule sortie de la ville vers l'Économie et le Combat. Il rend
## les mêmes bâtiments, dans le même ordre, pour la même raison que buildings().
func test_a_snapshot_mirrors_the_city_in_placement_order() -> void:
	_city.place(_terrain, _building(&"first", _single()), Vector2i(3, 3))
	_city.place(_terrain, _building(&"second", _single()), Vector2i(0, 0))
	var ids: Array[StringName] = []
	for building in _city.to_snapshot().buildings():
		ids.append(building.data().id)
	assert_array(ids).contains_exactly([&"first", &"second"])

func test_an_empty_city_gives_an_empty_snapshot() -> void:
	assert_int(_city.to_snapshot().count()).is_equal(0)

## L'ancre est la clé par laquelle une affectation désigne un bâtiment : sans cet
## index, le résolveur balaierait la ville une fois par ouvrier.
func test_a_snapshot_finds_a_building_by_its_anchor() -> void:
	_city.place(_terrain, _hut(), Vector2i(2, 2))
	var snapshot := _city.to_snapshot()
	assert_bool(snapshot.has_anchor(Vector2i(2, 2))).is_true()
	assert_str(snapshot.at_anchor(Vector2i(2, 2)).data().id).is_equal(&"hut")

## Null plutôt qu'une erreur : une affectation peut désigner une ancre dont le
## bâtiment vient d'être détruit, et le résolveur sait traiter « rien ici ».
func test_an_unknown_anchor_gives_null_rather_than_an_error() -> void:
	assert_object(_city.to_snapshot().at_anchor(Vector2i(9, 9))).is_null()

## La hauteur voyage avec l'instantané plutôt que d'être relue sur le terrain : c'est
## le bénéfice direct de la règle qui exige une empreinte plate.
func test_a_snapshot_carries_the_ground_height() -> void:
	_city.place(_terrain, _hut(), Vector2i(RAISED_X, 1))
	assert_int(_city.to_snapshot().at_anchor(Vector2i(RAISED_X, 1)).height()) \
		.is_equal(RAISED_HEIGHT)

## L'orientation traverse aussi, et les cellules en sortent déjà pivotées : rien en
## aval n'a à savoir qu'une rotation est en jeu.
func test_a_snapshot_carries_the_orientation_and_its_rotated_cells() -> void:
	var anchor := Vector2i(1, 1)
	_city.place(_terrain, _ell(), anchor, 1)
	var building := _city.to_snapshot().at_anchor(anchor)
	assert_int(building.turns()).is_equal(1)
	assert_array(building.cells()).contains_exactly(_ell().cells_at(anchor, 1))

## Une vue figée l'est vraiment. Sans quoi l'Économie lirait une ville qui bouge sous
## elle pendant qu'elle résout.
func test_a_snapshot_does_not_follow_later_changes() -> void:
	_city.place(_terrain, _hut(), Vector2i(2, 2))
	var snapshot := _city.to_snapshot()
	_city.remove(Vector2i(2, 2))
	_city.place(_terrain, _hut(), Vector2i(0, 5))
	assert_int(snapshot.count()).is_equal(1)
	assert_bool(snapshot.has_anchor(Vector2i(2, 2))).is_true()

# --- Chantiers (C4) ---

## Poser une carte de bâtiment ouvre un CHANTIER, pas un bâtiment. Il occupe déjà ses
## cellules — il les a payées — et ne fait rien d'autre. DESIGN.md 3.2.
func test_placing_a_building_opens_a_site_rather_than_a_building() -> void:
	_city.place(_terrain, _site(&"farm", 2), Vector2i(1, 1))
	var placed := _city.building_at(Vector2i(1, 1))
	assert_int(placed.progress()).is_equal(0)
	assert_int(placed.remaining()).is_equal(2)
	assert_bool(placed.is_complete()).is_false()
	assert_bool(_city.is_occupied(Vector2i(1, 1))).is_true()

## Le cas du Cœur : rien à bâtir, donc fini à la pose. C'est ce zéro qui lui évite un
## chemin de pose particulier.
func test_a_building_with_no_site_cost_is_finished_on_placement() -> void:
	_city.place(_terrain, _hut(), Vector2i(1, 1))
	assert_bool(_city.building_at(Vector2i(1, 1)).is_complete()).is_true()
	assert_int(_city.building_at(Vector2i(1, 1)).remaining()).is_equal(0)

func test_advancing_a_site_posts_one_notch() -> void:
	_city.place(_terrain, _site(&"farm", 2), Vector2i(1, 1))
	assert_bool(_city.advance(Vector2i(1, 1))).is_true()
	assert_int(_city.building_at(Vector2i(1, 1)).progress()).is_equal(1)
	assert_bool(_city.building_at(Vector2i(1, 1)).is_complete()).is_false()

func test_enough_notches_finish_the_site() -> void:
	_city.place(_terrain, _site(&"farm", 2), Vector2i(1, 1))
	_city.advance(Vector2i(1, 1))
	_city.advance(Vector2i(1, 1))
	assert_bool(_city.building_at(Vector2i(1, 1)).is_complete()).is_true()
	assert_int(_city.building_at(Vector2i(1, 1)).remaining()).is_equal(0)

## Un chantier fini n'absorbe pas un cran de plus en silence : il refuse, et
## remaining() ne part jamais dans le négatif. Le refus est rendu pour que l'appelant
## sache que sa carte n'a servi à rien.
func test_a_finished_site_refuses_further_notches() -> void:
	_city.place(_terrain, _site(&"farm", 1), Vector2i(1, 1))
	assert_bool(_city.advance(Vector2i(1, 1))).is_true()
	assert_bool(_city.advance(Vector2i(1, 1))).is_false()
	assert_int(_city.building_at(Vector2i(1, 1)).progress()).is_equal(1)
	assert_int(_city.building_at(Vector2i(1, 1)).remaining()).is_equal(0)

## Le chemin d'une action jouée au clic : on tient une cellule quelconque de
## l'empreinte, advance() veut l'ancre. Miroir exact de la démolition.
func test_a_covered_cell_leads_back_to_the_site_through_its_anchor() -> void:
	_city.place(_terrain, _site(&"keep", 2, _quad()), Vector2i(1, 1))
	_city.advance(_city.anchor_at(Vector2i(2, 2)))
	assert_int(_city.building_at(Vector2i(2, 2)).progress()).is_equal(1)

## L'avancement traverse l'instantané : c'est la ligne que DESIGN.md 8 demande
## nommément — « CitySnapshot qui le porte ».
func test_a_snapshot_carries_the_site_progress() -> void:
	_city.place(_terrain, _site(&"farm", 3), Vector2i(1, 1))
	_city.advance(Vector2i(1, 1))
	var building := _city.to_snapshot().at_anchor(Vector2i(1, 1))
	assert_int(building.progress()).is_equal(1)
	assert_int(building.remaining()).is_equal(2)
	assert_bool(building.is_complete()).is_false()

## Jumeau du cas de la destruction : une vue figée ne suit pas non plus les crans posés
## après elle. Sans lui, l'Économie pourrait résoudre sur un chantier qui s'achève
## pendant qu'elle compte.
func test_a_snapshot_does_not_follow_later_progress() -> void:
	_city.place(_terrain, _site(&"farm", 2), Vector2i(1, 1))
	var snapshot := _city.to_snapshot()
	_city.advance(Vector2i(1, 1))
	_city.advance(Vector2i(1, 1))
	assert_int(snapshot.at_anchor(Vector2i(1, 1)).progress()).is_equal(0)
	assert_bool(snapshot.at_anchor(Vector2i(1, 1)).is_complete()).is_false()

## Le partage des rôles entre les deux lectures de l'instantané, et c'est lui qui évite
## trois clauses recopiées chez trois consommateurs : buildings() rend tout, parce que
## le Combat doit voir les chantiers ; completed() ne rend que les finis, parce que
## l'Économie doit les ignorer.
func test_a_snapshot_separates_every_building_from_the_finished_ones() -> void:
	_city.place(_terrain, _site(&"done", 1), Vector2i(0, 0))
	# Le premier s'achève **avant** que le second s'ouvre, et pas après : un chantier n'étend
	# pas l'emprise *(C7)*, donc une ville dont le seul bâtiment est en travaux n'accepte
	# aucune seconde pose. C'est l'ordre qu'une vraie partie suit de toute façon.
	_city.advance(Vector2i(0, 0))
	_city.place(_terrain, _site(&"site", 1), Vector2i(2, 0))
	var snapshot := _city.to_snapshot()
	assert_int(snapshot.buildings().size()).is_equal(2)
	var finished: Array[StringName] = []
	for building in snapshot.completed():
		finished.append(building.data().id)
	assert_array(finished).contains_exactly([&"done"])

## Un chantier se détruit comme un bâtiment, et il ne laisse rien derrière lui. Ce que
## ça RENDRAIT au joueur reste OUVERT en DESIGN.md 3.2 ; ce que ça libère, non.
func test_removing_a_site_frees_its_cells_like_any_building() -> void:
	_city.place(_terrain, _site(&"keep", 3, _quad()), Vector2i(1, 1))
	_city.advance(Vector2i(1, 1))
	_city.remove(Vector2i(1, 1))
	assert_int(_city.count()).is_equal(0)
	assert_bool(_city.is_occupied(Vector2i(2, 2))).is_false()

# --- dégâts ---------------------------------------------------------------------------

## Un bâtiment frappé sans tomber reste en place, et son compte de points le suit.
func test_a_building_that_survives_a_blow_stays_up() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 0))
	assert_bool(_city.damage(Vector2i(0, 0), HIT_POINTS - 1)).is_false()
	assert_int(_city.count()).is_equal(1)
	assert_int(_city.building_at(Vector2i(0, 0)).hit_points_left()).is_equal(1)

## Deux coups s'accumulent. Sans quoi un bâtiment se soignerait entre deux vagues, ce que
## rien dans DESIGN.md ne propose et qui rendrait la seconde vague indolore.
func test_blows_add_up() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 0))
	_city.damage(Vector2i(0, 0), 2)
	_city.damage(Vector2i(0, 0), 2)
	assert_int(_city.building_at(Vector2i(0, 0)).damage()).is_equal(4)

## **Le cas qui porte la porte.** Un bâtiment tombé est retiré dans le même geste : le
## laisser debout dans les deux index le ferait occuper ses cellules et relever encore la
## réserve. C'est ce qui distingue damage() d'advance(), qui n'a rien à tenir.
func test_a_building_that_falls_leaves_the_city() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	assert_bool(_city.damage(Vector2i(1, 1), HIT_POINTS)).is_true()
	assert_int(_city.count()).is_equal(0)
	assert_bool(_city.has_anchor(Vector2i(1, 1))).is_false()

## Et il libère **toutes** ses cellules, pas seulement son ancre. Une empreinte de quatre
## cases dont trois resteraient occupées interdirait de rebâtir sur ses ruines.
func test_a_fallen_building_frees_its_whole_footprint() -> void:
	_city.place(_terrain, _keep(), Vector2i(1, 1))
	_city.damage(Vector2i(1, 1), HIT_POINTS)
	assert_bool(_city.is_occupied(Vector2i(2, 2))).is_false()

## Un coup plus fort que ce qu'il restait ne creuse pas sous zéro : le bâtiment tombe, et
## le compte de points reste lisible.
func test_an_overwhelming_blow_does_not_dig_below_zero() -> void:
	var hut := _hut()
	_city.place(_terrain, hut, Vector2i(0, 0))
	assert_bool(_city.damage(Vector2i(0, 0), HIT_POINTS * 10)).is_true()
	assert_int(_city.count()).is_equal(0)

## Un chantier encaisse comme le reste, et tombe comme le reste. C'est la perte que
## DESIGN.md 3.2 veut qu'on puisse raconter ; qui la raconte est le DamageReport.
func test_a_site_takes_blows_like_any_building() -> void:
	_city.place(_terrain, _site(&"site", 3), Vector2i(0, 0))
	assert_bool(_city.damage(Vector2i(0, 0), HIT_POINTS)).is_true()
	assert_int(_city.count()).is_equal(0)

## Les dégâts traversent l'instantané, sans quoi le Combat frapperait toujours des murs
## neufs et une seconde vague ne finirait jamais ce que la première avait entamé.
func test_a_snapshot_carries_the_damage() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 0))
	_city.damage(Vector2i(0, 0), 2)
	var snapshot := _city.to_snapshot()
	assert_int(snapshot.at_anchor(Vector2i(0, 0)).damage()).is_equal(2)
	assert_int(snapshot.at_anchor(Vector2i(0, 0)).hit_points_left()) \
		.is_equal(HIT_POINTS - 2)

## Et il ne suit pas les coups d'après, comme il ne suit pas les crans d'après.
func test_a_snapshot_does_not_follow_later_damage() -> void:
	_city.place(_terrain, _hut(), Vector2i(0, 0))
	var snapshot := _city.to_snapshot()
	_city.damage(Vector2i(0, 0), 2)
	assert_int(snapshot.at_anchor(Vector2i(0, 0)).damage()).is_equal(0)

func _single() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	return offsets

func _hut() -> BuildingData:
	return _building(&"hut", _single())

func _quad() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	return offsets

func _keep() -> BuildingData:
	return _building(&"keep", _quad())

## Un bâtiment qui réclame un chantier. Les bâtiments de travail de ce fichier n'en
## réclament aucun — ils sont finis à la pose, ce qui laisse les cas de rangement parler
## de rangement.
func _site(id: StringName, actions: int,
		offsets: Array[Vector2i] = _single()) -> BuildingData:
	var building := _building(id, offsets)
	building.site_turns = actions
	return building

## Un L, dont l'enveloppe couvre une cellule qu'il n'occupe pas : (1, 1).
func _ell() -> BuildingData:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	return _building(&"ell", offsets)

func _building(id: StringName, offsets: Array[Vector2i]) -> BuildingData:
	var building := BuildingData.new()
	building.id = id
	building.footprint = offsets
	building.hit_points = HIT_POINTS
	# Une emprise large, pour que la règle de C7 ne se mette pas en travers des cas qui
	# parlent d'autre chose. Trois et non un : à un anneau, un bâtiment de deux par deux posé
	# contre son voisin avait déjà un coin dehors, et trois cas de ce fichier se sont mis à
	# mesurer l'emprise au lieu de leur sujet. Un `reach` laissé à zéro, lui, n'ouvrirait même
	# pas la case voisine — c'est ce que ces deux fichiers ont trouvé le jour du jalon.
	building.reach = 3
	return building

func _make_terrain(id: StringName, build: TerrainData.Build) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	return data
