class_name ProductionReport
extends RefCounted
## Ce qu'une résolution a produit, stocké et perdu.
##
## Produit par l'Économie ; consommé par les Effectifs pour l'XP — via work() — et par
## les adapters pour l'affichage. Immuable.
##
## **L'upkeep n'y est plus.** Il y a vécu de `E1` à `I1`, tant qu'une journée n'avait
## qu'une seule résolution et que les deux tombaient forcément ensemble. La journée en
## compte désormais deux sortes : ce qu'une **phase** produit, et ce qu'une **journée**
## coûte. Manger deux fois parce qu'on a récolté deux fois serait un contresens, et un
## rapport qui porterait un upkeep nul la moitié du temps mentirait plutôt que de se
## taire. Voir `UpkeepReport`, et `DESIGN.md` 2 qui listait déjà les deux comme des
## étapes distinctes de la séquence.

var _produced: Dictionary[StringName, int] = {}
var _stored: Dictionary[StringName, int] = {}
var _work: Array[WorkLine] = []
var _idle: Array[StringName] = []

## Rapport d'une résolution. Appelé une seule fois, en fin de production.
##
## `produced` est la récolte brute et `stored` ce qui a franchi le plafond : les deux
## y figurent plutôt qu'un seul, parce que la différence est justement ce que la
## réserve commune fait perdre, et qu'un joueur qui ne la voit pas ne comprend pas
## pourquoi son entrepôt manque.
static func create(produced: Dictionary[StringName, int],
		stored: Dictionary[StringName, int], work: Array[WorkLine],
		idle: Array[StringName]) -> ProductionReport:
	var report := ProductionReport.new()
	report._produced = produced.duplicate()
	report._stored = stored.duplicate()
	report._work = work.duplicate()
	report._idle = idle.duplicate()
	return report

## Récolte brute du soir, avant le plafond. Copie.
func produced() -> Dictionary[StringName, int]:
	return _produced.duplicate()

## Ce qui est réellement entré en réserve. Copie.
func stored() -> Dictionary[StringName, int]:
	return _stored.duplicate()

## Ce que le plafond a fait perdre, par ressource. Dérivé : produit moins stocké.
##
## Une ressource qui n'a rien perdu n'y figure pas, plutôt que d'y figurer à zéro : le
## dictionnaire se lit alors comme la liste de ce qui a débordé.
func wasted() -> Dictionary[StringName, int]:
	var lost: Dictionary[StringName, int] = {}
	for resource in _produced:
		var over: int = _produced[resource] - _stored.get(resource, 0)
		if over > 0:
			lost[resource] = over
	return lost

## Total perdu au plafond, toutes ressources confondues.
##
## En réserve commune, c'est ce chiffre-là qui se lit d'un coup d'œil : peu importe
## laquelle a débordé, c'est la réserve entière qui était pleine.
func total_wasted() -> int:
	var lost := wasted()
	var total := 0
	for resource in lost:
		total += lost[resource]
	return total

## Journal de travail : qui a tenu quel slot, dans quelle famille. Copie.
func work() -> Array[WorkLine]:
	return _work.duplicate()

## Ouvriers qui n'ont rien produit — non affectés, affectés à une ancre vide, ou
## arrivés quand les slots de leur bâtiment étaient déjà pris. Copie.
##
## La raison n'est pas distinguée : « trois oisifs » suffit à l'affichage, et les
## séparer supposerait de savoir laquelle intéresse le joueur, ce que E2 tranchera
## devant une vraie maquette.
##
## Attention à la portée depuis I1 : c'est l'oisiveté **telle que l'Économie la voit**,
## donc un ouvrier parti sur un chantier y figure. Seul le rapport de phase, qui voit les
## deux journaux de travail, répond pour la résolution entière.
func idle() -> Array[StringName]:
	return _idle.duplicate()
