class_name DaySummary
extends RefCounted
## Ce que la journée a rendu, avant qu'on la ferme.
##
## `DESIGN.md` 2 le demande à `P2b`, et sa raison vient de plusieurs runs entiers joués à la
## main : **rien ne se souvenait d'une journée.** Chaque `PhaseReport` était émis puis
## oublié, et `DayReport` ne porte que l'upkeep et la vague. Un joueur qui voulait savoir ce
## que sa journée avait rapporté n'avait qu'un compte rendu de phase, dont la moitié était
## déjà remplacée par la suivante.
##
## **Il n'invente aucun chiffre.** Il additionne des rapports que les systèmes ont rendus,
## et rien d'autre : la somme est de l'arithmétique, pas une règle. Ce qui le sépare d'un
## accumulateur écrit dans une vue est ailleurs, et c'est ce que 2. donne comme argument :
## l'événement de 3.7 et les états d'ouvrier de `X6` voudront tous deux poser une ligne
## ici, et un accumulateur d'adapter devrait réapprendre chaque nouvelle source.
##
## **Il ne compte aucun oisif, et ce n'est pas un oubli.** Un oisif est un état de *phase* :
## quelqu'un qui chôme le matin et travaille l'après-midi n'est pas « un demi-oisif », et
## additionner deux ensembles de personnes rendrait un nombre qui ne désigne personne. Les
## postes tenus, eux, s'additionnent — ce sont des affectations, pas des gens. C'est la
## même distinction que `I2b` a tirée sur une phase qui ne résout pas : un oisif est un
## reproche, et un reproche a besoin d'un moment où l'on pouvait faire autrement.
##
## **L'upkeep y est *dû* et non consommé.** Il est prélevé à la fermeture de la journée, et
## ce bilan se lit avant — 2. tranche le moment et dit ce que ça coûte : les deux ne
## diffèrent qu'en famine, qui a déjà son alarme ailleurs. Ce qu'on achète en échange est un
## bilan qui n'ajoute aucun geste, puisque le bouton qui le referme est celui qui ferme la
## journée.
##
## Immuable, comme tous les rapports, et rangé dans `domain/run/` par le critère habituel :
## aucun second système du domaine ne le franchit. Il va du Cycle de jour aux adapters, et
## 3.8 pose que ce système-ci est justement celui qui a le droit de connaître tous les
## autres.

var _day: int
var _resolutions: int
var _produced: Dictionary[StringName, int] = {}
var _stored: Dictionary[StringName, int] = {}
var _wasted: Dictionary[StringName, int] = {}
var _completed: Array[Vector2i] = []
var _advanced: int
var _shifted: int
var _manned: int
var _xp: int
var _skill_ups: Array[SkillGain] = []
var _worker_ups: Array[SkillGain] = []
var _upkeep_due: int

## Le bilan de cette journée, composé de ses rapports de phase.
##
## Les rapports reçus sont ceux des phases qui ont **résolu**, dans l'ordre où elles se sont
## jouées. Une phase qui ne résout pas n'a rien produit, donc rien à additionner : la
## compter parmi les résolutions ferait mentir la seule colonne qui dise combien de fois la
## journée a travaillé.
##
## `upkeep_due` est **fourni** plutôt que calculé ici. Ce que le village doit à manger est
## une question d'Économie, et ce fichier ne connaît ni la réserve ni l'équilibrage — la
## même frontière que `DamageReport`, qui dit combien une vague emporte et jamais quoi.
static func of(day: int, reports: Array[PhaseReport], upkeep_due: int) -> DaySummary:
	assert(day > 0, "bilan d'une journée sans numéro : %d" % day)
	assert(upkeep_due >= 0, "upkeep dû négatif : %d" % upkeep_due)
	var summary := DaySummary.new()
	summary._day = day
	summary._upkeep_due = upkeep_due
	summary._resolutions = reports.size()
	for report in reports:
		assert(report != null, "bilan de journée avec un rapport nul")
		summary._fold(report)
	return summary

## Jour dont c'est le bilan.
func day() -> int:
	return _day

## Combien de fois la journée a résolu.
func resolutions() -> int:
	return _resolutions

## Ce que la journée a récolté, avant écrêtage. Ressource -> quantité.
func produced() -> Dictionary[StringName, int]:
	return _produced.duplicate()

## Ce qui est réellement entré en réserve.
func stored() -> Dictionary[StringName, int]:
	return _stored.duplicate()

## Ce que le plafond a refusé.
func wasted() -> Dictionary[StringName, int]:
	return _wasted.duplicate()

## Total perdu au plafond, toutes ressources confondues.
func total_wasted() -> int:
	var lost := 0
	for resource in _wasted:
		lost += _wasted[resource]
	return lost

## Ancres des chantiers menés à leur dernier cran aujourd'hui.
##
## Un bâtiment achevé est **l'événement** d'une journée, ce que `PhaseReport` avait déjà
## reconnu en le rapportant plutôt qu'en le laissant déduire d'une comparaison de villes.
func completed() -> Array[Vector2i]:
	return _completed.duplicate()

## Crans de chantier posés dans la journée.
func advanced() -> int:
	return _advanced

## Cellules terrassées dans la journée.
func shifted() -> int:
	return _shifted

## Postes tenus, toutes phases confondues.
##
## Des **affectations** et non des gens : le même ouvrier compte deux fois s'il a tenu deux
## postes, ce qui est exactement ce qu'on veut dire par « la journée a fait travailler onze
## fois quelqu'un ». Voir le docstring du fichier pour ce que ça interdit — l'oisiveté.
func manned() -> int:
	return _manned

## XP distribuée dans la journée.
func total_xp() -> int:
	return _xp

## Paliers de piste franchis, dans l'ordre où les phases les ont rendus.
func skill_level_ups() -> Array[SkillGain]:
	return _skill_ups.duplicate()

## Paliers de niveau d'ouvrier franchis.
func worker_level_ups() -> Array[SkillGain]:
	return _worker_ups.duplicate()

## Ce que la fermeture de cette journée va prélever.
func upkeep_due() -> int:
	return _upkeep_due

## La journée n'a-t-elle rien produit du tout ?
##
## Vrai d'une journée dont aucune phase n'a encore résolu — le matin d'un jour qui commence
## — et d'une journée entièrement chômée. L'upkeep, lui, est dû dans les deux cas : c'est ce
## que `DESIGN.md` 2 sépare depuis `I1`, une phase produit et une journée coûte.
func is_empty() -> bool:
	return _resolutions <= 0 or (_produced.is_empty() and _manned <= 0
		and _advanced <= 0 and _shifted <= 0 and _xp <= 0)

## Ajoute ce qu'une phase a rendu.
func _fold(report: PhaseReport) -> void:
	_add_into(_produced, report.production().produced())
	_add_into(_stored, report.production().stored())
	_add_into(_wasted, report.production().wasted())
	_manned += report.manned_count()
	_completed.append_array(report.completed())
	_advanced += report.sites().total_progress()
	_shifted += report.sites().shifted_count()
	_xp += report.progress().total_xp()
	_skill_ups.append_array(report.progress().skill_level_ups())
	_worker_ups.append_array(report.progress().worker_level_ups())

## Somme d'un lot dans un autre. Une ressource absente entre à sa valeur.
static func _add_into(total: Dictionary[StringName, int],
		bundle: Dictionary[StringName, int]) -> void:
	for resource in bundle:
		total[resource] = total.get(resource, 0) + bundle[resource]
