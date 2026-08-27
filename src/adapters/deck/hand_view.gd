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
## **Le coût, lui, s'affiche — et l'affaiblissement d'une carte trop chère aussi.** Ce
## n'est pas une entorse au paragraphe ci-dessus, c'est son autre moitié. La vue ne
## *décide* pas qu'une carte est impayable : elle passe le coût à `Ledger.can_afford()` et
## dessine la réponse, ce que CLAUDE.md écrit noir sur blanc — « la réserve est-elle
## pleine ? se demande au domaine, et la vue affiche la réponse ». La faute serait
## `if ledger.wood >= data.cost`, pas l'appel.
##
## `DESIGN.md` 8 le demande depuis la première partie jouée à la main, et sa raison est
## celle d'une main et non d'une carte : « une main de sept cartes dont on ne connaît le
## prix qu'une par une se joue à l'aveugle ». La ligne de survol donnait déjà le prix de la
## carte **tenue** ; c'est justement ce qui obligeait à toutes les prendre pour comparer.
##
## **Une carte d'action ne porte pas de coût, et ce n'est pas un oubli.** Ce qu'une action
## dépense, ce sont des ouvriers, et combien elle en accepte dépend de la cible — les
## postes d'un bâtiment, les crans qui restent à un chantier, un chiffre d'équilibrage sur
## une case nue. Ce prix-là ne se connaît qu'en visant, donc il se lit sur la ligne de
## survol et sur les cibles allumées, jamais sur la carte. Lui inventer un chiffre fixe ici
## serait mentir sur la seule chose que le joueur voudrait comparer.
##
## Construite en code, sans .tscn : c'est la règle des harnais, et cette vue n'a pas
## encore de raison d'entrer dans scenes/ui/. Le jour où elle en aura une, elle
## déménagera avec sa mise en forme, pas avec ses règles — elle n'en a pas.
##
## Les chiffres sont des constantes nommées et non de l'équilibrage : c'est de la mise en
## forme, et data/balance/ est réservé aux questions ouvertes de DESIGN.md.

## Une carte vient d'être cliquée, à ce rang dans Hand.cards().
##
## Un **signal** et non un appel : la vue signale, elle ne sélectionne pas. C'est le
## harnais qui garde ce qu'il tient, comme il garde déjà le bâtiment courant depuis C2, et
## une vue qui déciderait de la sélection serait la même faute d'architecture qu'une vue
## qui jugerait la jouabilité.
##
## Il transporte un rang et non un identifiant, pour la raison qui a coûté un bug au
## clavier : une main tient couramment deux exemplaires de la même carte, et un
## identifiant ne les distingue pas.
signal card_picked(slot: int)

## Largeur et hauteur d'une carte, en pixels.
##
## La hauteur a gagné douze pixels à `P1a` pour loger le coût sous le libellé, et **trois
## captures ont été nécessaires pour arriver à ce chiffre-là** plutôt qu'à un autre.
##
## Le coût a d'abord partagé la ligne du rang, qui semblait à moitié vide, ce qui laissait
## la carte à 74. C'était le mauvais choix, et pour une raison qui n'appartient pas à cette
## vue : le panneau d'affectation **déborde de sa colonne** aux journées chargées et couvre
## le haut des cartes posées sous lui — dix-huit pixels de bande au sixième jour d'un run
## de test, c'est-à-dire exactement la ligne du rang. Le rang y était déjà illisible avant
## `P1a` ; y ranger le coût l'aurait rendu invisible lui aussi, et un prix qu'on ne voit
## qu'à certaines journées est pire qu'un prix absent.
##
## Sous le libellé, le coût est dans le tiers **bas** de la carte, celui que rien ne
## recouvre. La carte plus haute fait remonter le bord de la bande, donc élargit ce que le
## panneau cache — mais ce qu'il cache reste le rang, qui est un rappel de touche et non
## une information de décision.
##
## Le débordement lui-même n'est pas réparé ici, et il ne peut pas l'être : c'est la
## troisième fois du projet qu'une colonne de droite ne tient pas — après `W2` et `I2` —,
## et `DESIGN.md` 8 lui garde un point à part.
const CARD_WIDTH := 104
const CARD_HEIGHT := 86

## Écart entre deux cartes, et entre deux pools.
const CARD_GAP := 6
const POOL_GAP := 26

## Épaisseur du cadre de la carte tenue.
const SELECTED_BORDER := 3

## De combien une carte survolée se soulève, en pixels.
##
## L'encombrement de la carte ne change pas pour autant : la marge perdue en haut est
## rendue en bas. Une rangée qui grandirait au survol repousserait ses voisines, et la
## main entière danserait sous la souris.
const HOVER_LIFT := 5

## Éclaircissement du fond d'une carte survolée.
const HOVER_LIGHTEN := 0.16

## Liseré d'une carte survolée. Fin et froid, là où la carte **tenue** porte un cadre
## épais et doré : la présélection doit se distinguer de la sélection d'un coup d'œil,
## sans quoi elle ajoute de la confusion plutôt que de l'information.
const HOVER_BORDER := 2
const HOVER_COLOR := Color(0.80, 0.86, 0.94, 0.85)

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

## Le coût, sous le libellé.
const COST_FONT_SIZE := 11

## Écart entre deux chiffres d'un coût. Serré : ce sont les segments d'une même somme,
## pas une liste.
const COST_GAP := 5

## Ce qui reste de l'encre d'une carte que la réserve ne paie pas.
##
## Un affaiblissement et **pas** une couleur d'alarme, et c'est une leçon de la passe
## jouée à la main : l'orange veut dire *danger* sur les quatre autres panneaux — famine,
## écrêtage, pertes d'une vague. Une main de sept cartes dont trois sont trop chères
## s'afficherait entièrement en alarme le premier jour, où rien n'est en train de mal
## tourner. « Pas maintenant » et « attention » sont deux messages ; ils doivent avoir deux
## formes.
const UNAFFORDABLE_DIM := 0.42

## Ce que l'infobulle ajoute quand la réserve ne suit pas.
const UNAFFORDABLE_TEXT := "Réserve insuffisante."

## Ce que l'infobulle ajoute quand la phase ne pose rien.
##
## Elle emprunte l'affaiblissement ci-dessus plutôt que d'en inventer un second, et c'est
## juste : les deux disent « pas maintenant », et les distinguer par la teinte demanderait
## au joueur d'apprendre deux gris. Ce qui les sépare est la **raison**, et une raison se
## lit, donc elle est dans l'infobulle. Celle-ci passe **avant** l'autre quand les deux
## valent : une réserve insuffisante est un problème qu'on peut résoudre, une phase qui ne
## pose rien est un fait qu'on ne discute pas.
const UNPLAYABLE_TEXT := "Cette phase ne pose pas de carte."

## Main vide.
##
## « Entrée résout le soir » jusqu'à `I2b`, où une journée a gagné une phase qui s'appelle
## vraiment *Soir* et qui, elle, ne résout rien. Le mot avait toujours désigné la phase et
## non l'heure — depuis que `PhaseReport` s'est séparé de `DayReport` à `I1` —, mais il
## avait cessé d'être lisible ainsi le jour où `data/` a pu nommer un soir.
const EMPTY_TEXT := "Main vide — Entrée termine la phase."

## Rang qui n'encadre aucune carte.
const NO_HELD := -1

var _catalogue: CardCatalogue

## De quoi mettre un coût en forme : le libellé, la couleur et le rang d'une ressource.
##
## La même palette que la barre de réserve, et c'est tout l'intérêt — un « 15 » vert
## d'ombre sur une carte est le même vert que le segment de bois de la jauge, à un
## centimètre au-dessus. La couleur n'a donc rien à apprendre au joueur qu'il ne lise déjà.
var _palette: CommodityPalette

## Bâtiment -> sa `BuildingData`, pour lire un coût.
##
## Indexée par identifiant de **bâtiment** et non de carte : c'est `CardData.building` qui
## fait le lien, et il existe précisément parce que rien n'oblige une carte à porter le nom
## de ce qu'elle pose. Deux cartes qui poseraient la même ferme à deux prix sont ce qu'un
## draft de méta-progression fera un jour, et cette table les sert déjà.
var _buildings: Dictionary[StringName, BuildingData] = {}

## Hauteur totale que la main occupe en bas de l'écran, marges comprises.
##
## Publique et calculée ici parce que **deux endroits en dépendent** : la bande elle-même,
## et la marge basse que le HUD doit garder pour ne pas descendre sur les cartes. Le
## harnais portait ce second chiffre à la main — un `88.0` recopié —, et c'est le doublon
## que `E2` avait déjà payé sur la réserve : un chiffre écrit à deux endroits est un
## chiffre qui finira par différer de lui-même. Il a d'ailleurs différé à `P1a`, où la
## carte a grandi.
##
## `HOVER_LIFT` y est compris : c'est la course que les cartes ont au-dessus d'elles pour
## se soulever, et l'oublier rognerait le haut de la carte survolée.
static func band_height() -> float:
	return CARD_HEIGHT + HOVER_LIFT + 2 * CARD_GAP

## Vue prête à être ajoutée à l'arbre.
static func create(catalogue: CardCatalogue, palette: CommodityPalette,
		buildings: Dictionary[StringName, BuildingData]) -> HandView:
	assert(catalogue != null, "main à l'écran sans catalogue")
	assert(palette != null, "main à l'écran sans palette de ressources")
	var view := HandView.new()
	view.name = "HandView"
	view._catalogue = catalogue
	view._palette = palette
	view._buildings = buildings
	view.add_theme_constant_override("separation", POOL_GAP)
	view.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	view.alignment = BoxContainer.ALIGNMENT_CENTER
	view.offset_top = -band_height()
	view.offset_bottom = -CARD_GAP
	# Les clics traversent : le curseur de cellule pioche sous la souris à chaque image,
	# et une main qui les avalerait rendrait le bas de la carte injouable.
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

## Redessine la main, la carte de rang `held` encadrée.
##
## `held` est un **rang** dans Hand.cards() et non un identifiant. La première version
## prenait l'identifiant et se trompait : une main tient couramment deux exemplaires de la
## même carte, si bien que le cadre se posait toujours sur le premier, quel que soit celui
## qu'on avait pris. NO_HELD = rien de tenu.
##
## La numérotation suit Hand.cards(), donc l'ordre de CardData.POOLS puis l'ordre de
## pioche. C'est celui que le harnais lit sur les touches 1 à 9, et le même d'une image à
## l'autre — un affichage qui suivrait l'ordre d'un Dictionary changerait sous les doigts.
##
## Le `Ledger` sert à une seule question, posée une fois par carte de bâtiment : la réserve
## paie-t-elle ce coût ? La vue n'en lit aucun montant et n'en additionne rien. C'est le
## même partage qu'avec le catalogue, à qui elle ne demande qu'un texte.
##
## Le `DayCycle` sert exactement de la même façon, et pour une phase que `I2b` a fait
## exister : celle qui ne pose rien et se contente de fermer la journée. Sans elle, la main
## s'y affichait à pleine encre, numérotée, avec son curseur de main — c'est-à-dire qu'elle
## **promettait un geste que le domaine refuse**. La vue ne le décide pas plus qu'elle ne
## décide qu'une carte est trop chère : elle demande `permits()` et dessine la réponse.
##
## `null` veut dire « aucune journée ne gouverne cette main », ce qui est le cas du harnais
## Cartes, où le `Deck` vit seul et où l'on joue quand on veut. C'est la même convention
## que le `phase` nul d'`AssignmentPanel`, qui veut dire hors run.
func show_hand(hand: Hand, held: int, ledger: Ledger, cycle: DayCycle = null) -> void:
	assert(ledger != null, "main à l'écran sans réserve")
	var playable := cycle == null or cycle.permits(PhaseDef.ACTION_PLAY)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	if hand.is_empty():
		add_child(_make_empty_notice())
		return
	var slot := 0
	for pool in CardData.POOLS:
		var cards := hand.cards_in(pool)
		if cards.is_empty():
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", CARD_GAP)
		for card in cards:
			row.add_child(_make_card(card, pool, slot, slot == held, ledger, playable))
			slot += 1
		add_child(row)

## Une carte : le libellé, son rang au clavier, un cadre si elle est tenue, et un liseré
## si la souris la survole.
##
## C'est l'**enveloppe** qui arrête la souris, pas le panneau qu'elle contient. La vue, les
## rangées et les libellés la laissent passer, ce qui permet de cliquer le sol **entre**
## deux cartes et sous la main, au lieu qu'une barre invisible avale le bas de l'écran.
##
## L'enveloppe plutôt que le panneau, et ce n'est pas indifférent : le panneau se soulève
## au survol, si bien qu'un curseur posé sur son bord bas se retrouverait dehors dès qu'il
## monte, ressortirait, le ferait redescendre — et la carte clignoterait sous la souris.
## L'enveloppe, elle, ne bouge jamais.
##
## C'est aussi ce qui évite qu'un clic sur une carte joue au passage la case survolée : un
## Control qui traite l'événement le consomme, donc l'_unhandled_input du harnais ne le
## voit jamais. Le routage est tenu par la structure, pas par un test dans le harnais.
func _make_card(card: StringName, pool: StringName, slot: int,
		selected: bool, ledger: Ledger, playable := true) -> MarginContainer:
	var cost := _cost_of(card)
	var affordable := cost.is_empty() or ledger.can_afford(cost)
	# Deux refus, une seule encre. `_inked()` prend donc « peut-on la poser », et
	# l'infobulle prend les deux, parce qu'elle est le seul endroit qui puisse dire lequel
	# des deux vaut.
	var ready := affordable and playable
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_style(pool, selected, false))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_make_line("%d" % (slot + 1), INDEX_FONT_SIZE,
		_inked(INDEX_COLOR, ready)))
	column.add_child(_make_line(_label_of(card), LABEL_FONT_SIZE,
		_inked(LABEL_COLOR, ready)))
	if not cost.is_empty():
		column.add_child(_make_cost_row(cost, ready))
	panel.add_child(column)

	var wrapper := MarginContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wrapper.tooltip_text = _tooltip_of(card, cost, affordable, playable)
	wrapper.add_child(panel)
	_lift(wrapper, false)
	wrapper.gui_input.connect(_on_card_input.bind(slot))
	wrapper.mouse_entered.connect(_on_card_hover.bind(wrapper, panel, pool, selected, true))
	wrapper.mouse_exited.connect(_on_card_hover.bind(wrapper, panel, pool, selected, false))
	return wrapper

## Un clic gauche sur une carte la signale. Les autres boutons passent leur chemin —
## le clic droit appartient au retrait d'une action, sur la carte du monde.
func _on_card_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	card_picked.emit(slot)

## La souris entre sur une carte, ou la quitte.
##
## `selected` est figé à la construction et non relu : la vue entière est reconstruite à
## chaque changement de sélection, donc une carte survolée ne peut pas changer d'état sous
## la souris sans que ce nœud-ci disparaisse avec.
func _on_card_hover(wrapper: MarginContainer, panel: PanelContainer, pool: StringName,
		selected: bool, hovered: bool) -> void:
	panel.add_theme_stylebox_override("panel", _make_style(pool, selected, hovered))
	_lift(wrapper, hovered)

## Soulève la carte dans son enveloppe, à encombrement constant.
func _lift(wrapper: MarginContainer, hovered: bool) -> void:
	var above := 0 if hovered else HOVER_LIFT
	wrapper.add_theme_constant_override("margin_top", above)
	wrapper.add_theme_constant_override("margin_bottom", HOVER_LIFT - above)

## Le fond d'une carte selon son pool, ce qu'on tient et ce qu'on survole.
##
## La sélection l'emporte sur le survol quand les deux tombent sur la même carte : garder
## le liseré de présélection par-dessus la carte déjà tenue effacerait la seule
## information qui compte. Le fond reste éclairci, ce qui suffit à dire « la souris est
## bien là ».
##
## La marge de contenu ne dépend d'aucun des deux : un cadre qui pousserait le texte
## ferait sauter le libellé d'un pixel au passage de la souris.
func _make_style(pool: StringName, selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint: Color = POOL_TINT.get(pool, DEFAULT_TINT)
	style.bg_color = tint.lightened(HOVER_LIGHTEN) if hovered else tint
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	if selected:
		style.set_border_width_all(SELECTED_BORDER)
		style.border_color = SELECTED_COLOR
	elif hovered:
		style.set_border_width_all(HOVER_BORDER)
		style.border_color = HOVER_COLOR
	return style

## Une ligne de carte. `wrap` décide si le texte a le droit de se replier.
##
## Il ne l'a pas pour un **chiffre**, et la capture de `P1a` dit pourquoi : un libellé se
## replie sur ses espaces, mais `AUTOWRAP_WORD_SMART` coupe aussi ce qui n'a pas d'espace
## dès que la largeur manque, et la largeur manque toujours dans un `HBoxContainer` qui
## distribue. « 20 bois » s'affichait donc « 2 » au-dessus de « 0 » — un coût de vingt lu
## comme deux chiffres empilés, ce qui est pire qu'illisible : c'est lisible et faux.
func _make_line(text: String, size: int, color: Color, wrap := true) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap \
		else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_empty_notice() -> Label:
	return _make_line(EMPTY_TEXT, LABEL_FONT_SIZE, INDEX_COLOR)

## Le coût d'une carte, ou un lot vide si elle n'en a pas.
##
## Vide couvre trois cas qui n'ont pas à se distinguer ici : une carte d'action, une carte
## que le catalogue ignore, et un bâtiment gratuit — le camp de bûcheron en est un dans
## `data/`. Les trois se dessinent pareil, c'est-à-dire sans ligne de coût, et la carte
## gratuite y gagne : « 0 » écrit en toutes lettres serait un prix, et il n'y en a pas.
func _cost_of(card: StringName) -> Dictionary[StringName, int]:
	var empty: Dictionary[StringName, int] = {}
	if not _catalogue.has(card):
		return empty
	var data := _catalogue.card(card)
	if not data.places_a_building():
		return empty
	var building := _buildings.get(data.building) as BuildingData
	return empty if building == null else building.cost

## Le coût, un chiffre par ressource, chacun de la couleur de la sienne.
##
## Des **chiffres nus** et pas « 15 Bois » : la carte fait cent quatre pixels de large, et
## deux ressources écrites en toutes lettres n'y tiennent pas à onze points. La couleur
## porte l'identité, exactement comme sur la jauge segmentée du haut de l'écran — et le
## texte entier reste dans l'infobulle, qui est là pour ce qui ne tient pas.
##
## Aucun des chiffres ne se replie, et c'est le contraire d'un détail : voir `_make_line()`.
##
## L'ordre est celui de la palette, donc celui de la barre de réserve : deux affichages du
## même lot doivent donner la même ligne.
func _make_cost_row(cost: Dictionary[StringName, int], affordable: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", COST_GAP)
	for id in _palette.keys_of(cost):
		row.add_child(_make_line("%d" % cost[id], COST_FONT_SIZE,
			_inked(_palette.color_of(id), affordable), false))
	return row

## L'infobulle : ce que la carte pose, ce qu'elle coûte en toutes lettres, et le refus de
## la réserve s'il y a lieu.
##
## C'est le pendant de la ligne de coût, et il porte ce qu'elle n'a pas la place de dire.
## Le nom des ressources y est écrit, ce qui rend la couleur apprenable au lieu d'être à
## deviner — une carte qui ne se lirait qu'à la teinte serait illisible pour qui les
## confond.
func _tooltip_of(card: StringName, cost: Dictionary[StringName, int],
		affordable: bool, playable: bool) -> String:
	var text := _label_of(card)
	if not cost.is_empty():
		text += "\n%s" % _palette.bundle_text(cost)
	if not playable:
		return "%s\n%s" % [text, UNPLAYABLE_TEXT]
	if not affordable:
		return "%s\n%s" % [text, UNAFFORDABLE_TEXT]
	return text

## Une couleur telle qu'on l'écrit sur une carte que la réserve paie, ou telle qu'on la
## laisse pâlir sur une carte qu'elle ne paie pas.
##
## L'alpha et non la saturation : les couleurs de ressource viennent de `data/` et rien ici
## ne doit décider de ce à quoi elles ressemblent. Les affaiblir toutes du même facteur
## garde leurs écarts entre elles, donc garde la ligne lisible.
func _inked(color: Color, affordable: bool) -> Color:
	return color if affordable else Color(color, color.a * UNAFFORDABLE_DIM)

## Libellé d'une carte, ou son identifiant si le catalogue l'ignore.
##
## Le catalogue est la seule chose que cette vue lit du domaine, et elle ne lui demande
## qu'un texte — jamais ce qu'une carte fait.
func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label
