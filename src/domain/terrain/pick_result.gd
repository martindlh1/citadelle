class_name PickResult
extends RefCounted
## Ce qu'un rayon a rencontré sur la grille : une cellule, ou rien.
##
## Un tir qui ne touche rien n'est pas une erreur — c'est le résultat normal d'un
## curseur pointé sur le ciel. D'où is_hit(), et non le { ok, reason } que les
## conventions réservent aux erreurs récupérables.
##
## Le résultat vit dans domain/terrain/ et non dans contracts/ : à T3, seul l'adapter
## du Terrain le consomme. Il se promeut le jour où Construction en aura besoin pour
## son fantôme de placement, pas avant.

var _is_hit: bool
var _cell: Vector2i
var _height: int
var _position: Vector3

## Le rayon n'a rencontré aucune colonne.
static func miss() -> PickResult:
	return PickResult.new()

## Le rayon a touché cette cellule, dont la colonne monte à `height` crans, au point
## `position` exprimé en unités de monde.
static func hit_at(cell: Vector2i, height: int, position: Vector3) -> PickResult:
	var result := PickResult.new()
	result._is_hit = true
	result._cell = cell
	result._height = height
	result._position = position
	return result

## Le rayon a-t-il rencontré une colonne ?
func is_hit() -> bool:
	return _is_hit

## Cellule touchée. Précondition : is_hit().
func cell() -> Vector2i:
	assert(_is_hit, "cellule demandée à un tir qui n'a rien touché")
	return _cell

## Hauteur de la colonne touchée, en crans. Précondition : is_hit().
func height() -> int:
	assert(_is_hit, "hauteur demandée à un tir qui n'a rien touché")
	return _height

## Point d'impact, en unités de monde.
##
## Sur une face supérieure, son y vaut exactement celui de la surface — c'est là
## qu'un bâtiment se posera. Sur un flanc, il est plus bas, et ses coordonnées XZ
## tombent pile sur une arête entre deux cellules : ne pas le repasser à cell_at()
## pour retrouver la cellule, elle est déjà là.
##
## Précondition : is_hit().
func position() -> Vector3:
	assert(_is_hit, "point d'impact demandé à un tir qui n'a rien touché")
	return _position
