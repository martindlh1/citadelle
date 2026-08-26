class_name DayCycle
extends RefCounted
## Où l'on en est dans la journée, et dans le run.
##
## **Il ne connaît ni « matin » ni « soir ».** `DESIGN.md` 2 en fait une exigence
## d'implémentation, pas une préférence : une journée est une liste ordonnée de
## `PhaseDef` définies en data, chacune déclarant ses gestes autorisés et si une
## résolution se déclenche à sa fin. Aucun nom de phase n'apparaît dans ce fichier, ni
## dans aucun de ceux qui l'appellent. C'est ce qui fera de l'arbitrage de `I2b` — deux
## phases symétriques ou deux asymétriques — un échange de `.tres`.
##
## Il ne décide de rien non plus : `advance()` fait avancer, il ne dit pas quand. Ce qui
## se passe **à** une frontière de phase — résoudre, vider le board, repiocher — appartient
## à `RunOrchestrator`, qui possède les états que ça touche. Même partage que `Deck`, qui
## offre `draw()` sans décider du moment.
##
## État mutable du système Run, comme `CityState` l'est de Construction. Il ne porte que
## deux entiers : le jour, et le rang de la phase dans la journée.

## Jour courant, à partir de 1.
var _day := 1

## Rang de la phase courante dans la journée.
var _index := 0

## Les phases d'une journée, dans l'ordre.
var _phases: Array[PhaseDef] = []

## Journées du run.
var _days: int

## Cycle ouvert au premier instant du premier jour.
##
## Les phases sont recopiées : la liste vient d'une `Resource` d'équilibrage partagée, et
## un cycle qui garderait le tableau vivant se ferait réécrire sous les pieds le jour où
## une passe d'équilibrage rechargera `data/`.
static func create(phases: Array[PhaseDef], days: int) -> DayCycle:
	assert(not phases.is_empty(), "journée sans phase")
	assert(days > 0, "run sans journée : %d" % days)
	var cycle := DayCycle.new()
	for phase in phases:
		assert(phase != null, "journée avec une phase nulle")
		cycle._phases.append(phase)
	cycle._days = days
	return cycle

## Jour courant, à partir de 1. Vaut days() + 1 une fois le run terminé.
func day() -> int:
	return _day

## Journées du run.
func days() -> int:
	return _days

## Phases d'une journée.
func phase_count() -> int:
	return _phases.size()

## Rang de la phase courante dans la journée. Précondition : not is_over().
func phase_index() -> int:
	assert(not is_over(), "phase demandée à un run terminé")
	return _index

## Phase courante. Précondition : not is_over().
func phase() -> PhaseDef:
	assert(not is_over(), "phase demandée à un run terminé")
	return _phases[_index]

## Le run est-il terminé ?
func is_over() -> bool:
	return _day > _days

## Ce geste est-il autorisé maintenant ? Faux une fois le run terminé.
##
## Une question plutôt qu'un assert, et c'est ce qui permet à une UI de griser un bouton
## au lieu de faire tomber le jeu quand on le presse.
func permits(kind: StringName) -> bool:
	if is_over():
		return false
	return phase().permits(kind)

## Une résolution se déclenche-t-elle à la fin de la phase courante ? Faux une fois le
## run terminé.
func resolves() -> bool:
	if is_over():
		return false
	return phase().resolves

## La phase courante est-elle la dernière de la journée ?
##
## C'est **la** définition d'une fin de journée, et c'est pourquoi ce n'est pas un champ
## de `PhaseDef`. Une journée se ferme après sa dernière phase, point : un booléen en data
## pourrait dire le contraire de la liste qui le porte, et personne ne saurait lequel des
## deux croire.
##
## Ce qu'une fin de journée déclenche — l'upkeep, plus tard l'événement et le combat — est
## indépendant de `resolves()`. Une journée coûte à nourrir même si sa dernière phase ne
## produit rien.
func closes_the_day() -> bool:
	if is_over():
		return false
	return _index == _phases.size() - 1

## Arrête le cycle ici, quel qu'ait été le jour. Un run peut finir avant sa dernière
## journée.
##
## `DESIGN.md` 5 donne deux défaites — le Cœur détruit, le roster vide — et aucune n'attend
## la quinzième journée. Il fallait donc que « le run est fini » puisse devenir vrai au
## milieu, et le faire ici plutôt que d'ajouter un second drapeau ailleurs est le seul
## choix qui garde **une** vérité : `is_over()` répond pour les deux fins, et tous les
## gardes déjà écrits — `permits()`, `resolves()`, `closes_the_day()`, `advance()` — se
## ferment sans qu'une ligne bouge. Deux « le run est fini » qui peuvent se contredire
## seraient pire que le cas qu'ils couvrent.
##
## Il ne dit pas **pourquoi**, et ce n'est pas son affaire : la cause et le score sont un
## `RunOutcome`, que `RunState` porte. Le cycle ne connaît que des jours.
##
## Appelable sur un cycle déjà terminé, où il ne fait rien : une victoire se constate
## justement après que le dernier jour est passé.
func end() -> void:
	_day = maxi(_day, _days + 1)

## Passe à la phase suivante. Rend vrai si un nouveau jour vient de s'ouvrir.
##
## Le booléen porte l'information qu'un appelant ne peut pas déduire sans avoir gardé
## l'état d'avant : `day()` a changé. Un run terminé n'avance plus et rend faux, ce qui
## rend la boucle « tant que ça avance » sûre sans garde.
func advance() -> bool:
	if is_over():
		return false
	_index += 1
	if _index < _phases.size():
		return false
	_index = 0
	_day += 1
	return true
