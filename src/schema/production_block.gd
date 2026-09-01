class_name ProductionBlock
extends Resource
## Ce qu'un bâtiment déclare produire, par tour.
##
## Il est **nullable sur BuildingData** : ou bien un bâtiment produit et le bloc dit
## tout, ou bien il ne produit pas et le bloc est absent. L'entrepôt et l'habitation
## n'ont pas « zéro rendement », ils n'ont pas de bloc. Tranché avant E1b, voir
## DESIGN.md 3.3.
##
## Ce que ça achète, et c'est la raison d'être du fichier : **la doctrine du zéro
## redevient applicable**. À E1 ses champs vivaient à plat sur BuildingData, où un
## rendement vide était une valeur parfaitement légitime — la palissade ne produit rien.
## Un champ non renseigné y cessait donc d'être détectable. Ici, l'existence du bloc porte
## déjà cette information : un bloc qui existe produit, donc son rendement est
## obligatoire, et un rendement vide redevient ce qu'il était partout ailleurs — un oubli.
##
## **N1 lui a retiré deux champs sur trois**, et c'était un résidu que `R0` avait laissé
## passer. `slots` comptait les postes qu'une carte venait tenir ; `skill_family` nommait la
## piste de compétence que le travail créditait. Les deux décrivaient des systèmes que le
## rescope a supprimés, et un `skill_family = &"harvest"` dans un `.tres` était exactement le
## genre de reste dont `R0` s'était promis de ne pas laisser traîner.
##
## Ce qui reste dit ce que le nouveau modèle veut, et rien de plus : **un bâtiment achevé,
## peuplé et non endormi verse ce rendement à chaque tour**, sans qu'on lui demande rien.
## Ses travailleurs ont été payés à l'ouverture de son chantier — voir BuildingData.workers.
##
## Ce fichier ne résout rien et n'en résoudra jamais. Une Resource qui porterait une
## méthode de résolution serait du domaine déguisé. Le jour où un bâtiment produit
## **autrement** — au voisinage, à l'événement, au palier —, cette classe devient une
## base et c'est le résolveur, dans src/domain/, qui commute sur son type. L'adjacence de
## `C3` est le premier candidat, et elle est datée.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Ce que le bâtiment verse à chaque tour.
##
## Les clés sont des identifiants de data/commodities/. Ce fichier ne peut pas les
## contrôler seul — une Resource de schéma ne lit jamais l'index —, c'est GameDatabase
## qui les confronte au catalogue au démarrage.
@export var yield_per_turn: Dictionary[StringName, int]

## Champs non renseignés. Vide = bloc exploitable.
## Agrégé par BuildingData.missing_fields(), qui les préfixe « production. ».
##
## Le rendement est réclamé sans condition : un bloc qui existe produit, par définition, et
## un rendement absent ne casse pas au chargement — il ne casse qu'au premier tour, en ne
## versant rien, ce qui est précisément pourquoi le boot le réclame.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if yield_per_turn.is_empty():
		missing.append("yield_per_turn")
	for resource in yield_per_turn:
		if yield_per_turn[resource] <= 0:
			missing.append("yield_per_turn.%s" % resource)
	return missing
