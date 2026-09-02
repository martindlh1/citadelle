class_name LedgerTest
extends GdUnitTestSuite
## La réserve commune : ce qui entre, ce qui sort, et ce que le plafond fait perdre.
##
## Le cœur de ce fichier est la **répartition d'un débordement**. C'est la seule vraie
## logique de la classe, et c'est une conséquence directe du choix d'une réserve
## partagée : avec un plafond par ressource, aucun de ces cas n'existerait.
##
## Aucun chiffre de data/balance/ n'est figé ici. Les capacités sont fabriquées à la
## main, petites, pour que les divisions se vérifient de tête.

const WOOD := &"wood"
const STONE := &"stone"
const FOOD := &"food"

func test_a_new_ledger_holds_nothing() -> void:
	var ledger := Ledger.create(100)
	assert_int(ledger.total()).is_equal(0)
	assert_int(ledger.amount(WOOD)).is_equal(0)
	assert_dict(ledger.amounts()).is_empty()

## Une ressource jamais reçue vaut zéro plutôt que de lever : le HUD affichera les
## trois compteurs dès le premier soir, dont deux à zéro.
func test_an_unknown_resource_reads_zero() -> void:
	assert_int(Ledger.create(100).amount(&"never_seen")).is_equal(0)

func test_free_space_shrinks_as_the_reserve_fills() -> void:
	var ledger := Ledger.create(50)
	assert_int(ledger.free_space()).is_equal(50)
	ledger.add(WOOD, 20)
	assert_int(ledger.free_space()).is_equal(30)
	assert_bool(ledger.is_full()).is_false()

## La réserve est commune : du bois mangeant la place, il ne reste pas 50 pour la
## pierre. C'est toute la différence avec un plafond par ressource.
func test_one_resource_eats_the_room_of_the_others() -> void:
	var ledger := Ledger.create(50)
	ledger.add(WOOD, 50)
	assert_bool(ledger.is_full()).is_true()
	assert_int(ledger.add(STONE, 10)).is_equal(10)
	assert_int(ledger.amount(STONE)).is_equal(0)

func test_adding_within_the_cap_loses_nothing() -> void:
	var ledger := Ledger.create(100)
	assert_int(ledger.add(WOOD, 40)).is_equal(0)
	assert_int(ledger.amount(WOOD)).is_equal(40)

func test_adding_past_the_cap_keeps_what_fits() -> void:
	var ledger := Ledger.create(100)
	ledger.add(WOOD, 90)
	assert_int(ledger.add(STONE, 30)).is_equal(20)
	assert_int(ledger.amount(STONE)).is_equal(10)
	assert_int(ledger.total()).is_equal(100)

func test_depositing_within_the_cap_stores_everything() -> void:
	var ledger := Ledger.create(100)
	var stored := ledger.deposit(_bundle([WOOD, 30, STONE, 10]))
	assert_int(stored[WOOD]).is_equal(30)
	assert_int(stored[STONE]).is_equal(10)
	assert_int(ledger.total()).is_equal(40)

## Le cas qui porte le jalon. Trente bois et dix pierres pour vingt places : chacune
## reçoit la moitié de ce qu'elle apportait, et non « le bois d'abord ».
func test_an_overrunning_deposit_splits_proportionally() -> void:
	var ledger := Ledger.create(20)
	var stored := ledger.deposit(_bundle([WOOD, 30, STONE, 10]))
	assert_int(stored[WOOD]).is_equal(15)
	assert_int(stored[STONE]).is_equal(5)
	assert_int(ledger.total()).is_equal(20)

## Le reste de la division va à la plus grosse part fractionnaire.
## Cinq bois et quatre pierres pour six places : 30/9 = 3 reste 3, 24/9 = 2 reste 6.
func test_the_remainder_goes_to_the_largest_fraction() -> void:
	var ledger := Ledger.create(6)
	var stored := ledger.deposit(_bundle([WOOD, 5, STONE, 4]))
	assert_int(stored[STONE]).is_equal(3)
	assert_int(stored[WOOD]).is_equal(3)
	assert_int(ledger.total()).is_equal(6)

## À fractions égales, l'identifiant tranche — et il tranche par son texte, jamais par
## le pointeur interne du StringName, dont l'ordre change d'une session à l'autre.
func test_equal_fractions_are_broken_by_identifier() -> void:
	var ledger := Ledger.create(20)
	var stored := ledger.deposit(_bundle([WOOD, 10, STONE, 10, FOOD, 10]))
	assert_int(stored[FOOD]).is_equal(7)
	assert_int(stored[STONE]).is_equal(7)
	assert_int(stored[WOOD]).is_equal(6)

## L'invariant qui justifie toute la règle : deux villes identiques bâties dans un
## ordre différent perdent exactement la même chose. Un premier-arrivé-premier-servi
## ferait diverger ces deux dépôts.
func test_the_split_does_not_depend_on_key_order() -> void:
	var first := Ledger.create(20)
	var second := Ledger.create(20)
	var forwards := first.deposit(_bundle([WOOD, 10, STONE, 10, FOOD, 10]))
	var backwards := second.deposit(_bundle([FOOD, 10, STONE, 10, WOOD, 10]))
	for resource in [WOOD, STONE, FOOD]:
		assert_int(forwards[resource]) \
			.override_failure_message("%s diverge selon l'ordre des clés" % resource) \
			.is_equal(backwards[resource])

## Une ressource qui n'obtient rien ne figure pas dans le retour : il se lit comme la
## liste de ce qui est entré, et ProductionReport.wasted() s'en sert telle quelle.
func test_a_resource_that_gets_nothing_is_absent_from_the_result() -> void:
	var ledger := Ledger.create(1)
	var stored := ledger.deposit(_bundle([WOOD, 100, STONE, 1]))
	assert_bool(stored.has(STONE)).is_false()

func test_depositing_into_a_full_reserve_stores_nothing() -> void:
	var ledger := Ledger.create(10)
	ledger.add(WOOD, 10)
	assert_dict(ledger.deposit(_bundle([STONE, 5]))).is_empty()

func test_an_empty_deposit_changes_nothing() -> void:
	var ledger := Ledger.create(100)
	ledger.add(WOOD, 5)
	assert_dict(ledger.deposit(_bundle([]))).is_empty()
	assert_int(ledger.total()).is_equal(5)

func test_raising_the_capacity_loses_nothing() -> void:
	var ledger := Ledger.create(50)
	ledger.add(WOOD, 40)
	assert_int(ledger.set_capacity(200)).is_equal(0)
	assert_int(ledger.amount(WOOD)).is_equal(40)

## Un entrepôt détruit par une vague. L'écrêtage suit la même règle qu'un dépôt qui
## déborde, pour la même raison : il ne doit pas vider une ressource en particulier.
func test_lowering_the_capacity_clips_proportionally() -> void:
	var ledger := Ledger.create(100)
	ledger.deposit(_bundle([WOOD, 60, STONE, 40]))
	assert_int(ledger.set_capacity(50)).is_equal(50)
	assert_int(ledger.amount(WOOD)).is_equal(30)
	assert_int(ledger.amount(STONE)).is_equal(20)
	assert_int(ledger.total()).is_equal(50)

func test_a_stock_over_capacity_is_clipped_on_creation() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 80, STONE, 80]), 100)
	assert_int(ledger.total()).is_equal(100)

func test_an_exact_cost_is_affordable() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 15]), 100)
	assert_bool(ledger.can_afford(_bundle([WOOD, 15]))).is_true()

## Aucune conversion : manquer d'une seule ressource suffit, quel que soit l'excédent
## des autres. C'est ce qui empêchera un marché implicite de s'installer par accident.
func test_a_surplus_elsewhere_does_not_cover_a_shortfall() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 90, STONE, 2]), 100)
	assert_bool(ledger.can_afford(_bundle([WOOD, 10, STONE, 5]))).is_false()

func test_an_empty_cost_is_always_affordable() -> void:
	assert_bool(Ledger.create(10).can_afford(_bundle([]))).is_true()

# --- ce qui manque, et pourquoi c'est le domaine qui le dit ------------------

## Le manque est un écart et non le coût entier : une réserve qui a la moitié du bois n'en
## réclame que l'autre moitié. C'est ce qu'une fiche affiche, donc l'erreur qui se lirait.
func test_a_shortfall_names_only_what_is_missing_and_by_how_much() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 4, STONE, 9]), 100)
	assert_dict(ledger.shortfall(_bundle([WOOD, 10, STONE, 5]))) \
		.is_equal(_bundle([WOOD, 6]))

## Une ressource jamais possédée manque de son coût entier, et figure quand même : elle
## est le cas le plus fréquent d'un refus au premier tour.
func test_a_resource_never_held_is_missing_whole() -> void:
	assert_dict(Ledger.create(100).shortfall(_bundle([FOOD, 3]))) \
		.is_equal(_bundle([FOOD, 3]))

func test_a_covered_cost_leaves_nothing_missing() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 15]), 100)
	assert_dict(ledger.shortfall(_bundle([WOOD, 15]))).is_empty()

## Les deux questions sont la même, et ce cas est ce qui les empêche de diverger : le jour
## où l'une des deux serait réécrite seule, il tombe. C'est la raison d'être de la forme
## `can_afford() == shortfall().is_empty()` plutôt que de deux boucles jumelles.
func test_affordability_is_exactly_an_empty_shortfall() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 90, STONE, 2]), 100)
	for cost in [_bundle([WOOD, 10, STONE, 5]), _bundle([WOOD, 10]), _bundle([])]:
		assert_bool(ledger.can_afford(cost)) \
			.override_failure_message("can_afford et shortfall ont divergé sur %s" % cost) \
			.is_equal(ledger.shortfall(cost).is_empty())

func test_spending_reduces_every_line_of_the_cost() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 20, STONE, 20]), 100)
	assert_bool(ledger.spend(_bundle([WOOD, 15, STONE, 5]))).is_true()
	assert_int(ledger.amount(WOOD)).is_equal(5)
	assert_int(ledger.amount(STONE)).is_equal(15)

## Tout ou rien. Une dépense partielle laisserait un bâtiment à moitié payé et rien
## pour le dire.
func test_a_refused_spend_mutates_nothing() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 20, STONE, 2]), 100)
	assert_bool(ledger.spend(_bundle([WOOD, 10, STONE, 5]))).is_false()
	assert_int(ledger.amount(WOOD)).is_equal(20)
	assert_int(ledger.amount(STONE)).is_equal(2)

func test_spending_a_resource_never_held_is_refused() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 20]), 100)
	assert_bool(ledger.spend(_bundle([STONE, 1]))).is_false()

## L'invariant : la réserve contient ce qu'elle a, et non des compteurs à zéro.
func test_spending_everything_erases_the_line() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 20]), 100)
	ledger.spend(_bundle([WOOD, 20]))
	assert_dict(ledger.amounts()).is_empty()
	assert_int(ledger.amount(WOOD)).is_equal(0)

## Partiel à dessein, contrairement à spend() : manger la moitié de sa ration est
## exactement ce que la famine veut dire.
func test_taking_more_than_held_takes_what_is_there() -> void:
	var ledger := Ledger.from_stock(_bundle([FOOD, 3]), 100)
	assert_int(ledger.take(FOOD, 8)).is_equal(3)
	assert_int(ledger.amount(FOOD)).is_equal(0)

func test_taking_from_nothing_takes_nothing() -> void:
	assert_int(Ledger.create(100).take(FOOD, 5)).is_equal(0)

func test_taking_less_than_held_leaves_the_rest() -> void:
	var ledger := Ledger.from_stock(_bundle([FOOD, 10]), 100)
	assert_int(ledger.take(FOOD, 4)).is_equal(4)
	assert_int(ledger.amount(FOOD)).is_equal(6)

## Une réserve de capacité nulle est légitime et ne doit pas diviser par zéro.
func test_a_zero_capacity_reserve_accepts_nothing() -> void:
	var ledger := Ledger.create(0)
	assert_dict(ledger.deposit(_bundle([WOOD, 10]))).is_empty()
	assert_int(ledger.total()).is_equal(0)

# --- retrait au prorata -----------------------------------------------------------------

## Le pendant exact de l'écrêtage d'un dépôt : on prend au prorata de ce que chaque
## ressource pèse. Quarante bois et vingt nourritures perdent deux pour un.
func test_a_share_is_taken_in_proportion() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 40, FOOD, 20]), 100)
	var taken := ledger.take_share(6)
	assert_int(taken[WOOD]).is_equal(4)
	assert_int(taken[FOOD]).is_equal(2)
	assert_int(ledger.total()).is_equal(54)

## **Le cas qui compte.** Deux réserves identiques rangées dans un ordre différent perdent
## exactement la même chose — c'est ce que E1 exige de la répartition d'une récolte qui
## déborde, et c'est pour ça que cette règle vit ici plutôt que chez le Combat.
func test_the_order_of_the_reserve_decides_nothing() -> void:
	var forward := Ledger.from_stock(_bundle([WOOD, 40, FOOD, 20]), 100)
	var backward := Ledger.from_stock(_bundle([FOOD, 20, WOOD, 40]), 100)
	assert_dict(backward.take_share(7)).is_equal(forward.take_share(7))

## Prendre plus que le total vide la réserve, sans creuser sous zéro. Un pillage n'a pas à
## savoir ce qu'il y avait.
func test_taking_more_than_the_reserve_holds_empties_it() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 10, FOOD, 5]), 100)
	var taken := ledger.take_share(100)
	assert_int(taken[WOOD]).is_equal(10)
	assert_int(taken[FOOD]).is_equal(5)
	assert_int(ledger.total()).is_equal(0)

func test_taking_nothing_takes_nothing() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 10]), 100)
	assert_dict(ledger.take_share(0)).is_empty()
	assert_int(ledger.amount(WOOD)).is_equal(10)

func test_taking_from_an_empty_reserve_takes_nothing() -> void:
	assert_dict(Ledger.create(100).take_share(10)).is_empty()

## Le total pris est celui demandé, reste de division compris : une part fractionnaire
## perdue ferait qu'une vague emporterait moins que ce qu'elle a percé.
func test_the_whole_demand_is_taken() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 10, FOOD, 10, &"stone", 10]), 100)
	var taken := ledger.take_share(7)
	var total := 0
	for resource in taken:
		total += taken[resource]
	assert_int(total).is_equal(7)

## Une ressource dont la part tombe à zéro n'apparaît pas dans le retrait. L'invariant
## « aucune clé à zéro » vaut pour ce que le Ledger rend comme pour ce qu'il garde.
func test_a_share_rounded_to_nothing_is_not_reported() -> void:
	var ledger := Ledger.from_stock(_bundle([WOOD, 100, FOOD, 1]), 200)
	assert_bool(ledger.take_share(2).has(FOOD)).is_false()

## Lot construit depuis une liste plate — [ressource, quantité, ressource, quantité].
## L'ordre d'insertion est celui de la liste, ce dont deux cas ci-dessus se servent.
func _bundle(flat: Array) -> Dictionary[StringName, int]:
	var bundle: Dictionary[StringName, int] = {}
	var index := 0
	while index < flat.size():
		bundle[flat[index]] = flat[index + 1]
		index += 2
	return bundle
