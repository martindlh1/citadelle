extends Node
## Harnais de dev du système Construction — jalon C1 : la ville, sans rendu.
##
## C1 est explicitement « sans rendu » : les bâtiments n'apparaissent à l'écran qu'à
## C2. Ce harnais est donc un rapport texte, comme l'était la carte ASCII de T1.
##
## Ce qu'il couvre et que les suites de tests ne couvrent pas : le domaine face à une
## carte réellement générée et aux vrais .tres de data/buildings/, là où les tests
## travaillent sur des grilles de six cases faites à la main. Une empreinte mal
## écrite, un terrain inattendu, ou une règle qui ne se déclenche jamais sur du
## terrain réel se voient ici et pas là-bas.
##
## Chaque refus est cherché plutôt que fabriqué : le harnais balaye la carte à la
## recherche d'une ancre qui produit exactement la raison visée. Une raison qui
## resterait introuvable serait le signal intéressant — soit la carte est trop lisse,
## soit la règle ne se déclenche plus.

## Seed de la carte. Fixe : un rapport doit être comparable d'un lancement à l'autre.
const SEED := 1234

## Rendu quand aucune cellule ne convient. Une ancre acceptée est toujours positive,
## puisque son empreinte contient son ancre et que toutes ses cellules sont en carte.
const NO_CELL := Vector2i(-1, -1)

## Cellule libre et constructible.
const GLYPH_FREE := "."

## Cellule sur laquelle on ne bâtit pas — eau, rocher.
const GLYPH_BLOCKED := "#"

## Première lettre attribuée aux bâtiments posés, dans l'ordre de pose.
const GLYPH_FIRST_BUILDING := "A"

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

var _terrain: TerrainQuery
var _city: CityState
var _lines := PackedStringArray()

func _ready() -> void:
	var params := GameDatabase.get_balance().terrain_gen
	_terrain = TerrainGen.generate(SEED, params.map_size, params).to_query()
	_city = CityState.new()
	var size := _terrain.size()
	_lines.append("Construction — seed %d, %d x %d" % [SEED, size.x, size.y])
	_place_every_building()
	_provoke_every_refusal()
	_draw_occupancy()
	var report := "\n".join(_lines)
	print(report)
	add_child(_make_label(report))

## Pose chaque bâtiment de data/ sur la première ancre qui l'accepte, balayée en x
## puis en y — le même ordre que TerrainQuery emploie sur une zone.
func _place_every_building() -> void:
	_lines.append("")
	_lines.append("Poses")
	for id in GameDatabase.list_building_ids():
		var data := GameDatabase.get_building(id)
		var anchor := _first_accepted_anchor(data)
		if anchor == NO_CELL:
			_lines.append("  %-16s aucune ancre ne l'accepte sur cette carte" % id)
			continue
		var result := _city.place(_terrain, data, anchor)
		_lines.append("  %-16s %s  hauteur %d, %d cellule(s)"
			% [id, _format_cell(anchor), result.height(), result.cells().size()])

## Cherche une ancre pour chacune des quatre raisons de refus, sur le bâtiment à la
## plus grande empreinte — sur une seule cellule, la planéité serait vraie partout et
## la règle ne se montrerait jamais.
func _provoke_every_refusal() -> void:
	_lines.append("")
	_lines.append("Refus")
	var widest := _widest_building()
	if widest == null:
		_lines.append("  data/buildings/ est vide, il n'y a rien à refuser")
		return
	var reasons: Array[StringName] = [
		PlacementResult.REASON_OUT_OF_BOUNDS,
		PlacementResult.REASON_NOT_BUILDABLE,
		PlacementResult.REASON_OCCUPIED,
		PlacementResult.REASON_UNEVEN_GROUND,
	]
	for reason in reasons:
		var anchor := _first_anchor_refused_with(widest, reason)
		if anchor == NO_CELL:
			_lines.append("  %-16s introuvable avec %s" % [reason, widest.id])
		else:
			_lines.append("  %-16s %s" % [reason, _format_cell(anchor)])

## La carte, un caractère par cellule : une lettre par bâtiment posé, sinon le
## terrain vu par le contrat.
func _draw_occupancy() -> void:
	_lines.append("")
	_lines.append("Occupation")
	var glyphs: Dictionary[Vector2i, String] = {}
	var placed := _city.buildings()
	for index in placed.size():
		for cell in placed[index].cells():
			glyphs[cell] = _glyph_of(index)
	var size := _terrain.size()
	for y in size.y:
		var row := ""
		for x in size.x:
			var cell := Vector2i(x, y)
			if glyphs.has(cell):
				row += glyphs[cell]
			elif _terrain.is_buildable(cell):
				row += GLYPH_FREE
			else:
				row += GLYPH_BLOCKED
		_lines.append("  " + row)
	_lines.append("")
	_lines.append("  %s libre    %s non constructible" % [GLYPH_FREE, GLYPH_BLOCKED])
	for index in placed.size():
		_lines.append("  %s %s" % [_glyph_of(index), placed[index].data().id])

## Première ancre acceptée, ou NO_CELL si la carte n'en offre aucune.
func _first_accepted_anchor(data: BuildingData) -> Vector2i:
	var size := _terrain.size()
	for y in size.y:
		for x in size.x:
			var anchor := Vector2i(x, y)
			if PlacementValidator.validate(_city, _terrain, data, anchor).is_ok():
				return anchor
	return NO_CELL

## Première ancre refusée pour exactement cette raison, ou NO_CELL.
func _first_anchor_refused_with(data: BuildingData, reason: StringName) -> Vector2i:
	var size := _terrain.size()
	for y in size.y:
		for x in size.x:
			var anchor := Vector2i(x, y)
			var result := PlacementValidator.validate(_city, _terrain, data, anchor)
			if not result.is_ok() and result.reason() == reason:
				return anchor
	return NO_CELL

## Bâtiment à la plus grande empreinte, ou null si data/buildings/ est vide.
## À égalité, le premier par identifiant — list_building_ids() est trié.
func _widest_building() -> BuildingData:
	var widest: BuildingData = null
	for id in GameDatabase.list_building_ids():
		var data := GameDatabase.get_building(id)
		if widest == null or data.footprint.size() > widest.footprint.size():
			widest = data
	return widest

func _glyph_of(index: int) -> String:
	return String.chr(GLYPH_FIRST_BUILDING.unicode_at(0) + index)

func _format_cell(cell: Vector2i) -> String:
	return "(%2d, %2d)" % [cell.x, cell.y]

func _make_label(report: String) -> Label:
	var label := Label.new()
	label.name = "CityReport"
	label.text = report
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	return label
