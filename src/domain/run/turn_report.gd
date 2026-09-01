class_name TurnReport
extends RefCounted
## Ce qu'un tour a fait, dans l'ordre où DESIGN.md 2 l'impose.
##
## Immuable. Rendu par RunOrchestrator.end_turn(), et c'est le seul objet que le joueur lit
## au début du tour suivant : « on lit ce que le tour précédent a rendu » est la première
## ligne de la boucle.
##
## Il vit dans domain/run/, comme PlayResult et RunOutcome, et pour la même raison.
##
## ---
##
## **Chacun de ses champs est un fait du tour, jamais un état courant.** La distinction a
## coûté cher au projet et elle décide de ce qui entre ici. « Quels bâtiments dorment en ce
## moment » n'est **pas** un fait du tour : c'est une question d'état, à laquelle
## Staffing.resolve() répond gratuitement à n'importe quel instant, puisque N1 a fait du
## sommeil un calcul et non un état mémorisé. La poser au rapport donnerait une réponse
## vraie **au moment de la résolution**, donc avant le repas — c'est-à-dire la mesure prise
## au mauvais moment que CLAUDE.md nomme depuis F2b, sur une ligne que l'écran afficherait
## en toute confiance.
##
## Ce qui entre ici est donc ce qui **s'est passé** et ne se retrouve nulle part après :
## ce qui a été produit, ce que le plafond a mangé, quels chantiers ont avancé, lesquels
## ont fini, lesquels sont restés sur place faute de bras, ce que le repas a coûté, qui est
## arrivé ou parti. Rien de tout cela n'est lisible sur l'état une fois le tour clos.

## Tour qui vient de se résoudre. Le premier est 1.
var _turn: int

## Ce que les bâtiments ont rendu, et ce que la réserve en a gardé.
var _production: ProductionReport

## Ce que le repas a coûté, et ce qu'il a changé à l'effectif.
var _upkeep: UpkeepReport

## Ancres des chantiers qui ont pris un cran, dans l'ordre de pose.
var _advanced: Array[Vector2i] = []

## Ancres des chantiers qui se sont **achevés** ce tour, dans l'ordre de pose.
##
## Sous-ensemble de _advanced : un chantier qui finit a d'abord avancé. Les deux sont
## rendus séparément parce qu'ils ne disent pas la même chose à l'écran — l'un est un
## progrès, l'autre est un bâtiment qui se met à produire au tour suivant.
var _completed: Array[Vector2i] = []

## Ancres des chantiers qui n'ont **pas** avancé faute de bras, dans l'ordre de pose.
##
## C'est la moitié invisible de la règle de N1, et la plus coûteuse pour le joueur : un
## chantier endormi n'avance pas, donc une famine ne fait pas que suspendre une récolte,
## elle **allonge** tout ce qui est en cours. Sans cette ligne, le tour paraîtrait n'avoir
## rien fait sans dire pourquoi.
var _stalled: Array[Vector2i] = []

## Comment le run s'est terminé, ou null s'il continue.
var _outcome: RunOutcome = null

## Rapport brut. Réservé à RunOrchestrator, qui est le seul à voir les quatre systèmes.
static func create(turn: int, production: ProductionReport, upkeep: UpkeepReport,
		advanced: Array[Vector2i], completed: Array[Vector2i], stalled: Array[Vector2i],
		outcome: RunOutcome = null) -> TurnReport:
	assert(turn > 0, "rapport de tour sans tour : %d" % turn)
	assert(production != null, "rapport de tour sans production")
	assert(upkeep != null, "rapport de tour sans repas")
	var report := TurnReport.new()
	report._turn = turn
	report._production = production
	report._upkeep = upkeep
	report._advanced = advanced.duplicate()
	report._completed = completed.duplicate()
	report._stalled = stalled.duplicate()
	report._outcome = outcome
	for anchor in report._completed:
		assert(report._advanced.has(anchor),
			"chantier achevé sans avoir avancé : %s" % anchor)
	return report

## Tour qui vient de se résoudre.
func turn() -> int:
	return _turn

## Ce que les bâtiments ont rendu.
func production() -> ProductionReport:
	return _production

## Ce que le repas a coûté.
func upkeep() -> UpkeepReport:
	return _upkeep

## Chantiers qui ont avancé, dans l'ordre de pose. Copie.
func advanced() -> Array[Vector2i]:
	return _advanced.duplicate()

## Chantiers achevés ce tour, dans l'ordre de pose. Copie.
func completed() -> Array[Vector2i]:
	return _completed.duplicate()

## Chantiers restés sur place faute de bras, dans l'ordre de pose. Copie.
func stalled() -> Array[Vector2i]:
	return _stalled.duplicate()

## Comment le run s'est terminé, ou null s'il continue.
func outcome() -> RunOutcome:
	return _outcome

## Ce tour a-t-il refermé le run ?
func ends_the_run() -> bool:
	return _outcome != null
