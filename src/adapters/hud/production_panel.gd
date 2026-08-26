class_name ProductionPanel
extends PanelContainer
## Le compte rendu de la dernière phase résolue : ce qui est rentré, ce que le plafond a
## mangé, ce que la journée a coûté.
##
## Vue pure. On lui donne un `PhaseReport`, elle dessine. Elle ne calcule rien qu'une
## somme d'affichage et ne rejoue aucune règle : un rapport est déjà la réponse du
## domaine, il n'y a plus qu'à la lire.
##
## **Elle prend un `PhaseReport` et non un `ProductionReport`**, alors que le jalon
## s'appelle Économie, et c'est délibéré. `I1` a trouvé que le rapport de production
## compte comme oisif un ouvrier parti bâtir — il ne connaît que les postes de
## production, et les deux lectures sont « chacune juste dans leur système et fausses
## dans la phase ». Seul le rapport de phase voit les deux journaux de travail. Un
## panneau qui lirait le second réintroduirait exactement le mensonge que `I1` a
## diagnostiqué, et il le réintroduirait en grand, à l'écran.
##
## **La ligne d'upkeep n'apparaît que sur la phase qui ferme la journée.** On mange une
## fois par jour quel que soit le nombre de fois qu'on a récolté ; une ligne à zéro les
## autres phases se lirait comme un soir où personne n'a mangé, ce qui est une autre
## affirmation. Même raison qu'un `DayReport` nul plutôt que vide.
##
## Trois lignes ne s'affichent que si elles ont quelque chose à dire — la perte au
## plafond, les chantiers, l'upkeep. Ce n'est pas une économie de place : un panneau dont
## la ligne « perdu » n'existe que quand on a perdu se lit d'un coup d'œil, là où une
## ligne à zéro permanente devient du décor qu'on cesse de voir.
##
## **Elle ne nomme pas qui a franchi un palier**, et s'en tient au compte. Le faire
## demanderait le `Roster` pour traduire un identifiant en prénom, c'est-à-dire
## exactement la dépendance que `W2` existe pour porter : c'est lui qui tient la fiche
## d'unité et le panneau d'affectation. Le compte suffit à dire que la phase a fait
## progresser quelqu'un.
##
## Le libellé de la phase est un **argument** et non une lecture. Un `PhaseReport` porte
## l'identifiant de sa phase et non son libellé, et au moment où le signal arrive le
## cycle a déjà avancé — `RunManager.phase()` désigne la suivante. L'appelant, lui,
## connaît celle qu'il finit. Aucun nom de phase n'est donc écrit ici, ce que
## `DESIGN.md` 2 exige jusque dans les adapters.
##
## Construite en code, sans `.tscn`, comme `HandView` et `ResourceBar`.

## Écarts internes de la grille et du panneau.
const ROW_GAP := 4
const COLUMN_GAP := 14
const TITLE_GAP := 8

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.94)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 12

## Largeur minimale, pour que le panneau ne se rétrécisse pas d'un rapport à l'autre.
## Un cadre qui change de taille à chaque résolution attire l'œil pour rien.
const MIN_WIDTH := 300

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const KEY_COLOR := Color(0.62, 0.66, 0.72)
const VALUE_COLOR := Color(0.90, 0.91, 0.93)

## Ce que le plafond a fait perdre, et la famine. Même teinte que la réserve pleine sur
## la barre : c'est le même événement, vu un cran plus tard.
const WARN_COLOR := Color(0.95, 0.62, 0.35)

## Le badge de fin de journée.
const BADGE_COLOR := Color(0.60, 0.68, 0.85)

const TITLE_FONT_SIZE := 14
const ROW_FONT_SIZE := 12

const KEY_HARVEST := "Récolte"
const KEY_STORED := "En réserve"
const KEY_WASTED := "Perdu au plafond"
const KEY_WORK := "Travail"
const KEY_XP := "Progression"
const KEY_SITES := "Chantiers"
const KEY_UPKEEP := "Upkeep"

const BADGE_CLOSES := "fin de journée"
const BADGE_FAMINE := "famine"
const BADGE_DONE := "achevé"

var _palette: CommodityPalette
var _title: Label
var _badge: Label
var _rows: GridContainer

## Panneau prêt à être ajouté à l'arbre, vide et masqué.
static func create(palette: CommodityPalette) -> ProductionPanel:
	assert(palette != null, "panneau de production sans palette")
	var panel := ProductionPanel.new()
	panel.name = "ProductionPanel"
	panel._palette = palette
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.custom_minimum_size = Vector2(MIN_WIDTH, 0)
	# Les clics traversent, comme sur la barre : le curseur de cellule pioche sous la
	# souris à chaque image, et le panneau couvre un coin de la carte.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", TITLE_GAP)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", COLUMN_GAP)
	panel._title = panel._make_text("", TITLE_FONT_SIZE, TITLE_COLOR)
	header.add_child(panel._title)
	panel._badge = panel._make_text("", ROW_FONT_SIZE, BADGE_COLOR)
	header.add_child(panel._badge)
	column.add_child(header)

	panel._rows = GridContainer.new()
	panel._rows.columns = 2
	panel._rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._rows.add_theme_constant_override("v_separation", ROW_GAP)
	panel._rows.add_theme_constant_override("h_separation", COLUMN_GAP)
	column.add_child(panel._rows)

	panel.add_child(column)
	panel.clear()
	return panel

## Montre ce que cette phase a rendu. `phase_label` est le libellé de la phase qui vient
## de finir — voir l'en-tête du fichier pour la raison qu'il soit fourni.
func show_report(report: PhaseReport, phase_label: String) -> void:
	assert(report != null, "panneau de production sans rapport")
	visible = true
	_title.text = "Jour %d · %s" % [report.day(), phase_label]
	_badge.text = BADGE_CLOSES if report.closes_the_day() else ""
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_fill(report)

## Vide le panneau et le masque. L'état d'un run qui n'a encore rien résolu.
func clear() -> void:
	visible = false
	_title.text = ""
	_badge.text = ""
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

# --- Les lignes -------------------------------------------------------------------------

func _fill(report: PhaseReport) -> void:
	var production := report.production()
	_add_row(KEY_HARVEST, _palette.bundle_text(production.produced()), VALUE_COLOR)
	_add_row(KEY_STORED, _palette.bundle_text(production.stored()), VALUE_COLOR)
	if production.total_wasted() > 0:
		_add_row(KEY_WASTED, "%d — %s" % [production.total_wasted(),
			_palette.bundle_text(production.wasted())], WARN_COLOR)
	_add_row(KEY_WORK, "%d poste(s) tenu(s), %d oisif(s)"
		% [report.manned_count(), report.idle().size()], VALUE_COLOR)
	_add_row(KEY_XP, "%d XP, %d palier(s) de piste"
		% [report.progress().total_xp(), report.progress().skill_level_ups().size()],
		VALUE_COLOR)
	if not report.sites().is_empty():
		_add_row(KEY_SITES, _sites_text(report), VALUE_COLOR)
	if report.closes_the_day():
		_add_upkeep(report.day_report().upkeep())

## Les crans posés et la terre déplacée, dans l'ordre où l'orchestrateur les a appliqués.
##
## Un chantier mené à son dernier cran est signalé : c'est l'événement de la phase, et
## `PhaseReport` le rapporte plutôt que de le laisser deviner — le retrouver demanderait
## de comparer la ville d'avant à celle d'après.
func _sites_text(report: PhaseReport) -> String:
	var parts := PackedStringArray()
	var advances := report.sites().advances()
	for anchor in advances:
		parts.append("%s +%d cran(s)%s" % [anchor, advances[anchor],
			" ← %s" % BADGE_DONE if report.completed().has(anchor) else ""])
	var shifts := report.sites().shifts()
	for cell in shifts:
		parts.append("%s terrassé de %+d" % [cell, shifts[cell]])
	return ", ".join(parts)

func _add_upkeep(upkeep: UpkeepReport) -> void:
	var text := "%d dû, %d mangé" % [upkeep.due(), upkeep.consumed()]
	if upkeep.is_famine():
		text += "   ← %s, %d à jeun" % [BADGE_FAMINE, upkeep.unfed()]
	_add_row(KEY_UPKEEP, text, WARN_COLOR if upkeep.is_famine() else VALUE_COLOR)

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
