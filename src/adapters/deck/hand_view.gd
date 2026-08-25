class_name HandView
extends HBoxContainer
## La main du joueur, en bas de l'écran : une carte par panneau, la sélection encadrée.
##
## Vue pure, et c'est ce que « la main à l'écran » veut dire à D2 — la première fois que
## le joueur voit ce qu'il tient plutôt que de le lire dans un rapport texte. Elle
## n'écoute aucun input et ne décide d'aucune sélection : on lui donne une Hand et
## l'identifiant tenu, elle dessine. Le harnais garde la sélection, comme il garde le
## bâtiment courant depuis C2.
##
## Elle ne juge **aucune** jouabilité. Une carte grisée parce qu'elle n'aurait aucune
## cible serait une règle rejouée dans une vue, exactement ce que CLAUDE.md refuse : la
## question se pose à ActionTargeting, et c'est la surbrillance des cibles qui affiche la
## réponse. Une carte sans cible se prend en main et n'allume rien, ce qui est une
## information plus honnête qu'un panneau éteint.
##
## Construite en code, sans .tscn : c'est la règle des harnais, et cette vue n'a pas
## encore de raison d'entrer dans scenes/ui/. Le jour où elle en aura une, elle
## déménagera avec sa mise en forme, pas avec ses règles — elle n'en a pas.
##
## Les chiffres sont des constantes nommées et non de l'équilibrage : c'est de la mise en
## forme, et data/balance/ est réservé aux questions ouvertes de DESIGN.md.

## Largeur et hauteur d'une carte, en pixels.
const CARD_WIDTH := 104
const CARD_HEIGHT := 74

## Écart entre deux cartes, et entre deux pools.
const CARD_GAP := 6
const POOL_GAP := 26

## Épaisseur du cadre de la carte tenue.
const SELECTED_BORDER := 3

## Teintes de fond, par pool. Un pool absent de la table retombe sur DEFAULT_TINT, ce qui
## laisse les powers entrer à X4 sans rien casser ici.
const POOL_TINT: Dictionary[StringName, Color] = {
	&"action": Color(0.16, 0.22, 0.30, 0.92),
	&"building": Color(0.26, 0.20, 0.14, 0.92),
	&"power": Color(0.24, 0.16, 0.28, 0.92),
}
const DEFAULT_TINT := Color(0.18, 0.18, 0.20, 0.92)

## Cadre de la carte tenue, et texte.
const SELECTED_COLOR := Color(1.0, 0.85, 0.35)
const LABEL_COLOR := Color(0.94, 0.94, 0.92)
const INDEX_COLOR := Color(0.62, 0.66, 0.72)

const LABEL_FONT_SIZE := 13
const INDEX_FONT_SIZE := 11

## Main vide.
const EMPTY_TEXT := "Main vide — Entrée résout le soir et repioche."

var _catalogue: CardCatalogue

## Vue prête à être ajoutée à l'arbre.
static func create(catalogue: CardCatalogue) -> HandView:
	assert(catalogue != null, "main à l'écran sans catalogue")
	var view := HandView.new()
	view.name = "HandView"
	view._catalogue = catalogue
	view.add_theme_constant_override("separation", POOL_GAP)
	view.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	view.alignment = BoxContainer.ALIGNMENT_CENTER
	view.offset_top = -(CARD_HEIGHT + 2 * CARD_GAP)
	view.offset_bottom = -CARD_GAP
	# Les clics traversent : le curseur de cellule pioche sous la souris à chaque image,
	# et une main qui les avalerait rendrait le bas de la carte injouable.
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

## Redessine la main, `held` encadrée.
##
## `held` est l'identifiant tenu et non un rang : la main se repioche entre deux phases,
## et un rang survivrait à la carte qu'il désignait. Vide = rien de tenu.
##
## La numérotation suit Hand.cards(), donc l'ordre de CardData.POOLS puis l'ordre de
## pioche. C'est celui que le harnais lit sur les touches 1 à 9, et le même d'une image à
## l'autre — un affichage qui suivrait l'ordre d'un Dictionary changerait sous les doigts.
func show_hand(hand: Hand, held: StringName) -> void:
	for child in get_children():
		child.queue_free()
		remove_child(child)
	if hand.is_empty():
		add_child(_make_empty_notice())
		return
	var slot := 0
	var marked := false
	for pool in CardData.POOLS:
		var cards := hand.cards_in(pool)
		if cards.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CARD_GAP)
		for card in cards:
			slot += 1
			# Un seul exemplaire est encadré même quand la main en tient deux : c'est
			# celui que la touche désigne, et encadrer les deux mentirait sur ce qu'un
			# clic jouerait.
			var selected := not marked and card == held
			marked = marked or selected
			row.add_child(_make_card(card, pool, slot, selected))
		add_child(row)

## Un panneau de carte : le libellé, son rang au clavier, et un cadre s'il est tenu.
func _make_card(card: StringName, pool: StringName, slot: int,
		selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_style(pool, selected))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_make_line("%d" % slot, INDEX_FONT_SIZE, INDEX_COLOR))
	column.add_child(_make_line(_label_of(card), LABEL_FONT_SIZE, LABEL_COLOR))
	panel.add_child(column)
	return panel

func _make_style(pool: StringName, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = POOL_TINT.get(pool, DEFAULT_TINT)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	if not selected:
		return style
	style.set_border_width_all(SELECTED_BORDER)
	style.border_color = SELECTED_COLOR
	return style

func _make_line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_empty_notice() -> Label:
	return _make_line(EMPTY_TEXT, LABEL_FONT_SIZE, INDEX_COLOR)

## Libellé d'une carte, ou son identifiant si le catalogue l'ignore.
##
## Le catalogue est la seule chose que cette vue lit du domaine, et elle ne lui demande
## qu'un texte — jamais ce qu'une carte fait.
func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label
