class_name EveningReport
extends RefCounted
## Le compte rendu d'une phase qui a résolu : tout ce que le soir a fait, en un objet.
##
## C'est le « rapport » qui clôt la séquence de `DESIGN.md` 2 — actions jouées, événement,
## upkeep, combat, gain d'XP, rapport. Il agrège les rapports des systèmes plutôt que de
## les recopier : chacun reste le seul auteur de ce qu'il dit, et l'orchestrateur ne fait
## que les tenir ensemble. Les deux cases encore vides de la séquence — l'événement de 3.7
## et le combat de `F1` — entreront de la même façon, par un champ de plus.
##
## Il vit dans `domain/run/` et non dans `contracts/`, comme `ProgressReport` vit dans
## `domain/workforce/` et `PickResult` dans `domain/terrain/` : aucun second système du
## domaine ne le franchit — il va du Cycle de jour aux adapters —, et 3.8 pose que ce
## système-ci est justement celui qui a le droit de connaître tous les autres. Inventer
## une frontière que personne ne traverse la figerait avant qu'on sache sa forme.
##
## Immuable.

## Jour où la phase s'est résolue.
var _day: int

## Identifiant de la phase qui a résolu. Lu depuis la `PhaseDef`, jamais écrit en dur.
var _phase: StringName

## Ce que l'Économie a produit, stocké et mangé.
var _production: ProductionReport

## Ce que les chantiers et le terrassement ont fait.
var _sites: SiteReport

## Ce que les Effectifs ont distribué.
var _progress: ProgressReport

## Qui n'a rien fait de la soirée.
var _idle: Array[StringName] = []

## Chantiers que ce soir a menés à leur dernier cran.
var _completed: Array[Vector2i] = []

## Rapport d'un soir. Appelé une seule fois, en fin de résolution.
##
## `idle` est fourni plutôt que relu sur `production.idle()`, et c'est le seul champ de ce
## fichier qui recopie quelque chose. La raison est un piège que `I1` a ouvert : le
## rapport de production ne connaît que les postes de production, si bien qu'un ouvrier
## parti bâtir y **figure comme oisif**. Les deux lectures sont chacune juste dans leur
## système et fausses dans la journée ; celle-ci, qui voit les deux journaux de travail,
## est la seule qui puisse répondre pour le soir entier.
##
## `ProductionReport.idle()` n'a pas été corrigé pour autant : le corriger lui demanderait
## de connaître le travail de chantier, donc de recevoir un rapport qu'un autre système
## produit, ce qui est exactement la dépendance que la ligne de contrat de 3.3 refuse.
static func create(day: int, phase: StringName, production: ProductionReport,
		sites: SiteReport, progress: ProgressReport, idle: Array[StringName],
		completed: Array[Vector2i]) -> EveningReport:
	assert(day > 0, "rapport de soirée sans jour : %d" % day)
	assert(production != null, "rapport de soirée sans production")
	assert(sites != null, "rapport de soirée sans chantiers")
	assert(progress != null, "rapport de soirée sans progression")
	var report := EveningReport.new()
	report._day = day
	report._phase = phase
	report._production = production
	report._sites = sites
	report._progress = progress
	report._idle = idle.duplicate()
	report._completed = completed.duplicate()
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

## Ouvriers qui n'ont tenu **aucun** poste ce soir, ni de production ni de chantier.
## Copie.
##
## La seule lecture juste de l'oisiveté d'une soirée. Voir create().
func idle() -> Array[StringName]:
	return _idle.duplicate()

## Ancres des chantiers achevés ce soir, dans l'ordre d'application. Copie.
##
## Dérivable de l'état de la ville après coup, et pourtant rapporté : « la ferme est
## finie » est l'événement de la soirée, et le retrouver demanderait de comparer la ville
## d'avant à celle d'après, ce que personne d'autre que l'orchestrateur ne peut faire.
func completed() -> Array[Vector2i]:
	return _completed.duplicate()

## Combien d'ouvriers ont tenu un poste, production et chantiers confondus.
func manned_count() -> int:
	return _production.work().size() + _sites.work().size()
