class_name BuildingRenderer
extends MultiMeshInstance3D
## Les bâtiments posés : une boîte par cellule occupée, un seul draw call.
##
## Une boîte par CELLULE, et non une par bâtiment. Sur une empreinte en L, un volume
## unique couvrirait le trou de l'enveloppe et mentirait sur la forme — or c'est
## précisément la forme que C1 a rendue libre. Le rendu suit l'empreinte, comme la
## validation, et pour la même raison : bounds_at() est une enveloppe, pas un bâtiment.
##
## Passe soeur de TerrainRenderer et non une variante : le relief et les bâtiments se
## peuplent depuis deux états différents et se reconstruisent à des moments différents.
##
## Le renderer ne connaît aucun bâtiment par son nom. Il lit couleur et hauteur sur le
## BuildingData, comme celui du terrain les lit sur le TerrainData : ajouter un
## bâtiment reste une édition de data.

var _metrics: TerrainMetrics

## Renderer prêt à être ajouté à l'arbre, déjà peuplé pour cette ville.
static func create(city: CityState, metrics: TerrainMetrics) -> BuildingRenderer:
	assert(city != null, "rendu d'une ville null")
	assert(metrics != null, "rendu sans métrique")
	var renderer := BuildingRenderer.new()
	renderer.name = "BuildingRenderer"
	renderer._metrics = metrics
	renderer.material_override = _make_material()
	renderer.multimesh = _make_multimesh()
	renderer.rebuild(city)
	return renderer

## Repeuple le rendu depuis cette ville.
##
## Une passe sur les bâtiments posés, à chaque pose et à chaque destruction. Une ville
## en compte quelques dizaines, là où le terrain en compte mille cellules : ce qui
## méritait une réserve chez TerrainRenderer n'en demande pas ici.
func rebuild(city: CityState) -> void:
	assert(city != null, "rendu d'une ville null")
	assert(_metrics != null, "renderer non initialisé — passer par create()")
	var placed := city.buildings()
	multimesh.instance_count = _cell_count(placed)
	var tile := _metrics.tile_size()
	var index := 0
	for building in placed:
		var data := building.data()
		# La hauteur est en fractions de tuile : c'est tile_size qui la met à l'échelle
		# du monde, pour qu'un réglage de la taille des cellules emporte les bâtiments.
		var thickness := data.height * tile
		for cell in building.cells():
			var base := _metrics.cell_surface_center(cell, building.height())
			# La BoxMesh est centrée sur son origine : on monte d'une demi-hauteur pour
			# que ce soit sa FACE DU DESSOUS qui repose sur la surface de la cellule.
			base.y += thickness * 0.5
			multimesh.set_instance_transform(index,
				Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), base))
			multimesh.set_instance_color(index, data.color)
			index += 1

## Combien de boîtes cette ville demande : la somme des cellules de ses empreintes.
func _cell_count(placed: Array[PlacedBuilding]) -> int:
	var count := 0
	for building in placed:
		count += building.data().footprint.size()
	return count

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
