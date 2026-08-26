class_name RunOutcome
extends RefCounted
## Comment un run s'est terminé, et ce qu'il valait.
##
## `DESIGN.md` 5 en entier, et rien de plus : deux défaites — le Cœur détruit, le roster
## vide —, une victoire — la dernière vague survécue —, et un score qui compte « ressources,
## bâtiments intacts, ouvriers vivants et leur niveau ».
##
## **Il n'y a pas de `RunScorer`, et c'est délibéré.** Un score est une somme pondérée de
## quatre nombres ; ce qui mérite un fichier n'est pas la somme mais le fait d'aller
## chercher les quatre au bon endroit — la réserve à la réserve, les bâtiments achevés à la
## ville, les vivants et leurs niveaux au roster. Or aller chercher quatre réponses chez
## quatre systèmes est exactement le métier de `RunOrchestrator`, qui « n'ajoute que ce
## qu'aucun d'eux ne peut faire seul : enchaîner deux questions ». Un résolveur de plus
## n'aurait fait que retransporter ces quatre entiers.
##
## Ce fichier reçoit donc des **comptes** et non des états. Aucun stock, aucune ville,
## aucun roster ne le traverse : c'est la règle que `F1` a posée sur le pillage — recevoir
## le contenu d'un état voisin, même en copie, revient à en dépendre.
##
## Il vit dans `domain/run/` et non dans `contracts/`, comme `PhaseReport` et `BattleReport`
## avant lui : aucun second système du domaine ne le franchit — il va du Cycle de jour aux
## adapters —, et 3.8 pose que ce système-ci est celui qui a le droit de connaître tous les
## autres.
##
## Immuable.

## Le run est allé au bout de ses journées. C'est la victoire de `DESIGN.md` 5.
##
## « Dernière vague survécue » se dit ici « dernière journée franchie », et les deux sont
## la même phrase dès lors que le calendrier pose sa dernière vague sur le dernier jour —
## ce que `data/balance/` fait. Le formuler en journées plutôt qu'en vagues évite d'avoir à
## inventer une règle pour un calendrier qui s'arrêterait avant la fin : un run paisible se
## gagne en le survivant, ce qui reste vrai.
const CAUSE_SURVIVED := &"survived"

## Le Cœur est tombé.
const CAUSE_HEART := &"heart"

## Il ne reste plus personne au village.
const CAUSE_ROSTER := &"roster"

## Pourquoi le run s'est arrêté.
var _cause: StringName

## Dernière journée jouée.
var _day: int

## Unités restées en réserve, toutes ressources confondues.
var _resources: int

## Bâtiments achevés encore debout.
var _buildings: int

## Ouvriers encore vivants.
var _workers: int

## Somme des niveaux de ces ouvriers.
var _levels: int

## Score total.
var _score: int

## Le compte d'un run fini, et ce qu'il vaut au barème de `data/balance/`.
##
## Les quatre comptes sont gardés à côté du total, et ce n'est pas une redondance : un écran
## de fin qui n'annoncerait qu'un nombre ne dirait pas *ce qui* l'a fait, et recalculer les
## termes en les redivisant par leurs poids serait une seconde arithmétique à tenir d'accord
## avec celle-ci.
static func tally(cause: StringName, day: int, resources: int, buildings: int,
		workers: int, levels: int, balance: RunBalance) -> RunOutcome:
	assert(not cause.is_empty(), "fin de run sans cause")
	assert(day > 0, "fin de run sans jour : %d" % day)
	assert(balance != null, "fin de run sans barème")
	var outcome := RunOutcome.new()
	outcome._cause = cause
	outcome._day = day
	outcome._resources = maxi(0, resources)
	outcome._buildings = maxi(0, buildings)
	outcome._workers = maxi(0, workers)
	outcome._levels = maxi(0, levels)
	outcome._score = outcome._resources * balance.score_per_resource \
		+ outcome._buildings * balance.score_per_building \
		+ outcome._workers * balance.score_per_worker \
		+ outcome._levels * balance.score_per_worker_level
	return outcome

## Pourquoi le run s'est arrêté — l'une des trois constantes ci-dessus.
func cause() -> StringName:
	return _cause

## Le run a-t-il été gagné ?
##
## Dérivé de la cause plutôt que porté à côté : deux champs qui peuvent se contredire
## laisseraient exister une défaite victorieuse. Même geste que `DamageReport.fighters()`,
## qui se déduit du journal au lieu de vivre en double.
func is_victory() -> bool:
	return _cause == CAUSE_SURVIVED

## Dernière journée jouée.
func day() -> int:
	return _day

## Unités restées en réserve.
func resources() -> int:
	return _resources

## Bâtiments achevés encore debout.
func buildings() -> int:
	return _buildings

## Ouvriers encore vivants.
func workers() -> int:
	return _workers

## Somme des niveaux de ces ouvriers.
func levels() -> int:
	return _levels

## Score total.
func score() -> int:
	return _score
