class_name RunOrchestrator
extends RefCounted
## Ce qu'on peut faire d'un run, et ce qu'un soir en fait.
##
## `DESIGN.md` 3.8 : « Le seul système qui connaît tous les autres. C'est volontaire : il
## orchestre, les autres s'ignorent. » Ce fichier est cette phrase. Il appelle les quatre
## résolveurs — placement, production, chantiers, XP — dans l'ordre de 2, et il est le
## seul endroit du domaine où deux systèmes se voient.
##
## Il ne **calcule** rien. Chaque question part chez celui qui sait y répondre : « puis-je
## poser ici ? » à `PlacementValidator`, « puis-je jouer là ? » à `ActionTargeting`, « que
## rapporte le soir ? » à `ProductionResolver`, « que bâtit-il ? » à `SiteResolver`, « qui
## progresse ? » à `SkillResolver`. Ce que ce fichier ajoute est ce qu'aucun d'eux ne peut
## faire seul : **enchaîner deux questions** et **appliquer un ordre**.
##
## Les deux choses qu'il apporte à `I1`, et elles sont exactement celles que `D2` avait
## laissées :
##
##   - **la bourse au moment de bâtir.** `DESIGN.md` 3.2 le dit depuis `C1` : « Ai-je les
##     15 bois ? » ne regarde pas la carte, et « c'est la couche qui orchestre la journée
##     qui pose les deux questions à la suite ». La voici.
##   - **l'exécution de *Construire* et *Terraformer*.** Le `SiteResolver` ordonne, ce
##     fichier applique — c'est le seul à tenir à la fois le `CityState` et la
##     `HeightGrid`, donc le seul qui **puisse** les appliquer sans casser la règle de
##     dépendance.
##
## Statique et sans état, comme tous les résolveurs : ce qui persiste est dans `RunState`.

## Joue cette carte sur cette cellule. Rend ce que ça a posé, ou pourquoi ça a été refusé.
##
## La porte **unique** du jeu d'une carte, quelle que soit sa nature : le joueur ne fait
## qu'un geste — prendre une carte, cliquer une cellule —, et que l'une pose une action
## quand l'autre ouvre un chantier est une asymétrie du domaine, pas de l'intention.
##
## `turns` ne sert qu'à une carte de bâtiment, `direction` qu'à un verbe qui déplace de la
## terre. Leurs défauts les rendent invisibles au reste, comme le `turns` de
## `CityState.place()` avant eux.
static func play(state: RunState, card: StringName, cell: Vector2i, turns := 0,
		direction := PlayedAction.DIRECTION_NONE) -> PlayResult:
	assert(state != null, "jeu sans run")
	if not state.cycle().permits(PhaseDef.ACTION_PLAY):
		return PlayResult.refused(PlayResult.REASON_WRONG_PHASE)
	if not state.deck().hand().has(card):
		return PlayResult.refused(PlayResult.REASON_NOT_IN_HAND)
	var catalogue := state.catalogue()
	if catalogue.has(card) and catalogue.card(card).places_a_building():
		return _open_site(state, card, cell, turns)
	if ActionTargeting.handles(card):
		return _post_action(state, card, cell, direction)
	return PlayResult.refused(PlayResult.REASON_UNKNOWN_CARD)

## Retire une action posée et rappelle ses ouvriers. Faux si rien ne porte ce numéro.
##
## Le rappel des ouvriers est fait ici et non laissé à l'appelant. Le domaine supporte
## très bien qu'une affectation survive à son action — le résolveur la saute et l'ouvrier
## chôme —, mais c'est une façon coûteuse de perdre de la main-d'œuvre, et la rattraper au
## même endroit que le retrait évite d'avoir à y penser.
##
## La carte, elle, ne revient pas en main : elle est à la défausse depuis qu'on l'a jouée.
## C'est l'état par défaut et non une réponse — le sort des cartes est l'`OUVERT` de 3.5,
## et `I2b` le tranchera devant un vrai playtest.
static func withdraw(state: RunState, action: int) -> bool:
	assert(state != null, "retrait sans run")
	if not state.cycle().permits(PhaseDef.ACTION_PLAY):
		return false
	if not state.board().has(action):
		return false
	state.release_action(action)
	return state.board().withdraw(action)

## Envoie cet ouvrier sur cette action. Faux si la phase, l'action ou l'ouvrier s'y
## opposent.
##
## Un booléen et non un DTO à raison, contrairement à `play()` : les quatre refus possibles
## se voient tous à l'écran avant le clic — la phase est affichée, la capacité est
## affichée, les ouvriers libres sont listés —, alors qu'un refus de jeu dépend d'un
## balayage de règles que seul le domaine connaît.
static func staff(state: RunState, worker: StringName, action: int) -> bool:
	assert(state != null, "affectation sans run")
	if not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
		return false
	var posted := state.board().at(action)
	if posted == null:
		return false
	if not state.roster().has(worker) or not state.roster().worker(worker).is_present():
		return false
	if state.is_staffed(worker):
		return false
	if state.staffed_on(action).size() >= posted.capacity():
		return false
	state.assign_worker(worker, action)
	return true

## Rappelle tous les ouvriers d'une action et rend leurs identifiants.
static func unstaff(state: RunState, action: int) -> Array[StringName]:
	assert(state != null, "rappel sans run")
	if not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
		var none: Array[StringName] = []
		return none
	return state.release_action(action)

## Résout le soir : la séquence de `DESIGN.md` 2, réduite à ce qui existe.
##
## Actions jouées — production **et** chantiers —, puis gain d'XP, puis rapport.
## L'événement de 3.7 et le combat de `F1` entreront entre les deux, et l'ordre est déjà
## le bon. L'upkeep est prélevé par le résolveur de production, à sa place dans la
## séquence.
##
## **Les deux résolveurs voient la même ville**, celle d'avant le soir, et l'ordre compte :
## les chantiers s'appliquent **après** que la production a été calculée. Sans cette
## règle, un entrepôt achevé ce soir relèverait la réserve du même soir, et un chantier
## fini avant qu'une récolte ne soit lue déciderait du rendement — donc l'ordre des cartes
## posées déciderait du résultat. C'est exactement ce que `E1` a refusé pour l'écrêtage, et
## pour la même raison : deux villes identiques bâties dans un ordre différent doivent
## rendre la même chose.
static func resolve(state: RunState) -> EveningReport:
	assert(state != null, "résolution sans run")
	assert(not state.cycle().is_over(), "résolution d'un run terminé")
	var balance := state.balance()
	var plan := state.board().to_plan()
	var assign := state.to_assignment()
	var labor := state.labor()
	var snapshot := state.city().to_snapshot()

	var production := ProductionResolver.resolve(state.terrain(), snapshot, plan, assign,
		labor, state.ledger(), balance.economy, balance.actions)
	var sites := SiteResolver.resolve(snapshot, plan, assign, labor, balance.actions)
	var completed := _apply(state, sites)

	var lines := production.work()
	lines.append_array(sites.work())
	var progress := SkillResolver.award_lines(state.roster(), lines, balance.workforce)

	return EveningReport.create(state.cycle().day(), state.cycle().phase().id, production,
		sites, progress, _idle(labor, lines), completed)

## Termine la phase courante et passe à la suivante. Rend le rapport si elle résolvait,
## null sinon.
##
## **Le board ne se vide qu'après une résolution**, jamais à chaque frontière de phase : il
## traverse la journée, puisque `D2` a fait de « poser une carte » et « y envoyer des
## ouvriers » deux gestes que rien n'oblige à tenir dans la même phase. Vider entre les
## deux effacerait ce que la première a fait.
##
## Repiocher suit `resolves` et non le calendrier, ce qui est ce qui permet aux deux
## modèles de journée de `DESIGN.md` 2 de se comporter sensément sans qu'un nom de phase
## soit écrit : une journée à deux phases dont une résout rend une main par jour, une
## journée à deux phases qui résolvent toutes les deux en rend deux.
##
## Ce que ça décide du sort de la main non jouée — elle est défaussée — est l'état par
## défaut de l'`OUVERT` de 3.5 et non une réponse. `I2b` le tranchera.
static func end_phase(state: RunState) -> EveningReport:
	assert(state != null, "fin de phase sans run")
	if state.cycle().is_over():
		return null
	var report: EveningReport = null
	if state.cycle().resolves():
		report = resolve(state)
		state.board().clear()
		state.clear_staffing()
		state.deck().discard_hand()
	state.cycle().advance()
	if report != null and not state.cycle().is_over():
		state.draw_phase()
	return report

## Ouvre un chantier, si la carte se pose **et** si la réserve suit.
##
## Les deux questions, dans cet ordre. Le placement d'abord parce que c'est le refus que
## le fantôme montre déjà sous le curseur : demander « ai-je les 15 bois ? » à propos d'une
## case où l'on ne peut de toute façon pas bâtir serait une réponse à côté de la question.
##
## Rien n'est muté avant que les deux soient passées : ni demi-paiement, ni chantier
## gratuit. C'est la même règle que `Ledger.spend()`, qui est tout ou rien.
static func _open_site(state: RunState, card: StringName, cell: Vector2i,
		turns: int) -> PlayResult:
	var data := state.building(state.catalogue().card(card).building)
	assert(data != null, "la carte %s pose un bâtiment absent du catalogue du run" % card)
	if data == null:
		return PlayResult.refused(PlayResult.REASON_UNKNOWN_CARD)
	var placement := PlacementValidator.validate(state.city(), state.terrain(), data, cell,
		turns)
	if not placement.is_ok():
		return PlayResult.refused(placement.reason())
	if not state.ledger().can_afford(data.cost):
		return PlayResult.refused(PlayResult.REASON_UNAFFORDABLE)
	state.ledger().spend(data.cost)
	state.city().place(state.terrain(), data, cell, turns)
	state.deck().discard(card)
	return PlayResult.opened(cell, data.cost)

## Pose une action, si le ciblage l'accepte.
##
## La validation a lieu ici, et `ActionBoard.post()` la refait de son côté sur les mêmes
## entrées — ce qui est voulu : le board est le gardien de son propre invariant, « rien
## n'entre sans passer par le ciblage ». Ce que cet appel-ci apporte, c'est la **raison**,
## que `post()` ne rend pas.
static func _post_action(state: RunState, card: StringName, cell: Vector2i,
		direction: int) -> PlayResult:
	var actions := state.balance().actions
	var verdict := ActionTargeting.validate(card, cell, state.terrain(),
		state.city().to_snapshot(), state.board().to_plan(), actions, direction)
	if not verdict.is_ok():
		return PlayResult.refused(verdict.reason())
	var action := state.board().post(card, cell, state.terrain(),
		state.city().to_snapshot(), actions, direction)
	assert(action != null, "le board a refusé une pose que le ciblage venait d'accepter")
	state.deck().discard(card)
	return PlayResult.posted(action)

## Applique les ordres de chantier au relief et à la ville, et rend les chantiers achevés.
##
## Le seul endroit du projet qui mute deux systèmes d'affilée, et c'est la raison d'être de
## ce fichier. Les crans sont posés un à un plutôt qu'en bloc parce que c'est `CityState`
## qui compte l'avancement — recopier ici l'arithmétique du chantier ouvrirait la porte à
## ce que les deux divergent.
##
## Une ancre qui ne porte plus rien est sautée sans un mot : rien ne détruit un bâtiment
## aujourd'hui, mais le `DamageReport` de `F1` le fera, et un ordre survivant à sa cible est
## le même cas qu'une affectation survivant à son action.
static func _apply(state: RunState, sites: SiteReport) -> Array[Vector2i]:
	var completed: Array[Vector2i] = []
	var advances := sites.advances()
	for anchor in advances:
		if not state.city().has_anchor(anchor):
			continue
		for _step in advances[anchor]:
			state.city().advance(anchor)
		if state.city().building_at(anchor).is_complete():
			completed.append(anchor)
	var shifts := sites.shifts()
	for cell in shifts:
		state.grid().set_height(cell, state.grid().height_at(cell) + shifts[cell])
	return completed

## Le roster moins tous ceux qui ont tenu un poste, quel qu'il soit.
##
## La seule lecture juste de l'oisiveté d'un soir. `ProductionReport.idle()` ne voit que
## les postes de production, donc y compte comme oisif un ouvrier parti bâtir ; le
## rapport de chantier ne voit que les siens. Seul cet endroit voit les deux journaux.
static func _idle(labor: LaborForce, lines: Array[WorkLine]) -> Array[StringName]:
	var worked: Dictionary[StringName, bool] = {}
	for line in lines:
		worked[line.worker()] = true
	var resting: Array[StringName] = []
	for worker in labor.workers():
		if not worked.has(worker):
			resting.append(worker)
	return resting
