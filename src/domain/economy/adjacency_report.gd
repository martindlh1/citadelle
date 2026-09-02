class_name AdjacencyReport
extends RefCounted
## Ce que le voisinage rapporte à un bâtiment, règle par règle, et **quelles cases** le
## rapportent.
##
## Immuable. Rendu par Adjacency.inspect().
##
## Il vit dans domain/economy/ et non dans contracts/, par le critère habituel : aucun **second
## système du domaine** ne le franchit. La Construction n'en a pas besoin — elle pose sa propre
## question au terrain, plus courte : « au moins une case ? ». Ce qui traverse la frontière est
## `TerrainQuery.tagged_within()`, et c'est là que le contrat a été écrit.
##
## ---
##
## **Il porte les cases et pas seulement leur nombre**, et c'est ce que `C3` lui a ajouté en
## déplaçant l'aperçu du HUD vers le fantôme. Une ligne de texte se contente d'un compte ; une
## carte qui **montre** les cases qui comptent en a besoin nommément. C'est la différence entre
## décrire un emplacement et le faire voir.
##
## **Il constate, il ne décide pas.** « Deux cases de forêt, donc +2 bois » est un fait ; « cet
## emplacement est bon » est un jugement, et personne ici ne le porte.
##
## **Les règles à zéro y figurent aussi.** « 0 forêt » dit pourquoi cet emplacement-ci ne vaut
## rien, ce qu'une liste vide ne dit pas. Une vue qui veut cacher les lignes creuses le peut ;
## l'inverse serait impossible.

## Les règles du bâtiment, dans l'ordre de sa data.
var _rules: Array[AdjacencyRule] = []

## Les cases trouvées pour chacune, dans le même ordre. Un `Array[Vector2i]` par règle.
##
## Le tableau extérieur n'est pas typé : GDScript ne sait pas déclarer un tableau de tableaux
## typés. Les accesseurs, eux, le sont, ce qui met la frontière au bon endroit.
var _found: Array = []

## Rapport brut. Réservé à Adjacency, qui est le seul à savoir le composer.
static func create(rules: Array[AdjacencyRule], found: Array) -> AdjacencyReport:
	assert(rules.size() == found.size(),
		"%d règle(s) pour %d relevé(s)" % [rules.size(), found.size()])
	var report := AdjacencyReport.new()
	report._rules = rules.duplicate()
	report._found = found.duplicate()
	return report

## Rapport d'un bâtiment qui n'a aucune règle.
static func none() -> AdjacencyReport:
	return AdjacencyReport.new()

## Nombre de règles examinées, celles qui n'ont rien trouvé comprises.
func size() -> int:
	return _rules.size()

## Le bâtiment n'a-t-il aucune règle du tout ?
##
## Distinct de « ne rapporte rien » : une ferme loin de toute eau a une règle et un total vide.
## Le fantôme ne dit pas la même chose dans les deux cas — l'un n'a rien à montrer, l'autre a
## une mauvaise nouvelle à montrer.
func is_empty() -> bool:
	return _rules.is_empty()

## La n-ième règle.
func rule(index: int) -> AdjacencyRule:
	assert(index >= 0 and index < _rules.size(), "règle %d hors rapport" % index)
	return _rules[index]

## Les cases que la n-ième règle a trouvées. Copie.
func matched(index: int) -> Array[Vector2i]:
	assert(index >= 0 and index < _found.size(), "règle %d hors rapport" % index)
	var cells: Array[Vector2i] = []
	cells.assign(_found[index])
	return cells

## Combien de cases la n-ième règle a trouvées.
func count(index: int) -> int:
	assert(index >= 0 and index < _found.size(), "règle %d hors rapport" % index)
	return (_found[index] as Array).size()

## Ce que la n-ième règle verse.
##
## Le calcul est délégué à la règle plutôt que refait ici : deux arithmétiques à tenir d'accord
## sont deux occasions de diverger.
func award(index: int) -> int:
	return rule(index).award(count(index))

## Toutes les cases qui comptent, sans doublon, dans l'ordre de balayage.
##
## C'est ce que le fantôme colore. Sans doublon parce que deux règles peuvent trouver la même
## case — une carrière et une mine cherchent le même tag —, et qu'une case peinte deux fois se
## verrait deux fois plus vive sans que rien ne le justifie.
func highlights() -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {}
	var cells: Array[Vector2i] = []
	for entry in _found:
		for cell in entry:
			if seen.has(cell):
				continue
			seen[cell] = true
			cells.append(cell)
	return cells

## Le bâtiment trouve-t-il au moins une case ?
##
## **Ce n'est pas la question que le placement pose.** La Construction la pose au terrain
## directement, et c'est délibéré : lui faire traverser ce rapport ferait dépendre un système
## du domaine des internes d'un autre. Celle-ci sert aux vues, qui lisent le domaine entier.
func is_satisfied() -> bool:
	for entry in _found:
		if not (entry as Array).is_empty():
			return true
	return false

## Tout ce que le voisinage verse, par ressource. Les règles à zéro n'y laissent aucune entrée.
##
## Deux règles qui versent la même ressource s'additionnent.
func total() -> Dictionary[StringName, int]:
	var gained: Dictionary[StringName, int] = {}
	for index in _rules.size():
		var amount := award(index)
		if amount <= 0:
			continue
		var resource := _rules[index].resource
		gained[resource] = gained.get(resource, 0) + amount
	return gained
