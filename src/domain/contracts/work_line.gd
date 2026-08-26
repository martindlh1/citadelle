class_name WorkLine
extends RefCounted
## Une ligne du journal de travail d'un soir : cet ouvrier a tenu un poste sur cette
## cellule, dans cette famille de compétence.
##
## C'est ce que les Effectifs consomment pour distribuer l'XP. L'Économie n'en calcule
## aucune : combien vaut une soirée de travail est un chiffre d'équilibrage des
## Effectifs, et la famille figure ici justement pour que W1 sache quelle piste
## créditer sans avoir à rouvrir la ville pour retrouver le bâtiment.
##
## La cellule était l'ancre d'un bâtiment jusqu'à D2, où le poste peut désormais être
## une case nue — DESIGN.md 3.5, « une action se joue à cru ou dans un bâtiment ». Le
## champ n'a pas changé de type, seulement de portée : sur un bâtiment, c'est toujours
## son ancre.
##
## Elle ne nomme pas l'action posée dont elle vient, et deux actions peuvent viser la
## même cellule. Personne ne pose la question aujourd'hui — SkillResolver ne lit que
## l'ouvrier et la famille —, et l'ajouter d'avance serait une frontière que personne ne
## franchit.
##
## Immuable.

var _worker: StringName
var _cell: Vector2i
var _family: StringName

## Ligne de journal pour cet ouvrier, sur cette cellule, dans cette famille.
static func create(worker: StringName, cell: Vector2i, family: StringName) -> WorkLine:
	assert(not worker.is_empty(), "ligne de travail sans ouvrier")
	var line := WorkLine.new()
	line._worker = worker
	line._cell = cell
	line._family = family
	return line

## Ouvrier qui a travaillé.
func worker() -> StringName:
	return _worker

## Cellule sur laquelle il a tenu un poste — l'ancre du bâtiment, ou la case nue.
func cell() -> Vector2i:
	return _cell

## Famille de compétence que ce poste emploie. C'est la piste à créditer.
func family() -> StringName:
	return _family
