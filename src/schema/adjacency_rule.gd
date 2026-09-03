class_name AdjacencyRule
extends Resource
## Une règle d'adjacence : « il faut du Y à moins de Z anneaux, et ça paie tant, de telle
## façon ».
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
## **Toutes les règles sont donc des exigences ; ce qui les sépare est ce qu'elles paient.**
## C'est le sens de `mode`, entré à `C7` : « +1 par arbre » ne savait pas dire « il faut de
## l'eau, et une seconde case d'eau n'y ajoute rien », ni « il faut toucher la veine, et c'est
## la veine entière qui paie ».
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
## cinq champs, donc aucun oubli ne passe. Une règle mal remplie ne casse jamais au
## chargement — elle rend zéro, tous les tours, sur un bâtiment qui semble bien posé.

## Comment une règle paie ce qu'elle a trouvé. UNSET vaut 0 pour rester détectable.
##
## Les trois disent une chose différente sur le **rapport entre la quantité de terrain et le
## rendement**, et c'est le seul axe sur lequel ils diffèrent : dans les trois cas il faut
## trouver au moins une case, sans quoi le bâtiment ne se pose pas.
##
## - `PER_CELL` — le rendement suit le nombre de cases à portée. Deux fois plus d'arbres, deux
##   fois plus de bois.
## - `FLAT` — il faut la case, elle ne paie qu'une fois. « La ferme doit être au bord de
##   l'eau » : irriguer est une affaire d'accès, pas de quantité, et un bonus par case aurait
##   primé absurdement le fait de border un lac sur trois côtés.
## - `VEIN` — il faut toucher le gisement, et c'est **le gisement entier** qui paie, au-delà du
##   rayon. La mine ne vit pas de ce qu'elle voit autour d'elle mais de ce qu'il y a à extraire
##   dessous, et ce mode fait du choix d'une case une question de prospection : deux
##   emplacements à un caillou près ne valent pas la même chose quand l'un touche une veine de
##   deux cases et l'autre une veine de onze.
enum Mode {
	UNSET = 0,
	PER_CELL = 1,
	FLAT = 2,
	VEIN = 3,
}

## Le tag de terrain que la règle cherche, tel que `data/terrain/` le pose.
##
## Ce fichier ne peut pas le confronter au catalogue — une `Resource` de schéma ne lit jamais
## l'index —, c'est `GameDatabase` qui le fait au démarrage, contre les tags que
## `data/terrain/` pose réellement.
@export var tag: StringName

## Comment cette règle paie ce qu'elle a trouvé. Voir Mode.
@export var mode: Mode

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

## Ce qu'une **unité** rapporte, l'unité dépendant du mode.
##
## Une case trouvée pour `PER_CELL`, une case de filon pour `VEIN`, et le versement entier pour
## `FLAT` — qui n'en compte aucune. Le champ s'appelait `per_cell` jusqu'à `C7` et le renommage
## n'est pas cosmétique : sur une règle à la présence, « par case » désignait une quantité que
## la règle ignore précisément.
@export_range(1, 40, 1) var amount: int

## Ce que cette règle rapporte pour ce nombre d'unités trouvées.
##
## **Elle ne sait pas ce qu'est une unité, et c'est le partage.** Compter est l'affaire
## d'`Adjacency`, qui voit le terrain : des cases à portée pour `PER_CELL`, les cases du filon
## entier pour `VEIN`. Ce fichier ne décide que du **barème**, et un seul mode l'infléchit —
## `FLAT` paie une fois ou pas du tout, quoi qu'on lui présente.
##
## Rien ne borne le produit. **Une première version le plafonnait**, et le plafond a été retiré
## le jour même : il se défendait tant que l'adjacence était un supplément posé sur un rendement
## de base, il fait l'inverse de ce qu'on veut comme source unique. Au plafond, une case à deux
## arbres et une case à dix rendent la même chose, donc le choix de la case cesse de compter —
## dans un jeu dont le placement est l'essence. `FLAT` n'est pas ce plafond revenu : il ne
## borne pas un barème, il en exprime un autre, sur une règle qui **ne veut pas** compter.
func award(units: int) -> int:
	assert(units >= 0, "compte d'unités négatif : %d" % units)
	if mode == Mode.FLAT:
		return amount if units > 0 else 0
	return units * amount

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
	if mode == Mode.UNSET:
		missing.append("mode")
	if amount < 1:
		missing.append("amount")
	return missing
