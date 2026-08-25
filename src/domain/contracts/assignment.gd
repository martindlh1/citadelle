class_name Assignment
extends RefCounted
## Qui travaille sur quoi : ouvrier -> action posée.
##
## Produit par les Effectifs, consommé par l'Économie puis par le Combat. Immuable,
## comme TerrainQuery fige une HeightGrid : l'UI d'affectation tient son propre
## brouillon et en fabrique une quand la phase se résout.
##
## **La clé est l'action, pas le lieu.** Jusqu'à D2 c'était l'ancre d'un bâtiment, ce
## qui était la lecture de E1 : la production balayait les bâtiments et l'affectation
## disait lesquels étaient tenus. DESIGN.md 2 dit le contraire — « c'est le résultat des
## actions que le joueur a posées » —, et une ancre ne suffit plus à désigner sans
## ambiguïté ce qu'un ouvrier fait : *Terraformer* et *Récolter* peuvent viser la même
## case nue, *Récolter* et *Chasser* la même forêt. Un ouvrier s'attache donc à l'action,
## qui porte sa propre identité, et l'endroit devient une propriété de l'action.
##
## Elle ne sait **rien** des actions posées — ni si elles existent, ni combien de postes
## elles offrent. Une affectation qui déborde la capacité, ou qui désigne une action
## retirée depuis, est un état normal que le résolveur tranche ; le trancher ici
## obligerait ce DTO à connaître le plan, ce qui est précisément la dépendance que
## contracts/ existe pour éviter.
##
## L'ordre compte. Les ouvriers d'une même action sortent dans l'ordre où ils ont été
## affectés, et c'est cet ordre que le résolveur suit pour remplir les postes : sur une
## action sur-affectée, les premiers arrivés travaillent et les autres chôment. Un
## producteur d'affectations doit donc être déterministe, sans quoi deux résolutions du
## même run divergeraient.

## Valeur qu'aucune action posée ne porte. L'ActionBoard alloue à partir de 1, ce qui
## laisse ce zéro disponible aux adapters pour dire « aucune action ».
const NO_ACTION := 0

## Ouvrier -> action posée, dans l'ordre d'affectation.
var _action_by_worker: Dictionary[StringName, int] = {}

## Action posée -> ouvriers affectés, dans l'ordre d'affectation.
##
## Le type de valeur reste Array nu : GDScript ne sait pas déclarer le paramètre d'un
## type imbriqué dans un Dictionary typé. workers_on() le retype à la sortie.
var _workers_by_action: Dictionary[int, Array] = {}

## Affectation figée depuis cette table, dont l'ordre d'insertion est conservé.
static func create(action_by_worker: Dictionary[StringName, int]) -> Assignment:
	var assignment := Assignment.new()
	for worker in action_by_worker:
		assert(not worker.is_empty(), "affectation d'un ouvrier sans identifiant")
		var action: int = action_by_worker[worker]
		assert(action != NO_ACTION, "ouvrier %s affecté à aucune action" % worker)
		assignment._action_by_worker[worker] = action
		if not assignment._workers_by_action.has(action):
			var none: Array[StringName] = []
			assignment._workers_by_action[action] = none
		assignment._workers_by_action[action].append(worker)
	return assignment

## Affectation vide : personne ne travaille. Le roster mange quand même.
static func empty() -> Assignment:
	var none: Dictionary[StringName, int] = {}
	return Assignment.create(none)

## Nombre d'ouvriers affectés.
func size() -> int:
	return _action_by_worker.size()

## Cet ouvrier est-il affecté quelque part ?
func is_assigned(worker: StringName) -> bool:
	return _action_by_worker.has(worker)

## Action à laquelle cet ouvrier est affecté. Précondition : is_assigned(worker).
func action_of(worker: StringName) -> int:
	assert(is_assigned(worker), "action demandée pour un ouvrier non affecté : %s" % worker)
	return _action_by_worker[worker]

## Ouvriers affectés, dans l'ordre d'affectation.
func workers() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_action_by_worker.keys())
	return ids

## Ouvriers affectés à cette action, dans l'ordre d'affectation. Vide si aucun.
func workers_on(action: int) -> Array[StringName]:
	var assigned: Array[StringName] = []
	if _workers_by_action.has(action):
		assigned.assign(_workers_by_action[action])
	return assigned

## Actions qui reçoivent au moins un ouvrier, dans l'ordre de première affectation.
func actions() -> Array[int]:
	var used: Array[int] = []
	used.assign(_workers_by_action.keys())
	return used
