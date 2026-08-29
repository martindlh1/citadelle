class_name CombatMovement
extends RefCounted
## Où un corps peut aller, et ce que le relief lui coûte pour y aller.
##
## Fonctions pures, aucun état, aucun `Node` — le profil de `CellPicker`, et pour la même
## raison : c'est la brique que le plateau, l'IA de `F2b` et l'écran de `F3` emploieront
## tous les trois, et trois copies d'une règle de portée finissent par montrer autre chose
## que ce qu'elles font.
##
## **Elle ne connaît pas la ville.** Les bâtiments arrivent ici fondus dans un ensemble de
## cases barrées, avec les corps, exactement comme le relief arrive par un `TerrainQuery`
## et non par une `HeightGrid`. Un mur, un chantier et un pillard bloquent de la même
## façon ; leur faire trois chemins de code n'apprendrait rien et donnerait trois occasions
## de diverger. C'est aussi ce qui rend ce fichier testable sans fabriquer une ville.
##
## **Le déplacement est orthogonal**, et la portée de `CombatStats.can_reach()` est en
## Manhattan pour rester d'accord avec lui. Mélanger deux métriques sur la même grille
## produit des distances qu'on ne peut pas lire à l'œil : une case atteignable en trois pas
## qui serait « à portée 2 » ferait mentir toute case allumée à l'écran.
##
## `DESIGN.md` 3.6 : « Le relief joue, et c'est la première chose qui l'emploie autrement
## que comme contrainte de pose. Monter coûte, une marche trop haute bloque. »

## Coût rendu par une marche infranchissable.
##
## Un entier négatif plutôt qu'un très grand nombre : un plafond déguisé en coût finirait
## par être franchi le jour où un corps aurait beaucoup de points, ce qui est le genre de
## limite qui cède en silence.
const BLOCKED := -1

## Voisinage orthogonal, dans un ordre figé.
##
## L'ordre compte pour le **déterminisme** et pour rien d'autre : deux runs partis du même
## seed doivent explorer les cases dans la même suite, sans quoi deux chemins de coût égal
## se départageraient différemment d'une partie à l'autre. C'est le même souci qui interdit
## de trier des `StringName` par `sort()`.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1),
]

## Un corps peut-il se tenir sur cette case ?
##
## Trois refus, dans l'ordre du moins cher au plus cher : hors carte, déjà occupée, terrain
## que rien ne traverse. Les tags viennent de `data/balance/` et ne sont écrits nulle part
## ici — le domaine écrirait sinon `&"water"`, qui est le nombre magique que les
## conventions refusent.
static func is_open(terrain: TerrainQuery, obstacles: Dictionary[Vector2i, bool],
		cell: Vector2i, balance: CombatBalance) -> bool:
	assert(terrain != null, "case testée sans relief")
	assert(balance != null, "case testée sans équilibrage")
	if not terrain.in_bounds(cell):
		return false
	if obstacles.has(cell):
		return false
	for tag in balance.impassable_tags:
		if terrain.has_tag(cell, tag):
			return false
	return true

## Ce qu'un pas d'une case à l'autre coûte à ce corps, ou `BLOCKED`.
##
## **Monter coûte, descendre non.** L'asymétrie est délibérée : elle fait d'une hauteur une
## position qu'on **tient** — longue à gagner, facile à quitter — plutôt qu'un mur qui
## enferme aussi celui qui est dessus. Un défenseur peut donc sauter d'un plateau pour
## rompre le contact, et l'assaillant devra remonter. C'est un chiffre à surveiller à `I3`,
## et c'est écrit ici parce que ça se discute.
##
## La marche trop haute, elle, bloque des **deux** côtés du calcul, puisqu'elle se lit sur
## le dénivelé du pas et non sur la hauteur absolue.
##
## Précondition : les deux cases sont dans la grille. Le tri des cases hors carte appartient
## à `is_open()`, qui est appelée avant.
static func step_cost(terrain: TerrainQuery, from: Vector2i, to: Vector2i,
		stats: CombatStats, balance: CombatBalance) -> int:
	assert(stats != null, "pas mesuré sans profil")
	var rise := terrain.height_at(to) - terrain.height_at(from)
	if rise > stats.climb():
		return BLOCKED
	return 1 + maxi(0, rise) * balance.climb_cost

## Toutes les cases que ce corps peut atteindre, et ce que chacune lui coûte.
##
## La case de départ y figure à zéro, et c'est une réponse plutôt qu'un artefact : « rester
## sur place » est un déplacement légal, et l'écran qui allume les cases atteignables doit
## pouvoir montrer celle qu'on quitte.
##
## Un Dijkstra et non un parcours en largeur, parce que les pas n'ont pas tous le même prix
## dès que `climb_cost` n'est pas nul. Sans file de priorité : les grilles du jeu font
## 32×32 et un corps parcourt une poignée de cases, donc chercher la moins chère à chaque
## tour coûte moins que d'entretenir un tas. Le jour où ça ne serait plus vrai, c'est ici
## que le tas s'installerait, et nulle part ailleurs.
##
## L'ordre d'insertion d'un `Dictionary` est stable en GDScript, ce dont le départage entre
## deux cases de coût égal dépend. Deux runs du même seed explorent donc la même carte dans
## le même ordre.
static func reachable(terrain: TerrainQuery, obstacles: Dictionary[Vector2i, bool],
		from: Vector2i, stats: CombatStats,
		balance: CombatBalance) -> Dictionary[Vector2i, int]:
	assert(terrain != null, "portée de déplacement sans relief")
	assert(stats != null, "portée de déplacement sans profil")
	assert(balance != null, "portée de déplacement sans équilibrage")
	assert(terrain.in_bounds(from), "corps hors carte en %s" % from)
	var best: Dictionary[Vector2i, int] = {}
	var settled: Dictionary[Vector2i, bool] = {}
	best[from] = 0
	while settled.size() < best.size():
		var cell := _cheapest_unsettled(best, settled)
		settled[cell] = true
		var spent: int = best[cell]
		for step in NEIGHBOURS:
			var next: Vector2i = cell + step
			if not is_open(terrain, obstacles, next, balance):
				continue
			var price := step_cost(terrain, cell, next, stats, balance)
			if price == BLOCKED:
				continue
			var total := spent + price
			if total > stats.move():
				continue
			if best.has(next) and best[next] <= total:
				continue
			best[next] = total
	return best

## La case non encore traitée la moins chère.
##
## Aucune sentinelle et aucun cas « rien à rendre » : l'appelante ne l'interroge que tant
## qu'il reste des cases à traiter, ce que sa condition de boucle dit en toutes lettres.
## Une sentinelle aurait été un `Vector2i` qui ressemble à une cellule, donc un piège.
##
## Le `>=` départage en faveur de la **première insérée**, ce qui est ce qui rend
## l'exploration reproductible.
static func _cheapest_unsettled(best: Dictionary[Vector2i, int],
		settled: Dictionary[Vector2i, bool]) -> Vector2i:
	var pick := Vector2i.ZERO
	var found := false
	for candidate in best:
		if settled.has(candidate):
			continue
		if found and best[candidate] >= best[pick]:
			continue
		pick = candidate
		found = true
	assert(found, "aucune case à traiter, la boucle appelante aurait dû s'arrêter")
	return pick
