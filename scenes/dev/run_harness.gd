extends Node
## Harnais de dev du système Run — jalon I1 : la boucle minimale.
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
##     creuse vraiment sous un terrassement. Le rapport du soir les nomme.
##
## Il ne décide rien. Il traduit un clic en appel de `RunManager` et une réponse en
## couleur, comme les harnais Construction et Cartes avant lui. Aucun « if » sur le
## terrain, la ville, la bourse ou la phase n'apparaît ici — la question se pose au
## domaine, l'écran affiche la réponse.
##
## Les commandes : une carte se prend au clavier — 1 à 9 — ou au clic dessus ; un clic
## gauche sur le sol la joue sur la case survolée, un clic droit retire l'action posée là,
## Espace y envoie un ouvrier, Retour arrière les rappelle tous, Tab pivote un bâtiment ou
## retourne un terrassement, **Entrée termine la phase**. La caméra garde Q/E, la molette,
## WASD et R.

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
Le travail Espace : y envoyer un ouvrier. Retour arrière : les rappeler. Entrée : finir la phase.
La caméra  Q/E : pivoter. Molette : zoomer. WASD : déplacer. R : recadrer."""

var _metrics: TerrainMetrics
var _world: DevWorld
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _targets: TargetHighlight
var _marker: ActionMarker
var _hand_view: HandView
var _label: Label

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
var _last_report := ""

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
	_label = _make_label()
	add_child(_label)

	EventBus.evening_resolved.connect(_on_evening_resolved)
	_refresh_targets()
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne — donc
## le fantôme et le rapport se refont à chaque image. Les cibles, elles, ne bougent qu'à un
## changement de carte, de sens, de pose ou de phase.
func _process(_delta: float) -> void:
	_refresh_ghost()
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
			_end_phase()
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
		_last_action = "Chantier ouvert : %s en %s, %s — payé %s." % [
			_label_of(held), result.anchor(), _orientation(), _bundle(result.paid())]
	_release()

func _withdraw_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	if not RunManager.withdraw(action.id()):
		_last_action = "Retrait refusé — %s ne le permet pas." % _phase_label()
		return
	_last_action = "Retiré : %s en %s." % [_label_of(action.card()), action.target()]
	_refresh_targets()

## Envoie le premier ouvrier libre sur l'action sous le curseur.
##
## Le premier libre et non un choix : `DESIGN.md` 3.4 dit que **qui** l'on place est la
## décision de fond d'une phase, et un harnais ne tranchera pas comment on la présente —
## c'est le panneau d'affectation de `W2`.
func _staff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var free := _state().free_workers()
	if free.is_empty():
		_last_action = "Plus aucun ouvrier libre."
		return
	if not RunManager.staff(free[0], action.id()):
		_last_action = "%s : refusé — %d/%d poste(s), %s." % [
			_label_of(action.card()), _state().staffed_on(action.id()).size(),
			action.capacity(), _phase_label()]
		return
	_last_action = "%s -> %s en %s (%d/%d)." % [
		_name_of(free[0]), _label_of(action.card()), action.target(),
		_state().staffed_on(action.id()).size(), action.capacity()]
	_refresh_markers()

func _unstaff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var recalled := RunManager.unstaff(action.id())
	_last_action = "%d ouvrier(s) rappelé(s) de %s." % [
		recalled.size(), _label_of(action.card())]
	_refresh_markers()

## Termine la phase. C'est `RunManager` qui décide si ça résout — le harnais ne connaît
## pas la journée, il la traverse.
func _end_phase() -> void:
	if _state().cycle().is_over():
		_last_action = "Run terminé."
		return
	var finished := _phase_label()
	RunManager.end_phase()
	_held_slot = NO_SLOT
	_refresh_targets()
	if _state().cycle().is_over():
		_last_action = "%s terminée — le run s'arrête là." % finished
		return
	_last_action = "%s terminée. Au tour de %s." % [finished, _phase_label()]

## Le seul endroit du harnais qui réagit à un signal plutôt qu'à une touche, et c'est ce
## que `I0` avait dessiné : le domaine retourne, `RunManager` publie, l'écran écoute.
func _on_evening_resolved(report: EveningReport) -> void:
	_last_report = _evening_text(report)
	# Le relief a pu bouger sous un terrassement, et la ville sous un chantier. Refaire
	# les deux plutôt que de deviner lequel : une soirée par jour, le coût est nul.
	_world.show_grid(_state().grid())
	_renderer.rebuild(_state().city())

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
	var data := _building_of(_held_card())
	if not hovered.is_hit() or data == null:
		_ghost.clear()
		return
	var result := PlacementValidator.validate(_state().city(), _state().terrain(), data,
		hovered.cell(), _turns)
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), result)

# --- Le rapport ------------------------------------------------------------------------

func _report() -> String:
	var lines := PackedStringArray()
	lines.append(_banner())
	lines.append("")
	lines.append(_piles_line())
	lines.append("")
	lines.append(_board_lines())
	lines.append("")
	lines.append(_roster_line())
	lines.append("")
	lines.append(_hover_line())
	lines.append(_last_action)
	if not _last_report.is_empty():
		lines.append("")
		lines.append(_last_report)
	lines.append("")
	lines.append(CONTROLS)
	return "\n".join(lines)

## Le bandeau de phase. Le libellé et les gestes viennent de la `PhaseDef`, jamais d'un
## nom écrit ici : c'est ce qui fera de l'arbitrage de `I2b` un échange de `.tres`.
func _banner() -> String:
	var cycle := _state().cycle()
	if cycle.is_over():
		return "Run terminé — %d jour(s) joués, seed %d." % [cycle.days(), SEED]
	return "Jour %d/%d   |   %s   |   réserve %d/%d   |   %s" % [
		cycle.day(), cycle.days(), _phase_label(), _state().ledger().total(),
		_state().ledger().capacity(), _permissions()]

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

func _piles_line() -> String:
	var parts := PackedStringArray()
	for pool in CardData.POOLS:
		parts.append("%s %d en main, %d pioche, %d défausse" % [pool,
			_state().deck().hand_size(pool), _state().deck().draw_size(pool),
			_state().deck().discard_size(pool)])
	return "Piles — %s" % "   |   ".join(parts)

func _board_lines() -> String:
	if _state().board().count() == 0:
		return "Actions posées : aucune. Prendre une carte et cliquer une cible."
	var lines := PackedStringArray()
	lines.append("Actions posées")
	for action in _state().board().to_plan().actions():
		var workers := _state().staffed_on(action.id())
		var names := PackedStringArray()
		for worker in workers:
			names.append(_name_of(worker))
		lines.append("  #%-2d %-12s %-8s %s%s   %d/%d   %s" % [
			action.id(), _label_of(action.card()),
			"à cru" if action.is_bare() else "bâtiment", action.target(),
			"" if not action.moves_ground() else (" %s" % _sense_of(action.direction())),
			workers.size(), action.capacity(),
			"— " + ", ".join(names) if not names.is_empty() else "—"])
	return "\n".join(lines)

func _roster_line() -> String:
	var free := PackedStringArray()
	for worker in _state().free_workers():
		free.append(_name_of(worker))
	var roster := _state().roster()
	return "Roster : %d ouvriers, %d au travail, %d libre(s)%s" % [
		roster.present_count(), _state().to_assignment().size(), free.size(),
		"" if free.is_empty() else " — " + ", ".join(free)]

## Ce que le curseur désigne, et ce que la carte tenue y ferait — coût compris.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return "Survol : —"
	var cell := hovered.cell()
	var line := "Survol : (%d, %d)   h = %d   %s" % [cell.x, cell.y, hovered.height(),
		_state().terrain().terrain_at(cell).id]
	var building := _state().city().building_at(cell)
	if building != null:
		line += "   |   %s : %s" % [building.data().id, _site_state(building)]
	var held := _held_card()
	if held.is_empty():
		return line
	var data := _building_of(held)
	if data != null:
		return "%s   ->   %s, %s, coût %s%s" % [line, _label_of(held), _orientation(),
			_bundle(data.cost),
			"" if _state().ledger().can_afford(data.cost) else "   ← réserve insuffisante"]
	var verdict := _validate(held, cell)
	return "%s   ->   %s : %s" % [line, _label_of(held),
		"accepté, %d poste(s)" % verdict.capacity() if verdict.is_ok()
			else String(verdict.reason())]

## Le compte rendu du dernier soir résolu.
##
## Il nomme ce que `D2` ne pouvait qu'annoncer : les crans posés, la terre déplacée, les
## chantiers achevés. Et il compte les oisifs sur le **rapport du soir** et non sur celui
## de la production, qui compterait un bâtisseur parmi eux.
func _evening_text(report: EveningReport) -> String:
	var production := report.production()
	var lines := PackedStringArray()
	lines.append("Jour %d, %s — %d poste(s) tenu(s), %d oisif(s)" % [report.day(),
		report.phase(), report.manned_count(), report.idle().size()])
	lines.append("  produit  %s" % _bundle(production.produced()))
	lines.append("  stocké   %s   perdu au plafond %d" % [_bundle(production.stored()),
		production.total_wasted()])
	lines.append("  upkeep   %d dû, %d mangé, %d à jeun%s" % [production.upkeep(),
		production.consumed(), production.unfed(),
		"   ← famine" if production.is_famine() else ""])
	lines.append("  XP       %d distribuée, %d palier(s) de piste" % [
		report.progress().total_xp(), report.progress().skill_level_ups().size()])
	lines.append("  chantiers %s" % _sites_text(report))
	return "\n".join(lines)

func _sites_text(report: EveningReport) -> String:
	var sites := report.sites()
	if sites.is_empty():
		return "—"
	var parts := PackedStringArray()
	var advances := sites.advances()
	for anchor in advances:
		parts.append("%s +%d cran(s)%s" % [anchor, advances[anchor],
			" ← achevé" if report.completed().has(anchor) else ""])
	var shifts := sites.shifts()
	for cell in shifts:
		parts.append("%s terrassé de %+d" % [cell, shifts[cell]])
	return ", ".join(parts)

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

## Le bâtiment que cette carte pose, ou null si ce n'en est pas une.
func _building_of(card: StringName) -> BuildingData:
	if card.is_empty() or not _state().catalogue().has(card):
		return null
	var data := _state().catalogue().card(card)
	if not data.places_a_building():
		return null
	return _state().building(data.building)

## Un lot de ressources en clair, trié par identifiant. Trié parce que l'ordre d'un
## Dictionary suit les insertions, et par sort_custom sur String, jamais par sort() —
## comparer deux StringName compare leurs pointeurs.
func _bundle(amounts: Dictionary[StringName, int]) -> String:
	if amounts.is_empty():
		return "gratuit"
	var ids: Array[StringName] = []
	ids.assign(amounts.keys())
	ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second))
	var parts := PackedStringArray()
	for id in ids:
		var commodity := GameDatabase.get_commodity(id)
		parts.append("%d %s" % [amounts[id],
			commodity.label if commodity != null else String(id)])
	return ", ".join(parts)

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

func _make_label() -> Label:
	var label := Label.new()
	label.name = "RunReport"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
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
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_state().grid().size() / 2))
	for _day in maxi(DevShot.argument(DevShot.SHOT_EVENINGS_FLAG).to_int(), 1):
		_scripted_day()
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[run_harness] %s" % _banner())
	print("[run_harness] %s" % _hover_line())
	print("[run_harness] %s" % _board_lines())
	print("[run_harness] %s" % _last_report)
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[run_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Une journée jouée comme une main humaine la jouerait : on pose ce qu'on peut, on
## envoie les ouvriers, on finit la journée.
##
## Elle s'arrête sur le nombre de phases de la journée et non sur un compte écrit ici :
## une journée de trois phases doit se jouer sans qu'une ligne bouge.
func _scripted_day() -> void:
	while not _state().cycle().is_over():
		if _state().cycle().permits(PhaseDef.ACTION_PLAY):
			_scripted_plays()
		if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
			_scripted_staffing()
		var resolved := _state().cycle().resolves()
		_end_phase()
		if resolved:
			return

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

## Remplit les actions posées avec les ouvriers libres, dans l'ordre.
func _scripted_staffing() -> void:
	for action in _state().board().to_plan().actions():
		while _state().staffed_on(action.id()).size() < action.capacity():
			var free := _state().free_workers()
			if free.is_empty():
				return
			if not RunManager.staff(free[0], action.id()):
				break
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
