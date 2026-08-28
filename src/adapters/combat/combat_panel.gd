class_name CombatPanel
extends PanelContainer
## Qui est sur le champ, ce qu'il lui reste, et à qui c'est le tour.
##
## Vue pure, bâtie en code comme toutes celles de `src/adapters/`. Elle **ne juge rien** :
## elle demande au plateau qui est debout, ce qu'il lui reste et quels gestes il a encore, et
## dessine les réponses. « Ce corps peut-il encore frapper ? » est une question du domaine, et
## `Combatant` y répond depuis `F2a`.
##
## C'est la sœur d'`AssignmentPanel` jusque dans le geste : on **clique une fiche** puis on
## clique sur la carte, ce que `P1a` a posé comme le vocabulaire du jeu et qu'il n'y a aucune
## raison de rompre parce qu'on se bat. Elle porte donc aussi `MOUSE_FILTER_STOP` — sans quoi
## un clic sur une fiche jouerait aussi la case cachée dessous.
##
## Les **noms** lui arrivent, elle ne va pas les chercher. `CLAUDE.md` en a tiré la règle à
## `I2` sur les morts d'une vague : un adapter qui traduit un identifiant en prénom en
## interrogeant le roster réussit pour tout le monde sauf pour ceux dont il est justement
## question. Un assaillant n'a d'ailleurs de nom dans aucun roster.
##
## Elle garde les **tombés** en liste, alors que la carte ne montre plus leur pion. Le partage
## est celui qu'`I2` a payé cher : la carte montre l'état, le panneau raconte. Un mort qui
## disparaîtrait des deux endroits laisserait le joueur compter ses gens pour comprendre ce
## qu'il vient de perdre.

## Fiche cliquée. Un signal et non un appel, pour la raison qu'`HandView` a écrite avant :
## une vue signale un geste, elle ne décide pas de ce qu'il déclenche.
signal body_picked(body: StringName)

## Bouton de fin de tour.
signal turn_ended()

const PANEL_WIDTH := 260.0
const MARGIN := 10
const TITLE_SIZE := 15
const ROW_SIZE := 13

## Teinte du camp d'en face. Celle des ouvriers vient de `BodyRenderer`, pour que le
## bandeau du panneau et les pions sur la carte ne puissent pas dériver l'un de l'autre.
const FOE_COLOR := Color(0.86, 0.44, 0.38)

## Encre d'une fiche dont ce n'est pas le tour, ou qui n'a plus de geste.
const SPENT_COLOR := Color(0.55, 0.57, 0.62)

## Encre d'un corps tombé.
const FALLEN_COLOR := Color(0.44, 0.40, 0.42)

var _title: Label
var _rows: VBoxContainer
var _end_turn: Button
var _cards: Array[Button] = []

## Rang de fiche -> identifiant du corps qu'elle porte.
##
## Une table parallèle plutôt qu'un identifiant relu sur le libellé de la fiche : un
## affichage n'est pas une clé, et le jour où la fiche gagne une ligne, la relire donnerait
## un identifiant tronqué sans que rien ne plante.
var _ids: Array[StringName] = []

## Panneau prêt à être ajouté à l'arbre.
static func create() -> CombatPanel:
	var panel := CombatPanel.new()
	panel.name = "CombatPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	# Une vue sur laquelle on clique arrête la souris, à l'inverse des vues de lecture.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_style())

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	panel._title = _make_text("", TITLE_SIZE, Color.WHITE)
	column.add_child(panel._title)

	panel._rows = VBoxContainer.new()
	column.add_child(panel._rows)

	panel._end_turn = Button.new()
	panel._end_turn.text = "Finir le tour"
	panel._end_turn.pressed.connect(panel._on_end_turn_pressed)
	column.add_child(panel._end_turn)
	return panel

## Montre ce plateau, la fiche `held` étant celle qu'on tient.
##
## Elle met ses nœuds à jour **sur place** plutôt que de les reconstruire, ce qui permet de
## l'appeler après chaque geste sans churn d'allocation — et surtout sans avoir à énumérer
## tous les gestes qui touchent son sujet, un oubli dans cette liste se lisant comme un
## compteur qui ne bouge pas.
func show_board(board: CombatBoard, held: StringName,
		names: Dictionary[StringName, String]) -> void:
	assert(board != null, "panneau de combat sans plateau")
	var playing := board.side()
	_title.text = "Manche %d · %s" % [board.round_number(),
		"Ouvriers" if playing == Combatant.Side.FRIEND else "Vague"]
	_title.add_theme_color_override("font_color",
		BodyRenderer.FRIEND_COLOR if playing == Combatant.Side.FRIEND else FOE_COLOR)

	var bodies := board.bodies()
	_ids.clear()
	for index in bodies.size():
		_ids.append(bodies[index].id())
		_card(index).visible = true
		_fill_card(_card(index), bodies[index], playing, held,
			names.get(bodies[index].id(), String(bodies[index].id())))
	for spare in range(bodies.size(), _cards.size()):
		_cards[spare].visible = false

## Écrit une fiche.
##
## Trois encres, et elles disent trois choses différentes qu'il vaut mieux ne pas confondre :
## un corps **tombé**, un corps du camp qui **ne joue pas**, et un corps qui a déjà tout
## dépensé. Le troisième est le seul sur lequel le joueur puisse encore agir — en le laissant
## tranquille — donc c'est le seul qui doit se distinguer d'un coup d'œil.
func _fill_card(card: Button, body: Combatant, playing: Combatant.Side,
		held: StringName, shown: String) -> void:
	var gestures := PackedStringArray()
	if not body.has_moved():
		gestures.append("pas")
	if not body.has_struck():
		gestures.append("coup")
	card.text = "%s %-10s %2d PV  %s" % [
		"▸" if body.id() == held else "·",
		("† " + shown) if body.is_down() else shown,
		body.hit_points(),
		"" if body.is_down() else " ".join(gestures)]
	card.tooltip_text = "%s — %d/%d PV, portée %d, %d de déplacement, marche de %d" % [
		shown, body.hit_points(), body.stats().hit_points(), body.stats().reach(),
		body.stats().move(), body.stats().climb()]
	card.disabled = body.is_down() or body.side() != playing
	var ink := FALLEN_COLOR if body.is_down() \
		else SPENT_COLOR if body.side() != playing \
		else BodyRenderer.FRIEND_COLOR if body.is_friend() else FOE_COLOR
	card.add_theme_color_override("font_color", ink)
	card.add_theme_color_override("font_disabled_color", ink)

## La fiche de ce rang, créée à la demande.
func _card(index: int) -> Button:
	while _cards.size() <= index:
		var card := Button.new()
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", ROW_SIZE)
		card.pressed.connect(_on_card_pressed.bind(_cards.size()))
		_cards.append(card)
		_rows.add_child(card)
	return _cards[index]

func _on_card_pressed(index: int) -> void:
	if index >= _ids.size():
		return
	body_picked.emit(_ids[index])

func _on_end_turn_pressed() -> void:
	turn_ended.emit()

static func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	# Un libellé qui porte un nombre ne s'enroule jamais : « 20 » se dessinerait « 2 »
	# au-dessus de « 0 », lisible et faux. Constaté à P1a.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.88)
	style.set_corner_radius_all(4)
	style.content_margin_left = MARGIN
	style.content_margin_right = MARGIN
	style.content_margin_top = MARGIN
	style.content_margin_bottom = MARGIN
	return style
