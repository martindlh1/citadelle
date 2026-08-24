extends Node
## Harnais de dev du système Terrain — jalon T1, donc aucun rendu 3D.
##
## Il imprime la grille en ASCII : une lettre par terrain, minuscule si la cellule
## est constructible, plus la carte des hauteurs, le décompte par terrain et
## l'histogramme des altitudes. C'est ce qui permet de juger la génération avant que
## T2 n'apporte le rendu en blocs étagés.
##
## Espace passe au seed suivant. Les seeds s'enchaînent à partir de FIRST_SEED
## plutôt que d'être tirés au hasard : une carte intéressante se retrouve en
## relançant, et le harnais ne contourne pas la règle du RNG seedé.
##
## La sortie standard est le canal lisible. Le Label affiche la même chose à
## l'écran, en police système monospace quand la plateforme en fournit une.

## Seed de départ. Espace donne FIRST_SEED + 1, puis + 2, etc.
const FIRST_SEED := 1234

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

## Hauteur au-delà de laquelle la carte des altitudes n'a plus qu'un chiffre à
## afficher et bascule sur un symbole de débordement.
const MAX_PRINTABLE_HEIGHT := 9

var _label: Label
var _seed := FIRST_SEED

func _ready() -> void:
	_label = _make_label()
	add_child(_label)
	_regenerate(FIRST_SEED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_regenerate(_seed + 1)

func _regenerate(new_seed: int) -> void:
	_seed = new_seed
	var params := GameDatabase.get_balance().terrain_gen
	var grid := TerrainGen.generate(_seed, params.map_size, params)
	var report := _report(grid, params)
	_label.text = report
	print(report)

func _report(grid: HeightGrid, params: TerrainGenBalance) -> String:
	var lines := PackedStringArray()
	lines.append("Terrain — seed %d, %d x %d" % [_seed, grid.size().x, grid.size().y])
	lines.append("hauteurs %d..%d, nappe à %d" % [params.min_height, params.max_height, params.water_level])
	lines.append("")
	lines.append(_terrain_map(grid))
	lines.append("")
	lines.append(_height_map(grid))
	lines.append("")
	lines.append(_terrain_tally(grid))
	lines.append("")
	lines.append(_height_tally(grid))
	lines.append("")
	lines.append("Espace : seed suivant.")
	return "\n".join(lines)

## Une lettre par terrain, minuscule si constructible, majuscule sinon.
func _terrain_map(grid: HeightGrid) -> String:
	var lines := PackedStringArray()
	for y in grid.size().y:
		var row := PackedStringArray()
		for x in grid.size().x:
			row.append(_terrain_symbol(grid.terrain_at(Vector2i(x, y))))
		lines.append("".join(row))
	return "\n".join(lines)

## Un chiffre par cran de hauteur.
func _height_map(grid: HeightGrid) -> String:
	var lines := PackedStringArray()
	for y in grid.size().y:
		var row := PackedStringArray()
		for x in grid.size().x:
			row.append(_height_symbol(grid.height_at(Vector2i(x, y))))
		lines.append("".join(row))
	return "\n".join(lines)

## Combien de cellules par terrain, et quelle part de la carte.
func _terrain_tally(grid: HeightGrid) -> String:
	var counts: Dictionary[StringName, int] = {}
	for cell in _cells(grid):
		var id := grid.terrain_at(cell).id
		counts[id] = counts.get(id, 0) + 1
	var total := grid.size().x * grid.size().y
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
	var lines := PackedStringArray()
	lines.append("Altitudes")
	for height in heights:
		var count: int = counts[height]
		lines.append("  %3d %5d  %s" % [height, count, "#".repeat(count * 40 / (grid.size().x * grid.size().y))])
	return "\n".join(lines)

func _terrain_symbol(terrain: TerrainData) -> String:
	var letter := String(terrain.id).left(1)
	return letter if terrain.is_buildable() else letter.to_upper()

func _height_symbol(height: int) -> String:
	if height < 0:
		return "-"
	if height > MAX_PRINTABLE_HEIGHT:
		return "+"
	return str(height)

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

func _make_label() -> Label:
	var label := Label.new()
	label.name = "TerrainReport"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	return label
