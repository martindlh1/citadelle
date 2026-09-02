class_name TerrainGenBalance
extends Resource
## Réglages de la génération de terrain, la palette qu'elle pose, et les promesses
## qu'elle doit tenir.
##
## Les chiffres et la palette tiennent dans la même Resource délibérément : décider
## quel terrain sort à quelle altitude ou à quelle densité devient une édition de
## .tres, sans toucher à un .gd.
##
## ---
##
## **Le relief revient au bruit, et les règles deviennent tacites.** La première version de
## `T4` dessinait une mesa — un plateau, une plaine, des rampes numérotées — et rendait des
## cartes qui tenaient toutes leurs promesses en ayant perdu tout leur charme : la forme se
## lisait comme une pièce posée sur une nappe, et l'on voyait le générateur au lieu de voir un
## paysage. Elle est retirée entière.
##
## Ce qui la remplace est du bruit, comme avant, **penché** par quelques règles qui ne se
## voient pas : un centre un peu plus haut, un centre un peu plus calme, des crêtes qui
## barrent parce qu'elles sont hautes et non parce qu'on les a posées là. `shape` dit
## laquelle de ces façons de pencher on essaie — c'est un champ d'**exploration**, et il se
## réduira à ce qu'on aura choisi.
##
## **L'audit, lui, ne change pas d'une ligne**, et c'est ce qui rend l'exploration possible :
## il retrouve le replat central en marchant et compte les accès sans rien savoir de la
## technique. Un vérificateur taillé sur la mesa aurait été à réécrire avec elle.
##
## La dispersion se lit en bandes cumulées sur un tirage unique par cellule :
## [0, forest) donne de la forêt, puis [forest, forest+stone) du gisement, puis
## [.., +rock) du rocher, le reste de la plaine. D'où la contrainte de somme.
##
## Aucun @export ne porte de défaut (voir terrain_balance.gd). Le filet de
## missing_fields() est partiel par nature : il ne peut rattraper que les champs dont
## 0 est une valeur invalide. Pour min_height, water_level ou une densité, 0 est
## légitime — et transite correctement, puisque Godot omet alors la ligne du .tres et
## que le chargement rend bien 0.

## Les façons de pencher le bruit. UNSET vaut 0 pour rester détectable, comme partout.
##
## - `RAW` — le bruit nu, celui d'avant `T4`. Aucune règle, aucune garantie ; il sert de
##   témoin, parce qu'on ne sait pas ce qu'une règle apporte sans la carte qui n'en a pas.
## - `DOME` — le bruit plus un relèvement radial **doux** du centre. La carte reste du bruit
##   de bout en bout ; elle a seulement tendance à culminer au milieu.
## - `CLEARING` — le dôme, plus un lissage progressif du centre et une décoration éclaircie
##   au même endroit. C'est « une zone centrale un peu surélevée et pas trop occupée » pris
##   au mot, sans qu'aucun bord ne soit dessiné.
## - `RIDGES` — deux échelles de bruit, dont une **en crêtes**, plus le dôme. Les barrières
##   sont des lignes de relief, donc les cols apparaissent là où une crête s'affaisse.
enum Shape {
	UNSET = 0,
	RAW = 1,
	DOME = 2,
	CLEARING = 3,
	RIDGES = 4,
}

@export_group("Relief")

## Taille de carte que les appelants passent à TerrainGen.generate(), en cellules.
@export var map_size: Vector2i

## La façon de pencher le bruit. Champ d'exploration : voir Shape.
@export var shape: Shape

## Hauteur la plus basse que la génération peut produire, en crans.
@export_range(-32, 32, 1) var min_height: int

## Hauteur la plus haute que la génération peut produire, en crans.
@export_range(-32, 32, 1) var max_height: int

## Niveau de la nappe d'eau. Toute cellule tirée à cette hauteur ou en dessous
## devient de l'eau et est aplanie à ce niveau. Sous min_height, la carte est sèche.
@export_range(-32, 32, 1) var water_level: int

## Crans qu'un marcheur enjambe d'un pas. Au-delà, la marche barre.
##
## C'est la règle de DESIGN.md 3.1 — « monter coûte, une marche trop haute bloque » — et
## elle vit ici parce que la génération est aujourd'hui son **seul lecteur** : elle compte ses
## accès avec. Une vague de V1 aura la sienne, et le jour où les deux devront être le même
## chiffre, ce champ déménage.
##
## C'est aussi lui qui décide, sur un relief bruité, **ce qui barre** : un cran de plus et la
## carte devient une plaine ouverte, un cran de moins et tout est falaise. Le réglage le plus
## sensible du bloc.
@export_range(1, 32, 1) var max_climb: int

@export_group("Bruit")

## Échelle du relief : plus c'est bas, plus les reliefs sont larges.
@export_range(0.0, 1.0, 0.001) var noise_frequency: float

## Nombre d'octaves du bruit fractal. Au moins 1.
@export_range(1, 8, 1) var noise_octaves: int

## Part du détail que la seconde échelle ajoute, pour `RIDGES`. 0 = une seule échelle.
##
## Les crêtes seules donnent un relief net et un peu nu ; le détail les ébrèche, ce qui est ce
## qui fait qu'un col a l'air trouvé plutôt que posé.
@export_range(0.0, 1.0, 0.01) var detail_share: float

## Fréquence de cette seconde échelle, en multiple de la première.
@export_range(1.0, 16.0, 0.1) var detail_scale: float

@export_group("Centre")

## Crans dont le centre est relevé, au plus.
##
## **Doux et non abrupt** : le relèvement décroît en cloche jusqu'à `dome_radius`, et il
## s'ajoute au bruit **avant** le découpage en crans. Le centre n'a donc pas de bord — il a
## seulement tendance à être plus haut, ce qui est une règle qu'on ressent sans la voir.
@export_range(0.0, 32.0, 0.1) var dome_rise: float

## Portée de ce relèvement, en cellules.
@export_range(0, 128, 1) var dome_radius: int

## Portée du lissage central, en cellules. 0 = pas de lissage. Lu par `CLEARING`.
@export_range(0, 128, 1) var clearing_radius: int

## Force de ce lissage au centre même, de 0 à 1.
##
## À 1 le centre est plat comme une table — c'est la mesa qu'on vient de retirer. Entre 0,4 et
## 0,7 il garde son grain tout en offrant de quoi bâtir, ce qui est le point de la règle.
@export_range(0.0, 1.0, 0.01) var clearing_flatten: float

## Part de la décoration qui subsiste au centre même, de 0 à 1. Lu par `CLEARING`.
##
## « Pas trop occupée » : moins de rochers et moins d'arbres au milieu, sans que la limite
## se voie. La décroissance est la même cloche que le reste.
@export_range(0.0, 1.0, 0.01) var clearing_calm: float

@export_group("Dispersion")

## Part des cellules non aquatiques couvertes de forêt, avant filtre d'altitude.
@export_range(0.0, 1.0, 0.01) var forest_density: float

## Part des cellules non aquatiques portant un gisement.
@export_range(0.0, 1.0, 0.01) var stone_density: float

## Part des cellules non aquatiques bloquées par un rocher.
@export_range(0.0, 1.0, 0.01) var rock_density: float

## Altitude au-dessus de laquelle la forêt ne pousse plus. Une cellule tirée en
## forêt trop haut retombe en plaine, sans décaler les bandes suivantes.
@export_range(-32, 32, 1) var forest_max_height: int

@export_group("Promesses")

## Cellules bâtissables que le replat central doit porter au minimum.
@export_range(1, 4096, 1) var min_plateau_cells: int

## Accès distincts que ce replat doit avoir au minimum.
@export_range(1, 32, 1) var min_accesses: int

## Accès distincts qu'il peut avoir au maximum.
@export_range(1, 32, 1) var max_accesses: int

## Emplacements 2x2 plats et bâtissables que la carte entière doit offrir au minimum.
@export_range(0, 4096, 1) var min_build_pads: int

## Gisements bâtissables que le replat doit porter au minimum.
@export_range(0, 512, 1) var min_plateau_deposits: int

## Seeds dérivés à essayer avant d'abandonner.
##
## Un plafond et non une boucle infinie : un jeu de réglages impossible à satisfaire doit
## s'arrêter en le disant plutôt que de tourner sans fin sur un écran de chargement.
@export_range(1, 256, 1) var max_attempts: int

@export_group("Palette")

## Terrain par défaut des cellules émergées.
@export var plain: TerrainData

## Terrain posé par la bande de forêt.
@export var forest: TerrainData

## Terrain posé par la bande de gisement.
@export var stone: TerrainData

## Terrain posé au niveau de la nappe et en dessous.
@export var water: TerrainData

## Terrain posé par la bande de rocher.
@export var rock: TerrainData

## Champs inexploitables : non renseignés, ou incohérents entre eux. Vide = bloc
## exploitable. Le boot refuse de démarrer tant que ce n'est pas vide.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if map_size.x <= 0 or map_size.y <= 0:
		missing.append("map_size")
	if shape == Shape.UNSET:
		missing.append("shape")
	if max_height < min_height:
		missing.append("max_height")
	if max_climb < 1:
		missing.append("max_climb")
	if noise_frequency <= 0.0:
		missing.append("noise_frequency")
	if noise_octaves < 1:
		missing.append("noise_octaves")
	if detail_scale < 1.0:
		missing.append("detail_scale")
	if forest_density + stone_density + rock_density > 1.0:
		missing.append("densities_sum")
	if min_plateau_cells < 1:
		missing.append("min_plateau_cells")
	if min_accesses < 1:
		missing.append("min_accesses")
	if max_accesses < min_accesses:
		missing.append("max_accesses")
	if max_attempts < 1:
		missing.append("max_attempts")
	_require(missing, "plain", plain)
	_require(missing, "forest", forest)
	_require(missing, "stone", stone)
	_require(missing, "water", water)
	_require(missing, "rock", rock)
	return missing

## Signale un terrain de palette absent sous le nom de son champ.
func _require(missing: PackedStringArray, field: String, terrain: TerrainData) -> void:
	if terrain == null:
		missing.append(field)
