class_name ProductionReport
extends RefCounted
## Ce qu'un tour a produit, ce que la réserve en a gardé, et qui dormait pendant ce temps.
##
## Immuable. Rendu par ProductionResolver.resolve().
##
## Il vit dans domain/economy/ et non dans contracts/, par le critère habituel : aucun
## **second système du domaine** ne le franchit. domain/run/ le lira pour en faire une ligne
## de rapport de tour, et domain/run/ est le seul dossier autorisé à connaître tout le monde ;
## les adapters lisent le domaine, c'est leur métier. C'est la décision que N1 a prise pour
## UpkeepReport et StaffingPlan, reconduite mot pour mot.
##
## ---
##
## **Il constate, il ne décide pas**, comme UpkeepReport. Le fait est « ces trois bâtiments
## n'ont rien rendu parce qu'ils dorment » ; ce que le run en fait — l'afficher, s'en
## alarmer — se décide plus haut.
##
## **Il tient produced et stored séparément, et ce n'est pas une redondance.** Leur écart est
## ce que le plafond a fait perdre, c'est-à-dire la seule chose qui rende un entrepôt
## désirable. Les confondre effacerait l'arbitrage que DESIGN.md 3.3 met au centre de la
## réserve commune : « remplir de bois, c'est renoncer à stocker de la pierre ».

## Ce que les bâtiments ont rendu, avant tout plafond.
var _produced: Dictionary[StringName, int] = {}

## Ce qui est réellement entré en réserve. Sous _produced quand le plafond a mordu.
var _stored: Dictionary[StringName, int] = {}

## Ancres qui ont produit, dans l'ordre de pose.
var _producers: Array[Vector2i] = []

## Ancres qui auraient produit et qui dormaient, dans l'ordre de pose.
var _dormant: Array[Vector2i] = []

## Rapport brut. Réservé à ProductionResolver, qui est le seul à savoir le composer.
static func create(produced: Dictionary[StringName, int],
		stored: Dictionary[StringName, int], producers: Array[Vector2i],
		dormant: Array[Vector2i]) -> ProductionReport:
	var report := ProductionReport.new()
	report._produced = produced.duplicate()
	report._stored = stored.duplicate()
	report._producers = producers.duplicate()
	report._dormant = dormant.duplicate()
	assert(report.overflow() >= 0, "réserve ayant gardé plus qu'il n'a été produit")
	return report

## Ce que les bâtiments ont rendu, avant plafond. Copie.
func produced() -> Dictionary[StringName, int]:
	return _produced.duplicate()

## Ce qui est entré en réserve. Copie.
##
## Une ressource entièrement écrêtée n'y figure pas, de sorte que ce lot se lise comme la
## liste de ce qui est entré — c'est le contrat de Ledger.deposit(), rendu tel quel.
func stored() -> Dictionary[StringName, int]:
	return _stored.duplicate()

## Ancres qui ont produit ce tour, dans l'ordre de pose. Copie.
func producers() -> Array[Vector2i]:
	return _producers.duplicate()

## Ancres qui auraient produit si elles avaient eu des bras, dans l'ordre de pose. Copie.
##
## C'est la phrase que DESIGN.md 3.3 veut qu'un joueur puisse se dire : « cette ferme dort,
## il me manque un toit ». Elle ne liste que les bâtiments qui **produisent** — un entrepôt
## endormi est dans le plan de Staffing, pas ici, parce qu'il ne manque à aucune récolte.
func dormant() -> Array[Vector2i]:
	return _dormant.duplicate()

## Unités perdues au plafond, toutes ressources confondues.
##
## L'écart entre ce qui a été produit et ce qui est entré. C'est l'écrêtage de DESIGN.md 3.3
## vu comme un seul nombre, celui qu'un HUD affiche pour dire « ta réserve déborde ».
func overflow() -> int:
	return _total(_produced) - _total(_stored)

## Le tour a-t-il rendu quelque chose ?
func is_empty() -> bool:
	return _produced.is_empty()

## Y a-t-il des bâtiments de production à l'arrêt ?
func has_dormant() -> bool:
	return not _dormant.is_empty()

func _total(bundle: Dictionary[StringName, int]) -> int:
	var sum := 0
	for resource in bundle:
		sum += bundle[resource]
	return sum
