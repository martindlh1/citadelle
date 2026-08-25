class_name ActionPlanTest
extends GdUnitTestSuite
## La projection figée de ce qui est posé, et les deux DTO qu'elle transporte.
##
## Suite à part de celle du board, comme hand_test.gd l'est de deck_test.gd : le board a
## un seul producteur mais le plan a plusieurs consommateurs, et ce qu'il **garantit**
## à ceux-là se teste sans passer par ce qui l'a rempli.
##
## Ce qui compte ici tient en deux points. Un plan vide n'est pas une erreur — c'est
## l'état d'un début de phase, et celui d'une phase où l'on a tout gardé en main. Et un
## identifiant inconnu se lit comme « plus rien sous ce numéro » plutôt que de casser :
## une affectation peut avoir survécu à l'action qu'elle nommait, le joueur l'ayant
## retirée après y avoir mis quelqu'un.

const FOREST := Vector2i(2, 2)
const HUT := Vector2i(5, 5)

func test_an_empty_plan_holds_nothing() -> void:
	var plan := ActionPlan.empty()
	assert_int(plan.count()).is_equal(0)
	assert_bool(plan.is_empty()).is_true()
	assert_array(plan.actions()).is_empty()

func test_a_plan_keeps_the_order_it_was_given() -> void:
	var plan := ActionPlan.create([_bare(1, &"harvest"), _bare(2, &"hunt"),
		_bare(3, &"terraform")])
	var posted := plan.actions()
	assert_int(posted.size()).is_equal(3)
	assert_str(posted[0].card()).is_equal(&"harvest")
	assert_str(posted[2].card()).is_equal(&"terraform")

func test_an_action_is_found_by_its_identifier() -> void:
	var plan := ActionPlan.create([_bare(7, &"harvest")])
	assert_bool(plan.has(7)).is_true()
	assert_str(plan.at(7).card()).is_equal(&"harvest")

## « Plus rien sous ce numéro » est une réponse que le résolveur sait traiter, pas une
## faute d'appelant. Même convention que CitySnapshot.at_anchor().
func test_an_unknown_identifier_reads_as_nothing() -> void:
	var plan := ActionPlan.create([_bare(7, &"harvest")])
	assert_bool(plan.has(1)).is_false()
	assert_object(plan.at(1)).is_null()

func test_the_action_list_is_a_copy() -> void:
	var plan := ActionPlan.create([_bare(1, &"harvest")])
	plan.actions().clear()
	assert_int(plan.count()).is_equal(1)

# --- PlayedAction ---------------------------------------------------------------------

## Les deux lectures de DESIGN.md 3.5 se lisent sur l'action posée elle-même, et non en
## rouvrant la ville : c'est ce qui permet au résolveur de traiter une action dont la
## cible a changé de nature depuis la pose.
func test_a_played_action_says_where_it_is_played() -> void:
	var bare := _bare(1, &"harvest")
	assert_bool(bare.is_bare()).is_true()
	assert_bool(bare.is_on_building()).is_false()
	var slot := PlayedAction.create(2, &"harvest", HUT, PlayedAction.Kind.BUILDING, 2)
	assert_bool(slot.is_on_building()).is_true()
	assert_bool(slot.is_bare()).is_false()

func test_a_played_action_carries_the_capacity_it_was_posted_with() -> void:
	assert_int(PlayedAction.create(1, &"build", HUT,
		PlayedAction.Kind.BUILDING, 3).capacity()).is_equal(3)

# --- TargetResult ---------------------------------------------------------------------

func test_an_accepted_target_carries_its_three_answers() -> void:
	var result := TargetResult.accepted(PlayedAction.Kind.BUILDING, HUT, 2)
	assert_bool(result.is_ok()).is_true()
	assert_str(result.reason()).is_equal(TargetResult.REASON_NONE)
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BUILDING)
	assert_vector(result.target()).is_equal(HUT)
	assert_int(result.capacity()).is_equal(2)

func test_a_refused_target_carries_only_its_reason() -> void:
	var result := TargetResult.refused(TargetResult.REASON_WRONG_TAG)
	assert_bool(result.is_ok()).is_false()
	assert_str(result.reason()).is_equal(TargetResult.REASON_WRONG_TAG)

func _bare(id: int, card: StringName) -> PlayedAction:
	return PlayedAction.create(id, card, FOREST, PlayedAction.Kind.BARE, 1)
