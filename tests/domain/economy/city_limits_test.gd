class_name CityLimitsTest
extends GdUnitTestSuite
## Les deux plafonds que le bâti relève, et la seule règle qu'ils partagent.
##
## Les cas vont par paires : ce qui vaut pour la réserve vaut pour le logement, et c'est
## exactement pourquoi les deux fonctions vivent dans le même fichier. Une paire qui
## divergerait se lirait ici avant de se lire en jeu.

const BASE_STORAGE := 100
const BASE_HOUSING := 6
const HIT_POINTS := 4

func _balance() -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = BASE_STORAGE
	balance.base_housing = BASE_HOUSING
	balance.starting_population = 4
	balance.upkeep_per_inhabitant = 1
	balance.upkeep_resource = &"food"
	return balance

## `site_turns` est ce qui fait d'un bâtiment un chantier tant que son avancement ne l'a pas
## rattrapé. À zéro il est achevé dès la pose, comme le Cœur.
func _building(id: StringName, storage: int, housing: int,
		site_turns: int = 0) -> BuildingData:
	var data := BuildingData.new()
	# Une emprise large, pour que la règle d'emprise de `C7` ne se mette pas en travers des
	# cas qui parlent d'autre chose : un `reach` laissé à zéro n'ouvrirait même pas la case
	# voisine, et toute ville de plus d'un bâtiment serait refusée.
	data.reach = 12
	data.id = id
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = HIT_POINTS
	data.storage_bonus = storage
	data.housing = housing
	data.site_turns = site_turns
	return data

## Ville de ces bâtiments, chacun sur sa propre ancre, tous **achevés**.
func _city(buildings: Array[BuildingData]) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	for i in buildings.size():
		placed.append(BuildingSnapshot.create(buildings[i], Vector2i(i, 0), 0, 0,
			buildings[i].site_turns))
	return CitySnapshot.create(placed)

# --- la base seule -----------------------------------------------------------

func test_an_empty_city_gets_the_base_caps() -> void:
	assert_int(CityLimits.storage_for(CitySnapshot.empty(), _balance())).is_equal(BASE_STORAGE)
	assert_int(CityLimits.housing_for(CitySnapshot.empty(), _balance())).is_equal(BASE_HOUSING)

func test_a_building_that_raises_nothing_leaves_the_caps_alone() -> void:
	var city := _city([_building(&"palisade", 0, 0)])
	assert_int(CityLimits.storage_for(city, _balance())).is_equal(BASE_STORAGE)
	assert_int(CityLimits.housing_for(city, _balance())).is_equal(BASE_HOUSING)

# --- ce que le bâti ajoute ---------------------------------------------------

func test_warehouses_add_up_on_the_common_reserve() -> void:
	var city := _city([_building(&"store", 100, 0), _building(&"store2", 100, 0)])
	assert_int(CityLimits.storage_for(city, _balance())).is_equal(BASE_STORAGE + 200)

func test_houses_add_up_on_the_housing_cap() -> void:
	var city := _city([_building(&"house", 0, 4), _building(&"house2", 0, 4)])
	assert_int(CityLimits.housing_for(city, _balance())).is_equal(BASE_HOUSING + 8)

## Un bâtiment peut relever les deux — le Cœur loge et pourrait stocker. Les deux
## fonctions lisent le même bâtiment sans se marcher dessus.
func test_one_building_can_raise_both_caps() -> void:
	var city := _city([_building(&"heart", 50, 4)])
	assert_int(CityLimits.storage_for(city, _balance())).is_equal(BASE_STORAGE + 50)
	assert_int(CityLimits.housing_for(city, _balance())).is_equal(BASE_HOUSING + 4)

# --- la règle qui compte : un chantier ne relève rien ------------------------

## « Un entrepôt en chantier a payé son coût et occupe ses cellules, mais il n'a pas de
## toit. » L'oubli serait **silencieux** : rien ne casserait, le plafond mentirait.
##
## Le cas vérifie sa propre prémisse — que le bâtiment fabriqué est bien inachevé — parce
## que c'est exactement le montage qu'un `site_turns` mal passé fait basculer sans bruit.
## C'est la leçon que N1 a payée sur un fixture.
func test_a_site_under_construction_raises_neither_cap() -> void:
	var store := _building(&"store", 100, 0, 3)
	var house := _building(&"house", 0, 4, 2)
	var opened: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(store, Vector2i(0, 0), 0, 0, 0),
		BuildingSnapshot.create(house, Vector2i(1, 0), 0, 0, 1)]
	var city := CitySnapshot.create(opened)
	assert_array(city.completed()) \
		.override_failure_message("le montage a fabriqué des bâtiments finis") \
		.is_empty()
	assert_int(CityLimits.storage_for(city, _balance())).is_equal(BASE_STORAGE)
	assert_int(CityLimits.housing_for(city, _balance())).is_equal(BASE_HOUSING)

## Le pendant du précédent : le cran qui achève le chantier est celui qui relève le
## plafond. Sans ce cas, le précédent passerait aussi sur une fonction qui ne compte
## jamais rien.
func test_the_notch_that_finishes_a_site_raises_the_cap() -> void:
	var store := _building(&"store", 100, 0, 3)
	var done: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(store, Vector2i(0, 0), 0, 0, 3)]
	assert_int(CityLimits.storage_for(CitySnapshot.create(done), _balance())) \
		.is_equal(BASE_STORAGE + 100)
