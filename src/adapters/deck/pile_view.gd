class_name PileView
extends MarginContainer
## Ce que les piles contiennent : une pioche et une défausse consultables, par pool.
##
## `DESIGN.md` 8 le demande à `P1b` en ces termes — « une pioche et une défausse
## consultables, plutôt que trois compteurs » — et donne la raison qui en fait autre chose
## qu'un confort : « c'est aussi ce qui rendra jouable l'`OUVERT` de 3.5 sur les cartes non
## jouées : on ne peut pas arbitrer ce qu'on ne voit pas ». `I2b` doit trancher ce que
## devient une main qu'on ne joue pas ; il faut d'abord pouvoir répondre à « combien de
## *Récolter* me reste-t-il ».
##
## **Elle ne montre pas l'ordre de la pioche**, et ce refus ne vient pas d'ici : le
## `Deck` répond par un recensement — carte vers nombre d'exemplaires —, donc l'ordre
## n'est pas dans ce que cette vue reçoit. Elle ne pourrait pas le montrer même si on le
## lui demandait. Le pourquoi est écrit sur `Deck.draw_census()` ; ce qui compte ici est
## que la vue le **dise** au joueur, en une ligne, plutôt que de le laisser deviner qu'une
## liste rangée par ordre alphabétique n'est pas un ordre de tirage.
##
## Vue pure, construite en code, sans `.tscn`, comme les vues de `E2` et de `W2`. On lui
## donne un `Deck`, elle dessine. Elle ne juge rien et ne pioche rien.
##
## **Modale, donc `MOUSE_FILTER_STOP` sur toute la surface.** C'est la seule vue du projet
## qui couvre l'écran, et le partage de `CLAUDE.md` la met du côté des vues sur lesquelles
## on clique : sans quoi un clic sur une ligne de la liste irait jouer la carte tenue sur
## la cellule cachée dessous.

## Un clic n'importe où sur la vue : on veut la refermer.
##
## Un signal et non une fermeture faite ici, alors que la vue décide bien de sa propre
## visibilité dans `toggle()`. La différence est l'appelant : `toggle()` répond à un geste
## que le harnais a reçu et rend l'état, ici c'est la vue qui **apprend** un geste au
## harnais. Le lui signaler lui laisse dire ce qu'il en fait — sa ligne d'action, entre
## autres — au lieu de le mettre devant le fait accompli.
signal dismissed()

## Fond du voile qui couvre l'écran. Assez sombre pour que la liste se lise, assez clair
## pour qu'on voie qu'on n'a pas quitté la partie.
const VEIL_COLOR := Color(0.04, 0.05, 0.07, 0.72)

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.98)
const PANEL_RADIUS := 6
const PANEL_MARGIN := 18

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const HEAD_COLOR := Color(0.62, 0.66, 0.72)
const CARD_COLOR := Color(0.90, 0.91, 0.93)

## Ce qu'un pool vide affiche sous une colonne.
const EMPTY_COLOR := Color(0.44, 0.47, 0.53)

const TITLE_FONT_SIZE := 16
const HEAD_FONT_SIZE := 12
const ROW_FONT_SIZE := 12

const BLOCK_GAP := 14
const ROW_GAP := 2
const COLUMN_GAP := 40

## Largeur d'une colonne de pile. Deux colonnes de même largeur se lisent comme deux
## listes comparables, ce qu'elles sont.
const COLUMN_WIDTH := 190

const TITLE := "Les piles"
const CLOSE_HINT := "P, Échap, ou un clic pour refermer"

## Les deux colonnes d'un pool, et le compte que chacune porte.
const DRAW_HEAD := "Pioche (%d)"
const DISCARD_HEAD := "Défausse (%d)"

## Ce que le pool annonce à côté de son nom : ce qu'on en tient déjà, et qui est à
## l'écran juste en dessous. C'est le troisième des « trois compteurs » que ce jalon
## remplace, et le seul qui méritait de rester un compte — la main, on la voit.
const IN_HAND := "%d en main"

const NOTHING := "—"

## Un exemplaire, plusieurs exemplaires. Le nombre est **toujours** écrit, y compris à un,
## parce qu'une liste dont certaines lignes portent un chiffre et d'autres non se lit deux
## fois : une fois pour la carte, une fois pour vérifier qu'il n'y a pas de chiffre.
const COPIES := "%s  ×%d"

## La phrase qui empêche la liste d'être lue comme un ordre de tirage.
##
## Elle est là parce que l'absence d'une information ne se voit pas. Un joueur qui lit
## quatre cartes rangées peut très raisonnablement croire qu'elles sortiront dans cet
## ordre, et rien à l'écran ne le détromperait — c'est le même défaut de forme que le
## « 2 » au-dessus du « 0 » de `P1a` : lisible, et faux.
const ORDER_NOTE := "La pioche est mélangée : cette liste dit ce qu'elle contient, jamais dans quel ordre."

var _catalogue: CardCatalogue

## Pool -> le bloc qui le décrit, pour une mise à jour sur place.
var _pools: Dictionary[StringName, VBoxContainer] = {}

## Vue prête à être ajoutée à l'arbre, masquée.
##
## Masquée et non absente : elle se remplit à chaque image où elle est visible, comme les
## autres vues du HUD, et la construire au moment de l'ouverture ferait payer une
## allocation d'arbre à un geste qui doit être instantané.
static func create(catalogue: CardCatalogue) -> PileView:
	assert(catalogue != null, "vue des piles sans catalogue")
	var view := PileView.new()
	view.name = "PileView"
	view._catalogue = catalogue
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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)
	column.add_child(_make_header())
	for pool in CardData.POOLS:
		var block := view._make_pool(pool)
		view._pools[pool] = block
		column.add_child(block)
	column.add_child(_make_text(ORDER_NOTE, HEAD_FONT_SIZE, EMPTY_COLOR))
	panel.add_child(column)
	return view

## Redessine les trois pools sur l'état du deck.
##
## Les blocs sont **reconstruits** ici, à l'inverse des vues rafraîchies à chaque image :
## une pile change de longueur à chaque pioche, donc il n'y a pas de nœud à réutiliser
## d'une ouverture à l'autre. Le coût est celui d'un geste et non d'une image, et
## l'appelant ne l'appelle qu'à l'ouverture.
func show_piles(deck: Deck) -> void:
	assert(deck != null, "vue des piles sans deck")
	for pool in CardData.POOLS:
		_fill_pool(deck, pool)

## Ouvre la vue, ou la referme. Rend le nouvel état.
##
## Le même partage que le repli d'`AssignmentPanel` : être ouverte ou fermée est la taille
## de la vue, donc son affaire ; le `Deck` qu'elle montre appartient au harnais, qui le
## lui passe. Elle rend son état pour éviter à l'appelant un accesseur qu'il serait le
## seul à lire, et juste après.
func toggle(deck: Deck) -> bool:
	visible = not visible
	if visible:
		show_piles(deck)
	return visible

# --- Les blocs -------------------------------------------------------------------------

## Le bloc d'un pool : son nom, puis les deux colonnes. Bâti vide, rempli ensuite.
##
## Le nom du pool est son identifiant capitalisé, comme le nom d'une famille sur une fiche
## d'ouvrier, et pour la même raison : les trois pools de `DESIGN.md` 3.5 vivent dans
## `CardData` et rien ne leur donne de libellé. Une table identifiant -> français ici
## serait le dictionnaire qu'aucune vue de ce projet n'écrit.
func _make_pool(pool: StringName) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = String(pool).capitalize()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", ROW_GAP)

	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_constant_override("separation", COLUMN_GAP / 2)
	# La teinte du pool est celle que la main emploie déjà sur le fond d'une carte. Elle
	# n'apprend rien de neuf : elle dit que ces listes-là sont les cartes de cette
	# couleur-là, ce qui est exactement ce qu'un joueur cherche à relier.
	var tint: Color = HandView.POOL_TINT.get(pool, HandView.DEFAULT_TINT)
	title.add_child(_make_text(String(pool).capitalize(), HEAD_FONT_SIZE,
		Color(tint.r, tint.g, tint.b).lightened(0.55)))
	title.add_child(_make_text("", HEAD_FONT_SIZE, EMPTY_COLOR))
	block.add_child(title)

	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	columns.add_child(_make_column())
	columns.add_child(_make_column())
	block.add_child(columns)
	return block

## Une colonne de pile : son en-tête, puis ses lignes.
static func _make_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(_make_text("", HEAD_FONT_SIZE, HEAD_COLOR))
	return column

func _fill_pool(deck: Deck, pool: StringName) -> void:
	var block := _pools[pool]
	var title := block.get_child(0) as HBoxContainer
	(title.get_child(1) as Label).text = IN_HAND % deck.hand_size(pool)
	var columns := block.get_child(1) as HBoxContainer
	_fill_column(columns.get_child(0) as VBoxContainer,
		DRAW_HEAD % deck.draw_size(pool), deck.draw_census(pool))
	_fill_column(columns.get_child(1) as VBoxContainer,
		DISCARD_HEAD % deck.discard_size(pool), deck.discard_census(pool))

## Remplit une colonne : son en-tête, puis une ligne par carte présente.
##
## Les cartes sont rangées par **libellé**, et jamais par identifiant. Comparer deux
## `StringName` compare leurs pointeurs internes : l'ordre obtenu est arbitraire, stable
## le temps d'une session et différent à la suivante — `CLAUDE.md` en fait un piège nommé,
## et il frapperait ici de la façon la plus visible qui soit, une liste qui se réordonne
## d'un lancement à l'autre sans que rien n'ait bougé.
func _fill_column(column: VBoxContainer, head: String,
		census: Dictionary[StringName, int]) -> void:
	(column.get_child(0) as Label).text = head
	for index in range(column.get_child_count() - 1, 0, -1):
		var stale := column.get_child(index)
		column.remove_child(stale)
		stale.queue_free()
	if census.is_empty():
		column.add_child(_make_text(NOTHING, ROW_FONT_SIZE, EMPTY_COLOR))
		return
	var cards: Array[StringName] = []
	cards.assign(census.keys())
	cards.sort_custom(func(one: StringName, other: StringName) -> bool:
		return _label_of(one) < _label_of(other))
	for card in cards:
		column.add_child(_make_text(COPIES % [_label_of(card), census[card]],
			ROW_FONT_SIZE, CARD_COLOR))

static func _make_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", COLUMN_GAP)
	var title := _make_text(TITLE, TITLE_FONT_SIZE, TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_text(CLOSE_HINT, HEAD_FONT_SIZE, EMPTY_COLOR))
	return header

## Refermer d'un clic, où que ce soit. Une modale qu'on ne peut quitter qu'au clavier est
## une modale dont on cherche la touche, et l'indice de la barre de tête ne se lit qu'une
## fois.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dismissed.emit()
		accept_event()

func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label

## `AUTOWRAP_OFF` par défaut, et c'est la leçon de `P1a` : un `Label` en
## `AUTOWRAP_WORD_SMART` coupe aussi ce qui n'a pas d'espace, si bien qu'un « ×10 » serré
## se dessine « ×1 » au-dessus de « 0 ». Lisible et faux.
static func _make_text(text: String, size: int, color: Color) -> Label:
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
