class_name ProductionBlockTest
extends GdUnitTestSuite
## Le bloc de production d'un bâtiment, et son filet de complétude.
##
## Aucun chiffre de data/ n'est figé ici : les rendements des bâtiments de DESIGN.md 4.1
## bougeront à B1. Ce qui est asserté, c'est le mécanisme qui refuse un bloc inexploitable.
##
## Ce que ce fichier existe pour prouver tient en une phrase, et elle a survécu au rescope :
## **un bloc qui existe produit**, donc son contenu se réclame sans condition. À E1 ces
## champs vivaient à plat sur BuildingData, où un rendement vide était légitime — la
## palissade ne produit rien —, si bien qu'on ne pouvait rien réclamer du tout. Le bloc
## nullable rend la doctrine du zéro applicable, et c'est sa seule raison d'être.

const BUILDING_ROOT := "res://data/buildings"

## Ce qu'un bloc vide réclame, et c'est désormais un seul champ.
##
## N1 lui en a retiré deux sur trois : `slots` comptait des postes qu'une carte venait
## tenir, `skill_family` nommait une piste de compétence. Les deux décrivaient des systèmes
## que le rescope a supprimés.
func test_a_blank_block_reports_its_yield() -> void:
	assert_array(ProductionBlock.new().missing_fields()).contains(["yield_per_turn"])

func test_a_filled_block_reports_nothing() -> void:
	assert_array(_block().missing_fields()).is_empty()

## Un bloc qui existe produit, par définition : un rendement vide ne casse pas au
## chargement, il ne casse qu'au premier tour en ne versant rien. C'est précisément
## pourquoi le boot le réclame.
func test_an_empty_yield_is_reported() -> void:
	var block := _block()
	block.yield_per_turn = {} as Dictionary[StringName, int]
	assert_array(block.missing_fields()).contains(["yield_per_turn"])

## Une ligne de rendement à zéro ne veut rien dire : on l'omet. L'écrire est une faute de
## contenu, et elle remonte sous le nom de sa ressource.
func test_a_null_yield_line_is_reported_under_its_resource() -> void:
	var block := _block()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"wood"] = 0
	block.yield_per_turn = per_turn
	assert_array(block.missing_fields()).contains(["yield_per_turn.wood"])

func test_a_negative_yield_line_is_reported() -> void:
	var block := _block()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"wood"] = -2
	block.yield_per_turn = per_turn
	assert_array(block.missing_fields()).contains(["yield_per_turn.wood"])

## Le bloc ne connaît pas le catalogue de data/commodities/ : une Resource de schéma ne
## lit jamais l'index, et c'est GameDatabase qui confronte les identifiants au démarrage.
## Ce cas garde la frontière plutôt qu'un comportement.
func test_an_unknown_resource_is_not_this_file_s_business() -> void:
	var block := _block()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"unobtainium"] = 3
	block.yield_per_turn = per_turn
	assert_array(block.missing_fields()).is_empty()

## Le seul cas qui regarde `data/` plutôt qu'un objet fabriqué, et le seul qui attraperait
## un `.tres` réenregistré de travers par l'éditeur.
##
## Il compte les producteurs en passant : à zéro, la boucle ne vérifierait rien tout en
## passant au vert — une table qui ne prouve rien parce qu'elle n'a rien à parcourir.
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

func _block() -> ProductionBlock:
	var block := ProductionBlock.new()
	var per_turn: Dictionary[StringName, int] = {}
	per_turn[&"wood"] = 2
	block.yield_per_turn = per_turn
	return block
