class_name BuildingSnapshot
extends RefCounted
## Un bâtiment posé, tel que les autres systèmes le voient.
##
## C'est la projection de PlacedBuilding, qui vit dans domain/city/ et n'a donc pas à
## traverser la frontière : l'Économie qui en dépendrait dépendrait des internes de
## Construction.
##
## Il porte exactement ce que PlacedBuilding sait déjà — c'est une projection, pas une
## invention, et rien n'y est ajouté d'avance pour un consommateur qui n'existe pas.
## Les PV que le Combat voudra viendront à F1, avec le champ qui les porte.
##
## Immuable. La ville en fabrique une série à chaque to_snapshot() et les jette après.

var _data: BuildingData
var _anchor: Vector2i
var _height: int
var _turns: int

## Projection d'un bâtiment posé sur cette ancre, à cette hauteur, dans cette
## orientation.
static func create(data: BuildingData, anchor: Vector2i, height: int,
		turns: int = 0) -> BuildingSnapshot:
	assert(data != null, "instantané de bâtiment sans données")
	var snapshot := BuildingSnapshot.new()
	snapshot._data = data
	snapshot._anchor = anchor
	snapshot._height = height
	snapshot._turns = posmod(turns, BuildingData.QUARTER_TURNS)
	return snapshot

## Contenu du bâtiment : son identité, son empreinte, son bloc économie.
func data() -> BuildingData:
	return _data

## Cellule d'ancrage. C'est la clé sous laquelle une affectation le désigne.
func anchor() -> Vector2i:
	return _anchor

## Hauteur commune de ses cellules, en crans.
func height() -> int:
	return _height

## Orientation dans laquelle il a été posé, en quarts de tour, toujours dans [0, 3].
func turns() -> int:
	return _turns

## Cellules absolues qu'il occupe, dans l'ordre de son empreinte et dans son
## orientation.
func cells() -> Array[Vector2i]:
	return _data.cells_at(_anchor, _turns)
