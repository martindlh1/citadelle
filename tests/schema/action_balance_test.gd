class_name ActionBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage des actions à cru, et son filet de complétude.
##
## Aucun chiffre n'est figé : la capacité et le rendement d'une case nue sont exactement
## le genre de valeur que I3 fera bouger. Ce qui est asserté, c'est qu'un bloc
## inexploitable se voit, et que la table imbriquée du .tres arrive vraiment jusqu'au
## domaine.
##
## Ce dernier point est le cas qui porte le fichier. `bare_sources` est le seul
## Dictionary de Dictionary du projet : GDScript ne sait pas typer l'imbriqué, donc rien
## dans le schéma ne garantit que le .tres l'a bien écrit. Sans ce cas, une table mal
## formée se chargerait vide, `missing_fields()` la rattraperait peut-être — et si elle
## se chargeait à moitié, personne ne dirait rien : les actions à cru cesseraient
## simplement de se poser.

const BALANCE_PATH := "res://data/balance/action_balance.tres"
const HARVEST := &"harvest"
const HUNT := &"hunt"
const FOREST := &"forest"

func test_a_blank_block_reports_everything() -> void:
	assert_array(ActionBalance.new().missing_fields()) \
		.contains(["bare_capacity", "bare_yield", "bare_skill_family", "slot_cards",
			"bare_sources"])

func test_a_complete_block_reports_nothing() -> void:
	assert_array(_filled().missing_fields()).is_empty()

func test_a_zero_capacity_is_reported() -> void:
	var balance := _filled()
	balance.bare_capacity = 0
	assert_array(balance.missing_fields()).contains(["bare_capacity"])

func test_a_zero_yield_is_reported() -> void:
	var balance := _filled()
	balance.bare_yield = 0
	assert_array(balance.missing_fields()).contains(["bare_yield"])

func test_a_missing_family_is_reported() -> void:
	var balance := _filled()
	balance.bare_skill_family = &""
	assert_array(balance.missing_fields()).contains(["bare_skill_family"])

## Aucune carte ne tiendrait de poste, donc aucun bâtiment ne produirait jamais rien.
## C'est une panne totale et silencieuse, ce qui est exactement ce que le boot rattrape.
func test_an_empty_slot_card_list_is_reported() -> void:
	var balance := _filled()
	balance.slot_cards = []
	assert_array(balance.missing_fields()).contains(["slot_cards"])

## La question que le résolveur pose avant toute autre sur un bâtiment. Sans elle, il ne
## lui resterait que « ce bâtiment produit-il ? », et *Construire* posé sur une ferme
## achevée en tirerait une récolte.
func test_only_the_named_cards_work_a_slot() -> void:
	var balance := _filled()
	assert_bool(balance.works_a_slot(HARVEST)).is_true()
	assert_bool(balance.works_a_slot(&"build")).is_false()
	assert_bool(balance.works_a_slot(&"terraform")).is_false()

## Une carte à cru sans aucun tag ne pourrait se poser nulle part. Ce n'est pas « elle
## ne se joue pas à cru », qui s'écrit en l'omettant, c'est une ligne qui ne veut rien
## dire.
func test_a_card_with_an_empty_source_table_is_reported() -> void:
	var balance := _filled()
	balance.bare_sources[HUNT] = {}
	assert_array(balance.missing_fields()).contains(["bare_sources.hunt"])

func test_a_source_naming_no_resource_is_reported() -> void:
	var balance := _filled()
	balance.bare_sources[HARVEST] = {FOREST: &""}
	assert_array(balance.missing_fields()).contains(["bare_sources.harvest.forest"])

## Une carte absente de la table ne se joue pas à cru, et c'est une réponse et non un
## oubli. C'est par cette absence que *Construire* et *Terraformer* sortent de la
## production sans que le résolveur ait à les nommer.
func test_a_card_absent_from_the_table_simply_does_not_play_bare() -> void:
	var balance := _filled()
	assert_bool(balance.is_bare_card(&"terraform")).is_false()
	assert_dict(balance.sources_for(&"terraform")).is_empty()
	assert_array(balance.missing_fields()).is_empty()

func test_sources_come_out_typed_and_copied() -> void:
	var balance := _filled()
	var sources := balance.sources_for(HARVEST)
	assert_int(sources.size()).is_equal(1)
	assert_str(sources[FOREST]).is_equal(&"wood")
	sources[&"stone"] = &"stone"
	assert_int(balance.sources_for(HARVEST).size()).is_equal(1)

## Le cas du fichier : la table imbriquée du .tres arrive entière jusqu'au domaine.
##
## Deux cartes s'y jouent à cru, et l'une d'elles tire trois ressources de trois tags
## différents. Une table qui se chargerait vide ou à moitié se verrait ici, et nulle
## part ailleurs.
func test_the_real_file_carries_a_readable_nested_table() -> void:
	var balance := load(BALANCE_PATH) as ActionBalance
	assert_object(balance).is_not_null()
	assert_array(balance.missing_fields()).is_empty()
	assert_bool(balance.is_bare_card(HARVEST)).is_true()
	assert_bool(balance.is_bare_card(HUNT)).is_true()
	var harvest := balance.sources_for(HARVEST)
	assert_int(harvest.size()).is_greater_equal(2)
	assert_str(harvest[FOREST]).is_equal(&"wood")
	assert_str(balance.sources_for(HUNT)[FOREST]).is_equal(&"food")

## Chaîné depuis data/balance/balance.tres : un .tres déplacé ou renommé priverait le
## ciblage de ses règles sans casser le chargement de l'équilibrage.
func test_the_block_is_wired_into_the_balance_root() -> void:
	var balance := load("res://data/balance/balance.tres") as BalanceData
	assert_object(balance.actions).is_not_null()
	assert_object(balance.actions).is_instanceof(ActionBalance)

## Un bloc renseigné à la main, sans passer par data/ : les cas ci-dessus le tordent, et
## un .tres dupliqué garderait une référence sur la ressource chargée.
func _filled() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = 1
	balance.bare_yield = 1
	balance.bare_skill_family = HARVEST
	var slots: Array[StringName] = [HARVEST]
	balance.slot_cards = slots
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[HARVEST] = {FOREST: &"wood"}
	sources[HUNT] = {FOREST: &"food"}
	balance.bare_sources = sources
	return balance
