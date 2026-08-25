class_name RosterTest
extends GdUnitTestSuite
## Le vivier : qui en fait partie, qui est là, et ce qui en sort.
##
## Le cas qui porte le jalon est **la projection des seuls présents**. C'est la
## contrainte que DESIGN.md 3.9 impose d'honorer d'avance — des ouvriers peuvent être
## absents sans être morts —, et elle tient sur une ligne : si to_labor() cessait de
## filtrer, rien d'autre ne le remarquerait avant X1.
##
## Sa conséquence est testée à côté, parce qu'elle a été décidée par construction et
## non écrite : un absent ne compte pas dans LaborForce.size(), donc **il ne mange pas**.
##
## Aucun chiffre de data/ n'est figé : les bâtiments sont fabriqués à la main, comme
## dans production_resolver_test.gd et pour la même raison.

const HARVEST := &"harvest"

func test_an_empty_roster_holds_and_projects_nothing() -> void:
	var roster := Roster.empty()
	assert_int(roster.size()).is_equal(0)
	assert_int(roster.present_count()).is_equal(0)
	assert_int(roster.to_labor(_balance()).size()).is_equal(0)

func test_a_roster_keeps_the_order_it_was_given() -> void:
	var roster := _roster([&"ana", &"bo", &"cy"])
	assert_array(roster.to_labor(_balance()).workers()) \
		.contains_exactly([&"ana", &"bo", &"cy"])

func test_a_named_worker_comes_back() -> void:
	var roster := _roster([&"ana", &"bo"])
	assert_bool(roster.has(&"ana")).is_true()
	assert_bool(roster.has(&"zed")).is_false()
	assert_str(roster.worker(&"bo").given_name()).is_equal("bo")

## Le cas du jalon. Un absent reste au roster — il n'est pas mort — mais ne traverse
## pas la projection, donc l'Économie ne peut ni l'affecter ni le compter.
func test_only_the_present_are_projected() -> void:
	var roster := _roster([&"ana", &"bo", &"cy"])
	roster.worker(&"bo").set_present(false)
	assert_int(roster.size()).is_equal(3)
	assert_int(roster.present_count()).is_equal(2)
	assert_array(roster.to_labor(_balance()).workers()).contains_exactly([&"ana", &"cy"])

## Conséquence assumée et tranchée à W1 : l'upkeep tombe sur LaborForce.size(), donc un
## absent ne mange pas. Ce cas existe pour que l'inverser réveille quelqu'un.
func test_an_absent_worker_is_not_a_mouth_to_feed() -> void:
	var roster := _roster([&"ana", &"bo", &"cy"])
	roster.worker(&"cy").set_present(false)
	assert_int(roster.to_labor(_balance()).size()).is_equal(2)

func test_an_absent_worker_comes_back_where_he_was() -> void:
	var roster := _roster([&"ana", &"bo", &"cy"])
	roster.worker(&"ana").set_present(false)
	roster.worker(&"ana").set_present(true)
	assert_array(roster.to_labor(_balance()).workers()) \
		.contains_exactly([&"ana", &"bo", &"cy"])

## La projection porte ce que les pistes valent, pas ce que le roster sait d'autre.
func test_the_projection_carries_what_the_tracks_are_worth() -> void:
	var roster := _roster([&"ana"])
	roster.worker(&"ana").gain(HARVEST, 20)
	assert_float(roster.to_labor(_balance()).efficiency(&"ana", HARVEST)).is_equal(2.0)

func test_a_worker_can_be_added_afterwards() -> void:
	var roster := _roster([&"ana"])
	roster.add(Worker.create(&"bo", "bo"))
	assert_int(roster.size()).is_equal(2)
	assert_bool(roster.has(&"bo")).is_true()

## Un mort quitte le vivier. L'affectation qui le nommait lui survit, et c'est aux
## résolveurs de l'ignorer — ce qu'ils font tous les deux.
func test_removing_a_worker_takes_him_out_of_the_projection() -> void:
	var roster := _roster([&"ana", &"bo"])
	assert_bool(roster.remove(&"ana")).is_true()
	assert_bool(roster.has(&"ana")).is_false()
	assert_array(roster.to_labor(_balance()).workers()).contains_exactly([&"bo"])

func test_removing_someone_who_was_never_there_changes_nothing() -> void:
	var roster := _roster([&"ana"])
	assert_bool(roster.remove(&"zed")).is_false()
	assert_int(roster.size()).is_equal(1)

## Miroir de ProductionResolver.capacity_for() : la base, plus ce que les habitations
## ajoutent, et rien d'autre.
func test_the_capacity_is_the_base_plus_the_houses() -> void:
	var city := _city([_house(2), Vector2i(0, 0), _house(2), Vector2i(4, 4)])
	assert_int(Roster.capacity_for(city, _balance())).is_equal(14)

func test_a_city_without_a_house_leaves_the_base_alone() -> void:
	var city := _city([_barn(), Vector2i(0, 0)])
	assert_int(Roster.capacity_for(city, _balance())).is_equal(10)

func test_an_empty_city_still_has_the_base_places() -> void:
	assert_int(Roster.capacity_for(CitySnapshot.empty(), _balance())).is_equal(10)

## Le roster ne consulte jamais le plafond : c'est la couche qui orchestre la journée
## qui pose les deux questions à la suite, comme elle enchaîne payable et posable.
## Sans ce cas, quelqu'un finirait par « réparer » add() en y ajoutant un refus.
func test_the_roster_does_not_enforce_the_cap_itself() -> void:
	var workers: Array[Worker] = []
	for index in 20:
		workers.append(Worker.create(StringName("w%d" % index), "w%d" % index))
	assert_int(Roster.create(workers).size()).is_equal(20)

func _roster(ids: Array[StringName]) -> Roster:
	var workers: Array[Worker] = []
	for id in ids:
		workers.append(Worker.create(id, String(id)))
	return Roster.create(workers)

## Une habitation : rien qu'un bâtiment qui porte des places.
func _house(places: int) -> BuildingData:
	var house := BuildingData.new()
	house.id = &"house"
	house.roster_places = places
	return house

## Un bâtiment qui ne loge personne, pour que le zéro compte comme tel.
func _barn() -> BuildingData:
	var barn := BuildingData.new()
	barn.id = &"barn"
	return barn

## Ville depuis une liste plate — [data, ancre, data, ancre].
func _city(flat: Array) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	var index := 0
	while index < flat.size():
		placed.append(BuildingSnapshot.create(flat[index], flat[index + 1], 0))
		index += 2
	return CitySnapshot.create(placed)

func _balance() -> WorkforceBalance:
	var balance := WorkforceBalance.new()
	balance.base_roster_places = 10
	balance.xp_per_shift = 4
	balance.skill_xp_per_level = 10
	balance.max_skill_level = 4
	balance.efficiency_per_skill_level = 0.5
	balance.worker_xp_per_level = 25
	balance.max_worker_level = 4
	return balance
