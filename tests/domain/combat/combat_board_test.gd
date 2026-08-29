class_name CombatBoardTest
extends GdUnitTestSuite
## Le plateau, ses deux verbes, et ce qu'une manche laisse derrière elle.
##
## `DESIGN.md` 3.6 donne à `F2` deux verbes — se déplacer, attaquer — et une règle qui
## décide de tout le reste : **une intention frappe la case, pas la cible**. Cette suite
## épingle cette règle et ses conséquences, pas les chiffres de `data/`.
##
## **Village de travail**, sur un relief 9×9 plat en plaine :
##   - une **cabane** achevée en `(4, 4)` — 6 PV ;
##   - un **chantier** en `(6, 4)` — mêmes PV, jamais fini ;
##   - de l'**eau** en `(0, 8)`, pour que quelque chose refuse un corps.
##
## Deux corps de référence : `ana`, ouvrière en `(2, 4)`, et `orc`, assaillant en `(7, 4)`.
## Leurs fourchettes de dégâts sont **dégénérées** — un seul chiffre possible — partout où
## le cas porte sur une règle : l'aléatoire a sa propre section en bas de fichier.

const HUT := Vector2i(4, 4)
const SITE := Vector2i(6, 4)
const WATER := Vector2i(0, 8)

const ANA := Vector2i(2, 4)
const ORC := Vector2i(7, 4)

## Entre la cabane et le chantier, donc **dans** l'enceinte que le pillage compte.
const INSIDE := Vector2i(5, 4)

const EXTENT := Vector2i(9, 9)
const HUT_HP := 6
const SITE_ACTIONS := 3
const MOVE := 3
## Borne de tours des plateaux de cette suite. Large, pour qu'aucun cas qui parle d'autre
## chose ne s'arrête au milieu.
const ROUNDS := 20
const SEED := 4413
const SAMPLES := 12

var _board: CombatBoard

func before_test() -> void:
	_board = _open()

# --- mise en place ---------------------------------------------------------------------

## Un corps entre à plein.
func test_a_deployed_body_stands_at_full_strength() -> void:
	assert_int(_board.body(&"ana").hit_points()).is_equal(10)
	assert_bool(_board.body(&"ana").is_friend()).is_true()

## Ce qui refuse un corps : un bâtiment debout, un chantier, l'eau, un autre corps, et le
## hors carte. Les cinq passent par la même porte, que l'écran de `F3` interrogera avant de
## dessiner une case posable.
func test_what_refuses_a_body() -> void:
	assert_bool(_board.can_stand(HUT)).is_false()
	assert_bool(_board.can_stand(SITE)).is_false()
	assert_bool(_board.can_stand(WATER)).is_false()
	assert_bool(_board.can_stand(ANA)).is_false()
	assert_bool(_board.can_stand(Vector2i(-1, 0))).is_false()

## **Un chantier barre comme un mur.** Il a payé ses cellules à la pose, règle qui vaut
## depuis `C4`, et le combat ne lui fait pas d'exception — la seule différence est ce qu'il
## rapporte en tombant.
func test_a_building_site_blocks_like_a_wall() -> void:
	assert_bool(_board.obstacles().has(SITE)).is_true()

# --- se déplacer -----------------------------------------------------------------------

## Le premier verbe, et son prix.
func test_a_body_moves_and_pays_the_distance() -> void:
	var moved := _board.move(&"ana", ANA + Vector2i(0, 2))
	assert_bool(moved.is_ok()).is_true()
	assert_int(moved.cost()).is_equal(2)
	assert_vector(_board.body(&"ana").cell()).is_equal(ANA + Vector2i(0, 2))

## Un déplacement par tour. Le fractionner ferait de « bouger d'une case pour voir » un
## geste gratuit, donc une annulation à écrire.
func test_a_body_moves_once_per_turn() -> void:
	_board.move(&"ana", ANA + Vector2i(0, 1))
	var again := _board.move(&"ana", ANA + Vector2i(0, 2))
	assert_bool(again.is_ok()).is_false()
	assert_str(again.reason()).is_equal(MoveResult.ALREADY_MOVED)

## On ne joue pas les pions d'en face. C'est la seule chose que le camp décide dans ce
## fichier — le reste des règles ignore à qui appartient un corps.
func test_a_body_of_the_other_camp_does_not_move() -> void:
	var moved := _board.move(&"orc", ORC + Vector2i(0, 1))
	assert_bool(moved.is_ok()).is_false()
	assert_str(moved.reason()).is_equal(MoveResult.WRONG_SIDE)

## Trop loin, barré, ou derrière une marche trop haute : une seule réponse, parce que du
## point de vue de qui joue c'est une seule situation.
func test_out_of_reach_is_one_refusal() -> void:
	assert_str(_board.move(&"ana", ANA + Vector2i(0, 4)).reason()) \
		.is_equal(MoveResult.OUT_OF_REACH)
	assert_str(_board.move(&"ana", HUT).reason()).is_equal(MoveResult.OUT_OF_REACH)

func test_an_unknown_body_does_not_move() -> void:
	assert_str(_board.move(&"nobody", ANA).reason()).is_equal(MoveResult.UNKNOWN_BODY)

# --- frapper ---------------------------------------------------------------------------

## Le second verbe, sur un corps au contact.
func test_a_blow_lands_on_a_body() -> void:
	_board.move(&"ana", HUT + Vector2i(-1, 0))
	var hit := _board.strike(&"ana", HUT + Vector2i(-2, 0))
	assert_bool(hit.is_ok()).is_true()

## **Frapper une case vide réussit.** C'est le cas que l'esquive produit, et il n'est pas
## un échec : le corps a dépensé son coup, la case était vide, et c'est exactement ce que
## l'adversaire avait manœuvré pour obtenir. `DESIGN.md` 3.6 : « Esquiver l'annule —
## l'attaque s'exécute dans le vide. »
func test_a_blow_into_an_empty_cell_is_not_a_failure() -> void:
	var hit := _board.strike(&"ana", ANA + Vector2i(0, 1))
	assert_bool(hit.is_ok()).is_true()
	assert_int(hit.hit()).is_equal(StrikeResult.Hit.NOTHING)
	assert_int(hit.damage()).is_equal(0)
	assert_bool(_board.body(&"ana").has_struck()).is_true()

## **Le coup ne demande pas à qui appartient ce qu'il touche.** 3.6 garde ouverte la
## conséquence — « si un autre corps se trouve sur la case au moment de l'exécution, il
## prend le coup, ennemi compris » — et la règle est écrite dans ce sens dès maintenant,
## pour n'avoir pas à la retourner le jour où des effets de poussée arriveront.
func test_a_blow_hits_whoever_stands_there() -> void:
	var board := _open()
	board.deploy(_unit(&"bo", 3, 3), ANA + Vector2i(1, 0))
	var hit := board.strike(&"ana", ANA + Vector2i(1, 0))
	assert_str(hit.body()).is_equal(&"bo")
	assert_int(board.body(&"bo").hit_points()).is_equal(7)

## Hors de portée, le coup ne part pas — et le corps garde son geste.
func test_a_blow_out_of_range_is_refused() -> void:
	var hit := _board.strike(&"ana", ANA + Vector2i(0, 3))
	assert_bool(hit.is_ok()).is_false()
	assert_str(hit.reason()).is_equal(StrikeResult.OUT_OF_RANGE)
	assert_bool(_board.body(&"ana").has_struck()).is_false()

func test_a_blow_off_the_map_is_refused() -> void:
	var board := _open(1, 1, Vector2i(1, 1))
	board.deploy(_unit(&"edge", 3, 3), Vector2i(0, 0))
	assert_str(board.strike(&"edge", Vector2i(-1, 0)).reason()) \
		.is_equal(StrikeResult.OFF_MAP)

## Un coup par tour, comme un déplacement.
func test_a_body_strikes_once_per_turn() -> void:
	_board.strike(&"ana", ANA + Vector2i(0, 1))
	assert_str(_board.strike(&"ana", ANA + Vector2i(0, 1)).reason()) \
		.is_equal(StrikeResult.ALREADY_STRUCK)

## **Se déplacer et frapper sont indépendants**, ce qui est la lettre de 3.6 — « un tour où
## l'on déplace les ouvriers déployés **et** où chacun agit ». On peut donc frapper puis
## reculer, qui est une décision tactique et non un effet de bord.
func test_striking_leaves_the_move_intact() -> void:
	_board.strike(&"ana", ANA + Vector2i(0, 1))
	assert_bool(_board.move(&"ana", ANA + Vector2i(0, -2)).is_ok()).is_true()

## **Un corps ne frappe pas sa propre case.** La règle de 3.6 dit qu'un coup frappe une
## case et que ce qui s'y trouve encaisse ; elle ne dit rien du frappeur, parce que la
## question ne se posait pas avant qu'un curseur se promene sur la carte. La portée inclut
## la distance zéro, donc sans ce refus un clic mal placé blesserait le sien.
func test_a_body_does_not_strike_its_own_cell() -> void:
	var hit := _board.strike(&"ana", ANA)
	assert_bool(hit.is_ok()).is_false()
	assert_str(hit.reason()).is_equal(StrikeResult.SELF)
	assert_int(_board.body(&"ana").hit_points()).is_equal(10)
	assert_bool(_board.body(&"ana").has_struck()).is_false()

## **Et il ne dépense pas son pas pour ne pas bouger.** `reachable()` rend toujours la case
## de départ à zéro — c'est une vérité sur les distances —, mais le **geste** brûlerait le
## déplacement du tour pour rien.
func test_a_body_does_not_spend_its_step_standing_still() -> void:
	var moved := _board.move(&"ana", ANA)
	assert_bool(moved.is_ok()).is_false()
	assert_str(moved.reason()).is_equal(MoveResult.NO_MOVE)
	assert_bool(_board.body(&"ana").has_moved()).is_false()
	assert_int(_board.reachable(&"ana")[ANA]).is_equal(0)

# --- ce qu'un écran demande avant de dessiner ------------------------------------------

## Les cases à portée, sans la sienne. Au contact, c'est exactement les quatre voisines.
func test_contact_can_strike_its_four_neighbours() -> void:
	var cells := _board.strikeable(&"ana")
	assert_int(cells.size()).is_equal(4)
	for step in CombatMovement.NEIGHBOURS:
		assert_bool(cells.has(ANA + step)).is_true()
	assert_bool(cells.has(ANA)).is_false()

## **Les cases vides en font partie**, et c'est la moitié de l'esquive de 3.6 : filtrer sur
## ce qui s'y trouve ferait d'une case qui s'éteint une information que le joueur n'a pas à
## recevoir avant d'avoir frappé.
func test_an_empty_cell_is_still_strikeable() -> void:
	var empty := ANA + Vector2i(0, 1)
	assert_object(_board.body_at(empty)).is_null()
	assert_bool(_board.strikeable(&"ana").has(empty)).is_true()

## Une portée de trois ouvre le losange de Manhattan, sa propre case retirée.
##
## Le tireur est placé assez loin des bords pour que le losange tienne **entièrement** dans
## la carte : sur un 9×9, une portée de trois déborde dès qu'on s'approche à moins de trois
## cases d'un bord, et le compte tomberait pour une raison qui n'a rien à voir avec la
## règle mesurée. Le bord a son propre cas, juste en dessous.
func test_reach_opens_a_manhattan_diamond() -> void:
	var board := _open()
	board.deploy(_unit_with_reach(&"bow", 3), Vector2i(4, 5))
	assert_int(board.strikeable(&"bow").size()).is_equal(2 * 3 * (3 + 1))

## Le bord de carte borne ce qu'un écran allume : une case hors grille n'est pas une cible,
## et `strike()` la refuse déjà.
func test_the_map_edge_bounds_what_can_be_struck() -> void:
	var board := _open()
	board.deploy(_unit(&"corner", 3, 3), Vector2i(0, 0))
	var cells := board.strikeable(&"corner")
	assert_int(cells.size()).is_equal(2)
	for cell in cells:
		assert_bool(board.terrain().in_bounds(cell)).is_true()

# --- ce que les bâtiments prennent -----------------------------------------------------

## Un coup sur une case bâtie compte pour l'**ancre** : une empreinte de quatre cases n'a
## qu'un jeu de points de vie, et frapper un coin de la ferme, c'est frapper la ferme.
func test_a_blow_on_a_building_counts_against_its_anchor() -> void:
	var board := _blow_at(HUT, 4)
	assert_int(board.damage_taken()[HUT]).is_equal(4)
	assert_bool(board.is_wrecked(HUT)).is_false()

## **Les points sont écrêtés à ce qui restait.** « Il lui restait 2, il a pris 7 » et
## « il lui restait 2, il a pris 2 » sont la même fin, et un rapport qui les distinguerait
## raconterait une graduation que ce jalon n'a pas.
func test_a_blow_is_clipped_to_what_was_left() -> void:
	var board := _blow_at(HUT, HUT_HP + 10)
	assert_int(board.damage_taken()[HUT]).is_equal(HUT_HP)

## Un bâtiment à zéro tombe, et **cesse de barrer sa case**. Sans ça, une ruine
## continuerait de tenir la ligne que ses murs ne tiennent plus.
func test_a_felled_building_stops_blocking() -> void:
	var board := _blow_at(HUT, HUT_HP)
	assert_bool(board.is_wrecked(HUT)).is_true()
	assert_array(board.wrecked()).contains_exactly([HUT])
	assert_bool(board.obstacles().has(HUT)).is_false()
	assert_bool(board.can_stand(HUT)).is_true()

## **Un chantier tombé est une perte qui se raconte**, et c'est pourquoi il est rapporté à
## part. `DESIGN.md` 3.2 : « un chantier à moitié fini détruit la veille de la vague, c'est
## le genre de perte qui se raconte. »
func test_a_felled_site_is_reported_as_interrupted() -> void:
	var board := _blow_at(SITE, HUT_HP)
	assert_array(board.interrupted()).contains_exactly([SITE])

## Et un bâtiment **achevé** qui tombe n'y figure pas. Le cas est le pendant du précédent :
## sans lui, `interrupted()` pourrait rendre tout ce qui tombe sans que rien ne le dise.
func test_a_felled_finished_building_is_not_interrupted() -> void:
	var board := _blow_at(HUT, HUT_HP)
	assert_array(board.interrupted()).is_empty()

## Frapper une ruine ne fait rien de plus. Une seconde vague trouve la case libre, pas un
## bâtiment à re-tuer.
func test_a_wreck_takes_no_more_blows() -> void:
	var board := _blow_at(HUT, HUT_HP)
	board.end_turn()
	board.end_turn()
	var again := board.strike(&"ana", HUT)
	assert_int(again.hit()).is_equal(StrikeResult.Hit.NOTHING)
	assert_int(board.damage_taken()[HUT]).is_equal(HUT_HP)

# --- ce que les corps prennent ---------------------------------------------------------

## Un ouvrier à zéro **meurt**, et il quitte le plateau sans le quitter : il n'est plus
## debout, il ne barre plus, et il est compté. `DESIGN.md` 3.6 assume le choix ; son
## revers — rien ou définitif — est confié à `X6`.
func test_a_worker_at_zero_falls_and_is_counted() -> void:
	var board := _open()
	board.deploy(_unit(&"bo", 20, 20), ANA + Vector2i(1, 0))
	board.strike(&"bo", ANA)
	assert_bool(board.body(&"ana").is_down()).is_true()
	assert_array(board.fallen()).contains_exactly([&"ana"])
	assert_bool(board.obstacles().has(ANA)).is_false()
	assert_array(board.standing(Combatant.Side.FRIEND)) \
		.contains_exactly([board.body(&"bo")])

## Un assaillant tombé n'entre pas dans `fallen()`, qui ne compte que les nôtres : c'est ce
## que `DamageReport.lost()` attend, et un rapport qui mêlerait les deux ferait pleurer un
## village sur ses pillards.
func test_a_fallen_foe_is_not_one_of_ours() -> void:
	var board := _open()
	board.deploy(_unit(&"bo", 20, 20), ORC + Vector2i(0, 1))
	board.strike(&"bo", ORC)
	assert_bool(board.body(&"orc").is_down()).is_true()
	assert_array(board.fallen()).is_empty()
	assert_array(board.standing(Combatant.Side.FOE)).is_empty()

# --- les tours -------------------------------------------------------------------------

## La main passe, et une manche est un tour par camp.
func test_a_round_is_one_turn_each() -> void:
	assert_int(_board.round_number()).is_equal(1)
	assert_int(_board.side()).is_equal(Combatant.Side.FRIEND)
	_board.end_turn()
	assert_int(_board.side()).is_equal(Combatant.Side.FOE)
	assert_int(_board.round_number()).is_equal(1)
	_board.end_turn()
	assert_int(_board.side()).is_equal(Combatant.Side.FRIEND)
	assert_int(_board.round_number()).is_equal(2)

## Le camp qui prend la main retrouve ses gestes, et **seulement lui**. Rafraîchir les deux
## rendrait son tour à quelqu'un qui ne l'a pas encore joué.
func test_taking_the_hand_gives_the_gestures_back() -> void:
	_board.move(&"ana", ANA + Vector2i(0, 1))
	_board.end_turn()
	assert_bool(_board.body(&"ana").has_moved()).is_true()
	_board.end_turn()
	assert_bool(_board.body(&"ana").has_moved()).is_false()

# --- l'aléatoire, et le déterminisme ---------------------------------------------------

## Les dégâts sont une fourchette : un combat entièrement calculable se calcule au lieu de
## se jouer. Le cas vérifie la **borne** et non un tirage — c'est tout ce qu'on peut
## affirmer d'un tirage sans le figer.
func test_a_blow_falls_inside_its_range() -> void:
	for attempt in SAMPLES:
		assert_int(_rolled(attempt)).is_greater_equal(2)
		assert_int(_rolled(attempt)).is_less_equal(6)

## **Et elle est vraiment tirée.** Sans ce cas, un plateau qui rendrait toujours le plancher
## passerait celui du dessus sans qu'on le voie : la borne est vraie d'un chiffre constant.
## Les graines sont fixées, donc le résultat l'est aussi — ce n'est pas un cas probabiliste.
func test_the_range_is_actually_sampled() -> void:
	var seen: Dictionary[int, bool] = {}
	for attempt in SAMPLES:
		seen[_rolled(attempt)] = true
	assert_int(seen.size()).is_greater(1)

## Une fourchette dégénérée, elle, rend toujours le même chiffre. C'est ce qui rend les cas
## de règle de ce fichier lisibles, et le cas est là pour que ça reste vrai.
func test_a_degenerate_range_never_varies() -> void:
	for attempt in SAMPLES:
		assert_int(_rolled(attempt, 3, 3)).is_equal(3)

## **Le cas qui porte le fichier.** Deux plateaux ouverts pareils et joués pareil finissent
## pareils, tirages compris. C'est la promesse de `CLAUDE.md` sur le déterminisme appliquée
## à la bataille : sans elle, un run rejoué depuis son seed divergerait à la première vague
## et tout l'équilibrage de `I3` deviendrait invérifiable.
func test_two_boards_played_alike_end_alike() -> void:
	assert_array(_scripted().fallen()).is_equal(_scripted().fallen())
	assert_dict(_scripted().damage_taken()).is_equal(_scripted().damage_taken())
	assert_int(_scripted().body(&"orc").hit_points()) \
		.is_equal(_scripted().body(&"orc").hit_points())

# --- la borne, et le départ de la vague -------------------------------------------------

## **Tenir la borne suffit à ce que la vague reparte.** `DESIGN.md` 3.6 : une vague est une
## razzia, pas un duel. Il n'y a donc ni victoire ni défaite — seulement une facture.
func test_a_battle_ends_once_the_round_cap_is_passed() -> void:
	var board := _open(3, 3, EXTENT, SEED, 2)
	assert_bool(board.is_over()).is_false()
	for _turn in 4:
		board.end_turn()
	assert_int(board.round_number()).is_equal(3)
	assert_bool(board.is_over()).is_true()

## Et battre le dernier assaillant y met fin aussi, sans attendre la borne. C'est le
## nettoyage complet que 3.6 récompense « par-dessus » ; ce qu'il vaut est `I3`.
func test_a_battle_ends_when_the_last_attacker_falls() -> void:
	var board := _open()
	board.deploy(_unit(&"hitter", 20, 20), ORC + Vector2i(0, -1))
	board.strike(&"hitter", ORC)
	assert_bool(board.swept()).is_true()
	assert_bool(board.is_over()).is_true()

## Un plateau où personne n'est entré n'a balayé personne. Le rendre vrai par vacuité ferait
## passer une bataille qui n'a pas eu lieu pour une victoire nette.
func test_a_board_no_attacker_entered_has_swept_nothing() -> void:
	var quiet := _open(3, 3, Vector2i(4, 4))
	assert_bool(quiet.swept()).is_false()
	assert_bool(quiet.is_over()).is_false()

## **Un village vidé de ses défenseurs ne met pas fin à la bataille.** Les manches restantes
## se jouent sans lui, et c'est ce qui rend la fuite coûteuse : une razzia qui s'arrêterait
## faute d'adversaire récompenserait le fait de ne plus en avoir.
func test_losing_every_defender_does_not_end_the_battle() -> void:
	var board := _open()
	board.send(&"beast", _make_enemy(20, 20), ANA + Vector2i(1, 0))
	board.end_turn()
	board.strike(&"beast", ANA)
	assert_array(board.fallen()).contains_exactly([&"ana"])
	assert_bool(board.is_over()).is_false()

# --- ce que la vague annonce ------------------------------------------------------------

## Une annonce vaut pour un tour, donc la table **remplace** la précédente. Un reliquat de la
## manche d'avant serait une case allumée que plus personne ne frappera.
func test_announcing_replaces_the_previous_table() -> void:
	var board := _open()
	var aimed: Dictionary[StringName, CombatIntent] = {&"orc": CombatIntent.strike(HUT)}
	board.announce(aimed)
	assert_bool(board.intent_of(&"orc").is_bound()).is_true()
	var coming: Dictionary[StringName, CombatIntent] = {&"orc": CombatIntent.advance()}
	board.announce(coming)
	assert_bool(board.intent_of(&"orc").is_bound()).is_false()
	assert_int(board.intents().size()).is_equal(1)

## Un corps qui n'a rien annoncé **avance**, et ce n'est pas un cas d'erreur : c'est ce que
## fera un renfort entré après le tour d'annonce, le jour où `X6` en enverra.
func test_a_body_that_announced_nothing_advances() -> void:
	assert_int(_board.intent_of(&"orc").kind()).is_equal(CombatIntent.Kind.ADVANCE)

# --- ce que la vague emporte ------------------------------------------------------------

## **Le butin court par manche passée dans l'enceinte**, ce que `DESIGN.md` 3.6 appelle « ce
## qu'ils ont cassé et emporté entre-temps ». Il s'accumule pendant la bataille et non à son
## départ, ce qui fait payer les deux bonnes façons de jouer.
func test_an_attacker_inside_the_walls_carries_off_its_share_each_round() -> void:
	var board := _open()
	board.send(&"thief", _make_looter(2), INSIDE)
	_a_round(board)
	assert_int(board.plunder()).is_equal(2)
	_a_round(board)
	assert_int(board.plunder()).is_equal(4)

## Et une vague tenue dehors repart les mains vides, sans qu'une règle ait à le dire.
func test_an_attacker_held_outside_carries_nothing_off() -> void:
	var board := _open()
	board.send(&"thief", _make_looter(2), ORC + Vector2i(0, -1))
	_a_round(board)
	assert_int(board.plunder()).is_equal(0)

## Un assaillant tombé ne pille plus. C'est la moitié de la règle qui fait payer le nettoyage
## sans qu'aucun bonus n'ait à être chiffré.
func test_a_fallen_attacker_stops_looting() -> void:
	var board := _open()
	board.send(&"thief", _make_looter(2), INSIDE)
	board.deploy(_unit(&"hitter", 20, 20), INSIDE + Vector2i(0, -1))
	board.strike(&"hitter", INSIDE)
	_a_round(board)
	assert_int(board.plunder()).is_equal(0)

## **L'enceinte ne rétrécit pas quand un mur tombe.** La recalculer ferait rapporter *moins*
## à une vague qui casse *plus*, ce qui est l'inverse de ce qu'on veut : le village qu'on
## pille est celui qu'on a trouvé en arrivant.
func test_the_enclosure_does_not_shrink_when_a_wall_falls() -> void:
	var board := _blow_at(SITE, HUT_HP)
	assert_bool(board.is_wrecked(SITE)).is_true()
	assert_vector(board.enclosure().size).is_equal(Vector2i(3, 1))

# --- le rapport -------------------------------------------------------------------------

## **Le producteur que `DESIGN.md` 3.6 réclame depuis `F1`**, et il ne calcule rien : tout ce
## qu'il rend, le plateau le tenait déjà. C'est ce qui laissera l'applicateur de
## `RunOrchestrator.fight()` intact à `F3b`.
func test_the_report_carries_what_the_battle_did() -> void:
	var board := _open(HUT_HP, HUT_HP)
	board.deploy(_unit(&"bo", HUT_HP, HUT_HP), HUT + Vector2i(0, -1))
	board.strike(&"bo", HUT)
	board.end_turn()
	board.strike(&"orc", SITE)
	var report := board.to_report()
	assert_dict(report.damaged()).contains_keys([HUT, SITE])
	assert_array(report.destroyed()).contains_exactly([HUT, SITE])
	assert_array(report.interrupted()).contains_exactly([SITE])
	assert_bool(report.is_held()).is_false()
	assert_bool(report.swept()).is_false()

## Un village que rien n'a entamé rend un rapport **tenu**, ce qui est l'état d'un joueur qui
## a bien joué et non une erreur.
func test_an_untouched_village_reports_a_held_wave() -> void:
	assert_bool(_board.to_report().is_held()).is_true()

## La ligne est payée en entier, **tombés compris** : un mort a tenu la ligne, et
## `DamageReport.fighters()` en dépend.
func test_the_report_pays_the_line_including_the_fallen() -> void:
	var board := _open()
	board.send(&"beast", _make_enemy(20, 20), ANA + Vector2i(1, 0))
	board.end_turn()
	board.strike(&"beast", ANA)
	var report := board.to_report()
	assert_array(report.lost()).contains_exactly([&"ana"])
	assert_array(report.fighters()).contains_exactly([&"ana"])


# --- fabrique --------------------------------------------------------------------------

## Une bataille jouée d'avance, toujours la même : on approche, on cogne le chantier, on
## passe la main, l'assaillant riposte.
func _scripted() -> CombatBoard:
	var board := _open(1, 8)
	board.move(&"ana", ANA + Vector2i(3, 0))
	board.strike(&"ana", HUT)
	board.end_turn()
	board.move(&"orc", ORC + Vector2i(-1, 0))
	board.strike(&"orc", HUT)
	return board

## Une manche entière pendant laquelle personne n'agit : on passe la main, puis on la
## reprend. C'est la fermeture du tour de la vague qui compte le butin, donc les deux
## `end_turn()` sont nécessaires et le second ne peut pas être sous-entendu.
func _a_round(board: CombatBoard) -> void:
	board.end_turn()
	board.end_turn()

## Un assaillant dont la seule particularité est ce qu'il emporte.
func _make_looter(loot: int) -> EnemyData:
	var enemy := _make_enemy(1, 1)
	enemy.plunder = loot
	return enemy


## Un plateau où `ana` a frappé cette case de ce coup, une fois.
func _blow_at(cell: Vector2i, blow: int) -> CombatBoard:
	var board := _open()
	board.deploy(_unit(&"hitter", blow, blow), cell + Vector2i(-1, 0))
	board.strike(&"hitter", cell)
	return board

## Ce qu'un coup de `ana` porte sur un mannequin, avec cette graine.
##
## Le mannequin a de quoi encaisser : sans lui le coup partirait dans le vide et rendrait
## zéro, ce qui est dans aucune fourchette. Le piège s'est refermé une fois en écrivant ce
## fichier, et il est silencieux — un coup dans le vide est un succès.
func _rolled(salt: int, low := 2, high := 6) -> int:
	var board := _open(low, high, EXTENT, SEED + salt)
	board.deploy(_unit(&"dummy", 1, 1), ANA + Vector2i(1, 0))
	return board.strike(&"ana", ANA + Vector2i(1, 0)).damage()

func _open(low := 3, high := 3, extent := EXTENT, grain := SEED,
		rounds := ROUNDS) -> CombatBoard:
	var rng := RandomNumberGenerator.new()
	rng.seed = grain
	var board := CombatBoard.open(_make_grid(extent).to_query(), _make_city(extent),
		_make_balance(), rng, rounds)
	if extent != EXTENT:
		return board
	board.deploy(_unit(&"ana", low, high), ANA)
	board.send(&"orc", _make_enemy(low, high), ORC)
	return board

## Un ouvrier dont la seule particularité est sa portée.
func _unit_with_reach(id: StringName, reach: int) -> CombatUnit:
	return CombatUnit.create(id, CombatUnit.BASE_EFFICIENCY,
		CombatStats.create(10, 3, 3, reach, MOVE, 1))

func _unit(id: StringName, low: int, high: int) -> CombatUnit:
	return CombatUnit.create(id, CombatUnit.BASE_EFFICIENCY,
		CombatStats.create(10, low, high, CombatStats.CONTACT, MOVE, 1))

func _make_enemy(low: int, high: int) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = &"orc"
	enemy.label = "Orc"
	enemy.hit_points = 10
	enemy.damage_min = low
	enemy.damage_max = high
	enemy.reach = CombatStats.CONTACT
	enemy.move = MOVE
	enemy.climb = 1
	return enemy

func _make_city(extent: Vector2i) -> CitySnapshot:
	if extent != EXTENT:
		return CitySnapshot.empty()
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(_make_building(), HUT, 0, 0, SITE_ACTIONS),
		BuildingSnapshot.create(_make_building(), SITE, 0, 0, 0)]
	return CitySnapshot.create(placed)

func _make_building() -> BuildingData:
	var data := BuildingData.new()
	data.id = &"hut"
	data.hit_points = HUT_HP
	data.build_actions = SITE_ACTIONS
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return data

func _make_grid(extent: Vector2i) -> HeightGrid:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	var grid := HeightGrid.create(extent, 0, plain)
	if extent != EXTENT:
		return grid
	var water := TerrainData.new()
	water.id = &"water"
	water.build = TerrainData.Build.BLOCKED
	water.tags.append(&"water")
	grid.set_terrain(WATER, water)
	return grid

func _make_balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.climb_cost = 1
	balance.impassable_tags = [&"water"] as Array[StringName]
	balance.spawn_margin = 2
	balance.combat_skill_family = &"combat"
	return balance
