class_name DeckBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage du deck, et son filet de complétude.
##
## Aucun chiffre n'est figé : le deck de départ et les trois tailles de main sont
## exactement ce que DESIGN.md 3.5 garde sous un OUVERT, et ils bougeront au premier
## playtest de la boucle. Ce qui est asserté, c'est qu'un bloc inexploitable se voit.
##
## Le cas qui porte le fichier est **le zéro légitime du pool des powers**. C'est la
## seule raison pour laquelle les tailles de main vivent dans une table plutôt qu'en
## trois champs plats : la présence de la clé vaut déclaration, donc un pool omis se
## rattrape alors qu'un zéro écrit reste une réponse valable. Trois champs plats
## auraient rendu les deux situations indiscernables.

const BALANCE_PATH := "res://data/balance/deck_balance.tres"
const CARD_ROOT := "res://data/cards"

func test_a_blank_block_reports_everything() -> void:
	assert_array(DeckBalance.new().missing_fields()) \
		.contains(["draft_choices", "starting_deck",
			"hand_size.action", "hand_size.building", "hand_size.power",
			"carry_over.action", "carry_over.building", "carry_over.power"])

func test_a_complete_block_reports_nothing() -> void:
	assert_array(_filled().missing_fields()).is_empty()

## Le cas du fichier. Le pool des powers est vide jusqu'à X4 : en piocher zéro est une
## réponse, pas un oubli.
func test_a_pool_drawing_nothing_is_complete() -> void:
	var balance := _filled()
	assert_int(balance.hand_size[CardData.POOL_POWER]).is_equal(0)
	assert_array(balance.missing_fields()).is_empty()

## Son revers, et ce que la table achète : un pool absent de la table est un pool qu'on
## ne piocherait jamais sans que rien ne le dise.
func test_a_missing_pool_is_reported() -> void:
	var balance := _filled()
	balance.hand_size.erase(CardData.POOL_BUILDING)
	assert_array(balance.missing_fields()).contains(["hand_size.building"])

func test_an_unknown_pool_is_reported() -> void:
	var balance := _filled()
	balance.hand_size[&"trinket"] = 2
	assert_array(balance.missing_fields()).contains(["hand_size.trinket.unknown"])

func test_a_negative_hand_is_reported() -> void:
	var balance := _filled()
	balance.hand_size[CardData.POOL_ACTION] = -1
	assert_array(balance.missing_fields()).contains(["hand_size.action"])

## Trois pools déclarés et pas une carte piochée : la phase ne distribuerait rien du
## tout, et l'écran de main resterait vide sans que rien ne casse.
func test_a_table_that_draws_nothing_at_all_is_reported() -> void:
	var balance := _filled()
	balance.hand_size[CardData.POOL_ACTION] = 0
	balance.hand_size[CardData.POOL_BUILDING] = 0
	assert_array(balance.missing_fields()).contains(["hand_size.all_zero"])

# --- Le report de main ------------------------------------------------------------------

## Le bouton de l'`OUVERT` de DESIGN.md 3.5, et les deux seules valeurs qu'il accepte.
##
## Zéro défausse tout — la boucle depuis `I1`. `hand_size` garde tout — la main persistante.
## Les deux se lisent dans le même fichier et se croisent, ce qu'un booléen n'aurait pas
## permis puisque « tout garder » n'est pas le même nombre d'un pool à l'autre.
func test_both_playable_carry_settings_are_complete() -> void:
	var balance := _filled()
	balance.carry_over[CardData.POOL_ACTION] = 0
	assert_array(balance.missing_fields()).is_empty()
	balance.carry_over[CardData.POOL_ACTION] = balance.hand_size[CardData.POOL_ACTION]
	assert_array(balance.missing_fields()).is_empty()

## Le cas qui porte le champ. Garder deux cartes sur cinq demande de dire *lesquelles*, et
## aucun écran ne sait le demander : le milieu est refusé **structurellement** plutôt que
## résolu par une règle d'ancienneté qui choisirait à la place du joueur. Le jour où le
## geste existe, c'est ce contrôle-ci qui se desserre, et rien d'autre.
func test_a_partial_carry_is_reported() -> void:
	var balance := _filled()
	balance.carry_over[CardData.POOL_ACTION] = 2
	assert_array(balance.missing_fields()).contains(["carry_over.action.partial"])

## Garder plus que ce qu'on tient ne veut rien dire : la pioche complète jusqu'à
## `hand_size`, donc la main ne dépasse jamais ce plafond. Même doctrine qu'un exemplaire
## à zéro dans le deck de départ — une ligne qui ne dit rien est une faute de contenu.
func test_a_carry_above_the_hand_is_reported() -> void:
	var balance := _filled()
	balance.carry_over[CardData.POOL_ACTION] = 6
	assert_array(balance.missing_fields()).contains(["carry_over.action.above_the_hand"])

## Le pool des powers pioche zéro et reporte zéro : les deux valeurs se confondent, et
## c'est le seul endroit où elles le peuvent. Ni `partial` ni `above_the_hand` ne doit s'y
## déclencher, sans quoi le bloc livré serait refusé au boot pour un pool vide.
func test_a_pool_that_draws_nothing_carries_nothing_without_complaint() -> void:
	var balance := _filled()
	assert_int(balance.carry_over[CardData.POOL_POWER]).is_equal(0)
	assert_array(balance.missing_fields()).is_empty()

func test_a_missing_carry_pool_is_reported() -> void:
	var balance := _filled()
	balance.carry_over.erase(CardData.POOL_BUILDING)
	assert_array(balance.missing_fields()).contains(["carry_over.building"])

func test_an_unknown_carry_pool_is_reported() -> void:
	var balance := _filled()
	balance.carry_over[&"trinket"] = 0
	assert_array(balance.missing_fields()).contains(["carry_over.trinket.unknown"])

func test_a_negative_carry_is_reported() -> void:
	var balance := _filled()
	balance.carry_over[CardData.POOL_ACTION] = -1
	assert_array(balance.missing_fields()).contains(["carry_over.action"])

## Un `hand_size` en défaut se signale une fois, pas deux. Sans ce cas, une main négative
## rendrait aussi un `carry_over` incohérent, et on chercherait deux défauts là où il n'y
## en a qu'un.
func test_a_broken_hand_does_not_also_break_the_carry() -> void:
	var balance := _filled()
	balance.hand_size[CardData.POOL_ACTION] = -1
	var missing := balance.missing_fields()
	assert_array(missing).contains(["hand_size.action"])
	assert_array(missing).not_contains(["carry_over.action.above_the_hand"])
	assert_array(missing).not_contains(["carry_over.action.partial"])

func test_an_empty_starting_deck_is_reported() -> void:
	var balance := _filled()
	balance.starting_deck = {}
	assert_array(balance.missing_fields()).contains(["starting_deck"])

## Zéro exemplaire n'est pas une carte absente du deck, c'est une ligne qui ne veut rien
## dire — même doctrine qu'un rendement à zéro dans un ProductionBlock.
func test_a_card_without_copies_is_reported() -> void:
	var balance := _filled()
	balance.starting_deck[&"harvest"] = 0
	assert_array(balance.missing_fields()).contains(["starting_deck.harvest"])

func test_a_draft_without_choices_is_reported() -> void:
	var balance := _filled()
	balance.draft_choices = 0
	assert_array(balance.missing_fields()).contains(["draft_choices"])

## Le seul cas qui touche data/. Il ne fige aucun chiffre : il exige que le fichier soit
## exploitable et que le deck de départ ne nomme que des cartes qui existent — le lien
## qu'une Resource de schéma ne peut pas vérifier seule, puisqu'elle ne lit jamais
## l'index.
func test_the_deck_balance_of_data_is_exploitable() -> void:
	var balance := load(BALANCE_PATH) as DeckBalance
	assert_object(balance) \
		.override_failure_message("%s n'est pas une DeckBalance" % BALANCE_PATH) \
		.is_not_null()
	assert_array(balance.missing_fields()) \
		.override_failure_message("bloc de deck inexploitable dans data/balance/") \
		.is_empty()
	var known := PackedStringArray()
	for file in DirAccess.get_files_at(CARD_ROOT):
		if file.get_extension() == "tres":
			known.append(file.get_basename())
	for card in balance.starting_deck:
		assert_bool(known.has(String(card))) \
			.override_failure_message("le deck de départ nomme une carte inconnue : %s" % card) \
			.is_true()

## Deux actions, un bâtiment, trois tailles de main dont celle des powers à zéro.
func _filled() -> DeckBalance:
	var balance := DeckBalance.new()
	var deck: Dictionary[StringName, int] = {}
	deck[&"harvest"] = 4
	deck[&"build"] = 2
	deck[&"farm"] = 1
	balance.starting_deck = deck
	var hand: Dictionary[StringName, int] = {}
	hand[CardData.POOL_ACTION] = 5
	hand[CardData.POOL_BUILDING] = 2
	hand[CardData.POOL_POWER] = 0
	balance.hand_size = hand
	var carry: Dictionary[StringName, int] = {}
	carry[CardData.POOL_ACTION] = 0
	carry[CardData.POOL_BUILDING] = 0
	carry[CardData.POOL_POWER] = 0
	balance.carry_over = carry
	balance.draft_choices = 3
	return balance
