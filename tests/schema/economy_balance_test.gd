class_name EconomyBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage de l'économie et son filet de complétude.
##
## Aucun chiffre de data/balance/ n'est figé : la réserve et l'upkeep bougeront à
## chaque passe d'équilibrage, et un test qui les figerait serait cassé en permanence.
## Ce qui est asserté, c'est le mécanisme qui refuse un bloc inexploitable.

func test_a_blank_block_reports_all_its_required_fields() -> void:
	assert_array(EconomyBalance.new().missing_fields()) \
		.contains(["base_storage_cap", "base_housing", "starting_population",
			"upkeep_per_inhabitant", "upkeep_resource"])

func test_a_filled_block_reports_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

## Sans elle, le résolveur ne saurait pas quoi prélever — et un &"food" écrit en dur
## dans src/domain/ survivrait à un renommage du catalogue sans rien dire.
func test_a_missing_upkeep_resource_is_reported() -> void:
	var balance := _balance()
	balance.upkeep_resource = &""
	assert_array(balance.missing_fields()).contains(["upkeep_resource"])

## Un upkeep nul supprimerait la famine, donc tout un système, sans que rien ne le
## signale. Godot n'écrivant jamais un 0 dans un .tres, « oublié » et « gratuit » y
## seraient indiscernables.
func test_a_zero_upkeep_is_reported() -> void:
	var balance := _balance()
	balance.upkeep_per_inhabitant = 0
	assert_array(balance.missing_fields()).contains(["upkeep_per_inhabitant"])

## En réserve commune, un stock d'ouverture au-dessus de la capacité serait écrêté dès
## le premier soir : le chiffre du .tres mentirait sur ce que le run reçoit.
func test_a_starting_stock_over_the_cap_is_reported() -> void:
	var balance := _balance()
	balance.base_storage_cap = 10
	assert_array(balance.missing_fields()).contains(["starting_stock.over_capacity"])

## Le total compte, pas chaque ligne. C'est précisément ce qu'une réserve commune veut
## dire, et un contrôle ligne par ligne laisserait passer trois stocks de 60.
func test_the_starting_stock_is_measured_as_a_whole() -> void:
	var balance := _balance()
	balance.base_storage_cap = 60
	balance.starting_stock = _stock(40, 40)
	assert_array(balance.missing_fields()).contains(["starting_stock.over_capacity"])

func test_a_negative_starting_amount_is_reported() -> void:
	var balance := _balance()
	balance.starting_stock = _stock(-5, 10)
	assert_array(balance.missing_fields()).contains(["starting_stock.wood"])

func test_an_empty_starting_stock_is_legitimate() -> void:
	var balance := _balance()
	balance.starting_stock = {}
	assert_array(balance.missing_fields()).is_empty()

func _balance() -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = 100
	balance.base_housing = 6
	balance.starting_population = 4
	balance.upkeep_per_inhabitant = 1
	balance.upkeep_resource = &"food"
	balance.starting_stock = _stock(30, 20)
	return balance

func _stock(wood: int, food: int) -> Dictionary[StringName, int]:
	var stock: Dictionary[StringName, int] = {}
	stock[&"wood"] = wood
	stock[&"food"] = food
	return stock
