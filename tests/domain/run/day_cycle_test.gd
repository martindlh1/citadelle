class_name DayCycleTest
extends GdUnitTestSuite
## Où l'on en est dans la journée, et dans le run.
##
## **Aucun nom de phase n'apparaît dans ce fichier**, et c'est le cas qui le porte tout
## entier. `DESIGN.md` 2 exige que le cycle ne code ni matin ni soir en dur ; une suite de
## tests qui écrirait `&"evening"` pour vérifier une règle figerait exactement ce que le
## design garde ouvert, et rendrait l'arbitrage de `I2b` plus coûteux qu'un échange de
## `.tres`. Les phases fabriquées ici s'appellent `first`, `second`, `third`.
##
## Aucun chiffre non plus : la durée d'un run est un `OUVERT`, et les cas travaillent sur
## des journées de deux ou trois jours parce que c'est ce qui se lit, pas parce que c'est
## ce que `data/` contient.

func test_a_cycle_opens_on_the_first_phase_of_the_first_day() -> void:
	var cycle := _cycle_of(2, 3)
	assert_int(cycle.day()).is_equal(1)
	assert_int(cycle.phase_index()).is_equal(0)
	assert_bool(cycle.is_over()).is_false()

func test_advancing_walks_the_phases_of_a_day() -> void:
	var cycle := _cycle_of(3, 2)
	assert_bool(cycle.advance()).is_false()
	assert_int(cycle.phase_index()).is_equal(1)
	assert_int(cycle.day()).is_equal(1)
	assert_bool(cycle.advance()).is_false()
	assert_int(cycle.phase_index()).is_equal(2)

## Le booléen rendu par advance() porte ce qu'un appelant ne peut pas déduire sans avoir
## gardé l'état d'avant : le jour a changé.
func test_the_last_phase_of_a_day_opens_the_next_one() -> void:
	var cycle := _cycle_of(2, 3)
	cycle.advance()
	assert_bool(cycle.advance()).is_true()
	assert_int(cycle.day()).is_equal(2)
	assert_int(cycle.phase_index()).is_equal(0)

func test_a_run_ends_after_the_last_phase_of_the_last_day() -> void:
	var cycle := _cycle_of(2, 2)
	for _step in 4:
		cycle.advance()
	assert_bool(cycle.is_over()).is_true()
	assert_int(cycle.day()).is_equal(3)

## Un run terminé n'avance plus et le dit en rendant faux, ce qui rend une boucle
## « tant que ça avance » sûre sans garde.
func test_a_finished_run_does_not_advance() -> void:
	var cycle := _cycle_of(1, 1)
	assert_bool(cycle.advance()).is_true()
	assert_bool(cycle.is_over()).is_true()
	assert_bool(cycle.advance()).is_false()
	assert_int(cycle.day()).is_equal(2)

## Les deux questions que l'UI pose à chaque image. Une réponse plutôt qu'un assert :
## c'est ce qui lui permet de griser un bouton au lieu de faire tomber le jeu.
func test_a_phase_answers_for_what_it_declares() -> void:
	var first := _phase(&"first", [PhaseDef.ACTION_PLAY], false)
	var second := _phase(&"second", [PhaseDef.ACTION_ASSIGN], true)
	var phases: Array[PhaseDef] = [first, second]
	var cycle := DayCycle.create(phases, 1)
	assert_bool(cycle.permits(PhaseDef.ACTION_PLAY)).is_true()
	assert_bool(cycle.permits(PhaseDef.ACTION_ASSIGN)).is_false()
	assert_bool(cycle.resolves()).is_false()
	cycle.advance()
	assert_bool(cycle.permits(PhaseDef.ACTION_ASSIGN)).is_true()
	assert_bool(cycle.resolves()).is_true()

## La fin de journée est la fin de la dernière phase, et rien d'autre. Ce n'est pas un
## champ de `PhaseDef` parce qu'un booléen en data pourrait dire le contraire de la liste
## qui le porte, et personne ne saurait lequel des deux croire.
func test_only_the_last_phase_of_a_day_closes_it() -> void:
	var cycle := _cycle_of(3, 2)
	assert_bool(cycle.closes_the_day()).is_false()
	cycle.advance()
	assert_bool(cycle.closes_the_day()).is_false()
	cycle.advance()
	assert_bool(cycle.closes_the_day()).is_true()
	cycle.advance()
	assert_int(cycle.day()).is_equal(2)
	assert_bool(cycle.closes_the_day()).is_false()

## Une journée d'une seule phase se ferme à chaque phase, ce qui est cohérent et non un
## cas particulier.
func test_a_single_phase_day_closes_on_that_phase() -> void:
	assert_bool(_cycle_of(1, 3).closes_the_day()).is_true()

## Fermer la journée et résoudre sont deux questions distinctes : une journée coûte à
## nourrir même si sa dernière phase ne produit rien.
func test_closing_the_day_does_not_depend_on_resolving() -> void:
	var phases: Array[PhaseDef] = [
		_phase(&"first", [PhaseDef.ACTION_PLAY], true),
		_phase(&"last", [PhaseDef.ACTION_PLAY], false)]
	var cycle := DayCycle.create(phases, 1)
	assert_bool(cycle.resolves()).is_true()
	assert_bool(cycle.closes_the_day()).is_false()
	cycle.advance()
	assert_bool(cycle.resolves()).is_false()
	assert_bool(cycle.closes_the_day()).is_true()

func test_a_finished_run_closes_no_day() -> void:
	var cycle := _cycle_of(1, 1)
	cycle.advance()
	assert_bool(cycle.closes_the_day()).is_false()

## Un run terminé n'autorise rien et ne résout rien. Sans cette réponse, l'UI d'un run
## fini interrogerait une phase qui n'existe plus.
func test_a_finished_run_permits_nothing_and_resolves_nothing() -> void:
	var cycle := _cycle_of(1, 1)
	cycle.advance()
	assert_bool(cycle.permits(PhaseDef.ACTION_PLAY)).is_false()
	assert_bool(cycle.resolves()).is_false()

## Le cycle recopie la liste qu'on lui donne : elle vient d'une Resource d'équilibrage
## partagée, et un cycle qui la garderait vivante se ferait réécrire sous les pieds par
## une passe qui rechargerait data/.
func test_a_cycle_does_not_follow_the_list_it_was_given() -> void:
	var phases: Array[PhaseDef] = [_phase(&"first", [PhaseDef.ACTION_PLAY], true)]
	var cycle := DayCycle.create(phases, 2)
	phases.append(_phase(&"second", [PhaseDef.ACTION_ASSIGN], false))
	assert_int(cycle.phase_count()).is_equal(1)

## Une journée d'une seule phase est parfaitement valide, et c'est le troisième modèle
## que DESIGN.md 2 dit vouloir pouvoir tester sans toucher au code.
func test_a_single_phase_day_is_a_valid_day() -> void:
	var cycle := _cycle_of(1, 3)
	assert_bool(cycle.advance()).is_true()
	assert_int(cycle.day()).is_equal(2)
	assert_int(cycle.phase_index()).is_equal(0)

## Une journée de N phases sur D jours en compte N × D, et rien ne saute.
func test_a_run_walks_every_phase_of_every_day() -> void:
	var cycle := _cycle_of(3, 4)
	var walked := 0
	while not cycle.is_over():
		walked += 1
		cycle.advance()
	assert_int(walked).is_equal(12)

## Une journée de phases anonymes, toutes permissives, la dernière résolvant.
func _cycle_of(phases_per_day: int, days: int) -> DayCycle:
	var names: Array[StringName] = [&"first", &"second", &"third", &"fourth"]
	var phases: Array[PhaseDef] = []
	for index in phases_per_day:
		phases.append(_phase(names[index], [PhaseDef.ACTION_PLAY],
			index == phases_per_day - 1))
	return DayCycle.create(phases, days)

func _phase(id: StringName, allows: Array, resolves: bool) -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = id
	phase.label = String(id)
	var kinds: Array[StringName] = []
	kinds.assign(allows)
	phase.allows = kinds
	phase.resolves = resolves
	return phase
