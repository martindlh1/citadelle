class_name SiteReport
extends RefCounted
## Ce que les verbes de chantier ont **ordonné** ce soir : les crans posés, la terre
## déplacée, et qui a travaillé à quoi.
##
## Le jumeau de `ProductionReport` pour l'autre moitié des actions jouées. `D2` a posé et
## affecté *Construire* et *Terraformer* sans les exécuter, et le journal de ce jalon
## disait pourquoi : leur effet mute le `CityState` et la `HeightGrid`, donc l'état de
## deux autres systèmes. Un résolveur d'Économie qui les muterait violerait la règle de
## dépendance.
##
## Le chemin propre est celui-ci : **le résolveur ordonne, l'orchestrateur applique.**
## Rien dans ce fichier n'a muté quoi que ce soit — ce sont des ordres, pas des faits, et
## c'est ce qui garde `SiteResolver` aussi pur que `ProductionResolver`. C'est aussi ce
## qui rend le soir rejouable : deux applications du même rapport sur le même état donnent
## le même état.
##
## Les deux tables sont indexées par cellule et non par action, alors que l'affectation
## est rekeyée sur l'action depuis `D2`. Ce n'est pas un retour en arrière : une cellule
## ne peut recevoir qu'**un** *Construire* et qu'**un** *Terraformer* par phase, le
## ciblage refusant deux fois la même carte sur la même cible. La clé est donc unique par
## construction, et l'orchestrateur n'a qu'un endroit où regarder pour muter une cellule.
##
## Immuable.

## Ancre de chantier -> crans posés ce soir.
var _advances: Dictionary[Vector2i, int] = {}

## Cellule -> déplacement de hauteur, en crans signés.
var _shifts: Dictionary[Vector2i, int] = {}

## Qui a tenu un poste de chantier, et dans quelle famille.
var _work: Array[WorkLine] = []

## Rapport d'un soir de chantier.
##
## L'ordre d'insertion des deux tables est celui de la pose des actions, ce qui rend
## l'application déterministe sans avoir à trier : deux runs partis du même seed et de la
## même suite de gestes appliquent les mêmes ordres dans le même ordre.
static func create(advances: Dictionary[Vector2i, int],
		shifts: Dictionary[Vector2i, int], work: Array[WorkLine]) -> SiteReport:
	var report := SiteReport.new()
	for anchor in advances:
		assert(advances[anchor] > 0,
			"chantier avancé de %d cran(s) en %s" % [advances[anchor], anchor])
		report._advances[anchor] = advances[anchor]
	for cell in shifts:
		assert(shifts[cell] != 0, "terrassement nul en %s" % cell)
		report._shifts[cell] = shifts[cell]
	report._work = work.duplicate()
	return report

## Rapport vide : aucun chantier, aucun terrassement. C'est l'état d'un soir où l'on
## n'a joué que des récoltes, et ce n'est pas une erreur.
static func empty() -> SiteReport:
	var no_advance: Dictionary[Vector2i, int] = {}
	var no_shift: Dictionary[Vector2i, int] = {}
	var no_work: Array[WorkLine] = []
	return SiteReport.create(no_advance, no_shift, no_work)

## Ancre de chantier -> crans posés. Copie.
func advances() -> Dictionary[Vector2i, int]:
	return _advances.duplicate()

## Cellule -> déplacement de hauteur signé. Copie.
func shifts() -> Dictionary[Vector2i, int]:
	return _shifts.duplicate()

## Journal de travail des postes de chantier. Copie.
##
## Séparé de celui de `ProductionReport` jusqu'à l'orchestrateur, qui les concatène pour
## la distribution d'XP. Les garder distincts est ce qui permet à chaque résolveur de ne
## rien savoir de l'autre.
func work() -> Array[WorkLine]:
	return _work.duplicate()

## Rien n'a-t-il été ordonné ?
func is_empty() -> bool:
	return _advances.is_empty() and _shifts.is_empty()

## Crans de chantier posés, tous sites confondus.
func total_progress() -> int:
	var posted := 0
	for anchor in _advances:
		posted += _advances[anchor]
	return posted

## Nombre de cellules terrassées.
func shifted_count() -> int:
	return _shifts.size()
