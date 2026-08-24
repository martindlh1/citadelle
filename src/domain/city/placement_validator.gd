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
## Aucun prérequis d'adjacence non plus : « requiert un gisement voisin » a été écarté
## du placement, et l'adjacence reste entièrement la couche de rendement de C3.

## Peut-on poser ce bâtiment sur cette ancre ?
##
## Quatre passes sur l'empreinte plutôt qu'une seule boucle qui testerait tout d'un
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
static func validate(city: CityState, terrain: TerrainQuery,
		data: BuildingData, anchor: Vector2i) -> PlacementResult:
	assert(city != null, "placement sans ville")
	assert(terrain != null, "placement sans terrain")
	assert(data != null, "placement sans données de bâtiment")
	assert(not data.footprint.is_empty(),
		"placement d'un bâtiment sans empreinte : %s" % data.id)
	var cells := data.cells_at(anchor)
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
	return PlacementResult.accepted(cells, height)
