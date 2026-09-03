class_name AdjacencyRuleTest
extends GdUnitTestSuite
## La règle d'adjacence : ce qu'elle verse selon son mode, et le filet qui attrape un `.tres`
## mal rempli.
##
## **Elle ne sait pas ce qu'est une unité**, et ce fichier ne le lui demande pas : compter est
## l'affaire d'`Adjacency`, qui voit le terrain. Ce qui est éprouvé ici est le **barème**, et le
## seul mode qui l'infléchit.
##
## Le filet est **complet**, ce qui est rare dans `src/schema/` : zéro est invalide pour
## les cinq champs, donc aucun oubli ne passe. C'est ce que ce fichier vérifie champ par
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

func test_a_rule_straight_out_of_new_names_all_five_fields() -> void:
	assert_array(AdjacencyRule.new().missing_fields()) \
		.contains(["tag", "radius", "resource", "mode", "amount"])

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
	rule.amount = 0
	assert_array(rule.missing_fields()).is_equal(["amount"])

## Le mode est réclamé comme les autres, et il doit l'être : un mode non renseigné vaut UNSET,
## ce qui n'est aucun des trois barèmes — la règle paierait alors comme `PER_CELL` par défaut,
## en silence, sur un `.tres` où quelqu'un voulait dire autre chose.
func test_a_missing_mode_is_named() -> void:
	var rule := _rule()
	rule.mode = AdjacencyRule.Mode.UNSET
	assert_array(rule.missing_fields()).is_equal(["mode"])

# --- les trois barèmes -------------------------------------------------------

## **À la présence, une case ou dix paient pareil.** C'est la ferme : irriguer est une affaire
## d'accès, pas de quantité, et un bonus par case aurait primé le fait de border un lac sur
## trois côtés.
func test_a_flat_rule_pays_once_however_much_it_finds() -> void:
	var rule := _rule()
	rule.mode = AdjacencyRule.Mode.FLAT
	rule.amount = 6
	assert_int(rule.award(1)).is_equal(6)
	assert_int(rule.award(9)).is_equal(6)

## Et rien du tout quand elle ne trouve rien : le mode change le barème, jamais l'exigence.
func test_a_flat_rule_that_finds_nothing_pays_nothing() -> void:
	var rule := _rule()
	rule.mode = AdjacencyRule.Mode.FLAT
	assert_int(rule.award(0)).is_equal(0)

## Le filon paie comme le mode par case : ce qui change est **ce qu'on lui compte**, et c'est
## `Adjacency` qui le décide en voyant le terrain. Le barème, lui, est le même.
func test_a_vein_rule_pays_per_unit_like_the_per_cell_one() -> void:
	var vein := _rule()
	vein.mode = AdjacencyRule.Mode.VEIN
	assert_int(vein.award(11)).is_equal(_rule().award(11))

# --- le montage --------------------------------------------------------------

## +1 bois par case de forêt à un anneau.
func _rule() -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	rule.tag = &"forest"
	rule.radius = 1
	rule.resource = &"wood"
	rule.mode = AdjacencyRule.Mode.PER_CELL
	rule.amount = 1
	return rule
