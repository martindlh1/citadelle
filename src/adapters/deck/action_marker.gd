class_name ActionMarker
extends MultiMeshInstance3D
## Ce que le joueur a posé, planté sur la carte : un jalon par action.
##
## Vue pure, reconstruite quand le board ou l'affectation bougent. Elle lit deux
## contrats — le plan et l'affectation — et n'en tire aucune règle.
##
## Deux couleurs seulement, et le choix mérite d'être dit : **quelqu'un y travaille, ou
## personne**. Colorer selon « tous les postes sont pris » aurait été plus riche et
## aurait **menti**, parce que le résolveur écarte au passage un ouvrier que la
## main-d'œuvre ne connaît plus, ce qu'un marqueur ne peut pas savoir. Une action vide
## est une action vide, quoi qu'il arrive ensuite ; le décompte exact appartient au
## rapport, où il peut s'expliquer.
##
## Un jalon par action et non par cellule : deux actions peuvent viser la même case, et
## c'est précisément ce que D2 rend possible. Elles se dessinent alors l'une à côté de
## l'autre plutôt que l'une dans l'autre — voir _offset_of().

## Côté du jalon, en fractions de tuile. Assez petit pour qu'il en tienne deux sur une
## cellule sans se recouvrir.
const SIDE_RATIO := 0.26

## Hauteur du jalon, en fractions de tuile. Il doit dépasser d'une colonne de terrain
## vue de biais, sans masquer le bâtiment sur lequel il est planté.
const HEIGHT_RATIO := 0.55

## Décollement de la surface, en fractions de tuile.
const LIFT_RATIO := 0.006

## Écartement de deux jalons posés sur la même cellule, en fractions de tuile.
const SPREAD_RATIO := 0.24

## Une action que personne ne tient, et une action où quelqu'un travaille.
const IDLE_COLOR := Color(0.95, 0.78, 0.30, 0.90)
const MANNED_COLOR := Color(0.35, 0.85, 0.45, 0.90)

var _metrics: TerrainMetrics

## Marqueur prêt à être ajouté à l'arbre, invisible tant que rien n'est posé.
static func create(metrics: TerrainMetrics) -> ActionMarker:
	assert(metrics != null, "marqueur d'actions sans métrique")
	var marker := ActionMarker.new()
	marker.name = "ActionMarker"
	marker._metrics = metrics
	marker.material_override = _make_material()
	marker.multimesh = _make_multimesh()
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	return marker

## Redessine tous les jalons du plan.
##
## Le relief est lu par le contrat Terrain, ce qu'un adapter a parfaitement le droit de
## faire : demander la hauteur d'une cellule est une lecture, pas une règle.
func rebuild(plan: ActionPlan, assign: Assignment, terrain: TerrainQuery) -> void:
	assert(plan != null, "marqueur sans plan")
	assert(assign != null, "marqueur sans affectation")
	assert(_metrics != null, "marqueur non initialisé — passer par create()")
	var posted := plan.actions()
	if posted.is_empty():
		clear()
		return
	_reserve(posted.size())
	var tile := _metrics.tile_size()
	var side := SIDE_RATIO * tile
	var thickness := HEIGHT_RATIO * tile
	var seen: Dictionary[Vector2i, int] = {}
	for index in posted.size():
		var action := posted[index]
		var cell := action.target()
		var rank: int = seen.get(cell, 0)
		seen[cell] = rank + 1
		var ground := terrain.height_at(cell) if terrain.in_bounds(cell) else 0
		var base := _metrics.cell_surface_center(cell, ground)
		base += _offset_of(rank, tile)
		base.y += thickness * 0.5 + LIFT_RATIO * tile
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(Vector3(side, thickness, side)), base))
		var manned := not assign.workers_on(action.id()).is_empty()
		multimesh.set_instance_color(index, MANNED_COLOR if manned else IDLE_COLOR)
	visible = true

## Retire tous les jalons. Rien n'est posé.
func clear() -> void:
	visible = false

## Décalage du n-ième jalon planté sur une même cellule.
##
## Les rangs pairs vont à gauche, les impairs à droite, et l'écart s'ouvre à mesure. Une
## cellule n'en porte que deux ou trois en pratique — les quatre verbes ne peuvent pas
## tous viser la même case —, mais rien ne casse au-delà : ils débordent sur les
## voisines, ce qui reste plus lisible que deux jalons superposés.
func _offset_of(rank: int, tile: float) -> Vector3:
	if rank == 0:
		return Vector3.ZERO
	var step := ((rank + 1) / 2) * SPREAD_RATIO * tile
	return Vector3(step if rank % 2 == 1 else -step, 0.0, 0.0)

func _reserve(count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count
	multimesh.visible_instance_count = count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre que partout ailleurs : le format se fige au premier instance_count non
	# nul, et le régler après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairé : un jalon est un signal et doit garder sa couleur à l'ombre. C'est
	# aussi ce qui lui évite le piège de la face verticale noire décrit dans CLAUDE.md.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
