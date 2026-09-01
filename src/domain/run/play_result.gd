class_name PlayResult
extends RefCounted
## Réponse à un geste du joueur : ce qu'il a posé, ou pourquoi il a été refusé.
##
## La forme { ok, reason } que les conventions réservent aux erreurs récupérables, et pour
## la raison qui a fait naître PlacementResult à C1 : un refus est le résultat **normal**
## d'un curseur promené sur la carte, pas un incident à remonter par push_error.
##
## ---
##
## **Il prolonge PlacementResult au lieu de le doubler**, et c'est ce qui rend ses raisons
## composables. Ouvrir un chantier demande quatre questions à quatre systèmes — la carte,
## la file, les bras, la bourse — et la première a déjà ses réponses écrites. Elles
## traversent ce DTO **telles quelles**, parce que la raison de PlacementResult est un
## StringName et non un enum, et c'est exactement ce que son docstring annonçait : « une
## raison qui s'ajoute plus tard — INSUFFICIENT_RESOURCES le jour où l'orchestrateur compose
## placement et bourse — ne renumérote rien ». Ce jour est arrivé.
##
## **Trois gestes, un seul DTO.** Fonder, bâtir et démolir rendent la même chose, parce que
## le joueur ne fait qu'un geste — désigner une cellule — et que la nature de ce qui s'y
## passe est une asymétrie du domaine, pas de l'intention. C'est la leçon que D2 avait tirée
## d'une porte unique de jeu de carte, et elle survit à la disparition des cartes.
##
## Il vit dans domain/run/ et non dans contracts/ : il va du Cycle de tour aux adapters, et
## aucun second système du domaine ne le franchit.
##
## Immuable.

## Le geste est accepté, il n'y a pas de raison à donner.
const REASON_NONE := &""

## Le run attend encore qu'on pose son Cœur.
const REASON_NO_HEART := &"no_heart"

## Le Cœur est déjà posé — on ne fonde pas deux fois.
const REASON_ALREADY_FOUNDED := &"already_founded"

## Le run est terminé ; plus aucun geste ne le change.
const REASON_RUN_OVER := &"run_over"

## Le catalogue ne connaît pas ce bâtiment.
const REASON_UNKNOWN_BUILDING := &"unknown_building"

## Tous les emplacements de la file de chantiers sont pris.
##
## C'est le refus qui **fait exister la file** de DESIGN.md 3.2. Sans lui, le second
## régulateur du rescope serait un champ de data que rien ne consulte.
const REASON_NO_BUILD_SLOT := &"no_build_slot"

## Le village n'a pas assez de bras libres pour ce chantier.
##
## Le pendant exact du refus de la bourse, et DESIGN.md 3.4 en fait le point : « une ferme
## coûte 10 bois **et 4 travailleurs** ». Les deux refus se lisent de la même façon parce
## que ce sont deux coûts de construction ; le seul mot qui les sépare est que le bois est
## consommé et le travailleur immobilisé.
const REASON_NOT_ENOUGH_WORKERS := &"not_enough_workers"

## La réserve ne couvre pas le coût.
const REASON_NOT_ENOUGH_RESOURCES := &"not_enough_resources"

## Rien n'est bâti sur la cellule désignée.
const REASON_NOTHING_HERE := &"nothing_here"

## On ne démolit pas son propre Cœur.
##
## DESIGN.md 4.2 ne l'exclut pas de « Démolir », et 5 fait du Cœur détruit une défaite : les
## deux mis bout à bout donnent un bouton « perdre la partie » sans confirmation ni retour
## en arrière, ce qu'aucune ligne de DESIGN.md ne demande. Le refus est ici et non dans
## CityState parce que le Cœur n'est un Cœur que pour le run : la Construction, elle, ne voit
## qu'un bâtiment comme un autre.
const REASON_THE_HEART := &"the_heart"

var _ok: bool
var _reason: StringName = REASON_NONE
var _anchor: Vector2i
var _spent: Dictionary[StringName, int] = {}
var _workers: int
var _homeless: int
var _spilled: int

## Geste accepté qui a **posé** quelque chose sur cette ancre, contre ce coût et ces bras.
##
## Sert aussi bien à la fondation qu'à l'ouverture d'un chantier : le Cœur passe par ici
## avec un coût vide et zéro bras, ce qui n'est pas un cas particulier mais ce que sa ligne
## de DESIGN.md 4.1 dit — « posé au départ », et un zéro dans la colonne Trav.
static func opened(anchor: Vector2i, spent: Dictionary[StringName, int],
		workers: int) -> PlayResult:
	assert(workers >= 0, "chantier ouvert sur un nombre de bras négatif : %d" % workers)
	var result := PlayResult.new()
	result._ok = true
	result._anchor = anchor
	result._spent = spent.duplicate()
	result._workers = workers
	return result

## Démolition acceptée : elle a rendu ces bras, et coûté ces habitants et ces unités.
##
## Les deux pertes ne sont pas symétriques du gain. Démolir « ne rend aucune ressource »
## (DESIGN.md 4.2), mais abattre une habitation ou un entrepôt **abaisse un plafond**, et ce
## qui dépassait s'en va — c'est le geste que Population.set_places() et
## Ledger.set_capacity() rendent depuis N1 et E1. Les taire ferait disparaître des habitants
## sans que l'écran puisse le dire.
static func razed(anchor: Vector2i, workers: int, homeless: int,
		spilled: int) -> PlayResult:
	assert(workers >= 0, "démolition rendant un nombre de bras négatif : %d" % workers)
	assert(homeless >= 0, "démolition chassant un nombre négatif d'habitants")
	assert(spilled >= 0, "démolition renversant une quantité négative")
	var result := PlayResult.new()
	result._ok = true
	result._anchor = anchor
	result._workers = workers
	result._homeless = homeless
	result._spilled = spilled
	return result

## Geste refusé pour cette raison, qui est l'une des constantes ci-dessus ou l'une de
## celles de PlacementResult.
static func refused(reason: StringName) -> PlayResult:
	assert(not reason.is_empty(), "refus sans raison")
	var result := PlayResult.new()
	result._reason = reason
	return result

## Le geste a-t-il abouti ?
func is_ok() -> bool:
	return _ok

## Raison du refus. Vide quand le geste a abouti.
func reason() -> StringName:
	return _reason

## Ancre visée. Précondition : is_ok().
func anchor() -> Vector2i:
	assert(_ok, "ancre demandée à un geste refusé")
	return _anchor

## Ce que la réserve a payé. Vide sur une démolition, qui ne coûte rien. Copie.
func spent() -> Dictionary[StringName, int]:
	return _spent.duplicate()

## Travailleurs que le geste a déplacés : **immobilisés** par une ouverture, **rendus** par
## une démolition. Le geste dit lequel des deux ; un signe le dirait moins bien, parce qu'il
## faudrait le lire pour comprendre ce qui vient de se passer.
func workers() -> int:
	return _workers

## Habitants chassés par le plafond de logement que le geste a abaissé. 0 partout ailleurs.
func homeless() -> int:
	return _homeless

## Unités renversées par le plafond de réserve que le geste a abaissé. 0 partout ailleurs.
func spilled() -> int:
	return _spilled
