class_name TerrainBalance
extends Resource
## Réglages géométriques du terrain, en unités de monde.
##
## Ces valeurs ne doivent jamais être recopiées dans un .gd : le rendu comme le
## picking passent par GameDatabase.get_balance().terrain.
##
## Aucun @export ne porte de défaut, volontairement. Godot n'écrit pas dans un .tres
## une propriété égale à son défaut : en donner un ferait remonter le chiffre dans ce
## fichier au premier réenregistrement par l'éditeur, et le data se viderait en
## silence. Un champ non renseigné vaut donc 0 et est rattrapé par missing_fields().

## Côté d'une cellule de la grille.
@export_range(0.0, 10.0, 0.05) var tile_size: float

## Élévation d'un cran de relief. Une cellule de hauteur h monte à h * step_height.
@export_range(0.0, 5.0, 0.05) var step_height: float

## Champs non renseignés. Vide = bloc exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if tile_size <= 0.0:
		missing.append("tile_size")
	if step_height <= 0.0:
		missing.append("step_height")
	return missing
