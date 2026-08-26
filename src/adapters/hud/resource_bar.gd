class_name ResourceBar
extends PanelContainer
## La réserve à l'écran : ce qu'on possède, et la place qu'il reste.
##
## Vue pure. On lui donne un `Ledger`, elle dessine. Elle ne juge rien, ne convertit
## rien, n'écrête rien : « la réserve est-elle pleine ? » se demande au domaine, et cette
## classe affiche la réponse. Un adapter qui appellerait `set_capacity()` serait la faute
## d'architecture que `CLAUDE.md` refuse en premier — c'est l'orchestrateur qui la pose.
##
## **La jauge est unique et segmentée, et c'est le sujet.** `DESIGN.md` 3.3 : les cent
## unités sont partagées entre toutes les ressources, « remplir sa réserve de bois, c'est
## renoncer à stocker de la pierre ». Quatre jauges côte à côte auraient dessiné quatre
## plafonds indépendants, c'est-à-dire exactement la lecture que `E1` a écartée. Une seule
## barre où le bois qui monte pousse la place de la pierre est la décision de `E1` rendue
## regardable — et 3.3 dit qu'« un joueur qui ne la voit pas ne comprend pas pourquoi son
## entrepôt manque ».
##
## **Les quatre colonnes ne bougent jamais**, même à zéro. Une ressource qui
## apparaîtrait le jour où on en gagne la première unité ferait glisser ses voisines sous
## l'œil, et il faudrait relire la barre entière pour retrouver la nourriture. Un zéro se
## grise ; il ne disparaît pas.
##
## Les nœuds sont construits une fois et **mis à jour sur place** : `show_ledger()` ne
## reconstruit rien, ce qui la rend appelable à chaque image sans churn d'allocation. Le
## jeu de ressources ne change pas en cours de run — il vient du catalogue, pas de la
## partie.
##
## Construite en code, sans `.tscn`, comme `HandView`. Elle déménagera sous `scenes/ui/`
## le jour où `I2` fera un vrai écran, et elle déménagera avec sa mise en forme : elle
## n'a pas de règles à emporter.
##
## Les chiffres sont des constantes nommées et non de l'équilibrage — une largeur de
## jauge est de la mise en forme, et `data/balance/` est réservé aux questions ouvertes
## de `DESIGN.md`.

## Largeur de la jauge, en pixels. Le segment de chaque ressource s'y taille au prorata.
const GAUGE_WIDTH := 260
const GAUGE_HEIGHT := 12

## Largeur minimale d'un segment non vide, en pixels.
##
## Sans elle, une unité sur deux cents s'arrondit à zéro et la ressource disparaît de la
## jauge alors qu'on en possède. Le prorata est faux d'un pixel ; l'absence était fausse
## tout court.
const MIN_SEGMENT := 2

## Côté de la pastille de couleur d'une ressource.
const SWATCH := 10

## Écarts internes.
const CHIP_GAP := 6
const COLUMN_GAP := 18
const ROW_GAP := 6

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.92)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 10

## Fond de la place libre dans la jauge.
const FREE_COLOR := Color(0.22, 0.24, 0.28)

## Texte d'un libellé, d'une quantité, et d'une ressource qu'on ne possède pas.
const LABEL_COLOR := Color(0.68, 0.72, 0.78)
const AMOUNT_COLOR := Color(0.94, 0.94, 0.92)
const EMPTY_COLOR := Color(0.42, 0.45, 0.50)

## Réserve pleine. La même teinte que ce que le panneau appelle une perte : c'est le
## même événement vu d'un cran plus tôt.
const FULL_COLOR := Color(0.95, 0.62, 0.35)

## Un delta gagné, un delta perdu.
const GAIN_COLOR := Color(0.55, 0.82, 0.50)
const LOSS_COLOR := Color(0.90, 0.48, 0.45)

## Opacité d'une pastille dont la ressource est à zéro.
const EMPTY_SWATCH_ALPHA := 0.28

const LABEL_FONT_SIZE := 12
const AMOUNT_FONT_SIZE := 14
const TOTAL_FONT_SIZE := 12

var _palette: CommodityPalette

var _names: Dictionary[StringName, Label] = {}
var _amounts: Dictionary[StringName, Label] = {}
var _deltas: Dictionary[StringName, Label] = {}
var _swatches: Dictionary[StringName, ColorRect] = {}
var _segments: Dictionary[StringName, ColorRect] = {}
var _free: ColorRect
var _total: Label

## Barre prête à être ajoutée à l'arbre, une colonne par ressource du catalogue.
static func create(palette: CommodityPalette) -> ResourceBar:
	assert(palette != null, "barre de ressources sans palette")
	var bar := ResourceBar.new()
	bar.name = "ResourceBar"
	bar._palette = palette
	bar.add_theme_stylebox_override("panel", _make_panel_style())
	# Les clics traversent : le curseur de cellule pioche sous la souris à chaque image,
	# et une barre qui les avalerait rendrait injouable la bande de carte qu'elle couvre.
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(bar._make_chips())
	column.add_child(bar._make_gauge())
	bar.add_child(column)
	return bar

## Montre cette réserve, annotée de ce que la dernière résolution y a changé.
##
## Les quantités viennent **toujours** du `Ledger` et jamais du delta : celui-ci n'est
## qu'une annotation de lecture, et une barre qui cumulerait des deltas finirait par
## diverger de la réserve qu'elle prétend montrer. Un delta vide n'annote rien.
##
## Sans reconstruction : appelable à chaque image.
func show_ledger(ledger: Ledger, delta: Dictionary[StringName, int] = {}) -> void:
	assert(ledger != null, "barre de ressources sans réserve")
	for id in _palette.ordered():
		var held := ledger.amount(id)
		_amounts[id].text = "%d" % held
		_amounts[id].add_theme_color_override("font_color",
			AMOUNT_COLOR if held > 0 else EMPTY_COLOR)
		_names[id].add_theme_color_override("font_color",
			LABEL_COLOR if held > 0 else EMPTY_COLOR)
		var swatch := _palette.color_of(id)
		swatch.a = 1.0 if held > 0 else EMPTY_SWATCH_ALPHA
		_swatches[id].color = swatch
		_show_delta(id, delta.get(id, 0))
	_show_gauge(ledger)

## Ce que la réserve a visiblement gagné ou perdu pendant cette phase.
##
## Une soustraction de deux choses que les rapports disent déjà — ce qui est entré en
## réserve, moins ce que la journée a mangé quand elle s'est fermée — et non une règle :
## la réserve fait foi, ceci n'est qu'une annotation posée à côté d'un chiffre.
##
## L'identifiant de l'upkeep est un argument et non un `&"food"` écrit ici : le
## `EconomyBalance` le porte précisément pour qu'aucun code ne le nomme, et une barre de
## ressources n'est pas l'endroit où cette discipline commencerait à céder.
static func delta_of(report: PhaseReport,
		upkeep_resource: StringName) -> Dictionary[StringName, int]:
	var delta: Dictionary[StringName, int] = {}
	var stored := report.production().stored()
	for id in stored:
		delta[id] = stored[id]
	if report.closes_the_day():
		var eaten := report.day_report().upkeep().consumed()
		delta[upkeep_resource] = delta.get(upkeep_resource, 0) - eaten
	for id in delta.keys():
		if delta[id] == 0:
			delta.erase(id)
	return delta

# --- La mise à jour ---------------------------------------------------------------------

func _show_delta(id: StringName, moved: int) -> void:
	var label := _deltas[id]
	if moved == 0:
		label.text = ""
		return
	label.text = "%+d" % moved
	label.add_theme_color_override("font_color",
		GAIN_COLOR if moved > 0 else LOSS_COLOR)

## Taille les segments au prorata, et écrit le total sur la capacité.
##
## Le reste de la division va à la place libre plutôt qu'à une ressource : lui donner un
## pixel de plus ferait mentir la seule barre qui compte — celle qui dit s'il reste de la
## place. Une réserve pleine n'a donc jamais de place libre à l'écran, même d'un pixel.
func _show_gauge(ledger: Ledger) -> void:
	var capacity := maxi(ledger.capacity(), 1)
	var used := 0
	for id in _palette.ordered():
		var held := ledger.amount(id)
		var width := 0
		if held > 0:
			width = maxi(held * GAUGE_WIDTH / capacity, MIN_SEGMENT)
		_segments[id].custom_minimum_size = Vector2(width, GAUGE_HEIGHT)
		_segments[id].color = _palette.color_of(id)
		used += width
	_free.custom_minimum_size = Vector2(maxi(GAUGE_WIDTH - used, 0), GAUGE_HEIGHT)
	_total.text = "%d / %d" % [ledger.total(), ledger.capacity()]
	_total.add_theme_color_override("font_color",
		FULL_COLOR if ledger.is_full() else LABEL_COLOR)

# --- La construction --------------------------------------------------------------------

func _make_chips() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", COLUMN_GAP)
	for id in _palette.ordered():
		row.add_child(_make_chip(id))
	return row

func _make_chip(id: StringName) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_constant_override("separation", CHIP_GAP)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swatches[id] = swatch
	chip.add_child(swatch)

	var name_label := _make_text(_palette.label_of(id), LABEL_FONT_SIZE, LABEL_COLOR)
	_names[id] = name_label
	chip.add_child(name_label)

	var amount := _make_text("0", AMOUNT_FONT_SIZE, AMOUNT_COLOR)
	_amounts[id] = amount
	chip.add_child(amount)

	var delta := _make_text("", LABEL_FONT_SIZE, GAIN_COLOR)
	_deltas[id] = delta
	chip.add_child(delta)
	return chip

func _make_gauge() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CHIP_GAP)

	var track := HBoxContainer.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_constant_override("separation", 0)
	for id in _palette.ordered():
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(0, GAUGE_HEIGHT)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_segments[id] = segment
		track.add_child(segment)
	_free = ColorRect.new()
	_free.color = FREE_COLOR
	_free.custom_minimum_size = Vector2(GAUGE_WIDTH, GAUGE_HEIGHT)
	_free.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_free)
	row.add_child(track)

	_total = _make_text("0 / 0", TOTAL_FONT_SIZE, LABEL_COLOR)
	row.add_child(_total)
	return row

func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	return style
