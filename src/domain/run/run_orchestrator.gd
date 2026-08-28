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
## rapporte le soir ? » à `ProductionResolver`, « que bâtit-il ? » à `SiteResolver`, « que
## casse la vague ? » à `InstantCombatResolver`, « qui progresse ? » à `SkillResolver`. Ce
## que ce fichier ajoute est ce qu'aucun d'eux ne peut faire seul : **enchaîner deux
## questions** et **appliquer un ordre**.
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
## Ce que `I2` y ajoute, et qui n'est que du branchement : la **fondation**, qui fait de la
## pose du Cœur un geste ; le **calendrier**, qui date les vagues sur la journée ; la
## **coupure** de la fin de journée, que `DESIGN.md` 3.8 réclamait avant d'en avoir besoin ;
## et la **fin de run** de 5. Aucun contrat n'a bougé pour ça, ce qui était la promesse de 8.
##
## Statique et sans état, comme tous les résolveurs : ce qui persiste est dans `RunState`.

## Fonde le village : pose le Cœur sur cette cellule, et ouvre la première journée.
##
## `DESIGN.md` 2 en fait une étape à part entière — « génération de carte → **pose du Cœur**
## → suite de journées » — et `I1` l'avait bouchonnée en le posant au centre, en annonçant
## que « l'écran qui la demande au joueur appartient à `I2` ». Le voici, et c'est un geste
## comme les autres : une cellule, une validation, un `PlayResult`.
##
## Il ne passe **pas** par la bourse, à l'inverse de `_open_site()`. Le Cœur est « posé au
## départ » et son coût est vide dans `data/` ; le facturer ferait dépendre l'ouverture d'un
## run du stock de départ, c'est-à-dire de deux chiffres d'équilibrage qui n'ont aucune
## raison de se parler. C'est la seule pose gratuite du jeu, et elle l'est parce qu'elle est
## le jeu qui commence.
##
## Il n'ouvre pas de chantier non plus, et sans qu'une ligne le dise : le `build_actions` du
## Cœur vaut 0, donc `CityState.place()` le rend achevé d'office. C'est ce que 4.1 annonçait
## depuis `C4` et que `I1` a vérifié.
##
## La main est piochée **ici** et non à l'ouverture du run, ce qui est la conséquence
## directe de faire de la fondation une étape : une main tirée devant une carte nue serait
## une main qu'on ne peut pas jouer, donc un écran qui promet ce qu'il refuse.
static func found(state: RunState, cell: Vector2i, turns := 0) -> PlayResult:
	assert(state != null, "fondation sans run")
	if not state.awaits_its_heart():
		return PlayResult.refused(PlayResult.REASON_ALREADY_FOUNDED)
	var data := state.building(state.balance().run.starting_building)
	assert(data != null,
		"balance/run_balance.tres → starting_building nomme un bâtiment inconnu : %s"
			% state.balance().run.starting_building)
	if data == null:
		return PlayResult.refused(PlayResult.REASON_UNKNOWN_CARD)
	var placement := PlacementValidator.validate(state.city(), state.terrain(), data, cell,
		turns)
	if not placement.is_ok():
		return PlayResult.refused(placement.reason())
	state.city().place(state.terrain(), data, cell, turns)
	state.set_heart_anchor(cell)
	state.draw_phase()
	return PlayResult.opened(cell, data.cost)

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
	if state.awaits_its_heart():
		return PlayResult.refused(PlayResult.REASON_NO_HEART)
	if state.awaits_a_battle():
		return PlayResult.refused(PlayResult.REASON_BATTLE_PENDING)
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
	if state.awaits_a_battle():
		return false
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
	if state.awaits_its_heart():
		return PlayResult.REASON_NO_HEART
	if state.awaits_a_battle():
		return PlayResult.REASON_BATTLE_PENDING
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
	if state.awaits_its_heart() or state.awaits_a_battle():
		return staffed
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
	if state.awaits_a_battle() or not state.cycle().permits(PhaseDef.ACTION_ASSIGN):
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
## **Et elle ne compte aucun oisif**, ce qui n'est pas la même chose que d'en compter zéro
## par hasard. Un oisif est un reproche — « tu avais six ouvriers et tu n'en as employé
## que quatre » —, et un reproche suppose qu'on pouvait faire autrement. Dans une phase où
## personne ne peut être affecté, tout le roster est trivialement oisif : le rapport
## annoncerait « 6 oisifs » à qui vient de faire travailler ses six ouvriers tout
## l'après-midi. C'était vrai au mot près et faux à la lecture, ce qui est le défaut que
## `E2` a nommé et que seule une capture montre. Constaté à `I2b`, sur la phase que le
## jalon venait de faire exister.
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
	var resting: Array[StringName] = []

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
		resting = _idle(labor, lines)

	var day_report: DayReport = null
	if cycle.closes_the_day():
		day_report = close_the_day(state)

	var report := PhaseReport.create(cycle.day(), cycle.phase().id, production, sites,
		progress, resting, completed, day_report)
	# Retenu pour le bilan de la journée, et **seulement si la phase a produit**. Une phase
	# qui ne résout pas n'a rien à additionner ; l'y mettre ferait compter une résolution de
	# plus, c'est-à-dire mentir sur la seule colonne qui dise combien de fois la journée a
	# travaillé. C'est ici plutôt que dans `end_phase()` parce que c'est le seul endroit qui
	# **produise** un rapport : un second producteur, un jour, n'aurait pas à y penser.
	if cycle.resolves():
		state.record_phase(report)
	return report

## Fait tomber cette vague sur le village, applique ce qu'elle ordonne, et rend ce que ça a
## coûté.
##
## Le même partage qu'à `I1` pour les verbes de chantier et qu'à `W2` pour l'affectation :
## **le résolveur ordonne, ce fichier applique.** Il est ici parce qu'il est le seul à tenir
## la ville, le roster et la réserve à la fois — un résolveur de Combat qui les muterait
## violerait la règle de dépendance trois fois.
##
## **Elle ne se choisit plus, elle s'attend.** `F1` prenait la vague en argument parce que
## rien ne la datait ; `I2` la lit dans le calendrier de `data/balance/` et l'arme à la
## fermeture de la journée, si bien que cette porte ne fait plus que consommer ce qui
## attend. On ne se bat donc pas hors calendrier, et c'est structurel plutôt qu'écrit.
##
## **Elle avance le cycle**, et c'est la seconde moitié de la coupure de `end_phase()`.
## Une bataille est le dernier cran de la fermeture d'une journée : quand elle est passée,
## il ne reste plus rien à faire de ce jour-là. La confier à un troisième geste laisserait
## un run capable de rester indéfiniment entre deux journées.
##
## **L'ordre des quatre applications est imposé, et chaque cran se justifie.**
##
##   - Les **bâtiments** d'abord, parce que la capacité de la réserve en dépend : un
##     entrepôt détruit doit avoir écrêté avant qu'on ne pille ce qu'il ne tient plus.
##   - La **capacité** ensuite, par la même ligne que la fin d'une phase — `_restore_capacity()`
##     annonçait ce cas mot pour mot depuis `E2` : « le jour où le `DamageReport` de `F1`
##     détruira un entrepôt, c'est cette même ligne qui écrêtera ».
##   - Le **pillage** après, sur ce qui reste vraiment.
##   - Les **morts**, puis l'**XP**, et dans cet ordre : `SkillResolver` saute un ouvrier que
##     le roster ne connaît plus, ce qui rend vraie sans une ligne de code la phrase que son
##     docstring porte depuis `W1` — « un mort ne progresse pas ».
##
## Une ancre que la vague nomme et que la ville ne porte plus est sautée sans un mot, comme
## `_apply()` saute un chantier disparu. Le cas ne se présente pas aujourd'hui, la ville
## étant figée entre le verdict et son application ; il se présentera le jour où deux choses
## frapperont le même soir.
static func fight(state: RunState) -> BattleReport:
	assert(state != null, "vague sans run")
	assert(state.awaits_a_battle(), "vague appelée sans vague en attente")
	var wave := state.pending_wave()
	var balance := state.balance()
	var force := state.roster().to_combat(balance.combat.combat_skill_family,
		balance.workforce, balance.combat)
	var damage := InstantCombatResolver.resolve(state.city().to_snapshot(), force, wave,
		balance.combat)

	var wounds := damage.damaged()
	for anchor in wounds:
		if not state.city().has_anchor(anchor):
			continue
		state.city().damage(anchor, wounds[anchor])
	_restore_capacity(state, balance.economy)

	var plundered := state.ledger().take_share(damage.plunder())

	for fallen in damage.lost():
		state.roster().remove(fallen)
	var progress := SkillResolver.award_lines(state.roster(), damage.work(),
		balance.workforce)

	state.clear_wave()
	var lost := _defeat_of(state)
	if lost.is_empty():
		_open_next_phase(state)
	else:
		_finish(state, lost)

	return BattleReport.create(damage, plundered, progress)

## Ce que la journée en cours a rendu jusqu'ici, et ce que la fermer va coûter.
##
## `DESIGN.md` 2 en fait la seconde moitié du soir depuis `P2b` : « on y lit le bilan de la
## journée avant de la fermer ». Il se lit donc **à tout moment** de la journée, et il rend
## un bilan vide le matin d'un jour qui commence — ce qui est la bonne réponse et non un cas
## particulier.
##
## Il est ici et pas sur `RunState` parce qu'il enchaîne **deux questions** posées à deux
## systèmes : ce que les phases ont rendu, que le run tient, et ce que le village doit à
## manger, que l'Économie sait seule. C'est la définition de ce fichier — « il ne calcule
## rien, il enchaîne deux questions là où chaque système n'en répond qu'à une ».
##
## L'upkeep est **dû** et non consommé, puisqu'il se prélève à la fermeture. Les deux ne
## diffèrent qu'en famine, et 2. a tranché ce que ça coûte contre ce que ça évite : un
## bilan qui n'ajoute aucun geste, le bouton qui le referme étant celui qui ferme la
## journée.
static func day_summary(state: RunState) -> DaySummary:
	assert(state != null, "bilan de journée sans run")
	var day := mini(state.cycle().day(), state.cycle().days())
	return DaySummary.of(day, state.day_reports(),
		ProductionResolver.upkeep_due(state.labor(), state.balance().economy))

## Ferme la journée : prélève l'upkeep, arme la vague du jour, et rend ce qu'elle a coûté.
##
## Une porte à part parce que c'est ici que `F1` devait s'ajouter, et il s'y ajoute **par un
## champ de plus** plutôt qu'en déplaçant quoi que ce soit — la séquence de 2 lui gardait la
## place : « actions jouées → événement → upkeep → **combat** → gain d'XP → rapport ».
## L'événement de 3.7 entrera par la même porte et de la même façon.
##
## Elle **arme** et ne frappe pas, et c'est toute la différence que `DESIGN.md` 3.8 réclame.
## Un résolveur rend un rapport ; un combat tactique attend le joueur pendant des dizaines
## de tours, et le domaine n'a pas le droit d'`await`. Le rapport de journée porte donc la
## vague **en attente**, et ce qu'elle aura coûté revient par `fight()`.
##
## L'ordre est celui de la séquence : on mange **avant** de se battre. Un village affamé le
## soir d'un siège l'est toujours pendant, et l'inverse ferait payer l'upkeep de morts qui
## viennent de tomber.
static func close_the_day(state: RunState) -> DayReport:
	assert(state != null, "fermeture de journée sans run")
	var balance := state.balance()
	var upkeep := ProductionResolver.take_upkeep(state.labor(), state.ledger(),
		balance.economy)
	var wave := balance.run.wave_on(state.cycle().day())
	if wave != null:
		state.arm_wave(wave)
	return DayReport.create(state.cycle().day(), upkeep, wave)

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
## Ce que ça décide du sort de la main non jouée **est un réglage depuis `I2b`**, et non
## plus une ligne d'ici. `DeckBalance.carry_over` dit par pool ce qui survit, cette porte
## l'applique, et l'`OUVERT` de 3.5 se tourne en éditant un `.tres` — ce qu'il fallait
## pour qu'une partie jouée l'arbitre au lieu d'une déduction. Le défaut livré reste la
## défausse totale, qui est l'état de `I1` et non une réponse.
##
## **Elle cesse d'être atomique à `I2`**, et c'est le seul travail que la discussion sur le
## format de combat a ajouté au jalon. `DESIGN.md` 3.8 l'a écrit avant qu'on en ait besoin :
## le combat clôt la journée, il attend le joueur, et « la rupture interactive tombe au
## milieu » de ce geste. Ce qui est donc différé n'est pas la résolution — elle a bien lieu,
## le plateau se vide, la main part à la défausse — mais l'**ouverture de la phase
## suivante**, que `fight()` fera à sa place. Le prix a été payé ici plutôt qu'à `F3` :
## « une demi-heure aujourd'hui contre un écran à défaire ensuite ».
static func end_phase(state: RunState) -> PhaseReport:
	assert(state != null, "fin de phase sans run")
	if state.cycle().is_over():
		return null
	if state.awaits_its_heart():
		return null
	if state.awaits_a_battle():
		return null
	var resolves := state.cycle().resolves()
	var report: PhaseReport = null
	if resolves or state.cycle().closes_the_day():
		report = resolve(state)
	if resolves:
		state.board().clear()
		state.clear_staffing()
		_drop_what_is_not_carried(state)
	if not state.awaits_a_battle():
		_open_next_phase(state)
	return report

## Comment le run s'est terminé, ou null tant qu'il tourne.
##
## Un relais sur `RunState`, et il est ici parce que c'est la porte que les adapters
## connaissent : un écran de fin n'a aucune raison d'aller chercher deux objets pour poser
## une question.
static func outcome(state: RunState) -> RunOutcome:
	assert(state != null, "issue sans run")
	return state.outcome()

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

## Défausse la main des pools qui ne reportent pas, et laisse les autres en place.
##
## L'application de `DeckBalance.carry_over`, et le seul endroit du projet qui la lise.
## Elle est ici plutôt que dans le `Deck` par la même ligne que tout le reste de ce
## fichier : le `Deck` offre `discard_pool()`, la journée décide de l'appeler. Un deck qui
## connaîtrait sa propre politique de fin de phase saurait quelque chose de la journée.
##
## Un pool absent de la table vaut zéro, donc se défausse : c'est le comportement de `I1`,
## et c'est la bonne dégradation — une table incomplète ne doit pas faire *garder* une main
## par accident. Le boot refuse de toute façon une clé manquante dans `data/`.
##
## Un report **partiel** garderait tout plutôt que rien. Le cas n'existe pas — le bloc
## d'équilibrage le refuse —, et s'il apparaissait par un fixture de test, garder est la
## dégradation qui se voit, là où défausser se confondrait avec le défaut.
static func _drop_what_is_not_carried(state: RunState) -> void:
	var deck := state.balance().deck
	for pool in CardData.POOLS:
		if int(deck.carry_over.get(pool, 0)) <= 0:
			state.deck().discard_pool(pool)

## Ouvre la phase suivante : avance le cycle, repioche si la précédente résolvait, et
## constate la victoire si le run vient d'épuiser ses journées.
##
## Appelé de **deux** endroits — la fin d'une phase ordinaire, et la bataille qui clôt une
## journée —, ce qui est exactement la coupure de `end_phase()`. Les avoir tous deux passer
## par ici est ce qui garantit qu'une journée fermée par un combat s'ouvre sur la suivante
## dans le même état qu'une journée paisible.
##
## Il lit `resolves()` **avant** d'avancer, et n'a donc rien à retenir : quand une bataille
## attend, le cycle pointe encore sur la phase qui vient de finir. C'est ce qui permet à
## `RunState` de ne porter qu'un seul champ pour l'attente — la vague — au lieu de traîner
## un souvenir de ce qu'il restait à faire.
##
## La conséquence à connaître pour lire une journée dont la **dernière phase ne résout
## pas** — le modèle retenu à `I2b` : la main est tirée à la fin de la dernière phase qui
## produit, et **traverse** la phase de fermeture sans que rien n'y touche. Le joueur
## regarde donc l'upkeep tomber et la vague arriver en tenant déjà la main de demain
## matin, ce qui est une information plutôt qu'un défaut. Le compte est juste dans tous les
## cas : **une main par phase qui résout**, et le report de `carry_over` s'applique là où
## la défausse a lieu, donc jamais sur une phase qui ne résout pas.
static func _open_next_phase(state: RunState) -> void:
	var draws := state.cycle().resolves()
	# Une journée neuve efface le bilan de la précédente, et c'est le **seul** endroit qui
	# l'efface. `advance()` dit lui-même qu'un jour vient de s'ouvrir, ce qui évite d'avoir
	# à comparer un numéro de jour d'avant à un numéro d'après — le genre de souvenir que
	# `RunState` n'a justement pas à porter.
	if state.cycle().advance():
		state.clear_day_reports()
	if state.cycle().is_over():
		_finish(state, RunOutcome.CAUSE_SURVIVED)
		return
	if draws:
		state.draw_phase()

## Pourquoi le run est perdu, ou &"" s'il tient encore.
##
## Les deux défaites de `DESIGN.md` 5, et rien d'autre. Elles se lisent sur ce que la ville
## et le roster disent déjà — c'est ce que `F1` annonçait : « la défaite lit ce que la ville
## et le roster disent déjà », donc aucun système n'a eu à apprendre un mot.
##
## Le Cœur passe en premier parce qu'un village dont le Cœur est tombé a perdu même s'il
## reste du monde, et parce que c'est l'ordre où 5. les nomme. Il ne se cherche pas par son
## identifiant : `RunState` retient son ancre à la fondation, ce qui laisse `&"heart"` dans
## `data/balance/` et hors de ce fichier.
##
## Un run sans bâtiment d'ouverture ne peut pas perdre son Cœur, et c'est la bonne réponse :
## on ne perd pas ce qu'on n'a jamais eu.
static func _defeat_of(state: RunState) -> StringName:
	var heart := state.heart_anchor()
	if heart != RunState.NO_CELL and not state.city().has_anchor(heart):
		return RunOutcome.CAUSE_HEART
	if state.roster().size() <= 0:
		return RunOutcome.CAUSE_ROSTER
	return &""

## Referme le run sur cette cause, et compte ce qu'il valait.
##
## Les deux gestes sont ici et nulle part ailleurs : le cycle s'arrête **et** l'issue est
## posée. Séparés, ils laisseraient exister un run arrêté sans raison ou un run fini qui
## avance encore.
##
## Il ne calcule pas le score — il va chercher ses quatre termes chez les quatre systèmes
## qui les possèdent, et c'est `RunOutcome` qui applique le barème. La réserve rend un
## total, la ville compte ses **achevés** — un chantier n'est pas un bâtiment intact —, le
## roster compte ses vivants et rend la somme de leurs niveaux. Aucun contenu d'état ne
## traverse : quatre entiers, ce qui est la ligne que `F1` a tracée sur le pillage.
##
## Le jour retenu est la **dernière journée jouée**, et il est borné : une victoire se
## constate après que le cycle a passé son dernier jour, où `day()` vaut déjà `days + 1`.
static func _finish(state: RunState, cause: StringName) -> void:
	var balance := state.balance()
	var cycle := state.cycle()
	var day := mini(cycle.day(), cycle.days())
	cycle.end()
	state.set_outcome(RunOutcome.tally(cause, day, state.ledger().total(),
		state.city().to_snapshot().completed().size(), state.roster().size(),
		state.roster().total_level(balance.workforce), balance.run))

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
