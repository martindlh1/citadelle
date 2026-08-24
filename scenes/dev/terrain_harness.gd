extends Node
## Harnais de dev du système Terrain — jalon T2 : le relief en blocs étagés, vu par
## une caméra isométrique.
##
## La carte ASCII de T1 a disparu, remplacée par le rendu : c'est très exactement ce
## que T2 apporte. Les décomptes, eux, restent en surimpression — un rendu montre la
## forme d'une carte mais pas ses proportions, et c'est sur les proportions que se
## règle la génération.
##
## Espace passe au seed suivant sans toucher à la caméra : comparer deux cartes
## suppose de ne pas perdre son point de vue entre les deux. Les seeds s'enchaînent à
## partir de FIRST_SEED plutôt que d'être tirés au hasard, pour qu'une carte
## intéressante se retrouve en relançant.
##
## Caméra : Q et E tournent, la molette zoome, les flèches ou WASD et le clic milieu
## déplacent, R recadre.

## Seed de départ. Espace donne FIRST_SEED + 1, puis + 2, etc.
const FIRST_SEED := 1234

## Argument de ligne de commande qui déclenche une capture puis quitte.
const SHOT_FLAG := "--shot"

## Argument optionnel : nombre de quarts de tour à appliquer avant de capturer.
## C'est ce qui rend la rotation de la caméra vérifiable depuis un terminal.
const SHOT_TURNS_FLAG := "--shot-turns"

## Argument optionnel « x,y » : cellule à désigner avant de capturer. Sans lui, la
## capture vise le centre de la carte — jamais rien, parce qu'une capture qui ne
## montre pas la surbrillance ne prouve rien à son sujet.
const SHOT_HOVER_FLAG := "--shot-hover"

## Images laissées passer avant une capture. La première ne porte encore ni le tampon
## d'instances téléversé ni la lumière, et rendrait un cadre vide.
const SHOT_WARMUP_FRAMES := 3

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

## Épaisseur du contour du texte. Sans lui le rapport devient illisible dès qu'il
## passe au-dessus d'une zone claire du terrain.
const REPORT_OUTLINE_SIZE := 4

## Largeur de l'histogramme des altitudes, en caractères.
const HISTOGRAM_WIDTH := 30

## Fond de la vue, au-delà de la carte.
const SKY_COLOR := Color(0.09, 0.11, 0.14)

## Lumière ambiante. Sans elle les flancs à l'ombre tombent au noir et le relief se
## lit comme des trous plutôt que comme des marches.
const AMBIENT_COLOR := Color(0.45, 0.52, 0.62)
const AMBIENT_ENERGY := 0.55

## Orientation du soleil. Volontairement décalée de l'axe de la caméra : c'est ce
## décalage qui donne aux quatre flancs d'une colonne quatre valeurs différentes, donc
## au relief son volume. Un éclairage frontal aplatirait tout.
const SUN_ROTATION_DEGREES := Vector3(-52.0, -125.0, 0.0)
const SUN_ENERGY := 1.15

## Marge de portée des ombres au-delà du recul du rig. Elle doit couvrir la moitié
## arrière de ce que la caméra voit au zoom le plus large ; en dessous, le fond de la
## carte perd son ombre, au-dessus chaque texel de la carte d'ombre couvre plus de
## monde pour rien et tout se floute.
const SUN_SHADOW_MARGIN := 60.0

## Rappel des touches, en pied du rapport. Constante parce que le rapport se
## reconstruit à chaque image depuis que le survol y figure.
const CONTROLS := """Espace : seed suivant.   Q/E : tourner.   Molette : zoom.
Flèches ou WASD, clic milieu : déplacer.   R : recadrer."""

var _metrics: TerrainMetrics
var _renderer: TerrainRenderer
var _decor: Array[TerrainDecorRenderer] = []
var _rig: CameraRig
var _cursor: CellCursor
var _label: Label
var _grid: HeightGrid
var _report_body: String
var _seed := FIRST_SEED

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	add_child(_make_environment())
	add_child(_make_sun())
	var grid := _generate(FIRST_SEED)
	_renderer = TerrainRenderer.create(grid, _metrics)
	add_child(_renderer)
	_decor = TerrainDecorRenderer.create_all(_palette(), _metrics)
	for decor_pass in _decor:
		add_child(decor_pass)
	_rig = CameraRig.create(balance.camera)
	add_child(_rig)
	_rig.frame(_metrics.world_center(grid.size()), _metrics.world_extent(grid.size()))
	_cursor = CellCursor.create(grid, _metrics, _rig.get_camera())
	add_child(_cursor)
	_label = _make_label()
	add_child(_label)
	_show(grid)
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne —
## donc le rapport se réécrit à chaque image. Seule sa dernière ligne change ; le corps
## est calculé une fois par carte, un balayage des mille cellules n'ayant rien à faire
## dans une boucle d'affichage.
func _process(_delta: float) -> void:
	_label.text = "%s\n\n%s\n\n%s" % [_report_body, _hover_line(), CONTROLS]

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_accept"):
		return
	_show(_generate(_seed + 1))
	get_viewport().set_input_as_handled()

## Montre cette grille : le sol, ses décorations, et le survol qui la désigne.
func _show(grid: HeightGrid) -> void:
	_grid = grid
	_renderer.rebuild(grid)
	for decor_pass in _decor:
		decor_pass.rebuild(grid)
	_cursor.set_grid(grid)
	_publish(grid)

## Tous les terrains connus, décorés ou non.
##
## Les passes de décoration se construisent sur la palette et non sur la grille : un
## seed qui ne sortirait aucun rocher ne doit pas supprimer la passe des rochers, que
## le seed suivant remplirait.
func _palette() -> Array[TerrainData]:
	var terrains: Array[TerrainData] = []
	for id in GameDatabase.list_terrain_ids():
		terrains.append(GameDatabase.get_terrain(id))
	return terrains

func _generate(new_seed: int) -> HeightGrid:
	_seed = new_seed
	var params := GameDatabase.get_balance().terrain_gen
	return TerrainGen.generate(_seed, params.map_size, params)

func _publish(grid: HeightGrid) -> void:
	_report_body = _report(grid)
	print(_report_body)

func _report(grid: HeightGrid) -> String:
	var params := GameDatabase.get_balance().terrain_gen
	var lines := PackedStringArray()
	lines.append("Terrain — seed %d, %d x %d" % [_seed, grid.size().x, grid.size().y])
	lines.append("hauteurs %d..%d, nappe à %d"
		% [params.min_height, params.max_height, params.water_level])
	lines.append("")
	lines.append(_terrain_tally(grid))
	lines.append("")
	lines.append(_height_tally(grid))
	return "\n".join(lines)

## Ce que le curseur désigne, en une ligne.
##
## Le point d'impact y figure en toutes lettres : c'est le seul endroit où l'on voit
## si le picker raconte la même histoire que ce qui est à l'écran. Un décalage d'une
## cellule entre la marque et ces coordonnées se lit tout de suite.
func _hover_line() -> String:
	var result := _cursor.hovered()
	if not result.is_hit():
		return "Survol : —"
	var cell := result.cell()
	var impact := result.position()
	return "Survol : (%d, %d)   h = %d   %s   monde (%.2f, %.2f, %.2f)" % [
		cell.x, cell.y, result.height(), _grid.terrain_at(cell).id,
		impact.x, impact.y, impact.z]

## Combien de cellules par terrain, et quelle part de la carte.
func _terrain_tally(grid: HeightGrid) -> String:
	var counts: Dictionary[StringName, int] = {}
	for cell in _cells(grid):
		var id := grid.terrain_at(cell).id
		counts[id] = counts.get(id, 0) + 1
	var total := _cell_count(grid)
	var lines := PackedStringArray()
	lines.append("Terrains")
	for id in _sorted_names(counts.keys()):
		var count: int = counts[id]
		lines.append("  %-8s %5d  %4.1f %%" % [id, count, 100.0 * count / total])
	return "\n".join(lines)

## Combien de cellules par altitude, de la plus basse à la plus haute.
func _height_tally(grid: HeightGrid) -> String:
	var counts: Dictionary[int, int] = {}
	for cell in _cells(grid):
		var height := grid.height_at(cell)
		counts[height] = counts.get(height, 0) + 1
	var heights: Array[int] = []
	heights.assign(counts.keys())
	heights.sort()
	var total := _cell_count(grid)
	var lines := PackedStringArray()
	lines.append("Altitudes")
	for height in heights:
		var count: int = counts[height]
		lines.append("  %3d %5d  %s" % [height, count, "#".repeat(count * HISTOGRAM_WIDTH / total)])
	return "\n".join(lines)

func _cell_count(grid: HeightGrid) -> int:
	return grid.size().x * grid.size().y

func _cells(grid: HeightGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid.size().y:
		for x in grid.size().x:
			cells.append(Vector2i(x, y))
	return cells

## Voir GameDatabase._sorted() : trier des StringName trie des pointeurs, pas du texte.
func _sorted_names(keys: Array) -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(keys)
	names.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second))
	return names

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-turns 1]
##
## C'est le seul moyen de juger un rendu sans ouvrir l'éditeur, donc le seul moyen de
## vérifier T2 depuis un terminal. Les arguments passés après -- sont ceux du jeu et
## non du moteur, d'où get_cmdline_user_args().
func _capture_if_asked() -> void:
	var path := _shot_path()
	if path.is_empty():
		return
	# La souris est à (0, 0) dans une session pilotée en ligne de commande, donc le
	# survol réel tomberait hors de la carte. On coupe l'input du curseur et on désigne
	# une cellule à la main : sans ça, aucune capture ne montrerait la surbrillance, et
	# c'est justement ce qu'on cherche à regarder.
	_cursor.input_enabled = false
	_cursor.hover_cell(_shot_hover_cell(_shot_argument(SHOT_HOVER_FLAG)))
	var turns := _shot_argument(SHOT_TURNS_FLAG).to_int()
	if turns != 0:
		_rig.rotate_steps(turns)
		var seconds: float = GameDatabase.get_balance().camera.rotation_seconds
		await get_tree().create_timer(seconds).timeout
	for _frame in SHOT_WARMUP_FRAMES:
		await get_tree().process_frame
	_probe_camera_ray()
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[terrain_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Contrôle du raccord caméra <-> picker, celui que rien d'autre ne couvre.
##
## Les tests unitaires tirent des rayons fabriqués à la main, et les trois commandes de
## vérification ne regardent pas l'écran. Entre les deux il reste une jointure : est-ce
## que project_ray_origin et project_ray_normal d'une caméra ORTHOGONALE donnent au
## picker ce qu'il attend ? C'est là que T2 s'est fait prendre deux fois.
##
## On projette donc le point d'impact désigné VERS l'écran, puis on retire un rayon
## depuis cette position d'écran exactement comme le ferait la souris. Les deux doivent
## tomber sur la même cellule.
func _probe_camera_ray() -> void:
	var expected := _cursor.hovered()
	if not expected.is_hit():
		print("[terrain_harness] sonde caméra : rien de survolé, contrôle sauté")
		return
	var camera := _rig.get_camera()
	var screen := camera.unproject_position(expected.position())
	var probed := CellPicker.pick(_grid, _metrics,
		camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	var landed := str(probed.cell()) if probed.is_hit() else "rien"
	var agreed := probed.is_hit() and probed.cell() == expected.cell()
	print("[terrain_harness] sonde caméra : écran %s -> %s, attendu %s : %s"
		% [screen.round(), landed, expected.cell(), "OK" if agreed else "DÉSACCORD"])

func _shot_path() -> String:
	return _shot_argument(SHOT_FLAG)

## Cellule à désigner sur une capture, lue en « x,y ». Le centre de la carte à défaut,
## et aussi sur un argument mal formé : une capture doit montrer quelque chose plutôt
## que d'échouer sur une virgule.
func _shot_hover_cell(argument: String) -> Vector2i:
	var middle := _grid.size() / 2
	if argument.is_empty():
		return middle
	var parts := argument.split(",")
	if parts.size() != 2:
		return middle
	return Vector2i(parts[0].to_int(), parts[1].to_int())

## Valeur qui suit ce drapeau sur la ligne de commande, ou "" s'il est absent.
func _shot_argument(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index < 0 or index + 1 >= args.size():
		return ""
	return args[index + 1]

func _make_environment() -> WorldEnvironment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = AMBIENT_ENERGY
	var node := WorldEnvironment.new()
	node.name = "Environment"
	node.environment = environment
	return node

func _make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION_DEGREES
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	# Une seule carte d'ombre, pas de cascades.
	#
	# Le défaut de Godot en découpe quatre selon la profondeur, chacune à une
	# résolution différente et sans fondu entre elles. Sous une caméra orthogonale la
	# profondeur croît linéairement du bas vers le haut de l'écran : ces frontières
	# deviennent des lignes horizontales FIXES à l'écran, nettes d'un côté et floues de
	# l'autre, que le terrain traverse quand on déplace la vue. Les cascades servent à
	# couvrir un horizon lointain ; ici la scène est bornée et tient dans une carte.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# Serrer la portée sur ce que la caméra voit réellement : la même carte d'ombre
	# étalée sur 400 unités au lieu de 180 divise par deux et demi sa densité de texels.
	sun.directional_shadow_max_distance = CameraRig.ORBIT_DISTANCE + SUN_SHADOW_MARGIN
	return sun

func _make_label() -> Label:
	var label := Label.new()
	label.name = "TerrainReport"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", REPORT_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
