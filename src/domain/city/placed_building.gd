class_name PlacedBuilding
extends RefCounted
## Un bâtiment posé sur la carte : son contenu, son ancre, sa hauteur.
##
## Immuable. La ville en crée un à la pose et le jette au retrait ; rien ne déplace un
## bâtiment posé, et le déplacer reviendrait de toute façon à valider un nouveau
## placement.
##
## La hauteur est stockée ici plutôt que relue sur le terrain à chaque besoin. Elle
## n'est bien définie que parce qu'un bâtiment exige toutes ses cellules à la même
## hauteur — c'est le bénéfice direct de cette règle, et c'est ce qui permettra au
## rendu de C2 de savoir où poser la boîte sans reparcourir l'empreinte ni interroger
## la grille.

var _data: BuildingData
var _anchor: Vector2i
var _height: int

## Bâtiment posé sur cette ancre, à cette hauteur.
static func create(data: BuildingData, anchor: Vector2i, height: int) -> PlacedBuilding:
	assert(data != null, "bâtiment posé sans données")
	assert(not data.footprint.is_empty(), "bâtiment posé sans empreinte : %s" % data.id)
	var building := PlacedBuilding.new()
	building._data = data
	building._anchor = anchor
	building._height = height
	return building

## Contenu du bâtiment : son identité, son empreinte, et ce que les systèmes suivants
## y ajouteront.
func data() -> BuildingData:
	return _data

## Cellule d'ancrage. C'est la clé sous laquelle la ville le range.
func anchor() -> Vector2i:
	return _anchor

## Hauteur commune de ses cellules, en crans.
func height() -> int:
	return _height

## Cellules absolues qu'il occupe, dans l'ordre de son empreinte.
func cells() -> Array[Vector2i]:
	return _data.cells_at(_anchor)
