class_name AdjacencyRule
extends Resource
## Une règle d'adjacence : « +X de telle ressource par case taggée Y à moins de Z, au plus P ».
##
## Les règles vivent sur `BuildingData.adjacency`, une par ligne de la table de
## `DESIGN.md` 3.2. C'est ce qui fait qu'un emplacement vaut mieux qu'un autre : où l'on
## **peut** poser est une question de relief, où il **vaut mieux** poser est celle-ci.
##
## Elle ne résout rien, comme `ProductionBlock` ne résout rien : une `Resource` qui porterait
## une méthode de calcul serait du domaine déguisé. C'est `Adjacency`, dans `src/domain/`, qui
## la lit — et qui la lit **une seule fois pour deux lectures**, la production d'un tour et la
## prévisualisation sous le curseur. Deux calculs auraient divergé, et le premier à mentir
## aurait été celui qu'on regarde.
##
## ---
##
## **Elle lit le terrain, pas les bâtiments voisins.** Un `BuildingData` n'a pas de tags
## aujourd'hui ; lui en donner sans qu'aucune règle les lise serait le champ ajouté d'avance
## que ce projet refuse depuis `E1b`. Le jour où une règle veut « à côté d'un entrepôt », c'est
## un mot de plus dans le schéma et rien de plus ici : `tag` ne dit pas d'où le tag vient.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd. Le filet
## de `missing_fields()` est ici **complet**, ce qui est rare : zéro est invalide pour les cinq
## champs, donc aucun oubli ne passe. Une règle mal remplie ne casse jamais au chargement —
## elle rend simplement zéro, tous les tours, sur un bâtiment qui semble bien posé.

## Le tag de terrain que la règle cherche, tel que `data/terrain/` le pose.
##
## Ce fichier ne peut pas le confronter au catalogue — une `Resource` de schéma ne lit jamais
## l'index —, c'est `GameDatabase` qui le fait au démarrage, comme pour les ressources d'un
## bloc de production.
@export var tag: StringName

## Rayon de recherche en anneaux, depuis la case la plus proche de l'empreinte.
##
## **En anneaux et non en pas**, donc les diagonales comptent : à 1, la zone est la couronne
## qui entoure le bâtiment. C'est ce qu'un joueur voit quand il regarde autour d'une cabane, et
## c'est la même métrique que l'audit emploie pour regrouper deux cols qui se touchent.
##
## **L'empreinte compte**, et c'est une décision de `C3` plutôt qu'une commodité : bâtir une
## carrière *sur* le gisement doit être le bon geste. Le terrain n'est pas consommé par la pose
## — la forêt reste sous la cabane —, donc rien ne s'y oppose, et l'inverse aurait fait d'un
## réflexe universel de jeu de bâtisseur une punition silencieuse.
@export_range(1, 8, 1) var radius: int

## La ressource que le bonus verse, telle que `data/commodities/` la nomme.
##
## Elle n'est pas déduite du bloc de production, et c'est délibéré : rien n'oblige un bâtiment
## à ne se bonifier que sur ce qu'il produit déjà, et un champ explicite se lit dans le `.tres`
## sans qu'il faille aller voir ailleurs ce qu'il désigne.
@export var resource: StringName

## Ce que chaque case taggée rapporte.
@export_range(1, 20, 1) var per_cell: int

## Ce que la règle rapporte **au total**, quel que soit le nombre de cases.
##
## Le cinquième nombre, et il n'est pas décoratif. `T4` rend des cartes couvertes de forêt **en
## bosquets** : un camp de bûcheron posé au milieu d'une futaie a ses huit voisines boisées,
## donc sans plafond il rendrait `+2` de base et `+8` de bonus. Le placement cesse alors d'être
## un choix pour devenir un gros lot, et le reste de la carte n'a plus d'intérêt.
##
## Ce qu'on veut est qu'un bon emplacement **double** à peu près un bâtiment. C'est un chiffre
## d'équilibrage, donc il vit en data — mais dans `data/buildings/` et non dans
## `data/balance/`, parce qu'il décrit ce bâtiment-là et non une règle du jeu.
@export_range(1, 100, 1) var at_most: int

## Ce que cette règle rapporte pour ce nombre de cases trouvées.
##
## Le plafond est appliqué ici et nulle part ailleurs : c'est la seule ligne du projet qui sait
## qu'il existe, et un appelant qui multiplierait lui-même finirait par l'oublier.
func award(cells: int) -> int:
	assert(cells >= 0, "compte de cases négatif : %d" % cells)
	return mini(cells * per_cell, at_most)

## Champs non renseignés. Vide = règle exploitable.
## Agrégée par BuildingData.missing_fields(), qui les préfixe « adjacency[i]. ».
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if tag.is_empty():
		missing.append("tag")
	if radius < 1:
		missing.append("radius")
	if resource.is_empty():
		missing.append("resource")
	if per_cell < 1:
		missing.append("per_cell")
	if at_most < 1:
		missing.append("at_most")
	return missing
