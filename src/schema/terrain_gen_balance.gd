class_name TerrainGenBalance
extends Resource
## Réglages de la génération de terrain, et la palette de terrains qu'elle pose.
##
## Les chiffres et la palette tiennent dans la même Resource délibérément : décider
## quel terrain sort à quelle altitude ou à quelle densité devient une édition de
## .tres, sans toucher à un .gd.
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

@export_group("Relief")

## Taille de carte que les appelants passent à TerrainGen.generate(), en cellules.
@export var map_size: Vector2i

## Hauteur la plus basse que la génération peut produire, en crans.
@export_range(-32, 32, 1) var min_height: int

## Hauteur la plus haute que la génération peut produire, en crans.
@export_range(-32, 32, 1) var max_height: int

## Niveau de la nappe d'eau. Toute cellule tirée à cette hauteur ou en dessous
## devient de l'eau et est aplanie à ce niveau. Sous min_height, la carte est sèche.
@export_range(-32, 32, 1) var water_level: int

@export_group("Bruit")

## Échelle du relief : plus c'est bas, plus les reliefs sont larges.
@export_range(0.0, 1.0, 0.001) var noise_frequency: float

## Nombre d'octaves du bruit fractal. Au moins 1.
@export_range(1, 8, 1) var noise_octaves: int

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
	if max_height < min_height:
		missing.append("max_height")
	if noise_frequency <= 0.0:
		missing.append("noise_frequency")
	if noise_octaves < 1:
		missing.append("noise_octaves")
	if forest_density + stone_density + rock_density > 1.0:
		missing.append("densities_sum")
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
