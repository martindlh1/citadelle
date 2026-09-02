@abstract
class_name TerrainQuery
extends RefCounted
## Face publique du système Terrain : la seule chose que les autres systèmes en voient.
##
## Construction et Combat interrogent le relief à travers ce contrat et n'accèdent
## jamais à la grille elle-même. La représentation interne peut donc changer — dense,
## creuse, découpée en chunks — sans qu'une ligne ne bouge ailleurs.
##
## Trois primitives seulement sont à implémenter : size(), height_at(), terrain_at().
## Tout le reste en découle et est fourni ici, pour que deux implémentations ne
## puissent pas diverger sur le sens de « constructible » ou de « plat ».
##
## Les conventions de bornes sont volontairement asymétriques :
##   - height_at() et terrain_at() exigent une cellule dans la grille. Les appeler
##     ailleurs est un bug de l'appelant, donc un assert.
##   - is_buildable() et les requêtes de zone rendent false hors grille. « Puis-je
##     bâtir ici ? » a une réponse pour une cellule hors carte, et Construction pose
##     couramment des empreintes qui débordent.

## Dimensions de la grille, en cellules : x en largeur, y en profondeur.
@abstract func size() -> Vector2i

## Hauteur de la cellule, en crans de relief. Précondition : in_bounds(cell).
@abstract func height_at(cell: Vector2i) -> int

## Terrain de la cellule, jamais null. Précondition : in_bounds(cell).
@abstract func terrain_at(cell: Vector2i) -> TerrainData

## La cellule tombe-t-elle dans la grille ?
func in_bounds(cell: Vector2i) -> bool:
	var extent := size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < extent.x and cell.y < extent.y

## Peut-on bâtir sur cette cellule ? False hors grille.
func is_buildable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return terrain_at(cell).is_buildable()

## Peut-on marcher sur cette cellule ? False hors grille.
##
## Même asymétrie de bornes que is_buildable(), et pour la même raison : « puis-je passer
## par là ? » a une réponse pour une cellule hors carte, et c'est non. Un parcours de grille
## interroge en permanence des voisins qui n'existent pas.
##
## **Elle ne dit rien du relief**, et c'est délibéré. Ce qui barre est de deux natures : la
## case — l'eau, le rocher — et la **marche**, qui dépend de qui grimpe. La première est une
## propriété du terrain, donc elle est ici ; la seconde appartient au marcheur, donc elle
## voyage avec lui — voir can_step(), qui reçoit sa hauteur d'enjambée en argument.
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return terrain_at(cell).is_walkable()

## Peut-on passer de cette cellule à celle-là, en enjambant au plus `climb` crans ?
##
## Les deux cellules doivent être dans la grille et franchissables. La **montée** est bornée
## par `climb` ; la **descente** ne l'est pas, ce qui est la règle de DESIGN.md 3.1 en une
## ligne : « monter coûte, une marche trop haute bloque, descendre ne coûte que le pas ».
##
## Elle ne vérifie **pas** que les deux cellules sont voisines : un appelant qui saute est un
## bug d'appelant, et l'assert le dit. C'est la même convention que CellPicker, qui suppose
## un rayon plutôt que de le valider.
##
## `climb` arrive en argument et non d'un champ de terrain parce que ce n'est pas le terrain
## qui grimpe. La génération de T4 l'emprunte à `data/balance/` pour se vérifier elle-même ;
## une vague de V1 l'aura de sa propre définition, et les deux poseront la même question.
func can_step(from: Vector2i, to: Vector2i, climb: int) -> bool:
	assert(climb >= 0, "hauteur d'enjambée négative : %d" % climb)
	assert((from - to).length_squared() == 1,
		"pas entre deux cellules non voisines : %s vers %s" % [from, to])
	if not is_walkable(from) or not is_walkable(to):
		return false
	return height_at(to) - height_at(from) <= climb

## Le terrain de cette cellule porte-t-il ce tag ? False hors grille.
func has_tag(cell: Vector2i, tag: StringName) -> bool:
	if not in_bounds(cell):
		return false
	return terrain_at(cell).has_tag(tag)

## Cases portant ce tag à `radius` anneaux ou moins de l'une de `cells`, `cells` comprises.
##
## **Elle est ici, sur le contrat, parce que deux systèmes du domaine la franchissent** : la
## Construction s'en sert pour refuser un bâtiment qui ne trouve aucun voisin, l'Économie pour
## calculer ce qu'il rend. C'est le critère nommé dans `CLAUDE.md` — un contrat s'écrit quand
## deux systèmes le traversent vraiment, jamais avant —, et il est rempli au mot près : sans
## elle, l'un des deux devrait dépendre des internes de l'autre, ou les deux compteraient
## séparément et finiraient par ne plus compter pareil.
##
## Ce serait la pire des divergences, parce qu'elle serait **muette** : le fantôme accepterait
## une case dont la récolte, un tour plus tard, ne verserait rien.
##
## En anneaux et non en pas, donc les diagonales comptent pour un : à rayon 1, la zone est la
## couronne qui entoure l'empreinte. C'est ce qu'on voit en regardant autour d'une cabane, et
## c'est la métrique que `MapAudit` emploie déjà pour dire que deux cols qui se touchent par un
## coin n'en font qu'un.
##
## Les cases de `cells` comptent, si elles portent le tag : bâtir une carrière **sur** le
## gisement est le geste qu'un joueur essaie en premier, et le terrain n'est pas consommé par
## la pose. Hors grille ne compte rien, ce qui est le cas normal d'un fantôme promené au bord.
##
## L'ordre du résultat est celui du balayage, donc identique d'un appel et d'un run à l'autre :
## le fantôme le dessine, et une liste qui changerait d'ordre ferait scintiller la carte.
func tagged_within(cells: Array[Vector2i], tag: StringName,
		radius: int) -> Array[Vector2i]:
	assert(radius >= 0, "rayon de voisinage négatif : %d" % radius)
	var found: Array[Vector2i] = []
	if cells.is_empty():
		return found
	var area := _spanning(cells).grow(radius)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not has_tag(cell, tag):
				continue
			if _rings_between(cells, cell) <= radius:
				found.append(cell)
	return found

## Rectangle englobant de ces cellules. Précondition : non vide.
##
## Il ne sert qu'à **borner le balayage** : sur une empreinte en L il couvre des cases que le
## bâtiment n'occupe pas, et c'est `_rings_between()` qui rattrape. Compter depuis l'enveloppe
## aurait donné le même chiffre sur les quatre bâtiments d'aujourd'hui — tous rectangulaires —
## et un chiffre faux, en silence, le jour d'un producteur en L.
func _spanning(cells: Array[Vector2i]) -> Rect2i:
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return Rect2i(low, high - low + Vector2i.ONE)

## Anneaux qui séparent cette cellule du plus proche membre de `cells`.
func _rings_between(cells: Array[Vector2i], cell: Vector2i) -> int:
	var nearest := -1
	for member in cells:
		var rings := maxi(absi(cell.x - member.x), absi(cell.y - member.y))
		if nearest < 0 or rings < nearest:
			nearest = rings
	return nearest

## Toutes les cellules de la zone sont-elles constructibles ?
## False si la zone déborde de la grille, ce qui est le cas d'une empreinte posée
## trop près d'un bord.
func is_area_buildable(area: Rect2i) -> bool:
	if not _encloses(area):
		return false
	# Balayage direct plutôt que par un tableau de cellules : l'audit de T4 pose cette
	# question mille fois par carte et deux cents fois par revue, et un tableau alloué à
	# chaque appel s'y comptait en dizaines de millions. La sémantique ne bouge pas d'un
	# pouce, et le helper qui les fabriquait n'avait plus d'appelant.
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not terrain_at(Vector2i(x, y)).is_buildable():
				return false
	return true

## Toutes les cellules de la zone sont-elles à la même hauteur ?
## False si la zone déborde de la grille, par cohérence avec is_area_buildable().
func is_area_flat(area: Rect2i) -> bool:
	if not _encloses(area):
		return false
	return height_span(area) == 0

## Dénivelé de la zone : hauteur la plus haute moins la plus basse, donc 0 sur un
## plateau. Précondition : la zone est non vide et entièrement dans la grille.
func height_span(area: Rect2i) -> int:
	assert(_encloses(area), "zone hors grille : %s dans %s" % [area, size()])
	var lowest := height_at(area.position)
	var highest := lowest
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var height := height_at(Vector2i(x, y))
			lowest = mini(lowest, height)
			highest = maxi(highest, height)
	return highest - lowest

## La zone est-elle non vide et entièrement contenue dans la grille ?
func _encloses(area: Rect2i) -> bool:
	if area.size.x <= 0 or area.size.y <= 0:
		return false
	return Rect2i(Vector2i.ZERO, size()).encloses(area)
