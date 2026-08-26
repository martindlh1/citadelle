class_name RunOrchestratorTest
extends GdUnitTestSuite
## Ce qu'on peut faire d'un run, et ce qu'un soir en fait.
##
## Les deux familles de cas sont les deux choses que `D2` avait laissées à `I1` : la
## bourse au moment de bâtir, et l'exécution de *Construire* et *Terraformer*. S'y ajoute
## la journée, qui décide de quand.
##
## Même équilibrage de travail que `run_state_test.gd`, et pour la même raison : le `.tres`
## réel dupliqué en surface, dont les cinq blocs que ces cas lisent sont remplacés par des
## blocs écrits à la main.
##
## Journée de travail par défaut, deux phases anonymes : la première pose, la seconde
## affecte et résout. Aucun cas ne les nomme — l'ordre suffit.
##
## Elle ne ressemble **pas** à celle que `data/balance/` porte, et c'est voulu : une
## journée restrictive est la seule façon de vérifier qu'une phase garde bien un geste.
## Les cas qui ont besoin de la journée livrée — deux phases identiques qui résolvent
## toutes les deux — fabriquent la leur avec `_two_working_phases()`. C'est ce partage qui
## a permis à la journée de `data/` de changer sans qu'une ligne de test bouge.

const BALANCE_PATH := "res://data/balance/balance.tres"

const SEED := 90210
const MAP := Vector2i(8, 8)
const GROUND := 2
const FOREST := Vector2i(2, 2)
const SPOT := Vector2i(4, 4)
const OTHER_SPOT := Vector2i(6, 6)
const DIRT := Vector2i(1, 6)

const CARD_HUT := &"hut"
const CARD_TOWER := &"tower"
const CARD_STORE := &"store"

const HUT_COST := 10
const HUT_ACTIONS := 2
const TOWER_COST := 999
const STORE_BONUS := 100

const BASE_CAP := 100
const OPENING_FOOD := 20
const OPENING_WOOD := 30
const XP_PER_SHIFT := 4
const DAYS := 6

const CONSTRUCTION := &"construction"
const HARVEST := &"harvest"

const UP := PlayedAction.DIRECTION_UP
const DOWN := PlayedAction.DIRECTION_DOWN

# --- Ce que la phase autorise ----------------------------------------------------------

func test_playing_is_refused_in_a_phase_that_does_not_allow_it() -> void:
	var state := _open()
	RunOrchestrator.end_phase(state)
	var result := RunOrchestrator.play(state, CARD_HUT, SPOT)
	assert_bool(result.is_ok()).is_false()
	assert_str(result.reason()).is_equal(PlayResult.REASON_WRONG_PHASE)

func test_staffing_is_refused_in_a_phase_that_does_not_allow_it() -> void:
	var state := _open()
	var posted := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_bool(RunOrchestrator.staff(state, &"ana", posted.action().id())).is_false()

func test_a_card_that_is_not_in_hand_is_refused() -> void:
	var result := RunOrchestrator.play(_open(), &"nowhere", SPOT)
	assert_str(result.reason()).is_equal(PlayResult.REASON_NOT_IN_HAND)

# --- La bourse au moment de bâtir -------------------------------------------------------

## `DESIGN.md` 3.2 le dit depuis `C1` : « Ai-je les 15 bois ? » ne regarde pas la carte.
## Voici la couche qui pose les deux questions à la suite.
func test_a_building_card_opens_a_site_and_pays_for_it() -> void:
	var state := _open()
	var result := RunOrchestrator.play(state, CARD_HUT, SPOT)
	assert_bool(result.is_ok()).is_true()
	assert_bool(result.posts_an_action()).is_false()
	assert_vector(result.anchor()).is_equal(SPOT)
	assert_int(result.paid()[&"wood"]).is_equal(HUT_COST)
	assert_int(state.ledger().amount(&"wood")).is_equal(OPENING_WOOD - HUT_COST)
	assert_int(state.city().count()).is_equal(1)
	assert_bool(state.city().building_at(SPOT).is_complete()).is_false()

## Tout ou rien : ni demi-paiement, ni chantier gratuit. C'est la règle de
## `Ledger.spend()`, et elle vaut pour le geste entier.
func test_an_unaffordable_building_changes_nothing() -> void:
	var state := _open()
	var result := RunOrchestrator.play(state, CARD_TOWER, SPOT)
	assert_str(result.reason()).is_equal(PlayResult.REASON_UNAFFORDABLE)
	assert_int(state.ledger().amount(&"wood")).is_equal(OPENING_WOOD)
	assert_int(state.city().count()).is_equal(0)
	assert_int(state.deck().hand().cards().count(CARD_TOWER)).is_equal(1)

## Le refus du placement traverse tel quel plutôt que d'être retraduit : il n'y a qu'un
## vocabulaire à tenir, et c'est celui que le fantôme montre déjà sous le curseur.
func test_a_refused_placement_relays_its_own_reason() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var second := RunOrchestrator.play(state, CARD_HUT, SPOT)
	assert_str(second.reason()).is_equal(PlacementResult.REASON_OCCUPIED)

## L'ordre des deux questions, et il n'est pas indifférent : demander « ai-je les 15
## bois ? » à propos d'une case où l'on ne peut de toute façon pas bâtir serait une
## réponse à côté de la question.
func test_the_purse_is_only_asked_once_the_placement_holds() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var result := RunOrchestrator.play(state, CARD_TOWER, SPOT)
	assert_str(result.reason()).is_equal(PlacementResult.REASON_OCCUPIED)

# --- Poser une action ------------------------------------------------------------------

func test_an_action_card_posts_and_leaves_the_hand() -> void:
	var state := _open()
	var before := state.deck().hand().cards().count(ActionTargeting.CARD_HARVEST)
	var result := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_bool(result.posts_an_action()).is_true()
	assert_int(result.action().capacity()).is_greater(0)
	assert_int(state.deck().hand().cards().count(ActionTargeting.CARD_HARVEST)) \
		.is_equal(before - 1)
	assert_int(state.board().count()).is_equal(1)

func test_a_terraform_play_carries_its_direction_to_the_board() -> void:
	var state := _open()
	var result := RunOrchestrator.play(state, SiteResolver.CARD_TERRAFORM, DIRT, 0, DOWN)
	assert_bool(result.is_ok()).is_true()
	assert_int(state.board().at(result.action().id()).direction()).is_equal(DOWN)

func test_a_refused_targeting_relays_its_own_reason() -> void:
	var result := RunOrchestrator.play(_open(), SiteResolver.CARD_TERRAFORM, DIRT)
	assert_str(result.reason()).is_equal(TargetResult.REASON_NO_DIRECTION)

func test_withdrawing_an_action_takes_it_off_the_board() -> void:
	var state := _open()
	var posted := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_bool(RunOrchestrator.withdraw(state, posted.action().id())).is_true()
	assert_int(state.board().count()).is_equal(0)

## Le retrait appartient à la phase qui **pose**, puisque c'est un jeu de carte à
## l'envers. Avec la journée de `data/`, où poser et affecter sont deux phases, il n'a
## donc jamais d'ouvrier à rappeler — on ne revient à une phase qui pose qu'après une
## résolution, qui a déjà tout vidé.
func test_withdrawing_is_refused_in_a_phase_that_only_staffs() -> void:
	var state := _open()
	var posted := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	RunOrchestrator.end_phase(state)
	assert_bool(RunOrchestrator.withdraw(state, posted.action().id())).is_false()
	assert_int(state.board().count()).is_equal(1)

## Le rappel n'est donc pas du code mort : il s'allume dès qu'une journée laisse poser et
## affecter dans la même phase — ce qui est un `.tres` et non une réécriture, et
## exactement le genre de variante que `I2b` mettra à l'épreuve. Sans lui, un ouvrier
## resterait attaché à un numéro que plus rien ne porte.
func test_withdrawing_recalls_its_workers_when_one_phase_does_both() -> void:
	var state := _open(SEED, _one_open_phase())
	var posted := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	var id := posted.action().id()
	assert_bool(RunOrchestrator.staff(state, &"ana", id)).is_true()
	assert_bool(RunOrchestrator.withdraw(state, id)).is_true()
	assert_bool(state.is_staffed(&"ana")).is_false()
	assert_int(state.board().count()).is_equal(0)

# --- Affecter ---------------------------------------------------------------------------

func test_a_worker_holds_one_action_at_a_time() -> void:
	var state := _open()
	var first := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	var second := RunOrchestrator.play(state, CARD_HUT, SPOT)
	assert_bool(second.is_ok()).is_true()
	RunOrchestrator.end_phase(state)
	assert_bool(RunOrchestrator.staff(state, &"ana", first.id())).is_true()
	assert_bool(RunOrchestrator.staff(state, &"ana", first.id())).is_false()

func test_an_action_refuses_more_workers_than_it_accepts() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	assert_int(bare.capacity()).is_equal(1)
	assert_bool(RunOrchestrator.staff(state, &"ana", bare.id())).is_true()
	assert_bool(RunOrchestrator.staff(state, &"bo", bare.id())).is_false()

func test_an_absent_worker_cannot_be_staffed() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	state.roster().worker(&"ana").set_present(false)
	assert_bool(RunOrchestrator.staff(state, &"ana", bare.id())).is_false()

func test_staffing_an_action_nobody_posted_is_refused() -> void:
	var state := _open()
	RunOrchestrator.end_phase(state)
	assert_bool(RunOrchestrator.staff(state, &"ana", 99)).is_false()

## Les cinq refus se nomment.
##
## Ils l'ont d'abord tous été de la même façon — un booléen nu — au motif qu'ils se
## voyaient à l'écran avant le clic. C'était faux à l'usage : la première partie jouée au
## clavier a donné un « refusé » sans cause, la touche paraissant morte alors que la phase
## courante l'expliquait entièrement. Un refus qui ne se nomme pas est indiscernable d'une
## panne, et c'est ce que ces cas tiennent désormais.
func test_the_phase_names_itself_when_it_refuses_a_staffing() -> void:
	var state := _open()
	var posted := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_str(RunOrchestrator.staffing_refusal(state, &"ana", posted.action().id())) \
		.is_equal(PlayResult.REASON_WRONG_PHASE)

func test_a_full_action_names_itself() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", bare.id())
	assert_str(RunOrchestrator.staffing_refusal(state, &"bo", bare.id())) \
		.is_equal(RunOrchestrator.REASON_NO_ROOM)

func test_a_worker_already_at_work_names_itself() -> void:
	var state := _open()
	var first := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	var second := RunOrchestrator.play(state, SiteResolver.CARD_TERRAFORM, DIRT, 0,
		UP).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", first.id())
	assert_str(RunOrchestrator.staffing_refusal(state, &"ana", second.id())) \
		.is_equal(RunOrchestrator.REASON_ALREADY_STAFFED)

func test_an_absent_worker_names_itself() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	state.roster().worker(&"ana").set_present(false)
	assert_str(RunOrchestrator.staffing_refusal(state, &"ana", bare.id())) \
		.is_equal(RunOrchestrator.REASON_ABSENT_WORKER)

## Un absent et un inconnu sont deux choses différentes : le premier revient d'expédition,
## le second n'a jamais existé. Les confondre ferait dire à l'écran « Ana est absente »
## d'un nom que personne ne porte.
func test_an_unknown_worker_names_itself() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	assert_str(RunOrchestrator.staffing_refusal(state, &"nobody", bare.id())) \
		.is_equal(RunOrchestrator.REASON_UNKNOWN_WORKER)

func test_a_missing_action_names_itself() -> void:
	var state := _open()
	RunOrchestrator.end_phase(state)
	assert_str(RunOrchestrator.staffing_refusal(state, &"ana", 99)) \
		.is_equal(RunOrchestrator.REASON_NO_ACTION)

## Et le revers : une affectation possible ne donne aucune raison. Sans ce cas, une
## fonction qui refuserait tout passerait les six précédents.
func test_an_allowed_staffing_gives_no_reason() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	assert_str(RunOrchestrator.staffing_refusal(state, &"ana", bare.id())).is_empty()
	assert_bool(RunOrchestrator.staff(state, &"ana", bare.id())).is_true()

# --- Le bouton ----------------------------------------------------------------------------

## **Le cas qui porte `W2`.** Jusqu'ici l'écran envoyait « le premier ouvrier libre », et
## `DESIGN.md` 3.4 dit que *qui* l'on envoie est la décision de fond d'une phase. Le
## bouton met chacun sur son métier : la récoltante à la forêt, le bâtisseur au chantier.
##
## Il passe par un run entier, là où `staffing_advisor_test.gd` tient la règle sur des
## objets nus — c'est le raccord entre les deux que ce cas vérifie, et notamment que la
## famille lue sur une action posée par le vrai ciblage est celle qu'on croit.
func test_the_button_sends_each_worker_to_his_trade() -> void:
	var state := _open()
	state.roster().worker(&"ana").gain(HARVEST, 100)
	state.roster().worker(&"bo").gain(CONSTRUCTION, 100)
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)

	var placed := RunOrchestrator.auto_staff(state)
	assert_array(placed).contains([&"ana", &"bo"])
	assert_array(state.staffed_on(bare.id())).contains([&"ana"])
	assert_array(state.staffed_on(site.id())).contains([&"bo"])

## Hors d'une phase qui affecte, le bouton ne fait rien — et surtout ne contourne pas les
## cinq refus, puisqu'il applique à travers `staff()`.
func test_the_button_does_nothing_in_a_phase_that_does_not_assign() -> void:
	var state := _open()
	RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_array(RunOrchestrator.auto_staff(state)).is_empty()
	assert_int(state.to_assignment().size()).is_equal(0)

## La surcharge manuelle : on place d'abord ceux dont on se soucie, le bouton complète.
## L'ordre des deux gestes n'a aucune importance, et c'est ce qui rend le bouton sûr.
func test_the_button_leaves_a_hand_placed_worker_where_he_is() -> void:
	var state := _open()
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)

	RunOrchestrator.staff(state, &"ana", site.id())
	RunOrchestrator.auto_staff(state)
	assert_int(state.to_assignment().action_of(&"ana")).is_equal(site.id())
	assert_array(state.staffed_on(bare.id())).contains([&"bo"])

## Un second appel ne déplace personne et ne double personne : tout ce qui pouvait être
## rempli l'est. C'est ce qui permet à l'écran de laisser le bouton cliquable en
## permanence sans avoir à deviner s'il reste quelque chose à faire.
func test_pressing_the_button_twice_places_nobody_new() -> void:
	var state := _open()
	RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	RunOrchestrator.end_phase(state)
	assert_array(RunOrchestrator.auto_staff(state)).is_not_empty()
	var settled := state.to_assignment().size()
	assert_array(RunOrchestrator.auto_staff(state)).is_empty()
	assert_int(state.to_assignment().size()).is_equal(settled)

# --- Le soir ------------------------------------------------------------------------------

## Le cas qui referme la panne de `D2` : *Construire* avance vraiment un chantier.
func test_an_evening_advances_the_site_its_crew_worked_on() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	var report := RunOrchestrator.end_phase(state)
	assert_int(report.sites().total_progress()).is_equal(1)
	assert_int(state.city().building_at(SPOT).progress()).is_equal(1)
	assert_bool(state.city().building_at(SPOT).is_complete()).is_false()

func test_a_site_finished_tonight_is_named_in_the_report() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	RunOrchestrator.staff(state, &"bo", site.id())
	var report := RunOrchestrator.end_phase(state)
	assert_array(report.completed()).contains_exactly([SPOT])
	assert_bool(state.city().building_at(SPOT).is_complete()).is_true()

## L'autre moitié de la panne : *Terraformer* déplace vraiment la terre.
func test_an_evening_moves_the_ground_a_terraform_targeted() -> void:
	var state := _open()
	var dig := RunOrchestrator.play(state, SiteResolver.CARD_TERRAFORM, DIRT, 0,
		DOWN).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", dig.id())
	var report := RunOrchestrator.end_phase(state)
	assert_int(report.sites().shifts()[DIRT]).is_equal(-1)
	assert_int(state.grid().height_at(DIRT)).is_equal(GROUND - 1)

func test_terraforming_upward_raises_the_cell() -> void:
	var state := _open()
	var heap := RunOrchestrator.play(state, SiteResolver.CARD_TERRAFORM, DIRT, 0,
		UP).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", heap.id())
	RunOrchestrator.end_phase(state)
	assert_int(state.grid().height_at(DIRT)).is_equal(GROUND + 1)

## **Le cas qui porte `PhaseReport.idle()`.** Le rapport de production ne connaît que
## les postes de production, donc il compte un bâtisseur parmi les oisifs. Les deux
## lectures sont chacune juste dans leur système ; seule la journée voit les deux
## journaux, et c'est elle qui répond pour le soir entier.
func test_a_builder_is_not_idle() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	var report := RunOrchestrator.end_phase(state)
	assert_array(report.production().idle()).contains([&"ana"])
	assert_array(report.idle()).not_contains([&"ana"])
	assert_array(report.idle()).has_size(2)

## L'XP d'un soir de chantier va dans la piste que `data/balance/` nomme, et le niveau
## d'ouvrier la reçoit aussi — la règle des deux axes de 3.4 vaut pour cette famille
## comme pour les autres.
func test_site_work_credits_the_construction_track() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	var report := RunOrchestrator.end_phase(state)
	assert_int(report.progress().total_xp()).is_equal(XP_PER_SHIFT)
	assert_int(state.roster().worker(&"ana").track_xp(CONSTRUCTION)) \
		.is_equal(XP_PER_SHIFT)
	assert_int(state.roster().worker(&"ana").xp()).is_equal(XP_PER_SHIFT)

## L'ordre de la résolution, et il n'est pas indifférent. Un entrepôt achevé ce soir ne
## sauve pas la récolte du même soir : la production se calcule sur la ville d'**avant**,
## et les chantiers s'appliquent après. Sans cette règle, l'ordre des cartes posées
## déciderait du résultat — ce que `E1` a refusé pour l'écrêtage.
##
## *(Réécrit à `E2`.)* `I1` tenait la même règle en affirmant que la **capacité** valait
## encore 100 à la fin de cette phase-là. C'était affirmer un effet de bord plutôt que la
## règle : ce que 2 protège est que la récolte du soir ne soit pas sauvée, pas que le
## compteur affiché reste en arrière. Le cas asserte donc désormais ce qui compte
## vraiment — la réserve était pleine quand la récolte est tombée, donc elle est perdue —,
## ce qui est plus fort que ce que `I1` pouvait observer, et ce qui laisse la capacité
## libre de se relever aussitôt. Voir le cas suivant.
func test_a_warehouse_finished_tonight_does_not_save_tonights_harvest() -> void:
	var state := _open(SEED, _one_open_phase())
	_fill_the_reserve(state)
	RunOrchestrator.play(state, CARD_STORE, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	var crop := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.staff(state, &"ana", site.id())
	RunOrchestrator.staff(state, &"bo", crop.id())
	var report := RunOrchestrator.end_phase(state)
	assert_array(report.completed()).contains_exactly([SPOT])
	assert_int(report.production().produced()[&"wood"]).is_equal(1)
	assert_dict(report.production().stored()).is_empty()
	assert_int(report.production().total_wasted()).is_equal(1)

## Et le revers, qui est le neuf de `E2` : la capacité, elle, monte **tout de suite**.
##
## Elle montait au soir suivant jusqu'ici, et personne ne l'avait vu parce qu'aucun écran
## n'affichait la réserve en continu — la résolution suivante la reposait de toute façon.
## Un HUD la met sous les yeux : l'entrepôt est fini sur la carte, et la jauge annonce
## encore l'ancien plafond pendant toute une phase.
##
## Les deux cas se lisent ensemble : le soir garde sa récolte perdue, et le plafond est
## déjà relevé quand la phase rend la main.
func test_a_warehouse_finished_tonight_raises_the_cap_at_once() -> void:
	var state := _open()
	RunOrchestrator.play(state, CARD_STORE, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	var report := RunOrchestrator.end_phase(state)
	assert_array(report.completed()).contains_exactly([SPOT])
	assert_int(state.ledger().capacity()).is_equal(BASE_CAP + STORE_BONUS)

## Et une phase sans entrepôt ne touche pas au plafond : sans ce revers, un
## `set_capacity()` qui rendrait n'importe quoi passerait les deux cas ci-dessus dès lors
## qu'il rendrait plus grand.
func test_a_phase_that_finishes_nothing_leaves_the_cap_alone() -> void:
	var state := _open()
	_resolve_an_empty_day(state)
	assert_int(state.ledger().capacity()).is_equal(BASE_CAP)

## L'upkeep tombe sur le roster entier, oisifs compris, et il tombe à la **fin de la
## journée**.
func test_closing_the_day_takes_the_upkeep() -> void:
	var state := _open()
	var report := _resolve_an_empty_day(state)
	assert_bool(report.closes_the_day()).is_true()
	assert_int(report.day_report().upkeep().due()).is_equal(3)
	assert_int(report.day_report().day()).is_equal(1)
	assert_int(state.ledger().amount(&"food")).is_equal(OPENING_FOOD - 3)

## **Le cas qui porte la correction.** On produit à chaque phase, on mange une fois par
## jour : une phase qui ne ferme pas la journée ne prélève rien, et son rapport ne porte
## aucune journée. Sans cette séparation, jouer deux phases par jour ferait manger deux
## fois, et la structure de la journée deviendrait inséparable de son équilibrage.
func test_a_phase_that_does_not_close_the_day_takes_no_upkeep() -> void:
	var state := _open(SEED, _two_working_phases())
	var report := RunOrchestrator.end_phase(state)
	assert_bool(report.closes_the_day()).is_false()
	assert_object(report.day_report()).is_null()
	assert_int(state.ledger().amount(&"food")).is_equal(OPENING_FOOD)

## Et le revers, sur la journée que `data/` porte : deux phases qui résolvent, deux
## récoltes, **un seul** upkeep.
func test_two_resolving_phases_produce_twice_and_eat_once() -> void:
	var state := _open(SEED, _two_working_phases())
	var first := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.staff(state, &"ana", first.id())
	var morning := RunOrchestrator.end_phase(state)
	var second := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.staff(state, &"ana", second.id())
	var afternoon := RunOrchestrator.end_phase(state)
	assert_int(morning.production().produced()[&"wood"]).is_equal(1)
	assert_int(afternoon.production().produced()[&"wood"]).is_equal(1)
	assert_bool(morning.closes_the_day()).is_false()
	assert_bool(afternoon.closes_the_day()).is_true()
	assert_int(afternoon.day_report().upkeep().due()).is_equal(3)
	assert_int(state.ledger().amount(&"food")).is_equal(OPENING_FOOD - 3)
	assert_int(state.cycle().day()).is_equal(2)

## Une journée coûte à nourrir même si sa dernière phase ne produit rien. Le prélèvement
## suit la fin de journée, pas `resolves`.
func test_a_day_whose_last_phase_does_not_resolve_still_eats() -> void:
	var phases: Array[PhaseDef] = [
		_phase(&"first", [PhaseDef.ACTION_PLAY], true),
		_phase(&"last", [PhaseDef.ACTION_PLAY], false)]
	var state := _open(SEED, phases)
	RunOrchestrator.end_phase(state)
	var report := RunOrchestrator.end_phase(state)
	assert_bool(report.closes_the_day()).is_true()
	assert_int(report.day_report().upkeep().due()).is_equal(3)
	assert_dict(report.production().produced()).is_empty()

# --- Les frontières de phase ---------------------------------------------------------------

## **Le board traverse la journée.** `D2` a fait de « poser une carte » et « y envoyer des
## ouvriers » deux gestes, et rien n'oblige à les tenir dans la même phase : vider entre
## les deux effacerait ce que la première a fait.
func test_the_board_survives_a_phase_that_does_not_resolve() -> void:
	var state := _open()
	RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	assert_object(RunOrchestrator.end_phase(state)).is_null()
	assert_int(state.board().count()).is_equal(1)

func test_a_resolving_phase_clears_the_board_and_deals_a_new_hand() -> void:
	var state := _open()
	RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	RunOrchestrator.end_phase(state)
	var before := state.deck().hand().cards().size()
	RunOrchestrator.end_phase(state)
	assert_int(state.board().count()).is_equal(0)
	assert_int(state.to_assignment().size()).is_equal(0)
	assert_int(state.deck().hand().cards().size()).is_equal(before + 1)

func test_a_resolution_opens_the_next_day() -> void:
	var state := _open()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.end_phase(state)
	assert_int(state.cycle().day()).is_equal(2)
	assert_int(state.cycle().phase_index()).is_equal(0)

func test_a_finished_run_resolves_nothing_more() -> void:
	var state := _open()
	for _step in DAYS * 2:
		RunOrchestrator.end_phase(state)
	assert_bool(state.cycle().is_over()).is_true()
	assert_object(RunOrchestrator.end_phase(state)).is_null()

# --- Le rejeu -----------------------------------------------------------------------------

## **Le cas qui porte le jalon.** `CLAUDE.md` promet depuis `I0` qu'« un seed plus une
## liste d'actions doit rejouer un run à l'identique — c'est ce qui rend l'équilibrage et
## le débogage possibles ». Jusqu'à `I1` rien ne pouvait le vérifier, faute d'un objet qui
## tienne un run entier. Deux runs, même seed, mêmes gestes, et tout se compare : la
## bourse, le relief, l'avancement du chantier, l'XP.
func test_the_same_seed_and_the_same_gestures_replay_the_run() -> void:
	var first := _scripted()
	var second := _scripted()
	assert_dict(first.ledger().amounts()).is_equal(second.ledger().amounts())
	assert_int(first.grid().height_at(DIRT)).is_equal(second.grid().height_at(DIRT))
	assert_int(first.city().building_at(SPOT).progress()) \
		.is_equal(second.city().building_at(SPOT).progress())
	assert_int(first.roster().worker(&"ana").xp()) \
		.is_equal(second.roster().worker(&"ana").xp())
	assert_array(first.deck().hand().cards()).is_equal(second.deck().hand().cards())

## Le revers : un seed différent ne rejoue pas la même partie. Sans lui, le cas ci-dessus
## passerait tout aussi bien sur un run parfaitement déterministe **et vide**.
func test_another_seed_deals_another_run() -> void:
	assert_array(_scripted().deck().hand().cards()) \
		.is_not_equal(_scripted(SEED + 1).deck().hand().cards())

## Le bouton est un geste, donc il entre sous la même promesse : un seed plus une suite
## de gestes rejoue le run à l'identique. C'est la vraie raison pour laquelle
## l'auto-affectation est dans le domaine — un classement dont le départage serait
## arbitraire enverrait deux ouvriers différents d'un rejeu à l'autre, et ni le relief ni
## la bourse ne le montreraient avant plusieurs journées.
func test_the_same_seed_replays_an_auto_staffed_run() -> void:
	var first := _auto_staffed()
	var second := _auto_staffed()
	assert_array(first.to_assignment().workers()) \
		.is_equal(second.to_assignment().workers())
	for worker in first.to_assignment().workers():
		assert_int(first.to_assignment().action_of(worker)) \
			.is_equal(second.to_assignment().action_of(worker))
	assert_int(first.roster().worker(&"ana").xp()) \
		.is_equal(second.roster().worker(&"ana").xp())

## Une journée posée à la main puis remplie au bouton, sur des ouvriers déjà spécialisés.
## Les pistes sont creusées d'avance : sans écart d'efficacité, le classement retomberait
## sur l'ordre du roster et le cas ne prouverait plus rien du départage.
func _auto_staffed(run_seed := SEED) -> RunState:
	var state := _open(run_seed)
	state.roster().worker(&"ana").gain(HARVEST, 100)
	state.roster().worker(&"bo").gain(CONSTRUCTION, 100)
	RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST)
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT)
	RunOrchestrator.end_phase(state)
	RunOrchestrator.auto_staff(state)
	return state

## Deux journées jouées, dans l'ordre, avec les trois verbes.
func _scripted(run_seed := SEED) -> RunState:
	var state := _open(run_seed)
	RunOrchestrator.play(state, CARD_HUT, SPOT)
	var site := RunOrchestrator.play(state, SiteResolver.CARD_BUILD, SPOT).action()
	var dig := RunOrchestrator.play(state, SiteResolver.CARD_TERRAFORM, DIRT, 0,
		DOWN).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"ana", site.id())
	RunOrchestrator.staff(state, &"bo", dig.id())
	RunOrchestrator.end_phase(state)
	var bare := RunOrchestrator.play(state, ActionTargeting.CARD_HARVEST, FOREST).action()
	RunOrchestrator.end_phase(state)
	RunOrchestrator.staff(state, &"cy", bare.id())
	RunOrchestrator.end_phase(state)
	return state

# --- La mise en place -----------------------------------------------------------------------

func _resolve_an_empty_day(state: RunState) -> PhaseReport:
	RunOrchestrator.end_phase(state)
	return RunOrchestrator.end_phase(state)

## Remplit la réserve jusqu'au plafond, pour que la récolte du soir n'ait nulle part où
## entrer. C'est la seule façon d'observer l'écrêtage avec cet équilibrage : trois
## ouvriers ne produiront jamais les cent unités qu'il faudrait pour déborder tout seuls.
func _fill_the_reserve(state: RunState) -> void:
	var top_up: Dictionary[StringName, int] = {}
	top_up[&"wood"] = BASE_CAP - state.ledger().total()
	state.ledger().deposit(top_up)
	assert_bool(state.ledger().is_full()) \
		.override_failure_message("la réserve n'est pas pleine avant le soir") \
		.is_true()

func _open(run_seed := SEED, phases: Array[PhaseDef] = []) -> RunState:
	return RunState.open(run_seed, _make_grid(), _make_roster(), _make_catalogue(),
		_make_buildings(), _make_balance(phases))

## La journée alternative : une seule phase qui pose, affecte et résout. Elle sert aux cas
## qui ont besoin des deux gestes d'un coup, et elle est aussi le rappel qu'une journée
## est de la data — celle-ci n'est pas moins valide que celle de `data/balance/`.
func _one_open_phase() -> Array[PhaseDef]:
	var phases: Array[PhaseDef] = [
		_phase(&"only", [PhaseDef.ACTION_PLAY, PhaseDef.ACTION_ASSIGN], true)]
	return phases

## La journée que `data/balance/` porte, sur des noms qui n'y sont pas : deux phases
## identiques qui posent, affectent et résolvent toutes les deux. Seule la seconde ferme
## la journée, parce qu'une journée se ferme après sa dernière phase — et pas parce qu'un
## champ le dirait.
func _two_working_phases() -> Array[PhaseDef]:
	var both: Array = [PhaseDef.ACTION_PLAY, PhaseDef.ACTION_ASSIGN]
	var phases: Array[PhaseDef] = [
		_phase(&"first", both, true), _phase(&"second", both, true)]
	return phases

func _make_grid() -> HeightGrid:
	var grid := HeightGrid.create(MAP, GROUND, _terrain(&"plain", []))
	grid.set_terrain(FOREST, _terrain(&"forest", [&"forest"]))
	return grid

func _terrain(id: StringName, tags: Array) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	var typed: Array[StringName] = []
	typed.assign(tags)
	data.tags = typed
	return data

func _make_roster() -> Roster:
	var workers: Array[Worker] = [
		Worker.create(&"ana", "Ana"), Worker.create(&"bo", "Bo"),
		Worker.create(&"cy", "Cy")]
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = [
		_card(ActionTargeting.CARD_HARVEST, CardData.POOL_ACTION),
		_card(SiteResolver.CARD_BUILD, CardData.POOL_ACTION),
		_card(SiteResolver.CARD_TERRAFORM, CardData.POOL_ACTION),
		_card(CARD_HUT, CardData.POOL_BUILDING, CARD_HUT),
		_card(CARD_TOWER, CardData.POOL_BUILDING, CARD_TOWER),
		_card(CARD_STORE, CardData.POOL_BUILDING, CARD_STORE)]
	return CardCatalogue.create(cards)

func _card(id: StringName, pool: StringName, builds := &"") -> CardData:
	var data := CardData.new()
	data.id = id
	data.label = String(id).capitalize()
	data.pool = pool
	data.building = builds
	return data

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	table[CARD_HUT] = _hut()
	table[CARD_TOWER] = _tower()
	table[CARD_STORE] = _store()
	return table

func _hut() -> BuildingData:
	var data := _building(CARD_HUT, HUT_COST, HUT_ACTIONS)
	var block := ProductionBlock.new()
	block.slots = 2
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = HARVEST
	data.production = block
	return data

## Impayable exprès : c'est le seul rôle de ce bâtiment.
func _tower() -> BuildingData:
	return _building(CARD_TOWER, TOWER_COST, 1)

## Gratuit et fini en un cran, pour que le cas de l'ordre de résolution tienne en une
## soirée.
func _store() -> BuildingData:
	var data := _building(CARD_STORE, 0, 1)
	data.storage_bonus = STORE_BONUS
	return data

func _building(id: StringName, wood: int, actions: int) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	data.build_actions = actions
	var cost: Dictionary[StringName, int] = {}
	if wood > 0:
		cost[&"wood"] = wood
	data.cost = cost
	return data

func _make_balance(phases: Array[PhaseDef]) -> BalanceData:
	var balance := (load(BALANCE_PATH) as BalanceData).duplicate() as BalanceData
	balance.economy = _economy()
	balance.workforce = _workforce()
	balance.deck = _deck()
	balance.actions = _actions()
	balance.run = _run(phases)
	return balance

func _economy() -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = BASE_CAP
	economy.upkeep_per_worker = 1
	economy.upkeep_resource = &"food"
	var stock: Dictionary[StringName, int] = {}
	stock[&"food"] = OPENING_FOOD
	stock[&"wood"] = OPENING_WOOD
	economy.starting_stock = stock
	return economy

func _workforce() -> WorkforceBalance:
	var workforce := WorkforceBalance.new()
	workforce.base_roster_places = 10
	workforce.xp_per_shift = XP_PER_SHIFT
	workforce.skill_xp_per_level = 25
	workforce.max_skill_level = 5
	workforce.efficiency_per_skill_level = 0.15
	workforce.worker_xp_per_level = 40
	workforce.max_worker_level = 10
	return workforce

## Le deck entier tient dans la main : les cas jouent la carte qu'ils nomment sans
## dépendre de ce qu'un mélange a bien voulu servir.
func _deck() -> DeckBalance:
	var deck := DeckBalance.new()
	var copies: Dictionary[StringName, int] = {}
	copies[ActionTargeting.CARD_HARVEST] = 2
	copies[SiteResolver.CARD_BUILD] = 2
	copies[SiteResolver.CARD_TERRAFORM] = 2
	copies[CARD_HUT] = 2
	copies[CARD_TOWER] = 1
	copies[CARD_STORE] = 1
	deck.starting_deck = copies
	var sizes: Dictionary[StringName, int] = {}
	sizes[CardData.POOL_ACTION] = 6
	sizes[CardData.POOL_BUILDING] = 4
	sizes[CardData.POOL_POWER] = 0
	deck.hand_size = sizes
	deck.draft_choices = 3
	return deck

func _actions() -> ActionBalance:
	var actions := ActionBalance.new()
	actions.bare_capacity = 1
	actions.bare_yield = 1
	actions.bare_skill_family = HARVEST
	actions.site_skill_family = CONSTRUCTION
	actions.terraform_floor = 0
	actions.terraform_ceiling = 4
	var slots: Array[StringName] = [HARVEST]
	actions.slot_cards = slots
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[HARVEST] = {&"forest": &"wood"}
	actions.bare_sources = sources
	return actions

## Deux phases anonymes par défaut : la première pose, la seconde affecte et résout. Un
## cas qui a besoin d'une autre journée passe la sienne.
func _run(phases: Array[PhaseDef]) -> RunBalance:
	var run := RunBalance.new()
	run.days = DAYS
	run.starting_building = &""
	var day := phases
	if day.is_empty():
		day = [_phase(&"first", [PhaseDef.ACTION_PLAY], false),
			_phase(&"second", [PhaseDef.ACTION_ASSIGN], true)]
	run.phases = day
	return run

func _phase(id: StringName, allows: Array, resolves: bool) -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = id
	phase.label = String(id)
	var kinds: Array[StringName] = []
	kinds.assign(allows)
	phase.allows = kinds
	phase.resolves = resolves
	return phase
