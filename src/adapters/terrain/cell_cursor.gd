class_name CellCursor
extends Node3D
## Le survol : de la position de la souris à la cellule désignée.
##
## C'est la traduction que fait un adapter, et rien d'autre. Il prend un input, le
## passe à CellPicker sous forme de rayon, et donne le résultat à la vue. Aucune règle
## ne se décide ici — la question « quelle cellule ? » est posée au domaine, et la
## réponse est affichée.
##
## Le tir a lieu à chaque image plutôt que sur mouvement de souris : la caméra bouge
## aussi, et pendant un quart de tour tweené le rayon change sans que le curseur n'ait
## remué. Une marche DDA sur une carte de trente cellules de côté coûte quelques
## dizaines d'itérations — moins qu'un test de collision qu'on aurait remplacé.
##
## input_enabled suit la convention de CameraRig : une scène qui pilote le survol
## elle-même coupe le drapeau et garde l'API — hover_cell() et hovered().

## Le curseur suit-il la souris ? À false, seul hover_cell() déplace la marque.
var input_enabled := true

var _grid: HeightGrid
var _metrics: TerrainMetrics
var _camera: Camera3D
var _highlight: CellHighlight
var _hovered: PickResult

## Curseur prêt à être ajouté à l'arbre, sa marque comprise.
static func create(grid: HeightGrid, metrics: TerrainMetrics, camera: Camera3D) -> CellCursor:
	assert(grid != null, "survol d'une grille null")
	assert(metrics != null, "survol sans métrique")
	assert(camera != null, "survol sans caméra")
	var cursor := CellCursor.new()
	cursor.name = "CellCursor"
	cursor._grid = grid
	cursor._metrics = metrics
	cursor._camera = camera
	cursor._hovered = PickResult.miss()
	cursor._highlight = CellHighlight.create(metrics)
	cursor.add_child(cursor._highlight)
	return cursor

## Ce que le curseur désigne en ce moment. Jamais null : un survol dans le vide rend
## un PickResult qui ne touche rien.
func hovered() -> PickResult:
	return _hovered

## Change la grille survolée — un changement de seed, une forêt déblayée.
func set_grid(grid: HeightGrid) -> void:
	assert(grid != null, "survol d'une grille null")
	_grid = grid
	# La colonne sous le curseur a pu changer de hauteur : refaire le survol tout de
	# suite plutôt que d'attendre que la souris bouge, ce qu'elle ne fera jamais si
	# input_enabled est coupé.
	if _hovered.is_hit():
		hover_cell(_hovered.cell())
	else:
		_apply(PickResult.miss())

## Désigne cette cellule sans passer par la souris.
##
## Fabrique le résultat qu'un rayon tombé sur le centre de la cellule aurait rendu.
## C'est ce qui rend le survol pilotable depuis une ligne de commande, donc vérifiable
## en capture d'écran — sans quoi une surbrillance ne se contrôle qu'à la main.
func hover_cell(cell: Vector2i) -> void:
	if not _grid.in_bounds(cell):
		_apply(PickResult.miss())
		return
	var height := _grid.height_at(cell)
	_apply(PickResult.hit_at(cell, height, _metrics.cell_surface_center(cell, height)))

func _process(_delta: float) -> void:
	if not input_enabled or _camera == null:
		return
	var screen := get_viewport().get_mouse_position()
	_apply(CellPicker.pick(_grid, _metrics,
		_camera.project_ray_origin(screen),
		_camera.project_ray_normal(screen)))

func _apply(result: PickResult) -> void:
	_hovered = result
	if result.is_hit():
		_highlight.show_cell(result.cell(), result.height())
	else:
		_highlight.clear()
