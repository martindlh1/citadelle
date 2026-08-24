class_name Assignment
extends RefCounted
## Qui travaille où : ouvrier -> ancre du bâtiment.
##
## Produit par les Effectifs, consommé par l'Économie puis par le Combat. Immuable,
## comme TerrainQuery fige une HeightGrid : l'UI d'affectation tient son propre
## brouillon et en fabrique une quand la phase se résout.
##
## Elle ne sait **rien** des bâtiments — ni s'ils existent, ni combien de slots ils
## ont. Une affectation qui déborde les slots, ou qui désigne une ancre vide, est un
## état normal que le résolveur tranche ; le trancher ici obligerait ce DTO à connaître
## la ville, ce qui est précisément la dépendance que contracts/ existe pour éviter.
##
## L'ordre compte. Les ouvriers d'une même ancre sortent dans l'ordre où ils ont été
## affectés, et c'est cet ordre que le résolveur suit pour remplir les slots : sur un
## bâtiment sur-affecté, les premiers arrivés travaillent et les autres chôment. Un
## producteur d'affectations doit donc être déterministe, sans quoi deux résolutions du
## même run divergeraient.

## Ouvrier -> ancre, dans l'ordre d'affectation.
var _anchor_by_worker: Dictionary[StringName, Vector2i] = {}

## Ancre -> ouvriers affectés, dans l'ordre d'affectation.
##
## Le type de valeur reste Array nu : GDScript ne sait pas déclarer le paramètre d'un
## type imbriqué dans un Dictionary typé. workers_at() le retype à la sortie.
var _workers_by_anchor: Dictionary[Vector2i, Array] = {}

## Affectation figée depuis cette table, dont l'ordre d'insertion est conservé.
static func create(anchor_by_worker: Dictionary[StringName, Vector2i]) -> Assignment:
	var assignment := Assignment.new()
	for worker in anchor_by_worker:
		assert(not worker.is_empty(), "affectation d'un ouvrier sans identifiant")
		var anchor: Vector2i = anchor_by_worker[worker]
		assignment._anchor_by_worker[worker] = anchor
		if not assignment._workers_by_anchor.has(anchor):
			var none: Array[StringName] = []
			assignment._workers_by_anchor[anchor] = none
		assignment._workers_by_anchor[anchor].append(worker)
	return assignment

## Affectation vide : personne ne travaille. Le roster mange quand même.
static func empty() -> Assignment:
	var none: Dictionary[StringName, Vector2i] = {}
	return Assignment.create(none)

## Nombre d'ouvriers affectés.
func size() -> int:
	return _anchor_by_worker.size()

## Cet ouvrier est-il affecté quelque part ?
func is_assigned(worker: StringName) -> bool:
	return _anchor_by_worker.has(worker)

## Ancre à laquelle cet ouvrier est affecté. Précondition : is_assigned(worker).
func anchor_of(worker: StringName) -> Vector2i:
	assert(is_assigned(worker), "ancre demandée pour un ouvrier non affecté : %s" % worker)
	return _anchor_by_worker[worker]

## Ouvriers affectés, dans l'ordre d'affectation.
func workers() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_anchor_by_worker.keys())
	return ids

## Ouvriers affectés à cette ancre, dans l'ordre d'affectation. Vide si aucun.
func workers_at(anchor: Vector2i) -> Array[StringName]:
	var assigned: Array[StringName] = []
	if _workers_by_anchor.has(anchor):
		assigned.assign(_workers_by_anchor[anchor])
	return assigned

## Ancres qui reçoivent au moins un ouvrier, dans l'ordre de première affectation.
func anchors() -> Array[Vector2i]:
	var used: Array[Vector2i] = []
	used.assign(_workers_by_anchor.keys())
	return used
