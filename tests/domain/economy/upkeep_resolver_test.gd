class_name UpkeepResolverTest
extends GdUnitTestSuite
## Le repas d'un tour : ce qu'il prélève, et ce qu'il change à l'effectif.

const FOOD := &"food"

func _balance(per_head: int = 1) -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = 100
	balance.base_housing = 10
	balance.starting_population = 4
	balance.upkeep_per_inhabitant = per_head
	balance.upkeep_resource = FOOD
	return balance

func _ledger(food: int) -> Ledger:
	var stock: Dictionary[StringName, int] = {}
	if food > 0:
		stock[FOOD] = food
	return Ledger.from_stock(stock, 100)

# --- ce que le repas coûte ---------------------------------------------------

## Tout le monde mange, immobilisés compris : le résolveur ne connaît pas le plan de
## travail, seulement l'effectif. C'est ce qui rend le chiffre indépendant de ce que le
## village fait tourner.
func test_everyone_eats() -> void:
	var people := Population.from_headcount(4, 10)
	var ledger := _ledger(20)
	var report := UpkeepResolver.resolve(people, ledger, _balance())
	assert_int(report.due()).is_equal(4)
	assert_int(report.paid()).is_equal(4)
	assert_int(ledger.amount(FOOD)).is_equal(16)

func test_the_ration_comes_from_the_balance() -> void:
	var people := Population.from_headcount(3, 10)
	var report := UpkeepResolver.resolve(people, _ledger(20), _balance(2))
	assert_int(report.due()).is_equal(6)

func test_an_empty_village_owes_nothing() -> void:
	var people := Population.from_headcount(0, 10)
	var report := UpkeepResolver.resolve(people, _ledger(5), _balance())
	assert_int(report.due()).is_equal(0)
	assert_bool(report.is_starving()).is_false()

# --- la croissance -----------------------------------------------------------

## La règle de DESIGN.md 3.4, littéralement : un reliquat suffit. C'est délibérément la plus
## simple qui la satisfasse, et c'est ici que se posera le premier bouton d'équilibrage de
## la population si un run entier montre que le village grossit trop vite.
func test_a_leftover_brings_someone() -> void:
	var people := Population.from_headcount(4, 10)
	var report := UpkeepResolver.resolve(people, _ledger(5), _balance())
	assert_int(report.arrived()).is_equal(1)
	assert_int(people.headcount()).is_equal(5)

## Le frein est spatial et il passe avant la nourriture : de quoi manger ne fait venir
## personne s'il n'y a pas de lit.
func test_a_full_village_does_not_grow_however_well_it_eats() -> void:
	var people := Population.from_headcount(4, 4)
	var report := UpkeepResolver.resolve(people, _ledger(80), _balance())
	assert_int(report.arrived()).is_equal(0)
	assert_int(people.headcount()).is_equal(4)

## Manger exactement ce qu'on avait ne fait venir personne : le reliquat est nul.
func test_eating_the_last_ration_brings_nobody() -> void:
	var people := Population.from_headcount(4, 10)
	var report := UpkeepResolver.resolve(people, _ledger(4), _balance())
	assert_int(report.paid()).is_equal(4)
	assert_int(report.arrived()).is_equal(0)
	assert_bool(report.is_starving()).is_false()

# --- la famine ---------------------------------------------------------------

## Un cran par tour, pas un par bouche non nourrie. C'est ce qui rend la famine une pente
## plutôt qu'une falaise — et le rapport porte les deux chiffres, de sorte qu'un écran
## puisse dire l'ampleur sans que le domaine la punisse deux fois.
func test_a_shortfall_costs_one_inhabitant() -> void:
	var people := Population.from_headcount(6, 10)
	var report := UpkeepResolver.resolve(people, _ledger(2), _balance())
	assert_bool(report.is_starving()).is_true()
	assert_int(report.paid()).is_equal(2)
	assert_int(report.lost()).is_equal(1)
	assert_int(people.headcount()).is_equal(5)

## Le manque est en nourriture, le compte en personnes : il s'arrondit au supérieur, sans
## quoi un manque plus petit qu'une ration se lirait « tout le monde a mangé » alors que
## quelqu'un n'a rien eu.
func test_the_unfed_count_rounds_up() -> void:
	var people := Population.from_headcount(4, 10)
	var report := UpkeepResolver.resolve(people, _ledger(5), _balance(2))
	assert_int(report.due()).is_equal(8)
	assert_int(report.paid()).is_equal(5)
	assert_int(report.unfed()).is_equal(2)

func test_an_empty_reserve_starves_everyone() -> void:
	var people := Population.from_headcount(3, 10)
	var report := UpkeepResolver.resolve(people, _ledger(0), _balance())
	assert_int(report.paid()).is_equal(0)
	assert_int(report.unfed()).is_equal(3)
	assert_int(report.lost()).is_equal(1)

## Le dernier habitant part comme les autres : c'est le run qui décide que le village est
## mort, pas ce résolveur. « Un système qui rencontre un fait le compte, il n'invente pas
## sa conséquence » — DESIGN.md 9.
func test_the_last_inhabitant_can_starve_away() -> void:
	var people := Population.from_headcount(1, 10)
	UpkeepResolver.resolve(people, _ledger(0), _balance())
	assert_int(people.headcount()).is_equal(0)

# --- l'exclusivité des deux issues -------------------------------------------

## Un tour ne fait jamais venir *et* partir : la croissance demande un reliquat, la
## décroissance un manque, et les deux ne peuvent pas être vrais du même repas. Ce n'est pas
## une garde, c'est une conséquence — et UpkeepReport l'assert pour qu'un changement de
## règle qui la casserait se signale au lieu de rendre un rapport contradictoire.
func test_a_turn_never_both_grows_and_shrinks() -> void:
	for food in [0, 1, 4, 5, 40]:
		var people := Population.from_headcount(4, 10)
		var report := UpkeepResolver.resolve(people, _ledger(food), _balance())
		assert_bool(report.arrived() > 0 and report.lost() > 0) \
			.override_failure_message("un repas à %d nourritures fait les deux" % food) \
			.is_false()
