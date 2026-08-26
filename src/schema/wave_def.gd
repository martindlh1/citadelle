class_name WaveDef
extends Resource
## Une vague : ce qui vient, et avec quelle force.
##
## Les .tres vivent dans data/waves/, un par vague. Le domaine la reçoit en argument et ne
## lit jamais GameDatabase, comme pour BuildingData et TerrainData.
##
## **Une Resource et non un DTO de contracts/**, alors que CLAUDE.md la rangeait là depuis
## I0. La correction est faite en même temps que le fichier, et elle suit ce que le projet
## fait déjà partout : une PhaseDef décrit la forme d'une journée et vit dans src/schema/ ;
## une BuildingData traverse tous les systèmes dans un BuildingSnapshot ; ProductionResolver
## et SiteResolver reçoivent leurs blocs d'équilibrage en argument. Un contenu que l'on
## édite dans un .tres n'a rien à faire dans contracts/, qui est l'endroit où deux systèmes
## **du code** se rencontrent.
##
## Ce qu'elle ne porte pas, et c'est presque tout. DESIGN.md 3.6 garde sous un OUVERT le
## « format, vue, durée, degré de contrôle du joueur, direction et nature des vagues, rôle
## du relief » — sept questions que F2 tranchera. Une vague est donc aujourd'hui un chiffre
## et un nom, et c'est délibérément le minimum : l'enrichir d'avance reviendrait à deviner
## la forme du combat, ce que ce jalon a précisément pour rôle de ne pas faire. Ce qui
## compte est que la frontière existe, parce que F1 est le dernier jalon qui la fait bouger.
##
## Elle ne dit pas non plus **quand** elle tombe. La fréquence des vagues est un OUVERT de
## DESIGN.md 2, et un run qui ne se bat pas encore n'a personne pour lire un calendrier :
## l'écrire ici serait une frontière que personne ne franchit. C'est I2 qui la datera, en
## même temps qu'il branchera le combat sur la fin de journée.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Identifiant stable. Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Libellé affiché. C'est la seule chose que l'écran dit de la vague.
##
## Réclamé comme celui d'une PhaseDef, et pour la même raison : une vague sans nom
## s'annoncerait par son identifiant interne, en anglais, au milieu d'un rapport français.
@export var label: String

## Ce qu'elle jette contre le village.
##
## Confrontée à la défense de la ville et des engagés ; la différence est la brèche, et
## tout le reste en découle. C'est le seul chiffre du bouchon de F1, et le premier que
## DESIGN.md 3.6 annonce comme jetable.
@export_range(0, 500, 1) var power: int

## Champs non renseignés ou incohérents. Vide = vague exploitable.
## Vérifiée au boot par GameDatabase, comme les terrains, les bâtiments et les cartes.
##
## `power` est réclamé strictement positif : une vague à zéro se contient toute seule, ne
## casse rien et ne se distingue en rien d'une journée sans combat. Elle n'est pas une
## vague facile, c'est un fichier vide qui se lit comme une vague.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if power <= 0:
		missing.append("power")
	return missing
