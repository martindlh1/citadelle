class_name BuildingDataTest
extends GdUnitTestSuite
## Le schéma d'un bâtiment : la géométrie de son empreinte, et son filet de complétude.
##
## Comme terrain_data_test.gd, aucune empreinte de data/ n'est figée ici — les tailles
## des dix bâtiments de DESIGN.md 4 bougeront à la passe de contenu. Ce qui est
## asserté, c'est la géométrie et le mécanisme qui refuse une empreinte inexploitable.
##
## Le L sert de forme de travail presque partout : sur un rectangle, cells_at() et
## bounds_at() rendraient la même chose et aucun des deux ne serait vraiment testé.

const BUILDING_ROOT := "res://data/buildings"

func test_a_blank_building_reports_all_its_required_fields() -> void:
	assert_array(BuildingData.new().missing_fields()) \
		.contains(["id", "color", "height", "footprint"])

## La sentinelle de couleur est recopiée de TerrainData, comme TerrainDecor la recopie
## déjà. Ce cas est ce qui empêche les copies de dériver les unes des autres.
func test_the_unset_colour_sentinels_agree() -> void:
	assert_bool(BuildingData.UNSET_COLOR == TerrainData.UNSET_COLOR) \
		.override_failure_message("les sentinelles ont divergé : %s contre %s"
			% [BuildingData.UNSET_COLOR, TerrainData.UNSET_COLOR]) \
		.is_true()

## Une hauteur nulle écraserait la boîte sur le sol, et Godot n'écrit pas un 0.0 dans
## un .tres : « oublié » et « à plat » y seraient indiscernables.
func test_a_zero_height_is_reported() -> void:
	var building := _building(_l_shape())
	building.height = 0.0
	assert_array(building.missing_fields()).contains(["height"])

func test_a_filled_building_reports_nothing() -> void:
	assert_array(_building(_l_shape()).missing_fields()).is_empty()

## Une empreinte absente se signale seule. Ajouter qu'il lui manque aussi son ancre
## serait du bruit sur un champ dont on sait déjà qu'il n'est pas là.
func test_an_empty_footprint_does_not_also_report_its_anchor() -> void:
	assert_array(BuildingData.new().missing_fields()).not_contains(["footprint.anchor"])

## L'ancre doit appartenir à l'empreinte : sans elle, CityState.anchor_at() renverrait
## vers une cellule que le bâtiment n'occupe pas.
func test_a_footprint_that_misses_its_anchor_is_reported() -> void:
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1)]
	assert_array(_building(offsets).missing_fields()).contains(["footprint.anchor"])

## Une cellule nommée deux fois se poserait sans erreur et ferait mentir cells().
func test_a_footprint_that_names_a_cell_twice_is_reported() -> void:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i.ZERO]
	assert_array(_building(offsets).missing_fields()).contains(["footprint.duplicate"])

## Une empreinte en deux morceaux disjoints est bizarre, mais se pose sans rien casser.
## La refuser serait une règle de contenu déguisée en règle de schéma.
func test_a_disjoint_footprint_is_accepted() -> void:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(5, 5)]
	assert_array(_building(offsets).missing_fields()).is_empty()

func test_cells_at_translates_the_footprint() -> void:
	var cells := _building(_l_shape()).cells_at(Vector2i(10, 4))
	assert_array(cells).contains_exactly([Vector2i(10, 4), Vector2i(11, 4), Vector2i(10, 5)])

## L'ordre du .tres est conservé tel quel : tout ce qui itère sur les cellules d'un
## bâtiment en dépend pour rester déterministe d'un run à l'autre.
func test_cells_at_keeps_the_footprint_order() -> void:
	var reversed: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i.ZERO]
	var cells := _building(reversed).cells_at(Vector2i.ZERO)
	assert_array(cells).contains_exactly([Vector2i(0, 1), Vector2i(1, 0), Vector2i.ZERO])

func test_a_single_cell_footprint_bounds_to_one_cell() -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	assert_that(_building(single).bounds_at(Vector2i(3, 7))).is_equal(Rect2i(3, 7, 1, 1))

## L'enveloppe d'un L couvre la quatrième cellule, que le bâtiment n'occupe pas.
## C'est exactement pourquoi elle ne sert pas à valider un placement.
func test_bounds_at_encloses_the_cell_the_l_does_not_occupy() -> void:
	assert_that(_building(_l_shape()).bounds_at(Vector2i(2, 2))).is_equal(Rect2i(2, 2, 2, 2))

## Une empreinte qui s'étend derrière son ancre : l'enveloppe doit reculer avec elle.
## Un calcul parti de l'ancre au lieu du minimum raterait ce cas.
func test_bounds_at_handles_offsets_behind_the_anchor() -> void:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1, -2)]
	assert_that(_building(offsets).bounds_at(Vector2i(5, 5))).is_equal(Rect2i(4, 3, 2, 3))

func test_neighbourhood_grows_the_bounds_on_all_four_sides() -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	assert_that(_building(single).neighbourhood_at(Vector2i(4, 4), 1)) \
		.is_equal(Rect2i(3, 3, 3, 3))

## Rayon nul : la zone est l'enveloppe elle-même. C'est ce qui rendra la fonction sûre
## à appeler sans cas particulier chez l'appelant, à C3.
func test_a_zero_radius_neighbourhood_is_the_bounds() -> void:
	var building := _building(_l_shape())
	assert_that(building.neighbourhood_at(Vector2i(2, 2), 0)) \
		.is_equal(building.bounds_at(Vector2i(2, 2)))

## Le format lui-même : une empreinte écrite dans un .tres revient bien en
## Array[Vector2i] exploitable, et data/buildings/ passerait le contrôle de boot.
##
## Ce cas est le seul à toucher data/, et il n'y fige aucune taille — seulement le
## fait qu'au moins un bâtiment existe et qu'aucun n'est inexploitable.
func test_the_buildings_of_data_are_exploitable() -> void:
	var seen: Array[String] = []
	for file in DirAccess.get_files_at(BUILDING_ROOT):
		if file.get_extension() != "tres":
			continue
		var building := load("%s/%s" % [BUILDING_ROOT, file]) as BuildingData
		assert_object(building) \
			.override_failure_message("%s n'est pas un BuildingData" % file) \
			.is_not_null()
		seen.append(file.get_basename())
		assert_array(building.missing_fields()) \
			.override_failure_message("bâtiment inexploitable dans %s" % file) \
			.is_empty()
	assert_array(seen) \
		.override_failure_message("data/buildings/ ne contient aucun bâtiment") \
		.is_not_empty()

## Un L : l'ancre, la cellule à sa droite, la cellule en dessous. Rendu neuf à chaque
## appel plutôt que gardé en constante — un tableau partagé entre cas finirait par
## être muté par l'un d'eux.
func _l_shape() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	return offsets

func _building(offsets: Array[Vector2i]) -> BuildingData:
	var building := BuildingData.new()
	building.id = &"test_hut"
	building.color = Color(0.5, 0.4, 0.3)
	building.height = 0.6
	building.footprint = offsets
	return building
