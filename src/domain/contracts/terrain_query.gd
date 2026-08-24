@abstract
class_name TerrainQuery
extends RefCounted
## Face publique du système Terrain : la seule chose que les autres systèmes en voient.
##
## Construction et Combat interrogent le relief à travers ce contrat et n'accèdent
## jamais à la grille elle-même. La représentation interne peut donc changer — dense,
## creuse, découpée en chunks — sans qu'une ligne ne bouge ailleurs.
##
## Trois primitives seulement sont à implémenter : size(), height_at(), terrain_at().
## Tout le reste en découle et est fourni ici, pour que deux implémentations ne
## puissent pas diverger sur le sens de « constructible » ou de « plat ».
##
## Les conventions de bornes sont volontairement asymétriques :
##   - height_at() et terrain_at() exigent une cellule dans la grille. Les appeler
##     ailleurs est un bug de l'appelant, donc un assert.
##   - is_buildable() et les requêtes de zone rendent false hors grille. « Puis-je
##     bâtir ici ? » a une réponse pour une cellule hors carte, et Construction pose
##     couramment des empreintes qui débordent.

## Dimensions de la grille, en cellules : x en largeur, y en profondeur.
@abstract func size() -> Vector2i

## Hauteur de la cellule, en crans de relief. Précondition : in_bounds(cell).
@abstract func height_at(cell: Vector2i) -> int

## Terrain de la cellule, jamais null. Précondition : in_bounds(cell).
@abstract func terrain_at(cell: Vector2i) -> TerrainData

## La cellule tombe-t-elle dans la grille ?
func in_bounds(cell: Vector2i) -> bool:
	var extent := size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < extent.x and cell.y < extent.y

## Peut-on bâtir sur cette cellule ? False hors grille.
func is_buildable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return terrain_at(cell).is_buildable()

## Le terrain de cette cellule porte-t-il ce tag ? False hors grille.
func has_tag(cell: Vector2i, tag: StringName) -> bool:
	if not in_bounds(cell):
		return false
	return terrain_at(cell).has_tag(tag)

## Toutes les cellules de la zone sont-elles constructibles ?
## False si la zone déborde de la grille, ce qui est le cas d'une empreinte posée
## trop près d'un bord.
func is_area_buildable(area: Rect2i) -> bool:
	if not _encloses(area):
		return false
	for cell in _cells_of(area):
		if not terrain_at(cell).is_buildable():
			return false
	return true

## Toutes les cellules de la zone sont-elles à la même hauteur ?
## False si la zone déborde de la grille, par cohérence avec is_area_buildable().
func is_area_flat(area: Rect2i) -> bool:
	if not _encloses(area):
		return false
	return height_span(area) == 0

## Dénivelé de la zone : hauteur la plus haute moins la plus basse, donc 0 sur un
## plateau. Précondition : la zone est non vide et entièrement dans la grille.
func height_span(area: Rect2i) -> int:
	assert(_encloses(area), "zone hors grille : %s dans %s" % [area, size()])
	var lowest := height_at(area.position)
	var highest := lowest
	for cell in _cells_of(area):
		var height := height_at(cell)
		lowest = mini(lowest, height)
		highest = maxi(highest, height)
	return highest - lowest

## La zone est-elle non vide et entièrement contenue dans la grille ?
func _encloses(area: Rect2i) -> bool:
	if area.size.x <= 0 or area.size.y <= 0:
		return false
	return Rect2i(Vector2i.ZERO, size()).encloses(area)

## Cellules de la zone, balayées en x puis en y. Ordre stable : le déterminisme de
## tout ce qui itère sur une zone en dépend.
func _cells_of(area: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			cells.append(Vector2i(x, y))
	return cells
