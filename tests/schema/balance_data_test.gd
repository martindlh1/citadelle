class_name BalanceDataTest
extends GdUnitTestSuite
## Fume-test du pipeline de données.
##
## S'il passe, trois choses tiennent debout d'un coup : gdUnit4 tourne sous la version
## de Godot épinglée, les Resource de src/schema/ sont enregistrées comme classes
## globales, et le chaînage de .tres de data/balance/ se résout.
##
## Il n'assert aucune valeur d'équilibrage précise : ces chiffres bougent à chaque passe
## d'équilibrage et un test qui les fige serait cassé en permanence. Il assert en
## revanche qu'aucun champ n'est resté vide, ce qui attrape le cas où l'éditeur
## réenregistre un .tres en effaçant une valeur.

const BALANCE_PATH := "res://data/balance/balance.tres"

func test_balance_loads_as_balance_data() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	assert_object(balance).is_not_null()

func test_balance_carries_a_terrain_block() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	assert_object(balance.terrain).is_not_null()
	assert_object(balance.terrain).is_instanceof(TerrainBalance)

func test_no_balance_field_is_left_unset() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	var missing := balance.missing_fields()
	assert_array(missing) \
		.override_failure_message("champs vides dans data/balance/ : %s" % ", ".join(missing)) \
		.is_empty()

func test_balance_carries_a_terrain_gen_block() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	assert_object(balance.terrain_gen).is_not_null()
	assert_object(balance.terrain_gen).is_instanceof(TerrainGenBalance)

## La palette de génération est chaînée depuis data/terrain/ : un .tres déplacé ou
## renommé casserait la génération sans casser le chargement de l'équilibrage.
func test_the_generation_palette_is_fully_wired() -> void:
	var generation := (load(BALANCE_PATH) as BalanceData).terrain_gen
	assert_object(generation.plain).is_not_null()
	assert_object(generation.forest).is_not_null()
	assert_object(generation.stone).is_not_null()
	assert_object(generation.water).is_not_null()
	assert_object(generation.rock).is_not_null()

func test_balance_carries_an_economy_block() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	assert_object(balance.economy).is_not_null()
	assert_object(balance.economy).is_instanceof(EconomyBalance)

## L'upkeep doit nommer une ressource qui existe. Le contrôle croisé complet est celui
## de GameDatabase au boot ; ici on tient au moins qu'il ne soit pas vide.
func test_the_upkeep_names_a_resource() -> void:
	var economy := (load(BALANCE_PATH) as BalanceData).economy
	assert_str(String(economy.upkeep_resource)).is_not_empty()

func test_balance_carries_a_camera_block() -> void:
	var balance := load(BALANCE_PATH) as BalanceData
	assert_object(balance.camera).is_not_null()
	assert_object(balance.camera).is_instanceof(CameraBalance)

## Le seul contrôle de cohérence du bloc caméra, et non de simple présence : une plage
## de zoom inversée passerait les tests de complétude et clamperait tout sur zoom_min,
## ce qui donne une caméra qui refuse de zoomer sans que rien ne signale pourquoi.
func test_an_inverted_zoom_range_is_reported() -> void:
	var camera := CameraBalance.new()
	camera.zoom_min = 20.0
	camera.zoom_max = 10.0
	assert_array(camera.missing_fields()).contains(["zoom_max"])

## Un facteur de molette à 1 laisse le zoom immobile : c'est un réglage vide, pas un
## réglage neutre.
func test_a_zoom_factor_of_one_is_reported() -> void:
	var camera := CameraBalance.new()
	camera.zoom_factor = 1.0
	assert_array(camera.missing_fields()).contains(["zoom_factor"])
