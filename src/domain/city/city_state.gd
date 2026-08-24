class_name CityState
extends RefCounted
## Ce qui est bâti : les bâtiments posés et les cellules qu'ils occupent.
##
## État interne du système Construction, comme HeightGrid l'est du Terrain. Il ignore
## délibérément les dimensions de la carte — c'est TerrainQuery qui les connaît, et
## une ville qui les recopierait aurait à les resynchroniser pour rien. La ville ne
## sait que ce qu'elle a posé.
##
## Deux index pour la même vérité :
##   - ancre -> bâtiment, la liste de ce qui existe ;
##   - cellule -> ancre, la « référence vers l'ancre » de DESIGN.md 3.2, qui rend
##     immédiat le survol d'une cellule quelconque d'une empreinte.
##
## place() est la SEULE porte d'entrée mutante, et elle valide avant de muter. Rien ne
## peut donc entrer dans la ville sans être passé par PlacementValidator : c'est un
## invariant tenu par la structure, et non une consigne qu'un appelant doit respecter.

## Ancre -> bâtiment posé. L'ordre d'insertion d'un Dictionary est l'ordre de pose :
## c'est lui qui rend buildings() déterministe pour un même seed et une même suite
## d'actions, sans avoir à trier quoi que ce soit.
var _buildings: Dictionary[Vector2i, PlacedBuilding] = {}

## Cellule occupée -> ancre du bâtiment qui l'occupe.
var _anchors: Dictionary[Vector2i, Vector2i] = {}

## Nombre de bâtiments posés.
func count() -> int:
	return _buildings.size()

## Bâtiments posés, dans l'ordre de pose.
func buildings() -> Array[PlacedBuilding]:
	var placed: Array[PlacedBuilding] = []
	placed.assign(_buildings.values())
	return placed

## Cette cellule porte-t-elle un bâtiment ?
##
## Répond hors carte, et le doit : la ville ne connaît pas les bornes, et « rien n'est
## posé là » reste vrai d'une cellule qui n'existe pas. C'est le contrat Terrain qui
## tranche l'existence, pas celui-ci.
func is_occupied(cell: Vector2i) -> bool:
	return _anchors.has(cell)

## Bâtiment qui occupe cette cellule, ou null si elle est libre.
##
## Null plutôt qu'un assert : un adapter interroge la cellule survolée à chaque image
## et la plupart sont libres. Même exception que decor sur TerrainData — « rien ici »
## est une réponse, pas une faute d'appelant.
func building_at(cell: Vector2i) -> PlacedBuilding:
	if not _anchors.has(cell):
		return null
	return _buildings[_anchors[cell]]

## Ancre du bâtiment qui occupe cette cellule. Précondition : is_occupied(cell).
##
## C'est le chemin d'une démolition au clic : l'adapter tient une cellule quelconque
## de l'empreinte, remove() veut l'ancre.
func anchor_at(cell: Vector2i) -> Vector2i:
	assert(is_occupied(cell), "ancre demandée à une cellule libre : %s" % cell)
	return _anchors[cell]

## Un bâtiment est-il ancré sur cette cellule ? Faux sur une cellule qu'une empreinte
## couvre sans y être ancrée.
func has_anchor(anchor: Vector2i) -> bool:
	return _buildings.has(anchor)

## Pose ce bâtiment sur cette ancre si le placement est valide, et ne mute rien sinon.
##
## Rend le PlacementResult de la validation tel quel, de sorte qu'un appelant qui
## prévisualisait déjà retrouve exactement la réponse qu'il affichait — le fantôme de
## C2 et la pose ne peuvent pas diverger.
func place(terrain: TerrainQuery, data: BuildingData, anchor: Vector2i) -> PlacementResult:
	var result := PlacementValidator.validate(self, terrain, data, anchor)
	if not result.is_ok():
		return result
	_buildings[anchor] = PlacedBuilding.create(data, anchor, result.height())
	for cell in result.cells():
		_anchors[cell] = anchor
	return result

## Retire le bâtiment ancré ici et libère toutes ses cellules.
##
## Précondition : has_anchor(anchor). Passer par anchor_at() quand on tient une
## cellule quelconque plutôt que l'ancre.
func remove(anchor: Vector2i) -> void:
	assert(has_anchor(anchor), "retrait sur une cellule qui n'ancre rien : %s" % anchor)
	for cell in _buildings[anchor].cells():
		_anchors.erase(cell)
	_buildings.erase(anchor)
