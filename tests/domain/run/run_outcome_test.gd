class_name RunOutcomeTest
extends GdUnitTestSuite
## Le verdict d'un run : sa cause, ses quatre termes, et leur somme.
##
## Il ne fige aucun poids de data/ — ceux-là sont l'affaire de B1. Il fige que chaque terme
## soit **bien celui que son poids multiplie**, ce qu'une somme de quatre produits rend
## facile à écrire de travers sans que rien ne le dise : quatre entiers additionnés se
## trompent en silence.

const TURN := 12

## Barème où chaque poids est distinct et non multiple des autres, de sorte qu'un terme
## branché sur le mauvais poids change forcément le total. Un barème à quatre 1 aurait
## laissé passer n'importe quelle permutation.
func _balance() -> RunBalance:
	var balance := RunBalance.new()
	balance.turns = 20
	balance.build_slots = 3
	balance.score_per_resource = 1
	balance.score_per_building = 10
	balance.score_per_inhabitant = 100
	balance.score_per_heart_hit_point = 1000
	return balance

func _tally(cause: StringName, resources := 0, buildings := 0, inhabitants := 0,
		heart := 0) -> RunOutcome:
	return RunOutcome.tally(cause, TURN, resources, buildings, inhabitants, heart,
		_balance())

# --- les causes --------------------------------------------------------------

func test_surviving_the_last_turn_is_a_victory() -> void:
	var outcome := _tally(RunOutcome.CAUSE_SURVIVED)
	assert_bool(outcome.is_victory()).is_true()
	assert_str(String(outcome.cause())).is_equal("survived")
	assert_int(outcome.turn()).is_equal(TURN)

## La victoire se **dérive** de la cause au lieu de vivre à côté d'elle : deux champs qui
## peuvent se contredire laisseraient exister une défaite victorieuse.
func test_both_defeats_are_defeats() -> void:
	assert_bool(_tally(RunOutcome.CAUSE_HEART).is_victory()).is_false()
	assert_bool(_tally(RunOutcome.CAUSE_POPULATION).is_victory()).is_false()

# --- les quatre termes -------------------------------------------------------

## Chacun est essayé **seul**, ce qui est la seule façon de prouver qu'il est branché sur son
## propre poids. Un cas qui les donnerait tous ensemble rendrait un total juste avec deux
## poids intervertis.
func test_each_term_is_weighed_by_its_own_weight() -> void:
	assert_int(_tally(RunOutcome.CAUSE_SURVIVED, 7).score()).is_equal(7)
	assert_int(_tally(RunOutcome.CAUSE_SURVIVED, 0, 7).score()).is_equal(70)
	assert_int(_tally(RunOutcome.CAUSE_SURVIVED, 0, 0, 7).score()).is_equal(700)
	assert_int(_tally(RunOutcome.CAUSE_SURVIVED, 0, 0, 0, 7).score()).is_equal(7000)

func test_the_score_is_the_sum_of_the_four() -> void:
	var outcome := _tally(RunOutcome.CAUSE_SURVIVED, 3, 4, 5, 6)
	assert_int(outcome.score()).is_equal(3 + 40 + 500 + 6000)

## Les quatre comptes sont gardés à côté du total, et ce n'est pas une redondance : un écran
## de fin qui n'annoncerait qu'un nombre ne dirait pas ce qui l'a fait, et redéduire les
## termes en les redivisant par leurs poids serait une seconde arithmétique à tenir d'accord
## avec celle-ci.
func test_the_terms_survive_next_to_the_total() -> void:
	var outcome := _tally(RunOutcome.CAUSE_SURVIVED, 3, 4, 5, 6)
	assert_int(outcome.resources()).is_equal(3)
	assert_int(outcome.buildings()).is_equal(4)
	assert_int(outcome.inhabitants()).is_equal(5)
	assert_int(outcome.heart_hit_points()).is_equal(6)

# --- ce qui ne peut pas descendre sous zéro ----------------------------------

## Un Cœur tombé rend 0 PV et non un nombre négatif, et une défaite par famine rend 0
## habitant. Les deux arrivent vraiment : le verdict est composé **après** les pertes.
func test_a_run_that_lost_everything_scores_zero() -> void:
	var outcome := _tally(RunOutcome.CAUSE_POPULATION)
	assert_int(outcome.score()).is_equal(0)
	assert_int(outcome.inhabitants()).is_equal(0)

## Un compte négatif serait un défaut d'appelant, pas un score négatif. L'écrêtage est là
## pour qu'un barème ne puisse jamais retrancher des points.
func test_a_negative_count_is_read_as_zero() -> void:
	assert_int(_tally(RunOutcome.CAUSE_HEART, -5, -5, -5, -5).score()).is_equal(0)

# --- ce que le barème permet -------------------------------------------------

## Un poids nul est un choix d'équilibrage, pas un oubli : le terme cesse simplement de
## compter, sans que rien d'autre ne bouge.
func test_a_weight_at_zero_silences_its_term_only() -> void:
	var balance := _balance()
	balance.score_per_inhabitant = 0
	var outcome := RunOutcome.tally(RunOutcome.CAUSE_SURVIVED, TURN, 3, 4, 5, 6, balance)
	assert_int(outcome.score()).is_equal(3 + 40 + 6000)
	assert_int(outcome.inhabitants()).is_equal(5)
