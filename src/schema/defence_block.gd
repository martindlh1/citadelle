class_name DefenceBlock
extends Resource
## Ce qu'un bâtiment tire : sa portée, ses dégâts, sa cadence.
##
## Il est **nullable sur BuildingData**, comme le bloc de production l'était : ou bien un
## bâtiment tire et le bloc dit tout, ou bien il ne tire pas et le bloc est absent. Une
## habitation n'a pas « zéro portée », elle n'a pas de bloc.
##
## Ce que ça achète est la doctrine du zéro : à plat sur `BuildingData`, une portée nulle
## serait une valeur parfaitement légitime — sept bâtiments sur neuf ne tirent pas — et un
## champ oublié cesserait d'être détectable. Ici l'existence du bloc porte déjà cette
## information, donc les trois chiffres sont **réclamés**, et un zéro redevient un oubli.
##
## ---
##
## **Trois chiffres et pas un de plus**, et c'est `DESIGN.md` 3.5 qui compte : « il n'y a pas
## de types de dégâts, pas d'armure, pas de ralentissement, pas de zone, pas de priorité de
## ciblage réglable ». Les points de vie ne sont pas ici parce que **tout** ce qui tient debout
## en a — ils vivent sur `BuildingData`, à côté de l'empreinte.
##
## Une vingtaine de nombres pour tout le tower-defense, contre les quatre-vingts d'un jeu
## complet : c'est la seule raison pour laquelle ce format a été retenu, et la tenir est le
## travail de ce fichier.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Portée en cases, **distance de Manhattan** sur la grille.
##
## Manhattan et non en anneaux, à l'inverse de l'adjacence et de l'emprise, et c'est
## `DESIGN.md` 3.5 qui le dit. La différence n'est pas cosmétique : en anneaux, une tour de
## portée 4 couvre 81 cases et son coin diagonal porte aussi loin que sa ligne droite ; en
## Manhattan elle en couvre 41 et sa zone est un losange. C'est la forme qu'on veut — une tour
## tient un **axe**, elle ne tient pas un carré —, et c'est ce qui rend l'arbitrage de 3.5
## lisible : sur le chemin ou à côté.
@export_range(1, 32, 1) var reach: int

## Dégâts par tir.
@export_range(1, 500, 1) var damage: int

## Ticks entre deux tirs.
##
## Une cadence et non une fréquence : c'est le nombre de pas de simulation que la défense
## attend, donc un entier, donc déterministe. `DESIGN.md` 3.5 est explicite là-dessus — aucun
## flottant dans le domaine, et le nombre de ticks est ce qui compte, jamais l'horloge murale.
@export_range(1, 1000, 1) var cadence: int

## Champs non renseignés. Vide = bloc exploitable.
## Agrégé par BuildingData.missing_fields(), qui les préfixe « defence. ».
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if reach < 1:
		missing.append("reach")
	if damage < 1:
		missing.append("damage")
	if cadence < 1:
		missing.append("cadence")
	return missing

## Cette case est-elle à portée d'une défense posée sur celle-là ?
##
## La règle vit ici plutôt que dans le plateau de combat parce qu'elle ne dépend que des deux
## cases et du chiffre : c'est de la géométrie, pas une décision. Le plateau, lui, choisit
## **qui** viser parmi ceux qui sont à portée, et ça n'est pas la même question.
func covers(from: Vector2i, target: Vector2i) -> bool:
	return absi(from.x - target.x) + absi(from.y - target.y) <= reach
