class_name RunEndScreen
extends MarginContainer
## Comment le run s'est terminé : le mot, la cause, le score et ses quatre termes.
##
## `DESIGN.md` 5 le demande à `P2a`, et sa raison tient en une observation de partie jouée :
## `I2` livrait le verdict **dans le pavé de texte du harnais**, à côté de l'aide au
## clavier. Une partie de quinze journées s'achevait donc sur une phrase qu'on pouvait
## manquer, au milieu de la seule zone de l'écran qu'on cesse de lire au bout de deux
## minutes.
##
## **La place lui était gardée depuis `I2` sans qu'on l'ait dit ainsi.** `EventBus` porte
## deux signaux distincts — `run_finished`, qui annonce qu'une partie est *jouée*, et
## `run_ended`, qui annonce qu'elle est *rangée* — et le commentaire qui les sépare écrit
## déjà la phrase : « un écran de fin vit entre les deux ». Le voici.
##
## Vue pure, comme les cinq autres du HUD. On lui donne un `RunOutcome` — immuable, qui ne
## référence aucun état du domaine —, elle dessine. Elle ne calcule pas le score : les
## quatre termes sont **à côté** du total dans le `RunOutcome` précisément pour qu'aucune
## vue n'ait à refaire l'addition, et une vue qui appliquerait le barème serait la faute
## que `CLAUDE.md` refuse en premier.
##
## **Modale, donc `MOUSE_FILTER_STOP` sur toute la surface**, comme `PileView` depuis `P1b`.
## Elle se referme d'un clic sur le voile — un run fini n'a plus de case à cliquer dessous,
## mais on veut pouvoir regarder le village qu'on laisse. Rien n'est perdu en la refermant :
## le bandeau garde le mot, et le bouton de pas garde « Relancer ».
##
## **Elle traduit la cause**, ce qui est le seul travail de domaine qu'elle fasse — et c'en
## est un d'adapter : `RunOutcome` rend `&"heart"`, l'écran en fait une phrase. Même partage
## que `staffing_refusal()` depuis `I1`. Le repli par défaut existe pour qu'une quatrième
## cause, le jour où il y en aura une, se lise plutôt que de disparaître.

## Le joueur veut ouvrir un run neuf.
signal restart_requested()

## Un clic sur le voile : on veut regarder ce qu'on laisse.
signal dismissed()

const VEIL_COLOR := Color(0.04, 0.05, 0.07, 0.78)

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.98)
const PANEL_RADIUS := 6
const PANEL_MARGIN := 26
const MIN_WIDTH := 380

## La victoire et la défaite ne portent pas la même couleur, et c'est le seul endroit du
## HUD où l'orange ne veut pas dire « attention » mais « c'est fini ». Il n'y a rien à
## corriger sur cet écran, donc rien à alarmer.
const WIN_COLOR := Color(0.62, 0.85, 0.58)
const LOSS_COLOR := Color(0.92, 0.55, 0.45)

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const KEY_COLOR := Color(0.62, 0.66, 0.72)
const VALUE_COLOR := Color(0.90, 0.91, 0.93)

const VERDICT_FONT_SIZE := 34
const SCORE_FONT_SIZE := 22
const ROW_FONT_SIZE := 13

const BLOCK_GAP := 14
const ROW_GAP := 4

const WORD_WIN := "Victoire"
const WORD_LOSS := "Défaite"

const KEY_RESERVE := "En réserve"
const KEY_BUILDINGS := "Bâtiments debout"
const KEY_WORKERS := "Ouvriers vivants"
const KEY_LEVELS := "Niveaux cumulés"

const LABEL_RESTART := "Relancer"
const HINT_DISMISS := "Clic à côté pour regarder le village."

var _verdict: Label
var _cause: Label
var _score: Label
var _values: Dictionary[StringName, Label] = {}
var _seed: Label

static func create() -> RunEndScreen:
	var view := RunEndScreen.new()
	view.name = "RunEndScreen"
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
	# Le panneau **arrête** la souris là où le voile la laisse passer : un clic sur le
	# bouton ne doit pas aussi refermer l'écran, et un clic à côté du bouton mais dans le
	# panneau ne doit rien faire du tout. C'est la même frontière que l'enveloppe d'une
	# carte de main depuis `P1a`, tenue par la structure et non par un test.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = MIN_WIDTH
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)

	view._verdict = _make_line("", VERDICT_FONT_SIZE, TITLE_COLOR)
	view._verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view._verdict)

	view._cause = _make_line("", ROW_FONT_SIZE, KEY_COLOR)
	view._cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view._cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(view._cause)

	view._score = _make_line("", SCORE_FONT_SIZE, TITLE_COLOR)
	view._score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view._score)

	var terms := VBoxContainer.new()
	terms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terms.add_theme_constant_override("separation", ROW_GAP)
	for key in [KEY_RESERVE, KEY_BUILDINGS, KEY_WORKERS, KEY_LEVELS]:
		terms.add_child(view._make_term(key))
	column.add_child(terms)

	view._seed = _make_line("", ROW_FONT_SIZE, KEY_COLOR)
	view._seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view._seed)

	var restart := Button.new()
	restart.text = LABEL_RESTART
	# Pas de focus clavier, pour la raison que `AssignmentPanel` a écrite à `W2` : `Entrée`
	# appartient au harnais, et un bouton focalisé la rejouerait à la touche suivante.
	restart.focus_mode = Control.FOCUS_NONE
	restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	restart.pressed.connect(view._on_restart_pressed)
	column.add_child(restart)

	var hint := _make_line(HINT_DISMISS, ROW_FONT_SIZE, KEY_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	panel.add_child(column)
	return view

## Montre cette fin. Le seed est **fourni** plutôt que lu sur le run : celui-ci est fini et
## `RunManager` peut déjà l'avoir rangé, ce qui est exactement le trou entre les deux
## signaux où cet écran vit.
func show_outcome(outcome: RunOutcome, run_seed: int) -> void:
	assert(outcome != null, "écran de fin sans issue")
	var won := outcome.is_victory()
	_verdict.text = WORD_WIN if won else WORD_LOSS
	_verdict.add_theme_color_override("font_color", WIN_COLOR if won else LOSS_COLOR)
	_cause.text = "%s  ·  jour %d" % [_cause_of(outcome), outcome.day()]
	_score.text = "Score %d" % outcome.score()
	_values[StringName(KEY_RESERVE)].text = "%d" % outcome.resources()
	_values[StringName(KEY_BUILDINGS)].text = "%d" % outcome.buildings()
	_values[StringName(KEY_WORKERS)].text = "%d" % outcome.workers()
	_values[StringName(KEY_LEVELS)].text = "%d" % outcome.levels()
	_seed.text = "seed %d" % run_seed
	visible = true

## Referme l'écran sans rien décider d'autre. Le run reste fini ; c'est le harnais qui
## décide s'il en ouvre un neuf.
func dismiss() -> void:
	visible = false

## Pourquoi le run s'est arrêté, en clair.
func _cause_of(outcome: RunOutcome) -> String:
	match outcome.cause():
		RunOutcome.CAUSE_SURVIVED:
			return "La dernière journée est passée, le village tient debout."
		RunOutcome.CAUSE_HEART:
			return "Le Cœur est tombé."
		RunOutcome.CAUSE_ROSTER:
			return "Il ne reste plus personne au village."
	return "Fin : %s." % outcome.cause()

## Une ligne « intitulé … valeur », dont la valeur est retenue pour être mise à jour.
func _make_term(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_line(key, ROW_FONT_SIZE, KEY_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := _make_line("0", ROW_FONT_SIZE, VALUE_COLOR)
	row.add_child(value)
	_values[StringName(key)] = value
	return row

## `AUTOWRAP_OFF` par défaut, et c'est la leçon de `P1a` : un `Label` en
## `AUTOWRAP_WORD_SMART` coupe aussi ce qui n'a pas d'espace, donc un score de 307 se
## dessinerait « 30 » au-dessus de « 7 » — lisible et faux. Seule la cause, qui est une
## phrase, y déroge et le demande explicitement.
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

func _on_restart_pressed() -> void:
	restart_requested.emit()

## Refermer d'un clic sur le voile. Le panneau, lui, arrête la souris : on ne referme pas
## en visant le bouton et en le manquant de trois pixels.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismissed.emit()
		accept_event()
