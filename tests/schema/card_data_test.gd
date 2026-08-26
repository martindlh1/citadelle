class_name CardDataTest
extends GdUnitTestSuite
## La carte et son filet de complétude.
##
## Aucun chiffre de data/ n'est figé : la composition du catalogue bougera à I3, et les
## trois actions non-MVP de DESIGN.md 4.2 y entreront avec X1, X2 et X3. Ce qui est
## asserté, c'est le mécanisme qui refuse une carte inexploitable — et, une fois, que
## data/cards/ le passe.
##
## Le cas qui porte le fichier est celui du bâtiment nommé **dans les deux sens** : une
## carte de bâtiment sans bâtiment n'aurait rien à poser, et une carte d'action qui en
## nommerait un ferait croire à un lien que rien ne suivra. Ni l'un ni l'autre ne casse
## au chargement ; les deux ne casseraient qu'à D2, sous le curseur.

const CARD_ROOT := "res://data/cards"
const BUILDING_ROOT := "res://data/buildings"

func test_a_blank_card_reports_its_three_fields() -> void:
	assert_array(CardData.new().missing_fields()).contains(["id", "label", "pool"])

func test_a_complete_action_reports_nothing() -> void:
	assert_array(_action().missing_fields()).is_empty()

func test_a_complete_building_card_reports_nothing() -> void:
	assert_array(_building_card().missing_fields()).is_empty()

## Un pool hors des trois classerait la carte nulle part : elle serait possédée sans
## jamais pouvoir être piochée.
func test_an_unknown_pool_is_reported() -> void:
	var card := _action()
	card.pool = &"trinket"
	assert_array(card.missing_fields()).contains(["pool.unknown"])

func test_a_building_card_without_a_building_is_reported() -> void:
	var card := _building_card()
	card.building = &""
	assert_array(card.missing_fields()).contains(["building"])

func test_an_action_that_names_a_building_is_reported() -> void:
	var card := _action()
	card.building = &"farm"
	assert_array(card.missing_fields()).contains(["building.unexpected"])

func test_only_a_building_card_places_a_building() -> void:
	assert_bool(_building_card().places_a_building()).is_true()
	assert_bool(_action().places_a_building()).is_false()

func test_the_three_pools_are_known_and_nothing_else() -> void:
	assert_array(CardData.POOLS).contains_exactly(
		[CardData.POOL_ACTION, CardData.POOL_BUILDING, CardData.POOL_POWER])
	assert_bool(CardData.is_known_pool(CardData.POOL_POWER)).is_true()
	assert_bool(CardData.is_known_pool(&"trinket")).is_false()

## Le seul cas qui touche data/, et il n'y fige aucune composition — seulement qu'aucune
## carte n'est inexploitable et que l'identifiant suit le nom du fichier, la convention
## que GameDatabase indexe.
func test_the_cards_of_data_are_exploitable() -> void:
	var seen: Array[String] = []
	for card in _cards_of_data():
		seen.append(String(card.id))
		assert_array(card.missing_fields()) \
			.override_failure_message("carte inexploitable : %s" % card.id) \
			.is_empty()
	assert_array(seen) \
		.override_failure_message("data/cards/ ne contient aucune carte") \
		.is_not_empty()

func test_a_card_of_data_is_named_after_its_file() -> void:
	for file in DirAccess.get_files_at(CARD_ROOT):
		if file.get_extension() != "tres":
			continue
		var card := load("%s/%s" % [CARD_ROOT, file]) as CardData
		assert_str(String(card.id)) \
			.override_failure_message("l'identifiant de %s ne suit pas son nom" % file) \
			.is_equal(file.get_basename())

## Le filet à mailles larges, du motif de production_block_test.gd : sans lui, le jour
## où un pool disparaîtrait entièrement de data/, aucun cas ne broncherait. Le pool des
## powers n'y figure volontairement pas — il est vide jusqu'à X4, et l'exiger ferait
## échouer la suite sur des données correctes.
func test_data_holds_at_least_one_action_and_one_building_card() -> void:
	var actions: Array[StringName] = []
	var buildings: Array[StringName] = []
	for card in _cards_of_data():
		if card.pool == CardData.POOL_ACTION:
			actions.append(card.id)
		elif card.pool == CardData.POOL_BUILDING:
			buildings.append(card.id)
	assert_array(actions) \
		.override_failure_message("aucune carte d'action dans data/cards/") \
		.is_not_empty()
	assert_array(buildings) \
		.override_failure_message("aucune carte de bâtiment dans data/cards/") \
		.is_not_empty()

## Le lien que GameDatabase confronte au boot, vérifié ici aussi : une Resource de
## schéma ne lit jamais l'index, donc une faute de frappe dans `building` ne se voit
## qu'en croisant les deux dossiers.
func test_every_building_card_of_data_names_a_real_building() -> void:
	var known := PackedStringArray()
	for file in DirAccess.get_files_at(BUILDING_ROOT):
		if file.get_extension() == "tres":
			known.append(file.get_basename())
	for card in _cards_of_data():
		if not card.places_a_building():
			continue
		assert_bool(known.has(String(card.building))) \
			.override_failure_message("la carte %s pose un bâtiment inconnu : %s"
				% [card.id, card.building]) \
			.is_true()

func _cards_of_data() -> Array[CardData]:
	var cards: Array[CardData] = []
	for file in DirAccess.get_files_at(CARD_ROOT):
		if file.get_extension() != "tres":
			continue
		var card := load("%s/%s" % [CARD_ROOT, file]) as CardData
		assert_object(card) \
			.override_failure_message("%s n'est pas une CardData" % file) \
			.is_not_null()
		if card != null:
			cards.append(card)
	return cards

func _action() -> CardData:
	var card := CardData.new()
	card.id = &"harvest"
	card.label = "Récolter"
	card.pool = CardData.POOL_ACTION
	return card

func _building_card() -> CardData:
	var card := CardData.new()
	card.id = &"farm"
	card.label = "Ferme"
	card.pool = CardData.POOL_BUILDING
	card.building = &"farm"
	return card
