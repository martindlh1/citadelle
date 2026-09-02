class_name AdjacencyReport
extends RefCounted
## Ce que le voisinage rapporte à un bâtiment, règle par règle.
##
## Immuable. Rendu par Adjacency.inspect().
##
## Il vit dans domain/economy/ et non dans contracts/, par le critère habituel : aucun **second
## système du domaine** ne le franchit. L'Économie le produit et le consomme pour verser la
## récolte ; les adapters le lisent pour dessiner la fiche sous le curseur, et lire le domaine
## est leur métier.
##
## ---
##
## **Il constate, il ne décide pas.** « Deux cases de forêt, donc +2 bois » est un fait ; « cet
## emplacement est bon » est un jugement, et personne ici ne le porte. C'est ce qui lui permet
## de servir deux lectures qui ne veulent pas la même chose : la production d'un tour n'a
## besoin que du `total()`, la fiche de placement a besoin du **détail**, parce que ce qu'un
## joueur doit comprendre n'est pas le chiffre mais **d'où il vient**.
##
## **Les règles à zéro y figurent aussi**, et c'est la moitié de son intérêt. « 0 forêt » sous
## un curseur dit pourquoi cet emplacement-ci ne vaut rien, ce qu'une liste vide ne dit pas —
## et `DESIGN.md` 3.2 est explicite : sans retour visuel du delta, l'adjacence est invisible,
## donc inexistante. Une vue qui veut cacher les lignes creuses le peut ; l'inverse serait
## impossible.

## Les règles du bâtiment, dans l'ordre de sa data.
var _rules: Array[AdjacencyRule] = []

## Cases taggées trouvées pour chacune, dans le même ordre.
var _counts: PackedInt32Array = PackedInt32Array()

## Rapport brut. Réservé à Adjacency, qui est le seul à savoir le composer.
static func create(rules: Array[AdjacencyRule], counts: PackedInt32Array) -> AdjacencyReport:
	assert(rules.size() == counts.size(),
		"%d règle(s) pour %d compte(s)" % [rules.size(), counts.size()])
	var report := AdjacencyReport.new()
	report._rules = rules.duplicate()
	report._counts = counts.duplicate()
	return report

## Rapport d'un bâtiment qui n'a aucune règle.
static func none() -> AdjacencyReport:
	return AdjacencyReport.new()

## Nombre de règles examinées, celles qui n'ont rien trouvé comprises.
func count() -> int:
	return _rules.size()

## Le bâtiment n'a-t-il aucune règle du tout ?
##
## Distinct de « ne rapporte rien » : une ferme loin de toute eau a une règle et un total vide.
## La fiche ne dit pas la même chose dans les deux cas — l'une n'a rien à dire, l'autre a une
## mauvaise nouvelle.
func is_empty() -> bool:
	return _rules.is_empty()

## La n-ième règle.
func rule(index: int) -> AdjacencyRule:
	assert(index >= 0 and index < _rules.size(), "règle %d hors rapport" % index)
	return _rules[index]

## Cases taggées trouvées par la n-ième règle.
func cells(index: int) -> int:
	assert(index >= 0 and index < _counts.size(), "règle %d hors rapport" % index)
	return _counts[index]

## Ce que la n-ième règle verse, plafond appliqué.
##
## Le calcul est délégué à la règle plutôt que refait ici : le plafond ne vit qu'à un endroit,
## et deux arithmétiques à tenir d'accord sont deux occasions de diverger.
func award(index: int) -> int:
	return rule(index).award(cells(index))

## La n-ième règle a-t-elle atteint son plafond ?
##
## Utile à la fiche : un emplacement au plafond dit qu'on ne gagnera rien à chercher mieux,
## ce qui est une information de placement et non un détail d'affichage.
func is_capped(index: int) -> bool:
	var rule_at := rule(index)
	return cells(index) * rule_at.per_cell >= rule_at.at_most

## Tout ce que le voisinage verse, par ressource. Les règles à zéro n'y laissent aucune entrée.
##
## Deux règles qui versent la même ressource s'additionnent, chacune sous **son** plafond. Un
## plafond commun aurait demandé un sixième nombre et une explication à donner.
func total() -> Dictionary[StringName, int]:
	var gained: Dictionary[StringName, int] = {}
	for index in _rules.size():
		var amount := award(index)
		if amount <= 0:
			continue
		var resource := _rules[index].resource
		gained[resource] = gained.get(resource, 0) + amount
	return gained
