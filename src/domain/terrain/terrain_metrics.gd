class_name TerrainMetrics
extends RefCounted
## Passage grille <-> monde : où se trouve une cellule, et quelle cellule est là.
##
## Fonction pure, aucun Node. C'est le rendu qui la consomme aujourd'hui et le
## CellPicker qui la consommera à T3 — deux fois le système Terrain, donc pas un
## contrat. Si Construction en a besoin directement, ce sera le moment de la promouvoir,
## pas avant.
##
## Trois conventions y sont fixées une fois pour toutes :
##
##   - La cellule (0, 0) occupe [0, tile) x [0, tile) en XZ. L'origine du monde est
##     donc au COIN de la carte, pas à son centre : cell_at() reste un floor sans
##     décalage, ce dont le DDA de T3 a besoin. Recentrer la carte à l'écran devient
##     un travail de caméra, pas de grille.
##   - Grille +x -> monde +X, grille +y -> monde +Z.
##   - Une cellule de hauteur h a sa FACE SUPÉRIEURE à y = h * step_height. C'est
##     l'invariant du système : ni le socle sous la colonne, ni l'épaisseur qu'un
##     renderer lui donne ne le déplacent.

var _tile_size: float
var _step_height: float

## Métrique pour ces dimensions. Les deux doivent être strictement positives : une
## cellule plate ou un cran nul écraseraient le monde sur un plan.
static func create(tile_size: float, step_height: float) -> TerrainMetrics:
	assert(tile_size > 0.0, "taille de cellule non positive : %f" % tile_size)
	assert(step_height > 0.0, "hauteur de cran non positive : %f" % step_height)
	var metrics := TerrainMetrics.new()
	metrics._tile_size = tile_size
	metrics._step_height = step_height
	return metrics

## Métrique tirée du bloc d'équilibrage. Le domaine reçoit la Resource en argument —
## il ne lit jamais GameDatabase lui-même, comme TerrainGen.generate().
static func from_balance(balance: TerrainBalance) -> TerrainMetrics:
	assert(balance != null, "réglages de terrain null")
	return create(balance.tile_size, balance.step_height)

## Côté d'une cellule, en unités de monde.
func tile_size() -> float:
	return _tile_size

## Élévation d'un cran de relief, en unités de monde.
func step_height() -> float:
	return _step_height

## Y de la face supérieure d'une cellule à cette hauteur.
func surface_y(height: int) -> float:
	return height * _step_height

## Centre d'une cellule dans le plan XZ, à y = 0.
func cell_center_xz(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * _tile_size,
		0.0,
		(cell.y + 0.5) * _tile_size)

## Centre de la face supérieure d'une cellule à cette hauteur : le point sur lequel
## un bâtiment se pose.
func cell_surface_center(cell: Vector2i, height: int) -> Vector3:
	var center := cell_center_xz(cell)
	center.y = surface_y(height)
	return center

## Cellule qui contient ce point, projeté sur XZ. La hauteur du point est ignorée.
##
## Rend volontiers une cellule hors grille pour un point hors carte : c'est à
## l'appelant de tester in_bounds(). Le découpage est un floor et non une troncature —
## à gauche de l'origine, int() ramènerait -0.3 sur 0 et collerait deux cellules l'une
## sur l'autre.
func cell_at(position: Vector3) -> Vector2i:
	return Vector2i(
		floori(position.x / _tile_size),
		floori(position.z / _tile_size))

## Emprise au sol d'une grille de cette taille, en unités de monde.
func world_extent(size: Vector2i) -> Vector2:
	assert(size.x > 0 and size.y > 0, "taille de grille non positive : %s" % size)
	return Vector2(size.x, size.y) * _tile_size

## Centre d'une grille de cette taille dans le plan XZ, à y = 0. C'est le point que la
## caméra vise à l'ouverture.
func world_center(size: Vector2i) -> Vector3:
	var extent := world_extent(size)
	return Vector3(extent.x * 0.5, 0.0, extent.y * 0.5)
