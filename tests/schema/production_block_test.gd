class_name ProductionBlockTest
extends GdUnitTestSuite
## Le bloc de production d'un bâtiment, et son filet de complétude.
##
## Aucun chiffre de data/ n'est figé ici : les slots et les rendements des douze
## bâtiments de DESIGN.md 4.1 bougeront à I3. Ce qui est asserté, c'est le mécanisme
## qui refuse un bloc inexploitable.
##
## Ce que ce fichier existe pour prouver tient en un cas — celui des slots. À E1 ces
## trois champs vivaient à plat sur BuildingData, où 0 slot était légitime : la
## palissade n'a pas de poste. On ne pouvait donc pas réclamer les slots, seulement
## constater qu'ils ne s'accordaient pas avec le reste. Ici un bloc qui existe produit,
## donc les trois se réclament sans condition.

const BUILDING_ROOT := "res://data/buildings"

func test_a_blank_block_reports_all_three_fields() -> void:
	assert_array(ProductionBlock.new().missing_fields()) \
		.contains(["slots", "yield_per_slot", "skill_family"])

func test_a_complete_block_reports_nothing() -> void:
	assert_array(_filled().missing_fields()).is_empty()

## Le cas qui porte le jalon. Un bloc sans poste ne serait jamais tenu — et à E1,
## là où 0 slot était une valeur légitime de BuildingData, il était indétectable.
func test_a_block_without_slots_is_reported() -> void:
	var block := _filled()
	block.slots = 0
	assert_array(block.missing_fields()).contains(["slots"])

## Des postes sans rendement ne verseraient rien, et ça ne casserait qu'au premier soir.
func test_a_block_without_a_yield_is_reported() -> void:
	var block := _filled()
	block.yield_per_slot = {}
	assert_array(block.missing_fields()).contains(["yield_per_slot"])

## Sans famille, un poste ne sait ni quel multiplicateur appliquer ni quelle piste
## créditer en XP.
func test_a_block_without_a_family_is_reported() -> void:
	var block := _filled()
	block.skill_family = &""
	assert_array(block.missing_fields()).contains(["skill_family"])

## Une ligne de rendement à zéro ne veut rien dire : on l'omet. L'écrire est une faute
## de contenu, pas un poste improductif.
func test_a_null_yield_line_is_reported() -> void:
	var block := _filled()
	var per_slot: Dictionary[StringName, int] = {}
	per_slot[&"wood"] = 0
	block.yield_per_slot = per_slot
	assert_array(block.missing_fields()).contains(["yield_per_slot.wood"])

func test_a_negative_yield_line_is_reported() -> void:
	var block := _filled()
	var per_slot: Dictionary[StringName, int] = {}
	per_slot[&"wood"] = -2
	block.yield_per_slot = per_slot
	assert_array(block.missing_fields()).contains(["yield_per_slot.wood"])

## Le bloc est écrit en sub_resource dans les .tres, comme TerrainDecor l'est sur un
## terrain. Ce cas vérifie qu'il en revient typé et exploitable, et non en Resource nue
## dont les champs seraient inaccessibles — une faute de format se lirait sans erreur
## et ne casserait qu'au premier soir.
##
## Il exige qu'au moins un bâtiment de data/ en porte un : sans ça, le cas passerait
## par vacuité le jour où le format se casserait partout.
func test_a_block_written_in_a_tres_comes_back_typed() -> void:
	var producers: Array[String] = []
	for file in DirAccess.get_files_at(BUILDING_ROOT):
		if file.get_extension() != "tres":
			continue
		var building := load("%s/%s" % [BUILDING_ROOT, file]) as BuildingData
		if not building.produces():
			continue
		producers.append(file.get_basename())
		assert_object(building.production) \
			.override_failure_message("le bloc de %s n'est pas un ProductionBlock" % file) \
			.is_instanceof(ProductionBlock)
		assert_array(building.production.missing_fields()) \
			.override_failure_message("bloc de production inexploitable dans %s" % file) \
			.is_empty()
	assert_array(producers) \
		.override_failure_message("aucun bâtiment de data/ ne porte de bloc typé") \
		.is_not_empty()

## Un bloc cohérent : deux postes, un rendement, une famille.
func _filled() -> ProductionBlock:
	var block := ProductionBlock.new()
	block.slots = 2
	var per_slot: Dictionary[StringName, int] = {}
	per_slot[&"wood"] = 2
	block.yield_per_slot = per_slot
	block.skill_family = &"harvest"
	return block
