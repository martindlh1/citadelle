class_name AdjacencyRuleTest
extends GdUnitTestSuite
## La règle d'adjacence : son plafond, et le filet qui attrape un `.tres` mal rempli.
##
## Le filet est **complet** ici, ce qui est rare dans `src/schema/` : zéro est invalide pour
## les cinq champs, donc aucun oubli ne passe. C'est ce que ce fichier vérifie champ par
## champ — une règle creuse ne casse jamais au chargement, elle rend zéro pour toujours sur un
## bâtiment qui semble bien posé.

# --- le plafond --------------------------------------------------------------

func test_each_cell_pays_what_the_rule_says() -> void:
	assert_int(_rule().award(2)).is_equal(2)

func test_nothing_found_pays_nothing() -> void:
	assert_int(_rule().award(0)).is_equal(0)

## **Le plafond, et c'est la raison d'être du cinquième champ.** Une cabane au milieu d'un
## bosquet voit ses huit voisines : sans lui, le placement cesserait d'être un choix pour
## devenir un gros lot.
func test_the_cap_holds() -> void:
	assert_int(_rule().award(8)).is_equal(3)

## Un plafond sous le rendement d'une seule case le rabote dès la première. C'est une valeur
## permise plutôt qu'une incohérence : « une case ou dix, c'est pareil » est une règle qu'un
## `.tres` a le droit d'écrire.
func test_a_cap_below_one_cell_clips_from_the_first() -> void:
	var rule := _rule()
	rule.per_cell = 5
	rule.at_most = 2
	assert_int(rule.award(1)).is_equal(2)

# --- le filet ----------------------------------------------------------------

func test_a_filled_rule_lacks_nothing() -> void:
	assert_array(_rule().missing_fields()).is_empty()

func test_a_rule_straight_out_of_new_names_all_five_fields() -> void:
	assert_array(AdjacencyRule.new().missing_fields()) \
		.contains(["tag", "radius", "resource", "per_cell", "at_most"])

func test_a_missing_tag_is_named() -> void:
	var rule := _rule()
	rule.tag = &""
	assert_array(rule.missing_fields()).is_equal(["tag"])

func test_a_missing_resource_is_named() -> void:
	var rule := _rule()
	rule.resource = &""
	assert_array(rule.missing_fields()).is_equal(["resource"])

func test_a_zero_yield_is_named() -> void:
	var rule := _rule()
	rule.per_cell = 0
	assert_array(rule.missing_fields()).is_equal(["per_cell"])

# --- le montage --------------------------------------------------------------

## +1 bois par case de forêt à un anneau, au plus 3.
func _rule() -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	rule.tag = &"forest"
	rule.radius = 1
	rule.resource = &"wood"
	rule.per_cell = 1
	rule.at_most = 3
	return rule
