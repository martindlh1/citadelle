class_name WavePath
extends RefCounted
## Le chemin qu'une vague emprunte : les cases qu'elle traverse, ce qu'il lui coûte, et les
## bâtiments qu'elle mange en route.
##
## Immuable. Rendu par WavePathfinder.find().
##
## Il vit dans domain/waves/ et non dans contracts/, par le critère habituel : aucun **second
## système du domaine** ne le franchit. Les Vagues le produisent et le consommeront pour
## résoudre une bataille à `V2` ; les adapters le liront pour le dessiner, et lire le domaine
## est leur métier. Le premier rapport qui entrera dans `contracts/` est celui d'une bataille,
## à `V2` — celui-ci n'en est que la moitié.
##
## ---
##
## **Il constate, il ne décide pas.** « Ce chemin coûte 47 et perce deux cases de palissade »
## est un fait ; « cette défense est mal placée » est un jugement, et personne ici ne le porte.
## C'est la séparation qui permettra à `V2` de rejouer ce chemin et à un harnais d'en imprimer
## une table sans que les chiffres arrivent déjà interprétés.
##
## **Les cases sont dans l'ordre de la marche**, départ compris, Cœur compris. C'est ce qui
## permet de le dessiner, de le rejouer pas à pas, et de dire où la vague en est à un instant
## donné — tout ce que `V2` et `V3` demanderont.

## Les cases traversées, du départ au Cœur.
var _cells: Array[Vector2i] = []

## Ce que la traversée coûte, dans l'unité de WaveBalance.
var _cost: int = 0

## Les ancres des bâtiments que le chemin perce, dans l'ordre où il les rencontre.
var _breached: Array[Vector2i] = []

## Chemin trouvé. Réservé à WavePathfinder, qui est le seul à savoir le composer.
static func create(cells: Array[Vector2i], cost: int,
		breached: Array[Vector2i]) -> WavePath:
	assert(not cells.is_empty(), "chemin sans case : passer par nowhere()")
	assert(cost >= 0, "chemin de coût négatif : %d" % cost)
	var path := WavePath.new()
	path._cells = cells.duplicate()
	path._cost = cost
	path._breached = breached.duplicate()
	return path

## Le chemin d'une vague qui n'atteint pas le Cœur.
##
## **Un objet et non `null`**, pour la raison qui a fait rendre un rapport à `MapAudit` même sur
## une carte ratée : l'appelant lit alors un chemin vide au lieu de distinguer deux cas pour
## arriver à la même conclusion. Et il y a une conclusion à tirer — un Cœur qu'aucune vague
## n'atteint est un village **invincible**, ce qui est pire qu'injouable, parce que rien ne le
## signale.
static func nowhere() -> WavePath:
	return WavePath.new()

## Les cases traversées, du départ au Cœur. Copie.
func cells() -> Array[Vector2i]:
	return _cells.duplicate()

## Le nombre de cases, Cœur compris. 0 si le Cœur est injoignable.
func length() -> int:
	return _cells.size()

## Ce que la traversée coûte.
func cost() -> int:
	return _cost

## Les ancres des bâtiments percés, dans l'ordre de la marche, sans doublon. Copie.
##
## **Ce sont des ancres et non des cases**, parce que ce que `V2` en fera est de retirer des
## bâtiments : une empreinte de deux cases traversée en son milieu ne doit pas être mangée deux
## fois. La case percée, elle, se relit sur le chemin.
func breached() -> Array[Vector2i]:
	return _breached.duplicate()

## La vague atteint-elle le Cœur ?
func reaches() -> bool:
	return not _cells.is_empty()

## Le chemin passe-t-il par cette case ?
##
## Sert au premier consommateur qu'on lui connaisse : une tour ne vaut que si le chemin passe à
## sa portée, et `DESIGN.md` 3.5 en fait l'arbitrage central du jeu — « sur le chemin, elle
## barre et se bat, mais elle meurt ; à côté, elle survit, mais il lui faut de la portée ».
func passes_through(cell: Vector2i) -> bool:
	return _cells.has(cell)
