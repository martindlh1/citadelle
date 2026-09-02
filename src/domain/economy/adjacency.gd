class_name Adjacency
extends RefCounted
## Ce que le terrain autour d'un bâtiment lui rapporte.
##
## Fonction pure sur un TerrainQuery et une BuildingData. Elle ne mute rien, ne lit ni
## GameDatabase ni le moindre Node, et ne sait pas si le bâtiment qu'on lui décrit est posé :
## elle reçoit une **ancre et une orientation**, pas un BuildingSnapshot.
##
## **C'est toute la raison d'être du fichier.** `DESIGN.md` 3.2 : « sans retour visuel en temps
## réel du delta, l'adjacence est invisible, donc inexistante ». Le delta doit donc se calculer
## sous un curseur, pour un bâtiment qui n'existe pas encore — et il doit être **le même
## chiffre** que celui que le tour versera. Deux calculs auraient divergé, et le premier à
## mentir aurait été celui qu'on regarde : la fiche promet, la récolte tombe, personne ne
## comprend. Un `BuildingSnapshot` en argument aurait rendu la prévisualisation impossible et
## forcé exactement ce doublon.
##
## Le résolveur de production l'appelle avec l'ancre et l'orientation d'un bâtiment posé ; la
## fiche de placement l'appelle avec celles du fantôme sous la souris. Une écriture, deux
## lectures.
##
## ---
##
## **L'empreinte compte parmi les cases cherchées.** Bâtir une carrière *sur* le gisement est
## le geste qu'un joueur essaie en premier, et le terrain n'est pas consommé par la pose — la
## forêt reste sous la cabane. Voir AdjacencyRule.radius.

## Zone examinée pour cette règle, et distance mesurée à l'empreinte réelle.
##
## `neighbourhood_at()` rend le rectangle **englobant** élargi du rayon, ce qui déborde sur une
## forme en L : son propre docstring dit depuis `C1` que le filtrage revient à l'appelant, et
## c'est ici qu'il se fait. La différence ne se voit sur aucun des quatre bâtiments qui portent
## une règle — tous rectangulaires —, et c'est précisément pourquoi il fallait l'écrire
## maintenant : un producteur en L ajouté plus tard aurait changé les chiffres en silence.
static func inspect(data: BuildingData, anchor: Vector2i, turns: int,
		terrain: TerrainQuery) -> AdjacencyReport:
	assert(data != null, "adjacence sans bâtiment")
	assert(terrain != null, "adjacence sans terrain")
	if data.adjacency.is_empty():
		return AdjacencyReport.none()

	var footprint := data.cells_at(anchor, turns)
	var counts := PackedInt32Array()
	counts.resize(data.adjacency.size())
	for index in data.adjacency.size():
		var rule := data.adjacency[index]
		counts[index] = _count(footprint, data.neighbourhood_at(anchor, rule.radius, turns),
			rule, terrain)
	return AdjacencyReport.create(data.adjacency, counts)

## Ce que ce voisinage rapporterait, sans le détail. Raccourci de `inspect().total()`.
##
## Il existe parce que le résolveur ne veut que ça et que `inspect(...).total()` à la ligne se
## lit mal ; il ne recalcule rien, ce qui est la seule forme de raccourci que ce projet
## accepte.
static func bonus(data: BuildingData, anchor: Vector2i, turns: int,
		terrain: TerrainQuery) -> Dictionary[StringName, int]:
	return inspect(data, anchor, turns, terrain).total()

## Cases taggées de cette zone qui sont à portée de l'empreinte.
##
## Le balayage est direct plutôt que par un tableau de cellules fabriqué à la volée : c'est la
## leçon de `is_area_buildable()` à `T4`, et elle vaut d'autant plus ici que la fiche de
## placement appelle cette fonction **à chaque image**, sous un curseur qui se promène.
static func _count(footprint: Array[Vector2i], area: Rect2i, rule: AdjacencyRule,
		terrain: TerrainQuery) -> int:
	var found := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not terrain.has_tag(cell, rule.tag):
				continue
			if _rings_to(footprint, cell) <= rule.radius:
				found += 1
	return found

## Anneaux qui séparent cette cellule de l'empreinte, mesurés à sa case la plus proche.
##
## Distance de Chebyshev, donc les diagonales comptent pour un : à rayon 1, la zone est la
## couronne qui entoure le bâtiment. C'est ce qu'on voit en regardant autour d'une cabane, et
## c'est la métrique que `MapAudit` emploie déjà pour dire que deux cols qui se touchent par un
## coin n'en font qu'un.
##
## Une cellule de l'empreinte est à zéro, donc toujours à portée.
static func _rings_to(footprint: Array[Vector2i], cell: Vector2i) -> int:
	var nearest := -1
	for occupied in footprint:
		var rings := maxi(absi(cell.x - occupied.x), absi(cell.y - occupied.y))
		if nearest < 0 or rings < nearest:
			nearest = rings
	return nearest
