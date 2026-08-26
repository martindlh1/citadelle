class_name CardCatalogueTest
extends GdUnitTestSuite
## Le catalogue : ce qu'une carte est, et rien sur qui la possède.
##
## Aucune carte de data/ n'est chargée ici : les cartes sont fabriquées à la main, comme
## les bâtiments de production_resolver_test.gd et pour la même raison — le contenu de
## data/cards/ bougera à I3, le mécanisme non.

func test_an_empty_catalogue_knows_nothing() -> void:
	var catalogue := CardCatalogue.empty()
	assert_int(catalogue.size()).is_equal(0)
	assert_bool(catalogue.has(&"harvest")).is_false()
	assert_array(catalogue.ids()).is_empty()

func test_a_named_card_comes_back() -> void:
	var catalogue := _catalogue()
	assert_bool(catalogue.has(&"farm")).is_true()
	assert_bool(catalogue.has(&"zeppelin")).is_false()
	assert_str(catalogue.card(&"farm").label).is_equal("farm")

func test_a_catalogue_keeps_the_order_it_was_given() -> void:
	assert_array(_catalogue().ids()) \
		.contains_exactly([&"harvest", &"hunt", &"build", &"farm", &"house", &"blessing"])

func test_a_card_says_which_pool_it_lives_in() -> void:
	var catalogue := _catalogue()
	assert_str(catalogue.pool_of(&"hunt")).is_equal(CardData.POOL_ACTION)
	assert_str(catalogue.pool_of(&"house")).is_equal(CardData.POOL_BUILDING)
	assert_str(catalogue.pool_of(&"blessing")).is_equal(CardData.POOL_POWER)

## Les trois pools se draftent séparément, donc le catalogue doit savoir les séparer
## sans que l'appelant filtre lui-même.
func test_a_pool_yields_only_its_own_cards_in_order() -> void:
	var catalogue := _catalogue()
	assert_array(catalogue.ids_in(CardData.POOL_ACTION)) \
		.contains_exactly([&"harvest", &"hunt", &"build"])
	assert_array(catalogue.ids_in(CardData.POOL_BUILDING)) \
		.contains_exactly([&"farm", &"house"])

## Le pool des powers est vide jusqu'à X4 et doit répondre sans casser : c'est le cas
## normal, pas une erreur.
func test_a_pool_without_cards_yields_nothing() -> void:
	var actions: Array[CardData] = [_card(&"harvest", CardData.POOL_ACTION)]
	assert_array(CardCatalogue.create(actions).ids_in(CardData.POOL_POWER)).is_empty()

## Le tableau rendu est une copie : le catalogue est immuable, et ce qui en sort ne doit
## pas ouvrir un chemin vers ses entrailles.
func test_the_ids_come_out_as_a_copy() -> void:
	var catalogue := _catalogue()
	var ids := catalogue.ids()
	ids.clear()
	assert_int(catalogue.ids().size()).is_equal(6)

## Trois actions, deux bâtiments, un power — de quoi exercer les trois pools.
func _catalogue() -> CardCatalogue:
	var cards: Array[CardData] = [
		_card(&"harvest", CardData.POOL_ACTION),
		_card(&"hunt", CardData.POOL_ACTION),
		_card(&"build", CardData.POOL_ACTION),
		_card(&"farm", CardData.POOL_BUILDING),
		_card(&"house", CardData.POOL_BUILDING),
		_card(&"blessing", CardData.POOL_POWER),
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
