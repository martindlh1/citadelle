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
##
## Le ciel, le soleil, la caméra, le rendu du relief et le survol sont montés par
## DevWorld depuis C2 : le harnais Construction en avait besoin à l'identique, et un
## soleil réglé une fois ne doit pas exister en double. Ne reste ici que ce qui est
## propre au Terrain — les décomptes, le seed, la capture et sa sonde.

## Seed de départ. Espace donne FIRST_SEED + 1, puis + 2, etc.
const FIRST_SEED := 1234

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

## Épaisseur du contour du texte. Sans lui le rapport devient illisible dès qu'il
## passe au-dessus d'une zone claire du terrain.
const REPORT_OUTLINE_SIZE := 4

## Largeur de l'histogramme des altitudes, en caractères.
const HISTOGRAM_WIDTH := 30

## Rappel des touches, en pied du rapport. Constante parce que le rapport se
## reconstruit à chaque image depuis que le survol y figure.
const CONTROLS := """Espace : seed suivant.   Q/E : tourner.   Molette : zoom.
Flèches ou WASD, clic milieu : déplacer.   R : recadrer."""

var _metrics: TerrainMetrics
var _world: DevWorld
var _label: Label
var _grid: HeightGrid
var _report_body: String
var _seed := FIRST_SEED

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	if DevShot.has_flag(DevShot.SURVEY_FLAG):
		_write_survey()
		return
	var grid := _generate(FIRST_SEED)
	_world = DevWorld.create(grid, _metrics, balance)
	add_child(_world)
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

## Montre cette grille : le plateau la redessine, le harnais réécrit son rapport.
func _show(grid: HeightGrid) -> void:
	_grid = grid
	_world.show_grid(grid)
	_publish(grid)

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
	lines.append("plaine %d..%d, plateau à %d, nappe à %d, enjambée %d" % [
		params.lowland_height, params.lowland_ceiling(), params.plateau_height,
		params.water_level, params.max_climb])
	lines.append("")
	lines.append(_audit_block(grid, params))
	lines.append("")
	lines.append(_terrain_tally(grid))
	lines.append("")
	lines.append(_height_tally(grid))
	return "\n".join(lines)

## Ce que l'audit dit de cette carte, et les cols qu'il a trouvés.
##
## Les entrées sont nommées en clair : c'est la seule ligne de tout le projet qui désigne un
## **col**, et le mot n'a de sens qu'attaché à des cases. Une carte s'y relit — on va voir
## si ces cases-là sont bien les rampes qu'on voit à l'écran.
func _audit_block(grid: HeightGrid, params: TerrainGenBalance) -> String:
	var report := MapAudit.inspect(grid.to_query(),
		TerrainGen.centre_of(grid.size()), params.max_climb)
	var lines := PackedStringArray()
	lines.append("Audit")
	lines.append("  plateau  %4d cases dont %d bâtissables, %d gisement(s)"
		% [report.shelf(), report.plateau(), report.deposits()])
	lines.append("  accès    %4d   %s" % [report.accesses(), report.entries()])
	lines.append("  assises  %4d   lisière à %d pas" % [report.pads(), report.edge_distance()])
	var missing := MapAudit.shortcomings(report, params)
	lines.append("  promesses %s" % ("tenues" if missing.is_empty()
		else "MANQUÉES : %s" % ", ".join(missing)))
	return "\n".join(lines)

## Ce que le curseur désigne, en une ligne.
##
## Le point d'impact y figure en toutes lettres : c'est le seul endroit où l'on voit
## si le picker raconte la même histoire que ce qui est à l'écran. Un décalage d'une
## cellule entre la marque et ces coordonnées se lit tout de suite.
func _hover_line() -> String:
	var result := _world.cursor().hovered()
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

# --- la revue de seeds ------------------------------------------------------

## Nombre de seeds parcourus par `--survey`. Celui que DESIGN.md 3.1 nomme.
const SURVEY_SEEDS := 200

## Accès énumérés dans l'histogramme avant qu'une colonne ne ramasse le reste.
const SURVEY_ACCESS_BUCKETS := 7

## Génère beaucoup de cartes sans écran et imprime ce qu'elles valent.
##
## **Ce que cette table doit montrer** : que la structure de `T4` tient ses promesses sur
## autre chose qu'un seed bien choisi, et **à quel prix**. Une promesse que rien ne rejette
## jamais est un seuil trop lâche — elle ne protège de rien ; une promesse qui rejette la
## moitié des brouillons est soit trop serrée, soit le signe que la structure ne fait pas ce
## qu'on croit. C'est la colonne des rejets qui porte le jalon, pas les moyennes.
##
## **Ce qu'elle ne montre pas** : si une carte est *agréable* à jouer. Aucun chiffre ici ne
## dit qu'un col est au bon endroit ni qu'un plateau a une forme intéressante — ça se regarde
## en capture, une carte à la fois. La table dit qu'une carte est **jouable**, ce qui est le
## plancher et non l'objectif.
##
## **Elle mesure les brouillons, pas les cartes retenues**, et c'est délibéré : une
## distribution prise après rejet serait bonne par construction, donc muette. Les deux
## dernières lignes disent séparément ce que le jeu reçoit — combien d'essais il faut, et
## si un seed a fini par ne rien rendre du tout.
func _write_survey() -> void:
	# La revue ne monte ni plateau ni caméra, et `quit()` ne prend effet qu'en fin d'image :
	# sans ce coupe-circuit, `_process` tourne une fois sur un monde qui n'existe pas et
	# noie la table sous deux erreurs de script.
	set_process(false)
	var params := GameDatabase.get_balance().terrain_gen
	var size := params.map_size
	var centre := TerrainGen.centre_of(size)
	print("[terrain_harness] revue de %d seeds — %d x %d, plateau à %d sur une plaine %d..%d"
		% [SURVEY_SEEDS, size.x, size.y, params.plateau_height, params.lowland_height,
			params.lowland_ceiling()])
	print("  Les chiffres portent sur les BROUILLONS, avant tout rejet : une distribution")
	print("  mesurée après rejet serait bonne par construction, donc sans intérêt.")

	var accesses: Dictionary[int, int] = {}
	var plateaus: Array[int] = []
	var pads: Array[int] = []
	var deposits: Array[int] = []
	var depths: Array[int] = []
	var refusals: Dictionary[String, int] = {}
	var refused := 0
	for index in SURVEY_SEEDS:
		var run_seed := FIRST_SEED + index
		var grid := TerrainGen.draft(TerrainGen.seed_for(run_seed, 0), size, params)
		var report := MapAudit.inspect(grid.to_query(), centre, params.max_climb)
		accesses[report.accesses()] = accesses.get(report.accesses(), 0) + 1
		plateaus.append(report.plateau())
		pads.append(report.pads())
		deposits.append(report.deposits())
		depths.append(report.edge_distance())
		var missing := MapAudit.shortcomings(report, params)
		if missing.is_empty():
			continue
		refused += 1
		for reason in missing:
			refusals[reason] = refusals.get(reason, 0) + 1

	print("  accès      %s" % _access_histogram(accesses))
	print("  plateau    %s cases bâtissables" % _spread(plateaus))
	print("  assises    %s emplacements 2x2" % _spread(pads))
	print("  gisements  %s sur le plateau" % _spread(deposits))
	print("  lisière    %s pas jusqu'au plateau (−1 : plateau injoignable)" % _spread(depths))
	print("  rejets     %d/%d brouillons — %s"
		% [refused, SURVEY_SEEDS, _refusal_tally(refusals)])
	_survey_the_kept(params, size)
	print("[terrain_harness] la table dit que les cartes sont jouables, pas qu'elles sont")
	print("[terrain_harness] bonnes — ça se regarde en capture, une carte à la fois.")
	get_tree().quit(OK)

## Ce que le jeu reçoit vraiment : combien d'essais coûte une carte, et s'il en manque.
##
## Le compte vient de `TerrainGen.accepted_attempt()`, c'est-à-dire de **la boucle que
## `generate()` emprunte**, et non d'une copie écrite ici. Une boucle recopiée aurait mesuré
## la copie, ce qui est le raccourci que `CLAUDE.md` nomme depuis `F1` — et sous sa forme la
## plus perfide, puisque les deux auraient été justes le jour où on les a écrites.
func _survey_the_kept(params: TerrainGenBalance, size: Vector2i) -> void:
	var spent := 0
	var worst := 0
	var lost := 0
	for index in SURVEY_SEEDS:
		var attempt := TerrainGen.accepted_attempt(FIRST_SEED + index, size, params)
		if attempt < 0:
			lost += 1
			continue
		spent += attempt + 1
		worst = maxi(worst, attempt + 1)
	var kept := SURVEY_SEEDS - lost
	print("  retenues   %d/%d seeds, %.2f essai(s) en moyenne, %d au pire"
		% [kept, SURVEY_SEEDS, float(spent) / float(maxi(kept, 1)), worst])

## Combien de cartes par nombre d'accès, avec la borne des promesses en clair.
func _access_histogram(counts: Dictionary[int, int]) -> String:
	var parts := PackedStringArray()
	var tail := 0
	for value in counts:
		if value >= SURVEY_ACCESS_BUCKETS:
			tail += counts[value]
	for value in SURVEY_ACCESS_BUCKETS:
		parts.append("%d:%d" % [value, counts.get(value, 0)])
	if tail > 0:
		parts.append("%d+:%d" % [SURVEY_ACCESS_BUCKETS, tail])
	return "  ".join(parts)

## Le plus bas, la médiane et le plus haut d'une série. Copie triée : l'appelant garde
## la sienne dans l'ordre où il l'a remplie.
func _spread(values: Array[int]) -> String:
	if values.is_empty():
		return "—"
	var sorted := values.duplicate()
	sorted.sort()
	return "min %4d  méd %4d  max %4d" % [sorted[0], sorted[sorted.size() / 2],
		sorted[sorted.size() - 1]]

## Les motifs de rejet, du plus fréquent au moins fréquent.
##
## Par motif et non en total, parce que c'est le **nom** qui sert : « deposits, deposits,
## deposits » désigne le chiffre à tourner, là où « onze rejets » ne désigne rien.
func _refusal_tally(refusals: Dictionary[String, int]) -> String:
	if refusals.is_empty():
		return "aucun"
	var reasons: Array[String] = []
	reasons.assign(refusals.keys())
	reasons.sort_custom(func(first: String, second: String) -> bool:
		if refusals[first] != refusals[second]:
			return refusals[first] > refusals[second]
		return first < second)
	var parts := PackedStringArray()
	for reason in reasons:
		parts.append("%s %d" % [reason, refusals[reason]])
	return ", ".join(parts)

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
	var path := DevShot.path()
	if path.is_empty():
		return
	# La souris est à (0, 0) dans une session pilotée en ligne de commande, donc le
	# survol réel tomberait hors de la carte. On coupe l'input du curseur et on désigne
	# une cellule à la main : sans ça, aucune capture ne montrerait la surbrillance, et
	# c'est justement ce qu'on cherche à regarder.
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_grid.size() / 2))
	var turns := DevShot.argument(DevShot.SHOT_TURNS_FLAG).to_int()
	if turns != 0:
		_world.rig().rotate_steps(turns)
		var seconds: float = GameDatabase.get_balance().camera.rotation_seconds
		await get_tree().create_timer(seconds).timeout
	for _frame in DevShot.WARMUP_FRAMES:
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
	var expected := _world.cursor().hovered()
	if not expected.is_hit():
		print("[terrain_harness] sonde caméra : rien de survolé, contrôle sauté")
		return
	var camera := _world.rig().get_camera()
	# Le zoom et le viewport en toutes lettres : sans eux, deux captures d'apparence
	# différente ne se départagent pas — un cadrage qui a bougé et une fenêtre qui a
	# changé de taille produisent la même impression à l'oeil.
	print("[terrain_harness] cadrage : camera.size = %.3f, viewport = %s"
		% [camera.size, get_viewport().get_visible_rect().size])
	var screen := camera.unproject_position(expected.position())
	var probed := CellPicker.pick(_grid, _metrics,
		camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	var landed := str(probed.cell()) if probed.is_hit() else "rien"
	var agreed := probed.is_hit() and probed.cell() == expected.cell()
	print("[terrain_harness] sonde caméra : écran %s -> %s, attendu %s : %s"
		% [screen.round(), landed, expected.cell(), "OK" if agreed else "DÉSACCORD"])

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
