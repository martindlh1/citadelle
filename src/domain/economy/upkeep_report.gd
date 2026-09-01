class_name UpkeepReport
extends RefCounted
## Ce que le repas d'un tour a coûté, et ce qu'il a changé à l'effectif.
##
## Immuable. Rendu par UpkeepResolver.resolve().
##
## Il vit dans domain/economy/ et non dans contracts/, par le critère habituel : aucun
## second système du domaine ne le franchit. C'est domain/run/ qui le lira pour en faire une
## ligne de rapport de tour, et domain/run/ a le droit de connaître tout le monde.
##
## ---
##
## **Il constate, il ne décide pas.** C'est la règle que DESIGN.md 9 garde du jeu supprimé,
## et elle avait été apprise cher : un système qui rencontre un fait le compte et le
## rapporte, il n'invente pas sa conséquence. Ici le fait est « il a manqué de la nourriture
## pour trois personnes » ; ce que le run en fait — l'annoncer, terminer la partie quand
## l'effectif tombe à zéro — se décide plus haut.

## Nourriture due par l'effectif entier.
var _due: int = 0

## Nourriture réellement prélevée. Inférieure à _due en famine.
var _paid: int = 0

## Habitants qui n'ont pas mangé.
var _unfed: int = 0

## Habitants arrivés ce tour.
var _arrived: int = 0

## Habitants partis ce tour, faute d'avoir mangé.
var _lost: int = 0

## Rapport brut. Réservé à UpkeepResolver.
static func create(due: int, paid: int, unfed: int, arrived: int, lost: int) -> UpkeepReport:
	assert(due >= 0 and paid >= 0, "upkeep négatif")
	assert(paid <= due, "plus prélevé que dû")
	assert(not (arrived > 0 and lost > 0), "un tour ne fait pas venir et partir à la fois")
	var report := UpkeepReport.new()
	report._due = due
	report._paid = paid
	report._unfed = unfed
	report._arrived = arrived
	report._lost = lost
	return report

## Ce que l'effectif devait manger.
func due() -> int:
	return _due

## Ce que la réserve a pu donner.
func paid() -> int:
	return _paid

## Combien n'ont pas mangé. Zéro quand la réserve a suivi.
func unfed() -> int:
	return _unfed

## Combien sont arrivés.
func arrived() -> int:
	return _arrived

## Combien sont partis.
func lost() -> int:
	return _lost

## La réserve a-t-elle manqué ?
##
## Se lit sur les nourritures et non sur les habitants : un village peut manquer d'une
## unité sans que personne ne parte, et c'est déjà une alarme à afficher.
func is_starving() -> bool:
	return _paid < _due
