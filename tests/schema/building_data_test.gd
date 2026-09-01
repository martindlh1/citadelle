class_name BuildingDataTest
extends GdUnitTestSuite
## Le schéma d'un bâtiment : la géométrie de son empreinte, et son filet de complétude.
##
## Comme terrain_data_test.gd, aucune empreinte de data/ n'est figée ici — les tailles
## des bâtiments de DESIGN.md 4.1 bougeront à la passe de contenu. Ce qui est asserté,
## c'est la géométrie et le mécanisme qui refuse une empreinte inexploitable.
##
## Le bloc de production a son propre fichier depuis E1b. Ce qui en reste ici est la
## couture : l'absence de bloc, et le préfixe sous lequel ce qui lui manque remonte.
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

## La grille va +x à droite et +y vers le fond : un quart de tour horaire vu de dessus
## envoie donc la droite vers le fond.
func test_a_quarter_turn_sends_right_to_front() -> void:
	assert_vector(BuildingData.rotate_offset(Vector2i(1, 0), 1)).is_equal(Vector2i(0, 1))
	assert_vector(BuildingData.rotate_offset(Vector2i(0, 1), 1)).is_equal(Vector2i(-1, 0))

## L'ancre est invariante par rotation. C'est ce qui garantit qu'une empreinte pivotée
## contient toujours son ancre, sans que missing_fields() ait à le revérifier.
func test_the_anchor_is_invariant_under_rotation() -> void:
	for turns in 4:
		assert_vector(BuildingData.rotate_offset(Vector2i.ZERO, turns)).is_equal(Vector2i.ZERO)

func test_four_quarter_turns_return_to_the_start() -> void:
	var offset := Vector2i(2, -3)
	assert_vector(BuildingData.rotate_offset(offset, 4)).is_equal(offset)

## Les crans sont repliés dans [0, 3] : un appelant qui les accumule sans jamais les
## replier — comme CameraRig — n'a pas à s'en occuper.
func test_turns_beyond_a_full_circle_wrap() -> void:
	var offset := Vector2i(1, 0)
	assert_vector(BuildingData.rotate_offset(offset, 5)) \
		.is_equal(BuildingData.rotate_offset(offset, 1))
	assert_vector(BuildingData.rotate_offset(offset, -1)) \
		.is_equal(BuildingData.rotate_offset(offset, 3))

## Un L pivoté reste un L, ancré au même endroit, mais tourné.
func test_cells_at_rotates_the_footprint_around_the_anchor() -> void:
	var cells := _building(_l_shape()).cells_at(Vector2i(5, 5), 1)
	assert_array(cells).contains_exactly([Vector2i(5, 5), Vector2i(5, 6), Vector2i(4, 5)])

## Une empreinte symétrique rend les quatre orientations identiques, sans cas
## particulier à écrire nulle part.
func test_a_single_cell_is_the_same_in_every_orientation() -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	var building := _building(single)
	for turns in 4:
		assert_array(building.cells_at(Vector2i(3, 3), turns)).contains_exactly([Vector2i(3, 3)])

## L'enveloppe suit la rotation : sur un L pivoté d'un quart de tour, elle recule
## derrière l'ancre.
func test_bounds_at_follows_the_rotation() -> void:
	assert_that(_building(_l_shape()).bounds_at(Vector2i(5, 5), 1)) \
		.is_equal(Rect2i(4, 5, 2, 2))

func test_neighbourhood_follows_the_rotation() -> void:
	var building := _building(_l_shape())
	assert_that(building.neighbourhood_at(Vector2i(5, 5), 1, 1)) \
		.is_equal(building.bounds_at(Vector2i(5, 5), 1).grow(1))

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

## Le point de doctrine du bloc économie, et il porte le jalon. Un coût vide et une
## réserve nulle sont deux valeurs légitimes du tableau de DESIGN.md 4.1 — la cabane de
## bûcheron est gratuite, presque rien ne stocke. Et **l'absence de bloc de production
## en est une troisième** : l'entrepôt n'a pas zéro slot, il n'a pas de bloc. Un
## bâtiment qui ne renseigne rien de tout ça est complet.
func test_a_building_without_any_economy_block_is_complete() -> void:
	var building := _building(_l_shape())
	assert_bool(building.produces()).is_false()
	assert_array(building.missing_fields()).is_empty()

func test_a_building_with_a_coherent_block_reports_nothing() -> void:
	var building := _producer()
	assert_bool(building.produces()).is_true()
	assert_array(building.missing_fields()).is_empty()

## Ce que E1 vérifiait ici est parti dans ProductionBlock, et il n'en reste que la
## couture : ce qui manque au bloc remonte préfixé, comme TerrainData préfixe
## « decor. ». Sans le préfixe, un « yield_per_turn » nu dans le rapport de boot ne dirait
## pas d'où il vient le jour où BuildingData portera plusieurs blocs.
func test_an_incomplete_block_is_reported_under_its_prefix() -> void:
	var building := _producer()
	building.production.yield_per_turn = {} as Dictionary[StringName, int]
	assert_array(building.missing_fields()).contains(["production.yield_per_turn"])

## Et le préfixe descend jusqu'aux lignes de rendement, qui portent déjà un point.
func test_a_bad_yield_line_keeps_both_levels_of_prefix() -> void:
	var building := _producer()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"wood"] = -2
	building.production.yield_per_turn = per_turn
	assert_array(building.missing_fields()).contains(["production.yield_per_turn.wood"])

## Une ligne de coût à zéro ne veut rien dire : on l'omet. L'écrire est une faute de
## contenu, pas une gratuité.
func test_a_null_cost_line_is_reported() -> void:
	var building := _building(_l_shape())
	var cost: Dictionary[StringName, int] = {}
	cost[&"wood"] = 0
	building.cost = cost
	assert_array(building.missing_fields()).contains(["cost.wood"])

## Le logement suit la doctrine de storage_bonus et non celle du zéro : la plupart des
## bâtiments ne logent personne, et le réclamer refuserait de démarrer sur des données
## correctes.
func test_a_building_that_houses_nobody_is_complete() -> void:
	var building := _building(_l_shape())
	assert_int(building.housing).is_equal(0)
	assert_array(building.missing_fields()).is_empty()

func test_a_house_carries_its_places() -> void:
	var building := _building(_l_shape())
	building.housing = 2
	assert_array(building.missing_fields()).is_empty()

## Il remonte sous son propre nom et non sous un préfixe économique : les ranger avec le
## coût ferait mentir le rapport.
func test_negative_places_are_reported_under_their_own_name() -> void:
	var building := _building(_l_shape())
	building.housing = -1
	assert_array(building.missing_fields()).contains(["housing"])

## Le coût en travailleurs suit la même doctrine que le logement : une palissade n'en
## immobilise aucun, et zéro y est une valeur de contenu parfaitement légitime. Ce qui est
## refusé est le négatif, qui rendrait des bras au lieu d'en prendre.
##
## Ce que ce fichier ne peut **pas** vérifier, et c'est la question que CLAUDE.md fait poser
## avant tout missing_fields() : qu'il existe quelque part un bâtiment qui loge sans coûter
## de bras. Une BuildingData ne voit qu'elle-même, donc la règle vit dans GameDatabase.
func test_a_building_that_commits_nobody_is_complete() -> void:
	var building := _building(_l_shape())
	assert_int(building.workers).is_equal(0)
	assert_array(building.missing_fields()).is_empty()

func test_negative_workers_are_reported() -> void:
	var building := _building(_l_shape())
	building.workers = -1
	assert_array(building.missing_fields()).contains(["workers"])

## Les PV, eux, sont **réclamés**, et c'est le seul champ de combat qui le soit. Un
## bâtiment à zéro tombe au premier coup sans que rien ne le signale : « gratuit à
## défendre » et « oublié dans le .tres » y seraient indiscernables, Godot n'écrivant
## jamais un 0.
func test_a_building_without_hit_points_is_reported() -> void:
	var building := _building(_l_shape())
	building.hit_points = 0
	assert_array(building.missing_fields()).contains(["hit_points"])


## Le coût de chantier suit la même doctrine, et pour une raison qui lui est propre : le
## Cœur porte « — » dans la colonne Chantier de DESIGN.md 4.1 comme il porte « posé au
## départ » dans celle du coût. Un zéro y veut dire « achevé à la pose », et le réclamer
## refuserait de démarrer sur le seul bâtiment du jeu qui ne se construit pas.
func test_a_building_without_a_site_is_complete() -> void:
	var building := _building(_l_shape())
	assert_int(building.site_turns).is_equal(0)
	assert_array(building.missing_fields()).is_empty()

func test_a_building_carries_its_site_cost() -> void:
	var building := _building(_l_shape())
	building.site_turns = 3
	assert_array(building.missing_fields()).is_empty()

## Sous son propre nom lui aussi : c'est un chiffre de la Construction.
func test_a_negative_site_cost_is_reported_under_its_own_name() -> void:
	var building := _building(_l_shape())
	building.site_turns = -1
	assert_array(building.missing_fields()).contains(["site_turns"])

## Le rachat du zéro légitime, et la seule chose qui rattraperait un site_turns
## oublié dans TOUS les .tres à la fois : au moins un bâtiment de data/ en déclare un.
##
## Sans cette exigence, un champ disparu du format entier passerait par vacuité — c'est
## le même filet que production_block_test.gd tend sous les blocs de production.
func test_at_least_one_building_of_data_declares_a_site() -> void:
	var with_a_site: Array[String] = []
	for file in DirAccess.get_files_at(BUILDING_ROOT):
		if file.get_extension() != "tres":
			continue
		var building := load("%s/%s" % [BUILDING_ROOT, file]) as BuildingData
		if building.site_turns > 0:
			with_a_site.append(file.get_basename())
	assert_array(with_a_site) \
		.override_failure_message("aucun bâtiment de data/buildings/ ne déclare de chantier") \
		.is_not_empty()

## L'interdit de blocage de DESIGN.md 3.4, vérifié sur la data réelle.
##
## GameDatabase le tient déjà au boot, et ce cas ne le double pas pour rien : un `assert()`
## est retiré d'un export, alors qu'une suite de tests tourne toujours en débogage. La règle
## est trop coûteuse à perdre pour ne reposer que sur la première des deux — un catalogue
## qui la violerait rendrait une partie **définitivement** injouable, sans rien casser ni
## rien signaler.
##
## Ce qu'il exige est faible exprès : *au moins un* bâtiment qui loge sans coûter de bras.
## Un manoir cher en travailleurs resterait légitime à côté.
##
## **Le bâtiment d'ouverture est écarté depuis I3.** Le Cœur loge quatre personnes et ne
## coûte aucun bras, donc il satisfaisait ce cas à lui seul — mais il est posé une fois, à
## la fondation, et aucun geste du jeu n'en bâtit un second. La soupape qu'il semblait
## offrir ne s'ouvre jamais, si bien que le cas serait passé sur un catalogue où
## l'habitation coûte des bras, c'est-à-dire sur exactement la partie bloquée qu'il existe
## pour interdire. C'est la même famille de défaut que la règle qu'il protège : **une
## soupape se joue, elle ne se déclare pas** — et il aura fallu un tour jouable pour que la
## différence se voie.
func test_at_least_one_buildable_shelter_costs_no_workers() -> void:
	var balance := load("res://data/balance/balance.tres") as BalanceData
	var opener := String(balance.run.starting_building)
	var free_shelters: Array[String] = []
	for file in DirAccess.get_files_at(BUILDING_ROOT):
		if file.get_extension() != "tres" or file.get_basename() == opener:
			continue
		var building := load("%s/%s" % [BUILDING_ROOT, file]) as BuildingData
		if building != null and building.housing > 0 and building.workers == 0:
			free_shelters.append(file.get_basename())
	assert_array(free_shelters) \
		.override_failure_message(
			"aucun bâtiment constructible de data/buildings/ ne loge sans coûter de "
			+ "travailleur : une partie dont tout le monde est immobilisé ne pourrait "
			+ "plus rien bâtir") \
		.is_not_empty()

## Le bâtiment d'ouverture est bien celui que le cas ci-dessus écarte, et il est bien
## gratuit en bras. Sans cette vérification, un starting_building mal orthographié
## n'écarterait rien et le trou se refermerait tout seul sans qu'on le sache.
func test_the_starting_building_is_the_one_the_shelter_rule_skips() -> void:
	var balance := load("res://data/balance/balance.tres") as BalanceData
	var opener := balance.run.starting_building
	var heart := load("%s/%s.tres" % [BUILDING_ROOT, opener]) as BuildingData
	assert_object(heart).is_not_null()
	assert_int(heart.workers).is_equal(0)
	assert_int(heart.housing).is_greater(0)

## Un producteur cohérent : un rendement par tour, et c'est tout ce que N1 lui demande.
func _producer() -> BuildingData:
	var building := _building(_l_shape())
	var block := ProductionBlock.new()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"wood"] = 2
	block.yield_per_turn = per_turn
	building.production = block
	return building

## Un L : l'ancre, la cellule à sa droite, la cellule en dessous. Rendu neuf à chaque
## appel plutôt que gardé en constante — un tableau partagé entre cas finirait par
## être muté par l'un d'eux.
func _l_shape() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	return offsets

## Les PV sont renseignés ici et pas la défense ni les places de déploiement, et l'écart
## est la doctrine elle-même : F1 réclame les premiers et laisse les deux autres
## légitimement nuls. Un bâtiment de test qui les porterait tous les trois ne dirait plus
## rien de ce que missing_fields() exige vraiment.
func _building(offsets: Array[Vector2i]) -> BuildingData:
	var building := BuildingData.new()
	building.id = &"test_hut"
	building.color = Color(0.5, 0.4, 0.3)
	building.height = 0.6
	building.hit_points = 4
	building.footprint = offsets
	return building
