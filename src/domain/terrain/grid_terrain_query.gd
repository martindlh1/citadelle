class_name GridTerrainQuery
extends TerrainQuery
## Adosse le contrat TerrainQuery à une HeightGrid vivante.
##
## Vue et non copie : la grille reste la source de vérité, donc déblayer une forêt à
## la construction se voit immédiatement à travers la query, sans invalidation ni
## reconstruction.
##
## Trois méthodes suffisent — constructibilité, tags, planéité et dénivelé sont
## dérivés par le contrat lui-même. Aucun mutateur n'est exposé.

var _grid: HeightGrid

func _init(grid: HeightGrid) -> void:
	assert(grid != null, "query sans grille")
	_grid = grid

func size() -> Vector2i:
	return _grid.size()

func height_at(cell: Vector2i) -> int:
	return _grid.height_at(cell)

func terrain_at(cell: Vector2i) -> TerrainData:
	return _grid.terrain_at(cell)
