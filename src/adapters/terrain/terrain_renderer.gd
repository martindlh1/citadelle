class_name TerrainRenderer
extends MultiMeshInstance3D
## Le relief en blocs étagés : une colonne par cellule, un seul draw call.
##
## Un MultiMesh de BoxMesh unitaires mis à l'échelle, couleur par instance. Pas de
## GridMap : il ne sait pas faire une hauteur variable par cellule sans empiler des
## cubes unitaires, ce qui multiplierait les instances par la hauteur de la carte.
##
## C'est la passe du sol, et elle seule. Les décorations de T3 — arbres, rochers,
## gisements — seront des passes soeurs, une par type, jamais une variante d'ici.
##
## Le renderer ne connaît aucun terrain par son nom : il lit la couleur sur le
## TerrainData de la cellule. Ajouter un terrain reste une édition de data.

var _metrics: TerrainMetrics

## Renderer prêt à être ajouté à l'arbre, déjà peuplé pour cette grille.
static func create(grid: HeightGrid, metrics: TerrainMetrics) -> TerrainRenderer:
	assert(grid != null, "rendu d'une grille null")
	assert(metrics != null, "rendu sans métrique")
	var renderer := TerrainRenderer.new()
	renderer.name = "TerrainRenderer"
	renderer._metrics = metrics
	renderer.material_override = _make_material()
	renderer.multimesh = _make_multimesh()
	renderer.rebuild(grid)
	return renderer

## Repeuple le rendu depuis cette grille. La métrique, elle, ne change pas : elle
## vient de l'équilibrage et vaut pour toute la partie.
##
## Reconstruire coûte une passe sur les cellules. C'est assez pour changer de seed
## dans un harnais ; le jour où une seule cellule change — un déblaiement de forêt à
## la construction — il faudra une mise à jour ciblée plutôt que celle-ci.
func rebuild(grid: HeightGrid) -> void:
	assert(grid != null, "rendu d'une grille null")
	assert(_metrics != null, "renderer non initialisé — passer par create()")
	var extent := grid.size()
	multimesh.instance_count = extent.x * extent.y
	# Le socle vient de la métrique, pas d'une constante locale : le CellPicker ferme
	# ses colonnes sur ce même plan, et une silhouette dessinée ailleurs que là où on
	# la désigne rendrait le survol faux sous le bord de la carte.
	var floor_y := _metrics.base_y(grid.lowest_height())
	var tile := _metrics.tile_size()
	var index := 0
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var top := _metrics.cell_surface_center(cell, grid.height_at(cell))
			var thickness := top.y - floor_y
			# La BoxMesh est centrée sur son origine : on descend d'une demi-épaisseur
			# pour que ce soit sa FACE du dessus qui atterrisse sur la surface, et pas
			# son centre. C'est l'invariant de TerrainMetrics qui se joue ici.
			top.y -= thickness * 0.5
			multimesh.set_instance_transform(index,
				Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), top))
			multimesh.set_instance_color(index, grid.terrain_at(cell).color)
			index += 1

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# L'ordre compte : Godot fige le format du tampon d'instances au premier
	# instance_count non nul. Régler transform_format ou use_colors après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Les couleurs des .tres sont choisies dans un sélecteur, donc en sRGB, alors que
	# le rendu travaille en linéaire. Sans cette conversion elles ressortent délavées.
	material.vertex_color_is_srgb = true
	return material
