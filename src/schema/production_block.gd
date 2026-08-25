class_name ProductionBlock
extends Resource
## Ce qu'un bâtiment déclare produire : ses postes, ce qu'ils rendent, et la famille de
## compétence qu'ils emploient.
##
## Il est **nullable sur BuildingData** : ou bien un bâtiment produit et le bloc dit
## tout, ou bien il ne produit pas et le bloc est absent. L'entrepôt et l'habitation
## n'ont pas « zéro slot », ils n'ont pas de bloc. Tranché avant E1b, voir DESIGN.md
## 3.3.
##
## Ce que ça achète, et c'est la raison d'être du fichier : **la doctrine du zéro
## redevient applicable**. À E1 ces trois champs vivaient à plat sur BuildingData, où 0
## slot était une valeur parfaitement légitime — la palissade n'a pas de poste. Un
## champ non renseigné y cessait donc d'être détectable, et il fallait le remplacer par
## un contrôle de cohérence entre les trois. Ici, l'existence du bloc porte déjà cette
## information : un bloc qui existe produit, donc ses trois champs sont obligatoires
## ensemble, et 0 slot redevient ce qu'il était partout ailleurs — un oubli.
##
## La cohérence cesse d'être vérifiée pour devenir **structurelle** : il n'est plus
## possible d'écrire des slots sans rendement, ou un poste sans famille, parce que les
## trois vivent ou meurent ensemble.
##
## Ce fichier ne résout rien et n'en résoudra jamais. Une Resource qui porterait une
## méthode de résolution serait du domaine déguisé, et le jour où il lui faut le
## terrain, la ville et le roster, on aurait recodé ProductionResolver dans
## src/schema/. Le jour où un bâtiment produit **autrement** — au voisinage, à
## l'événement, au palier —, cette classe devient une base et c'est le résolveur, dans
## src/domain/, qui commute sur son type.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Nombre de postes de travail.
##
## La borne basse de la plage est 0 et non 1, comme height dans BuildingData : un champ
## jamais renseigné vaut 0 quoi qu'annonce l'inspecteur, et une plage qui commencerait
## à 1 afficherait une valeur que le fichier ne contient pas. C'est missing_fields()
## qui réclame, pas la plage.
@export_range(0, 8, 1) var slots: int

## Ce qu'un slot occupé rapporte en un soir, avant le multiplicateur de l'ouvrier.
##
## Les clés sont des identifiants de data/commodities/. Ce fichier ne peut pas les
## contrôler seul — une Resource de schéma ne lit jamais l'index —, c'est GameDatabase
## qui les confronte au catalogue au démarrage.
@export var yield_per_slot: Dictionary[StringName, int]

## Famille de compétence que ses postes emploient.
##
## C'est elle qui décide quel multiplicateur de l'ouvrier s'applique au rendement, et
## quelle piste l'XP créditera en retour. Un bâtiment qui n'a pas de bloc n'en a pas
## besoin ; un bloc qui existe, si.
@export var skill_family: StringName

## Champs non renseignés. Vide = bloc exploitable.
## Agrégé par BuildingData.missing_fields(), qui les préfixe « production. ».
##
## Les trois sont réclamés sans condition, ce qui n'était pas possible à E1. Un bloc
## sans slot ne serait jamais tenu, un rendement absent ne serait jamais versé, et un
## poste sans famille ne saurait ni quel multiplicateur appliquer ni quelle piste
## créditer. Aucun des trois ne casse au chargement : ils ne cassent qu'au premier soir
## de production, ce qui est précisément pourquoi le boot les réclame.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if slots <= 0:
		missing.append("slots")
	if yield_per_slot.is_empty():
		missing.append("yield_per_slot")
	if skill_family.is_empty():
		missing.append("skill_family")
	for resource in yield_per_slot:
		if yield_per_slot[resource] <= 0:
			missing.append("yield_per_slot.%s" % resource)
	return missing
