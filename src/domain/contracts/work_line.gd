class_name WorkLine
extends RefCounted
## Une ligne du journal de travail d'un soir : cet ouvrier a tenu un slot de ce
## bâtiment, dans cette famille de compétence.
##
## C'est ce que les Effectifs consomment pour distribuer l'XP. L'Économie n'en calcule
## aucune : combien vaut une soirée de travail est un chiffre d'équilibrage des
## Effectifs, et la famille figure ici justement pour que W1 sache quelle piste
## créditer sans avoir à rouvrir la ville pour retrouver le bâtiment.
##
## Immuable.

var _worker: StringName
var _anchor: Vector2i
var _family: StringName

## Ligne de journal pour cet ouvrier, à cette ancre, dans cette famille.
static func create(worker: StringName, anchor: Vector2i, family: StringName) -> WorkLine:
	assert(not worker.is_empty(), "ligne de travail sans ouvrier")
	var line := WorkLine.new()
	line._worker = worker
	line._anchor = anchor
	line._family = family
	return line

## Ouvrier qui a travaillé.
func worker() -> StringName:
	return _worker

## Ancre du bâtiment dont il a tenu un slot.
func anchor() -> Vector2i:
	return _anchor

## Famille de compétence que ce poste emploie. C'est la piste à créditer.
func family() -> StringName:
	return _family
