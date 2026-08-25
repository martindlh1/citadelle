class_name CommodityDataTest
extends GdUnitTestSuite
## Le catalogue des ressources : son filet de complétude, et la convention de nommage
## qui lie un fichier à son identifiant.
##
## Aucun chiffre ni aucune couleur de data/commodities/ n'est figé ici. Ce qui est
## asserté, c'est que le catalogue est exploitable et que les identifiants suivent
## leurs noms de fichier — DESIGN.md 3.3 laisse le nombre de ressources ouvert, et
## ce fichier doit rester vrai qu'il y en ait trois ou six.

const COMMODITY_ROOT := "res://data/commodities"

func test_a_blank_commodity_reports_all_its_required_fields() -> void:
	assert_array(CommodityData.new().missing_fields()).contains(["id", "label", "color"])

## Troisième copie de la sentinelle, après TerrainData et BuildingData. Ce cas est ce
## qui empêche les trois de dériver les unes des autres.
func test_the_unset_colour_sentinels_agree() -> void:
	assert_bool(CommodityData.UNSET_COLOR == TerrainData.UNSET_COLOR) \
		.override_failure_message("les sentinelles ont divergé : %s contre %s"
			% [CommodityData.UNSET_COLOR, TerrainData.UNSET_COLOR]) \
		.is_true()

func test_a_filled_commodity_reports_nothing() -> void:
	assert_array(_commodity(&"wood").missing_fields()).is_empty()

## Le noir opaque est le défaut d'un Color en GDScript, donc exactement ce que Godot
## omet du .tres : un champ oublié et un noir délibéré y seraient indiscernables.
func test_an_unset_colour_is_reported() -> void:
	var commodity := _commodity(&"wood")
	commodity.color = CommodityData.UNSET_COLOR
	assert_array(commodity.missing_fields()).contains(["color"])

## Le libellé est le seul champ que le domaine ne regarde jamais — il est là pour le
## HUD de E2. Le réclamer quand même évite d'arriver à E2 avec trois ressources
## anonymes à afficher.
func test_a_missing_label_is_reported() -> void:
	var commodity := _commodity(&"wood")
	commodity.label = ""
	assert_array(commodity.missing_fields()).contains(["label"])

## Chaque .tres du catalogue se charge, est complet, et porte l'identifiant de son
## nom de fichier. C'est cette convention que GameDatabase indexe.
func test_every_commodity_in_data_is_usable_and_well_named() -> void:
	var seen := PackedStringArray()
	for file in DirAccess.get_files_at(COMMODITY_ROOT):
		if file.get_extension() != "tres":
			continue
		var commodity := load("%s/%s" % [COMMODITY_ROOT, file]) as CommodityData
		assert_object(commodity) \
			.override_failure_message("%s n'est pas une CommodityData" % file) \
			.is_not_null()
		assert_array(commodity.missing_fields()) \
			.override_failure_message("ressource inexploitable dans %s" % file) \
			.is_empty()
		assert_str(String(commodity.id)) \
			.override_failure_message("l'identifiant de %s ne suit pas son nom" % file) \
			.is_equal(file.get_basename())
		seen.append(file.get_basename())
	assert_array(seen) \
		.override_failure_message("data/commodities/ ne contient aucune ressource") \
		.is_not_empty()

func _commodity(id: StringName) -> CommodityData:
	var commodity := CommodityData.new()
	commodity.id = id
	commodity.label = "Libellé de test"
	commodity.color = Color(0.5, 0.4, 0.3)
	return commodity
