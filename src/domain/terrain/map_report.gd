class_name MapReport
extends RefCounted
## Ce qu'une carte vaut, mesuré sur la carte elle-même : où le village s'installe, le replat
## qui le porte, ses accès, sa surface bâtissable, ses gisements, et la distance qui l'en
## sépare de la lisière.
##
## Immuable. Rendu par MapAudit.inspect().
##
## Il vit dans domain/terrain/ et non dans contracts/, par le critère habituel : aucun
## **second système du domaine** ne le franchit. La génération le produit et le consomme pour
## accepter ou rejeter un seed ; le harnais le lit pour en faire une table, et les adapters
## lisent le domaine, c'est leur métier. Le jour où les Vagues voudront connaître les cols
## avant de choisir par où entrer, il déménagera, et ce sera un déplacement de fichier.
##
## ---
##
## **Il constate, il ne décide pas**, comme UpkeepReport et ProductionReport. « Deux accès »
## est un fait ; « deux accès, c'est trop peu » est un seuil, donc de l'équilibrage, donc
## MapAudit.shortcomings() et data/balance/. La séparation compte plus ici qu'ailleurs : ce
## même rapport sert à **rejeter** un seed et à **décrire** une distribution de deux cents
## cartes, et la seconde lecture serait sans intérêt si les chiffres arrivaient déjà jugés.

## Là où le village s'installe : la case que l'audit a retenue pour fonder.
var _site: Vector2i = Vector2i.ZERO

## Cases qui la séparent du milieu de la carte, en anneaux.
var _drift: int = 0

## Cellules du replat qui porte ce site : tout ce qui est à sa hauteur et s'y rattache.
var _shelf: int = 0

## Celles de ce replat sur lesquelles on peut bâtir. Un rocher posé dessus fait l'écart.
var _plateau: int = 0

## Une cellule d'entrée par accès distinct, dans l'ordre de balayage.
##
## Ce sont des cellules **du plateau**, celles qu'un marcheur venu du dehors atteint en
## premier : c'est là qu'une tour sert à quelque chose, et c'est ce qu'une capture doit
## marquer pour qu'on voie de quoi parle le mot « col ».
var _entries: Array[Vector2i] = []

## Emplacements où une empreinte 2x2 tient, sur toute la carte.
var _pads: int = 0

## Cellules de gisement bâtissables sur le plateau.
var _deposits: int = 0

## Pas qui séparent la lisière de la carte du plateau, ou -1 s'il est injoignable.
var _edge_distance: int = -1

## Rapport brut. Réservé à MapAudit, qui est le seul à savoir le composer.
static func create(site: Vector2i, drift: int, shelf: int, plateau: int,
		entries: Array[Vector2i], pads: int, deposits: int,
		edge_distance: int) -> MapReport:
	assert(plateau <= shelf, "plus de cases bâtissables que de replat")
	assert(drift >= 0, "dérive négative : %d" % drift)
	var report := MapReport.new()
	report._site = site
	report._drift = drift
	report._shelf = shelf
	report._plateau = plateau
	report._entries = entries.duplicate()
	report._pads = pads
	report._deposits = deposits
	report._edge_distance = edge_distance
	return report

## Là où le village s'installe.
##
## **C'est un résultat et non une donnée**, et c'est ce qui distingue ce rapport de celui que
## `T4` rendait d'abord. Un relief bruité n'a aucune raison d'offrir une place à bâtir au
## milieu exact de la carte — sur des crêtes, le centre géométrique est souvent un **pic**. On
## a donc cessé de fonder au centre pour fonder **où le terrain le permet, au plus près du
## centre**, ce qui est aussi la seule des deux règles qu'un joueur puisse deviner en
## regardant la carte.
func site() -> Vector2i:
	return _site

## Cases qui séparent ce site du milieu de la carte, en anneaux.
##
## C'est le filtre qui a remplacé la garantie de plateau : une carte trouve presque toujours
## un replat quelque part, la question est **à quelle distance**. Un village qui s'installe
## à douze cases du milieu se retrouve adossé à la lisière, donc sans terrain devant lui.
func drift() -> int:
	return _drift

## Cellules du replat qui porte le site, bâtissables ou non.
func shelf() -> int:
	return _shelf

## Cellules bâtissables du plateau. C'est la garantie de DESIGN.md 3.1.
func plateau() -> int:
	return _plateau

## Nombre d'accès distincts au plateau.
func accesses() -> int:
	return _entries.size()

## Une cellule d'entrée par accès, dans l'ordre de balayage. Copie.
func entries() -> Array[Vector2i]:
	return _entries.duplicate()

## Emplacements où une empreinte 2x2 tient, sur toute la carte.
func pads() -> int:
	return _pads

## Gisements bâtissables sur le plateau.
func deposits() -> int:
	return _deposits

## Pas de la lisière au plateau. -1 si aucun chemin n'y mène.
func edge_distance() -> int:
	return _edge_distance

## Le plateau est-il joignable depuis la lisière ?
##
## Une carte dont il ne l'est pas est **invincible**, ce qui est pire qu'injouable : aucune
## vague n'atteint jamais le Cœur, donc le jeu n'a plus d'enjeu et rien ne le signale.
func is_reachable() -> bool:
	return _edge_distance >= 0
