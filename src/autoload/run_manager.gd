extends Node
## Possède l'état du run courant, pilote le DayCycle, et publie les résultats du domaine
## sur EventBus.
##
## Unique pont domaine -> adapters : aucun autre Node n'appelle le domaine, et le domaine
## ne connaît ni ce fichier ni EventBus.
##
## I0 en avait fait une coquille qui ne portait que le seed et le RNG, avec cette note :
## « ils déménageront sur RunState à I1. DayCycle et la séquence de résolution arrivent
## avec. » C'est fait. Le seed et le RNG vivent maintenant dans RunState, et ce fichier ne
## garde plus rien qui lui appartienne en propre.
##
## Ce qu'il fait, et c'est tout : il **traduit**. Un appel d'adapter devient un appel
## d'orchestrateur, et un résultat de domaine devient un signal. Il ne décide de rien —
## pas une règle, pas un chiffre, pas un ordre de résolution. Chercher ici pourquoi une
## carte est refusée, c'est chercher au mauvais endroit : la réponse vient du domaine et
## ne fait que passer.
##
## Il ne construit pas non plus le run. `open()` reçoit un RunState déjà ouvert, parce que
## le relief, le roster et le catalogue viennent de trois endroits — la génération,
## le recrutement qui reste `OUVERT`, et GameDatabase — dont aucun n'est de son ressort.
## C'est l'appelant qui compose, et c'est ce qui permet à un harnais d'ouvrir un run sur
## des données bidon sans que ce fichier ait à le savoir.

## Le run courant, ou null hors run.
var _state: RunState = null

## Un run est-il ouvert ?
func is_running() -> bool:
	return _state != null

## Le run courant, ou null. C'est par lui que l'UI lit la ville, la réserve et la main.
func state() -> RunState:
	return _state

## Seed du run courant. Ce seed plus la même suite d'actions rejoue le run à l'identique.
func get_run_seed() -> int:
	if _state == null:
		return 0
	return _state.run_seed()

## RNG du run courant, ou null hors run. Tout l'aléatoire du jeu passe par lui.
func get_rng() -> RandomNumberGenerator:
	if _state == null:
		return null
	return _state.rng()

## Phase courante, ou null hors run et une fois le run terminé. C'est d'elle que l'UI tire
## son libellé et les boutons qu'elle allume.
func phase() -> PhaseDef:
	if _state == null or _state.cycle().is_over():
		return null
	return _state.cycle().phase()

## La vague qui attend, ou null. C'est d'elle que l'UI tire le libellé qu'elle annonce.
func pending_wave() -> WaveDef:
	if _state == null:
		return null
	return _state.pending_wave()

## Comment le run s'est terminé, ou null tant qu'il tourne.
func outcome() -> RunOutcome:
	if _state == null:
		return null
	return _state.outcome()

## Ouvre ce run et l'annonce.
##
## Il n'annonce **pas** de phase quand le run attend son Cœur : la première journée n'a pas
## commencé, et dire le contraire allumerait un bandeau de phase au-dessus d'une carte
## nue. C'est `found()` qui l'annoncera.
func open(state: RunState) -> void:
	assert(state != null, "ouverture d'un run nul")
	assert(not is_running(), "un run est déjà ouvert")
	_state = state
	EventBus.run_started.emit(state.run_seed())
	if not state.awaits_its_heart():
		EventBus.phase_changed.emit(state.cycle().day(), state.cycle().phase().id)

## Pose le Cœur et ouvre la première journée. Rend le verdict du domaine, tel quel.
func found(cell: Vector2i, turns := 0) -> PlayResult:
	assert(is_running(), "fondation hors run")
	var result := RunOrchestrator.found(_state, cell, turns)
	if result.is_ok():
		EventBus.phase_changed.emit(_state.cycle().day(), _state.cycle().phase().id)
	return result

## Fait tomber la vague en attente et publie ce qu'elle a coûté.
##
## La **seconde porte** de `DESIGN.md` 3.8 : la fin de journée s'arrête sur une bataille,
## et c'est celle-ci qui la reprend. Les trois signaux qui suivent sont les mêmes qu'une
## fin de phase, dans le même ordre et pour la même raison — le rapport d'abord, parce
## qu'il décrit ce qui vient de se passer et non ce qui commence.
func fight() -> BattleReport:
	assert(is_running(), "vague hors run")
	var report := RunOrchestrator.fight(_state)
	EventBus.battle_resolved.emit(report)
	_announce_what_comes_next()
	return report

## Joue une carte et rend le verdict du domaine, tel quel.
func play(card: StringName, cell: Vector2i, turns := 0,
		direction := PlayedAction.DIRECTION_NONE) -> PlayResult:
	assert(is_running(), "carte jouée hors run")
	return RunOrchestrator.play(_state, card, cell, turns, direction)

## Retire une action posée et rappelle ses ouvriers.
func withdraw(action: int) -> bool:
	assert(is_running(), "retrait hors run")
	return RunOrchestrator.withdraw(_state, action)

## Envoie un ouvrier sur une action posée.
func staff(worker: StringName, action: int) -> bool:
	assert(is_running(), "affectation hors run")
	return RunOrchestrator.staff(_state, worker, action)

## Remplit les postes libres au mieux et rend les ouvriers que ça vient de placer.
func auto_staff() -> Array[StringName]:
	assert(is_running(), "auto-affectation hors run")
	return RunOrchestrator.auto_staff(_state)

## Rappelle tous les ouvriers d'une action.
func unstaff(action: int) -> Array[StringName]:
	assert(is_running(), "rappel hors run")
	return RunOrchestrator.unstaff(_state, action)

## Termine la phase courante et publie ce qui en sort.
##
## Trois signaux possibles pour un seul geste, et c'est la seule logique de ce fichier :
## une phase résolue, puis ce qui vient ensuite. Ils sont émis dans cet ordre — le rapport
## d'abord, parce qu'il décrit la phase qui vient de finir et non celle qui commence.
##
## « Ce qui vient ensuite » a trois formes depuis `I2`, et non plus deux : la phase
## suivante, la fin du run, ou **une bataille qui attend**. La troisième est la coupure de
## `DESIGN.md` 3.8, et elle se voit ici en une ligne — le cycle n'a pas avancé, donc
## annoncer une phase entrante serait annoncer celle qui vient de finir.
func end_phase() -> PhaseReport:
	assert(is_running(), "fin de phase hors run")
	var report := RunOrchestrator.end_phase(_state)
	if report != null:
		EventBus.phase_resolved.emit(report)
	_announce_what_comes_next()
	return report

## Referme le run courant.
##
## Le score n'est plus un argument : il est dans l'issue que le domaine a posée, et le
## faire venir de l'appelant laisserait un écran libre d'annoncer un chiffre que personne
## n'a calculé.
func close() -> void:
	assert(is_running(), "aucun run n'est ouvert")
	var ending := _state.outcome()
	_state = null
	EventBus.run_ended.emit(ending)

## Annonce ce qui suit une résolution : une bataille, une fin, ou la phase suivante.
##
## Écrit une fois pour les deux portes qui ferment quelque chose — la fin d'une phase et la
## fin d'une bataille —, parce que ces deux-là mènent exactement aux mêmes trois suites.
## Les dédoubler laisserait dériver l'ordre des signaux entre une journée paisible et une
## journée qui se bat, ce qu'aucun écran ne pourrait rattraper.
func _announce_what_comes_next() -> void:
	if _state.awaits_its_heart():
		return
	if _state.awaits_a_battle():
		EventBus.battle_pending.emit(_state.pending_wave().id)
		return
	if _state.cycle().is_over():
		EventBus.run_finished.emit(_state.outcome())
		return
	EventBus.phase_changed.emit(_state.cycle().day(), _state.cycle().phase().id)
