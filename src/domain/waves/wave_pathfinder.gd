class_name WavePathfinder
extends RefCounted
## Par où une vague passe pour atteindre le Cœur, et ce que ça lui coûte.
##
## Fonction pure sur un TerrainQuery et un CitySnapshot. Elle ne mute rien, ne connaît ni les
## `Node` ni l'Économie, et ne sait pas ce qu'une vague **est** : ce fichier trouve un chemin,
## `V2` y fera marcher des corps.
##
## ---
##
## **Casser ou contourner n'est pas une règle, c'est le résultat d'une comparaison.** Une case
## de bâtiment n'est pas un mur : c'est un passage **cher**, au prix de la patience de celui
## qui le franchit. La recherche
## compare donc « dix cases de détour » à « une case de mur » dans la même unité, et casse
## quand le mur revient moins cher. C'est le troc que `DESIGN.md` 3.5 demande — *je te barre, tu
## me manges le mur* — et il n'existe nulle part sous forme de seuil : le seuil **est** le prix.
##
## Un « si le détour dépasse N, casser » écrit à côté aurait été un second mécanisme à tenir
## d'accord avec le chemin, et il se serait trompé exactement là où deux détours se valent.
##
## **Ce qui barre pour de bon** — l'eau, le rocher, une marche trop haute — n'a pas de prix.
## `DESIGN.md` 3.5 les met dans la même phrase que les bâtiments, mais ils n'y jouent pas le
## même rôle : on ne creuse pas une falaise, alors qu'un mur est fait pour être troqué. Le
## relief est ce que le joueur **reçoit**, le bâti ce qu'il **pose** ; seul le second se paie.
##
## **Elle ignore ce qui ne la barre pas.** Une ferme à côté du chemin ne coûte rien et ne
## rapporte rien : la vague ne se détourne jamais pour manger. C'est ce qui fait du chemin toute
## l'histoire, et c'est ce qui crée l'arbitrage sur une tour.
##
## ---
##
## Un Dijkstra et non un A* : le coût d'une case dépend de ce qu'elle porte, donc une heuristique
## de distance à vol d'oiseau sous-estimerait grossièrement dès qu'un mur est en travers, et
## l'avance qu'elle achète sur une carte de mille cases ne se mesure pas. Ce qui compte ici est
## que le chemin soit **le moins cher**, sans quoi le troc du mur devient faux.
##
## Multi-sources : toute la lisière d'entrée est empilée au départ, ce qui rend en un seul
## parcours la meilleure façon d'entrer. Une recherche par case de bordure aurait rendu le même
## résultat pour trente fois le prix — et aurait demandé de comparer trente chemins à la main.

## Les quatre voisins d'une case, dans un ordre fixe.
##
## Quatre et non huit, comme partout où ce projet fait marcher quelqu'un : c'est la métrique de
## `MapAudit` depuis `T4`, et une diagonale qui se faufilerait entre deux coins de bâtiments
## rendrait le troc du mur contournable par une géométrie que personne ne voit.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, 1)]

## Le chemin le moins coûteux de l'une de ces entrées jusqu'au Cœur.
##
## `sources` est la lisière par laquelle la vague entre — `DESIGN.md` 3.5 veut une direction
## annoncée, et `WaveDef.entry_cells()` la traduit en cases ; ici on les reçoit et on trouve la
## meilleure.
##
## **Deux sources de chiffres, chacune ce qu'elle possède** : `balance` donne l'échelle — ce que
## vaut un pas, ce que vaut un cran —, `enemy` ce qui lui est propre — sa patience et son
## enjambée. Un chemin est donc celui de **cette créature-là** sur cette carte, et deux sortes
## d'assaillants n'empruntent pas forcément le même.
##
## Le Cœur est désigné par **une** de ses cases, et le chemin s'arrête à la première qu'il
## atteint : une empreinte de deux par deux n'a pas de « bonne » case d'arrivée, et exiger
## l'ancre ferait faire le tour du bâtiment à une vague qui l'a déjà touché.
static func find(terrain: TerrainQuery, city: CitySnapshot, heart: Vector2i,
		sources: Array[Vector2i], balance: WaveBalance, enemy: EnemyDef) -> WavePath:
	assert(terrain != null, "chemin sans terrain")
	assert(city != null, "chemin sans ville")
	assert(balance != null, "chemin sans équilibrage")
	assert(enemy != null, "chemin sans assaillant")
	assert(balance.missing_fields().is_empty(),
		"équilibrage de vague inexploitable : %s" % ", ".join(balance.missing_fields()))
	assert(enemy.missing_fields().is_empty(),
		"assaillant inexploitable : %s" % ", ".join(enemy.missing_fields()))

	var goal := city.at_cell(heart)
	# Les cases du Cœur et non la seule qu'on nous a donnée : la vague est arrivée dès qu'elle
	# en touche une. Un Cœur qui n'existe pas laisse la case nue faire l'affaire, ce qui rend ce
	# fichier utilisable sur une grille montée à la main sans y bâtir une ville.
	var arrival: Dictionary[Vector2i, bool] = {}
	if goal == null:
		arrival[heart] = true
	else:
		for cell in goal.cells():
			arrival[cell] = true

	var occupied := _occupied_by(city, arrival, enemy.patience)
	var best: Dictionary[Vector2i, int] = {}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var queue: Array[Vector2i] = []
	for cell in sources:
		if not _stands_on(terrain, cell) or best.has(cell):
			continue
		# Entrer coûte ce que la case porte : une lisière bâtie se perce comme le reste.
		best[cell] = occupied.get(cell, 0)
		queue.append(cell)

	while not queue.is_empty():
		var cell := _cheapest(queue, best)
		if arrival.has(cell):
			return _walk_back(cell, came_from, best[cell], occupied, city)
		queue.erase(cell)
		for step in NEIGHBOURS:
			var side: Vector2i = cell + step
			if not _can_walk(terrain, cell, side, enemy.climb):
				continue
			var price: int = best[cell] + _price_of(terrain, cell, side, occupied, balance)
			if best.has(side) and best[side] <= price:
				continue
			best[side] = price
			came_from[side] = cell
			if not queue.has(side):
				queue.append(side)
	return WavePath.nowhere()

## Ce que coûte le pas de `from` vers `to` : la distance, la montée, et le mur s'il y en a un.
##
## La descente est gratuite, la montée se paie au cran. C'est la lecture de `DESIGN.md` 3.5, et
## elle a une conséquence de jeu qu'on veut : un village haut perché est **naturellement** plus
## loin qu'il n'en a l'air, sans qu'aucune règle ne le dise.
static func _price_of(terrain: TerrainQuery, from: Vector2i, to: Vector2i,
		occupied: Dictionary[Vector2i, int], balance: WaveBalance) -> int:
	var rise := maxi(0, terrain.height_at(to) - terrain.height_at(from))
	return balance.step_cost + rise * balance.climb_cost + occupied.get(to, 0)

## Peut-on poser le pied de `from` sur `to` ?
##
## Le bâti n'entre pas ici : il ne barre pas, il coûte. Ce qui barre est le terrain seul — et
## c'est `TerrainQuery.can_step()` qui le dit, la même fonction dont `MapAudit` compte ses accès
## depuis `T4`. Deux définitions de « ça passe » auraient fini par diverger, et la carte aurait
## promis des cols qu'aucune vague n'emprunte.
static func _can_walk(terrain: TerrainQuery, from: Vector2i, to: Vector2i,
		climb: int) -> bool:
	return terrain.can_step(from, to, climb)

## La case est-elle un point de départ tenable ? Le bâti n'y change rien, le terrain seul décide.
static func _stands_on(terrain: TerrainQuery, cell: Vector2i) -> bool:
	return terrain.is_walkable(cell)

## Case -> ce qu'il en coûte d'y passer, pour toutes celles qu'un bâtiment occupe.
##
## Les cases du Cœur en sont **exclues** : c'est l'arrivée, pas un obstacle, et lui donner le
## prix d'un mur ferait préférer un détour à une vague qui est déjà au but.
static func _occupied_by(city: CitySnapshot, arrival: Dictionary[Vector2i, bool],
		breach: int) -> Dictionary[Vector2i, int]:
	var occupied: Dictionary[Vector2i, int] = {}
	for building in city.buildings():
		for cell in building.cells():
			if arrival.has(cell):
				continue
			occupied[cell] = breach
	return occupied

## Remonte la piste jusqu'au départ et compose le chemin.
##
## Les ancres percées se relèvent **ici** plutôt qu'en chemin, parce qu'on ne sait qu'à
## l'arrivée quelles cases ont été retenues : un Dijkstra visite bien plus de cases qu'il n'en
## garde, et compter les murs au passage aurait compté ceux des chemins abandonnés.
static func _walk_back(goal: Vector2i, came_from: Dictionary[Vector2i, Vector2i], cost: int,
		occupied: Dictionary[Vector2i, int], city: CitySnapshot) -> WavePath:
	var cells: Array[Vector2i] = [goal]
	var cell := goal
	while came_from.has(cell):
		cell = came_from[cell]
		cells.append(cell)
	cells.reverse()

	var breached: Array[Vector2i] = []
	for step in cells:
		if not occupied.has(step):
			continue
		var building := city.at_cell(step)
		if building == null or breached.has(building.anchor()):
			continue
		breached.append(building.anchor())
	return WavePath.create(cells, cost, breached)

## La case ouverte la moins chère.
##
## Un balayage linéaire plutôt qu'un tas : la file d'un Dijkstra sur une carte de mille cases
## reste courte, et un tas binaire écrit à la main serait cinquante lignes de plus à tester
## pour un gain qu'aucune mesure de ce projet ne réclame. Le jour où une carte fera dix mille
## cases, c'est ici qu'on regardera.
##
## À prix égal, la première case dans l'ordre d'insertion l'emporte : deux lancements doivent
## rendre le même chemin, sans quoi rien de ce qui en dépend n'est reproductible.
static func _cheapest(queue: Array[Vector2i], best: Dictionary[Vector2i, int]) -> Vector2i:
	var found := queue[0]
	for cell in queue:
		if best[cell] < best[found]:
			found = cell
	return found
