class_name CellPicker
extends RefCounted
## Quelle cellule un rayon rencontre-t-il ? Marche DDA sur la grille de hauteurs.
##
## Pas de collider, pas de PhysicsServer : la grille est une fonction, et un rayon qui
## la traverse se résout analytiquement. C'est exact, testable sans arbre de scène, et
## ça ne coûte rien à maintenir en face d'un relief qui change de forme à chaque pose.
##
## L'adapter caméra fournit origin et dir via project_ray_origin / project_ray_normal.
##
## La signature de CLAUDE.md prenait (grid, origin, dir). Elle reçoit ici la métrique
## en plus, parce que le passage monde -> grille en dépend et que T2 a délibérément
## sorti tile_size et step_height de HeightGrid pour les mettre dans TerrainMetrics.
## La fonction reste pure et statique, et reçoit son réglage en argument comme
## TerrainGen.generate() reçoit le sien.
##
## Modèle de collision : une colonne est SOLIDE VERS LE BAS, sans fond. On ne regarde
## jamais le terrain par en dessous, et le socle que le renderer dessine sous la carte
## n'est qu'une épaisseur d'affichage — lui donner un fond ici ouvrirait des tirs qui
## passent sous la carte pour ressortir de l'autre côté.

## Marge sur le nombre de cellules qu'un rayon peut visiter. Une droite en coupe au
## plus largeur + profondeur + 1 ; le facteur absorbe les pas dégénérés que produit un
## point d'entrée tombé pile sur une arête.
const STEP_BUDGET_FACTOR := 2

## Première cellule que le rayon rencontre, ou un miss s'il n'en rencontre aucune.
##
## `dir` n'a pas à être normalisé, mais ne peut pas être nul. Les tirs qui partent
## en arrière de l'origine ne comptent pas : la carte entièrement derrière le tireur
## est un miss.
static func pick(grid: HeightGrid, metrics: TerrainMetrics,
		origin: Vector3, dir: Vector3) -> PickResult:
	assert(grid != null, "tir sur une grille null")
	assert(metrics != null, "tir sans métrique")
	assert(not dir.is_zero_approx(), "direction de tir nulle")
	var ray := dir.normalized()
	var span := _footprint_span(origin, ray, metrics.world_extent(grid.size()))
	# span.x > span.y : le rayon rate l'emprise de la carte.
	# span.y < 0      : il la traverserait, mais entièrement derrière son origine.
	if span.x > span.y or span.y < 0.0:
		return PickResult.miss()
	return _walk(grid, metrics, origin, ray, maxf(span.x, 0.0), span.y)

## Marche de cellule en cellule, de l'entrée dans l'emprise jusqu'à la sortie.
##
## À chaque cellule visitée on tient l'intervalle [u, u_exit] du rayon qui la traverse,
## et on teste sa colonne. C'est la seule boucle du picker.
static func _walk(grid: HeightGrid, metrics: TerrainMetrics,
		origin: Vector3, ray: Vector3, u_in: float, u_out: float) -> PickResult:
	var size := grid.size()
	var tile := metrics.tile_size()
	var u := u_in
	var cell := metrics.cell_at(origin + ray * u)
	# Le point d'entrée est posé sur une face de l'emprise : un ulp de flottant suffit
	# à le faire tomber du mauvais côté. On le ramène dans la grille — le clip a déjà
	# prouvé que le rayon y entre.
	cell = Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))

	var step_x := _axis_step(ray.x)
	var step_z := _axis_step(ray.z)
	var next_x := _first_crossing(origin.x, ray.x, cell.x, tile)
	var next_z := _first_crossing(origin.z, ray.z, cell.y, tile)
	var delta_x := _crossing_period(ray.x, tile)
	var delta_z := _crossing_period(ray.z, tile)

	for _visit in (size.x + size.y + 1) * STEP_BUDGET_FACTOR:
		var u_exit := minf(minf(next_x, next_z), u_out)
		var height := grid.height_at(cell)
		var top := metrics.surface_y(height)
		var y_enter := origin.y + ray.y * u
		var y_exit := origin.y + ray.y * u_exit
		# Le rayon plonge sous le sommet quelque part dans la cellule : il est dans la
		# colonne. y étant linéaire en u, son minimum sur l'intervalle est à l'un des
		# deux bouts, et il n'y a rien de plus à chercher.
		if minf(y_enter, y_exit) <= top:
			return PickResult.hit_at(cell, height, _impact(origin, ray, u, y_enter, top))
		if next_x < next_z:
			u = next_x
			cell.x += step_x
			next_x += delta_x
		else:
			u = next_z
			cell.y += step_z
			next_z += delta_z
		if u > u_out or not grid.in_bounds(cell):
			return PickResult.miss()
	return PickResult.miss()

## Point d'impact sur une colonne dont le sommet est à `top`, sachant que le rayon
## entre dans la cellule au paramètre `u_enter`, à l'altitude `y_enter`.
static func _impact(origin: Vector3, ray: Vector3,
		u_enter: float, y_enter: float, top: float) -> Vector3:
	if y_enter <= top:
		# Le rayon entrait déjà sous le sommet : il touche un FLANC, sur l'arête
		# verticale par laquelle il est entré dans la cellule.
		return origin + ray * u_enter
	# Sinon il franchit le plan du sommet à l'intérieur de la cellule : c'est la FACE
	# SUPÉRIEURE. y_enter > top impose ray.y < 0, la division est donc sûre.
	var impact := origin + ray * ((top - origin.y) / ray.y)
	# Ce y vaut exactement le sommet par construction. Le laisser sortir du calcul
	# flottant y remettrait quelques ulp de bruit, dans la valeur même sur laquelle un
	# bâtiment viendra se poser.
	impact.y = top
	return impact

## Intervalle (entrée, sortie) du rayon dans l'emprise au sol de la carte, en
## paramètre le long du rayon. Intervalle inversé — x > y — quand il la rate.
##
## Sans ce clip, un rayon parti d'une caméra orthogonale à cent unités de la carte
## commencerait sa marche loin dans le vide.
static func _footprint_span(origin: Vector3, ray: Vector3, extent: Vector2) -> Vector2:
	var span := Vector2(-INF, INF)
	span = _slab(origin.x, ray.x, extent.x, span)
	span = _slab(origin.z, ray.z, extent.y, span)
	return span

## Rétrécit l'intervalle sur la bande [0, hi] d'un axe.
static func _slab(from: float, along: float, hi: float, span: Vector2) -> Vector2:
	if is_zero_approx(along):
		# Rayon parallèle à cette paire de faces : soit il est déjà dans la bande et
		# elle ne le contraint pas, soit il n'y entrera jamais.
		if from < 0.0 or from > hi:
			return Vector2(1.0, 0.0)
		return span
	var first := -from / along
	var second := (hi - from) / along
	return Vector2(
		maxf(span.x, minf(first, second)),
		minf(span.y, maxf(first, second)))

## Sens du pas de la marche sur cet axe. 0 quand le rayon lui est parallèle.
static func _axis_step(along: float) -> int:
	if is_zero_approx(along):
		return 0
	return 1 if along > 0.0 else -1

## Paramètre auquel le rayon franchit la prochaine arête de cet axe.
##
## INF quand il est parallèle à l'axe : la comparaison de la marche ne choisira alors
## jamais cette direction, et la cellule n'y bougera pas.
static func _first_crossing(from: float, along: float, index: int, tile: float) -> float:
	if is_zero_approx(along):
		return INF
	var edge := (index + (1 if along > 0.0 else 0)) * tile
	return (edge - from) / along

## Paramètre écoulé entre deux arêtes consécutives de cet axe.
static func _crossing_period(along: float, tile: float) -> float:
	if is_zero_approx(along):
		return INF
	return tile / absf(along)
