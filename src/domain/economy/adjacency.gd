class_name Adjacency
extends RefCounted
## Ce que le terrain autour d'un bâtiment lui rapporte — et c'est **tout** ce qu'il rapporte.
##
## Fonction pure sur un TerrainQuery et une BuildingData. Elle ne mute rien, ne lit ni
## GameDatabase ni le moindre Node, et ne sait pas si le bâtiment qu'on lui décrit est posé :
## elle reçoit une **ancre et une orientation**, pas un BuildingSnapshot.
##
## **C'est toute la raison d'être du fichier.** `DESIGN.md` 3.2 : « sans retour visuel en temps
## réel du delta, l'adjacence est invisible, donc inexistante ». Le delta doit donc se calculer
## sous un curseur, pour un bâtiment qui n'existe pas encore — et il doit être **le même
## chiffre** que celui que le tour versera. Deux calculs auraient divergé, et le premier à
## mentir aurait été celui qu'on regarde : le fantôme promet, la récolte tombe, personne ne
## comprend. Un `BuildingSnapshot` en argument aurait rendu la prévisualisation impossible et
## forcé exactement ce doublon.
##
## ---
##
## **Elle ne compte pas elle-même.** Le balayage est sur `TerrainQuery.tagged_within()`, parce
## que la Construction pose la même question au terrain pour refuser un bâtiment sans voisin —
## deux systèmes du domaine, donc un contrat. Ce qui reste ici est la seule chose qui soit
## vraiment de l'Économie : traduire des cases en ressources.

## Ce que le voisinage de cette pose rapporte, règle par règle.
static func inspect(data: BuildingData, anchor: Vector2i, turns: int,
		terrain: TerrainQuery) -> AdjacencyReport:
	assert(data != null, "adjacence sans bâtiment")
	assert(terrain != null, "adjacence sans terrain")
	if data.adjacency.is_empty():
		return AdjacencyReport.none()

	var footprint := data.cells_at(anchor, turns)
	var found: Array = []
	for rule in data.adjacency:
		found.append(terrain.tagged_within(footprint, rule.tag, rule.radius))
	return AdjacencyReport.create(data.adjacency, found)

## Ce que ce voisinage rapporterait, sans le détail. Raccourci de `inspect().total()`.
##
## Il existe parce que le résolveur ne veut que ça et que `inspect(...).total()` à la ligne se
## lit mal ; il ne recalcule rien, ce qui est la seule forme de raccourci que ce projet
## accepte.
static func bonus(data: BuildingData, anchor: Vector2i, turns: int,
		terrain: TerrainQuery) -> Dictionary[StringName, int]:
	return inspect(data, anchor, turns, terrain).total()
