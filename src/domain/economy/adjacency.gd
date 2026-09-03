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
## **Elle ne balaie pas elle-même.** `TerrainQuery.tagged_within()` et `vein_from()` portent
## les deux parcours, parce que la Construction pose la même question au terrain pour refuser
## un bâtiment sans voisin — deux systèmes du domaine, donc un contrat.
##
## Ce qui reste ici est ce qui est vraiment de l'Économie : **décider quoi compter selon le
## mode**, puis traduire des cases en ressources. Le placement, lui, n'a jamais besoin que de
## la première question — « au moins une case à portée ? » —, qui est la même dans les trois
## modes. C'est pourquoi la règle du validateur n'a pas eu à changer d'une ligne à `C7`.

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
		found.append(_counted(terrain, footprint, rule))
	return AdjacencyReport.create(data.adjacency, found)

## Ce que cette règle compte, selon son mode.
##
## **C'est ici que les trois modes se séparent, et nulle part ailleurs.** La règle ne connaît
## que son barème ; savoir *quoi* compter demande de voir le terrain, donc c'est de ce côté-ci
## de la frontière.
##
## `PER_CELL` et `FLAT` comptent les cases à portée — le second n'en fait rien d'autre que
## regarder si la liste est vide, et c'est `award()` qui s'en charge. `VEIN` remonte de ces
## cases au **filon entier**, au-delà du rayon.
##
## Les cases rendues sont aussi celles que le fantôme colore : sur une règle au filon, c'est
## donc la veine complète qui s'allume sous le curseur, ce qui montre d'où vient le rendement
## plutôt que de l'annoncer. Un compte qui ne rendrait qu'un entier aurait laissé l'écran
## refaire le parcours de son côté.
static func _counted(terrain: TerrainQuery, footprint: Array[Vector2i],
		rule: AdjacencyRule) -> Array[Vector2i]:
	var touched := terrain.tagged_within(footprint, rule.tag, rule.radius)
	if rule.mode != AdjacencyRule.Mode.VEIN:
		return touched
	return terrain.vein_from(touched, rule.tag)

## Ce que ce voisinage rapporterait, sans le détail. Raccourci de `inspect().total()`.
##
## Il existe parce que le résolveur ne veut que ça et que `inspect(...).total()` à la ligne se
## lit mal ; il ne recalcule rien, ce qui est la seule forme de raccourci que ce projet
## accepte.
static func bonus(data: BuildingData, anchor: Vector2i, turns: int,
		terrain: TerrainQuery) -> Dictionary[StringName, int]:
	return inspect(data, anchor, turns, terrain).total()
