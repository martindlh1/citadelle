class_name ActionPlan
extends RefCounted
## Ce que le joueur a posé dans la phase, figé.
##
## Projection immuable de l'`ActionBoard`, dont `to_plan()` est le seul producteur — le
## miroir exact de `Deck.hand()` -> `Hand`, de `CityState.to_snapshot()` ->
## `CitySnapshot` et de `Roster.to_labor()` -> `LaborForce`. Le board garde ses actions ;
## le plan qu'il rend ne peut pas poser à sa place.
##
## C'est ce que l'Économie consomme pour résoudre le soir. `DESIGN.md` 2 : « La
## production n'est plus une étape passive qui balaye les bâtiments : c'est le résultat
## des actions que le joueur a posées. Un bâtiment dont aucun slot n'a reçu d'action ne
## rend rien. » Sans ce contrat, cette phrase ne pouvait pas devenir vraie — le résolveur
## partait des bâtiments et n'avait aucun moyen de savoir lesquels avaient reçu une
## action.
##
## L'index par identifiant existe parce qu'une affectation désigne une action par le
## sien : sans lui, le résolveur balaierait tout le plan une fois par ouvrier.

## Actions posées, dans l'ordre de pose.
var _actions: Array[PlayedAction] = []

## Identifiant -> action posée.
var _by_id: Dictionary[int, PlayedAction] = {}

## Vue figée de ces actions, dans cet ordre.
##
## L'ordre compte et il est celui de la pose : c'est lui que le résolveur suit, donc deux
## phases identiques jouées dans un ordre différent doivent rendre la même chose, et un
## ordre qui viendrait d'un `Dictionary` non maîtrisé ferait diverger deux runs partis du
## même seed.
static func create(actions: Array[PlayedAction]) -> ActionPlan:
	var plan := ActionPlan.new()
	for action in actions:
		assert(action != null, "plan d'actions avec une action nulle")
		assert(not plan._by_id.has(action.id()),
			"deux actions posées portent l'identifiant %d" % action.id())
		plan._actions.append(action)
		plan._by_id[action.id()] = action
	return plan

## Plan vide : le joueur n'a rien posé. Ce n'est pas une erreur — c'est l'état d'un
## début de phase, et celui d'une phase où l'on a tout gardé en main.
static func empty() -> ActionPlan:
	var none: Array[PlayedAction] = []
	return ActionPlan.create(none)

## Nombre d'actions posées.
func count() -> int:
	return _actions.size()

## Rien n'a-t-il été posé ?
func is_empty() -> bool:
	return _actions.is_empty()

## Actions posées, dans l'ordre de pose. Copie : le tableau interne ne sort jamais.
func actions() -> Array[PlayedAction]:
	return _actions.duplicate()

## Cette action figure-t-elle au plan ?
func has(id: int) -> bool:
	return _by_id.has(id)

## Action posée sous cet identifiant, ou null s'il n'y en a pas.
##
## Null plutôt qu'un assert, pour la même raison que `CitySnapshot.at_anchor()` : une
## affectation peut avoir survécu à l'action qu'elle nommait — le joueur l'a retirée
## après y avoir mis un ouvrier —, et « plus rien sous ce numéro » est une réponse que le
## résolveur sait traiter.
func at(id: int) -> PlayedAction:
	if not _by_id.has(id):
		return null
	return _by_id[id]
