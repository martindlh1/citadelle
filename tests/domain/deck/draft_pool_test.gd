class_name DraftPoolTest
extends GdUnitTestSuite
## L'offre d'un draft : distincte, tirée d'un seul pool, et rejouable sur un seed.

const SEED := 20260825
const OTHER_SEED := 41

func test_an_offer_holds_as_many_cards_as_asked() -> void:
	assert_int(_offer(3, SEED).size()).is_equal(3)

## Une offre où la même carte apparaîtrait deux fois ne serait pas un choix.
func test_an_offer_never_repeats_a_card() -> void:
	var offer := _offer(4, SEED)
	var seen: Dictionary[StringName, bool] = {}
	for card in offer:
		assert_bool(seen.has(card)) \
			.override_failure_message("carte offerte deux fois : %s" % card) \
			.is_false()
		seen[card] = true

## Les pools se draftent séparément : une offre d'actions ne montre jamais un bâtiment.
func test_an_offer_comes_from_the_asked_pool_only() -> void:
	var catalogue := _catalogue()
	for card in DraftPool.offer(catalogue, CardData.POOL_ACTION, 3, _rng(SEED)):
		assert_str(catalogue.pool_of(card)).is_equal(CardData.POOL_ACTION)

## Un pool épuisé rend moins que demandé, jusqu'à rien : ce n'est pas une erreur.
func test_an_offer_stops_at_what_the_pool_holds() -> void:
	assert_int(_offer(20, SEED).size()).is_equal(4)

func test_an_empty_pool_offers_nothing() -> void:
	assert_array(DraftPool.offer(_catalogue(), CardData.POOL_POWER, 3, _rng(SEED))) \
		.is_empty()

func test_an_offer_of_no_card_is_empty() -> void:
	assert_array(_offer(0, SEED)).is_empty()

func test_an_excluded_card_is_never_offered() -> void:
	var excluded: Array[StringName] = [&"harvest", &"hunt"]
	var offer := DraftPool.offer(_catalogue(), CardData.POOL_ACTION, 4, _rng(SEED), excluded)
	assert_array(offer).contains_exactly_in_any_order([&"build", &"terraform"])

func test_the_same_seed_offers_the_same_cards() -> void:
	assert_array(_offer(3, SEED)).contains_exactly(_offer(3, SEED))

## Son complément : sans lui, une offre qui rendrait toujours les premières cartes du
## catalogue passerait le précédent.
func test_another_seed_offers_another_hand() -> void:
	assert_bool(_offer(3, SEED) == _offer(3, OTHER_SEED)).is_false()

func _offer(count: int, rng_seed: int) -> Array[StringName]:
	return DraftPool.offer(_catalogue(), CardData.POOL_ACTION, count, _rng(rng_seed))

## Quatre actions — assez pour qu'une offre de trois ait de quoi varier — et deux
## bâtiments, pour que le filtre par pool ait quelque chose à écarter.
func _catalogue() -> CardCatalogue:
	var cards: Array[CardData] = [
		_card(&"harvest", CardData.POOL_ACTION),
		_card(&"hunt", CardData.POOL_ACTION),
		_card(&"build", CardData.POOL_ACTION),
		_card(&"terraform", CardData.POOL_ACTION),
		_card(&"farm", CardData.POOL_BUILDING),
		_card(&"house", CardData.POOL_BUILDING),
	]
	return CardCatalogue.create(cards)

func _card(id: StringName, pool: StringName) -> CardData:
	var card := CardData.new()
	card.id = id
	card.label = String(id)
	card.pool = pool
	if pool == CardData.POOL_BUILDING:
		card.building = id
	return card

func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
