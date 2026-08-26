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
## **La carte revient en main**, et c'est une correction plutôt qu'un ajout. Ce docstring
## affirmait le contraire — « elle est à la défausse depuis qu'on l'a jouée, c'est l'état
## par défaut et non une réponse » — en renvoyant à l'`OUVERT` de 3.5. Il confondait deux
## gestes : cet `OUVERT` porte sur les cartes **non jouées en fin de phase**, alors qu'un
## retrait reprend une carte **jouée**, dans la phase même, avant que quoi que ce soit
## n'ait été consommé. Rien n'a produit, aucun ouvrier n'a travaillé, la réserve n'a pas
## bougé : il n'y a rien à faire payer.
##
## Le prix de l'ancienne lecture se voyait au clavier et nulle part ailleurs : le clic
## droit n'était pas une annulation mais un sacrifice, et il punissait une cible mal
## visée plutôt qu'une décision. Le scumming qu'on aurait pu craindre en retour —  poser
## pour lire la capacité, retirer, reposer ailleurs — n'existe pas : le ciblage annonce
## déjà la capacité **avant** le jeu, et la surbrillance montre les cibles légales.
##
## Une **carte de bâtiment** ne passe pas par ici : elle ouvre un chantier, que rien ne
## retire. « Que rend un chantier annulé ? » est l'`OUVERT` de 3.2, et il reste entier.
static func withdraw(state: RunState, action: int) -> bool:
	assert(state != null, "retrait sans run")
	if not state.cycle().permits(PhaseDef.ACTION_PLAY):
		return false
	var posted := state.board().at(action)
	if posted == null:
		return false
	state.release_action(action)
	state.deck().take_back(posted.card())
	return state.board().withdraw(action)

## Rien ne porte ce numéro d'action.
const REASON_NO_ACTION := &"no_action"

## Le roster ne connaît pas cet ouvrier.
const REASON_UNKNOWN_WORKER := &"unknown_worker"

## Il est absent — parti en expédition, et `DESIGN.md` 3.9 exige que rien ne puisse le
## placer.
const REASON_ABSENT_WORKER := &"absent_worker"

## Il tient déjà une autre action. On le rappelle avant de le renvoyer ailleurs.
const REASON_ALREADY_STAFFED := &"already_staffed"

## Tous les postes de l'action sont pris.
const REASON_NO_ROOM := &"no_room"

## Pourquoi cet ouvrier ne peut pas aller sur cette action, ou &"" s'il le peut.
##
## **Ce n'est pas un doublon de `staff()`, c'en est le seul juge.** `staff()` l'appelle,
## et un écran qui veut expliquer un refus l'appelle aussi — exactement comme le fantôme
## de `C2` et la pose interrogent tous deux `PlacementValidator`, et comme la
## surbrillance des cibles et `ActionBoard.post()` interrogent tous deux
## `ActionTargeting`. Une seule liste de règles, donc rien qui puisse dériver.
##
## Il a d'abord manqué, et l'erreur mérite d'être écrite ici plutôt que dans le seul
## journal : `staff()` rendait un booléen nu, au motif que « les refus se voient tous à
## l'écran avant le clic ». C'était faux à l'usage. La phase est bien affichée dans un
## bandeau, mais rien ne reliait ce bandeau à une touche qui ne répond pas, et le premier
## essai au clavier a donné un « refusé » sans cause. Un refus qui ne se nomme pas est
## indiscernable d'une panne.
static func staffing_refusal(state: RunState, worker: StringName,
		action: int) -> StringName:
	assert(state != null, "affectation sans run")
	if not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
		return PlayResult.REASON_WRONG_PHASE
	var posted := state.board().at(action)
	if posted == null:
		return REASON_NO_ACTION
	if not state.roster().has(worker):
		return REASON_UNKNOWN_WORKER
	if not state.roster().worker(worker).is_present():
		return REASON_ABSENT_WORKER
	if state.is_staffed(worker):
		return REASON_ALREADY_STAFFED
	if state.staffed_on(action).size() >= posted.capacity():
		return REASON_NO_ROOM
	return PlayResult.REASON_NONE

## Envoie cet ouvrier sur cette action. Faux si la phase, l'action ou l'ouvrier s'y
## opposent — `staffing_refusal()` dit lequel des cinq.
static func staff(state: RunState, worker: StringName, action: int) -> bool:
	if not staffing_refusal(state, worker, action).is_empty():
		return false
	state.assign_worker(worker, action)
	return true

## Remplit les postes libres au mieux et rend les ouvriers que ça vient de placer.
##
## Le bouton d'auto-affectation de `DESIGN.md` 3.4, et le même partage qu'à `I1` pour les
## verbes de chantier : `StaffingAdvisor` **ordonne**, ce fichier **applique**. Le plan
## est calculé une fois sur l'état d'avant, puis posé geste par geste à travers
## `staff()` — donc à travers `staffing_refusal()`, qui reste le seul juge. Une porte
## d'affectation qui court-circuiterait les cinq refus serait une seconde liste de
## règles, et c'est exactement ce que `I1` a refusé en écrivant la première.
##
## Il ne déplace personne : `plan()` ne propose que des ouvriers libres, ce qui fait de la
## surcharge manuelle un geste qui **tient**. On place à la main ceux dont on se soucie,
## on appuie sur le bouton pour le reste, et l'ordre des deux gestes n'a pas d'importance.
##
## L'assertion tient l'invariant que l'advisor promet — un plan ne se fait pas refuser à
## l'application, puisqu'il compte les postes de la même façon que `staffing_refusal()`.
## Elle ne survit pas à un export release, et c'est sans danger : un refus y sortirait
## simplement l'ouvrier de la liste rendue, sans rien casser.
static func auto_staff(state: RunState) -> Array[StringName]:
	assert(state != null, "auto-affectation sans run")
	var staffed: Array[StringName] = []
	if not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
		return staffed
	var orders := StaffingAdvisor.plan(state.terrain(), state.city().to_snapshot(),
		state.board().to_plan(), state.to_assignment(), state.labor(),
		state.balance().actions)
	for worker in orders:
		var accepted := staff(state, worker, orders[worker])
		assert(accepted, "le plan d'affectation a proposé %s, que staff() refuse" % worker)
		if accepted:
			staffed.append(worker)
	return staffed

## Rappelle tous les ouvriers d'une action et rend leurs identifiants.
static func unstaff(state: RunState, action: int) -> Array[StringName]:
	assert(state != null, "rappel sans run")
	if not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
		var none: Array[StringName] = []
		return none
	return state.release_action(action)

## Résout la phase courante : la séquence de `DESIGN.md` 2, réduite à ce qui existe.
##
## Actions jouées — production **et** chantiers —, puis gain d'XP, puis rapport. Et si
## cette phase **ferme la journée**, l'upkeep par-dessus. L'événement de 3.7 et le combat
## de `F1` entreront dans la fermeture de journée, à la place que la séquence leur garde.
##
## **Deux sortes de résolution, et c'est le cœur de la journée.** Une phase produit ; une
## journée coûte. Jouer deux phases par jour ne doit pas faire manger deux fois, sans quoi
## la structure de la journée deviendrait inséparable de son équilibrage — exactement ce
## que 2 veut pouvoir échanger séparément.
##
## Une phase qui ne résout pas mais ferme la journée ne produit rien et prélève quand
## même : une journée coûte à nourrir qu'on y ait travaillé ou non.
##
## **Les deux résolveurs voient la même ville**, celle d'avant le soir, et l'ordre compte :
## les chantiers s'appliquent **après** que la production a été calculée. Sans cette
## règle, un entrepôt achevé ce soir relèverait la réserve du même soir, et un chantier
## fini avant qu'une récolte ne soit lue déciderait du rendement — donc l'ordre des cartes
## posées déciderait du résultat. C'est exactement ce que `E1` a refusé pour l'écrêtage, et
## pour la même raison : deux villes identiques bâties dans un ordre différent doivent
## rendre la même chose.
##
## La capacité est reposée juste après cette application, et ce n'est **pas** une entorse
## à ce qui précède : la récolte est déjà calculée quand elle bouge. Voir
## `_restore_capacity()`, qui existe pour que la jauge cesse de mentir entre deux phases.
static func resolve(state: RunState) -> PhaseReport:
	assert(state != null, "résolution sans run")
	assert(not state.cycle().is_over(), "résolution d'un run terminé")
	var cycle := state.cycle()
	var balance := state.balance()
	var labor := state.labor()

	var production := ProductionReport.create({}, {}, [], [])
	var sites := SiteReport.empty()
	var progress := ProgressReport.empty()
	var completed: Array[Vector2i] = []
	var lines: Array[WorkLine] = []

	if cycle.resolves():
		var plan := state.board().to_plan()
		var assign := state.to_assignment()
		var snapshot := state.city().to_snapshot()
		production = ProductionResolver.resolve(state.terrain(), snapshot, plan, assign,
			labor, state.ledger(), balance.economy, balance.actions)
		sites = SiteResolver.resolve(snapshot, plan, assign, labor, balance.actions)
		completed = _apply(state, sites)
		_restore_capacity(state, balance.economy)
		lines = production.work()
		lines.append_array(sites.work())
		progress = SkillResolver.award_lines(state.roster(), lines, balance.workforce)

	var day_report: DayReport = null
	if cycle.closes_the_day():
		day_report = close_the_day(state)

	return PhaseReport.create(cycle.day(), cycle.phase().id, production, sites, progress,
		_idle(labor, lines), completed, day_report)

## Ferme la journée : prélève l'upkeep et rend ce qu'elle a coûté.
##
## Une porte à part parce que c'est ici que 3.7 et `F1` viendront s'ajouter, et qu'ils s'y
## ajouteront **par un champ de plus** plutôt qu'en déplaçant quoi que ce soit. La
## séquence de 2 leur garde la place : « actions jouées → événement → upkeep → combat →
## gain d'XP → rapport ».
static func close_the_day(state: RunState) -> DayReport:
	assert(state != null, "fermeture de journée sans run")
	var balance := state.balance()
	var upkeep := ProductionResolver.take_upkeep(state.labor(), state.ledger(),
		balance.economy)
	return DayReport.create(state.cycle().day(), upkeep)

## Termine la phase courante et passe à la suivante. Rend un rapport si elle résolvait ou
## si elle fermait la journée, null sinon.
##
## **Le board ne se vide qu'après une résolution**, jamais à chaque frontière de phase : il
## traverse la journée, puisque `D2` a fait de « poser une carte » et « y envoyer des
## ouvriers » deux gestes que rien n'oblige à tenir dans la même phase. Vider entre les
## deux effacerait ce que la première a fait.
##
## Repiocher suit `resolves` et non le calendrier, ce qui permet aux modèles de journée de
## `DESIGN.md` 2 de se comporter sensément sans qu'un nom de phase soit écrit : **une main
## par phase qui résout**. Deux phases qui résolvent rendent donc deux mains par jour et
## deux récoltes — mais un seul upkeep, parce que manger suit la journée et non la phase.
##
## Ce que ça décide du sort de la main non jouée — elle est défaussée — est l'état par
## défaut de l'`OUVERT` de 3.5 et non une réponse. `I2b` le tranchera.
static func end_phase(state: RunState) -> PhaseReport:
	assert(state != null, "fin de phase sans run")
	if state.cycle().is_over():
		return null
	var resolves := state.cycle().resolves()
	var report: PhaseReport = null
	if resolves or state.cycle().closes_the_day():
		report = resolve(state)
	if resolves:
		state.board().clear()
		state.clear_staffing()
		state.deck().discard_hand()
	state.cycle().advance()
	if resolves and not state.cycle().is_over():
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

## Relève la réserve de ce qu'un entrepôt achevé à l'instant vient de lui ajouter.
##
## `ProductionResolver.resolve()` pose déjà la capacité, mais il la pose sur la ville
## d'**avant** le soir. C'est la règle d'ordre de `resolve()` et elle ne bouge pas d'un
## pouce : un entrepôt fini ce soir ne sauve toujours pas la récolte de ce soir. Ce que
## cette règle ne dit pas, c'est ce que la jauge affiche **entre deux phases**.
##
## Sans cette ligne, un entrepôt achevé reste sur la carte toute une phase pendant que le
## HUD annonce l'ancienne capacité : le joueur voit le bâtiment et ne voit pas ses cent
## unités. Le défaut a traversé `I1` sans se faire remarquer parce qu'aucun écran ne
## montrait la capacité en continu, et parce que la résolution suivante la reposait de
## toute façon — un mensonge qui se corrige tout seul reste un mensonge le temps qu'il
## dure. C'est `E2` qui l'a rendu visible.
##
## Le harnais Économie contournait la même chose à sa façon depuis `E1`, en reposant la
## capacité à la main après ses poses, et son commentaire renvoyait la question « là où le
## HUD de `E2` le fera aussi ». Elle est ici et non dans une vue : un adapter qui muterait
## la réserve serait la faute d'architecture que `CLAUDE.md` refuse en premier.
##
## Elle ne peut que monter — achever un chantier n'a jamais détruit d'entrepôt. Le jour où
## le `DamageReport` de `F1` en détruira un, c'est cette même ligne qui écrêtera, par la
## règle proportionnelle de `Ledger.set_capacity()`.
static func _restore_capacity(state: RunState, balance: EconomyBalance) -> void:
	state.ledger().set_capacity(
		ProductionResolver.capacity_for(state.city().to_snapshot(), balance))

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
