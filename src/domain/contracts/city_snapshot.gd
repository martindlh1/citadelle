class_name CitySnapshot
extends RefCounted
## Ce qui est bâti, tel que l'Économie et le Combat le voient.
##
## Le miroir exact de HeightGrid.to_query() : un état mutable du domaine — ici
## CityState — se fige en une vue que les autres systèmes consomment sans jamais
## toucher à l'original. CityState.to_snapshot() en est le seul producteur.
##
## L'index par ancre existe parce qu'une affectation désigne un bâtiment par son
## ancre : sans lui, le résolveur de production balaierait toute la ville une fois par
## ouvrier.
##
## Il n'y a **pas** d'index par cellule. C3 et le Combat en voudront peut-être un ; on
## n'ouvre pas une porte que personne ne pousse.
##
## Immuable.

## Bâtiments, dans l'ordre où la ville les a posés.
var _buildings: Array[BuildingSnapshot] = []

## Ancre -> bâtiment.
var _by_anchor: Dictionary[Vector2i, BuildingSnapshot] = {}

## Vue figée de ces bâtiments, dans cet ordre.
static func create(buildings: Array[BuildingSnapshot]) -> CitySnapshot:
	var snapshot := CitySnapshot.new()
	for building in buildings:
		assert(building != null, "instantané de ville avec un bâtiment nul")
		assert(not snapshot._by_anchor.has(building.anchor()),
			"deux bâtiments sur la même ancre : %s" % building.anchor())
		snapshot._buildings.append(building)
		snapshot._by_anchor[building.anchor()] = building
	return snapshot

## Vue d'une ville sans aucun bâtiment.
static func empty() -> CitySnapshot:
	var none: Array[BuildingSnapshot] = []
	return CitySnapshot.create(none)

## Nombre de bâtiments.
func count() -> int:
	return _buildings.size()

## Bâtiments, dans l'ordre de pose. Copie : le tableau interne ne sort jamais.
func buildings() -> Array[BuildingSnapshot]:
	return _buildings.duplicate()

## Un bâtiment est-il ancré ici ?
func has_anchor(anchor: Vector2i) -> bool:
	return _by_anchor.has(anchor)

## Bâtiment ancré ici, ou null si l'ancre ne porte rien.
##
## Null plutôt qu'un assert, pour la même raison que CityState.building_at() : une
## affectation peut désigner une ancre dont le bâtiment vient d'être détruit, et
## « rien ici » est une réponse que le résolveur sait traiter.
func at_anchor(anchor: Vector2i) -> BuildingSnapshot:
	if not _by_anchor.has(anchor):
		return null
	return _by_anchor[anchor]
