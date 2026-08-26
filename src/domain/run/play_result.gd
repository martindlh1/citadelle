class_name PlayResult
extends RefCounted
## Réponse à « je joue cette carte, ici » : ce que ça a posé, ou pourquoi ça a été refusé.
##
## C'est la forme { ok, reason } que les conventions réservent aux erreurs récupérables,
## et le troisième membre de la famille après `PlacementResult` et `TargetResult`. Un
## refus est le résultat normal d'une carte promenée sur la carte, pas un incident.
##
## **Pourquoi un troisième et non l'un des deux autres.** `DESIGN.md` 3.2 pose depuis `C1`
## que le coût ne regarde pas la carte : « Ai-je les 15 bois ? » ne se demande pas au
## validateur de placement, et le contrat de Construction ne reçoit aucune bourse. C'est
## « la couche qui orchestre la journée qui pose les deux questions à la suite ». Cette
## couche existe enfin — c'est `RunOrchestrator` —, et il lui fallait un résultat qui
## puisse dire *les deux* refus. Ajouter `unaffordable` à `PlacementResult` aurait fait
## exactement ce que 3.2 interdit.
##
## Il **relaie** la raison du sous-refus telle quelle plutôt que de la retraduire : un
## `uneven_ground` venu du placement et un `wrong_tag` venu du ciblage traversent
## inchangés, de sorte qu'il n'y ait jamais deux vocabulaires à tenir d'accord. Les seules
## raisons propres à ce fichier sont celles que lui seul peut constater, parce que lui
## seul voit la main, la bourse et la phase.
##
## Il couvre les **deux natures de carte** d'un seul profil, ce qui est la traduction
## directe du fait qu'il n'y a qu'un geste pour le joueur : on prend une carte, on clique
## une cellule. Que l'une pose une action et l'autre ouvre un chantier est une asymétrie
## du domaine, pas de l'intention.
##
## Immuable.

## La carte est jouée, il n'y a pas de raison à donner.
const REASON_NONE := &""

## La carte n'est pas dans la main.
##
## Refus et non `assert` : une main rétrécit sous les doigts — une carte jouée, une phase
## résolue — et un rang qui désignait quelque chose peut ne plus rien désigner.
const REASON_NOT_IN_HAND := &"not_in_hand"

## La phase courante n'autorise pas ce geste.
##
## `DESIGN.md` 2 : une journée est une liste ordonnée de `PhaseDef`, « chaque phase
## déclarant les types d'action autorisés ». C'est ici que ce refus se lit, et c'est la
## seule chose qu'un `PlayResult` sache de la journée.
const REASON_WRONG_PHASE := &"wrong_phase"

## La réserve ne couvre pas le coût du bâtiment.
##
## La seule raison de ce fichier qui touche à la bourse, et la raison d'être du fichier.
const REASON_UNAFFORDABLE := &"unaffordable"

## La carte n'est ni un verbe que le ciblage sait poser, ni un bâtiment à ouvrir.
##
## C'est le sort d'un power tant que `X4` n'a pas rempli le troisième pool.
const REASON_UNKNOWN_CARD := &"unknown_card"

var _ok: bool
var _reason: StringName = REASON_NONE
var _action: PlayedAction = null
var _anchor: Vector2i
var _paid: Dictionary[StringName, int] = {}

## La carte a posé cette action. Rien n'a été payé : `DESIGN.md` ne donne de coût qu'aux
## cartes de bâtiment, et un lot vide qu'on ferait passer en argument serait un champ que
## personne ne remplit.
static func posted(action: PlayedAction) -> PlayResult:
	assert(action != null, "jeu accepté sans action posée")
	var result := PlayResult.new()
	result._ok = true
	result._action = action
	result._anchor = action.target()
	return result

## La carte a ouvert un chantier à cette ancre, pour ce coût.
##
## Le coût voyage dans le résultat plutôt que d'être relu depuis la `BuildingData` :
## c'est ce qui a **réellement** quitté la réserve, et c'est ce qu'un écran doit annoncer.
## Le jour où une remise ou une adjacence l'abaissera, la ligne affichée restera juste
## sans que rien ne bouge ici.
static func opened(anchor: Vector2i,
		paid: Dictionary[StringName, int]) -> PlayResult:
	var result := PlayResult.new()
	result._ok = true
	result._anchor = anchor
	result._paid = paid.duplicate()
	return result

## Carte refusée pour cette raison — l'une des constantes ci-dessus, ou celle qu'un
## `PlacementResult` ou un `TargetResult` vient de rendre.
static func refused(reason: StringName) -> PlayResult:
	assert(not reason.is_empty(), "refus sans raison")
	var result := PlayResult.new()
	result._reason = reason
	return result

## La carte a-t-elle été jouée ?
func is_ok() -> bool:
	return _ok

## Raison du refus. Vide quand la carte est jouée.
func reason() -> StringName:
	return _reason

## Le jeu a-t-il posé une action à laquelle des ouvriers peuvent aller ?
##
## Faux pour un chantier ouvert : une carte de bâtiment se pose et ne s'affecte pas, et
## c'est *Construire* jouée dessus qui l'avancera.
func posts_an_action() -> bool:
	return _ok and _action != null

## Action posée. Précondition : posts_an_action().
##
## L'objet et non son seul identifiant, parce que l'appelant en veut trois choses d'un
## coup au moment du clic — le numéro pour y envoyer un ouvrier, la capacité pour dire
## combien il en tient, la cible pour l'annoncer.
func action() -> PlayedAction:
	assert(posts_an_action(), "action demandée à un jeu qui n'en pose pas")
	return _action

## Cellule où la carte a atterri : la cible canonique de l'action posée, ou l'ancre du
## chantier ouvert. Précondition : is_ok().
func anchor() -> Vector2i:
	assert(_ok, "cible demandée à un jeu refusé")
	return _anchor

## Ce que le jeu a coûté. Vide pour une action posée. Copie.
func paid() -> Dictionary[StringName, int]:
	return _paid.duplicate()
