class_name TerrainDataTest
extends GdUnitTestSuite
## Fume-test du contenu de data/terrain/, et de la sentinelle de couleur.
##
## Comme balance_data_test.gd, il ne fige aucune valeur : dire ici que l'eau n'est
## pas constructible reviendrait à recopier data/ dans tests/. Il vérifie que les
## cinq fichiers existent, qu'ils chargent, qu'aucun champ n'est resté vide, et que
## la convention « id = nom de fichier » tient — c'est elle qui rend les .tres
## interchangeables dans la palette de génération.
##
## Aucune couleur n'est assertée non plus : elles bougeront à la première passe
## visuelle. Ce qui est asserté, c'est le mécanisme qui détecte leur absence.
##
## Les identifiants sont manipulés en String et non en StringName : comparer deux
## StringName compare des pointeurs internes, pas du texte, donc les trier ne rend
## pas l'ordre alphabétique.

const TERRAIN_ROOT := "res://data/terrain"
const EXPECTED_IDS: Array[String] = ["forest", "plain", "rock", "stone", "water"]

func test_the_five_terrains_are_present() -> void:
	var ids: Array[String] = []
	for file in DirAccess.get_files_at(TERRAIN_ROOT):
		if file.get_extension() == "tres":
			ids.append(file.get_basename())
	ids.sort()
	assert_array(ids).is_equal(EXPECTED_IDS)

func test_every_terrain_loads_as_terrain_data() -> void:
	for id in EXPECTED_IDS:
		assert_object(_load(id)) \
			.override_failure_message("%s ne charge pas en TerrainData" % id) \
			.is_not_null()

func test_no_terrain_field_is_left_unset() -> void:
	for id in EXPECTED_IDS:
		var missing := _load(id).missing_fields()
		assert_array(missing) \
			.override_failure_message("champs vides dans %s.tres : %s" % [id, ", ".join(missing)]) \
			.is_empty()

func test_every_terrain_id_matches_its_file_name() -> void:
	for id in EXPECTED_IDS:
		assert_str(String(_load(id).id)) \
			.override_failure_message("l'id de %s.tres ne reprend pas son nom de fichier" % id) \
			.is_equal(id)

## Le pari de la sentinelle, épinglé : « non renseigné » vaut exactement la valeur par
## défaut d'un Color, donc exactement celle que Godot omet du .tres. Si une version du
## moteur changeait ce défaut, la détection deviendrait muette sans rien casser
## d'autre — c'est ce cas-là qui le dirait.
func test_the_unset_colour_sentinel_is_what_a_fresh_terrain_carries() -> void:
	var blank := TerrainData.new()
	assert_bool(blank.color == TerrainData.UNSET_COLOR) \
		.override_failure_message("un Color neuf vaut %s, la sentinelle vaut %s"
			% [blank.color, TerrainData.UNSET_COLOR]) \
		.is_true()

## Un terrain construit en code n'a rien de renseigné, et les quatre champs
## obligatoires se signalent — la couleur comprise, ce qui prouve que la sentinelle
## ne se contente pas d'exister.
func test_a_blank_terrain_reports_all_its_required_fields() -> void:
	var missing := TerrainData.new().missing_fields()
	assert_array(missing).contains(["id", "build", "walk", "color"])

## **Les deux verdicts sont deux champs**, et ce cas est ce qui l'épingle : un terrain qui
## déclare sa constructibilité et rien d'autre reste incomplet. Sans lui, une
## franchissabilité déduite de `build` passerait la suite entière — les cinq terrains de
## `data/` répondent la même chose aux deux questions.
func test_declaring_where_one_builds_says_nothing_of_where_one_walks() -> void:
	var terrain := TerrainData.new()
	terrain.build = TerrainData.Build.ALLOWED
	assert_bool(terrain.is_walkable()).is_false()
	assert_array(terrain.missing_fields()).contains(["walk"])

## Une couleur posée sort de la liste des manquants.
func test_a_colour_once_set_stops_being_reported() -> void:
	var terrain := TerrainData.new()
	terrain.color = Color(0.4, 0.6, 0.3)
	assert_array(terrain.missing_fields()).not_contains(["color"])

func _load(id: String) -> TerrainData:
	return load("%s/%s.tres" % [TERRAIN_ROOT, id]) as TerrainData
