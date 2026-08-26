class_name RunOutcomeTest
extends GdUnitTestSuite
## Comment un run s'est terminé, et ce qu'il valait.
##
## `DESIGN.md` 5 en entier : deux défaites, une victoire, et un score sur « ressources,
## bâtiments intacts, ouvriers vivants et leur niveau ».
##
## **Aucun poids n'est figé.** Les quatre vivent dans `data/balance/` et `I3` les réglera
## devant un run entier ; ce qui se vérifie ici est que chacun **compte**, et qu'il compte
## le terme qu'il annonce. Un cas qui écrirait « un entrepôt vaut dix » rendrait
## l'équilibrage plus coûteux qu'il ne doit l'être, et c'est exactement ce que les suites de
## ce projet refusent de faire depuis `E1`.

const DAY := 7

func test_the_score_weighs_each_term() -> void:
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, DAY, 10, 3, 4, 6,
		_balance(1, 10, 100, 1000))
	assert_int(outcome.score()).is_equal(10 * 1 + 3 * 10 + 4 * 100 + 6 * 1000)

## Chaque poids ne touche que son terme. Sans ce cas, deux poids intervertis donneraient le
## même total sur des comptes symétriques et personne ne le verrait.
func test_each_weight_moves_only_its_own_term() -> void:
	var counts := [11, 13, 17, 19]
	var flat := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, DAY, counts[0], counts[1],
		counts[2], counts[3], _balance(1, 1, 1, 1))
	assert_int(flat.score()).is_equal(11 + 13 + 17 + 19)
	var heavier := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, DAY, counts[0], counts[1],
		counts[2], counts[3], _balance(2, 1, 1, 1))
	assert_int(heavier.score() - flat.score()).is_equal(counts[0])

## Un poids nul est un choix d'équilibrage lisible : « la thésaurisation ne rapporte rien ».
func test_a_zero_weight_drops_its_term() -> void:
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, DAY, 50, 1, 1, 1,
		_balance(0, 1, 1, 1))
	assert_int(outcome.score()).is_equal(3)

## Les quatre comptes restent lisibles à côté du total : un écran de fin qui n'annoncerait
## qu'un nombre ne dirait pas *ce qui* l'a fait, et les redéduire en divisant par les poids
## serait une seconde arithmétique à tenir d'accord avec celle-ci.
func test_the_counts_survive_next_to_the_total() -> void:
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, DAY, 10, 3, 4, 6,
		_balance(1, 1, 1, 1))
	assert_int(outcome.resources()).is_equal(10)
	assert_int(outcome.buildings()).is_equal(3)
	assert_int(outcome.workers()).is_equal(4)
	assert_int(outcome.levels()).is_equal(6)
	assert_int(outcome.day()).is_equal(DAY)

## La victoire se **déduit** de la cause plutôt que d'être portée à côté : deux champs qui
## peuvent se contredire laisseraient exister une défaite victorieuse. Même geste que
## `DamageReport.fighters()`, qui se déduit du journal au lieu de vivre en double.
func test_only_surviving_is_a_victory() -> void:
	assert_bool(_ended(RunOutcome.CAUSE_SURVIVED).is_victory()).is_true()
	assert_bool(_ended(RunOutcome.CAUSE_HEART).is_victory()).is_false()
	assert_bool(_ended(RunOutcome.CAUSE_ROSTER).is_victory()).is_false()

## Une défaite compte comme une victoire : un run perdu au jour douze vaut plus qu'un run
## perdu au jour deux, et `DESIGN.md` 5 ne dit nulle part que le score serait réservé aux
## vainqueurs.
func test_a_defeat_is_still_worth_what_it_left_standing() -> void:
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_HEART, DAY, 10, 0, 2, 3,
		_balance(1, 1, 1, 1))
	assert_int(outcome.score()).is_equal(15)

## Un compte négatif n'a pas de sens et ne doit pas pouvoir **retirer** des points : un
## terme qui déduirait ferait d'un run vide un meilleur score qu'un run désastreux.
func test_a_negative_count_cannot_take_points_away() -> void:
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_ROSTER, DAY, -50, 0, 0, 0,
		_balance(1, 1, 1, 1))
	assert_int(outcome.resources()).is_equal(0)
	assert_int(outcome.score()).is_equal(0)

func _ended(cause: StringName) -> RunOutcome:
	return RunOutcome.tally(cause, DAY, 1, 1, 1, 1, _balance(1, 1, 1, 1))

func _balance(per_resource: int, per_building: int, per_worker: int,
		per_level: int) -> RunBalance:
	var balance := RunBalance.new()
	balance.score_per_resource = per_resource
	balance.score_per_building = per_building
	balance.score_per_worker = per_worker
	balance.score_per_worker_level = per_level
	return balance
