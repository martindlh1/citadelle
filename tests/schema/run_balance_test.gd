class_name RunBalanceTest
extends GdUnitTestSuite
## Ce que le bloc de run réclame, et ce qu'il laisse vide exprès.
##
## Il ne fige aucun chiffre de data/ : ceux-là bougent à chaque passe d'équilibrage, et un
## test qui les épinglerait serait cassé en permanence. Il fige les **règles** — ce qui doit
## être renseigné, ce qui a le droit de ne pas l'être, et le filet qui rattrape la
## disparition du barème entier.

## Bloc complet, sur lequel chaque cas retire une chose et une seule.
##
## Fabriqué et non chargé depuis data/ : un cas qui partirait du .tres réel mesurerait
## l'équilibrage du jour plutôt que la règle. C'est balance_data_test.gd qui regarde le
## fichier, et lui seul.
func _balance() -> RunBalance:
	var balance := RunBalance.new()
	balance.turns = 20
	balance.starting_building = &"heart"
	balance.score_per_resource = 1
	balance.score_per_building = 5
	balance.score_per_inhabitant = 10
	balance.score_per_heart_hit_point = 2
	return balance

func test_a_complete_block_reports_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

# --- ce qui est réclamé ------------------------------------------------------

func test_a_run_without_turns_is_reported() -> void:
	var balance := _balance()
	balance.turns = 0
	assert_array(balance.missing_fields()).contains(["turns"])

# --- ce qui a le droit d'être vide -------------------------------------------

## Vide est une réponse : c'est le run d'un harnais qui veut une carte nue et pas de
## fondation. Le cas est écrit pour que personne ne réclame le champ en croyant corriger un
## oubli.
func test_a_run_without_a_starting_building_is_complete() -> void:
	var balance := _balance()
	balance.starting_building = &""
	assert_array(balance.missing_fields()).is_empty()

## Un poids nul est un choix d'équilibrage lisible — « la thésaurisation ne vaut pas de
## points » — et le réclamer interdirait de l'essayer sans toucher au GDScript.
func test_a_single_weight_left_at_zero_is_complete() -> void:
	var balance := _balance()
	balance.score_per_resource = 0
	assert_array(balance.missing_fields()).is_empty()

# --- le filet qui rattrape la disparition du barème --------------------------

## Quatre poids nuls ne sont pas quatre réglages : c'est un run qui vaut zéro quoi qu'on y
## fasse, donc la disparition d'un format. Le contrôle est écrit un cran au-dessus des
## champs pour cette raison, exactement comme celui qui exige qu'un bâtiment loge sans
## coûter de bras vit au-dessus de BuildingData.
func test_a_score_where_nothing_counts_is_reported() -> void:
	var balance := _balance()
	balance.score_per_resource = 0
	balance.score_per_building = 0
	balance.score_per_inhabitant = 0
	balance.score_per_heart_hit_point = 0
	assert_array(balance.missing_fields()).contains(["score.none_counts"])

## Le pendant du précédent, et il compte autant : le filet doit se lever dès qu'**un** terme
## compte, sinon il ne rattrape pas une disparition mais interdit un réglage. Chacun des
## quatre est essayé seul, parce que celui du Cœur est le seul dont rien ne fait varier la
## valeur avant V4 et qu'un « et » écrit de travers ne se verrait que sur lui.
func test_any_single_weight_lifts_the_net() -> void:
	for weight in ["score_per_resource", "score_per_building", "score_per_inhabitant",
			"score_per_heart_hit_point"]:
		var balance := _balance()
		balance.score_per_resource = 0
		balance.score_per_building = 0
		balance.score_per_inhabitant = 0
		balance.score_per_heart_hit_point = 0
		balance.set(weight, 1)
		assert_array(balance.missing_fields()) \
			.override_failure_message("%s seul ne suffit pas à lever le filet" % weight) \
			.is_empty()
