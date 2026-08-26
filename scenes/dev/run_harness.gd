extends Node
## Harnais de dev du système Run — la boucle minimale de `I1`, le HUD de `E2`.
##
## C'est le premier harnais qui ne montre pas un système mais **une journée**. Le harnais
## Cartes de `D2` composait déjà trois systèmes du domaine ; celui-ci les compose tous, et
## surtout il ne les appelle plus lui-même : tout passe par `RunManager`, qui est le pont
## que `I0` avait annoncé et laissé vide.
##
## Ce que `I1` met sous les yeux, et qu'aucun harnais précédent ne pouvait montrer :
##
##   - **la journée en phases.** Le bandeau dit où l'on en est, et les gestes s'allument
##     ou s'éteignent selon ce que la phase courante autorise. Aucun nom de phase n'est
##     écrit ici : le libellé vient de la `PhaseDef`, et les touches se gardent en
##     demandant au domaine ce qui est permis.
##   - **la bourse au moment de bâtir.** Une carte de bâtiment affiche son coût sous le
##     curseur et se fait refuser quand la réserve ne suit pas. `D2` la posait
##     gratuitement et le disait en toutes lettres.
##   - **les deux verbes exécutés.** Un chantier monte vraiment d'un cran, et le relief se
##     creuse vraiment sous un terrassement. Le rapport de phase les nomme.
##
## Ce que `E2` y a ajouté, et surtout ce qu'il en a **retiré** : la réserve et le compte
## rendu de résolution ne sont plus deux morceaux du pavé de texte, ce sont deux vues —
## `ResourceBar` en haut à gauche, `ProductionPanel` en haut à droite. Le harnais ne
## fabrique plus une seule ligne de leur mise en forme ; il leur passe un `Ledger` et un
## `PhaseReport`. Les deux endroits où le même chiffre se lisait ont disparu avec, ce qui
## est le vrai bénéfice : un chiffre affiché à deux endroits est un chiffre qui finira par
## différer de lui-même.
##
## Il ne décide rien. Il traduit un clic en appel de `RunManager` et une réponse en
## couleur, comme les harnais Construction et Cartes avant lui. Aucun « if » sur le
## terrain, la ville, la bourse ou la phase n'apparaît ici — la question se pose au
## domaine, l'écran affiche la réponse.
##
## Ce que `W2` y ajoute, et ce qu'il en retire à son tour : le plateau et le roster ne
## sont plus deux lignes de texte, c'est un `AssignmentPanel`. On y choisit **qui** l'on
## envoie — une fiche, puis une action — au lieu de subir le premier ouvrier libre, et un
## bouton remplit le reste. Le harnais ne classe personne : il demande, `StaffingAdvisor`
## répond.
##
## Ce que `I2` en fait enfin un jeu qu'on ouvre et qu'on finit. Le run **commence** par la
## pose du Cœur — un clic sur la carte, ou Entrée pour la case que le domaine suggère — au
## lieu de le trouver déjà posé au centre. Les vagues **tombent à leur date**, et la journée
## s'arrête sur elles : le bandeau annonce l'assaut, le `BattlePanel` dit ce qu'on lui
## oppose, et rien n'avance tant qu'on n'a pas tenu la ligne. Et le run **se termine** — la
## dernière journée franchie, le Cœur tombé ou le village vidé —, sur un bandeau qui dit
## laquelle des trois et ce que la partie valait.
##
## Ce qui reste en texte est ce dont aucune vue n'a la charge : les piles, le survol, et le
## bandeau de tête.
##
## Les commandes : une carte se prend au clavier — 1 à 9 — ou au clic dessus ; un clic
## gauche sur le sol la joue sur la case survolée, un clic droit retire l'action posée là,
## Espace y envoie un ouvrier, Retour arrière les rappelle tous, Tab pivote un bâtiment ou
## retourne un terrassement, **Entrée termine la phase**. La caméra garde Q/E, la molette,
## WASD et R. Dans le panneau : un clic sur une fiche la sélectionne, un clic sur une
## ligne d'action y envoie le sélectionné, et **Auto** remplit le reste.

## Seed du run. Fixe : deux lancements doivent se comparer.
const SEED := 20260825

## Ouvriers du roster d'ouverture.
##
## Ils sont fabriqués ici et non par le domaine, et c'est voulu : `DESIGN.md` 3.4 garde le
## recrutement sous un `OUVERT`, `RunState.open()` reçoit son roster, et un harnais est
## exactement le genre d'appelant qui a le droit d'en inventer un.
const GIVEN_NAMES: Array[String] = ["Ana", "Bo", "Cy", "Dov", "Ema", "Fen"]

## Rendu quand aucune cellule ne convient.
const NO_CELL := Vector2i(-1, -1)

## Cartes que les touches 1 à 9 atteignent. Au-delà, il faut cliquer.
const SLOT_KEYS := 9

## Rang qui ne désigne aucune carte.
const NO_SLOT := -1

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13
const REPORT_OUTLINE_SIZE := 4

const CONTROLS := """La main    1-9 ou clic sur une carte : la prendre. Tab : pivoter, ou retourner un terrassement.
La carte   clic gauche : jouer sur la case survolée. Clic droit : retirer.
Le travail clic sur une fiche, puis sur une ligne d'action — ou Auto. Espace : envoyer sur la case survolée.
           Retour arrière : rappeler.
Entrée     fonder le village, tenir la ligne, ou finir la phase — selon ce que le run attend.
La caméra  Q/E : pivoter. Molette : zoomer. WASD : déplacer. R : recadrer."""

## Marge basse du panneau d'affectation : la hauteur que la main occupe, plus son écart.
## Sans elle le panneau descendrait sur les cartes, la main étant ancrée en bas.
const HAND_CLEARANCE := 88.0

## Ce que `--shot-evenings` doit valoir pour capturer l'écran de **fondation**.
##
## Zéro journée, littéralement : le run n'a pas commencé. C'est le seul état de `I2` qu'une
## capture ne pouvait sinon jamais atteindre, puisque toute journée jouée commence par
## poser le Cœur — donc le seul écran neuf du jalon que personne n'aurait regardé. La
## valeur est comparée en **texte** et non convertie, pour distinguer un « 0 » écrit
## exprès d'un drapeau absent, que `to_int()` rend tous les deux à zéro.
const SHOT_FOUNDING := "0"

var _metrics: TerrainMetrics
var _world: DevWorld
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _targets: TargetHighlight
var _marker: ActionMarker
var _hand_view: HandView
var _palette: CommodityPalette
var _bar: ResourceBar
var _panel: ProductionPanel
var _battle: BattlePanel
var _crew: AssignmentPanel
var _label: Label

## Le libellé de la vague qu'on est en train de mener, et le jour où elle tombe.
##
## Retenus **avant** d'appeler `RunManager.fight()`, exactement pour la raison qui vaut
## depuis `I1` sur le libellé de phase : quand `battle_resolved` arrive, la vague est
## consommée et le cycle a avancé. Le rapport de bataille ne porte ni l'une ni l'autre —
## il dit ce que la vague a coûté, pas comment elle s'appelait.
var _battle_label := ""
var _battle_day := 0

## Identifiant -> prénom, relevé juste avant que la vague tombe.
##
## **Trouvé en capture, et c'est le défaut que `F1` avait nommé d'avance** : une table peut
## être fausse sur ce qu'elle prétend montrer. Le panneau annonçait « Pertes : bo, cy » —
## les identifiants internes — parce que `_name_of()` interroge le roster, et qu'au moment
## où `battle_resolved` arrive **les morts n'y sont plus** : `RunOrchestrator.fight()` les a
## retirés avant de rendre son rapport, ce qui est précisément l'ordre qui fait qu'un mort
## ne gagne pas d'XP. Rien ne plantait, rien ne compilait de travers, et la seule ligne du
## jeu qui raconte quelque chose disait des matricules.
var _battle_names: Dictionary[StringName, String] = {}

## Ouvrier sélectionné dans le panneau, ou &"" si aucun.
##
## Il vit ici et non dans la vue, exactement comme le rang de la carte tenue : `HandView`
## a posé à `D2` qu'une vue signale et ne sélectionne pas, et une seconde vue qui
## déciderait de sa propre sélection serait la même faute écrite deux fois.
var _held_worker := &""

## Rang de la carte tenue dans Hand.cards(), ou NO_SLOT. Un **rang** et non un
## identifiant : une main tient couramment deux exemplaires du même nom, et `D2` a payé
## cette leçon au clavier.
var _held_slot := NO_SLOT

## Quarts de tour appliqués au bâtiment qu'on s'apprête à poser.
var _turns := 0

## Sens du terrassement. Il démarre à « monter » plutôt qu'à « aucun » : une carte tenue
## sans sens choisi n'allumerait aucune cible, ce qui se lirait comme une panne.
var _direction := PlayedAction.DIRECTION_UP

var _last_action := "Prendre une carte : 1 à 9, ou un clic dessus."

## Le libellé de la phase qu'on est en train de finir.
##
## Retenu **avant** d'appeler `RunManager.end_phase()`, parce que le cycle a déjà avancé
## quand `phase_resolved` arrive : à ce moment-là `RunManager.phase()` désigne la
## suivante, et le rapport ne porte que l'identifiant de celle qui vient de finir. C'est
## la seule chose que le harnais sache et que le panneau ne puisse pas retrouver.
var _ending_label := ""

## Ce que la dernière résolution a changé à la réserve, annoté sur la barre jusqu'à la
## prochaine. Il se vide dès qu'on repose une carte : un « +5 » qui survivrait à une
## dépense annoterait le mauvais chiffre.
var _last_delta: Dictionary[StringName, int] = {}

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	var grid := TerrainGen.generate(SEED, balance.terrain_gen.map_size,
		balance.terrain_gen)

	RunManager.open(RunState.open(SEED, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance))

	_world = DevWorld.create(grid, _metrics, balance)
	add_child(_world)
	_renderer = BuildingRenderer.create(_state().city(), _metrics)
	add_child(_renderer)
	_ghost = PlacementGhost.create(_metrics)
	add_child(_ghost)
	_targets = TargetHighlight.create(_metrics)
	add_child(_targets)
	_marker = ActionMarker.create(_metrics)
	add_child(_marker)
	_hand_view = HandView.create(_state().catalogue())
	_hand_view.card_picked.connect(_hold)
	add_child(_hand_view)
	_palette = CommodityPalette.from_database()
	_bar = ResourceBar.create(_palette)
	_panel = ProductionPanel.create(_palette)
	_battle = BattlePanel.create()
	_battle.battle_requested.connect(_fight)
	_crew = AssignmentPanel.create(_state().catalogue())
	_crew.worker_picked.connect(_on_worker_picked)
	_crew.action_picked.connect(_on_action_picked)
	_crew.auto_requested.connect(_on_auto_requested)
	_label = _make_label()
	add_child(_hud_slot(_make_left_column(), Control.SIZE_SHRINK_BEGIN,
		Control.SIZE_SHRINK_BEGIN))
	add_child(_hud_slot(_make_right_column(), Control.SIZE_SHRINK_END,
		Control.SIZE_SHRINK_END, HAND_CLEARANCE))

	EventBus.phase_resolved.connect(_on_phase_resolved)
	EventBus.battle_pending.connect(_on_battle_pending)
	EventBus.battle_resolved.connect(_on_battle_resolved)
	# La première ligne du jeu doit parler du premier geste. « Prendre une carte » était
	# vrai tant qu'un run s'ouvrait Cœur posé et main tirée ; depuis `I2` il n'y a ni
	# l'un ni l'autre, et l'écran conseillerait un geste que le domaine refuse.
	if _state().awaits_its_heart():
		_last_action = "Poser le Cœur : un clic sur la carte, ou Entrée pour la case suggérée."
	_refresh_targets()
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne — donc
## le fantôme et le rapport se refont à chaque image. Les cibles, elles, ne bougent qu'à un
## changement de carte, de sens, de pose ou de phase.
##
## La barre de ressources y est aussi, et c'est délibéré : elle met ses nœuds à jour sur
## place plutôt que de se reconstruire, donc elle ne coûte rien par image. La rafraîchir
## sur événement aurait demandé de lister tous les gestes qui touchent la bourse — poser
## un bâtiment, résoudre, et demain piller —, et un oubli dans cette liste se serait vu
## comme une réserve qui ne bouge pas.
func _process(_delta: float) -> void:
	_refresh_ghost()
	_bar.show_ledger(_state().ledger(), _last_delta)
	_crew.show_state(_state(), _held_worker)
	_label.text = _report()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_play_here()
		MOUSE_BUTTON_RIGHT:
			_withdraw_here()
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_TAB:
			_turn_the_held_card()
		KEY_SPACE:
			_staff_here()
		KEY_BACKSPACE:
			_unstaff_here()
		KEY_ENTER, KEY_KP_ENTER:
			_press_on()
		_:
			var slot := event.keycode - KEY_1
			if slot < 0 or slot >= SLOT_KEYS:
				return
			_hold(slot)
	get_viewport().set_input_as_handled()

# --- Les gestes -----------------------------------------------------------------------

## Prend en main la carte de ce rang, ou la repose si elle y était déjà.
func _hold(slot: int) -> void:
	if slot < 0 or slot >= _state().deck().hand().size():
		_last_action = "Aucune carte au rang %d." % (slot + 1)
		return
	_held_slot = NO_SLOT if slot == _held_slot else slot
	var held := _held_card()
	_last_action = "Reposé." if held.is_empty() else "En main : %s." % _label_of(held)
	_refresh_targets()

## Tab agit sur ce que la carte tenue **ferait** : elle pivote un bâtiment, elle retourne
## un terrassement. Une seule touche pour une seule idée, plutôt qu'une par verbe.
func _turn_the_held_card() -> void:
	var held := _held_card()
	if held == SiteResolver.CARD_TERRAFORM:
		_direction = -_direction
		_last_action = "Terrassement : %s." % _sense()
		_refresh_targets()
		return
	_turns = posmod(_turns + 1, BuildingData.QUARTER_TURNS)
	_last_action = "Orientation : %s." % _orientation()

## Joue la carte tenue sur la cellule survolée.
##
## Un seul chemin pour les deux natures de carte, à l'inverse du harnais Cartes qui en
## avait deux : `RunOrchestrator.play()` est la porte unique, et c'est lui qui sait
## laquelle des deux il a sous la main.
func _play_here() -> void:
	var hovered := _world.cursor().hovered()
	if _state().awaits_its_heart():
		if not hovered.is_hit():
			_last_action = "Rien sous le curseur — le Cœur se pose sur la carte."
			return
		_found_at(hovered.cell())
		return
	var held := _held_card()
	if held.is_empty():
		_last_action = "Aucune carte en main — 1 à 9, ou un clic sur une carte."
		return
	if not hovered.is_hit():
		_last_action = "Rien sous le curseur."
		return
	var result := RunManager.play(held, hovered.cell(), _turns, _direction)
	if not result.is_ok():
		_last_action = "Refusé : %s en %s — %s" % [_label_of(held), hovered.cell(),
			result.reason()]
		return
	if result.posts_an_action():
		_last_action = "Posé : %s en %s, %d poste(s), 0 ouvrier." % [
			_label_of(held), result.anchor(), result.action().capacity()]
	else:
		_renderer.rebuild(_state().city())
		# La bourse vient d'être débitée : le delta de la dernière résolution n'annote
		# plus le chiffre qu'il commentait, et un « +5 » à côté d'une réserve qui vient
		# de baisser de 20 se lirait à l'envers.
		_last_delta = {}
		_last_action = "Chantier ouvert : %s en %s, %s — payé %s." % [
			_label_of(held), result.anchor(), _orientation(),
			_cost_text(result.paid())]
	_release()

func _withdraw_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	if not RunManager.withdraw(action.id()):
		_last_action = "Retrait refusé — %s ne le permet pas." % _phase_label()
		return
	_last_action = "Retiré : %s en %s — la carte revient en main." % [
		_label_of(action.card()), action.target()]
	# La main vient de changer, donc un **rang** dans la main ne désigne plus la même
	# carte : la carte rendue s'insère dans son pool et décale tout ce qui suit. C'est le
	# même piège que `D2` a payé au clavier, et la même réponse que `_play_here()` — tout
	# geste qui touche la main repose ce qu'on tenait.
	_release()

## Envoie un ouvrier sur l'action sous le curseur : le sélectionné, ou le meilleur.
##
## Le premier ouvrier libre a tenu de `D2` à `E2`, et son commentaire renvoyait déjà ici :
## `DESIGN.md` 3.4 dit que **qui** l'on place est la décision de fond d'une phase. Elle se
## prend maintenant dans le panneau ; cette touche en est le raccourci, et c'est la même
## règle qui la sert — `StaffingAdvisor` classe, on prend le premier du classement. Le
## bouton n'est donc pas un chemin à part : c'est ce geste-ci répété.
func _staff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	_staff_on(action)

## Envoie l'ouvrier tenu — ou le meilleur de son métier — sur cette action.
func _staff_on(action: PlayedAction) -> void:
	var worker := _held_worker if not _held_worker.is_empty() else _best_for(action)
	if worker.is_empty():
		_last_action = "Plus aucun ouvrier libre — tout le monde est déjà au travail."
		return
	if not RunManager.staff(worker, action.id()):
		_last_action = "%s en %s : %s" % [_label_of(action.card()), action.target(),
			_staffing_refusal(worker, action)]
		return
	_held_worker = &""
	_last_action = "%s -> %s en %s (%d/%d)." % [
		_name_of(worker), _label_of(action.card()), action.target(),
		_state().staffed_on(action.id()).size(), action.capacity()]
	_refresh_markers()

## Le meilleur ouvrier libre pour cette action, ou &"" s'il n'y en a aucun.
##
## Le classement vient du domaine et n'est pas refait ici : c'est celui-là même que le
## bouton suit, donc la touche et le bouton ne peuvent pas envoyer deux personnes
## différentes. Deux classements auraient dérivé, exactement comme deux tables de ciblage
## l'auraient fait à `D2`.
func _best_for(action: PlayedAction) -> StringName:
	var family := StaffingAdvisor.family_of(action, _state().terrain(),
		_state().city().to_snapshot(), _state().balance().actions)
	var ranked := StaffingAdvisor.ranked_for(_state().free_workers(), _state().labor(),
		family)
	return &"" if ranked.is_empty() else ranked[0]

## Le refus d'affectation, en clair et avec le geste qui le lève.
##
## La raison vient du domaine et n'est pas redevinée ici : l'écran ne fait que traduire.
## Sans cette traduction, la touche paraissait morte — le premier essai au clavier a
## donné un « refusé » sans cause, alors que la phase courante l'expliquait entièrement.
func _staffing_refusal(worker: StringName, action: PlayedAction) -> String:
	var reason := RunOrchestrator.staffing_refusal(_state(), worker, action.id())
	match reason:
		PlayResult.REASON_WRONG_PHASE:
			return "affecter n'est pas permis en phase « %s ». Entrée pour la finir." \
				% _phase_label()
		RunOrchestrator.REASON_NO_ROOM:
			return "ses %d poste(s) sont pris. Retour arrière pour les rappeler." \
				% action.capacity()
		RunOrchestrator.REASON_ALREADY_STAFFED:
			return "%s tient déjà une autre action." % _name_of(worker)
		RunOrchestrator.REASON_ABSENT_WORKER:
			return "%s est absent." % _name_of(worker)
		RunOrchestrator.REASON_NO_ACTION:
			return "cette action n'est plus posée."
	return "refusé (%s)." % reason

## Prend une fiche en main, ou la repose si elle y était déjà. Même geste que pour une
## carte, et volontairement : ce sont les deux moitiés d'une même intention.
func _on_worker_picked(worker: StringName) -> void:
	_held_worker = &"" if worker == _held_worker else worker
	if _held_worker.is_empty():
		_last_action = "Reposé."
		return
	_last_action = "%s en main — cliquer une ligne d'action pour l'y envoyer." \
		% _name_of(worker)

func _on_action_picked(action: int) -> void:
	var posted := _state().board().at(action)
	if posted == null:
		_last_action = "Cette action n'est plus posée."
		return
	_staff_on(posted)

## Le bouton d'auto-affectation. Il ne calcule rien ici : le domaine plane, l'orchestrateur
## applique, et l'écran ne fait que compter ce qui est parti.
func _on_auto_requested() -> void:
	var placed := RunManager.auto_staff()
	if placed.is_empty():
		_last_action = "Auto : rien à remplir — %s." % _why_auto_did_nothing()
		return
	var names := PackedStringArray()
	for worker in placed:
		names.append(_name_of(worker))
	_held_worker = &""
	_last_action = "Auto : %d ouvrier(s) placé(s) — %s." % [placed.size(),
		", ".join(names)]
	_refresh_markers()

## Pourquoi le bouton n'a rien fait. Trois causes, et aucune n'est une panne — c'est la
## leçon de `I1` sur le refus muet, appliquée au seul geste de `W2` qui puisse ne rien
## produire sans que rien ne soit cassé.
func _why_auto_did_nothing() -> String:
	if not _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		return "affecter n'est pas permis en phase « %s »" % _phase_label()
	if _state().free_workers().is_empty():
		return "tout le monde est déjà au travail"
	return "aucun poste libre sur ce qui est posé"

func _unstaff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var recalled := RunManager.unstaff(action.id())
	_last_action = "%d ouvrier(s) rappelé(s) de %s." % [
		recalled.size(), _label_of(action.card())]
	_refresh_markers()

## Entrée fait avancer le run, quoi qu'il attende : elle fonde, elle mène la bataille, ou
## elle finit la phase.
##
## Une seule touche pour une seule idée — « je suis prêt » —, comme Tab agit sur ce que la
## carte tenue **ferait**. Les trois attentes sont exclusives et le domaine les distingue
## déjà ; une touche par cas aurait demandé au joueur de savoir laquelle avant d'appuyer.
##
## Fonder par Entrée pose le Cœur sur la case que le domaine suggère. C'est le « bouton par
## défaut » que `F1` annonçait pour le déploiement automatique, et c'est le même geste :
## la règle automatique de `I1` survit comme raccourci, le clic reste le choix.
func _press_on() -> void:
	if _state().awaits_its_heart():
		_found_at(_state().suggested_heart_anchor())
		return
	if _state().awaits_a_battle():
		_fight()
		return
	_end_phase()

## Termine la phase. C'est `RunManager` qui décide si ça résout — le harnais ne connaît
## pas la journée, il la traverse.
##
## Trois suites depuis `I2` et non plus deux : la phase suivante, la fin du run, ou une
## **bataille qui attend**. La troisième se lit à ce que le cycle n'a pas bougé, et il
## fallait la nommer : annoncer « au tour de Matin » alors qu'on est toujours au Matin qui
## vient de finir serait un écran qui ment sur ce qu'il attend.
func _end_phase() -> void:
	if _state().cycle().is_over():
		_last_action = "Run terminé."
		return
	var finished := _phase_label()
	_ending_label = finished
	RunManager.end_phase()
	_held_slot = NO_SLOT
	_refresh_targets()
	if _state().awaits_a_battle():
		_last_action = "%s terminée — %s en approche. Entrée pour tenir la ligne." % [
			finished, _state().pending_wave().label]
		return
	if _state().cycle().is_over():
		_last_action = "%s terminée — %s." % [finished, _verdict()]
		return
	_last_action = "%s terminée. Au tour de %s." % [finished, _phase_label()]

## Pose le Cœur sur cette cellule, et ouvre la première journée.
##
## Le refus vient du domaine et n'est pas redeviné ici — `PlacementValidator` répond, comme
## pour n'importe quelle carte de bâtiment. C'est le tout premier geste d'un run, donc
## l'endroit où un refus muet coûterait le plus cher.
func _found_at(cell: Vector2i) -> void:
	if cell == NO_CELL:
		_last_action = "Aucune place pour le Cœur sur ce relief."
		return
	var result := RunManager.found(cell, _turns)
	if not result.is_ok():
		_last_action = "Cœur refusé en %s — %s" % [cell, result.reason()]
		return
	_renderer.rebuild(_state().city())
	_last_action = "Cœur posé en %s. La première journée commence." % cell
	_refresh_targets()

## Fait tomber la vague en attente.
##
## Le libellé et le jour sont retenus **avant** l'appel : la vague est consommée et le
## cycle a avancé quand le signal arrive.
func _fight() -> void:
	if not _state().awaits_a_battle():
		_last_action = "Aucune vague en approche."
		return
	_battle_label = _state().pending_wave().label
	_battle_day = _state().cycle().day()
	_battle_names = {}
	for worker in _state().roster().workers():
		_battle_names[worker.id()] = worker.given_name()
	var report := RunManager.fight()
	_held_slot = NO_SLOT
	_refresh_targets()
	# Les murs sont tombés et le relief n'a pas bougé : seul le rendu de la ville est à
	# refaire. C'est aussi le seul endroit du harnais où un bâtiment disparaît sans qu'un
	# geste du joueur l'ait visé.
	_renderer.rebuild(_state().city())
	if _state().cycle().is_over():
		_last_action = "%s : %s." % [_battle_label, _verdict()]
		return
	_last_action = "%s repoussée." % _battle_label if report.is_held() 		else "%s a frappé. Au tour de %s." % [_battle_label, _phase_label()]

## Le seul endroit du harnais qui réagit à un signal plutôt qu'à une touche, et c'est ce
## que `I0` avait dessiné : le domaine retourne, `RunManager` publie, l'écran écoute.
##
## `E2` a sorti d'ici le pavé de texte que `I1` fabriquait à la main : c'est le panneau
## qui met en forme le rapport, et le harnais ne fait plus que le lui passer. Il ne
## calcule qu'une chose, le delta de la réserve, et par une fonction de la vue.
func _on_phase_resolved(report: PhaseReport) -> void:
	_panel.show_report(report, _ending_label)
	_crew.show_progress(report.progress())
	# La résolution a vidé le brouillon d'affectation : garder une fiche en main
	# encadrerait un choix que plus rien ne porte.
	_held_worker = &""
	_last_delta = ResourceBar.delta_of(report,
		_state().balance().economy.upkeep_resource)
	# Le relief a pu bouger sous un terrassement, et la ville sous un chantier. Refaire
	# les deux plutôt que de deviner lequel : deux résolutions par jour, le coût est nul.
	_world.show_grid(_state().grid())
	_renderer.rebuild(_state().city())

## La vague est armée et n'est pas encore tombée : le seul moment que `DESIGN.md` 3.8 fait
## exister, et le seul où l'on peut encore regarder ce qu'on lui oppose.
##
## Les deux chiffres viennent du Combat et ne sont pas refaits ici. Un écran qui
## additionnerait des points de défense serait une seconde règle de combat, et celle qui
## s'afficherait ne serait pas celle qui frappe — le même piège que deux tables de ciblage
## à `D2`.
func _on_battle_pending(_wave: StringName) -> void:
	var balance := _state().balance()
	var city := _state().city().to_snapshot()
	var force := _state().roster().to_combat(balance.combat.combat_skill_family,
		balance.workforce)
	var slots := InstantCombatResolver.slots_for(city, balance.combat)
	_battle.show_pending(_state().pending_wave(), _state().cycle().day(),
		InstantCombatResolver.defense_of(city, force, balance.combat),
		InstantCombatResolver.deploy(force, slots).size())

## Ce que la vague a coûté. Les prénoms sont traduits ici : le panneau ne connaît pas le
## roster, et c'est ce que `E2` a posé pour `ProductionPanel`.
##
## Ils viennent du relevé pris **avant** la bataille et non du roster, qui ne connaît plus
## les morts — voir `_battle_names`.
func _on_battle_resolved(report: BattleReport) -> void:
	var names := PackedStringArray()
	for fallen in report.damage().lost():
		names.append(_battle_names.get(fallen, String(fallen)))
	_battle.show_report(report, _battle_label, _battle_day, names)
	_crew.show_progress(report.progress())

# --- Les rafraîchissements -------------------------------------------------------------

func _release() -> void:
	_held_slot = NO_SLOT
	_refresh_targets()

func _refresh_markers() -> void:
	_marker.rebuild(_state().board().to_plan(), _state().to_assignment(),
		_state().terrain())

## Recalcule le jeu de cibles de la carte tenue. Un balayage complet de la carte, et il
## n'a lieu qu'ici : à une prise de carte, un retournement, une pose, un retrait ou une
## fin de phase.
func _refresh_targets() -> void:
	_refresh_markers()
	_hand_view.show_hand(_state().deck().hand(), _held_slot)
	var held := _held_card()
	if held.is_empty() or not ActionTargeting.handles(held):
		_targets.clear()
		return
	var cells: Array[Vector2i] = []
	var heights := PackedInt32Array()
	var extent := _state().terrain().size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if not _validate(held, cell).is_ok():
				continue
			cells.append(cell)
			heights.append(_state().terrain().height_at(cell))
	_targets.show_targets(cells, heights)

## Montre ce que poserait une carte de bâtiment sous le curseur.
##
## Le fantôme ne dit **que** le placement, et c'est assumé : la bourse est la seconde
## question, elle se lit sur la ligne de survol. Un fantôme qui virerait au rouge faute de
## bois mélangerait deux refus que `DESIGN.md` 3.2 sépare exprès.
func _refresh_ghost() -> void:
	var hovered := _world.cursor().hovered()
	var data := _founding_data() if _state().awaits_its_heart() 		else _building_of(_held_card())
	if not hovered.is_hit() or data == null:
		_ghost.clear()
		return
	var result := PlacementValidator.validate(_state().city(), _state().terrain(), data,
		hovered.cell(), _turns)
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), result)

# --- Le rapport ------------------------------------------------------------------------

## Ce qui reste du rapport texte de `I1` après que `E2` puis `W2` en ont pris des morceaux.
##
## La réserve est partie sur la barre, la résolution sur le panneau de production, le
## plateau et le roster sur le panneau d'affectation. Ce qui demeure est ce qu'aucun des
## trois jalons d'écran n'a de vue pour : les piles et le survol, qui attendront `I2`.
##
## Chaque fois, le morceau est **retiré** plutôt que doublé. Garder les deux laisserait le
## même chiffre lisible à deux endroits, et un chiffre affiché deux fois est un chiffre
## qui finira par différer de lui-même — la capture n'en vérifie qu'une des deux mises en
## forme, et l'autre dérive en silence.
func _report() -> String:
	var lines := PackedStringArray()
	lines.append(_banner())
	lines.append("")
	lines.append_array(_closing_lines())
	lines.append(_piles_line())
	lines.append("")
	lines.append(_hover_line())
	lines.append(_last_action)
	lines.append("")
	lines.append(CONTROLS)
	return "\n".join(lines)

## Le bandeau de phase. Le libellé et les gestes viennent de la `PhaseDef`, jamais d'un
## nom écrit ici : c'est ce qui fera de l'arbitrage de `I2b` un échange de `.tres`.
##
## La réserve en est sortie à `E2`. Elle y était parce qu'il n'y avait nulle part
## ailleurs où la mettre ; la garder en double aurait donné deux endroits où lire le même
## chiffre, donc un endroit où le lire faux le jour où l'un des deux dériverait.
func _banner() -> String:
	var cycle := _state().cycle()
	if _state().awaits_its_heart():
		return "Fondation   |   poser le Cœur : clic sur la carte, ou Entrée pour la case suggérée   |   seed %d" 			% SEED
	if cycle.is_over():
		return "Run terminé   |   %s" % _verdict()
	if _state().awaits_a_battle():
		return "Jour %d/%d   |   %s en approche   |   tenir la ligne" % [
			cycle.day(), cycle.days(), _state().pending_wave().label]
	return "Jour %d/%d   |   %s   |   %s" % [
		cycle.day(), cycle.days(), _phase_label(), _permissions()]

## Comment le run s'est terminé, en une demi-ligne.
##
## La cause est traduite ici et non portée par le domaine : un `RunOutcome` rend une
## constante, l'écran en fait une phrase — le même partage que `_staffing_refusal()` depuis
## `I1`.
##
## Court, et il l'est en deux fois. La première capture de `I2` mettait la phrase entière
## dans le bandeau, qui passait sous les panneaux de droite : la seule chose qu'il devait
## annoncer se lisait « Victoire — la dernière journée est passée au jour 15. Score 431 —
## 71 en ré ». La raccourcir une fois ne suffisait pas — la moitié gauche de l'écran est
## large de sept cents pixels, et un bandeau ne se replie pas. Ce qui tient est donc **un
## mot**, et la cause comme le détail sont des lignes du rapport, où le texte peut aller à
## la ligne.
func _verdict() -> String:
	var ending := _state().outcome()
	if ending == null:
		return "%d jour(s) joués, seed %d" % [_state().cycle().days(), SEED]
	return "%s   |   jour %d, score %d" % [_outcome_word(ending), ending.day(),
		ending.score()]

func _outcome_word(ending: RunOutcome) -> String:
	return "Victoire" if ending.is_victory() else "Défaite"

## Le détail du score, sur sa propre ligne du rapport.
##
## Les quatre termes que `DESIGN.md` 5 énumère, parce qu'un total seul ne dit pas ce qui l'a
## fait — c'est la raison pour laquelle `RunOutcome` les garde à côté de la somme.
func _score_line() -> String:
	var ending := _state().outcome()
	if ending == null:
		return ""
	return "Score %d — %d en réserve, %d bâtiment(s) debout, %d ouvrier(s), %d niveau(x)." \
		% [ending.score(), ending.resources(), ending.buildings(), ending.workers(),
			ending.levels()]

## Pourquoi le run s'est arrêté, en clair.
##
## La traduction d'une constante du domaine, comme `_staffing_refusal()` depuis `I1` : un
## `RunOutcome` rend `&"heart"`, l'écran en fait une phrase. Le repli par défaut existe pour
## qu'une quatrième cause, le jour où il y en aura une, se lise plutôt que de disparaître.
func _cause_of(ending: RunOutcome) -> String:
	match ending.cause():
		RunOutcome.CAUSE_SURVIVED:
			return "La dernière journée est passée, le village tient debout."
		RunOutcome.CAUSE_HEART:
			return "Le Cœur est tombé."
		RunOutcome.CAUSE_ROSTER:
			return "Il ne reste plus personne au village."
	return "Fin : %s." % ending.cause()

## Le détail du score s'ajoute au rapport une fois le run fini, et lui seul : les autres
## lignes décrivent une partie en cours.
func _closing_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if not _state().cycle().is_over():
		return lines
	lines.append(_cause_of(_state().outcome()))
	lines.append(_score_line())
	lines.append("")
	return lines

## Ce que la phase courante autorise, en clair. L'écran ne suppose rien : il pose les
## deux questions au domaine et affiche les réponses.
func _permissions() -> String:
	var allowed := PackedStringArray()
	if _state().cycle().permits(PhaseDef.ACTION_PLAY):
		allowed.append("poser")
	if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		allowed.append("affecter")
	if _state().cycle().resolves():
		allowed.append("résout en partant")
	return "—" if allowed.is_empty() else ", ".join(allowed)

## Les trois pioches, une par ligne.
##
## Elles tenaient sur une seule jusqu'à `E2`, qui a posé le panneau de production dans le
## coin où cette ligne finissait : le troisième pool passait dessous et se lisait à
## moitié. Trois lignes courtes valent mieux qu'une longue tronquée, et la colonne ainsi
## formée se lit de toute façon mieux qu'une file de séparateurs.
func _piles_line() -> String:
	var lines := PackedStringArray()
	for pool in CardData.POOLS:
		lines.append("Piles %-9s %d en main, %d pioche, %d défausse" % [pool,
			_state().deck().hand_size(pool), _state().deck().draw_size(pool),
			_state().deck().discard_size(pool)])
	return "\n".join(lines)

## Ce que le curseur désigne, et ce que la carte tenue y ferait — coût compris.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return "Survol : —"
	var cell := hovered.cell()
	var line := "Survol : (%d, %d)   h = %d   %s" % [cell.x, cell.y, hovered.height(),
		_state().terrain().terrain_at(cell).id]
	if _state().awaits_its_heart():
		return "%s   ->   %s, %s%s" % [line, _founding_label(), _orientation(),
			"" if _founding_placement(cell).is_ok()
				else "   <- %s" % _founding_placement(cell).reason()]
	var building := _state().city().building_at(cell)
	if building != null:
		line += "   |   %s : %s" % [building.data().id, _site_state(building)]
	var held := _held_card()
	if held.is_empty():
		return line
	var data := _building_of(held)
	if data != null:
		return "%s   ->   %s, %s, coût %s%s" % [line, _label_of(held), _orientation(),
			_cost_text(data.cost),
			"" if _state().ledger().can_afford(data.cost) else "   ← réserve insuffisante"]
	var verdict := _validate(held, cell)
	return "%s   ->   %s : %s" % [line, _label_of(held),
		"accepté, %d poste(s)" % verdict.capacity() if verdict.is_ok()
			else String(verdict.reason())]

# --- Les petites lectures ---------------------------------------------------------------

func _state() -> RunState:
	return RunManager.state()

func _validate(card: StringName, cell: Vector2i) -> TargetResult:
	return ActionTargeting.validate(card, cell, _state().terrain(),
		_state().city().to_snapshot(), _state().board().to_plan(),
		_state().balance().actions, _direction)

## La carte tenue, ou &"" si l'on ne tient rien. Relue depuis la main à chaque appel : une
## main qui rétrécit invalide le rang, et le rendre vide d'office évite de le remettre à
## zéro partout où la main bouge.
func _held_card() -> StringName:
	var cards := _state().deck().hand().cards()
	if _held_slot < 0 or _held_slot >= cards.size():
		return &""
	return cards[_held_slot]

## Dernière action posée sur la cellule survolée, ou null.
func _action_here() -> PlayedAction:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return null
	var here := _state().board().at_cell(hovered.cell())
	if here.is_empty():
		return null
	return here[here.size() - 1]

func _phase_label() -> String:
	var phase := RunManager.phase()
	return "—" if phase == null else phase.label

func _sense() -> String:
	return _sense_of(_direction)

func _sense_of(direction: int) -> String:
	return "monter" if direction == PlayedAction.DIRECTION_UP else "descendre"

func _orientation() -> String:
	return "%d/4" % posmod(_turns, BuildingData.QUARTER_TURNS)

func _site_state(building: PlacedBuilding) -> String:
	if building.is_complete():
		return "achevé"
	return "chantier %d/%d" % [building.progress(), building.data().build_actions]

func _label_of(card: StringName) -> String:
	var catalogue := _state().catalogue()
	if not catalogue.has(card):
		return String(card)
	return catalogue.card(card).label

func _name_of(worker: StringName) -> String:
	if not _state().roster().has(worker):
		return String(worker)
	return _state().roster().worker(worker).given_name()

## Le bâtiment d'ouverture, ou null si `data/balance/` n'en nomme aucun.
##
## Il est lu sur l'équilibrage et jamais écrit ici : `&"heart"` dans un `.gd` serait
## l'identifiant de contenu que les conventions refusent partout ailleurs.
func _founding_data() -> BuildingData:
	return _state().building(_state().balance().run.starting_building)

## Le nom du bâtiment d'ouverture, tel que `data/` le porte.
func _founding_label() -> String:
	var data := _founding_data()
	return "—" if data == null else String(data.id)

## Ce que le validateur dit de la case survolée pendant la fondation.
##
## La même question que le fantôme pose, posée au même endroit : c'est
## `PlacementValidator` qui répond, et l'écran ne fait que traduire. Un survol qui
## afficherait « accepté » là où le fantôme est rouge serait deux règles de placement.
func _founding_placement(cell: Vector2i) -> PlacementResult:
	return PlacementValidator.validate(_state().city(), _state().terrain(),
		_founding_data(), cell, _turns)

## Le bâtiment que cette carte pose, ou null si ce n'en est pas une.
func _building_of(card: StringName) -> BuildingData:
	if card.is_empty() or not _state().catalogue().has(card):
		return null
	var data := _state().catalogue().card(card)
	if not data.places_a_building():
		return null
	return _state().building(data.building)

## Un coût en clair. La palette met un lot en forme et rend « — » pour un lot vide ; un
## coût vide, lui, se dit « gratuit ». C'est la phrase du harnais et non celle de la
## palette : la même absence ne se raconte pas pareil selon qu'on paie ou qu'on reçoit.
func _cost_text(cost: Dictionary[StringName, int]) -> String:
	if cost.is_empty():
		return "gratuit"
	return _palette.bundle_text(cost)

# --- La mise en place ---------------------------------------------------------------------

func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	for id in GameDatabase.list_building_ids():
		table[id] = GameDatabase.get_building(id)
	return table

## Colle une vue de HUD dans un coin de l'écran, à la marge du rapport.
##
## Une bande plein écran à marges, dont l'enfant se rétracte vers le coin voulu — et non
## des ancres et des décalages calculés à la main. `E2` a essayé de les calculer, et la
## capture a montré les deux pièges l'un après l'autre.
##
## Le premier est que `set_anchors_preset()` prend un **booléen** en second argument, là
## où `set_anchors_and_offsets_preset()` prend un mode de redimensionnement : lui passer
## `PRESET_MODE_MINSIZE` revient à lui dire « garde tes décalages », donc à laisser la vue
## à zéro. Un `PanelContainer` de taille nulle ne dessine pas son fond, et ses libellés
## débordent par-dessus la carte.
##
## Le second survit à la correction du premier : une taille minimale lue juste après avoir
## ajouté des enfants est encore celle d'avant, Godot la recalculant à la passe suivante.
## Le panneau se plaçait donc toujours sur la taille du rapport **précédent**.
##
## Un conteneur ne se trompe sur aucun des deux, et il ne se trompe pas non plus à la
## dixième résolution : c'est lui qui refait la mise en page quand le contenu change.
## `bottom` s'écarte de la marge commune pour une seule raison, et c'est la main : elle
## est ancrée au bas de l'écran, donc une vue qui se rétracte vers le bas lui monterait
## dessus. Une marge plus grande est la façon de le dire dans le vocabulaire du
## conteneur ; une hauteur recopiée serait exactement ce que `E2` a payé pour ne plus
## écrire.
func _hud_slot(view: Control, horizontal: int, vertical: int,
		bottom := REPORT_MARGIN) -> MarginContainer:
	var slot := MarginContainer.new()
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right"]:
		slot.add_theme_constant_override("margin_%s" % side, int(REPORT_MARGIN))
	slot.add_theme_constant_override("margin_bottom", int(bottom))
	view.size_flags_horizontal = horizontal
	view.size_flags_vertical = vertical
	slot.add_child(view)
	return slot

## La barre, puis le rapport texte dessous.
##
## Empilés dans un `VBoxContainer` plutôt que posés à des hauteurs écrites à la main : le
## texte démarre sous la barre parce qu'il la suit, et non parce qu'un chiffre recopié se
## trouve valoir la bonne hauteur. Régler la barre ne peut donc pas faire repasser le
## texte dessous.
##
## La barre se rétracte à sa largeur ; sans ça, la colonne l'étirerait sur la largeur du
## bloc de texte, qui est bien plus large. Le panneau de bataille fait de même.
##
## Il s'intercale entre les deux, et il est masqué tant qu'aucune vague n'est en jeu — voir
## `_make_right_column()`, qui dit pourquoi il n'y est pas. Entre la barre et le texte
## plutôt qu'en dessous : ce qu'une vague pille est ce que la barre au-dessus affiche, et
## tant qu'elle est en approche c'est la seule chose de l'écran qui demande une décision.
func _make_left_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(REPORT_MARGIN))
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)
	_battle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_battle)
	column.add_child(_label)
	return column

## Le compte rendu de phase, puis le panneau d'affectation dessous.
##
## Empilés pour la raison que la première capture de `W2` a montrée : posés séparément,
## l'un en haut à droite et l'autre en bas à droite, ils se **recouvrent** dès que le
## plateau porte cinq actions — le panneau grandit vers le haut et vient manger les lignes
## « Chantiers » et « Upkeep » du rapport. Ce n'est pas une marge à régler : c'est deux
## vues qui grandissent l'une vers l'autre, donc un chevauchement qui n'attend qu'une
## phase chargée. Une colonne les fait se pousser au lieu de se croiser.
##
## Le prix est que le compte rendu descend du haut de l'écran, où `E2` l'avait mis. Il n'y
## était pas par principe mais parce que rien d'autre n'occupait ce coin, et il reste au
## même endroit d'une résolution à l'autre — ce qui est la seule chose qu'on lui demande.
##
## Les deux se rétractent à leur largeur ; sans ça, la colonne étirerait le plus étroit
## sur la largeur du plus large.
##
## **Le panneau de bataille n'est pas ici, et la capture de `I2` explique pourquoi.** Il y a
## d'abord été mis, en tête — un assaut en approche se lit avant un compte rendu de récolte
## —, et le jour de la dernière vague la colonne débordait par le bas : trois panneaux
## empilés plus la marge que la main réclame ne tiennent pas dans huit cents pixels, et la
## dernière fiche d'ouvrier sortait de l'écran. C'est le défaut qu'`W2` avait déjà payé, un
## cran plus loin — la colonne ne se recouvre pas, elle **déborde**, et augmenter une marge
## basse aggraverait la chose au lieu de la corriger.
##
## Il vit donc dans la colonne de gauche, où la place est. Ce n'est pas un pis-aller : `W2`
## notait déjà du compte rendu de phase qu'« il n'y était pas par principe mais parce que
## rien d'autre n'occupait ce coin ». Et la lecture y gagne — la vague est voisine de la
## réserve qu'elle va piller.
func _make_right_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(REPORT_MARGIN))
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_panel)
	_crew.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_crew)
	return column

## Le rapport texte. Il n'a plus ni ancre ni décalage depuis `E2` : il est empilé sous la
## barre de ressources par la colonne de gauche, qui les place l'un après l'autre.
func _make_label() -> Label:
	var label := Label.new()
	label.name = "RunReport"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", REPORT_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

# --- La capture --------------------------------------------------------------------------

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-hover x,y] [--shot-evenings n]
##
## `src/adapters/` n'est pas testé et les trois commandes de vérification ne regardent pas
## l'écran : cette capture est le contrôle principal du jalon. Elle joue donc une journée
## entière plutôt qu'un geste — un chantier ouvert, payé, avancé, et un terrassement
## exécuté —, sans quoi elle ne montrerait rien de ce que `I1` ajoute.
##
## **Elle joue le run entier et non plus une journée**, ce qui est le sujet de `I2` : un
## `--shot-evenings 16` fonde, traverse quinze journées, encaisse les trois vagues du
## calendrier et s'arrête sur le bandeau de fin. Une vague reste **en approche** quand elle
## tombe sur la dernière journée demandée, de sorte que les deux moitiés de la coupure de
## `DESIGN.md` 3.8 soient chacune atteignables en une commande. Et `--shot-evenings 0`
## capture la fondation, voir `SHOT_FOUNDING`.
##
## Elle n'imprime plus le compte rendu de la dernière phase : il est devenu un panneau, et
## un panneau se regarde. Le réécrire en texte à côté aurait donné deux mises en forme du
## même rapport, dont une seule serait vérifiée par la capture — donc l'autre dériverait.
## Ce qui reste imprimé est ce qu'aucune image ne rend lisible d'un coup d'œil : la réserve
## chiffrée, qui dit si la bourse a bien été débitée.
##
## **`W2` lui retire la table des actions posées**, pour la même raison et à contrecœur :
## c'est elle qui avait attrapé le seul vrai bug de `D2`. Elle est désormais dessinée par
## le panneau d'affectation, avec les ouvriers qui la tiennent, et la garder en texte
## aurait laissé la version imprimée dire vrai pendant qu'une mise en page fautive cachait
## l'autre — c'est exactement le piège que `E2` a rencontré deux fois de suite.
##
## Ce que la journée scriptée traverse a changé en revanche : elle remplit les postes par
## le **bouton**, donc par `StaffingAdvisor`. Le chemin neuf du jalon est emprunté par le
## seul contrôle qui regarde l'écran.
##
## Et elle s'arrête désormais **au milieu** d'une phase, sur une dernière manche posée et
## affectée qu'on ne finit pas. Une capture prise juste après une résolution montrait un
## plateau vide et six fiches oisives, c'est-à-dire tout `W2` sauf ce qu'il fait : la
## seule image qui prouve quelque chose est celle où des ouvriers tiennent des postes.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_state().grid().size() / 2))
	var asked := DevShot.argument(DevShot.SHOT_EVENINGS_FLAG)
	if asked != SHOT_FOUNDING:
		_scripted_found()
		var days := maxi(asked.to_int(), 1)
		for index in days:
			_scripted_day()
			if _state().awaits_a_battle() and index < days - 1:
				_fight()
		if not _state().awaits_a_battle() and not _state().cycle().is_over():
			_scripted_open_phase()
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[run_harness] %s" % _banner())
	print("[run_harness] %s" % _armies_line())
	print("[run_harness] réserve %s — %d/%d" % [
		_palette.bundle_text(_state().ledger().amounts()),
		_state().ledger().total(), _state().ledger().capacity()])
	print("[run_harness] %s" % _hover_line())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[run_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Fonde le village là où le domaine le suggère.
##
## Elle doit passer avant tout : depuis `I2`, un run attend son Cœur et refuse tout autre
## geste d'ici là. Sans elle, la journée scriptée poserait zéro carte et la capture
## montrerait une carte nue — ce qui compilerait, ne lèverait aucune erreur, et serait faux
## sur ce qu'elle prétend montrer.
func _scripted_found() -> void:
	if not _state().awaits_its_heart():
		return
	_found_at(_state().suggested_heart_anchor())

## Ce que la ligne oppose à la vague en approche, ou ce que la dernière a coûté.
##
## Imprimé à côté de la réserve, et pour la même raison qu'elle : c'est ce qu'une image ne
## rend pas lisible d'un coup d'œil. Un `BattlePanel` masqué et un `BattlePanel` qui annonce
## zéro brèche se ressemblent beaucoup en capture, et ne disent pas du tout la même chose.
func _armies_line() -> String:
	if _state().awaits_a_battle():
		return "vague en approche : %s, puissance %d" % [
			_state().pending_wave().label, _state().pending_wave().power]
	if _battle_label.is_empty():
		return "aucune vague n'est encore tombée"
	return "dernière vague : %s au jour %d — %d bâtiment(s), %d ouvrier(s) restants" % [
		_battle_label, _battle_day, _state().city().count(), _state().roster().size()]

## Une journée jouée comme une main humaine la jouerait : on pose ce qu'on peut, on
## envoie les ouvriers, on finit la journée.
##
## Elle s'arrête sur la **fin de journée** et non sur un compte écrit ici : une journée de
## trois phases se joue sans qu'une ligne bouge.
##
## Elle s'est d'abord arrêtée sur `resolves()`, ce qui revenait au même tant qu'une seule
## phase par jour résolvait. Depuis que les deux le font, ça n'en jouait plus qu'une —
## défaut que seule la capture pouvait montrer, puisqu'elle est le seul contrôle qui
## compte les jours.
func _scripted_day() -> void:
	while not _state().cycle().is_over():
		if _state().cycle().permits(PhaseDef.ACTION_PLAY):
			_scripted_plays()
		if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
			_scripted_staffing()
		var closed := _state().cycle().closes_the_day()
		_end_phase()
		if closed:
			return

## Pose et affecte sans finir la phase : l'état sur lequel la capture s'arrête.
##
## C'est le seul moment où le panneau d'affectation a quelque chose à montrer — des postes
## ouverts et des ouvriers dessus. Une phase résolue les efface tous les deux, et l'image
## ne dirait plus rien de ce que `W2` ajoute.
func _scripted_open_phase() -> void:
	if _state().cycle().is_over():
		return
	if _state().cycle().permits(PhaseDef.ACTION_PLAY):
		_scripted_plays()
	if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		_scripted_staffing()
	_refresh_markers()

## Pose une carte de chaque nature qui trouve une cible : un bâtiment payable, puis les
## verbes. L'ordre compte — le chantier doit exister avant que *Construire* le vise.
func _scripted_plays() -> void:
	for card in _state().deck().hand().cards_in(CardData.POOL_BUILDING):
		if _play_scripted(card):
			break
	for card in _state().deck().hand().cards_in(CardData.POOL_ACTION):
		_play_scripted(card)

## Joue cette carte sur la première cible venue, du centre vers les bords. Vrai si elle
## est partie.
func _play_scripted(card: StringName) -> bool:
	for cell in _cells_from_the_middle():
		if RunManager.play(card, cell, _turns, _direction).is_ok():
			return true
	return false

## Remplit les actions posées, par le bouton lui-même.
##
## Elle recopiait la boucle « premier libre » jusqu'à `W2`. Passer par
## `RunManager.auto_staff()` la raccourcit à une ligne, et surtout fait entrer le chemin
## neuf du jalon dans le seul contrôle qui regarde l'écran — sans quoi ni le parsing, ni
## les tests, ni la capture n'auraient jamais emprunté le bouton.
func _scripted_staffing() -> void:
	RunManager.auto_staff()
	_refresh_markers()

## Les cellules de la carte, balayées **du centre vers les bords**.
##
## Le coin de la carte est exactement l'endroit que le rapport texte recouvre : une
## première capture de `D2` n'y montrait ni les bâtiments ni le jalon posé dessus.
## L'ordre reste totalement déterministe — à distance égale, le balayage en y puis en x
## départage.
func _cells_from_the_middle() -> Array[Vector2i]:
	var extent := _state().terrain().size()
	var middle := extent / 2
	var cells: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var near := (first - middle).length_squared()
		var far := (second - middle).length_squared()
		if near != far:
			return near < far
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	return cells
