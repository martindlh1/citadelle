class_name MoveResult
extends RefCounted
## Ce qu'un déplacement a fait, ou pourquoi il n'a rien fait.
##
## `{ ok, reason }` comme `PlacementResult` et `TargetResult`, et pour la même raison qu'eux :
## un curseur promené sur un plateau refuse la plupart du temps, donc **un refus est le
## résultat normal** et non un incident. Rien ici ne `push_error` — les conventions
## réservent ça à ce qui ne devrait pas arriver.
##
## Il vit dans `domain/combat/` et non dans `contracts/` par le critère habituel : aucun
## second système du domaine ne le franchit. Il va du plateau à l'écran, et un adapter qui
## lit le domaine fait son métier.
##
## Immuable.

## Ce corps n'est pas sur le plateau.
const UNKNOWN_BODY := &"unknown_body"

## Il est tombé — un mort ne se déplace pas.
const IS_DOWN := &"is_down"

## Ce n'est pas le tour de son camp.
const WRONG_SIDE := &"wrong_side"

## Il a déjà employé son déplacement ce tour.
const ALREADY_MOVED := &"already_moved"

## La case visée est celle où il se tient déjà.
##
## *(Entré à `F3a`.)* Rester sur place **est** un déplacement légal, et `reachable()`
## continue de rendre la case de départ à zéro parce que c'est une vérité sur les
## distances. Mais le geste, lui, brûlerait le déplacement du tour pour rien : un clic
## égaré sur son propre pion coûterait un tour sans que rien ne le dise. Le refus est donc
## dans le domaine et non dans la vue, sinon deux écrans devraient s'en souvenir.
const NO_MOVE := &"no_move"

## La case est hors de ce qu'il peut parcourir — trop loin, barrée, ou derrière une marche
## trop haute. Les trois se confondent volontairement : du point de vue de celui qui joue,
## « je ne peux pas aller là » est une seule réponse, et l'écran allume de toute façon les
## cases où l'on peut aller.
const OUT_OF_REACH := &"out_of_reach"

var _ok: bool
var _reason: StringName
var _cost: int

## Déplacement accompli, pour ce prix en points.
static func moved(cost: int) -> MoveResult:
	assert(cost >= 0, "déplacement de coût négatif : %d" % cost)
	var result := MoveResult.new()
	result._ok = true
	result._cost = cost
	return result

## Déplacement refusé, pour cette raison.
static func refused(reason: StringName) -> MoveResult:
	assert(not reason.is_empty(), "refus de déplacement sans raison")
	var result := MoveResult.new()
	result._ok = false
	result._reason = reason
	return result

## Le corps s'est-il déplacé ?
func is_ok() -> bool:
	return _ok

## Pourquoi le refus, ou vide si le déplacement a eu lieu.
func reason() -> StringName:
	return _reason

## Points de déplacement dépensés. Zéro sur un refus, et zéro aussi sur un pas qui revient
## à la case de départ — les deux sont indiscernables ici, et personne n'a à les distinguer.
func cost() -> int:
	return _cost
