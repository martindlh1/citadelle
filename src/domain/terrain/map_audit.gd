class_name MapAudit
extends RefCounted
## Ce qui regarde une carte et dit ce qu'elle vaut, en marchant dessus.
##
## Fonction pure sur un TerrainQuery. Elle ne génère rien, ne corrige rien, et surtout **ne
## sait rien de la façon dont la carte a été faite** : elle cherche où le village peut
## s'installer, retrouve le replat par un parcours, compte les accès en marchant depuis la
## lisière, et mesure la place à bâtir en essayant d'y poser une empreinte. C'est la condition
## pour qu'elle **vérifie** au lieu de répéter.
##
## `CLAUDE.md` le dit d'une table et ça vaut d'un contrôle : deux chiffres qui viennent du
## même compteur ne prouvent rien en se ressemblant. Un audit à qui la génération dirait « j'ai
## creusé trois rampes » rendrait trois accès sur une carte dont deux rampes se touchent, ou
## dont une est bouchée par un rocher. Il n'en reçoit donc que la carte, et une cellule de
## départ.
##
## ---
##
## **Elle sert deux fois, et c'est ce qui la justifie comme classe.** La génération l'appelle
## pour accepter ou **rejeter** un seed *(DESIGN.md 3.1)* ; le harnais l'appelle sur deux
## cents seeds pour en imprimer la distribution. Les deux lisent le même rapport, ce qui est
## la seule façon d'être sûr que la table décrit les cartes qu'on joue vraiment.
##
## **Ce qu'elle ne fait pas : juger.** Les seuils sont de l'équilibrage et vivent dans
## `data/balance/` ; shortcomings() les confronte au rapport et nomme ce qui manque, comme un
## `missing_fields()` de Resource.

## Côté d'une empreinte carrée qui doit tenir pour qu'une case compte comme bâtissable.
##
## Deux, parce que c'est la plus grande empreinte de `DESIGN.md` 4.1 — la ferme. Compter les
## cellules plates une par une aurait rendu un chiffre flatteur et faux : une cellule plate
## isolée entre trois pentes ne reçoit **aucun** bâtiment du jeu, et la garantie de 3.1 porte
## sur ce qui fait démarrer la boucle économique, pas sur de la surface.
const PAD_SIDE := 2

## Tags qui font d'une cellule un gisement.
##
## Un seul aujourd'hui : `DESIGN.md` 3.1 décrit un Gisement (`stone`) et un Filon (`ore`), et
## le second n'existe pas encore en data — il arrivera avec l'adjacence de `C3`, qui est le
## premier système à lire un tag de terrain. Ce jour-là c'est un mot de plus dans ce tableau.
const DEPOSIT_TAGS: Array[StringName] = [&"stone"]

## Les quatre voisins d'une cellule. L'ordre est fixe : tout ce qui parcourt la grille en
## dépend pour rendre le même résultat d'un lancement à l'autre.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, 1)]

## Case rendue quand la carte n'offre aucun site du tout. Hors grille, donc jamais confondue.
const NOWHERE := Vector2i(-1, -1)

## Ce que cette carte vaut pour un village qui s'installe au plus près de `centre`, et pour un
## marcheur qui enjambe `climb` crans.
##
## **Le site est cherché, pas reçu**, et c'est le tour qu'a pris `T4` après avoir retiré la
## mesa. Un relief bruité n'a aucune raison d'offrir une place à bâtir au milieu exact de la
## carte : sur des crêtes, le centre géométrique est le plus souvent un **pic**, donc un replat
## d'une seule case. Auditer là revenait à noter la carte sur un pixel, et rejetait des cartes
## superbes dont le premier replat était trois cases plus loin.
##
## La règle est donc celle qu'un joueur devinerait en regardant la carte : **on fonde où le
## terrain le permet, au plus près du centre.** `centre` reste le point de repère — il dit
## vers quoi le village tend —, `need` dit ce qu'un replat doit offrir pour mériter qu'on s'y
## installe, et ce qui en sort est un **résultat** que le rapport porte.
##
## Une carte où rien n'atteint `need` n'est pas pour autant sans rapport : on s'installe alors
## sur le plus grand replat qu'il y ait, et `plateau()` dit de combien on manque. Un audit qui
## rendrait `null` là obligerait l'appelant à distinguer deux cas au lieu de lire un chiffre.
static func inspect(query: TerrainQuery, centre: Vector2i, climb: int,
		need: int) -> MapReport:
	assert(query != null, "audit sans carte")
	assert(climb >= 0, "hauteur d'enjambée négative : %d" % climb)
	assert(query.in_bounds(centre), "centre hors carte : %s" % centre)
	assert(need >= 1, "un site sans place à bâtir : %d" % need)

	var site := _site(query, centre, need)
	var shelf := _shelf_at(query, site)
	var buildable := 0
	var deposits := 0
	for cell in shelf:
		if not query.is_buildable(cell):
			continue
		buildable += 1
		if _is_deposit(query, cell):
			deposits += 1
	var drift := maxi(absi(site.x - centre.x), absi(site.y - centre.y))
	return MapReport.create(site, drift, shelf.size(), buildable,
		_entries(query, shelf, climb), _pads(query), deposits,
		_edge_distance(query, shelf, climb))

## Ce qui manque à cette carte pour être jouable. Vide = carte acceptable.
##
## Même forme qu'un `missing_fields()` de Resource, et pour la même raison : nommer ce qui
## cloche vaut mieux qu'un booléen, parce que **c'est le nom qui sert**. Une génération qui
## rejette neuf seeds sur dix sans dire pourquoi est un réglage qu'on ne peut pas corriger ;
## la même qui dit « deposits, deposits, deposits » désigne le chiffre à tourner.
static func shortcomings(report: MapReport, params: TerrainGenBalance) -> PackedStringArray:
	assert(report != null, "verdict sans rapport")
	assert(params != null, "verdict sans réglages")
	var missing := PackedStringArray()
	# `inspect()` a cherché un replat de `min_plateau_cells` cases, donc cette ligne ne peut
	# refuser que les cartes où il n'en existe **nulle part** — c'est-à-dire un relief si
	# hachuré qu'aucun village n'y tiendrait, où que ce soit. Elle n'est pas tautologique pour
	# autant, et c'est le genre de doublon apparent que `CLAUDE.md` demande de justifier : les
	# deux chiffres ne viennent pas du même compteur, l'un est une consigne de recherche et
	# l'autre ce que la recherche a trouvé.
	if report.plateau() < params.min_plateau_cells:
		missing.append("plateau")
	if report.drift() > params.max_site_drift:
		missing.append("site_drift")
	if report.accesses() < params.min_accesses:
		missing.append("accesses_too_few")
	if report.accesses() > params.max_accesses:
		missing.append("accesses_too_many")
	if report.pads() < params.min_build_pads:
		missing.append("pads")
	if report.deposits() < params.min_plateau_deposits:
		missing.append("deposits")
	# Rien sur `is_reachable()`, et c'est délibéré : un accès **est** un chemin depuis la
	# lisière, donc `min_accesses >= 1` — que missing_fields() impose — le garantit déjà.
	# Une ligne de plus n'aurait jamais rien refusé, et `N1` a écrit qu'un contrôle qui n'a
	# jamais refusé quoi que ce soit ne prouve pas qu'il refuserait. Le chiffre reste au
	# rapport, où il **mesure** au lieu de juger.
	return missing

# --- le site ----------------------------------------------------------------

## Où le village s'installe : la case bâtissable la plus proche du centre dont le replat
## offre `need` cases à bâtir.
##
## **Le repli compte autant que la règle.** Quand aucun replat n'atteint `need`, on s'installe
## sur le plus grand qu'il y ait plutôt que de rendre « rien » : l'appelant lit alors un
## `plateau()` trop court et rejette le seed, ce qui est exactement ce qu'on veut qu'il fasse.
## Rendre une case hors carte l'aurait obligé à traiter un second cas pour arriver à la même
## conclusion.
static func _site(query: TerrainQuery, centre: Vector2i, need: int) -> Vector2i:
	var room := _room_per_cell(query)
	var found := _closest(query, centre, room, need)
	if found != NOWHERE:
		return found
	var largest := 0
	for cell in room:
		largest = maxi(largest, room[cell])
	if largest < 1:
		return centre
	return _closest(query, centre, room, largest)

## Combien de cases à bâtir offre le replat de chaque cellule.
##
## Chaque replat n'est parcouru qu'une fois et son compte est recopié sur tous ses membres :
## demander la question cellule par cellule aurait refait mille parcours par carte, et l'audit
## tourne deux cents fois par revue. C'est la leçon du tableau alloué dans une boucle de
## grille, une case plus loin.
static func _room_per_cell(query: TerrainQuery) -> Dictionary[Vector2i, int]:
	var extent := query.size()
	var room: Dictionary[Vector2i, int] = {}
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if room.has(cell):
				continue
			var shelf := _shelf_at(query, cell)
			var buildable := 0
			for member in shelf:
				if query.is_buildable(member):
					buildable += 1
			for member in shelf:
				room[member] = buildable
	return room

## La case bâtissable la plus proche du centre dont le replat offre `need` places, ou NOWHERE.
##
## La distance est prise au carré et sans racine — comparer suffit —, et les égalités se
## départagent par l'ordre de balayage. Deux lancements doivent fonder le même village.
static func _closest(query: TerrainQuery, centre: Vector2i,
		room: Dictionary[Vector2i, int], need: int) -> Vector2i:
	var extent := query.size()
	var best := NOWHERE
	var best_reach := 0
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if room[cell] < need or not query.is_buildable(cell):
				continue
			var reach := (cell - centre).length_squared()
			if best == NOWHERE or reach < best_reach:
				best = cell
				best_reach = reach
	return best

# --- le plateau -------------------------------------------------------------

## Le replat qui porte cette cellule : tout ce qui est à sa hauteur et s'y rattache de proche
## en proche.
##
## Le rattachement se fait **par la hauteur seule** et non par la constructibilité. Un rocher
## posé au milieu du plateau n'en coupe pas la surface en deux — on le contourne, et il ne
## retire qu'une case à bâtir. Compter deux moitiés là où le joueur voit un plateau aurait
## rejeté des cartes correctes pour un caillou.
static func _shelf_at(query: TerrainQuery, centre: Vector2i) -> Array[Vector2i]:
	var level := query.height_at(centre)
	var seen: Dictionary[Vector2i, bool] = { centre: true }
	var shelf: Array[Vector2i] = [centre]
	var queue: Array[Vector2i] = [centre]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in NEIGHBOURS:
			var side := cell + step
			if seen.has(side) or not query.in_bounds(side):
				continue
			if query.height_at(side) != level:
				continue
			seen[side] = true
			shelf.append(side)
			queue.append(side)
	return shelf

## Cette cellule porte-t-elle un gisement ?
static func _is_deposit(query: TerrainQuery, cell: Vector2i) -> bool:
	for tag in DEPOSIT_TAGS:
		if query.has_tag(cell, tag):
			return true
	return false

# --- les accès --------------------------------------------------------------

## Une cellule d'entrée par accès distinct, dans l'ordre de balayage.
##
## Un accès est une **façon d'entrer**, pas une case : on marche depuis la lisière de la
## carte sans jamais poser le pied sur le replat, on relève toutes les cellules du replat
## qu'on pourrait enjamber depuis là, et on regroupe celles qui se touchent.
##
## **Le regroupement se fait en huit voisins**, là où la marche s'en tient à quatre. Deux
## cases d'entrée qui se touchent, même par un coin, sont le même col : une tour posée là les
## couvre toutes les deux, et c'est ce que le mot « accès » veut dire pour un joueur. Les
## compter séparément aurait fait passer une rampe de deux cases pour deux passages.
static func _entries(query: TerrainQuery, shelf: Array[Vector2i],
		climb: int) -> Array[Vector2i]:
	var on_shelf: Dictionary[Vector2i, bool] = {}
	for cell in shelf:
		on_shelf[cell] = true
	var outside := _outside(query, on_shelf, climb)

	var gateways: Dictionary[Vector2i, bool] = {}
	for cell in outside:
		for step in NEIGHBOURS:
			var side := cell + step
			if on_shelf.has(side) and query.can_step(cell, side, climb):
				gateways[side] = true
	return _grouped(query, gateways)

## Ce qu'un marcheur venu de la lisière atteint **sans monter sur le replat**.
##
## Le replat est exclu du parcours et non pas simplement ignoré à l'arrivée : sans ça, un
## marcheur entré par un col ressortirait par un autre et l'on compterait des accès depuis
## l'intérieur. Ce qu'on veut est ce que le dehors touche.
static func _outside(query: TerrainQuery, on_shelf: Dictionary[Vector2i, bool],
		climb: int) -> Array[Vector2i]:
	var extent := query.size()
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for cell in _border(extent):
		if on_shelf.has(cell) or seen.has(cell) or not query.is_walkable(cell):
			continue
		seen[cell] = true
		queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in NEIGHBOURS:
			var side := cell + step
			if seen.has(side) or on_shelf.has(side):
				continue
			if not query.can_step(cell, side, climb):
				continue
			seen[side] = true
			queue.append(side)
	return queue

## Un représentant par groupe de cellules qui se touchent, coins compris.
static func _grouped(query: TerrainQuery,
		gateways: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var extent := query.size()
	var taken: Dictionary[Vector2i, bool] = {}
	var leaders: Array[Vector2i] = []
	# Balayage en y puis en x : le représentant d'un groupe est sa cellule la plus haute
	# puis la plus à gauche, donc le même d'un lancement à l'autre.
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if not gateways.has(cell) or taken.has(cell):
				continue
			leaders.append(cell)
			taken[cell] = true
			var queue: Array[Vector2i] = [cell]
			var head := 0
			while head < queue.size():
				var here := queue[head]
				head += 1
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var side: Vector2i = here + Vector2i(dx, dy)
						if not gateways.has(side) or taken.has(side):
							continue
						taken[side] = true
						queue.append(side)
	return leaders

## Les cellules du pourtour de la carte, sans doublon aux quatre coins.
static func _border(extent: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in extent.x:
		cells.append(Vector2i(x, 0))
		if extent.y > 1:
			cells.append(Vector2i(x, extent.y - 1))
	for y in range(1, maxi(extent.y - 1, 1)):
		cells.append(Vector2i(0, y))
		if extent.x > 1:
			cells.append(Vector2i(extent.x - 1, y))
	return cells

# --- la place à bâtir et la distance ----------------------------------------

## Emplacements où une empreinte carrée de PAD_SIDE tient : plate et bâtissable de bout en
## bout. Compte les **ancres**, donc deux emplacements qui se chevauchent comptent deux fois.
static func _pads(query: TerrainQuery) -> int:
	var extent := query.size()
	var count := 0
	for y in extent.y:
		for x in extent.x:
			var area := Rect2i(Vector2i(x, y), Vector2i(PAD_SIDE, PAD_SIDE))
			if query.is_area_buildable(area) and query.is_area_flat(area):
				count += 1
	return count

## Pas qui séparent la lisière du plateau, ou -1 si aucun chemin n'y mène.
##
## Un parcours en largeur, donc **le nombre de cases** et non un coût. Le chemin d'une vague
## sera plus cher que celui-ci — `V1` fera payer la montée —, et c'est écrit ici pour qu'une
## table qui imprime ce chiffre ne se lise pas comme une prédiction de bataille. Ce qu'il dit
## est la **profondeur** de la carte : combien de cases séparent le bord du village, donc
## combien de terrain une défense a devant elle.
##
## **Jusqu'au plateau et non jusqu'au centre**, et l'écart n'est pas cosmétique : un rocher
## tombé sur la case du milieu la rend infranchissable, et une distance mesurée là aurait
## rendu -1 sur une carte parfaitement jouable dont le Cœur se poserait une case à côté. Ce
## qu'on veut savoir est où le village commence, pas ce que porte une cellule.
static func _edge_distance(query: TerrainQuery, shelf: Array[Vector2i], climb: int) -> int:
	var on_shelf: Dictionary[Vector2i, bool] = {}
	for cell in shelf:
		on_shelf[cell] = true
	var extent := query.size()
	var depth: Dictionary[Vector2i, int] = {}
	var queue: Array[Vector2i] = []
	for cell in _border(extent):
		if depth.has(cell) or not query.is_walkable(cell):
			continue
		depth[cell] = 0
		queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if on_shelf.has(cell):
			return depth[cell]
		for step in NEIGHBOURS:
			var side := cell + step
			if depth.has(side) or not query.can_step(cell, side, climb):
				continue
			depth[side] = depth[cell] + 1
			queue.append(side)
	return -1
