class_name PhaseReport
extends RefCounted
## Le compte rendu d'une phase qui a résolu : ce que les actions posées ont donné.
##
## Il agrège les rapports des systèmes plutôt que de les recopier : chacun reste le seul
## auteur de ce qu'il dit, et l'orchestrateur ne fait que les tenir ensemble.
##
## **Il porte un `DayReport` quand la phase a fermé la journée**, et null sinon. C'est ce
## qui permet à une journée de compter deux résolutions sans deux types de retour : on
## produit à chaque phase, on mange une fois par jour. `closes_the_day()` dit laquelle des
## deux on lit.
##
## *(Il s'est appelé `EveningReport` le temps d'un jalon, quand une journée n'avait qu'une
## seule résolution et que « soir » et « phase » désignaient la même chose. Ils se sont
## séparés, et le nom a suivi : le soir est maintenant ce que `DayReport` décrit.)*
##
## Il vit dans `domain/run/` et non dans `contracts/`, comme `ProgressReport` vit dans
## `domain/workforce/` et `PickResult` dans `domain/terrain/` : aucun second système du
## domaine ne le franchit — il va du Cycle de jour aux adapters —, et 3.8 pose que ce
## système-ci est justement celui qui a le droit de connaître tous les autres.
##
## Immuable.

## Jour où la phase s'est résolue.
var _day: int

## Identifiant de la phase qui a résolu. Lu depuis la `PhaseDef`, jamais écrit en dur.
var _phase: StringName

## Ce que l'Économie a produit et stocké.
var _production: ProductionReport

## Ce que les chantiers et le terrassement ont fait.
var _sites: SiteReport

## Ce que les Effectifs ont distribué.
var _progress: ProgressReport

## Qui n'a rien fait de la phase.
var _idle: Array[StringName] = []

## Chantiers que cette phase a menés à leur dernier cran.
var _completed: Array[Vector2i] = []

## La journée que cette phase a fermée, ou null si elle ne l'a pas fermée.
var _day_report: DayReport = null

## Rapport d'une phase. Appelé une seule fois, en fin de résolution.
##
## `idle` est fourni plutôt que relu sur `production.idle()`, et c'est le seul champ de ce
## fichier qui recopie quelque chose. La raison est un piège que `I1` a ouvert : le
## rapport de production ne connaît que les postes de production, si bien qu'un ouvrier
## parti bâtir y **figure comme oisif**. Les deux lectures sont chacune juste dans leur
## système et fausses dans la phase ; celle-ci, qui voit les deux journaux de travail, est
## la seule qui puisse répondre pour la phase entière.
##
## `ProductionReport.idle()` n'a pas été corrigé pour autant : le corriger lui demanderait
## de connaître le travail de chantier, donc de recevoir un rapport qu'un autre système
## produit, ce qui est exactement la dépendance que la ligne de contrat de 3.3 refuse.
static func create(day: int, phase: StringName, production: ProductionReport,
		sites: SiteReport, progress: ProgressReport, idle: Array[StringName],
		completed: Array[Vector2i], day_report: DayReport = null) -> PhaseReport:
	assert(day > 0, "rapport de phase sans jour : %d" % day)
	assert(production != null, "rapport de phase sans production")
	assert(sites != null, "rapport de phase sans chantiers")
	assert(progress != null, "rapport de phase sans progression")
	var report := PhaseReport.new()
	report._day = day
	report._phase = phase
	report._production = production
	report._sites = sites
	report._progress = progress
	report._idle = idle.duplicate()
	report._completed = completed.duplicate()
	report._day_report = day_report
	return report

## Jour de la résolution.
func day() -> int:
	return _day

## Phase qui a résolu.
func phase() -> StringName:
	return _phase

## Ce que l'Économie a rendu.
func production() -> ProductionReport:
	return _production

## Ce que les chantiers ont rendu.
func sites() -> SiteReport:
	return _sites

## Ce que les Effectifs ont rendu.
func progress() -> ProgressReport:
	return _progress

## Cette phase a-t-elle fermé la journée ?
func closes_the_day() -> bool:
	return _day_report != null

## Ce que la journée a coûté, ou null si cette phase ne l'a pas fermée.
##
## Null plutôt qu'un rapport vide, pour la même raison qu'un bâtiment qui ne produit pas
## n'a pas « zéro slot » mais **pas de bloc** : un upkeep à zéro se lirait comme une
## journée où personne n'a mangé, ce qui est une autre affirmation.
func day_report() -> DayReport:
	return _day_report

## Ouvriers qui n'ont tenu **aucun** poste, ni de production ni de chantier. Copie.
##
## La seule lecture juste de l'oisiveté d'une phase. Voir create().
func idle() -> Array[StringName]:
	return _idle.duplicate()

## Ancres des chantiers achevés, dans l'ordre d'application. Copie.
##
## Dérivable de l'état de la ville après coup, et pourtant rapporté : « la ferme est
## finie » est l'événement de la phase, et le retrouver demanderait de comparer la ville
## d'avant à celle d'après, ce que personne d'autre que l'orchestrateur ne peut faire.
func completed() -> Array[Vector2i]:
	return _completed.duplicate()

## Combien d'ouvriers ont tenu un poste, production et chantiers confondus.
func manned_count() -> int:
	return _production.work().size() + _sites.work().size()
