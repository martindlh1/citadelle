class_name TerrainDataTest
extends GdUnitTestSuite
## Fume-test du contenu de data/terrain/.
##
## Comme balance_data_test.gd, il ne fige aucune valeur : dire ici que l'eau n'est
## pas constructible reviendrait à recopier data/ dans tests/. Il vérifie que les
## cinq fichiers existent, qu'ils chargent, qu'aucun champ n'est resté vide, et que
## la convention « id = nom de fichier » tient — c'est elle qui rend les .tres
## interchangeables dans la palette de génération.
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

func _load(id: String) -> TerrainData:
	return load("%s/%s.tres" % [TERRAIN_ROOT, id]) as TerrainData
