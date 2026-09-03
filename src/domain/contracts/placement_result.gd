class_name PlacementResult
extends RefCounted
## Réponse à « puis-je poser ce bâtiment ici ? » : oui avec ce que ça couvrirait, ou
## non avec la raison.
##
## C'est la forme { ok, reason } que les conventions réservent aux erreurs
## récupérables. Un placement refusé est le résultat normal d'un curseur promené sur
## la carte, pas un incident à remonter par push_error : le fantôme de C2 interrogera
## cette fonction à chaque image, et la plupart des réponses seront des refus.
##
## La raison est un StringName et non un enum, comme le veut la convention pour ce
## DTO précisément. Un adapter la mappe sur un libellé sans rien importer du domaine,
## et une raison qui s'ajoute plus tard — INSUFFICIENT_RESOURCES le jour où
## l'orchestrateur compose placement et bourse — ne renumérote rien.
##
## Contrairement à PickResult à T3, ce DTO entre dans contracts/ dès C1 : la table de
## CLAUDE.md l'y liste déjà, producteur Construction, consommateur adapters.

## Le placement est accepté, il n'y a pas de raison à donner.
const REASON_NONE := &""

## L'empreinte déborde de la carte.
const REASON_OUT_OF_BOUNDS := &"out_of_bounds"

## Une cellule de l'empreinte porte un terrain sur lequel on ne bâtit pas.
const REASON_NOT_BUILDABLE := &"not_buildable"

## Une cellule de l'empreinte est déjà prise par un autre bâtiment.
const REASON_OCCUPIED := &"occupied"

## Les cellules de l'empreinte ne sont pas toutes à la même hauteur.
const REASON_UNEVEN_GROUND := &"uneven_ground"

## La case est **hors de l'emprise du village**.
##
## L'emprise est la réunion des disques que les bâtiments achevés projettent autour d'eux
## *(DESIGN.md 3.2)*. Elle se dit **avant** le voisinage et après le terrain, et l'ordre porte
## un sens : « il n'y a pas d'arbre ici » n'intéresse personne sur une case où l'on n'a de toute
## façon pas le droit de bâtir.
const REASON_OUT_OF_REACH := &"out_of_reach"

## Le bâtiment porte des règles de voisinage et **aucune ne trouve de case**.
##
## C'est le seul refus qui ne parle ni de la carte ni de ce qui est bâti, mais de ce que le
## bâtiment **serait** ici : une cabane de bûcheron sans un arbre à portée coûte des bras,
## occupe une case et ne rend rien. `DESIGN.md` 3.2 en fait un prérequis dur plutôt qu'un
## rendement nul, parce qu'un rendement nul est un piège qu'on ne repère qu'après avoir payé.
##
## *Il revient sur une décision de C1*, qui avait écarté l'adjacence du placement en la
## réservant au rendement. Elle était juste tant que les deux couches étaient distinctes ;
## depuis C3 elles n'en font plus qu'une.
const REASON_NO_NEIGHBOUR := &"no_neighbour"

var _ok: bool
var _reason: StringName = REASON_NONE
var _cells: Array[Vector2i] = []
var _height: int

## Placement accepté : il couvrirait ces cellules, toutes à cette hauteur.
static func accepted(cells: Array[Vector2i], height: int) -> PlacementResult:
	assert(not cells.is_empty(), "placement accepté sans aucune cellule")
	var result := PlacementResult.new()
	result._ok = true
	result._cells = cells.duplicate()
	result._height = height
	return result

## Placement refusé pour cette raison, qui est l'une des constantes ci-dessus.
static func refused(reason: StringName) -> PlacementResult:
	assert(not reason.is_empty(), "refus sans raison")
	var result := PlacementResult.new()
	result._reason = reason
	return result

## Le placement est-il accepté ?
func is_ok() -> bool:
	return _ok

## Raison du refus. Vide quand le placement est accepté.
func reason() -> StringName:
	return _reason

## Cellules que le bâtiment couvrirait, dans l'ordre de son empreinte.
##
## Copie : le bus ne transporte jamais une référence mutable sur un état du domaine,
## et un adapter qui garde ce tableau ne doit pas pouvoir déplacer un bâtiment posé.
##
## Précondition : is_ok().
func cells() -> Array[Vector2i]:
	assert(_ok, "cellules demandées à un placement refusé")
	return _cells.duplicate()

## Hauteur commune des cellules couvertes, en crans.
##
## Elle n'est bien définie que parce qu'un bâtiment exige toutes ses cellules à la
## même hauteur — c'est le y auquel il se dessinera, sans que le rendu ait à
## reparcourir l'empreinte.
##
## Précondition : is_ok().
func height() -> int:
	assert(_ok, "hauteur demandée à un placement refusé")
	return _height
