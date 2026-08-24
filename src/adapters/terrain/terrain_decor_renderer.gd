class_name TerrainDecorRenderer
extends MultiMeshInstance3D
## Ce que les cellules portent sur leurs colonnes : une passe MultiMesh par terrain
## décoré.
##
## Des passes soeurs de TerrainRenderer, comme son docstring l'annonçait à T2, et
## jamais une variante d'elle : le sol est une géométrie, les décorations en sont une
## autre, avec sa propre mesh et son propre matériau.
##
## Le renderer ne connaît aucun terrain par son nom. Il reçoit la palette et lit sur
## chaque TerrainData ce qu'il doit dessiner — c'est ce qui garde l'ajout d'un terrain
## décoré dans data/.
##
## La palette est passée en argument plutôt que lue sur GameDatabase, pour deux
## raisons. Les passes se construisent alors sur ce que le jeu CONNAÎT et non sur ce
## qu'une grille contient, donc changer de seed ne peut pas en faire disparaître une ;
## et l'adapter reçoit ses données comme le domaine reçoit les siennes.

## Dérive maximale du centre de la cellule, en fractions de tuile, à variation = 1.
const MAX_DRIFT_RATIO := 0.25

## Écart d'échelle maximal à variation = 1 : les décorations vont alors de 75 % à
## 125 % de leur taille nominale.
const MAX_SIZE_SPREAD := 0.5

## Finesse des primitives. Elles se voient à trente unités de distance sous une
## caméra orthogonale : au-delà, les segments ne coûtent que des sommets.
const CONE_SEGMENTS := 8
const BOULDER_SEGMENTS := 8
const BOULDER_RINGS := 4

## Grains du hash de dispersion. Un par grandeur tirée, pour que deux cellules
## voisines ne partagent ni leur dérive ni leur taille ni leur orientation.
const GRAIN_DRIFT_X := 0
const GRAIN_DRIFT_Z := 1
const GRAIN_SIZE := 2
const GRAIN_SPIN := 3

## Facteurs de mélange du hash. Trois grands nombres impairs sans facteur commun ;
## leurs produits restent loin de la capacité d'un entier 64 bits une fois masqués.
const HASH_X := 374761393
const HASH_Y := 668265263
const HASH_GRAIN := 1274126177
const HASH_MIX := 2246822519
const HASH_WORD := 0xFFFFFFFF

## Nombre de bits gardés pour le tirage final. 24 bits donnent seize millions de
## valeurs distinctes, très au-delà de ce qu'une carte peut montrer.
const NOISE_MASK := 0xFFFFFF

var _terrain_id: StringName
var _decor: TerrainDecor
var _metrics: TerrainMetrics

## Une passe par terrain de la palette qui porte une décoration. Les terrains nus
## n'en produisent aucune.
##
## L'ordre suit celui de la palette reçue, donc celui de GameDatabase, donc l'ordre
## alphabétique : deux exécutions montent le même arbre de scène.
static func create_all(terrains: Array[TerrainData],
		metrics: TerrainMetrics) -> Array[TerrainDecorRenderer]:
	var passes: Array[TerrainDecorRenderer] = []
	for terrain in terrains:
		if terrain == null or terrain.decor == null:
			continue
		passes.append(create(terrain, metrics))
	return passes

## Passe prête à être ajoutée à l'arbre, encore vide. Peupler avec rebuild().
static func create(terrain: TerrainData, metrics: TerrainMetrics) -> TerrainDecorRenderer:
	assert(terrain != null, "passe de décoration sans terrain")
	assert(terrain.decor != null, "le terrain %s ne porte pas de décoration" % terrain.id)
	assert(metrics != null, "passe de décoration sans métrique")
	var renderer := TerrainDecorRenderer.new()
	renderer.name = "TerrainDecor_%s" % terrain.id
	renderer._terrain_id = terrain.id
	renderer._decor = terrain.decor
	renderer._metrics = metrics
	renderer.material_override = _make_material(terrain.decor)
	renderer.multimesh = _make_multimesh(terrain.decor)
	return renderer

## Repose les décorations de cette grille. Seules les cellules de CE terrain comptent ;
## les autres passes s'occupent des leurs.
func rebuild(grid: HeightGrid) -> void:
	assert(grid != null, "décoration d'une grille null")
	assert(_metrics != null, "passe non initialisée — passer par create()")
	var cells := _cells_of_this_terrain(grid)
	multimesh.instance_count = cells.size()
	var tile := _metrics.tile_size()
	var footprint := _decor.width * tile
	var rise := _decor.height * tile
	for index in cells.size():
		var cell := cells[index]
		var anchor := _metrics.cell_surface_center(cell, grid.height_at(cell))
		var drift := _decor.variation * MAX_DRIFT_RATIO * tile
		anchor.x += (_cell_noise(cell, GRAIN_DRIFT_X) - 0.5) * 2.0 * drift
		anchor.z += (_cell_noise(cell, GRAIN_DRIFT_Z) - 0.5) * 2.0 * drift
		var spread := 1.0 + (_cell_noise(cell, GRAIN_SIZE) - 0.5) * _decor.variation * MAX_SIZE_SPREAD
		# Les trois primitives sont centrées sur leur origine : monter d'une
		# demi-élévation pose leur BASE sur la face supérieure de la colonne, ce qui
		# est l'invariant de TerrainMetrics vu depuis le dessus.
		anchor.y += rise * spread * 0.5
		var spin := Basis.from_euler(Vector3(0.0, _cell_noise(cell, GRAIN_SPIN) * TAU, 0.0))
		var scaled := spin.scaled(Vector3(footprint, rise, footprint) * spread)
		multimesh.set_instance_transform(index, Transform3D(scaled, anchor))

## Cellules de la grille qui portent ce terrain, balayées en x puis en y. L'ordre est
## stable, comme celui de TerrainQuery._cells_of().
func _cells_of_this_terrain(grid: HeightGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if grid.terrain_at(cell).id == _terrain_id:
				cells.append(cell)
	return cells

## Tirage dans [0, 1) déterminé par la cellule et le grain.
##
## Un hash plutôt qu'un RandomNumberGenerator, et surtout pas randf() : la dispersion
## doit être la même à chaque affichage d'une même carte, sans qu'aucun flux de tirage
## n'ait à être semé ni transporté jusqu'à une passe de rendu. RunState.rng est un état
## de partie ; il n'a rien à faire ici, et le faire descendre jusqu'au renderer
## coûterait une dépendance pour un résultat identique.
static func _cell_noise(cell: Vector2i, grain: int) -> float:
	var mixed := (cell.x * HASH_X) ^ (cell.y * HASH_Y) ^ (grain * HASH_GRAIN)
	mixed = (mixed ^ (mixed >> 13)) & HASH_WORD
	mixed = (mixed * HASH_MIX) & HASH_WORD
	mixed = mixed ^ (mixed >> 16)
	return float(mixed & NOISE_MASK) / float(NOISE_MASK + 1)

static func _make_multimesh(decor: TerrainDecor) -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre qu'à TerrainRenderer : le format du tampon se fige au premier
	# instance_count non nul. Pas de use_colors ici — une passe est d'une seule teinte.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _make_mesh(decor.shape)
	return multimesh

## Primitive unitaire de cette forme, centrée sur son origine et tenant dans le cube
## [-0.5, 0.5]. C'est ce qui rend la mise à l'échelle et la pose identiques pour les
## trois formes.
static func _make_mesh(shape: TerrainDecor.Shape) -> Mesh:
	match shape:
		TerrainDecor.Shape.CONE:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = CONE_SEGMENTS
			cone.rings = 1
			return cone
		TerrainDecor.Shape.BOULDER:
			var boulder := SphereMesh.new()
			boulder.radius = 0.5
			boulder.height = 1.0
			boulder.radial_segments = BOULDER_SEGMENTS
			boulder.rings = BOULDER_RINGS
			return boulder
	# UNSET n'arrive jamais jusqu'ici : GameDatabase refuse de démarrer dessus.
	assert(false, "forme de décoration inconnue : %d" % shape)
	return null

static func _make_material(decor: TerrainDecor) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Contrairement aux couleurs par instance de TerrainRenderer, albedo_color est
	# déjà lu comme du sRGB par le moteur : rien à convertir à la main ici.
	material.albedo_color = decor.color
	return material
