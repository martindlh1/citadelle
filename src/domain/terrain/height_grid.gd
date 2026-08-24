class_name HeightGrid
extends RefCounted
## Le relief : une hauteur entière et un terrain par cellule.
##
## C'est l'état interne du système Terrain, et les autres systèmes ne le voient
## jamais. Ils reçoivent la vue en lecture seule que rend to_query().
##
## La représentation est dense, indexée y * largeur + x : la grille est rectangulaire
## et toutes ses cellules sont remplies, un Dictionary ne paierait que du surcoût
## mémoire et d'indirection. C'est précisément ce que le contrat rend invisible —
## passer à une représentation creuse ou découpée ne toucherait personne d'autre.

var _size: Vector2i
var _heights: PackedInt32Array
var _terrain: Array[TerrainData]

## Grille pleine, toutes ses cellules à la même hauteur et au même terrain.
static func create(size: Vector2i, fill_height: int, fill_terrain: TerrainData) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de grille non positive : %s" % size)
	assert(fill_terrain != null, "terrain de remplissage null")
	var grid := HeightGrid.new()
	grid._size = size
	var count := size.x * size.y
	grid._heights.resize(count)
	grid._heights.fill(fill_height)
	grid._terrain.resize(count)
	grid._terrain.fill(fill_terrain)
	return grid

## Dimensions de la grille, en cellules.
func size() -> Vector2i:
	return _size

## La cellule tombe-t-elle dans la grille ?
func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y

## Hauteur de la cellule, en crans. Précondition : in_bounds(cell).
func height_at(cell: Vector2i) -> int:
	assert(in_bounds(cell), "cellule hors grille : %s dans %s" % [cell, _size])
	return _heights[_index(cell)]

## Terrain de la cellule, jamais null. Précondition : in_bounds(cell).
func terrain_at(cell: Vector2i) -> TerrainData:
	assert(in_bounds(cell), "cellule hors grille : %s dans %s" % [cell, _size])
	return _terrain[_index(cell)]

## Écrit hauteur et terrain d'un coup. Précondition : in_bounds(cell).
func set_cell(cell: Vector2i, height: int, terrain: TerrainData) -> void:
	assert(in_bounds(cell), "cellule hors grille : %s dans %s" % [cell, _size])
	assert(terrain != null, "terrain null en %s" % cell)
	var index := _index(cell)
	_heights[index] = height
	_terrain[index] = terrain

## Écrit la seule hauteur. Précondition : in_bounds(cell).
func set_height(cell: Vector2i, height: int) -> void:
	assert(in_bounds(cell), "cellule hors grille : %s dans %s" % [cell, _size])
	_heights[_index(cell)] = height

## Écrit le seul terrain — c'est ce que fait le déblaiement d'une forêt.
## Précondition : in_bounds(cell).
func set_terrain(cell: Vector2i, terrain: TerrainData) -> void:
	assert(in_bounds(cell), "cellule hors grille : %s dans %s" % [cell, _size])
	assert(terrain != null, "terrain null en %s" % cell)
	_terrain[_index(cell)] = terrain

## Vue en lecture seule de cette grille, à passer aux autres systèmes.
## C'est une vue et non une copie : la grille reste la source de vérité.
func to_query() -> TerrainQuery:
	return GridTerrainQuery.new(self)

func _index(cell: Vector2i) -> int:
	return cell.y * _size.x + cell.x
