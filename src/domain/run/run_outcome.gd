class_name RunOutcome
extends RefCounted
## Comment un run s'est terminé, et ce qu'il valait.
##
## DESIGN.md 5 en entier, et rien de plus : deux défaites — le Cœur détruit, la population à
## zéro —, une victoire — le dernier tour franchi —, et un score qui compte « ressources,
## bâtiments intacts, population, points de vie restants du Cœur ».
##
## **Il n'y a pas de RunScorer, et c'est délibéré.** Un score est une somme pondérée de
## quatre nombres ; ce qui mériterait un fichier n'est pas la somme mais le fait d'aller
## chercher les quatre au bon endroit — la réserve à la réserve, les bâtiments achevés à la
## ville, l'effectif à la population, les PV du Cœur à la ville encore. Or aller chercher
## quatre réponses chez trois systèmes est exactement le métier de RunOrchestrator. Un
## résolveur de plus n'aurait fait que retransporter ces quatre entiers.
##
## Ce fichier reçoit donc des **comptes** et non des états. Aucun stock, aucune ville, aucune
## population ne le traverse : c'est la règle que F1 a posée sur le pillage — recevoir le
## contenu d'un état voisin, même en copie, revient à en dépendre.
##
## Il vit dans domain/run/ et non dans contracts/ : il va du Cycle de tour aux adapters, et
## aucun second système du domaine ne le franchit.
##
## Immuable.

## Le run est allé au bout de ses tours. C'est la victoire de DESIGN.md 5.
##
## « Dernière vague survécue » se dit ici « dernier tour franchi », et les deux seront la
## même phrase dès que le calendrier de V4 posera sa dernière vague sur le dernier tour. Le
## formuler en tours évite d'avoir à inventer une règle pour un calendrier qui s'arrêterait
## avant la fin : **un run paisible se gagne en le survivant**, ce qui reste vrai — et c'est
## ce qui rend le verdict atteignable dès I3, où aucune vague n'existe encore.
const CAUSE_SURVIVED := &"survived"

## Le Cœur est tombé.
##
## Inatteignable avant V4, où une vague qui arrive au Cœur lui inflige ses dégâts. La cause
## est écrite ici parce qu'elle est **une ligne de la même règle** que celle d'à côté, et
## qu'un verdict qui n'en connaîtrait qu'une aurait à rouvrir sa question le jour venu.
const CAUSE_HEART := &"heart"

## Il ne reste plus personne au village.
##
## La seule défaite atteignable à I3, et elle l'est vraiment : c'est la famine de
## DESIGN.md 3.4, un cran par tour, jusqu'à zéro. Elle remplace le roster vide du jeu
## d'avant, et c'est le même événement compté autrement.
const CAUSE_POPULATION := &"population"

## Pourquoi le run s'est arrêté.
var _cause: StringName

## Dernier tour joué.
var _turn: int

## Unités restées en réserve, toutes ressources confondues.
var _resources: int

## Bâtiments achevés encore debout.
var _buildings: int

## Habitants encore vivants.
var _inhabitants: int

## Points de vie qu'il reste au Cœur. 0 s'il est tombé, ou si le run n'en avait pas.
var _heart_hit_points: int

## Score total.
var _score: int

## Le compte d'un run fini, et ce qu'il vaut au barème de data/balance/.
##
## Les quatre comptes sont gardés à côté du total, et ce n'est pas une redondance : un écran
## de fin qui n'annoncerait qu'un nombre ne dirait pas **ce qui** l'a fait, et recalculer les
## termes en les redivisant par leurs poids serait une seconde arithmétique à tenir d'accord
## avec celle-ci.
static func tally(cause: StringName, turn: int, resources: int, buildings: int,
		inhabitants: int, heart_hit_points: int, balance: RunBalance) -> RunOutcome:
	assert(not cause.is_empty(), "fin de run sans cause")
	assert(turn > 0, "fin de run sans tour : %d" % turn)
	assert(balance != null, "fin de run sans barème")
	var outcome := RunOutcome.new()
	outcome._cause = cause
	outcome._turn = turn
	outcome._resources = maxi(0, resources)
	outcome._buildings = maxi(0, buildings)
	outcome._inhabitants = maxi(0, inhabitants)
	outcome._heart_hit_points = maxi(0, heart_hit_points)
	outcome._score = outcome._resources * balance.score_per_resource \
		+ outcome._buildings * balance.score_per_building \
		+ outcome._inhabitants * balance.score_per_inhabitant \
		+ outcome._heart_hit_points * balance.score_per_heart_hit_point
	return outcome

## Pourquoi le run s'est arrêté — l'une des trois constantes ci-dessus.
func cause() -> StringName:
	return _cause

## Le run a-t-il été gagné ?
##
## Dérivé de la cause plutôt que porté à côté : deux champs qui peuvent se contredire
## laisseraient exister une défaite victorieuse.
func is_victory() -> bool:
	return _cause == CAUSE_SURVIVED

## Dernier tour joué.
func turn() -> int:
	return _turn

## Unités restées en réserve.
func resources() -> int:
	return _resources

## Bâtiments achevés encore debout.
func buildings() -> int:
	return _buildings

## Habitants encore vivants.
func inhabitants() -> int:
	return _inhabitants

## Points de vie restants du Cœur.
func heart_hit_points() -> int:
	return _heart_hit_points

## Score total.
func score() -> int:
	return _score
