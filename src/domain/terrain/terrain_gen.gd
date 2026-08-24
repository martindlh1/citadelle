class_name TerrainGen
extends RefCounted
## Génération de terrain seedée.
##
## Fonction pure : même seed et mêmes réglages rendent exactement la même grille.
## C'est ce qui rend un run rejouable et un bug d'équilibrage reproductible à partir
## d'un seed et d'une suite d'actions.
##
## Le seed est passé en argument plutôt que pris sur un RNG partagé. La génération ne
## consomme donc pas le flux du run : elle se rejoue seule en test, sans dépendre de
## ce qui a été tiré avant elle.
##
## Deux passes. Le relief d'abord, découpé en crans depuis un bruit fractal, avec la
## nappe d'eau aplanie à son niveau. La dispersion ensuite, en bandes cumulées sur un
## tirage unique par cellule émergée.

## Décorrèle le flux de dispersion de celui du relief. Sans ce décalage les deux
## passes partiraient du même seed et leurs motifs seraient corrélés — des forêts
## qui suivent les lignes de crête, par exemple.
const SCATTER_SEED_SALT := 0x5CA77E12

## Grille générée pour ce seed, aux dimensions demandées.
static func generate(run_seed: int, size: Vector2i, params: TerrainGenBalance) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de carte non positive : %s" % size)
	assert(params != null, "réglages de génération null")
	assert(params.missing_fields().is_empty(),
		"réglages de génération inexploitables : %s" % ", ".join(params.missing_fields()))
	var grid := HeightGrid.create(size, params.min_height, params.plain)
	_carve_relief(grid, run_seed, params)
	_scatter(grid, run_seed, params)
	return grid

## Pose la hauteur de chaque cellule, et l'eau partout où le relief passe au niveau
## de la nappe ou en dessous. L'eau est aplanie : une nappe est plate.
static func _carve_relief(grid: HeightGrid, run_seed: int, params: TerrainGenBalance) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = run_seed
	noise.frequency = params.noise_frequency
	noise.fractal_octaves = params.noise_octaves
	var levels := params.max_height - params.min_height + 1
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			# get_noise_2d rend [-1, 1] : on le ramène en [0, 1] avant de le
			# découper en crans. mini() rattrape le cas d'un bruit exactement à 1.
			var unit := clampf((noise.get_noise_2d(x, y) + 1.0) * 0.5, 0.0, 1.0)
			var height := params.min_height + mini(int(unit * levels), levels - 1)
			var cell := Vector2i(x, y)
			if height <= params.water_level:
				grid.set_cell(cell, params.water_level, params.water)
			else:
				grid.set_cell(cell, height, params.plain)

## Répartit forêt, gisement et rocher sur les cellules émergées, en bandes cumulées.
static func _scatter(grid: HeightGrid, run_seed: int, params: TerrainGenBalance) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ SCATTER_SEED_SALT
	var forest_band := params.forest_density
	var stone_band := forest_band + params.stone_density
	var rock_band := stone_band + params.rock_density
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if grid.terrain_at(cell) == params.water:
				continue
			# Le tirage est consommé même quand il ne donne rien : relever
			# forest_max_height ne doit pas décaler tout le reste du flux.
			var draw := rng.randf()
			if draw < forest_band:
				if grid.height_at(cell) <= params.forest_max_height:
					grid.set_terrain(cell, params.forest)
			elif draw < stone_band:
				grid.set_terrain(cell, params.stone)
			elif draw < rock_band:
				grid.set_terrain(cell, params.rock)
