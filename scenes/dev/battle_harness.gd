extends Node
## Harnais de dev du système Combat — jalon `F3a` : la bataille, jouée à la souris.
##
## **On y joue les deux camps.** Il n'y a pas encore d'IA — c'est `F2b` —, et c'est
## précisément ce qui rend ce harnais utile : jouer la vague à la main est la seule façon de
## sentir le format avant que quelqu'un décide à sa place, et ce sera le banc d'essai de
## l'IA le jour où elle existera. On pourra rejouer le même plateau des deux façons.
##
## Il remplace le damier ASCII de `F2a`, qui a servi à ce pour quoi il était fait — trouver
## deux défauts en une soirée — et que la vue rend illisible par comparaison. Le pavé de
## texte **perd ce que l'image montre** plutôt que de le doubler : plus de damier, plus de
## carte des coûts, plus d'échange scripté. Il garde ce qu'une image ne dit pas — les
## réglages, le catalogue, la mesure du blocage — comme `E2`, `W2`, `P1b` et `P2a` avant lui.
##
## Le relief, le Cœur et les bâtiments viennent d'un vrai `RunState`, seed fixé : la question
## porte sur un terrain qu'on n'a pas choisi. Les ouvriers et la vague sont fabriqués.
##
## Ce qu'il ne fait pas : rien du run. La bataille ne se déclenche pas à la fermeture d'une
## journée et ne rend aucun `DamageReport` — c'est `F3b`, et il attend `F2b`.

## Prénoms des défenseurs. Inventés et codés en dur, comme aux harnais Effectifs et Combat.
const GIVEN_NAMES: PackedStringArray = [
	"Alaric", "Brenne", "Cadoc", "Doria", "Elric", "Fenn",
]

## Bâtiments posés autour du Cœur. Le dernier reste **en chantier**, pour qu'on voie les
## deux états et qu'il y ait quelque chose à interrompre.
const VILLAGE: Array[StringName] = [
	&"lumberjack_hut", &"farm", &"palisade", &"palisade", &"warehouse",
]

## Vague de mesure, prise dans `data/waves/`.
##
## Elle était codée en dur jusqu'à `F2b` : une liste d'identifiants d'assaillants, écrite
## dans le harnais. Une `WaveDef` dit désormais qui vient **et** combien de manches il faut
## tenir, et un harnais qui composerait la sienne mesurerait autre chose que ce que le jeu
## enverra.
const WAVE := &"raid"

## Côté par lequel la vague arrive. Un argument tant que `F3b` n'aura pas dit d'où il vient.
const FROM_SIDE := Vector2i(0, -1)

## Seed du run et de la bataille. Fixé, sans quoi deux lancements donneraient deux reliefs.
const SEED := 4413

## Teinte des cases où le corps tenu peut aller. Bleue comme son camp, et très translucide :
## on doit lire le relief à travers, puisque c'est lui qui explique le coût.
const REACH_COLOR := Color(0.40, 0.66, 0.95, 0.26)

## Teinte des cases qu'il peut frapper. Rouge, et **nettement plus dense** que la
## précédente : là où les deux se superposent, c'est la menace qui doit se lire, parce que
## c'est elle qui coûte un tour si on se trompe.
##
## L'opacité vient d'une capture et non d'un goût. À 0,34 elle tenait pour un archer, dont la
## portée couvre vingt-quatre cases, et **disparaissait pour un corps-à-corps**, qui n'en a
## que quatre — c'est-à-dire qu'elle s'effaçait exactement pour le cas le plus fréquent. Une
## surface deux fois plus petite a besoin d'être deux fois plus franche pour se voir autant.
const STRIKE_COLOR := Color(0.95, 0.30, 0.24, 0.55)

## Décollement du voile rouge au-dessus du bleu, en fractions de tuile.
const STRIKE_LIFT := 0.012

const HELP_KEY := KEY_H
const NEW_BATTLE_KEY := KEY_N
## Cases de dégagement autour du champ de bataille au cadrage.
const FRAME := 2

const PANEL_MARGIN := 14
const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13

var _wave: WaveDef
var _combat: CombatBalance
var _workforce: WorkforceBalance
var _grid: HeightGrid
var _metrics: TerrainMetrics
var _state: RunState
var _board: CombatBoard
var _world: DevWorld
var _bodies: BodyRenderer
var _buildings: BuildingRenderer
var _reach: TargetHighlight
var _strike: TargetHighlight
var _panel: CombatPanel
var _report: Label

## Corps tenu, ou vide. C'est un état de **jeu** et non d'affichage, donc il vit ici et non
## dans le panneau — même partage qu'`AssignmentPanel` depuis `P1a`.
var _held: StringName

## Identifiant de corps -> teinte de son pion, et -> nom affiché.
##
## Deux tables tenues par le harnais parce que lui seul sait quel `EnemyData` il a envoyé.
## Le plateau ne porte que des chiffres, et lui faire porter une couleur ou un prénom
## mettrait de l'affichage dans le domaine.
var _tints: Dictionary[StringName, Color] = {}
var _names: Dictionary[StringName, String] = {}

## Cases de la carte triées par distance au Cœur, calculées une fois.
var _spiral: Array[Vector2i] = []

var _lines := PackedStringArray()

## Les seules lignes affichées par défaut : ce sur quoi appuyer.
##
## Le reste part sur la **sortie standard** et n'apparaît qu'à la touche `H`. La première
## capture a montré pourquoi : le rapport entier couvrait les deux tiers du champ, ce qui est
## exactement ce qu'un jalon d'écran ne doit pas faire. Une table se lit dans un terminal, un
## champ de bataille se regarde.
var _keys := PackedStringArray()
var _help_open := false

## Ce que chaque voile porte, en cases.
##
## Deux compteurs de débogage, et ils existent pour la raison que `P1b` a payée une heure :
## sonder un PNG pour savoir si un voile est dessiné rend un doute, pas un chiffre. Cinq
## lignes le rendent dans le bon repère, et il sort désormais sur **toutes** les captures.
var _reach_count := 0
var _strike_count := 0

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_wave = GameDatabase.get_wave(WAVE)
	_combat = balance.combat
	_workforce = balance.workforce
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	_state = _open_run(balance)
	_board = _open_board()

	_world = DevWorld.create(_grid, _metrics, balance)
	add_child(_world)
	_world.light_day(0.35)
	_frame_battle()
	_buildings = BuildingRenderer.create(_state.city(), _metrics)
	add_child(_buildings)
	_reach = TargetHighlight.create(_metrics, REACH_COLOR)
	_reach.name = "ReachHighlight"
	add_child(_reach)
	_strike = TargetHighlight.create(_metrics, STRIKE_COLOR)
	_strike.name = "StrikeHighlight"
	# Un cran au-dessus du voile bleu, sans quoi les deux se disputent le même Y sur toutes
	# les cases qui sont à la fois atteignables et frappables — c'est-à-dire les voisines,
	# donc les seules qui comptent. Trouvé en capture : le rouge y disparaissait par plaques.
	_strike.position.y = _metrics.tile_size() * STRIKE_LIFT
	add_child(_strike)
	_bodies = BodyRenderer.create(_metrics)
	add_child(_bodies)

	_panel = CombatPanel.create()
	_panel.body_picked.connect(_on_body_picked)
	_panel.turn_ended.connect(_end_turn)
	add_child(_make_panel_slot(_panel))

	_report = _make_report()
	add_child(_report)
	_refresh()
	_capture_if_asked()

## Le clavier et la souris.
##
## Le clic gauche **sélectionne ou déplace**, dans cet ordre : cliquer un corps de son camp
## le prend, cliquer une case atteignable y va. L'ordre compte — sans lui, cliquer un
## coéquipier au contact échouerait à le sélectionner au lieu de le prendre.
##
## Le clic droit **frappe**, et il est libre : le rig de caméra emploie la molette, le
## bouton du milieu et Q/E/R, donc rien ne se dispute avec lui.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		_click_left(hovered.cell())
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		_click_right(hovered.cell())

func _handle_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	match key.keycode:
		HELP_KEY:
			_help_open = not _help_open
			_report.text = "\n".join(_lines if _help_open else _keys)
		NEW_BATTLE_KEY:
			_board = _open_board()
			_held = &""
			_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			_end_turn()
		_:
			return
	get_viewport().set_input_as_handled()

## Prendre un corps, ou l'emmener.
func _click_left(cell: Vector2i) -> void:
	var standing := _board.body_at(cell)
	if standing != null and standing.side() == _board.side():
		_on_body_picked(standing.id())
		return
	if _held.is_empty():
		return
	_announce(_board.move(_held, cell).reason(), "déplacement")
	_refresh()

## Frapper une case, quoi qu'il y ait dessus.
func _click_right(cell: Vector2i) -> void:
	if _held.is_empty():
		return
	var hit := _board.strike(_held, cell)
	if hit.is_ok():
		print("[battle] %s" % _tell(hit))
	else:
		_announce(hit.reason(), "coup")
	_refresh()

func _on_body_picked(body: StringName) -> void:
	_held = &"" if body == _held else body
	_refresh()

func _end_turn() -> void:
	_board.end_turn()
	_held = &""
	_refresh()

## Redessine tout ce qui dépend du plateau.
##
## Une seule porte, appelée après **chaque** geste. C'est ce qui évite d'avoir à énumérer
## les gestes qui touchent chaque vue — un oubli dans cette liste se lit comme un compteur
## qui ne bouge pas, et `CLAUDE.md` en a fait une règle à `E2`.
func _refresh() -> void:
	_bodies.rebuild(_board, _tints)
	_buildings.rebuild(_state.city(), _board.wrecked())
	if _held.is_empty() or not _board.has_body(_held) or _board.body(_held).is_down():
		_held = &""
		_reach.clear()
		_strike.clear()
		_reach_count = 0
		_strike_count = 0
	else:
		var piece := _board.body(_held)
		_show(_reach, [] if piece.has_moved() else _board.reachable(_held).keys())
		_show(_strike, [] if piece.has_struck() else _board.strikeable(_held))
	_panel.show_board(_board, _held, _names)

## Allume ces cases sur cette couche, chacune à la hauteur de son relief.
##
## Une case dont le geste est déjà dépensé ne s'allume pas : `CLAUDE.md` pose depuis `I2b`
## qu'une vue qui invite à un geste doit demander si le geste est possible, et un voile qui
## resterait après le coup promettrait un second coup qui n'arrivera pas.
func _show(layer: TargetHighlight, cells: Array) -> void:
	if layer == _reach:
		_reach_count = cells.size()
	else:
		_strike_count = cells.size()
	var targets: Array[Vector2i] = []
	var heights := PackedInt32Array()
	for cell in cells:
		targets.append(cell)
		heights.append(_board.terrain().height_at(cell))
	layer.show_targets(targets, heights)

## Dit pourquoi un geste a été refusé, ou rien s'il ne l'a pas été.
##
## Sur la sortie standard et non à l'écran : un refus est le régime normal d'un curseur
## promené sur une carte, et l'afficher ferait clignoter un message à chaque clic à côté.
## Les deux refus qui comptent se voient de toute façon — une case non allumée est une case
## où l'on ne peut pas aller.
func _announce(reason: StringName, what: String) -> void:
	if reason.is_empty():
		return
	print("[battle] %s refusé : %s" % [what, reason])

## Ce qu'un coup a fait, en une phrase.
func _tell(hit: StrikeResult) -> String:
	if hit.hit() == StrikeResult.Hit.NOTHING:
		return "coup dans le vide en %s" % hit.cell()
	var what := _name_of(hit.body()) if hit.hit() == StrikeResult.Hit.BODY \
		else "le bâti en %s" % hit.anchor()
	return "%d sur %s%s" % [hit.damage(), what, ", il tombe" if hit.felled() else ""]

# --- le pavé de texte -------------------------------------------------------------------

## Ce que l'image ne dit pas.
##
## Trois blocs seulement, et chacun a passé le test que `F2a` a appliqué à ses tables :
## est-ce qu'une image le montrerait ? Les réglages, non — ce sont des chiffres. Le
## catalogue, non — on ne voit pas la portée d'un archer, on la subit. La mesure du blocage,
## non plus : on voit un corps barrer un passage, on ne voit pas **combien** il retire.
func _build_report() -> void:
	_keys.append("Clic gauche : prendre un corps, ou l'emmener sur une case bleue")
	_keys.append("Clic droit  : frapper une case rouge, quoi qu'il y ait dessus")
	_keys.append("Entrée : finir le tour   N : nouvelle bataille   H : les chiffres")
	_keys.append("Q/E : pivoter   molette : zoom   clic milieu : déplacer   R : recadrer")
	_lines.append("Citadelle — harnais Bataille (F3a)")
	_lines.append("")
	for line in _keys:
		_lines.append(line)
	_lines.append("")
	_lines.append("Profil d'un ouvrier engagé, de data/balance/combat_balance.tres")
	_lines.append("  %d PV, %d–%d de dégâts, portée %d, %d de déplacement, marche de %d"
		% [_combat.fighter_hit_points, _combat.fighter_damage_min,
			_combat.fighter_damage_max, _combat.fighter_reach, _combat.fighter_move,
			_combat.fighter_climb])
	_lines.append("  un cran de montée coûte %d ; infranchissable : %s"
		% [_combat.climb_cost, ", ".join(_tag_names())])
	_lines.append("  la vague entre à %d case(s) de la lisière" % _combat.spawn_margin)
	_lines.append("")
	_lines.append("Assaillants de data/enemies/")
	_lines.append("  %-12s %4s %7s %6s %6s %6s" % ["type", "PV", "dégâts", "port.",
		"dépl.", "marche"])
	for id in GameDatabase.list_enemy_ids():
		var enemy := GameDatabase.get_enemy(id)
		_lines.append("  %-12s %4d %7s %6d %6d %6d" % [enemy.label, enemy.hit_points,
			"%d–%d" % [enemy.damage_min, enemy.damage_max], enemy.reach, enemy.move,
			enemy.climb])
	_lines.append("")
	_report_blocking()
	_report_verdict()

## Ce qu'un corps interposé retire.
##
## La seule tactique que `F2a` livre, et la seule table que la vue ne remplace pas : on
## **voit** un corps barrer un passage, on ne voit pas combien de cases il retire.
##
## Elle mesure en posant vraiment un corps plutôt qu'en barrant une case à la main : un
## obstacle simulé mesurerait le simulateur.
func _report_blocking() -> void:
	var who := _first_of(Combatant.Side.FRIEND)
	var wall := _first_of(Combatant.Side.FOE)
	if who == null or wall == null:
		return
	var blocked := _open_board()
	var step := _toward(who.cell(), wall.cell())
	if not blocked.can_stand(step):
		return
	blocked.send(&"blocker", GameDatabase.get_enemy(_wave.roster[0]), step)
	_lines.append("Ce qu'un corps interposé retire — un assaillant posé en %s" % step)
	_lines.append("  %-28s %6s %8s" % ["plateau", "cases", "sorties"])
	_lines.append("  %-28s %6d %8d" % ["dégagé", _board.reachable(who.id()).size(),
		_exits(_board, who)])
	_lines.append("  %-28s %6d %8d" % ["un corps sur le passage",
		blocked.reachable(who.id()).size(), _exits(blocked, who)])
	_lines.append("")
	_lines.append("  La colonne « sorties » se prend sur le voisinage et non sur le")
	_lines.append("  parcours : deux colonnes tirées du même compteur ne prouvent rien en")
	_lines.append("  se ressemblant. Une sortie unique dit qu'on tient une porte.")
	_lines.append("")

func _report_verdict() -> void:
	_lines.append("Ce que cet écran doit montrer")
	_lines.append("  — un corps pris allume deux voiles distincts : où il va en bleu, ce")
	_lines.append("    qu'il frappe en rouge, et le rouge doit se lire par-dessus ;")
	_lines.append("  — les coûts ne se voient pas, mais leur effet si : un voile bleu")
	_lines.append("    parfaitement carré dirait que le relief ne joue pas ;")
	_lines.append("  — un voile s'éteint quand son geste est dépensé, sinon l'écran promet")
	_lines.append("    un second coup qui n'arrivera pas ;")
	_lines.append("  — les deux camps se distinguent par la forme et pas seulement par la")
	_lines.append("    teinte, sinon un pion à l'ombre devient indéchiffrable.")
	_lines.append("")
	_lines.append("Ce que F3a ne dit pas : ce que les assaillants décident (F2b), quand la")
	_lines.append("vague repart (F2b), ni comment une bataille s'ouvre depuis une journée")
	_lines.append("qui se ferme (F3b). Ici on joue les deux camps à la main, exprès.")

# --- capture ----------------------------------------------------------------------------

## `src/adapters/` n'est pas testé et les trois commandes ne regardent pas l'écran : cette
## capture est le contrôle principal du jalon, et non un supplément.
##
## Deux drapeaux lui sont propres, tous deux par la porte habituelle — **un état qu'aucune
## capture ne peut atteindre est celui que personne ne regardera.** Les voiles ne s'allument
## qu'après un clic sur une fiche, et le tour de la vague ne s'obtient que par un geste.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	if DevShot.has_flag(DevShot.SHOT_FOES_FLAG):
		_end_turn()
	var rank := DevShot.argument(DevShot.SHOT_SELECT_FLAG)
	if not rank.is_empty():
		var camp := _board.standing(_board.side())
		if not camp.is_empty():
			_on_body_picked(camp[clampi(rank.to_int(), 0, camp.size() - 1)].id())
	# La souris est à (0, 0) dans une session pilotée en ligne de commande : sans ça le
	# survol tomberait hors carte et la capture ne montrerait aucune marque de cellule.
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_held_cell()))
	var turns := DevShot.argument(DevShot.SHOT_TURNS_FLAG).to_int()
	if turns != 0:
		_world.rig().rotate_steps(turns)
		await get_tree().create_timer(
			GameDatabase.get_balance().camera.rotation_seconds).timeout
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[battle_harness] manche %d, camp %s, tenu : %s"
		% [_board.round_number(),
			"ouvriers" if _board.side() == Combatant.Side.FRIEND else "vague",
			_held if not _held.is_empty() else "aucun"])
	print("[battle_harness] voiles : %d case(s) atteignable(s), %d frappable(s)"
		% [_reach_count, _strike_count])
	print("[battle_harness] panneau en %s, %.0f x %.0f"
		% [_panel.global_position, _panel.size.x, _panel.size.y])
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[battle_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Cadre la caméra sur le champ de bataille, et non sur la carte.
##
## `DevWorld` cadre la grille entière, ce qui est juste pour les harnais qui la regardent
## toute — et illisible ici : une bataille tient dans une dizaine de cases au milieu d'un
## 32×32, donc les pions y font trois pixels. C'est la première chose que la capture a dite.
##
## Le cadre est le bâti **plus la marge d'entrée**, de sorte que la vague soit dedans dès la
## première image : un cadrage qui la laisserait dehors ferait croire qu'elle n'est pas
## arrivée. `DESIGN.md` 3.6 veut que « la caméra zoome sur le côté attaqué » ; ceci en est la
## moitié qui ne demande aucune décision, et `R` y revient toujours.
func _frame_battle() -> void:
	var area := BattleGround.built_area(_board.city()).grow(_combat.spawn_margin + FRAME)
	var tile := _metrics.tile_size()
	_world.rig().frame(
		Vector3((area.position.x + area.size.x * 0.5) * tile, 0.0,
			(area.position.y + area.size.y * 0.5) * tile),
		Vector2(area.size) * tile)

## La case du corps tenu, ou le centre du bâti à défaut.
func _held_cell() -> Vector2i:
	if not _held.is_empty() and _board.has_body(_held):
		return _board.body(_held).cell()
	return BattleGround.built_area(_board.city()).get_center()

# --- fabrique ---------------------------------------------------------------------------

## Ouvre le plateau : les défenseurs sur leur poste, la vague à la lisière.
##
## Le déploiement passe par `InstantCombatResolver.deploy()`, la règle de `F1` employée
## comme **bouton par défaut**, ce que `DESIGN.md` 3.6 annonçait mot pour mot.
func _open_board() -> CombatBoard:
	var city := _state.city().to_snapshot()
	var force := _state.roster().to_combat(_combat.combat_skill_family, _workforce, _combat)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var board := CombatBoard.open(_state.terrain(), city, _combat, rng, _wave.rounds)
	_tints.clear()
	_names.clear()
	var line := InstantCombatResolver.deploy(force,
		InstantCombatResolver.slots_for(city, _combat))
	var posts := BattleGround.landing_cells(board, FROM_SIDE, line.size())
	for rank in mini(line.size(), posts.size()):
		board.deploy(force.unit(line[rank]), posts[rank])
		_tints[line[rank]] = BodyRenderer.FRIEND_COLOR
		_names[line[rank]] = _state.roster().worker(line[rank]).given_name()
	var roster := _wave.roster
	var gates := BattleGround.entry_cells(board, FROM_SIDE, roster.size())
	for rank in mini(roster.size(), gates.size()):
		var enemy := GameDatabase.get_enemy(roster[rank])
		var id := StringName("%s_%d" % [roster[rank], rank])
		board.send(id, enemy, gates[rank])
		_tints[id] = enemy.color
		_names[id] = "%s %d" % [enemy.label, rank + 1]
	return board

## Ouvre un vrai run, le fonde, et lui bâtit un village autour du Cœur.
##
## La fondation n'est pas un détail de mise en scène : sans elle la ville est vide, les
## bâtiments se posent où le balayage commence — en bande contre le bord haut —, et une
## vague qui arrive du nord n'a **aucune** case où entrer. Trouvé à `F2a`, par une table qui
## a annoncé qu'elle n'avait rien à montrer.
func _open_run(balance: BalanceData) -> RunState:
	_grid = TerrainGen.generate(SEED, balance.terrain_gen.map_size, balance.terrain_gen)
	var state := RunState.open(SEED, _grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance)
	RunOrchestrator.found(state, state.suggested_heart_anchor())
	for id in VILLAGE:
		_raise(state, GameDatabase.get_building(id))
	return state

## Pose ce bâtiment sur l'ancre libre la plus proche du Cœur et le mène à son dernier cran,
## sauf le dernier de la liste — laissé **en chantier**.
func _raise(state: RunState, data: BuildingData) -> void:
	for anchor in _rings(state):
		if not state.city().place(state.terrain(), data, anchor).is_ok():
			continue
		if data.id == VILLAGE[VILLAGE.size() - 1]:
			return
		while not state.city().building_at(anchor).is_complete():
			state.city().advance(anchor)
		return

## Les cases de la carte, du Cœur vers les bords. Même ordre que
## `RunState.suggested_heart_anchor()` emploie pour le Cœur lui-même.
func _rings(state: RunState) -> Array[Vector2i]:
	if not _spiral.is_empty():
		return _spiral
	var heart := state.heart_anchor()
	var extent := state.terrain().size()
	for y in extent.y:
		for x in extent.x:
			_spiral.append(Vector2i(x, y))
	_spiral.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var near := (first - heart).length_squared()
		var far := (second - heart).length_squared()
		if near != far:
			return near < far
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	return _spiral

func _first_of(camp: Combatant.Side) -> Combatant:
	var upright := _board.standing(camp)
	return null if upright.is_empty() else upright[0]

## Les cases voisines où ce corps peut poser le pied, sur ce plateau.
##
## Prise sur le **voisinage** et non sur le parcours, par la règle de `I2b` : une colonne
## qui doit corroborer une autre se prend ailleurs, sinon leur accord est une tautologie.
func _exits(board: CombatBoard, piece: Combatant) -> int:
	var open := 0
	for step in CombatMovement.NEIGHBOURS:
		var cell: Vector2i = piece.cell() + step
		if not board.can_stand(cell):
			continue
		if CombatMovement.step_cost(board.terrain(), piece.cell(), cell, piece.stats(),
				_combat) == CombatMovement.BLOCKED:
			continue
		open += 1
	return open

## Le premier pas de `from` vers `to`, en orthogonal.
func _toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if absi(delta.x) > absi(delta.y):
		return from + Vector2i(signi(delta.x), 0)
	return from + Vector2i(0, signi(delta.y))

func _name_of(id: StringName) -> String:
	return _names.get(id, String(id).capitalize())

func _tag_names() -> PackedStringArray:
	var names := PackedStringArray()
	for tag in _combat.impassable_tags:
		names.append(String(tag))
	return names

func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	for id in GameDatabase.list_building_ids():
		table[id] = GameDatabase.get_building(id)
	return table

## Le panneau, calé en haut à droite par un conteneur et jamais par des ancres calculées.
##
## `E2` a payé deux pièges de suite pour cette ligne : `set_anchors_preset()` prend un
## booléen en second argument, et `get_combined_minimum_size()` se lit en retard d'une passe.
## Un `MarginContainer` plein écran dont l'enfant rétrécit vers un coin ne se trompe sur
## aucun des deux.
func _make_panel_slot(panel: Control) -> MarginContainer:
	var slot := MarginContainer.new()
	slot.name = "PanelSlot"
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		slot.add_theme_constant_override("margin_" + side, PANEL_MARGIN)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_child(panel)
	return slot

func _make_report() -> Label:
	_build_report()
	print("\n".join(_lines))
	var label := Label.new()
	label.name = "BattleReport"
	label.text = "\n".join(_keys)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Une vue de lecture laisse passer la souris, pour que le curseur de cellule continue
	# de piocher dessous.
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi les deux tableaux se désalignent.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
