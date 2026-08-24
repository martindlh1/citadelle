class_name TerrainBalance
extends Resource
## Réglages géométriques du terrain, en unités de monde.
##
## Ces valeurs ne doivent jamais être recopiées dans un .gd : le rendu comme
## le picking passent par GameDatabase.get_balance().terrain.

## Côté d'une cellule de la grille.
@export_range(0.1, 10.0, 0.1) var tile_size: float = 1.0

## Élévation d'un cran de relief. Une cellule de hauteur h monte à h * step_height.
@export_range(0.05, 5.0, 0.05) var step_height: float = 0.25
