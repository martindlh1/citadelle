class_name CameraBalance
extends Resource
## Réglages de la caméra isométrique : zoom, pan, durée de rotation, cadrage.
##
## Ce ne sont pas des chiffres d'équilibrage de jeu, mais ce sont des chiffres
## réglables, et TerrainBalance a déjà posé le précédent avec tile_size et
## step_height. Les régler ne doit pas être une édition de GDScript.
##
## Ce qui n'est PAS ici : le piqué de -35.264°. C'est l'isométrique vrai, une décision
## figée de CLAUDE.md et non un réglage — il vit en constante nommée dans CameraRig.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

@export_group("Zoom")

## Taille orthographique la plus serrée, en unités de monde sur la hauteur d'écran.
@export_range(0.0, 200.0, 0.5) var zoom_min: float

## Taille orthographique la plus large. Doit dépasser zoom_min.
@export_range(0.0, 400.0, 0.5) var zoom_max: float

## Facteur appliqué par cran de molette. Doit dépasser 1 : à 1 la molette ne fait rien.
@export_range(1.0, 2.0, 0.01) var zoom_factor: float

@export_group("Déplacement")

## Vitesse du pan au clavier, en hauteurs d'écran par seconde. L'exprimer à l'écran
## et non dans le monde rend la vitesse ressentie indépendante du zoom.
@export_range(0.0, 5.0, 0.05) var pan_speed: float

## Durée d'un quart de tour, en secondes.
@export_range(0.0, 2.0, 0.05) var rotation_seconds: float

@export_group("Cadrage")

## Marge appliquée au cadrage initial. 1.0 colle aux bords, au-delà prend du recul.
@export_range(0.0, 2.0, 0.05) var frame_margin: float

## Champs inexploitables : non renseignés, ou incohérents entre eux.
## Vide = bloc exploitable. Le boot refuse de démarrer tant que ce n'est pas vide.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if zoom_min <= 0.0:
		missing.append("zoom_min")
	if zoom_max <= zoom_min:
		missing.append("zoom_max")
	if zoom_factor <= 1.0:
		missing.append("zoom_factor")
	if pan_speed <= 0.0:
		missing.append("pan_speed")
	if rotation_seconds <= 0.0:
		missing.append("rotation_seconds")
	if frame_margin <= 0.0:
		missing.append("frame_margin")
	return missing
