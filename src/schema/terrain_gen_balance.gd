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
## **T4 la réécrit en trois blocs, et l'ordre raconte la méthode** de DESIGN.md 3.1 :
## « poser la structure, décorer au bruit ». La *Structure* dit la forme garantie — un
## plateau central, une plaine plus basse, des rampes ; la *Décoration* n'a le droit d'y
## ajouter que ce qui ne peut pas la défaire ; les *Promesses* sont ce qu'une carte doit
## mesurer pour être acceptée, et un seed qui n'y arrive pas est rejeté.
##
## **Deux contrôles de missing_fields() valent plus que tout le reste**, parce qu'ils rendent
## la garantie **structurelle** au lieu de vérifiée. Une plaine dont le point le plus haut
## reste hors d'enjambée du plateau ne peut pas ouvrir un accès que personne n'a voulu, quel
## que soit le bruit qu'on y jette ; une nappe sous la plaine ne peut pas noyer le plateau.
## C'est le même geste que le `carry_over` du jeu d'avant, qui refusait une valeur plutôt que
## de l'interpréter : le jour où l'on voudra une plaine qui touche le plateau, c'est le
## contrôle qui se desserre, pas la génération qui se met à espérer.
##
## min_height et max_height ont disparu avec le bruit pur : l'amplitude du relief n'est plus
## une entrée, c'est une **conséquence** de la structure — de la nappe au plateau.
##
## La dispersion se lit en bandes cumulées sur un tirage unique par cellule :
## [0, forest) donne de la forêt, puis [forest, forest+stone) du gisement, puis
## [.., +rock) du rocher, le reste de la plaine. D'où la contrainte de somme.
##
## Aucun @export ne porte de défaut (voir terrain_balance.gd). Le filet de
## missing_fields() est partiel par nature : il ne peut rattraper que les champs dont
## 0 est une valeur invalide. Pour water_level ou une densité, 0 est légitime — et transite
## correctement, puisque Godot omet alors la ligne du .tres et que le chargement rend bien 0.

@export_group("Structure")

## Taille de carte que les appelants passent à TerrainGen.generate(), en cellules.
@export var map_size: Vector2i

## Hauteur du plateau central, en crans. C'est le niveau où l'on fonde et où l'on bâtit.
@export_range(-32, 32, 1) var plateau_height: int

## Rayon nominal du plateau, en cellules. Son bord est déformé par plateau_jitter.
@export_range(1, 64, 1) var plateau_radius: int

## Part du rayon dont le bord du plateau peut s'écarter, en fraction.
##
## À 0 le plateau est un disque, ce qui se lit comme une pièce de monnaie posée sur la
## carte. Ce n'est pas qu'une question de goût : un bord régulier place tous les cols à la
## même distance du centre, donc les rend interchangeables, et « quel col je tiens » perd sa
## réponse.
@export_range(0.0, 1.0, 0.01) var plateau_jitter: float

## Hauteur de base de la plaine qui entoure le plateau, en crans.
@export_range(-32, 32, 1) var lowland_height: int

## Crans de relief que le bruit ajoute par-dessus cette base.
##
## Borné, et c'est ce qui rend la structure inviolable : le point le plus haut de la plaine
## est lowland_height + lowland_relief, et missing_fields() exige qu'il reste hors
## d'enjambée du plateau.
@export_range(0, 32, 1) var lowland_relief: int

## Niveau de la nappe d'eau. Toute cellule de plaine tirée à cette hauteur ou en dessous
## devient de l'eau et est aplanie à ce niveau.
@export_range(-32, 32, 1) var water_level: int

## Crans qu'un marcheur enjambe d'un pas. Au-delà, la marche barre.
##
## C'est la règle de DESIGN.md 3.1 — « monter coûte, une marche trop haute bloque » — et
## elle vit ici parce que la génération est aujourd'hui son **seul lecteur** : elle taille
## ses rampes dessus et compte ses accès avec. Une vague de V1 aura la sienne, et le jour où
## les deux devront être le même chiffre, ce champ déménage. Un contrat inventé maintenant
## pour un consommateur qui n'existe pas est ce que ce projet refuse depuis toujours.
@export_range(1, 32, 1) var max_climb: int

## Largeur d'une rampe, en cellules.
##
## Une rampe est un col : c'est là qu'une tour sert à quelque chose, donc elle doit être
## assez large pour qu'on y bâtisse et assez étroite pour que la tenir veuille dire quelque
## chose. Un caillou tombé dessus peut la boucher, et c'est l'audit qui le constate.
@export_range(1, 8, 1) var ramp_width: int

@export_group("Décoration")

## Échelle du relief : plus c'est bas, plus les reliefs sont larges.
@export_range(0.0, 1.0, 0.001) var noise_frequency: float

## Nombre d'octaves du bruit fractal. Au moins 1.
@export_range(1, 8, 1) var noise_octaves: int

## Part de la plaine noyée sous la nappe.
##
## Les mares suivent un bruit propre plutôt qu'un tirage par cellule : de l'eau tirée case
## par case donnerait des flaques d'une cellule éparpillées, là où un bruit lissé donne des
## étangs. C'est aussi ce qui leur permet de barrer — une flaque isolée ne barre rien.
@export_range(0.0, 1.0, 0.01) var water_share: float

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

## Cellules bâtissables qu'un plateau doit porter au minimum.
@export_range(1, 4096, 1) var min_plateau_cells: int

## Accès distincts qu'un plateau doit avoir au minimum. « Jamais un » (DESIGN.md 3.1).
@export_range(1, 32, 1) var min_accesses: int

## Accès distincts qu'un plateau peut avoir au maximum. « Jamais douze ».
@export_range(1, 32, 1) var max_accesses: int

## Emplacements 2x2 plats et bâtissables que la carte entière doit offrir au minimum.
@export_range(0, 4096, 1) var min_build_pads: int

## Gisements bâtissables que le plateau doit porter au minimum.
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

## Le point le plus haut que la plaine puisse atteindre.
func lowland_ceiling() -> int:
	return lowland_height + lowland_relief

## Champs inexploitables : non renseignés, ou incohérents entre eux. Vide = bloc
## exploitable. Le boot refuse de démarrer tant que ce n'est pas vide.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if map_size.x <= 0 or map_size.y <= 0:
		missing.append("map_size")
	if plateau_radius < 1:
		missing.append("plateau_radius")
	if lowland_relief < 0:
		missing.append("lowland_relief")
	if max_climb < 1:
		missing.append("max_climb")
	if ramp_width < 1:
		missing.append("ramp_width")
	missing.append_array(_structure_fields())
	if noise_frequency <= 0.0:
		missing.append("noise_frequency")
	if noise_octaves < 1:
		missing.append("noise_octaves")
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

## Les deux incohérences qui feraient mentir la garantie de DESIGN.md 3.1.
##
## Elles sont à part des autres parce qu'elles ne disent pas « ce champ est vide » mais
## « ces champs ensemble ne décrivent pas une mesa ». Ce sont elles qui permettent à la
## génération de **ne pas espérer** : tant qu'elles tiennent, aucun bruit jeté sur la plaine
## ne peut ouvrir un accès, et aucune nappe ne peut monter sur le plateau.
func _structure_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	# Le plateau doit surplomber la plaine de plus d'une enjambée, sinon on y monte
	# n'importe où et les rampes ne sont plus des cols mais de la décoration.
	if plateau_height - lowland_ceiling() <= max_climb:
		missing.append("plateau_height")
	# La nappe doit rester sous la plaine, sinon la carte est un lac.
	if water_level >= lowland_height:
		missing.append("water_level")
	return missing

## Signale un terrain de palette absent sous le nom de son champ.
func _require(missing: PackedStringArray, field: String, terrain: TerrainData) -> void:
	if terrain == null:
		missing.append(field)
