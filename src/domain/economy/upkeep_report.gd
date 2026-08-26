class_name UpkeepReport
extends RefCounted
## Ce qu'une journée a coûté à nourrir, et qui n'a pas mangé.
##
## `DESIGN.md` 3.3 : « Upkeep 1 nourriture par ouvrier et par soir, **oisifs compris** —
## c'est ce qui rend un ouvrier non affecté coûteux, et le pool tendu. »
##
## Il vivait dans `ProductionReport` de `E1` à `I1`, et il en est sorti le jour où une
## journée a compté **deux** sortes de résolution. Une phase produit ; une journée coûte.
## Les fusionner obligeait à manger deux fois parce qu'on avait récolté deux fois, ce qui
## est un contresens, ou à porter un upkeep nul la moitié du temps, ce qui est un
## mensonge. `DESIGN.md` 2 les listait déjà comme deux étapes distinctes de la séquence
## de résolution — la fusion était l'accident, pas la séparation.
##
## **Il rapporte, il ne punit pas.** La famine y est un compte d'ouvriers non nourris et
## rien d'autre : ce qu'il leur arrive appartient aux Effectifs, qui possèdent les
## unités, et 3.3 garde la question ouverte. Un rapport qui trancherait ici fermerait ce
## choix sans que personne ne le décide.
##
## Il reste dans `domain/economy/` et n'entre pas dans `contracts/`, comme `PickResult`
## est resté dans `domain/terrain/` : aucun second **système du domaine** ne le franchit
## encore. Il y entrera le jour où la famine aura une conséquence, puisque ce jour-là ce
## sont les Effectifs qui la liront.
##
## Immuable.

## Nourriture due : le roster présent entier, oisifs compris.
var _due: int

## Nourriture réellement prélevée.
var _consumed: int

## Ouvriers que la réserve n'a pas pu nourrir.
var _unfed: int

## Rapport d'un upkeep. Appelé une seule fois, en fin de journée.
static func create(due: int, consumed: int, unfed: int) -> UpkeepReport:
	assert(due >= 0, "upkeep négatif : %d" % due)
	assert(consumed >= 0, "consommation négative : %d" % consumed)
	assert(consumed <= due, "consommé %d pour %d dû" % [consumed, due])
	assert(unfed >= 0, "compte de non-nourris négatif : %d" % unfed)
	var report := UpkeepReport.new()
	report._due = due
	report._consumed = consumed
	report._unfed = unfed
	return report

## Rapport d'une journée sans personne à nourrir.
static func empty() -> UpkeepReport:
	return UpkeepReport.create(0, 0, 0)

## Nourriture due ce jour : le roster présent entier, oisifs compris.
func due() -> int:
	return _due

## Nourriture réellement consommée. Inférieure à due() quand la réserve manque.
func consumed() -> int:
	return _consumed

## Ce qui a manqué. Zéro quand tout le monde a mangé.
func shortfall() -> int:
	return _due - _consumed

## Ouvriers que la réserve n'a pas pu nourrir.
func unfed() -> int:
	return _unfed

## La réserve a-t-elle manqué ?
func is_famine() -> bool:
	return _unfed > 0
