class_name HandTest
extends GdUnitTestSuite
## La main : trois sections, un ordre fixe, et rien qui remonte vers le Deck.

func test_an_empty_hand_holds_nothing() -> void:
	var hand := Hand.empty()
	assert_int(hand.size()).is_equal(0)
	assert_bool(hand.is_empty()).is_true()
	assert_array(hand.cards()).is_empty()

func test_a_section_keeps_the_order_it_was_drawn_in() -> void:
	assert_array(_hand().cards_in(CardData.POOL_ACTION)) \
		.contains_exactly([&"harvest", &"build", &"harvest"])

## L'ordre entre pools est celui de CardData.POOLS et non celui d'un Dictionary : un
## rapport de harnais doit se comparer d'une phase à l'autre.
func test_the_whole_hand_reads_pool_by_pool() -> void:
	assert_array(_hand().cards()) \
		.contains_exactly([&"harvest", &"build", &"harvest", &"farm"])

func test_a_hand_counts_what_it_holds() -> void:
	var hand := _hand()
	assert_int(hand.size()).is_equal(4)
	assert_int(hand.count_in(CardData.POOL_ACTION)).is_equal(3)
	assert_int(hand.count_in(CardData.POOL_BUILDING)).is_equal(1)
	assert_int(hand.count_in(CardData.POOL_POWER)).is_equal(0)

func test_a_held_card_is_found_whatever_its_pool() -> void:
	var hand := _hand()
	assert_bool(hand.has(&"harvest")).is_true()
	assert_bool(hand.has(&"farm")).is_true()
	assert_bool(hand.has(&"mine")).is_false()

func test_an_unheld_pool_reads_as_empty_rather_than_missing() -> void:
	assert_array(_hand().cards_in(CardData.POOL_POWER)).is_empty()

## La main est une projection figée : ce qui en sort ne doit pas permettre de la
## modifier, sans quoi l'UI de D2 pourrait défausser à la place du Deck.
func test_the_cards_come_out_as_a_copy() -> void:
	var hand := _hand()
	var held := hand.cards_in(CardData.POOL_ACTION)
	held.clear()
	assert_int(hand.count_in(CardData.POOL_ACTION)).is_equal(3)

## Trois actions dont deux exemplaires de la même, un bâtiment, aucun power.
func _hand() -> Hand:
	var by_pool: Dictionary[StringName, Array] = {}
	by_pool[CardData.POOL_ACTION] = [&"harvest", &"build", &"harvest"]
	by_pool[CardData.POOL_BUILDING] = [&"farm"]
	return Hand.create(by_pool)
