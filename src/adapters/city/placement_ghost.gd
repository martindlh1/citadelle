class_name PlacementGhost
extends MultiMeshInstance3D
## Le fantôme : les cellules que le bâtiment couvrirait, teintées par la réponse du
## domaine.
##
## Il ne décide RIEN. CellHighlight annonçait déjà à T3 qu'elle ne coderait aucune
## validité et que la question appartiendrait à C2 : la voici, et la réponse vient
## toujours du domaine. Le fantôme reçoit un PlacementResult déjà calculé et le
## colore. Vert accepté, rouge refusé — aucune règle n'est réévaluée ici, sans quoi
## l'écran et la pose pourraient se contredire.
##
## Il dessine TOUTES les cellules de l'empreinte, y compris celles qui débordent de la
## carte. Un bâtiment à moitié dans le vide se voit alors tel qu'il est, ce qui
## explique le refus mieux qu'une empreinte tronquée.

## Teintes du fantôme. Translucides : on doit lire le terrain à travers, sans quoi le
## fantôme cache exactement ce sur quoi on cherche à se décider.
const OK_COLOR := Color(0.45, 0.95, 0.5, 0.45)
const REFUSED_COLOR := Color(0.95, 0.33, 0.28, 0.45)

## Décollement de la surface, en fractions de tuile. La boîte repose déjà dessus ;
## cette marge n'existe que pour les angles rasants, où deux surfaces qui se touchent
## scintillent.
const LIFT_RATIO := 0.004

var _metrics: TerrainMetrics

## Fantôme prêt à être ajouté à l'arbre, invisible tant que rien n'est visé.
static func create(metrics: TerrainMetrics) -> PlacementGhost:
	assert(metrics != null, "fantôme sans métrique")
	var ghost := PlacementGhost.new()
	ghost.name = "PlacementGhost"
	ghost._metrics = metrics
	ghost.material_override = _make_material()
	ghost.multimesh = _make_multimesh()
	# Un fantôme qui projette une ombre dessinerait un bâtiment qui n'existe pas encore.
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	return ghost

## Montre ce bâtiment posé sur cette ancre, au sol de hauteur `ground`, teinté par
## `result`.
##
## `ground` est passé à part et n'est pas lu sur le résultat : un refus n'a pas de
## hauteur — PlacementResult.height() lève sur un placement refusé, et c'est justement
## sur un refus qu'on a le plus besoin de voir le fantôme. La hauteur vient donc de la
## cellule survolée, qui est toujours connue.
func show_at(data: BuildingData, anchor: Vector2i, ground: int,
		result: PlacementResult) -> void:
	assert(data != null, "fantôme sans données de bâtiment")
	assert(result != null, "fantôme sans résultat")
	assert(_metrics != null, "fantôme non initialisé — passer par create()")
	var cells := data.cells_at(anchor)
	if cells.is_empty():
		clear()
		return
	_reserve(cells.size())
	var tile := _metrics.tile_size()
	var thickness := data.height * tile
	var color := OK_COLOR if result.is_ok() else REFUSED_COLOR
	for index in cells.size():
		var base := _metrics.cell_surface_center(cells[index], ground)
		base.y += thickness * 0.5 + LIFT_RATIO * tile
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), base))
		multimesh.set_instance_color(index, color)
	visible = true

## Retire le fantôme. Plus rien n'est visé.
func clear() -> void:
	visible = false

## Assure que le tampon tient `count` boîtes, sans le réallouer à chaque image.
##
## instance_count ne fait que croître ; c'est visible_instance_count qui découpe. Le
## fantôme est reconstruit à chaque image sous le curseur, et redimensionner le tampon
## soixante fois par seconde pour trois boîtes serait absurde.
func _reserve(count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count
	multimesh.visible_instance_count = count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre que TerrainRenderer : le format se fige au premier instance_count non
	# nul, et le régler après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairé : le fantôme doit garder sa teinte sur un flanc à l'ombre comme sur
	# une crête au soleil. Vert et rouge sont un signal, pas un objet de la scène.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
