extends Node
## Harnais de dev du HUD — jalon `E2` : la barre de ressources et le panneau de
## résolution, sur des états fabriqués.
##
## Le harnais Run montre les deux vues **en situation**, et c'est là qu'on vérifie
## qu'elles disent la vérité. Ce qu'il ne peut pas montrer, c'est à quoi elles ressemblent
## quand ça va mal : une réserve pleine qui gaspille, une famine, une journée qui ne se
## ferme pas. Un vrai run met une dizaine de journées à y arriver, et une capture ne sait
## pas attendre.
##
## Il **fabrique donc ses cas** au lieu de les jouer, comme le harnais Économie cherche le
## soir où l'économie casse au lieu de le mettre en scène. Chaque scène est un `Ledger` et
## un `PhaseReport` écrits à la main, et les deux vues les reçoivent sans savoir d'où ils
## viennent — ce qui est aussi le contrôle qu'elles ne lisent rien d'autre que ce qu'on
## leur donne : il n'y a **pas de run ouvert** derrière ce harnais.
##
## Aucun chiffre d'ici ne vaut équilibrage. Ce sont des cas d'affichage, choisis pour ce
## qu'ils mettent à l'épreuve : un débordement qui perd trois ressources à la fois, une
## famine, une phase du milieu de journée qui n'a donc pas de ligne d'upkeep, et une
## réserve vide où toutes les colonnes sont à zéro.
##
## Les commandes : Espace ou clic pour passer à la scène suivante, Retour arrière pour la
## précédente.

const REPORT_MARGIN := 16.0
const SCENE_GAP := 20
const TITLE_FONT_SIZE := 15
const NOTE_FONT_SIZE := 12

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const NOTE_COLOR := Color(0.62, 0.66, 0.72)

## Capacité de base des scènes, et ce qu'un entrepôt y ajoute.
const CAPACITY := 100
const WITH_WAREHOUSE := 200

## Un roster de scène. Les identifiants n'ont pas à exister : aucune vue ne les résout.
const CREW := 6

## Familles créditées par les scènes. Elles ne nomment rien de `data/` — une piste naît à
## l'usage, et un harnais d'affichage n'a pas à connaître celles du jeu.
const FAMILY := &"harvest"

## Les scènes, dans l'ordre. Chaque entrée est le nom d'une méthode qui monte la sienne.
const SCENES: Array[StringName] = [
	&"_a_plain_phase", &"_a_full_reserve", &"_a_famine", &"_a_mid_day_phase",
	&"_an_empty_reserve",
]

var _palette: CommodityPalette
var _bar: ResourceBar
var _panel: ProductionPanel
var _title: Label
var _note: Label

## Scène affichée, un rang dans SCENES.
var _scene := 0

func _ready() -> void:
	_palette = CommodityPalette.from_database()
	_bar = ResourceBar.create(_palette)
	_panel = ProductionPanel.create(_palette)
	_title = _make_text("", TITLE_FONT_SIZE, TITLE_COLOR)
	_note = _make_text("", NOTE_FONT_SIZE, NOTE_COLOR)
	add_child(_make_background())
	add_child(_make_column())
	_show_scene()
	_capture_if_asked()

func _unhandled_input(event: InputEvent) -> void:
	var forward := event.is_pressed() and not event.is_echo() \
		and (event is InputEventMouseButton or _is_key(event, KEY_SPACE))
	var backward := event.is_pressed() and not event.is_echo() \
		and _is_key(event, KEY_BACKSPACE)
	if not forward and not backward:
		return
	_scene = posmod(_scene + (1 if forward else -1), SCENES.size())
	_show_scene()
	get_viewport().set_input_as_handled()

func _is_key(event: InputEvent, code: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).keycode == code

func _show_scene() -> void:
	callv(SCENES[_scene], [])
	_note.text = "Scène %d/%d — Espace ou clic : suivante. Retour arrière : précédente." \
		% [_scene + 1, SCENES.size()]

# --- Les scènes ---------------------------------------------------------------------------

## Une phase ordinaire qui ferme la journée : tout rentre, tout le monde mange.
##
## La scène de référence — c'est celle contre laquelle les quatre autres se lisent.
func _a_plain_phase() -> void:
	_title.text = "Une phase ordinaire, fin de journée"
	_bar.show_ledger(_ledger({&"food": 24, &"wood": 31, &"stone": 12, &"ore": 3}),
		{&"wood": 6, &"food": -2})
	_panel.show_report(_report(
		{&"food": 4, &"wood": 6}, {&"food": 4, &"wood": 6},
		_sites({Vector2i(12, 9): 2}, {}), [Vector2i(12, 9)],
		_upkeep(6, 6, 0)), "Après-midi")

## La réserve est pleine, et trois ressources se partagent ce qui reste.
##
## Le cas que `E1` a créé en tranchant pour une réserve **commune** : ce qui déborde est
## réparti au prorata, donc la perte touche tout ce qu'on a récolté et pas la dernière
## ressource arrivée. La jauge est saturée, la ligne « perdu » apparaît, et le total
## passe à la teinte d'alerte.
func _a_full_reserve() -> void:
	_title.text = "Réserve pleine — la commune fait perdre au prorata"
	_bar.show_ledger(_ledger({&"food": 30, &"wood": 44, &"stone": 18, &"ore": 8}),
		{&"wood": 2, &"stone": 1})
	_panel.show_report(_report(
		{&"food": 5, &"wood": 9, &"stone": 4}, {&"wood": 2, &"stone": 1},
		SiteReport.empty(), [], _upkeep(6, 6, 0)), "Après-midi")

## La réserve n'a pas nourri tout le monde.
##
## `DESIGN.md` 3.3 : la famine se **constate**, elle ne punit pas encore. Le panneau dit
## donc combien n'ont pas mangé et s'arrête là — ce qu'il leur arrive appartient aux
## Effectifs, et la question est ouverte.
func _a_famine() -> void:
	_title.text = "Famine — le rapport constate, il ne punit pas"
	_bar.show_ledger(_ledger({&"wood": 12, &"stone": 5}), {&"food": -2})
	_panel.show_report(_report(
		{&"food": 2}, {&"food": 2}, SiteReport.empty(), [],
		_upkeep(6, 2, 4)), "Après-midi")

## Une phase du milieu de journée : elle produit et **ne mange pas**.
##
## La scène qui tient la règle de `I1` à l'écran. On mange une fois par jour quel que
## soit le nombre de fois qu'on a récolté, donc pas de ligne d'upkeep et pas de badge de
## fin de journée. Une ligne à zéro se lirait comme un soir où personne n'a mangé.
func _a_mid_day_phase() -> void:
	_title.text = "Phase du matin — elle produit, elle ne mange pas"
	_bar.show_ledger(_ledger({&"food": 18, &"wood": 22, &"stone": 4}), {&"wood": 4})
	_panel.show_report(_report(
		{&"wood": 4}, {&"wood": 4},
		_sites({Vector2i(7, 3): 1}, {Vector2i(8, 4): -1}), []), "Matin")

## Une réserve vide, sur une capacité relevée par un entrepôt.
##
## Les quatre colonnes restent en place et se grisent, ce qui est la décision d'affichage
## de la barre : une ressource qui apparaîtrait le jour où l'on en gagne la première
## unité ferait glisser ses voisines sous l'œil.
func _an_empty_reserve() -> void:
	_title.text = "Réserve vide, capacité relevée par un entrepôt"
	_bar.show_ledger(_ledger({}, WITH_WAREHOUSE), {})
	_panel.clear()

# --- Les cas fabriqués ---------------------------------------------------------------------

func _ledger(stock: Dictionary[StringName, int], capacity := CAPACITY) -> Ledger:
	return Ledger.from_stock(stock, capacity)

## Un rapport de phase écrit à la main.
##
## Le journal de travail est fabriqué à la taille de l'équipe pour que `manned_count()` et
## `idle()` disent quelque chose : sans lui, toutes les scènes annonceraient « 0 poste
## tenu, 6 oisifs », ce qui n'exercerait pas la ligne.
func _report(produced: Dictionary[StringName, int], stored: Dictionary[StringName, int],
		sites: SiteReport, completed: Array[Vector2i],
		upkeep: UpkeepReport = null) -> PhaseReport:
	var lines: Array[WorkLine] = []
	for index in CREW - 1:
		lines.append(WorkLine.create(_worker(index), Vector2i(index, 0), FAMILY))
	var idle: Array[StringName] = [_worker(CREW - 1)]
	var day: DayReport = null
	if upkeep != null:
		day = DayReport.create(1, upkeep)
	return PhaseReport.create(1, &"scene",
		ProductionReport.create(produced, stored, lines, idle),
		sites, _progress(lines), idle, completed, day)

func _sites(advances: Dictionary[Vector2i, int],
		shifts: Dictionary[Vector2i, int]) -> SiteReport:
	var work: Array[WorkLine] = []
	return SiteReport.create(advances, shifts, work)

## Une progression plausible : un gain par ligne de travail, et un palier de piste.
##
## Les niveaux avant et après sont écrits à la main plutôt que calculés — le panneau ne
## lit qu'un compte, et faire tourner `SkillResolver` ici demanderait un roster et un
## équilibrage pour un chiffre qui s'affiche en toutes lettres.
func _progress(lines: Array[WorkLine]) -> ProgressReport:
	var gains: Array[SkillGain] = []
	for index in lines.size():
		var crossed := index == 0
		gains.append(SkillGain.create(lines[index].worker(), FAMILY, 4,
			0, 1 if crossed else 0, 0, 0))
	return ProgressReport.create(gains)

func _upkeep(due: int, consumed: int, unfed: int) -> UpkeepReport:
	return UpkeepReport.create(due, consumed, unfed)

func _worker(index: int) -> StringName:
	return StringName("ouvrier_%d" % (index + 1))

# --- La mise en place -----------------------------------------------------------------------

## Un fond opaque : ce harnais n'a pas de monde 3D, et les deux vues ont des fonds
## translucides qui ne se jugent que posés sur quelque chose.
func _make_background() -> ColorRect:
	var background := ColorRect.new()
	background.name = "Backdrop"
	background.color = DevWorld.SKY_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return background

## Les deux vues empilées, non pas dans deux coins mais l'une sous l'autre : ici on les
## compare d'une scène à l'autre, on ne joue pas.
func _make_column() -> MarginContainer:
	var slot := MarginContainer.new()
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		slot.add_theme_constant_override("margin_%s" % side, int(REPORT_MARGIN))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", SCENE_GAP)
	column.add_child(_title)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_panel)
	column.add_child(_note)
	slot.add_child(column)
	return slot

func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

# --- La capture ------------------------------------------------------------------------------

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-evenings n]
##
## `--shot-evenings` désigne ici la scène à capturer, en réutilisant le drapeau plutôt
## qu'en en inventant un : `DevShot` documente que les harnais ignorent ceux qui ne les
## concernent pas, et un neuvième drapeau pour « le n-ième cas » dirait la même chose.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	_scene = posmod(maxi(DevShot.argument(DevShot.SHOT_EVENINGS_FLAG).to_int(), 1) - 1,
		SCENES.size())
	_show_scene()
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[hud_harness] %s" % _title.text)
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[hud_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)
