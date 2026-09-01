class_name RunOrchestrator
extends RefCounted
## Ce qu'on peut faire d'un run, et ce qu'un tour en fait.
##
## DESIGN.md 3.7 : « Le seul système qui connaît tous les autres. C'est volontaire : il
## orchestre, les autres s'ignorent. » Ce fichier est cette phrase.
##
## Il ne **calcule** rien. Chaque question part chez celui qui sait y répondre : « puis-je
## poser ici ? » à PlacementValidator, « puis-je payer ? » au Ledger, « ai-je les bras ? » à
## Staffing, « que rendent les bâtiments ? » à ProductionResolver, « que coûte le repas ? » à
## UpkeepResolver, « où sont les plafonds ? » à CityLimits. Ce qu'il ajoute est ce qu'aucun
## d'eux ne peut faire seul : **enchaîner deux questions** et **appliquer un ordre**.
##
## Statique et sans état : ce qui persiste est dans RunState.
##
## ---
##
## **Il a rétréci de moitié à I3, et c'est la mesure du rescope.** Celui d'avant R0 faisait
## 691 lignes et orchestrait cinq systèmes ; il en orchestre trois. Il connaissait deux
## sortes de résolution — une phase qui produit, une journée qui coûte —, il n'en connaît
## qu'une, parce que DESIGN.md 2 a ramené la journée à un tour. La machine à phases est
## partie avec les phases, et la coupure de fin de journée avec la bataille qui attendait :
## 3.5 pose que « la fin de tour reste atomique », donc il n'y a plus ni état d'attente ni
## seconde porte.
##
## **Ce qu'il n'a plus à faire du tout, et c'est le gain de la population-compteur.** Il n'y
## a **rien à réaffecter**. Les bras d'un bâtiment sont payés à l'ouverture de son chantier
## et y restent (DESIGN.md 3.4) ; le sommeil est un calcul que Staffing refait à la demande
## (N1). Un bâtiment démoli rend donc ses bras sans qu'une ligne d'ici ne le dise, et un
## village qui repeuple le fait sans qu'on l'ordonne. Les deux se lisent à ce que ce fichier
## **ne contient pas**.

## Fonde le village : pose le Cœur sur cette cellule.
##
## DESIGN.md 2 en fait une étape à part entière — « génération de carte → **pose du Cœur** →
## suite de tours ». C'est un geste comme les autres : une cellule, une validation, un
## PlayResult.
##
## Il ne passe **ni par la bourse ni par les bras**, à l'inverse d'open_site(). Le Cœur est
## « posé au départ » et son coût est vide dans data/ ; le facturer ferait dépendre
## l'ouverture d'un run du stock de départ, c'est-à-dire de deux chiffres d'équilibrage qui
## n'ont aucune raison de se parler. C'est la seule pose gratuite du jeu, et elle l'est parce
## qu'elle est le jeu qui commence.
##
## Il n'ouvre pas de chantier non plus, et sans qu'une ligne le dise : le site_turns du Cœur
## vaut 0, donc CityState.place() le rend achevé d'office.
static func found(state: RunState, cell: Vector2i, turns := 0) -> PlayResult:
	assert(state != null, "fondation sans run")
	if state.is_over():
		return PlayResult.refused(PlayResult.REASON_RUN_OVER)
	if not state.awaits_its_heart():
		return PlayResult.refused(PlayResult.REASON_ALREADY_FOUNDED)
	var data := state.building(state.balance().run.starting_building)
	if data == null:
		return PlayResult.refused(PlayResult.REASON_UNKNOWN_BUILDING)
	var placement := PlacementValidator.validate(state.city(), state.terrain(), data, cell,
		turns)
	if not placement.is_ok():
		return PlayResult.refused(placement.reason())
	state.city().place(state.terrain(), data, cell, turns)
	state.set_heart_anchor(cell)
	_apply_limits(state)
	return PlayResult.opened(cell, data.cost, data.workers)

## Ouvre un chantier : pose ce bâtiment sur cette cellule, paie tout de suite.
##
## **Un chantier paie tout à l'ouverture, ressources et travailleurs** (DESIGN.md 3.2). Il
## occupe ses cellules, débite la réserve, immobilise les bras du bâtiment à venir — et ces
## gens-là bâtissent puis restent. C'est l'investissement de main-d'œuvre étalé qu'on veut :
## pendant ce temps ils ne produisent rien.
##
## **Les bras ne sont écrits nulle part**, et c'est le meilleur signe que le modèle de N1 est
## le bon. Il n'y a pas de compteur d'immobilisés à décrémenter : le bâtiment est dans la
## ville, donc Staffing le compte, donc les bras sont pris. Ils reviendront de la même
## façon — en cessant d'être comptés — quand il sera démoli ou détruit.
##
## **Cinq refus, et un seul remonte.** L'ordre est une décision : les portes d'état d'abord,
## puis la **carte**, puis les trois coûts dans l'ordre où DESIGN.md 4.2 les énumère. La
## carte passe avant les coûts parce que c'est elle qu'un joueur corrige en bougeant la
## souris, et parce que le fantôme de C2 l'affiche déjà — une réponse qui contredirait la
## couleur du fantôme serait pire qu'une réponse incomplète.
static func open_site(state: RunState, id: StringName, cell: Vector2i,
		turns := 0) -> PlayResult:
	assert(state != null, "chantier ouvert sans run")
	if state.is_over():
		return PlayResult.refused(PlayResult.REASON_RUN_OVER)
	if state.awaits_its_heart():
		return PlayResult.refused(PlayResult.REASON_NO_HEART)
	var data := state.building(id)
	if data == null:
		return PlayResult.refused(PlayResult.REASON_UNKNOWN_BUILDING)
	var placement := PlacementValidator.validate(state.city(), state.terrain(), data, cell,
		turns)
	if not placement.is_ok():
		return PlayResult.refused(placement.reason())
	if state.open_sites() >= state.balance().run.build_slots:
		return PlayResult.refused(PlayResult.REASON_NO_BUILD_SLOT)
	if not _has_the_hands(state, data):
		return PlayResult.refused(PlayResult.REASON_NOT_ENOUGH_WORKERS)
	if not state.ledger().can_afford(data.cost):
		return PlayResult.refused(PlayResult.REASON_NOT_ENOUGH_RESOURCES)
	state.city().place(state.terrain(), data, cell, turns)
	state.ledger().spend(data.cost)
	_apply_limits(state)
	return PlayResult.opened(cell, data.cost, data.workers)

## Démolit ce qui occupe cette cellule.
##
## « Rien, et ne rend aucune ressource ; libère les cellules **et les travailleurs** »
## (DESIGN.md 4.2). Les bras reviennent sans qu'une ligne le dise, pour la raison exposée
## sur open_site() : ils n'étaient nulle part, ils étaient comptés.
##
## **C'est la seconde soupape de DESIGN.md 3.4, et I3 lui en découvre un troisième usage.**
## Elle rendait déjà des bras à un village dont tout le monde est immobilisé ; elle est aussi
## le seul geste qui **libère un emplacement de file**. Un village dont les trois chantiers
## dorment après une famine ne peut plus rien ouvrir — pas même l'habitation gratuite en
## bras, faute d'emplacement — et c'est en démolissant qu'il repart. Un cas de test le tient.
##
## Elle ne rend rien mais peut **coûter** : abattre une habitation ou un entrepôt abaisse un
## plafond, et ce qui dépassait s'en va. Les deux pertes sont mesurées ici, avant et après,
## parce que c'est le seul instant où elles sont visibles.
static func demolish(state: RunState, cell: Vector2i) -> PlayResult:
	assert(state != null, "démolition sans run")
	if state.is_over():
		return PlayResult.refused(PlayResult.REASON_RUN_OVER)
	if not state.city().is_occupied(cell):
		return PlayResult.refused(PlayResult.REASON_NOTHING_HERE)
	var anchor := state.city().anchor_at(cell)
	if anchor == state.heart_anchor():
		return PlayResult.refused(PlayResult.REASON_THE_HEART)
	var freed := state.city().building_at(cell).data().workers
	var held := state.ledger().total()
	var headcount := state.people().headcount()
	state.city().remove(anchor)
	_apply_limits(state)
	return PlayResult.razed(anchor, freed, headcount - state.people().headcount(),
		held - state.ledger().total())

## Passe le tour, et rend ce que sa résolution a donné.
##
## La séquence de DESIGN.md 2, dans l'ordre imposé, moins l'étape `e` — la vague est V4, et
## elle s'insérera entre le repas et le verdict sans que rien d'autre ne bouge. C'est ce que
## 3.6 demande d'ailleurs à cette fonction : pouvoir accueillir une étape de plus sans se
## réécrire.
##
## **L'ordre a-b est imposé, et c'est la règle héritée qui survit intacte.** La production se
## calcule sur la ville **d'avant** l'avancement des chantiers, sans quoi un entrepôt achevé
## ce tour-ci relèverait la réserve du même tour, et l'ordre dans lequel les chantiers ont
## été lancés déciderait du résultat. Deux villes identiques bâties dans un ordre différent
## doivent rendre la même chose. C'est le `city` figé en tête de fonction qui le garantit :
## il est pris une fois, et l'avancement qui suit ne le suit pas.
##
## **Le plan d'occupation est calculé une fois et sert deux fois** — à la production et à
## l'avancement. C'est voulu, et c'est la phrase de Staffing dite pour l'autre moitié de la
## ville : « un chantier endormi n'avance pas » est la même règle que « un bâtiment endormi
## ne produit rien ». Le recalculer entre les deux le ferait porter sur une ville qui vient
## de changer, donc sur un autre moment que celui qu'il décrit.
##
## **Elle assert au lieu de refuser**, à l'inverse des trois gestes ci-dessus, et c'est le
## profil de CityState.advance() pour la même raison : les deux seuls refus possibles — run
## fini, Cœur pas encore posé — se posent **avant** l'appel, et l'appelant les lit sur le run
## lui-même. Un curseur promené sur la carte produit des refus par centaines ; passer le tour
## n'en produit aucun.
static func end_turn(state: RunState) -> TurnReport:
	assert(state != null, "tour passé sans run")
	assert(not state.is_over(), "tour passé sur un run déjà terminé")
	assert(not state.awaits_its_heart(), "tour passé avant la fondation du Cœur")

	var economy := state.balance().economy
	# Les plafonds valent pour la ville que les gestes du joueur ont laissée. Ils sont
	# réappliqués une seconde fois plus bas, parce que la ville change une seconde fois —
	# ce sont deux mutations, donc deux applications, et non un état tenu en double.
	_apply_limits(state)

	# a. les bâtiments finis produisent, sur la ville d'avant.
	var city := state.city().to_snapshot()
	var plan := Staffing.resolve(city, state.people().headcount())
	var production := ProductionResolver.resolve(city, plan, state.ledger(), economy)

	# b. les chantiers actifs avancent, et ceux qui s'achèvent deviennent des bâtiments.
	var advanced: Array[Vector2i] = []
	var completed: Array[Vector2i] = []
	var stalled: Array[Vector2i] = []
	for building in city.buildings():
		if building.is_complete():
			continue
		var anchor := building.anchor()
		if not plan.is_active(anchor):
			stalled.append(anchor)
			continue
		if not state.city().advance(anchor):
			continue
		advanced.append(anchor)
		if state.city().building_at(anchor).is_complete():
			completed.append(anchor)
	_apply_limits(state)

	# c et d. tout le monde mange, puis l'effectif en tire la conséquence. Les deux sont
	# le même appel depuis N1 : un tour ne fait jamais venir et partir à la fois, parce
	# que la croissance demande un reliquat et la décroissance un manque.
	var upkeep := UpkeepResolver.resolve(state.people(), state.ledger(), economy)

	# e. la vague, si une est datée ce tour — V4.

	var outcome := _verdict(state)
	if outcome != null:
		state.set_outcome(outcome)
	var report := TurnReport.create(state.turn(), production, upkeep, advanced, completed,
		stalled, outcome)
	state.record_turn(report)
	if outcome == null:
		state.advance_turn()
	return report

## Le village peut-il **posséder** un bâtiment de plus ?
##
## La question se pose à la demande totale de la ville et non aux bras que le plan laisse
## libres, et l'écart entre les deux est un piège. Une ville de trois bâtiments à deux bras
## pour cinq habitants a un endormi et rend `available() == 1` : ouvrir un chantier d'un bras
## sur cette base **creuserait** le manque, et endormirait un bâtiment de plus au tour
## suivant. Ce que DESIGN.md 3.2 fait dire aux travailleurs est « ce que le village peut
## posséder », pas « ce qu'il lui reste sous la main cet instant ».
static func _has_the_hands(state: RunState, data: BuildingData) -> bool:
	var demand := Staffing.demand(state.city().to_snapshot())
	return demand + maxi(0, data.workers) <= state.people().headcount()

## Réaccorde les deux plafonds sur la ville du moment.
##
## Les deux ensemble, toujours, et c'est la raison d'être de CityLimits : ce sont deux
## plafonds bâtis sur le même modèle, et n'en appliquer qu'un est l'oubli qui ne se voit
## pas — un entrepôt démoli laisserait une réserve au-dessus de sa capacité, une habitation
## démolie laisserait des habitants sans toit.
##
## Les pertes que l'abaissement provoque sont **rendues par les deux setters** et ignorées
## ici : c'est l'appelant qui sait si elles ont un sens à raconter. demolish() les mesure
## avant/après parce que c'est son geste qui les cause ; la résolution d'un tour ne les
## regarde pas, puisqu'un tour ne fait que monter des plafonds — un chantier qui s'achève
## n'en abaisse aucun.
static func _apply_limits(state: RunState) -> void:
	var city := state.city().to_snapshot()
	var economy := state.balance().economy
	state.ledger().set_capacity(CityLimits.storage_for(city, economy))
	state.people().set_places(CityLimits.housing_for(city, economy))

## Le run est-il fini, et pourquoi ? null s'il continue.
##
## DESIGN.md 5 en trois lignes, et **les défaites passent avant la victoire**. Un dernier
## tour où le village meurt de faim n'est pas un run survécu : on ne gagne pas en tombant sur
## la ligne d'arrivée. L'ordre est donc une règle et non un détail d'écriture.
static func _verdict(state: RunState) -> RunOutcome:
	var cause := &""
	if not state.has_its_heart():
		cause = RunOutcome.CAUSE_HEART
	elif state.people().headcount() <= 0:
		cause = RunOutcome.CAUSE_POPULATION
	elif state.is_last_turn():
		cause = RunOutcome.CAUSE_SURVIVED
	if cause.is_empty():
		return null
	return RunOutcome.tally(cause, state.turn(), state.ledger().total(),
		state.city().to_snapshot().completed().size(), state.people().headcount(),
		state.heart_hit_points(), state.balance().run)
