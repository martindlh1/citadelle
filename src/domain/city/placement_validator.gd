class_name PlacementValidator
extends RefCounted
## Peut-on poser ce bâtiment ici ? Fonction pure, aucune mutation.
##
## Elle ne regarde que le relief et ce qui est déjà bâti. Ne rien muter est ce qui
## compte le plus ici : le fantôme de C2 l'appellera à chaque image sous le curseur,
## sans rien engager. CityState.place() la rappelle avant de poser plutôt que de faire
## confiance à un appelant qui aurait déjà demandé.
##
## Le coût n'entre pas dans le placement. « Ai-je les 15 bois ? » ne regarde pas la
## carte, le contrat de DESIGN.md 3.2 ne reçoit aucune bourse, et c'est la couche qui
## orchestre la journée qui enchaîne les deux questions. REASON_INSUFFICIENT_RESOURCES
## rejoindra PlacementResult ce jour-là, sans que rien d'ici ne bouge.
##
## **L'emprise du village est entrée à C7**, et c'est la seule des six règles qui ne regarde ni
## le terrain ni la case elle-même : elle demande où en est le village. Toute l'empreinte doit y
## être et pas seulement l'ancre — une ferme à cheval sur la frontière serait un bâtiment à
## moitié dehors, et « chaque cellule répond » est déjà la forme des quatre premières.
##
## Le calcul est chez `Territory`, qui le partage avec le contour dessiné à l'écran. Deux
## arithmétiques de distance auraient fini par dessiner une bordure dans laquelle le clic
## refuse, et ce désaccord-là ne se signale par rien.
##
## **Un prérequis d'adjacence, en revanche, est entré à C3.** Ce docstring disait le contraire :
## « requiert un gisement voisin » avait été écarté du placement, l'adjacence restant la couche
## de rendement. La décision était juste tant que les deux couches étaient distinctes — depuis
## que le voisinage est la **seule** source de production, elles n'en font plus qu'une, et un
## bâtiment sans voisin n'est pas un bâtiment qui rend peu : c'est un bâtiment qui ne rend rien.
##
## Il reste conforme au premier paragraphe : la question se pose au **terrain**, pas à une
## bourse. Elle passe par `TerrainQuery.tagged_within()`, le même balayage dont l'Économie tire
## le rendement — un second comptage écrit ici aurait pu accepter une case dont la récolte, un
## tour plus tard, ne verserait rien.

## Peut-on poser ce bâtiment sur cette ancre ?
##
## Une passe par règle plutôt qu'une seule boucle qui testerait tout d'un
## coup, et c'est délibéré : en une passe, une empreinte dont une cellule est occupée
## et une autre sous l'eau rendrait la raison de celle qui vient en premier dans le
## .tres. La raison dépendrait donc de l'ordre d'écriture de la data. En quatre
## passes, elle ne dépend que de l'ordre des règles, qui est fixe et documenté
## ci-dessous. Une empreinte fait quelques cellules : le surcoût n'existe pas.
##
## L'ordre des règles n'est pas non plus arbitraire. Les bornes d'abord, parce que
## height_at() exige une cellule dans la grille et lèverait sur une empreinte qui
## déborde — c'est une précondition du contrat Terrain, pas une préférence. Puis du
## plus local — cette cellule-ci accepte-t-elle un bâtiment — au plus global : la
## planéité est la seule règle qui doive avoir vu toute l'empreinte pour conclure.
## `turns` oriente l'empreinte par quarts de tour. Les règles, elles, ne changent pas
## d'un iota : elles reçoivent une liste de cellules et ne savent pas d'où elle vient.
## C'est tout l'intérêt d'avoir fait pivoter l'empreinte autour de son ancre.
static func validate(city: CityState, terrain: TerrainQuery,
		data: BuildingData, anchor: Vector2i, turns: int = 0) -> PlacementResult:
	assert(city != null, "placement sans ville")
	assert(terrain != null, "placement sans terrain")
	assert(data != null, "placement sans données de bâtiment")
	assert(not data.footprint.is_empty(),
		"placement d'un bâtiment sans empreinte : %s" % data.id)
	var cells := data.cells_at(anchor, turns)
	# is_buildable() répondrait déjà false hors grille, mais confondre les deux cas
	# rendrait « c'est de la roche » là où il faut lire « c'est hors de la carte ».
	for cell in cells:
		if not terrain.in_bounds(cell):
			return PlacementResult.refused(PlacementResult.REASON_OUT_OF_BOUNDS)
	for cell in cells:
		if not terrain.is_buildable(cell):
			return PlacementResult.refused(PlacementResult.REASON_NOT_BUILDABLE)
	for cell in cells:
		if city.is_occupied(cell):
			return PlacementResult.refused(PlacementResult.REASON_OCCUPIED)
	var height := terrain.height_at(cells[0])
	for cell in cells:
		if terrain.height_at(cell) != height:
			return PlacementResult.refused(PlacementResult.REASON_UNEVEN_GROUND)
	# Les quatre règles au-dessus disent que la case est **utilisable** ; les deux qui suivent
	# disent qu'on y a **droit**, puis qu'elle est **utile**. L'ordre entre elles n'est pas
	# indifférent non plus : « il n'y a pas d'arbre ici » n'intéresse personne sur une case hors
	# du village, et « c'est trop loin » n'intéresse personne sur une case sous l'eau.
	for cell in cells:
		if not Territory.reaches(city, cell):
			return PlacementResult.refused(PlacementResult.REASON_OUT_OF_REACH)
	if not _has_a_neighbour(terrain, data, cells):
		return PlacementResult.refused(PlacementResult.REASON_NO_NEIGHBOUR)
	return PlacementResult.accepted(cells, height)

## Au moins une règle de ce bâtiment trouve-t-elle une case ? Vrai s'il n'en porte aucune.
##
## « Au moins une » et non « toutes » : un bâtiment à deux règles a deux façons de mériter sa
## place, et en exiger deux ferait d'une carte généreuse la seule carte jouable. C'est aussi
## exactement la condition qui garantit que tout bâtiment posable **rend quelque chose**,
## puisqu'une règle qui trouve une case verse au moins son `per_cell`, lequel vaut au minimum 1.
static func _has_a_neighbour(terrain: TerrainQuery, data: BuildingData,
		cells: Array[Vector2i]) -> bool:
	if data.adjacency.is_empty():
		return true
	for rule in data.adjacency:
		if not terrain.tagged_within(cells, rule.tag, rule.radius).is_empty():
			return true
	return false
