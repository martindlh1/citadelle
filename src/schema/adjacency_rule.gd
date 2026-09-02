class_name AdjacencyRule
extends Resource
## Une règle d'adjacence : « +X de telle ressource par case taggée Y à moins de Z anneaux ».
##
## Les règles vivent sur `BuildingData.adjacency`, une par ligne de la table de
## `DESIGN.md` 3.2. **Elles sont la seule source de production du jeu** : un camp de bûcheron ne
## rend pas du bois parce qu'il existe, il en rend parce qu'il y a des arbres autour de lui, et
## deux fois plus s'il y en a deux fois plus. `ProductionBlock` a disparu avec ce renversement.
##
## Un bâtiment qui porte des règles et n'en satisfait aucune **ne se pose pas** — c'est un
## prérequis dur du placement, et non un rendement nul, parce qu'un bâtiment qui coûte des bras
## et ne rend rien est un piège qu'on ne repère qu'après avoir payé.
##
## Elle ne résout rien : une `Resource` qui porterait une méthode de décision serait du domaine
## déguisé ; `award()` est une multiplication, pas une décision. C'est `Adjacency`, dans
## `src/domain/`, qui la lit — et qui la lit **une seule fois pour deux lectures**, la
## production d'un tour et la prévisualisation sous le curseur. Deux calculs auraient divergé, et le premier à mentir
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
## de `missing_fields()` est ici **complet**, ce qui est rare : zéro est invalide pour les
## quatre champs, donc aucun oubli ne passe. Une règle mal remplie ne casse jamais au
## chargement — elle rend zéro, tous les tours, sur un bâtiment qui semble bien posé.

## Le tag de terrain que la règle cherche, tel que `data/terrain/` le pose.
##
## Ce fichier ne peut pas le confronter au catalogue — une `Resource` de schéma ne lit jamais
## l'index —, c'est `GameDatabase` qui le fait au démarrage, contre les tags que
## `data/terrain/` pose réellement.
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
## Explicite plutôt que déduite du bâtiment : rien n'oblige deux règles d'un même bâtiment à
## verser la même chose, et un champ nommé se lit dans le `.tres` sans aller voir ailleurs.
@export var resource: StringName

## Ce que chaque case taggée rapporte.
@export_range(1, 20, 1) var per_cell: int

## Ce que cette règle rapporte pour ce nombre de cases trouvées.
##
## Une multiplication, et rien d'autre. **Une première version bornait ce produit**, et le
## plafond a été retiré le jour même : il se défendait tant que l'adjacence était un supplément
## posé sur un rendement de base, il fait l'inverse de ce qu'on veut comme source unique. Au
## plafond, une case à deux arbres et une case à dix rendent la même chose, donc le choix de la
## case cesse de compter — dans un jeu dont le placement est l'essence.
func award(cells: int) -> int:
	assert(cells >= 0, "compte de cases négatif : %d" % cells)
	return cells * per_cell

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
	return missing
