class_name BattlePanel
extends PanelContainer
## La vague : celle qui attend, puis ce qu'elle a coûté.
##
## Vue pure, comme `ProductionPanel` et pour les mêmes raisons. On lui donne des chiffres
## déjà calculés par le domaine, elle dessine. Elle ne rejoue aucune règle : « que casse
## cette vague ? » se demande au Combat, et le seul travail de ce fichier est de rendre la
## réponse regardable.
##
## **Elle a deux états, et c'est tout son intérêt.** `DESIGN.md` 3.8 fait de l'attente
## d'une bataille un **état du run** et non un instant : entre la fermeture d'une journée
## et l'ouverture de la suivante, le cycle refuse d'avancer. Il y a donc un moment où le
## joueur regarde une vague qui n'est pas encore tombée, et un moment où il regarde la
## facture. Un panneau qui n'aurait montré que le second aurait effacé la moitié que ce
## jalon vient d'écrire.
##
## Le bouton est là pour la même raison. `F2` fera de ce moment un déploiement puis une
## bataille au tour par tour ; en attendant, « tenir la ligne » reste **un geste** qu'on
## pose, et non une conséquence automatique d'avoir fini sa journée. La coupure de
## `end_phase()` n'aurait aucun sens à l'écran si l'écran la franchissait tout seul.
##
## Elle porte donc `MOUSE_FILTER_STOP`, à l'inverse des deux vues de lecture du HUD : on
## clique dessus, et le clic ne doit pas atteindre la case cachée dessous. Même partage
## qu'`AssignmentPanel` depuis `W2`.
##
## **Elle ne traduit aucun identifiant.** Les prénoms des morts lui sont **fournis** : les
## retrouver demanderait le `Roster`, c'est-à-dire la dépendance que `ProductionPanel`
## refuse depuis `E2`. Et ces prénoms comptent — « morts : Brenne, Cadoc » est la phrase
## que ce jeu raconte —, donc ils entrent par la porte plutôt que par un raccourci.
##
## Construite en code, sans `.tscn`, comme les trois autres vues du HUD.

## Le joueur veut mener la bataille qui attend.
signal battle_requested()

const ROW_GAP := 4
const COLUMN_GAP := 14
const TITLE_GAP := 8

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.94)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 12
const MIN_WIDTH := 300

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const KEY_COLOR := Color(0.62, 0.66, 0.72)
const VALUE_COLOR := Color(0.90, 0.91, 0.93)

## Ce qui fait mal. Même teinte que l'écrêtage et la famine sur `ProductionPanel` : c'est
## la couleur de ce que le village perd, quelle qu'en soit la cause.
const WARN_COLOR := Color(0.95, 0.62, 0.35)

## Ce qui tient. La vague contenue est la seule bonne nouvelle du panneau.
const HELD_COLOR := Color(0.55, 0.80, 0.60)

const TITLE_FONT_SIZE := 14
const ROW_FONT_SIZE := 12

const KEY_ASSAULT := "Puissance"
const KEY_LINE := "La ligne"
const KEY_BREACH := "Brèche"
const KEY_WALLS := "Les murs"
const KEY_FALLEN := "Pertes"
const KEY_PLUNDER := "Pillé"
const KEY_XP := "Progression"

const BADGE_WAITING := "en approche"
const BADGE_HELD := "contenue"
const LABEL_FIGHT := "Tenir la ligne"

## Morts nommés avant de compter le reste.
##
## La leçon de `W2` : « une liste qui suit la partie se borne ». Un HUD a une hauteur fixe,
## une vague peut emporter tout un roster, et une liste sans plafond finit dehors.
const NAMED_LOSSES := 4

var _title: Label
var _badge: Label
var _rows: GridContainer
var _button: Button

## Panneau prêt à être ajouté à l'arbre, vide et masqué.
static func create() -> BattlePanel:
	var panel := BattlePanel.new()
	panel.name = "BattlePanel"
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.custom_minimum_size = Vector2(MIN_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", TITLE_GAP)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", COLUMN_GAP)
	panel._title = panel._make_text("", TITLE_FONT_SIZE, TITLE_COLOR)
	header.add_child(panel._title)
	panel._badge = panel._make_text("", ROW_FONT_SIZE, WARN_COLOR)
	header.add_child(panel._badge)
	column.add_child(header)

	panel._rows = GridContainer.new()
	panel._rows.columns = 2
	panel._rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._rows.add_theme_constant_override("v_separation", ROW_GAP)
	panel._rows.add_theme_constant_override("h_separation", COLUMN_GAP)
	column.add_child(panel._rows)

	panel._button = Button.new()
	panel._button.text = LABEL_FIGHT
	panel._button.pressed.connect(panel._on_fight_pressed)
	column.add_child(panel._button)

	panel.add_child(column)
	panel.clear()
	return panel

## Montre la vague qui attend, et ce qu'on lui oppose.
##
## `defense` et `deployed` viennent du domaine — `InstantCombatResolver` répond aux deux —
## et non d'un calcul fait ici : un panneau qui additionnerait des points de défense serait
## une seconde règle de combat, et celle qui s'afficherait ne serait pas celle qui frappe.
func show_pending(wave: WaveDef, day: int, defense: int, deployed: int) -> void:
	assert(wave != null, "panneau de bataille sans vague")
	visible = true
	_button.visible = true
	_title.text = "Jour %d · %s" % [day, wave.label]
	_badge.text = BADGE_WAITING
	_badge.add_theme_color_override("font_color", WARN_COLOR)
	_clear_rows()
	_add_row(KEY_ASSAULT, str(wave.power), WARN_COLOR)
	_add_row(KEY_LINE, "%d engagé(s), %d de défense" % [deployed, defense], VALUE_COLOR)

## Montre ce que la vague a coûté. `names` sont les prénoms des morts, dans l'ordre du
## déploiement — voir l'en-tête du fichier pour la raison qu'ils soient fournis.
func show_report(report: BattleReport, wave_label: String, day: int,
		names: PackedStringArray) -> void:
	assert(report != null, "panneau de bataille sans rapport")
	visible = true
	_button.visible = false
	var damage := report.damage()
	_title.text = "Jour %d · %s" % [day, wave_label]
	_badge.text = BADGE_HELD if report.is_held() else ""
	_badge.add_theme_color_override("font_color", HELD_COLOR)
	_clear_rows()
	_add_row(KEY_ASSAULT, "%d contre %d de défense"
		% [damage.assault(), damage.defense()], VALUE_COLOR)
	if not report.is_held():
		_add_row(KEY_BREACH, str(damage.breach()), WARN_COLOR)
	if not damage.damaged().is_empty():
		_add_row(KEY_WALLS, _walls_text(damage), WARN_COLOR)
	if not names.is_empty():
		_add_row(KEY_FALLEN, _losses_text(names), WARN_COLOR)
	if report.total_plundered() > 0:
		_add_row(KEY_PLUNDER, "%d unité(s) de réserve" % report.total_plundered(),
			WARN_COLOR)
	_add_row(KEY_XP, "%d XP, %d palier(s) de piste"
		% [report.progress().total_xp(),
			report.progress().skill_level_ups().size()], VALUE_COLOR)

## Vide le panneau et le masque. L'état d'un run que rien n'assiège.
func clear() -> void:
	visible = false
	_button.visible = false
	_title.text = ""
	_badge.text = ""
	_clear_rows()

# --- Les lignes -------------------------------------------------------------------------

## Ce que les murs ont pris, et ce qu'il en reste.
##
## Les chantiers interrompus sont comptés à part alors qu'ils sont un sous-ensemble des
## détruits, et c'est ce que `DamageReport` sépare exprès : `DESIGN.md` 3.2 veut qu'« un
## chantier à moitié fini détruit la veille de la vague » soit une perte qui se raconte.
func _walls_text(damage: DamageReport) -> String:
	var parts := PackedStringArray()
	parts.append("%d frappé(s)" % damage.damaged().size())
	if not damage.destroyed().is_empty():
		parts.append("%d détruit(s)" % damage.destroyed().size())
	if not damage.interrupted().is_empty():
		parts.append("dont %d chantier(s)" % damage.interrupted().size())
	return ", ".join(parts)

## Les morts, nommés puis comptés. Voir `NAMED_LOSSES`.
func _losses_text(names: PackedStringArray) -> String:
	if names.size() <= NAMED_LOSSES:
		return ", ".join(names)
	var shown := names.slice(0, NAMED_LOSSES)
	return "%s et %d autre(s)" % [", ".join(shown), names.size() - NAMED_LOSSES]

func _on_fight_pressed() -> void:
	battle_requested.emit()

func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

func _add_row(key: String, value: String, color: Color) -> void:
	_rows.add_child(_make_text(key, ROW_FONT_SIZE, KEY_COLOR))
	_rows.add_child(_make_text(value, ROW_FONT_SIZE, color))

func _make_text(text: String, size: int, color: Color) -> Label:
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
