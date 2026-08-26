class_name AssignmentPanel
extends PanelContainer
## Le panneau d'affectation : ce qui est posé, qui est là, et le bouton qui remplit le
## reste.
##
## C'est le morceau de `W2` que deux jalons ont annoncé sans l'écrire. `I1` : « le choix
## de *qui* l'on envoie — le harnais prend toujours le premier ouvrier libre. 3.4 dit que
## c'est la décision de fond d'une phase ; la présenter est `W2` ». `E2` : « ce qui reste
## en texte […] le plateau et le roster iront à `W2` ». Les deux tiennent ici, et les deux
## lignes de texte qu'ils décrivent disparaissent du harnais plutôt que de le doubler —
## un chiffre affiché à deux endroits est un chiffre qui finira par différer de lui-même.
##
## **Il montre les deux moitiés du geste ensemble**, et c'est tout le sujet. `D2` a fait
## de « jouer une carte » et « y envoyer des ouvriers » deux gestes distincts : les
## actions posées d'un côté, les fiches de l'autre, et l'on relie les deux d'un clic. Une
## liste d'ouvriers sans les postes, ou l'inverse, laisserait la décision se prendre de
## mémoire.
##
## Vue pure, et la règle vaut jusqu'au bout : elle ne **décide** d'aucune affectation.
## Elle signale un clic, le harnais appelle `RunManager.staff()`, et le domaine dit oui ou
## non — c'est `RunOrchestrator.staffing_refusal()` qui reste le seul juge des cinq refus.
## Le seul verdict qu'elle lit elle-même est celui de la phase courante, pour éteindre son
## bouton : `I1` a payé pour savoir qu'« un refus qui ne se nomme pas est indiscernable
## d'une panne », et un bouton éteint est la façon la moins chère de nommer celui-là.
##
## **Elle reçoit un `RunState`**, ce qu'aucune vue n'avait fait avant elle, et il faut
## dire pourquoi. Une affectation a besoin de trois choses à la fois — le plateau, le
## roster, et le brouillon qui les relie —, plus le relief et la ville pour savoir quelle
## piste chaque action créditera. `RunState` est le seul objet du projet qui les tienne
## ensemble, et c'est `DESIGN.md` 3.8 qui l'autorise à exister pour cette raison même. Les
## passer un par un aurait fait six arguments dont l'appelant devrait calculer le sixième.
## Le risque est connu et il est le même que celui de `ResourceBar` devant son `Ledger` :
## rien n'empêche techniquement une vue de muter ce qu'on lui montre, et rien ici ne le
## fait.
##
## Construite en code, sans `.tscn`, comme les trois vues de `E2`. Elle déménagera sous
## `scenes/ui/` quand `I2` fera un vrai écran, et elle déménagera avec sa mise en forme :
## elle n'a pas de règles à emporter.

## Une fiche vient d'être cliquée.
signal worker_picked(worker: StringName)

## Une action posée vient d'être cliquée.
signal action_picked(action: int)

## Le bouton d'auto-affectation vient d'être pressé.
signal auto_requested()

## Fiches par rangée. Trois tient dans la largeur qui reste à droite de la carte, et
## garde le panneau assez court pour ne pas monter dans le compte rendu de phase.
const CARD_COLUMNS := 3

## Lignes d'action affichées au plus, le reste étant compté sur une ligne.
##
## Une borne et non une place « qui devrait suffire ». La première capture de `W2` a
## montré ce qu'un panneau sans borne fait dans un HUD de taille fixe : il grandit avec le
## plateau jusqu'à recouvrir son voisin, et le défaut n'apparaît qu'à la phase la plus
## chargée — donc le plus tard possible. Quatre est ce que la hauteur laisse une fois le
## compte rendu de phase et la main servis ; au-delà, la ligne de reste le dit et les
## actions restent atteignables sur la carte, où Espace les affecte.
const MAX_ROWS := 4

## Ce que la ligne de reste annonce.
const MORE_TEXT := "… et %d autre(s), sur la carte."

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.94)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 10

const ROW_GAP := 3
const CARD_GAP := 5
const BLOCK_GAP := 6

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const COUNT_COLOR := Color(0.62, 0.66, 0.72)

## Une action dont tous les postes sont pris. Le même vert que le poste tenu d'une fiche :
## c'est le même fait, vu de l'autre côté.
const FULL_COLOR := Color(0.55, 0.82, 0.50)

## Une action à qui il manque du monde.
const HUNGRY_COLOR := Color(0.95, 0.62, 0.35)

const TITLE_FONT_SIZE := 14
const ROW_FONT_SIZE := 11

const TITLE := "Affectation"
const EMPTY_BOARD := "Aucune action posée — prendre une carte et cliquer une cible."
const AUTO_TEXT := "Auto"
const NO_ONE := "—"

## Marque d'un palier franchi, sur la fiche de celui qui l'a franchi.
const PROMOTED_MARK := "↑ "

var _catalogue: CardCatalogue

var _counts: Label
var _rows: VBoxContainer
var _more: Label
var _empty: Label
var _grid: GridContainer
var _auto: Button

## Rang de ligne -> action qu'elle porte. C'est par lui que le clic retrouve son numéro,
## les boutons de ligne étant recyclés d'une image à l'autre.
var _row_actions: Array[int] = []

## Les lignes d'action, réutilisées et non reconstruites.
var _row_buttons: Array[Button] = []

## Ouvrier -> sa fiche. Le roster ne rétrécit pas en cours de run, et rien ne le remplit
## non plus — le recrutement est l'`OUVERT` de `DESIGN.md` 3.4 —, mais la table grandit
## sans qu'on ait à le savoir.
var _cards: Dictionary[StringName, WorkerCard] = {}

## Ouvrier -> ce que la dernière résolution lui a fait franchir.
##
## Il vit jusqu'à la résolution **suivante**, qui le remplace — y compris par rien. C'est
## le même cycle que le delta de `ResourceBar`, et il s'entretient tout seul : aucune
## liste de gestes à énumérer, donc aucun geste à oublier.
var _notes: Dictionary[StringName, String] = {}

## Panneau prêt à être ajouté à l'arbre, vide.
static func create(catalogue: CardCatalogue) -> AssignmentPanel:
	assert(catalogue != null, "panneau d'affectation sans catalogue")
	var panel := AssignmentPanel.new()
	panel.name = "AssignmentPanel"
	panel._catalogue = catalogue
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)

	column.add_child(panel._make_header())

	panel._rows = VBoxContainer.new()
	panel._rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._rows.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(panel._rows)

	panel._more = _make_text("", ROW_FONT_SIZE, COUNT_COLOR)
	panel._more.visible = false
	column.add_child(panel._more)

	panel._empty = _make_text(EMPTY_BOARD, ROW_FONT_SIZE, COUNT_COLOR)
	column.add_child(panel._empty)

	panel._grid = GridContainer.new()
	panel._grid.columns = CARD_COLUMNS
	panel._grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._grid.add_theme_constant_override("v_separation", CARD_GAP)
	panel._grid.add_theme_constant_override("h_separation", CARD_GAP)
	column.add_child(panel._grid)

	panel.add_child(column)
	return panel

## Redessine le panneau. `held` est l'ouvrier sélectionné, ou &"" si aucun.
##
## Mise à jour sur place, appelable à chaque image : la règle que `E2` a écrite dans
## `CLAUDE.md`. Les lignes d'action sont recyclées et masquées plutôt que détruites, et
## les fiches ne naissent qu'une fois par ouvrier.
func show_state(state: RunState, held: StringName) -> void:
	assert(state != null, "panneau d'affectation sans run")
	var roster := state.roster()
	var assign := state.to_assignment()
	var places := Roster.capacity_for(state.city().to_snapshot(),
		state.balance().workforce)
	var free := state.free_workers().size()
	_counts.text = "%d au travail · %d libre(s) · %d/%d place(s)" % [
		assign.size(), free, roster.size(), places]

	_fill_rows(state, assign)
	_fill_cards(state, assign, held)
	_auto.disabled = not state.cycle().permits(PhaseDef.ACTION_ASSIGN)
	_auto.text = AUTO_TEXT if _auto.disabled else "%s (%d)" % [AUTO_TEXT, free]

## Retient qui vient de franchir un palier, pour l'annoncer sur sa fiche.
##
## `E2` a laissé cette dépendance ici en toutes lettres : `ProductionPanel` « ne nomme pas
## qui a franchi un palier » parce que le faire lui demanderait le `Roster`, « c'est-à-dire
## exactement la dépendance que `W2` existe pour porter ». Elle est portée — et elle l'est
## sur la **fiche de l'intéressé** plutôt que dans le compte rendu de récolte. Un palier
## appartient à la personne ; l'annoncer aux deux endroits rejouerait le doublon que `E2`
## a précisément défait.
func show_progress(report: ProgressReport) -> void:
	assert(report != null, "progression annoncée sans rapport")
	_notes.clear()
	for gain in report.gains():
		var parts := PackedStringArray()
		if gain.is_skill_level_up():
			parts.append("%s %d" % [String(gain.family()).capitalize(),
				gain.skill_level_after()])
		if gain.is_worker_level_up():
			parts.append("%s%d" % [WorkerCard.LEVEL_PREFIX, gain.worker_level_after()])
		if parts.is_empty():
			continue
		_notes[gain.worker()] = PROMOTED_MARK + " · ".join(parts)

# --- Les lignes d'action --------------------------------------------------------------

## Une ligne par action posée, dans l'ordre de pose — qui est aussi l'ordre dans lequel le
## bouton les sert. Ce que la ligne montre n'est donc pas décoratif : c'est la priorité que
## le joueur a exprimée en posant ses cartes.
##
## La **famille** y figure à côté du verbe, et c'est elle qui rend le classement lisible :
## sans elle, « pourquoi le bouton a-t-il envoyé Bo ici ? » n'a pas de réponse à l'écran.
## Elle est demandée au domaine, jamais devinée du nom de la carte.
func _fill_rows(state: RunState, assign: Assignment) -> void:
	var posted := state.board().to_plan().actions()
	var shown_count := mini(posted.size(), MAX_ROWS)
	_empty.visible = posted.is_empty()
	_rows.visible = not posted.is_empty()
	_row_actions.resize(shown_count)
	while _row_buttons.size() < shown_count:
		var button := _make_row(_row_buttons.size())
		_row_buttons.append(button)
		_rows.add_child(button)
	for index in _row_buttons.size():
		var shown := index < shown_count
		_row_buttons[index].visible = shown
		if not shown:
			continue
		var action := posted[index]
		_row_actions[index] = action.id()
		_row_buttons[index].text = _row_text(state, action, assign)
		_row_buttons[index].add_theme_color_override("font_color",
			_row_color(action, assign))
	_more.visible = posted.size() > shown_count
	if _more.visible:
		_more.text = MORE_TEXT % (posted.size() - shown_count)

func _row_text(state: RunState, action: PlayedAction, assign: Assignment) -> String:
	var held := assign.workers_on(action.id())
	var names := PackedStringArray()
	for worker in held:
		names.append(_name_of(state, worker))
	var family := StaffingAdvisor.family_of(action, state.terrain(),
		state.city().to_snapshot(), state.balance().actions)
	return "%s · %s · %s%d/%d · %s" % [_label_of(action.card()),
		String(family).capitalize() if not family.is_empty() else NO_ONE,
		action.target(), held.size(), action.capacity(),
		", ".join(names) if not names.is_empty() else NO_ONE]

## Vert quand les postes sont tenus, orange quand il en manque. C'est la seule chose que
## le panneau juge, et ce n'est pas une règle : c'est une soustraction.
func _row_color(action: PlayedAction, assign: Assignment) -> Color:
	if StaffingAdvisor.room_on(action, assign) > 0:
		return HUNGRY_COLOR
	return FULL_COLOR

# --- Les fiches ---------------------------------------------------------------------------

## Les fiches dans l'ordre du roster, absents compris.
##
## Un absent reste affiché, grisé, et c'est délibéré : `DESIGN.md` 3.9 veut qu'on sache
## qu'il existe et qu'il reviendra. Le retirer de l'écran le confondrait avec un mort.
func _fill_cards(state: RunState, assign: Assignment, held: StringName) -> void:
	for worker in state.roster().workers():
		var id := worker.id()
		if not _cards.has(id):
			var card := WorkerCard.create(state.balance().workforce)
			card.picked.connect(_on_card_picked.bind(id))
			_cards[id] = card
			_grid.add_child(card)
		var note: String = _notes.get(id, "")
		_cards[id].show_worker(worker, _job_of(state, assign, id), note, id == held)

## Ce que cet ouvrier tient, en clair. Vide s'il ne tient rien.
func _job_of(state: RunState, assign: Assignment, worker: StringName) -> String:
	if not assign.is_assigned(worker):
		return ""
	var action := state.board().at(assign.action_of(worker))
	if action == null:
		return ""
	return "%s %s" % [_label_of(action.card()), action.target()]

func _name_of(state: RunState, worker: StringName) -> String:
	if not state.roster().has(worker):
		return String(worker)
	return state.roster().worker(worker).given_name()

func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label

# --- Les clics ------------------------------------------------------------------------------

func _on_card_picked(worker: StringName) -> void:
	worker_picked.emit(worker)

func _on_row_pressed(index: int) -> void:
	if index >= _row_actions.size():
		return
	action_picked.emit(_row_actions[index])

# --- La mise en place -------------------------------------------------------------------------

func _make_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", BLOCK_GAP)
	header.add_child(_make_text(TITLE, TITLE_FONT_SIZE, TITLE_COLOR))
	_counts = _make_text("", ROW_FONT_SIZE, COUNT_COLOR)
	_counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_counts)
	_auto = Button.new()
	_auto.text = AUTO_TEXT
	_auto.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	_auto.pressed.connect(_on_auto_pressed)
	header.add_child(_auto)
	return header

func _on_auto_pressed() -> void:
	auto_requested.emit()

## Une ligne d'action est un bouton plat : il porte le survol et le clic sans qu'on ait à
## les écrire, et un bouton plat ne se distingue d'un libellé que quand la souris passe
## dessus — ce qui est exactement l'indication qu'on veut donner.
func _make_row(index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.pressed.connect(_on_row_pressed.bind(index))
	return button

static func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	return style
