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
## barrent parce qu'elles sont hautes et non parce qu'on les a posées là.
##
## **Et le village ne s'installe plus au centre, mais au plus près du centre.** C'est ce qui
## rend le reste tenable : un bruit n'a aucune raison de laisser une place à bâtir sur une case
## désignée d'avance, et l'exiger revenait à noter la carte sur un pixel. Voir
## `min_plateau_cells` et `max_site_drift`, qui disent ensemble ce qu'on cherche et jusqu'où.
##
## **L'audit, lui, ne sait toujours rien de la technique**, et c'est ce qui rend l'exploration
## possible : il cherche le replat en marchant et compte les accès en marchant. Un vérificateur
## taillé sur la mesa aurait été à réécrire avec elle.
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

## La nature du bruit de fond. UNSET vaut 0 pour rester détectable, comme partout.
##
## **Deux valeurs et non quatre**, parce que ce ne sont pas quatre techniques mais **trois
## axes qui se combinent** : la nature du bruit, la colline centrale, et la clairière. Les
## avoir empilés dans un seul enum interdisait justement la combinaison qu'on voulait — des
## crêtes *et* une colline au milieu. Les deux autres axes sont des nombres, et un nombre à
## zéro éteint son effet.
##
## - `FRACTAL` — le bruit fractal ordinaire : des collines rondes, des vallées larges.
## - `RIDGED` — le même en crêtes : des arêtes, des cirques, des cols. Plus beau et plus
##   découpé, donc moins de place à bâtir — c'est l'arbitrage de cet axe.
enum Relief {
	UNSET = 0,
	FRACTAL = 1,
	RIDGED = 2,
}

@export_group("Relief")

## Taille de carte que les appelants passent à TerrainGen.generate(), en cellules.
@export var map_size: Vector2i

## La nature du bruit de fond. Voir Relief.
@export var relief: Relief

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

## Portée du lissage central, en cellules. **0 = pas de lissage du tout.**
@export_range(0, 128, 1) var clearing_radius: int

## Force de ce lissage au centre même, de 0 à 1.
##
## À 1 le centre est plat comme une table — c'est la mesa qu'on vient de retirer. Entre 0,4 et
## 0,7 il garde son grain tout en offrant de quoi bâtir, ce qui est le point de la règle.
@export_range(0.0, 1.0, 0.01) var clearing_flatten: float

## Part de la décoration qui subsiste au centre même, de 0 à 1. **1 = rien n'est éclairci.**
##
## « Pas trop occupée » : moins de rochers et moins d'arbres au milieu, sans que la limite
## se voie. La décroissance est la même cloche que le reste.
@export_range(0.0, 1.0, 0.01) var clearing_calm: float

@export_group("Eau")

## Cellules qu'une étendue d'eau doit compter pour rester. En dessous, elle est comblée.
##
## **Un lac ou rien.** Un relief découpé en crans laisse partout des cuvettes d'une ou deux
## cases sous le niveau de la nappe, et chacune devient une flaque : la carte se retrouve
## mouchetée de bleu, ce qui est laid et surtout **sans conséquence** — une flaque d'une case
## ne barre rien, ne se contourne pas, ne veut rien dire. Ce qu'on veut est un lac : quelque
## chose qu'on longe.
@export_range(1, 512, 1) var min_lake_cells: int

@export_group("Dispersion")

## Finesse des zones de décoration, en multiple de la fréquence du relief.
##
## La décoration suit son **propre bruit**, pas un tirage par cellule : c'est ce qui fait des
## bosquets, des futaies et des éboulis au lieu d'un semis uniforme. Plus haut que 1, les
## taches sont plus petites que les reliefs — une forêt tient dans une vallée plutôt que de
## couvrir la moitié de la carte.
@export_range(0.5, 16.0, 0.1) var decor_scale: float

## Part des cellules non aquatiques couvertes de forêt, avant filtre d'altitude.
##
## Une **part exacte** et non un seuil : les cellules sont classées par le bruit de la famille
## et l'on prend les meilleures jusqu'à ce compte. Comparer le bruit au chiffre paraît
## équivalent et ne l'est pas — un bruit se serre autour de sa moyenne, donc « vingt pour
## cent » y donne à peu près n'importe quoi. Le piège a déjà coûté une passe sur l'eau.
@export_range(0.0, 1.0, 0.01) var forest_density: float

## Part des cellules non aquatiques portant un gisement.
@export_range(0.0, 1.0, 0.01) var stone_density: float

## Part des cellules non aquatiques bloquées par un rocher.
@export_range(0.0, 1.0, 0.01) var rock_density: float

## Penchant de la forêt pour l'altitude : négatif pour les fonds, positif pour les hauteurs.
##
## C'est la seconde moitié de la « logique » d'une carte, et elle compte autant que les
## taches : une forêt qui pousse aussi bien au bord d'un lac qu'au sommet d'une crête n'a pas
## l'air d'avoir poussé. Le penchant s'ajoute au bruit de la famille avant le classement, donc
## il **incline** sans jamais interdire — on trouve encore un bosquet en hauteur.
@export_range(-2.0, 2.0, 0.05) var forest_height_bias: float

## Penchant du gisement pour l'altitude.
@export_range(-2.0, 2.0, 0.05) var stone_height_bias: float

## Penchant du rocher pour l'altitude. Positif, les éboulis coiffent les sommets.
@export_range(-2.0, 2.0, 0.05) var rock_height_bias: float

## Altitude au-dessus de laquelle la forêt ne pousse plus, quel que soit son penchant.
@export_range(-32, 32, 1) var forest_max_height: int

@export_group("Promesses")

## Cellules bâtissables qu'un replat doit offrir pour qu'on veuille bien s'y installer.
##
## **C'est une consigne de recherche avant d'être un seuil**, et la nuance est ce qui a
## remplacé la mesa. L'audit cherche le replat de cette taille le plus proche du centre ; il ne
## rejette la carte que s'il n'en trouve **nulle part**, ce qui veut dire un relief où aucun
## village ne tiendrait. Le filtre utile, celui qui mord, est `max_site_drift`.
@export_range(1, 4096, 1) var min_plateau_cells: int

## Cases dont le village peut s'écarter du milieu de la carte, en anneaux.
##
## Fonder au centre exact n'a pas de sens sur un relief bruité — c'est souvent un pic —, mais
## fonder n'importe où non plus : un village adossé à la lisière n'a pas de terrain devant lui,
## donc pas de bataille. Ce chiffre est l'écart qu'on tolère entre les deux, et c'est **le**
## réglage qui décide combien de brouillons partent à la poubelle.
## À zéro le village devrait tomber sur le milieu exact, ce qui est justement la contrainte
## qu'on vient de retirer : la valeur est refusée au boot plutôt que d'être interprétée.
@export_range(1, 128, 1) var max_site_drift: int

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
	if relief == Relief.UNSET:
		missing.append("relief")
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
	if decor_scale <= 0.0:
		missing.append("decor_scale")
	if min_lake_cells < 1:
		missing.append("min_lake_cells")
	if forest_density + stone_density + rock_density > 1.0:
		missing.append("densities_sum")
	if min_plateau_cells < 1:
		missing.append("min_plateau_cells")
	if max_site_drift < 1:
		missing.append("max_site_drift")
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
