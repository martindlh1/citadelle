extends Node
## Harnais de dev du système Construction — jalon C2 : le fantôme, la pose, la
## destruction.
##
## Le rapport texte de C1 a disparu, remplacé par la scène : c'est très exactement ce
## que C2 apporte. Ce qu'il énumérait — les quatre raisons de refus, trouvées sur la
## carte — se lit maintenant en promenant le curseur, ce qui est plus direct qu'une
## liste.
##
## Le harnais ne décide rien. Il traduit un clic en appel de domaine, et une réponse de
## domaine en couleur. C'est tout le travail d'un adapter, et la règle vaut ici comme
## ailleurs : si un « if » sur le terrain ou sur les ressources apparaissait dans ce
## fichier, ce serait un bug d'architecture.
##
## La ville s'ouvre avec ses bâtiments déjà posés, chacun sur la première ancre qui
## l'accepte. Deux raisons : une capture montre alors quelque chose sans qu'il faille
## piloter des clics, et la première destruction a une cible sans qu'il faille bâtir
## d'abord.
##
## Clic gauche pose, clic droit détruit, 1 à 9 choisissent le bâtiment. La caméra garde
## Q et E, la molette, WASD et R.

## Seed de la carte. Fixe : deux lancements doivent se comparer.
const SEED := 1234

## Rendu quand aucune cellule ne convient. Une ancre acceptée est toujours positive,
## puisque l'empreinte contient son ancre et que toutes ses cellules sont en carte.
const NO_CELL := Vector2i(-1, -1)

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

## Épaisseur du contour du texte. Sans lui le rapport devient illisible dès qu'il passe
## au-dessus d'une zone claire du terrain.
const REPORT_OUTLINE_SIZE := 4

## Rappel des touches, en pied du rapport.
const CONTROLS := "Clic gauche : poser.   Clic droit : détruire.   1-9 : bâtiment.   Tab : pivoter.\nQ/E : tourner la caméra.   Molette : zoom.   WASD ou clic milieu : déplacer.   R : recadrer."

var _metrics: TerrainMetrics
var _world: DevWorld
var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _label: Label
var _catalogue: Array[BuildingData] = []
var _selected := 0
var _turns := 0
var _preview: PlacementResult
var _last_action := "—"

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	var params := balance.terrain_gen
	_grid = TerrainGen.generate(SEED, params.map_size, params)
	_terrain = _grid.to_query()
	_world = DevWorld.create(_grid, _metrics, balance)
	add_child(_world)
	_city = CityState.new()
	_catalogue = _known_buildings()
	_seed_city()
	_renderer = BuildingRenderer.create(_city, _metrics)
	add_child(_renderer)
	_ghost = PlacementGhost.create(_metrics)
	add_child(_ghost)
	_label = _make_label()
	add_child(_label)
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne —
## donc le fantôme et le rapport se refont à chaque image. Une validation coûte une
## poignée de cellules, et c'est exactement ce que C1 a rendu appelable ici.
func _process(_delta: float) -> void:
	_refresh_preview()
	_label.text = _report()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)

## Le clic gauche pose, le droit détruit. La molette et le clic milieu restent à la
## caméra, qui les traite dans son propre _unhandled_input.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_place_here()
		MOUSE_BUTTON_RIGHT:
			_demolish_here()
		_:
			return
	get_viewport().set_input_as_handled()

## Tab pivote ce qu'on s'apprête à poser, 1 à 9 choisissent le bâtiment.
##
## Sélection directe plutôt qu'un cycle : sur quatre entrées, tourner en rond pour
## revenir à la première est une gêne pure. La rotation, elle, est bien un cycle — il
## n'y a que quatre orientations et elles se suivent naturellement.
##
## Tab et non R : R recadre la caméra depuis T2. Un vrai jeu du genre mettrait la
## rotation sur R et déplacerait le recadrage, mais c'est une décision d'UI qui
## appartient à D2, pas au sélecteur de debug d'un harnais.
func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		_turns = posmod(_turns + 1, BuildingData.QUARTER_TURNS)
		get_viewport().set_input_as_handled()
		return
	var index := event.keycode - KEY_1
	if index < 0 or index >= _catalogue.size():
		return
	_selected = index
	get_viewport().set_input_as_handled()

## Pose le bâtiment courant sous le curseur.
##
## La ville valide elle-même : le harnais ne teste rien avant d'appeler, il rapporte ce
## qu'on lui répond. C'est ce qui garantit que l'écran et l'état ne divergent pas.
func _place_here() -> void:
	var hovered := _world.cursor().hovered()
	var data := _selected_building()
	if not hovered.is_hit() or data == null:
		_last_action = "Pose : rien sous le curseur."
		return
	var result := _city.place(_terrain, data, hovered.cell(), _turns)
	if not result.is_ok():
		_last_action = "Refusé : %s en %s, %s — %s" % [
			data.id, hovered.cell(), _orientation(_turns), result.reason()]
		return
	_renderer.rebuild(_city)
	_last_action = "Posé : %s en %s, %s, hauteur %d" % [
		data.id, hovered.cell(), _orientation(_turns), result.height()]

## Détruit le bâtiment sous le curseur.
##
## Le curseur tient une cellule quelconque de l'empreinte et remove() veut l'ancre :
## c'est exactement le chemin pour lequel CityState.anchor_at() existe.
func _demolish_here() -> void:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		_last_action = "Destruction : rien sous le curseur."
		return
	var cell := hovered.cell()
	if not _city.is_occupied(cell):
		_last_action = "Destruction : rien de bâti en %s" % cell
		return
	var anchor := _city.anchor_at(cell)
	var id := _city.building_at(cell).data().id
	_city.remove(anchor)
	_renderer.rebuild(_city)
	_last_action = "Détruit : %s ancré en %s" % [id, anchor]

## Réévalue ce que donnerait une pose sous le curseur, et le montre.
##
## La validation a lieu ICI et une seule fois : le fantôme et le rapport lisent le même
## résultat. Les faire valider chacun de son côté ouvrirait la porte à une couleur qui
## contredit sa propre légende.
func _refresh_preview() -> void:
	var hovered := _world.cursor().hovered()
	var data := _selected_building()
	if not hovered.is_hit() or data == null:
		_preview = null
		_ghost.clear()
		return
	_preview = PlacementValidator.validate(_city, _terrain, data, hovered.cell(), _turns)
	# La hauteur vient du survol et non du résultat : un refus n'en a pas, et c'est
	# justement sur un refus qu'il faut voir le fantôme.
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), _preview)

## Pose chaque bâtiment connu sur la première ancre qui l'accepte, balayée en x puis en
## y — le même ordre que TerrainQuery emploie sur une zone.
##
## Chacun est posé dans une orientation différente, son rang dans le catalogue faisant
## office de crans. C'est arbitraire et assumé : sans ça, aucune capture ne montrerait
## un bâtiment POSÉ pivoté, et le rendu d'une empreinte tournée ne serait vérifié nulle
## part — le fantôme seul ne prouve rien sur BuildingRenderer.
func _seed_city() -> void:
	for index in _catalogue.size():
		var data := _catalogue[index]
		var anchor := _first_accepted_anchor(data, index)
		if anchor != NO_CELL:
			_city.place(_terrain, data, anchor, index)

func _first_accepted_anchor(data: BuildingData, turns: int) -> Vector2i:
	var size := _terrain.size()
	for y in size.y:
		for x in size.x:
			var anchor := Vector2i(x, y)
			if PlacementValidator.validate(_city, _terrain, data, anchor, turns).is_ok():
				return anchor
	return NO_CELL

## Tous les bâtiments de data/, triés par identifiant.
func _known_buildings() -> Array[BuildingData]:
	var buildings: Array[BuildingData] = []
	for id in GameDatabase.list_building_ids():
		buildings.append(GameDatabase.get_building(id))
	return buildings

func _selected_building() -> BuildingData:
	if _selected < 0 or _selected >= _catalogue.size():
		return null
	return _catalogue[_selected]

func _report() -> String:
	var size := _grid.size()
	var lines := PackedStringArray()
	lines.append("Construction — seed %d, %d x %d   %d bâtiment(s) posé(s)"
		% [SEED, size.x, size.y, _city.count()])
	lines.append("")
	lines.append(_catalogue_lines())
	lines.append("")
	lines.append(_hover_line())
	lines.append(_last_action)
	lines.append("")
	lines.append(CONTROLS)
	return "\n".join(lines)

func _catalogue_lines() -> String:
	var lines := PackedStringArray()
	lines.append("Bâtiments")
	for index in _catalogue.size():
		var data := _catalogue[index]
		var mark := ">" if index == _selected else " "
		var turns := _orientation(_turns) if index == _selected else ""
		lines.append("  %s %d  %-16s %d cellule(s), h %.2f  %s"
			% [mark, index + 1, data.id, data.footprint.size(), data.height, turns])
	return "\n".join(lines)

## Ce que le curseur désigne, et le verdict du domaine sur une pose à cet endroit.
## C'est la légende du fantôme : la couleur dit oui ou non, cette ligne dit pourquoi.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit() or _preview == null:
		return "Survol : —"
	var cell := hovered.cell()
	var verdict := "accepté" if _preview.is_ok() else String(_preview.reason())
	return "Survol : (%d, %d)   h = %d   %s   %s   -> %s" % [
		cell.x, cell.y, hovered.height(), _grid.terrain_at(cell).id,
		_orientation(_turns), verdict]

## L'orientation en clair. Les crans seuls ne disent rien à la lecture d'une capture,
## et c'est précisément là qu'on cherche à vérifier qu'une forme a bien pivoté.
func _orientation(turns: int) -> String:
	return "%d/4" % posmod(turns, BuildingData.QUARTER_TURNS)

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-hover x,y] [--shot-turns 1]
##
## C1 se vérifiait aux tests ; C2 ne le peut pas — src/adapters/ n'est pas testé, et
## les trois commandes de vérification ne regardent pas l'écran. Cette capture est donc
## le contrôle principal du jalon, et non un supplément.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	# La souris est à (0, 0) dans une session pilotée en ligne de commande : sans ça le
	# survol tomberait hors carte et la capture ne montrerait aucun fantôme.
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_grid.size() / 2))
	# Ce que Tab ferait à la main. Sans ce drapeau, aucune capture ne montrerait un
	# bâtiment pivoté, donc rien ne le vérifierait — c'est le même raisonnement que
	# --shot-hover pour la surbrillance.
	_turns = DevShot.argument(DevShot.SHOT_ROTATE_FLAG).to_int()
	var turns := DevShot.argument(DevShot.SHOT_TURNS_FLAG).to_int()
	if turns != 0:
		_world.rig().rotate_steps(turns)
		var seconds: float = GameDatabase.get_balance().camera.rotation_seconds
		await get_tree().create_timer(seconds).timeout
	# Les images d'échauffement servent ici doublement : le tampon d'instances est
	# téléversé, et le fantôme, qui se construit dans _process, suit la cellule qu'on
	# vient de désigner à la main.
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	var camera := _world.rig().get_camera()
	print("[city_harness] cadrage : camera.size = %.3f, viewport = %s"
		% [camera.size, get_viewport().get_visible_rect().size])
	print("[city_harness] %s" % _hover_line())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[city_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

func _make_label() -> Label:
	var label := Label.new()
	label.name = "CityReport"
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
