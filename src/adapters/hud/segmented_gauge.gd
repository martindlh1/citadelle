class_name SegmentedGauge
extends HBoxContainer
## Une barre unique où des parts se partagent une capacité, et le compte qui la légende.
##
## Vue pure. On lui donne des quantités et une capacité, elle taille des rectangles. Elle
## ne sait pas ce qu'elle mesure : `ResourceBar` y met quatre ressources sur cent unités de
## réserve, `PopulationBar` y met les bras immobilisés et les bras libres sur les places de
## logement. Elle ne juge rien non plus — « est-ce plein ? » lui arrive en argument, parce
## que la question appartient au domaine qui tient le plafond.
##
## ---
##
## **Elle existe parce que `N1` a écrit que la population est le jumeau de la réserve**, et
## ce fichier est l'endroit où ce jumelage devient visible plutôt qu'affirmé. Deux plafonds
## bâtis sur le même modèle — une quantité, une capacité que des bâtiments relèvent, un
## écrêtage quand elle baisse — se regardent avec la même barre, ou bien la ressemblance
## n'était qu'une phrase de docstring.
##
## Elle sort de `ResourceBar`, qui la tenait seule depuis `E2` avec la règle qui suit.
##
## **Le reste de la division va à la place libre, jamais à une part.** Lui donner un pixel
## de plus ferait mentir la seule lecture qui compte — celle qui dit s'il reste de la place.
## Un plafond atteint n'a donc jamais de place libre à l'écran, même d'un pixel, et c'est ce
## qui rend l'arbitrage de `DESIGN.md` 3.3 regardable : « remplir sa réserve de bois, c'est
## renoncer à stocker de la pierre » — et remplir son village de bras immobilisés, c'est
## renoncer à en avoir de libres.
##
## L'ordre des parts est celui de la table de couleurs reçue à la construction, donc celui
## de son insertion. Les nœuds sont bâtis une fois et mis à jour **sur place** : appelable à
## chaque image, sans churn d'allocation.

## Largeur de la piste, en pixels.
var _width: int

## Part -> son rectangle, dans l'ordre de la piste.
var _segments: Dictionary[StringName, ColorRect] = {}

## Le reste de la capacité.
var _free: ColorRect

## « tant sur tant », à droite de la piste.
var _total: Label

## Jauge prête à être ajoutée à l'arbre, un segment par part de cette table.
##
## La table donne à la fois les parts, leur ordre et leur couleur. Un `Dictionary` plutôt
## que deux tableaux parallèles : ceux-là se désalignent au premier ajout, et personne ne
## s'en aperçoit avant de lire une couleur sur la mauvaise colonne.
static func create(colors: Dictionary[StringName, Color],
		width: int = HudStyle.GAUGE_WIDTH) -> SegmentedGauge:
	assert(not colors.is_empty(), "jauge sans aucune part")
	var gauge := SegmentedGauge.new()
	gauge.name = "SegmentedGauge"
	gauge._width = width
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_theme_constant_override("separation", HudStyle.CHIP_GAP)

	var track := HudStyle.row(0)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for part in colors:
		var segment := ColorRect.new()
		segment.color = colors[part]
		segment.custom_minimum_size = Vector2(0, HudStyle.GAUGE_HEIGHT)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge._segments[part] = segment
		track.add_child(segment)
	gauge._free = ColorRect.new()
	gauge._free.color = HudStyle.FREE_COLOR
	gauge._free.custom_minimum_size = Vector2(width, HudStyle.GAUGE_HEIGHT)
	gauge._free.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(gauge._free)
	gauge.add_child(track)

	gauge._total = HudStyle.text("0 / 0", HudStyle.TOTAL_FONT_SIZE, HudStyle.LABEL_COLOR)
	gauge.add_child(gauge._total)
	return gauge

## Taille les segments au prorata et écrit le total sur la capacité.
##
## `total` et `full` arrivent **du domaine** au lieu d'être resommés ici, et ce n'est pas de
## la pédanterie : `Ledger.total()` et `Population.headcount()` sont les chiffres qui font
## foi, `is_full()` est une question à laquelle le domaine répond, et une vue qui
## recomposerait l'un ou l'autre finirait par afficher un plein qui n'en est pas un. Ce qui
## se calcule ici est de la **géométrie**, rien de plus.
##
## Une part absente de la table vaut zéro : c'est le cas normal d'une jauge dont une part
## n'existe pas encore, pas un incident.
func show_amounts(amounts: Dictionary[StringName, int], total: int, capacity: int,
		full: bool) -> void:
	var room := maxi(capacity, 1)
	var used := 0
	for part in _segments:
		var held: int = maxi(0, amounts.get(part, 0))
		var pixels := 0
		if held > 0:
			pixels = maxi(held * _width / room, HudStyle.MIN_SEGMENT)
		_segments[part].custom_minimum_size = Vector2(pixels, HudStyle.GAUGE_HEIGHT)
		used += pixels
	_free.custom_minimum_size = Vector2(maxi(_width - used, 0), HudStyle.GAUGE_HEIGHT)
	_total.text = "%d / %d" % [total, capacity]
	_total.add_theme_color_override("font_color",
		HudStyle.FULL_COLOR if full else HudStyle.LABEL_COLOR)
