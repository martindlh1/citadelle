class_name DaySummaryView
extends MarginContainer
## Le bilan de la journée, lu au soir avant de la fermer.
##
## `DESIGN.md` 2 le demande à `P2b`, et c'est ce qui donne au soir sa seconde moitié : sans
## lui, la phase de fermeture est un clic. Ce qu'on y lit est ce que la journée a rendu —
## récolte, paliers, chantiers — et ce que la fermer va coûter.
##
## **Il tombe à l'entrée du soir et non après**, ce que 2. tranche en nommant l'échange :
## l'upkeep y est **dû** et non consommé, puisqu'il se prélève à la fermeture, et les deux
## ne diffèrent qu'en famine. Ce qu'on achète en retour est qu'aucun geste ne s'ajoute à la
## journée — **le bouton qui referme ce bilan est celui qui ferme la journée**.
##
## Vue pure, comme les six autres du HUD. On lui donne un `DaySummary` — immuable, composé
## par le domaine —, elle dessine. Elle n'additionne rien : le bilan arrive fait, et une vue
## qui sommerait des rapports serait le premier endroit où le chiffre de l'écran pourrait
## différer de celui du jeu.
##
## **Elle pose deux questions au domaine et affiche les réponses**, ce qui est le partage
## que `CLAUDE.md` écrit noir sur blanc. « La réserve paiera-t-elle l'upkeep ? » va au
## `Ledger` — la faute serait `if ledger.food < due`, pas l'appel — et le résultat teinte la
## ligne. C'est le précédent de `HandView` depuis `P1a`, sur la ligne qui compte le plus du
## soir : savoir qu'on va manquer **avant** de fermer est la seule chose qu'on puisse encore
## corriger.
##
## **Modale, donc `MOUSE_FILTER_STOP`**, comme `PileView` et `RunEndScreen`. Un clic sur le
## voile la referme sans fermer la journée : on veut pouvoir regarder le village avant de
## décider. Le bouton de pas en bas à droite continue d'annoncer « Finir la journée », donc
## rien ne se perd en la refermant.

## Le joueur veut fermer la journée. Le harnais en fait le même geste qu'`Entrée`.
signal close_requested()

## Un clic sur le voile : on veut regarder ce qu'on a bâti avant de fermer.
signal dismissed()

const VEIL_COLOR := Color(0.04, 0.05, 0.07, 0.74)

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.98)
const PANEL_RADIUS := 6
const PANEL_MARGIN := 24
const MIN_WIDTH := 400

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const KEY_COLOR := Color(0.62, 0.66, 0.72)
const VALUE_COLOR := Color(0.90, 0.91, 0.93)

## Ce qui fait mal. Le même orange que la famine, l'écrêtage et les pertes d'une vague :
## c'est la couleur de ce que le village perd, quelle qu'en soit la cause.
const WARN_COLOR := Color(0.95, 0.62, 0.35)

## Ce qui est allé mieux que prévu. Réservé aux paliers : c'est la seule bonne nouvelle
## qu'une journée puisse porter par elle-même.
const GOOD_COLOR := Color(0.62, 0.85, 0.58)

const TITLE_FONT_SIZE := 22
const SUB_FONT_SIZE := 12
const ROW_FONT_SIZE := 13

const BLOCK_GAP := 12
const ROW_GAP := 5
const KEY_GAP := 24

const KEY_HARVEST := "Récolte"
const KEY_STORED := "Entré en réserve"
const KEY_WASTED := "Perdu au plafond"
const KEY_WORK := "Travail"
const KEY_XP := "Progression"
const KEY_SITES := "Chantiers"
const KEY_UPKEEP := "À nourrir ce soir"
const KEY_WAVE := "Cette nuit"

const NOTHING := "—"
const LABEL_CLOSE := "Finir la journée"
const HINT_DISMISS := "Clic à côté pour regarder le village."

## Ce que le titre ajoute sous le jour. Un bilan qui n'annoncerait pas combien de fois la
## journée a résolu se lirait pareil sous deux modèles de journée différents, et `I2b` a
## rendu ce nombre réglable.
const SUB_TEXT := "%d résolution(s) — ce que la journée a rendu"

var _palette: CommodityPalette
var _title: Label
var _sub: Label
var _rows: VBoxContainer

static func create(palette: CommodityPalette) -> DaySummaryView:
	assert(palette != null, "bilan de journée sans palette de ressources")
	var view := DaySummaryView.new()
	view.name = "DaySummaryView"
	view._palette = palette
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.visible = false

	var veil := ColorRect.new()
	veil.color = VEIL_COLOR
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(veil)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(centre)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	# Le panneau arrête la souris là où le voile la laisse passer : un clic à côté du bouton
	# mais dans le panneau ne doit pas refermer le bilan. Même frontière tenue par la
	# structure que l'enveloppe d'une carte de main depuis `P1a`.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = MIN_WIDTH
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)

	view._title = _make_line("", TITLE_FONT_SIZE, TITLE_COLOR)
	view._title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view._title)

	view._sub = _make_line("", SUB_FONT_SIZE, KEY_COLOR)
	view._sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view._sub)

	view._rows = VBoxContainer.new()
	view._rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view._rows.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(view._rows)

	var close := Button.new()
	close.text = LABEL_CLOSE
	# Pas de focus clavier : `Entrée` appartient au harnais et fait déjà ce geste. La règle
	# vient d'`AssignmentPanel` à `W2`, et elle compte double ici — ce bouton est
	# exactement celui qu'`Entrée` déclenche.
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	close.pressed.connect(view._on_close_pressed)
	column.add_child(close)

	var hint := _make_line(HINT_DISMISS, SUB_FONT_SIZE, KEY_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	panel.add_child(column)
	return view

## Montre ce bilan. `wave` est le libellé de la vague qui tombe cette nuit, ou "".
##
## Les lignes sont **reconstruites** à chaque ouverture plutôt que mises à jour sur place,
## et c'est ici le bon choix : une modale s'ouvre une fois par journée, et son contenu ne
## bouge pas tant qu'elle est ouverte — le soir ne résout rien. C'est l'inverse exact du
## panneau d'affectation, relu à chaque image, et la raison est la même dans les deux sens :
## on reconstruit ce qui est rare, on met à jour sur place ce qui est continu.
func show_summary(summary: DaySummary, ledger: Ledger, upkeep: StringName,
		wave: String) -> void:
	assert(summary != null, "bilan de journée sans bilan")
	assert(ledger != null, "bilan de journée sans réserve")
	assert(not upkeep.is_empty(), "bilan de journée sans ressource d'upkeep")
	_title.text = "Jour %d" % summary.day()
	_sub.text = SUB_TEXT % summary.resolutions()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_fill(summary, ledger, upkeep, wave)
	visible = true

## Referme le bilan sans fermer la journée.
func dismiss() -> void:
	visible = false

# --- Les lignes -------------------------------------------------------------------------

func _fill(summary: DaySummary, ledger: Ledger, upkeep: StringName,
		wave: String) -> void:
	_add_row(KEY_HARVEST, _bundle(summary.produced()), VALUE_COLOR)
	_add_row(KEY_STORED, _bundle(summary.stored()), VALUE_COLOR)
	if summary.total_wasted() > 0:
		_add_row(KEY_WASTED, "%d — %s" % [summary.total_wasted(),
			_palette.bundle_text(summary.wasted())], WARN_COLOR)
	_add_row(KEY_WORK, "%d poste(s) tenu(s)" % summary.manned(), VALUE_COLOR)
	_add_row(KEY_XP, _progress_text(summary), _progress_color(summary))
	if summary.advanced() > 0 or summary.shifted() > 0:
		_add_row(KEY_SITES, _sites_text(summary), VALUE_COLOR)
	_add_upkeep(summary, ledger, upkeep)
	if not wave.is_empty():
		_add_row(KEY_WAVE, wave, WARN_COLOR)

## Ce que la journée coûte à nourrir, et si la réserve suivra.
##
## **La question part au domaine**, comme le coût d'une carte depuis `P1a` : `can_afford()`
## répond, la vue teinte. Savoir qu'on va manquer avant d'avoir fermé est la seule chose de
## ce panneau sur laquelle on puisse encore agir — après, c'est une famine constatée.
## La ressource est **reçue** et jamais écrite ici : c'est un identifiant de contenu, et un
## `&"food"` dans une vue serait le nombre magique que les conventions refusent partout
## ailleurs. Elle vient de l'équilibrage, par le harnais.
func _add_upkeep(summary: DaySummary, ledger: Ledger, upkeep: StringName) -> void:
	var due := summary.upkeep_due()
	var bill: Dictionary[StringName, int] = {}
	bill[upkeep] = due
	var covered := due <= 0 or ledger.can_afford(bill)
	_add_row(KEY_UPKEEP, "%d" % due if covered else "%d — la réserve ne suit pas" % due,
		VALUE_COLOR if covered else WARN_COLOR)

func _progress_text(summary: DaySummary) -> String:
	var skills := summary.skill_level_ups().size()
	var levels := summary.worker_level_ups().size()
	return "%d XP, %d palier(s) de piste, %d niveau(x)" % [
		summary.total_xp(), skills, levels]

## Un palier franchi est la bonne nouvelle d'une journée : il se voit. Une journée sans
## palier reste neutre plutôt que grise — elle n'a rien raté.
func _progress_color(summary: DaySummary) -> Color:
	if summary.skill_level_ups().is_empty() and summary.worker_level_ups().is_empty():
		return VALUE_COLOR
	return GOOD_COLOR

func _sites_text(summary: DaySummary) -> String:
	var parts := PackedStringArray()
	if summary.advanced() > 0:
		parts.append("%d cran(s)" % summary.advanced())
	if not summary.completed().is_empty():
		parts.append("%d achevé(s)" % summary.completed().size())
	if summary.shifted() > 0:
		parts.append("%d terrassement(s)" % summary.shifted())
	return ", ".join(parts)

## Un lot de ressources, ou un tiret s'il est vide. Le tiret plutôt qu'une ligne absente :
## une journée qui n'a rien récolté est une information, et une ligne qui disparaîtrait
## ferait sauter les suivantes d'un cran d'une journée à l'autre.
func _bundle(bundle: Dictionary[StringName, int]) -> String:
	var text := _palette.bundle_text(bundle)
	return NOTHING if text.is_empty() else text

func _add_row(key: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", KEY_GAP)
	var label := _make_line(key, ROW_FONT_SIZE, KEY_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_make_line(value, ROW_FONT_SIZE, color))
	_rows.add_child(row)

## `AUTOWRAP_OFF`, et c'est la règle que `P2a` a élargie : un `Label` qui s'enroule déclare
## une largeur minimale minuscule, donc un conteneur qui distribue la lui donne et le coupe
## une lettre par ligne. Toutes les lignes d'ici portent des nombres.
static func _make_line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	return style

func _on_close_pressed() -> void:
	close_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismissed.emit()
		accept_event()
