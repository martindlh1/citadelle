class_name AdjacencyRuleTest
extends GdUnitTestSuite
## La règle d'adjacence : ce qu'elle verse, et le filet qui attrape un `.tres` mal rempli.
##
## Le filet est **complet** ici, ce qui est rare dans `src/schema/` : zéro est invalide pour
## les quatre champs, donc aucun oubli ne passe. C'est ce que ce fichier vérifie champ par
## champ — une règle creuse ne casse jamais au chargement, elle rend zéro pour toujours sur un
## bâtiment qui semble bien posé.

# --- ce qu'elle verse -----------------------------------------------------

func test_each_cell_pays_what_the_rule_says() -> void:
	assert_int(_rule().award(2)).is_equal(2)

func test_nothing_found_pays_nothing() -> void:
	assert_int(_rule().award(0)).is_equal(0)

## **Rien ne borne le produit.** Une première version le plafonnait, et le plafond est parti le
## jour où le voisinage est devenu la seule source de production : deux cases à deux arbres et à
## dix arbres qui rendent la même chose, c'est le choix de la case qui cesse de compter.
func test_ten_cells_pay_ten_times_one() -> void:
	assert_int(_rule().award(10)).is_equal(10 * _rule().award(1))

# --- le filet ----------------------------------------------------------------

func test_a_filled_rule_lacks_nothing() -> void:
	assert_array(_rule().missing_fields()).is_empty()

func test_a_rule_straight_out_of_new_names_all_four_fields() -> void:
	assert_array(AdjacencyRule.new().missing_fields()) \
		.contains(["tag", "radius", "resource", "per_cell"])

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

## +1 bois par case de forêt à un anneau.
func _rule() -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	rule.tag = &"forest"
	rule.radius = 1
	rule.resource = &"wood"
	rule.per_cell = 1
	return rule
