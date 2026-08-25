extends Node
## Harnais de dev du système Cartes — jalon D2 : la main à l'écran, et ce qu'une carte
## jouée déclenche.
##
## Le rapport texte de D1 a disparu, remplacé par la scène. C'est exactement le geste que
## C2 a fait sur C1 : ce que D1 énumérait — les piles, la pioche, le remélange — se lit
## maintenant en jouant, ce qui est plus direct qu'un tableau. Le verdict statistique de
## D1 avait fait son travail et n'avait pas à être rejoué à chaque lancement.
##
## Ce que le harnais montre, et c'est tout le jalon : **jouer une carte n'affecte
## personne**. On prend une carte, les cibles s'allument, on la pose — et il ne se passe
## rien de plus tant qu'aucun ouvrier n'y est envoyé. La carte dit ce qu'on peut faire,
## les ouvriers disent combien on peut en faire, et ce sont deux gestes.
##
## Il ne décide rien. Il traduit un clic en appel de domaine et une réponse de domaine en
## couleur, comme le harnais Construction. Aucun « if » sur le terrain, la ville ou les
## ressources n'apparaît ici : la question se pose à ActionTargeting, l'écran affiche la
## réponse.
##
## Les touches : 1 à 9 prennent une carte, clic gauche la joue sur la case survolée, clic
## droit retire l'action posée là, Espace y envoie un ouvrier, Retour arrière les rappelle
## tous, Tab pivote un bâtiment, Entrée résout le soir. La caméra garde Q/E, la molette,
## WASD et R.
##
## Ce que le soir ne fait **pas encore** : exécuter *Construire* et *Terraformer*. Les
## deux se posent, s'affectent, et leurs ouvriers rentrent bredouilles — leur effet mute
## le CityState et la HeightGrid, donc l'état de deux autres systèmes, et c'est
## l'orchestrateur de I1 qui les appliquera. Le rapport le dit en toutes lettres plutôt
## que de laisser croire à une panne.

## Seed du run. Fixe : deux lancements doivent se comparer.
const SEED := 20260825

## Ouvriers du roster de démonstration. Assez pour qu'un poste reste vide quand on
## disperse, assez peu pour qu'on les suive de tête.
const GIVEN_NAMES: Array[String] = ["Ana", "Bo", "Cy", "Dov", "Ema", "Fen"]

## Bâtiments posés à l'ouverture, pour que *Récolter* en slot et *Construire* aient une
## cible dès la première image. Le dernier reste en chantier, exprès.
const SEEDED: Array[StringName] = [&"lumberjack_hut", &"farm", &"quarry"]

## Rendu quand aucune cellule ne convient.
const NO_CELL := Vector2i(-1, -1)

## Cartes que les touches 1 à 9 atteignent.
const SLOT_KEYS := 9

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13
const REPORT_OUTLINE_SIZE := 4

const CONTROLS := "1-9 : prendre une carte.   Clic gauche : jouer.   Clic droit : retirer l'action.   Espace : y envoyer un ouvrier.   Retour arr. : les rappeler.\nTab : pivoter un bâtiment.   Entrée : résoudre le soir.   Q/E : tourner la caméra.   Molette : zoom.   WASD : déplacer.   R : recadrer."

var _metrics: TerrainMetrics
var _world: DevWorld
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _targets: TargetHighlight
var _marker: ActionMarker
var _hand_view: HandView
var _label: Label

var _catalogue: CardCatalogue
var _deck: Deck
var _board: ActionBoard
var _roster: Roster
var _ledger: Ledger
var _rng: RandomNumberGenerator

var _deck_balance: DeckBalance
var _action_balance: ActionBalance
var _economy: EconomyBalance
var _workforce: WorkforceBalance

## Ouvrier -> action qu'il tient. Le brouillon dont DESIGN.md parle : l'UI le garde
## mutable et en fabrique une Assignment figée au moment de résoudre.
var _posted: Dictionary[StringName, int] = {}

var _held: StringName = &""
var _turns := 0
var _evening := 0
var _last_action := "Prendre une carte avec 1 à 9."
var _last_report := ""

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_deck_balance = balance.deck
	_action_balance = balance.actions
	_economy = balance.economy
	_workforce = balance.workforce
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	_grid = TerrainGen.generate(SEED, balance.terrain_gen.map_size, balance.terrain_gen)
	_terrain = _grid.to_query()
	_world = DevWorld.create(_grid, _metrics, balance)
	add_child(_world)

	_city = CityState.new()
	_seed_city()
	_renderer = BuildingRenderer.create(_city, _metrics)
	add_child(_renderer)
	_ghost = PlacementGhost.create(_metrics)
	add_child(_ghost)
	_targets = TargetHighlight.create(_metrics)
	add_child(_targets)
	_marker = ActionMarker.create(_metrics)
	add_child(_marker)

	_rng = _make_rng()
	_catalogue = _make_catalogue()
	_deck = _open_deck()
	_board = ActionBoard.new()
	_roster = _make_roster()
	_ledger = Ledger.from_stock(_economy.starting_stock, _economy.base_storage_cap)

	_hand_view = HandView.create(_catalogue)
	add_child(_hand_view)
	_label = _make_label()
	add_child(_label)

	_draw_phase()
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne —
## donc le fantôme et le rapport se refont à chaque image.
##
## Les **cibles**, elles, ne se recalculent pas ici : elles ne bougent qu'à un changement
## de carte, une pose ou une résolution, et les rafraîchir par image coûterait un
## balayage de carte soixante fois par seconde pour un résultat identique.
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
			_turns = posmod(_turns + 1, BuildingData.QUARTER_TURNS)
		KEY_SPACE:
			_staff_here()
		KEY_BACKSPACE:
			_unstaff_here()
		KEY_ENTER, KEY_KP_ENTER:
			_resolve_evening()
		_:
			var slot := event.keycode - KEY_1
			if slot < 0 or slot >= SLOT_KEYS:
				return
			_hold(slot)
	get_viewport().set_input_as_handled()

## Prend en main la carte de ce rang, ou la repose si elle y était déjà.
##
## Le rang suit Hand.cards(), le même ordre que HandView numérote. Reposer est utile :
## sans carte tenue les cibles s'éteignent, et c'est la seule façon de regarder la carte
## sans un voile dessus.
func _hold(slot: int) -> void:
	var cards := _deck.hand().cards()
	if slot >= cards.size():
		_last_action = "Aucune carte au rang %d." % (slot + 1)
		return
	_held = &"" if cards[slot] == _held else cards[slot]
	_last_action = "Reposé." if _held.is_empty() else "En main : %s." % _label_of(_held)
	_refresh_targets()

## Joue la carte tenue sur la cellule survolée.
##
## Deux natures de carte, deux chemins, et l'asymétrie est le sujet. Une carte d'action
## **pose une action** que des ouvriers viendront tenir ; une carte de bâtiment **ouvre un
## chantier** et ne s'affecte pas — c'est *Construire* qui l'avancera, jouée dessus.
##
## Le harnais ne teste rien avant d'appeler : il rapporte ce qu'on lui répond, comme la
## pose du harnais Construction. C'est ce qui garantit que l'écran et l'état ne divergent
## pas.
##
## Ce que ce chemin ne fait pas : payer. DESIGN.md 3.2 pose que « ai-je les 15 bois ? »
## est une seconde question, posée par la couche qui orchestre la journée — donc I1. Un
## bâtiment se pose ici gratuitement, et le rapport le dit.
func _play_here() -> void:
	var hovered := _world.cursor().hovered()
	if _held.is_empty():
		_last_action = "Aucune carte en main — 1 à 9 pour en prendre une."
		return
	if not hovered.is_hit():
		_last_action = "Rien sous le curseur."
		return
	if _catalogue.has(_held) and _catalogue.card(_held).places_a_building():
		_place_here(hovered.cell())
		return
	_post_here(hovered.cell())

func _post_here(cell: Vector2i) -> void:
	var verdict := _validate(_held, cell)
	var action := _board.post(_held, cell, _terrain, _city.to_snapshot(), _action_balance)
	if action == null:
		_last_action = "Refusé : %s en %s — %s" % [_label_of(_held), cell, verdict.reason()]
		return
	_deck.discard(_held)
	_last_action = "Posé : %s en %s, %d poste(s), 0 ouvrier." % [
		_label_of(_held), action.target(), action.capacity()]
	_release()

func _place_here(cell: Vector2i) -> void:
	var data := _building_of(_held)
	if data == null:
		_last_action = "Carte de bâtiment sans bâtiment : %s" % _held
		return
	var result := _city.place(_terrain, data, cell, _turns)
	if not result.is_ok():
		_last_action = "Refusé : %s en %s, %s — %s" % [
			data.id, cell, _orientation(_turns), result.reason()]
		return
	_deck.discard(_held)
	_renderer.rebuild(_city)
	_last_action = "Chantier ouvert : %s en %s, %s, %d cran(s) à poser (non payé — I1)." % [
		data.id, cell, _orientation(_turns), data.build_actions]
	_release()

## Retire l'action posée sous le curseur, la dernière si la cellule en porte plusieurs.
##
## Les ouvriers qui la tenaient sont rappelés ici, ce qui est un choix d'UI et non une
## règle : le domaine laisse très bien une affectation survivre à son action — le
## résolveur la saute et l'ouvrier chôme — mais laisser un ouvrier attaché à un numéro
## que plus rien ne porte serait une façon coûteuse de perdre une main-d'œuvre.
func _withdraw_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	_board.withdraw(action.id())
	for worker in _workers_on(action.id()):
		_posted.erase(worker)
	_last_action = "Retiré : %s en %s." % [_label_of(action.card()), action.target()]
	_refresh_targets()

## Envoie le premier ouvrier libre sur l'action sous le curseur.
##
## Le premier libre et non un choix : DESIGN.md 3.4 dit que **qui** l'on place est la
## décision de fond d'une phase, et un harnais ne tranchera pas comment on la présente —
## c'est le panneau d'affectation de W2. Ce qui se vérifie ici est la mécanique : une
## action se remplit jusqu'à sa capacité, et pas au-delà.
func _staff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var held := _workers_on(action.id()).size()
	if held >= action.capacity():
		_last_action = "%s en %s : %d poste(s), tous pris." % [
			_label_of(action.card()), action.target(), action.capacity()]
		return
	var free := _first_free_worker()
	if free.is_empty():
		_last_action = "Plus aucun ouvrier libre — %d au travail." % _posted.size()
		return
	_posted[free] = action.id()
	_last_action = "%s -> %s en %s (%d/%d)." % [
		_name_of(free), _label_of(action.card()), action.target(),
		held + 1, action.capacity()]
	_marker.rebuild(_board.to_plan(), _assignment(), _terrain)

## Rappelle tous les ouvriers de l'action sous le curseur.
func _unstaff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var recalled := _workers_on(action.id())
	for worker in recalled:
		_posted.erase(worker)
	_last_action = "%d ouvrier(s) rappelé(s) de %s." % [
		recalled.size(), _label_of(action.card())]
	_marker.rebuild(_board.to_plan(), _assignment(), _terrain)

## Résout le soir, distribue l'XP, vide le board et repioche.
##
## C'est la séquence de DESIGN.md 2 réduite à ce qui existe : actions jouées, puis gain
## d'XP, puis rapport. L'événement, l'upkeep hors Économie et le combat viendront avec
## leurs systèmes ; l'ordre, lui, est déjà le bon.
##
## Défausser la main est un choix du **harnais** et non du domaine. DESIGN.md 3.5 garde
## ouvert le sort de la main non jouée, D1 s'est gardé de le trancher en n'offrant que
## des capacités, et ce n'est pas un harnais qui va décider à sa place — il lui fallait
## juste une phase suivante.
func _resolve_evening() -> void:
	var plan := _board.to_plan()
	var assign := _assignment()
	var report := ProductionResolver.resolve(_terrain, _city.to_snapshot(), plan, assign,
		_roster.to_labor(_workforce), _ledger, _economy, _action_balance)
	var progress := SkillResolver.award(_roster, report, _workforce)
	_evening += 1
	_last_report = _evening_text(plan, report, progress)
	_board.clear()
	_posted.clear()
	_deck.discard_hand()
	_draw_phase()
	_last_action = "Soir %d résolu." % _evening

## Pioche la main de la phase, dans les trois pools, aux tailles de data/balance/.
func _draw_phase() -> void:
	for pool in CardData.POOLS:
		_deck.draw(pool, _hand_size(pool), _rng)
	_release()

## Repose la carte tenue et rafraîchit ce qui en dépend.
func _release() -> void:
	_held = &""
	_refresh_targets()

## Recalcule le jeu de cibles de la carte tenue, et redessine les jalons.
##
## Un balayage complet de la carte, et il n'a lieu qu'ici : à une prise de carte, une
## pose, un retrait ou une résolution. C'est ce qui permet de montrer TOUTES les cibles
## plutôt que la seule case survolée, sans le payer soixante fois par seconde.
func _refresh_targets() -> void:
	_marker.rebuild(_board.to_plan(), _assignment(), _terrain)
	_hand_view.show_hand(_deck.hand(), _held)
	if _held.is_empty() or not ActionTargeting.handles(_held):
		_targets.clear()
		return
	var cells: Array[Vector2i] = []
	var heights := PackedInt32Array()
	var size := _terrain.size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if not _validate(_held, cell).is_ok():
				continue
			cells.append(cell)
			heights.append(_terrain.height_at(cell))
	_targets.show_targets(cells, heights)

## Montre ce que poserait une carte de bâtiment sous le curseur.
##
## La validation a lieu ICI et une seule fois, comme dans le harnais Construction : le
## fantôme et le rapport lisent le même résultat, et une couleur ne peut pas contredire
## sa propre légende.
func _refresh_ghost() -> void:
	var hovered := _world.cursor().hovered()
	var data := _building_of(_held)
	if not hovered.is_hit() or data == null:
		_ghost.clear()
		return
	var result := PlacementValidator.validate(_city, _terrain, data, hovered.cell(), _turns)
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), result)

func _validate(card: StringName, cell: Vector2i) -> TargetResult:
	return ActionTargeting.validate(card, cell, _terrain, _city.to_snapshot(),
		_board.to_plan(), _action_balance)

## L'affectation figée à partir du brouillon. C'est le geste que l'UI d'affectation de W2
## fera, et il est déjà à sa place : le domaine ne voit jamais le dictionnaire mutable.
func _assignment() -> Assignment:
	return Assignment.create(_posted)

## Dernière action posée sur la cellule survolée, ou null.
func _action_here() -> PlayedAction:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return null
	var here := _board.at_cell(hovered.cell())
	if here.is_empty():
		return null
	return here[here.size() - 1]

func _workers_on(action: int) -> Array[StringName]:
	var held: Array[StringName] = []
	for worker in _posted:
		if _posted[worker] == action:
			held.append(worker)
	return held

func _first_free_worker() -> StringName:
	for worker in _roster.present():
		if not _posted.has(worker.id()):
			return worker.id()
	return &""

# --- Le rapport ----------------------------------------------------------------------

func _report() -> String:
	var lines := PackedStringArray()
	lines.append("Cartes — seed %d, soir %d   |   réserve %d/%d   |   %d action(s) posée(s)"
		% [SEED, _evening + 1, _ledger.total(),
			ProductionResolver.capacity_for(_city.to_snapshot(), _economy), _board.count()])
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

func _piles_line() -> String:
	var parts := PackedStringArray()
	for pool in CardData.POOLS:
		parts.append("%s %d en main, %d pioche, %d défausse"
			% [pool, _deck.hand_size(pool), _deck.draw_size(pool),
				_deck.discard_size(pool)])
	return "Piles — %s" % "   |   ".join(parts)

func _board_lines() -> String:
	if _board.count() == 0:
		return "Actions posées : aucune. Prendre une carte et cliquer une cible."
	var lines := PackedStringArray()
	lines.append("Actions posées")
	for action in _board.to_plan().actions():
		var workers := _workers_on(action.id())
		var names := PackedStringArray()
		for worker in workers:
			names.append(_name_of(worker))
		lines.append("  #%-2d %-12s %-8s %s   %d/%d   %s" % [
			action.id(), _label_of(action.card()),
			"à cru" if action.is_bare() else "bâtiment", action.target(),
			workers.size(), action.capacity(),
			"— " + ", ".join(names) if not names.is_empty() else "—"])
	return "\n".join(lines)

func _roster_line() -> String:
	var free := PackedStringArray()
	for worker in _roster.present():
		if not _posted.has(worker.id()):
			free.append(worker.given_name())
	return "Roster : %d ouvriers, %d au travail, %d libre(s)%s" % [
		_roster.present_count(), _posted.size(), free.size(),
		"" if free.is_empty() else " — " + ", ".join(free)]

## Ce que le curseur désigne, et ce que la carte tenue y donnerait.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return "Survol : —"
	var cell := hovered.cell()
	var line := "Survol : (%d, %d)   h = %d   %s" % [
		cell.x, cell.y, hovered.height(), _grid.terrain_at(cell).id]
	var building := _city.building_at(cell)
	if building != null:
		line += "   |   %s : %s" % [building.data().id, _site_state(building)]
	if _held.is_empty():
		return line
	if _catalogue.has(_held) and _catalogue.card(_held).places_a_building():
		return "%s   ->   %s, %s" % [line, _label_of(_held), _orientation(_turns)]
	var verdict := _validate(_held, cell)
	return "%s   ->   %s : %s" % [line, _label_of(_held),
		"accepté, %d poste(s)" % verdict.capacity() if verdict.is_ok()
			else String(verdict.reason())]

## Le compte rendu du dernier soir résolu.
##
## Les ouvriers rentrés bredouilles sont nommés avec leur raison quand elle est connue —
## c'est là que se lit le périmètre de D2, et un « 2 oisifs » sec laisserait croire à une
## panne.
func _evening_text(plan: ActionPlan, report: ProductionReport,
		progress: ProgressReport) -> String:
	var lines := PackedStringArray()
	lines.append("Soir %d — %d action(s) jouée(s), %d poste(s) tenu(s)"
		% [_evening, plan.count(), report.work().size()])
	lines.append("  produit  %s" % _bundle(report.produced()))
	lines.append("  stocké   %s   perdu au plafond %d"
		% [_bundle(report.stored()), report.total_wasted()])
	lines.append("  upkeep   %d dû, %d mangé, %d à jeun%s"
		% [report.upkeep(), report.consumed(), report.unfed(),
			"   ← famine" if report.is_famine() else ""])
	lines.append("  XP       %d distribuée, %d palier(s) de piste"
		% [progress.total_xp(), progress.skill_level_ups().size()])
	var stalled := _stalled(plan)
	if not stalled.is_empty():
		lines.append("  en attente de I1 : %s — posées et affectées, sans effet ce soir."
			% ", ".join(stalled))
	return "\n".join(lines)

## Les verbes que le plan portait et que le soir n'exécute pas encore.
##
## Lu sur data/balance/ et non sur une liste de noms écrite ici : une carte qui ne tient
## aucun poste et qui ne se joue pas à cru ne produit rien, et c'est exactement le
## critère du résolveur.
func _stalled(plan: ActionPlan) -> PackedStringArray:
	var names := PackedStringArray()
	for action in plan.actions():
		var card := action.card()
		if _action_balance.works_a_slot(card) or _action_balance.is_bare_card(card):
			continue
		var label := _label_of(card)
		if not names.has(label):
			names.append(label)
	return names

## Un lot de ressources en clair, trié par identifiant.
##
## Trié parce que l'ordre d'un Dictionary suit les insertions, donc l'ordre où les
## actions ont produit : deux soirs identiques s'afficheraient différemment selon la
## carte jouée en premier. Et par sort_custom sur String, jamais par sort() — comparer
## deux StringName compare leurs pointeurs.
func _bundle(amounts: Dictionary[StringName, int]) -> String:
	if amounts.is_empty():
		return "—"
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

func _site_state(building: PlacedBuilding) -> String:
	if building.is_complete():
		return "achevé"
	return "chantier %d/%d" % [building.progress(), building.data().build_actions]

func _orientation(turns: int) -> String:
	return "%d/4" % posmod(turns, BuildingData.QUARTER_TURNS)

# --- La mise en place -----------------------------------------------------------------

## Pose quelques bâtiments pour que la première image ait de quoi jouer.
##
## Le dernier reste **en chantier**, ce qui donne à *Construire* une cible dès l'ouverture
## et met sous les yeux la distinction que C4 a écrite : un chantier n'offre aucun poste
## de production, mais il en offre un à qui vient le bâtir.
func _seed_city() -> void:
	for index in SEEDED.size():
		var data := GameDatabase.get_building(SEEDED[index])
		if data == null:
			continue
		var anchor := _first_accepted_anchor(data)
		if anchor == NO_CELL:
			continue
		_city.place(_terrain, data, anchor)
		if index == SEEDED.size() - 1:
			continue
		while _city.advance(anchor):
			pass

## La première ancre acceptée, balayée **du centre vers les bords**.
##
## Le harnais Construction balaye en x puis en y et pose tout près de (0, 0), ce qui lui
## va : il pose treize bâtiments et ils s'étalent. Ici il y en a trois, et le coin de la
## carte est exactement l'endroit que le rapport texte recouvre — une première capture
## n'a montré ni les bâtiments, ni le jalon posé dessus.
##
## L'ordre reste totalement déterministe : à distance égale, c'est le balayage en x puis
## en y qui départage.
func _first_accepted_anchor(data: BuildingData) -> Vector2i:
	for anchor in _cells_from_the_middle():
		if PlacementValidator.validate(_city, _terrain, data, anchor).is_ok():
			return anchor
	return NO_CELL

func _cells_from_the_middle() -> Array[Vector2i]:
	var size := _terrain.size()
	var middle := size / 2
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
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

## Un deck neuf, ses trois pools mélangés. C'est ce que RunOrchestrator fera à
## l'ouverture d'un run — create() ne mélange pas, exprès.
func _open_deck() -> Deck:
	var deck := Deck.create(_catalogue, _deck_balance.starting_deck)
	for pool in CardData.POOLS:
		deck.shuffle(pool, _rng)
	return deck

## Le catalogue, dans l'ordre trié que GameDatabase rend.
func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng

func _hand_size(pool: StringName) -> int:
	if not _deck_balance.hand_size.has(pool):
		return 0
	return _deck_balance.hand_size[pool]

func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label

func _name_of(worker: StringName) -> String:
	if not _roster.has(worker):
		return String(worker)
	return _roster.worker(worker).given_name()

## Le bâtiment que cette carte pose, ou null si ce n'en est pas une.
func _building_of(card: StringName) -> BuildingData:
	if card.is_empty() or not _catalogue.has(card):
		return null
	var data := _catalogue.card(card)
	if not data.places_a_building():
		return null
	return GameDatabase.get_building(data.building)

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-hover x,y]
##
## src/adapters/ n'est pas testé et les trois commandes de vérification ne regardent pas
## l'écran : cette capture est donc le contrôle principal du jalon, et non un supplément.
## Elle prend une carte et en pose une, sans quoi elle ne montrerait ni la surbrillance
## des cibles ni un jalon — c'est-à-dire rien de ce que D2 ajoute.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_grid.size() / 2))
	# Ce que Entrée ferait à la main, et sans lui rien n'emprunterait jamais le chemin de
	# résolution : un rapport de fin de soirée est du texte fabriqué à la main, donc
	# précisément ce que ni le parsing ni les tests ne regardent.
	for _evening_number in DevShot.argument(DevShot.SHOT_EVENINGS_FLAG).to_int():
		_scripted_opening()
		_resolve_evening()
	_scripted_opening()
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[deck_harness] %s" % _hover_line())
	print("[deck_harness] %s" % _board_lines())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[deck_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Ce qu'une main humaine ferait dans les cinq premières secondes : poser une carte sur
## la première cible venue, y envoyer un ouvrier, puis en reprendre une autre pour que les
## cibles restent allumées.
##
## Les deux gestes sont le sujet de D2 et doivent tous les deux figurer sur l'image : un
## jalon planté sur la carte, et le voile des cibles de la carte suivante. Une première
## capture n'avait ni l'un ni l'autre — c'est exactement ce qu'un contrôle par l'image
## attrape et qu'aucune des trois commandes ne dit.
func _scripted_opening() -> void:
	for card in _deck.hand().cards():
		if not ActionTargeting.handles(card) or not _deck.hand().has(card):
			continue
		var target := _first_target(card)
		if target == NO_CELL:
			continue
		_held = card
		_post_here(target)
		_staff(_board.to_plan().actions())
	_held = _first_playable_card()
	_refresh_targets()

## Remplit la dernière action posée, autant que les ouvriers libres le permettent.
##
## Jusqu'à sa capacité et pas au-delà : c'est la mécanique que la capture doit montrer,
## et la remplir à moitié ne dirait pas si le plafond tient.
func _staff(posted: Array[PlayedAction]) -> void:
	if posted.is_empty():
		return
	var action := posted[posted.size() - 1]
	while _workers_on(action.id()).size() < action.capacity():
		var free := _first_free_worker()
		if free.is_empty():
			return
		_posted[free] = action.id()

## La première cellule, du centre vers les bords, où cette carte se joue.
func _first_target(card: StringName) -> Vector2i:
	for cell in _cells_from_the_middle():
		if _validate(card, cell).is_ok():
			return cell
	return NO_CELL

## La première carte de la main qui a au moins une cible sur cette carte.
##
## Choisie sur ce critère et non par son nom : la main dépend du seed, et une capture qui
## exigerait une carte précise se viderait le jour où le deck de départ bouge — ce que
## DESIGN.md 3.5 annonce comme certain.
func _first_playable_card() -> StringName:
	for card in _deck.hand().cards():
		if ActionTargeting.handles(card) and _first_target(card) != NO_CELL:
			return card
	return &""

func _make_label() -> Label:
	var label := Label.new()
	label.name = "DeckReport"
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
