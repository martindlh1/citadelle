class_name HudStyle
extends RefCounted
## Ce que les vues du HUD partagent : leurs teintes, leurs écarts, et trois fabriques.
##
## Couche adapter et rien d'autre. Aucune règle, aucun chiffre du jeu — **de la mise en
## forme**, et c'est exactement pourquoi ces nombres ne sont pas dans `data/balance/` :
## `CLAUDE.md` y réserve les questions encore ouvertes de `DESIGN.md`, et la largeur d'une
## jauge n'en est pas une.
##
## Elle naît à `N2` du même constat que `CommodityPalette` à `E2`, et il vaut d'être écrit
## parce que c'est la deuxième fois : une fonction recopiée deux fois est un doublon qu'on
## tolère, recopiée trois fois c'est un fichier qui manque. `ResourceBar` tenait seule un
## style de panneau, une fabrique de `Label` et sept teintes ; `PopulationBar` et
## `BuildingCard` en voulaient les mêmes. Trois copies de `FULL_COLOR` finissent par ne plus
## être la même couleur, et le jour où ça arrive personne ne sait laquelle est la bonne.
##
## **Les trois vues sont des vues de lecture**, donc les conteneurs fabriqués ici laissent
## passer la souris. C'est le partage que `CLAUDE.md` impose : une vue sur laquelle on
## clique porte `MOUSE_FILTER_STOP` et le déclare elle-même ; celles qui se contentent
## d'afficher laissent le curseur de cellule piocher la carte sous elles.

## Largeur d'une jauge segmentée, en pixels. Le segment de chaque part s'y taille au
## prorata de la capacité.
const GAUGE_WIDTH := 260
const GAUGE_HEIGHT := 12

## Largeur minimale d'un segment non vide, en pixels.
##
## Sans elle, une unité sur deux cents s'arrondit à zéro et la part disparaît de la jauge
## alors qu'on la possède. Le prorata est faux d'un pixel ; l'absence était fausse tout
## court.
const MIN_SEGMENT := 2

## Côté de la pastille de couleur d'une part.
const SWATCH := 10

## Largeur minimale d'un panneau du HUD.
##
## Elle existe pour que la colonne de droite ne **respire pas** quand son contenu change :
## sans elle, choisir « Mine » après « Camp de bûcheron » rétrécit la fiche, donc la colonne
## entière, donc la barre de réserve deux panneaux plus bas. Une vue qui bouge parce qu'une
## autre a changé de texte est un mouvement que rien ne justifie.
const PANEL_WIDTH := 300

## Écarts internes.
const CHIP_GAP := 6
const COLUMN_GAP := 18
const ROW_GAP := 6

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.92)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 10

## Fond de la place libre dans une jauge.
const FREE_COLOR := Color(0.22, 0.24, 0.28)

## Texte d'un libellé, d'une quantité, et d'une part qu'on ne possède pas.
const LABEL_COLOR := Color(0.68, 0.72, 0.78)
const AMOUNT_COLOR := Color(0.94, 0.94, 0.92)
const EMPTY_COLOR := Color(0.42, 0.45, 0.50)

## Un plafond atteint. La même teinte que ce que le HUD appelle une perte : c'est le même
## événement vu d'un cran plus tôt — une réserve pleine renverse la prochaine récolte, un
## logement plein arrête la prochaine naissance.
const FULL_COLOR := Color(0.95, 0.62, 0.35)

## Un delta gagné, un delta perdu — et, depuis `N2`, ce qui manque pour bâtir.
const GAIN_COLOR := Color(0.55, 0.82, 0.50)
const LOSS_COLOR := Color(0.90, 0.48, 0.45)

## Les bras au travail, et les bras libres.
##
## Elles vivent ici et non sur `PopulationBar` parce que **deux vues les lisent**, et que
## c'est le lien entre les deux qui compte : les bras qu'une fiche de bâtiment réclame sont
## exactement ceux qui passeront de la part froide à la part chaude de la jauge du village.
## Une teinte recopiée aurait laissé ce lien se défaire au premier réglage.
##
## Ni l'une ni l'autre n'est la couleur d'une ressource du catalogue : la barre d'à côté et
## celle-ci se répondraient sans rien vouloir dire.
const WORKERS_COLOR := Color(0.85, 0.68, 0.36)
const IDLE_COLOR := Color(0.48, 0.74, 0.90)

## Opacité d'une pastille dont la part est à zéro.
const EMPTY_SWATCH_ALPHA := 0.28

const TITLE_FONT_SIZE := 16
const LABEL_FONT_SIZE := 12
const AMOUNT_FONT_SIZE := 14
const TOTAL_FONT_SIZE := 12

## Le fond commun aux panneaux du HUD.
static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	return style

## Un libellé de HUD, centré verticalement et qui ne s'enroule jamais.
##
## `AUTOWRAP_OFF` sans exception, et c'est la règle que `P2a` a élargie après que `P1a` l'eut
## tirée à moitié : un `Label` qui s'enroule déclare une largeur minimale minuscule, donc un
## conteneur qui distribue la lui donne. « 20 » se dessine alors « 2 » au-dessus de « 0 » —
## lisible et faux, ce qui est pire qu'illisible — et « Main vide » s'est écrit à la
## verticale pendant trois jalons. Aucun texte du HUD n'a sa largeur bornée par autre chose.
static func text(content: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

## Une pastille de couleur, du côté d'un libellé.
static func swatch(color: Color) -> ColorRect:
	var patch := ColorRect.new()
	patch.color = color
	patch.custom_minimum_size = Vector2(SWATCH, SWATCH)
	patch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return patch

## Une ligne qui laisse passer la souris.
static func row(separation: int = CHIP_GAP) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box

## Une colonne qui laisse passer la souris.
static func column(separation: int = ROW_GAP) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box
