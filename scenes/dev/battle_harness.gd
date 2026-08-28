extends Node
## Harnais de dev du système Combat — jalon `F2a` : le plateau, le relief, et les deux
## verbes.
##
## Un damier **en texte**, et c'est délibéré : la vue de combat est `F3`, et un damier
## qu'on peut lire dans un diff prouve mieux qu'une image ce que le domaine calcule. Le
## harnais `combat` de `F1` reste à côté — il calibre le bouchon, et le bouchon fait encore
## tourner le jeu jusqu'à ce que `F3` l'échange.
##
## Comme les précédents, il **cherche** au lieu de mettre en scène. Quatre questions
## qu'aucune suite de tests ne peut poser, parce qu'elles portent sur les chiffres de
## `data/` et sur un vrai relief plutôt que sur des règles :
##
##   - **où la vague tombe** sur un village qu'on n'a pas dessiné pour elle, et si la marge
##     de `data/balance/` la met à portée de décision ou à quatre tours de marche ;
##   - **ce qu'un relief généré fait d'un déplacement** — si les crans mordent assez pour
##     qu'un détour soit une décision, ou si tout se vaut ;
##   - **ce qu'un corps interposé change**, qui est la seule tactique que `F2a` livre ;
##   - **ce qu'un échange coûte en tours**, c'est-à-dire si la borne de `F2b` aura quelque
##     chose à borner.
##
## Le relief, le Cœur et les bâtiments viennent d'un vrai `RunState` : la question porte
## justement sur un terrain qu'on n'a pas choisi. Les ouvriers et la vague sont fabriqués.
##
## Il n'est **pas** interactif, et c'est un choix plutôt qu'un manque : il n'y a encore
## personne en face. Les intentions et l'IA sont `F2b`, et c'est là qu'un pas-à-pas au
## clavier aura quelque chose à faire jouer.

## Prénoms des défenseurs. Inventés et codés en dur, comme aux harnais Effectifs et
## Combat : un catalogue de prénoms dans `data/` est du contenu, donc `I3`.
const GIVEN_NAMES: PackedStringArray = [
	"Alaric", "Brenne", "Cadoc", "Doria", "Elric", "Fenn",
]

## Bâtiments posés autour du Cœur, dans l'ordre. Le dernier reste **en chantier**, pour que
## le damier montre les deux états et que l'un d'eux se fasse casser.
const VILLAGE: Array[StringName] = [
	&"lumberjack_hut", &"farm", &"palisade", &"palisade", &"warehouse",
]

## Vague de mesure : trois types du catalogue, pour que la table ne parle pas d'un seul
## profil. L'ordre est celui de l'entrée sur le plateau.
const WAVE: Array[StringName] = [&"raider", &"raider", &"brute", &"archer"]

## Côté par lequel la vague arrive. Un argument tant que `F3` n'aura pas dit d'où il vient.
const FROM_SIDE := Vector2i(0, -1)

## Tours de l'échange scripté. Assez pour qu'un mur tombe, pas assez pour lasser.
const EXCHANGE_ROUNDS := 4

## Seed du run de mesure. Fixé, sans quoi deux lancements donneraient deux reliefs et les
## tables ne se compareraient pas d'une session à l'autre.
const SEED := 4413

## Marge de damier autour du bâti, en cases, par-dessus la marge d'entrée de la vague.
const FRAME := 2

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 12

var _combat: CombatBalance
var _workforce: WorkforceBalance
var _state: RunState
var _board: CombatBoard
var _line: Array[StringName] = []
var _lines := PackedStringArray()

## Cases de la carte triées par distance au Cœur, calculées une fois.
var _spiral: Array[Vector2i] = []

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_combat = balance.combat
	_workforce = balance.workforce
	_state = _open_run(balance)
	_board = _open_board()

	_report_opening()
	_report_ground()
	_report_reach()
	_report_blocking()
	_report_exchange()
	_report_verdict()

	var text := "\n".join(_lines)
	print(text)
	add_child(_make_label(text))

func _report_opening() -> void:
	_lines.append("Citadelle — harnais Bataille (F2a)")
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

## Le damier, et où chacun se pose.
##
## La table dit deux choses qu'aucun test ne dit : que la vague tombe **près** du bâti sur
## un relief qu'on n'a pas choisi, et que les défenseurs se posent entre elle et le village.
## Les deux se lisent sur l'image plutôt que sur un chiffre, ce qui est le seul cas de ce
## projet où c'est vrai — une distance se vérifie en la voyant.
func _report_ground() -> void:
	var area := BattleGround.built_area(_board.city())
	_lines.append("Le champ de bataille — village de %d bâtiments, lisière %s"
		% [_board.city().count(), area])
	_lines.append("  chiffre = hauteur du relief, # bâtiment, + chantier, ~ eau, ^ rocher")
	_lines.append("  majuscule = ouvrier engagé, minuscule = assaillant")
	_lines.append("")
	for row in _draw({}):
		_lines.append("  " + row)
	_lines.append("")
	_lines.append("  entrée de la vague : %s" % _cells_of(Combatant.Side.FOE))
	_lines.append("  poste des défenseurs : %s" % _cells_of(Combatant.Side.FRIEND))
	_lines.append("")

## Ce que le relief fait d'un déplacement.
##
## Le damier reprend le même, avec le **coût** de chaque case atteignable à la place du
## décor. Une carte de coûts uniformément égale à la distance dirait que le relief ne joue
## pas ; c'est exactement ce que cette table doit permettre de constater ou d'écarter.
func _report_reach() -> void:
	var who := _first_of(Combatant.Side.FRIEND)
	if who == null:
		_lines.append("Aucun défenseur posé — rien à mesurer.")
		_lines.append("")
		return
	var within := _board.reachable(who.id())
	_lines.append("Ce que %s peut parcourir — %d point(s), marche de %d, depuis %s"
		% [_name_of(who.id()), who.stats().move(), who.stats().climb(), who.cell()])
	_lines.append("  chiffre = coût pour y aller, · hors d'atteinte")
	_lines.append("")
	for row in _draw(within):
		_lines.append("  " + row)
	_lines.append("")
	_lines.append("  %d case(s) atteignables, coût le plus élevé %d, à plat il y en aurait %d"
		% [within.size(), _dearest(within), _flat_count(who.stats().move())])
	_lines.append("")

## Ce qu'un corps interposé change.
##
## La seule tactique que `F2a` livre, et la table la mesure en **posant vraiment** un corps
## plutôt qu'en barrant une case à la main : un obstacle simulé mesurerait le simulateur.
## Les deux lignes doivent différer, sans quoi le blocage ne bloque rien.
func _report_blocking() -> void:
	var who := _first_of(Combatant.Side.FRIEND)
	var wall := _first_of(Combatant.Side.FOE)
	if who == null or wall == null:
		return
	var before := _board.reachable(who.id()).size()
	var blocked := _open_board()
	var step := _toward(who.cell(), wall.cell())
	blocked.send(&"blocker", GameDatabase.get_enemy(WAVE[0]), step)
	_lines.append("Ce qu'un corps interposé retire — un assaillant posé en %s" % step)
	_lines.append("  %-28s %6s %8s" % ["plateau", "cases", "sorties"])
	_lines.append("  %-28s %6d %8d" % ["dégagé", before, _exits(_board, who)])
	_lines.append("  %-28s %6d %8d" % ["un corps sur le passage",
		blocked.reachable(who.id()).size(), _exits(blocked, who)])
	_lines.append("")
	_lines.append("  La colonne « sorties » compte les voisines où ce corps peut poser le")
	_lines.append("  pied. Elle se prend sur le voisinage et non sur le parcours : deux")
	_lines.append("  colonnes tirées du même compteur ne prouvent rien en se ressemblant.")
	_lines.append("  Une sortie unique dit qu'on tient une porte, pas qu'un calcul a raté.")
	_lines.append("")

## Un échange scripté, tour par tour.
##
## Les défenseurs marchent sur la vague et frappent ce qui est au contact ; les assaillants
## font l'inverse. **Ce n'est pas une IA** — c'est un script, et `F2b` écrira la vraie. Ce
## que la table montre est ce qu'un tour coûte en gestes et ce qu'une manche entame, donc
## si la borne de tours de `F2b` aura quelque chose à borner.
func _report_exchange() -> void:
	_lines.append("Un échange de %d manches — script, pas IA" % EXCHANGE_ROUNDS)
	_lines.append("  %-6s %-10s %-22s %s" % ["manche", "camp", "geste", "effet"])
	for pass_index in EXCHANGE_ROUNDS * 2:
		for piece in _board.standing(_board.side()):
			_play(piece)
		_board.end_turn()
	_lines.append("")
	_lines.append("  après %d manches : %d ouvrier(s) debout sur %d, %d assaillant(s) sur %d"
		% [_board.round_number() - 1,
			_board.standing(Combatant.Side.FRIEND).size(), _line.size(),
			_board.standing(Combatant.Side.FOE).size(), WAVE.size()])
	_lines.append("  bâtiments frappés : %d, tombés : %d, dont %d chantier(s)"
		% [_board.damage_taken().size(), _board.wrecked().size(),
			_board.interrupted().size()])
	_lines.append("  pertes : %s" % (", ".join(_names_of(_board.fallen()))
		if not _board.fallen().is_empty() else "aucune"))
	_lines.append("  %s" % _exchange_finding())
	_lines.append("")
	for row in _draw({}):
		_lines.append("  " + row)
	_lines.append("")

## Ce que l'échange vient de montrer, confronté au critère du verdict.
##
## Écrit ici plutôt que laissé à la relecture, parce que le critère est **faux au seed
## courant** : la ligne ne tient pas, elle est balayée. Un verdict qui réclamerait
## « entamer sans tout finir » sous une table qui montre l'inverse serait exactement le
## tableau aligné, plausible et faux que `CLAUDE.md` décrit depuis `F1`.
func _exchange_finding() -> String:
	var held := _board.standing(Combatant.Side.FRIEND).size()
	var raiders := _board.standing(Combatant.Side.FOE).size()
	if held > 0 and raiders > 0:
		return "constat : les deux camps tiennent encore, la borne de F2b aura à borner."
	if held == 0:
		return ("constat : la ligne est balayée — %d contre %d à ces chiffres-là, "
			+ "donc un réglage pour I3 et non une règle.") % [_line.size(), WAVE.size()]
	return "constat : la vague est nettoyée avant la borne — chiffres trop tendres, I3."

func _report_verdict() -> void:
	_lines.append("Ce que ces tables doivent montrer")
	_lines.append("  — la vague doit entrer à portée de décision, pas à quatre tours de")
	_lines.append("    marche : ses cases doivent se voir sur le même damier que le bâti ;")
	_lines.append("  — les coûts de déplacement ne doivent pas tous valoir la distance,")
	_lines.append("    sinon le relief ne joue pas et le terrassement n'est pas militaire ;")
	_lines.append("  — les deux lignes du blocage doivent différer, sinon un corps ne")
	_lines.append("    barre rien et F2a n'a livré aucune tactique ;")
	_lines.append("  — l'échange doit entamer quelque chose sans tout finir, sinon la")
	_lines.append("    borne de tours de F2b n'aura rien à borner.")
	_lines.append("")
	_lines.append("Ce que F2a ne dit pas : ce que les assaillants **décident** (intentions")
	_lines.append("et IA, F2b), quand la vague repart (borne de tours, F2b), ce qu'elle")
	_lines.append("emporte (pillage, F2b), ni ce qu'un survivant garde (X6).")

# --- le script d'échange ----------------------------------------------------------------

## Fait jouer un corps : il avance sur le camp d'en face, puis frappe ce qui est à portée.
##
## Volontairement bête, et le docstring de `_report_exchange()` dit pourquoi. La seule chose
## qu'il partage avec l'IA de `F2b` est de viser une **case** et non une cible.
func _play(piece: Combatant) -> void:
	var goal := _quarry(piece)
	if goal == StrikeResult.NO_ANCHOR:
		return
	if not piece.stats().can_reach(piece.cell(), goal):
		_approach(piece, goal)
	if piece.stats().can_reach(piece.cell(), goal):
		_strike_at(piece, goal)

## Ce que ce corps vise : un adversaire debout, ou le bâti à défaut.
##
## **Le défaut n'existe que pour la vague.** Un ouvrier qui n'a plus personne en face
## n'attaque pas son propre village ; un assaillant qui n'a plus personne mange les murs,
## et c'est la moitié du troc que `DESIGN.md` 3.6 veut — « on garde ses gens, ils mangent
## les murs ».
##
## Ce n'est **pas** la règle de 3.6, qui dit « les ouvriers à portée, les bâtiments sinon »
## et demande de savoir ce qui sera atteignable ce tour-ci. Celle-là est `F2b` ; celle-ci
## est le plus court script qui produise un échange à mesurer.
func _quarry(piece: Combatant) -> Vector2i:
	var prey := _nearest_foe(piece)
	if prey != null:
		return prey.cell()
	if piece.is_friend():
		return StrikeResult.NO_ANCHOR
	return _nearest_wall(piece)

## Avance ce corps aussi près que possible de cette case.
func _approach(piece: Combatant, goal: Vector2i) -> void:
	var best := piece.cell()
	for cell in _board.reachable(piece.id()):
		if _distance(cell, goal) < _distance(best, goal):
			best = cell
	if best == piece.cell():
		return
	_log(piece, "marche vers %s" % best,
		"coût %d" % _board.move(piece.id(), best).cost())

## La case bâtie debout la plus proche de ce corps, ou `NO_ANCHOR` s'il n'en reste aucune.
func _nearest_wall(piece: Combatant) -> Vector2i:
	var best := StrikeResult.NO_ANCHOR
	for building in _board.city().buildings():
		if _board.is_wrecked(building.anchor()):
			continue
		for cell in building.cells():
			if best == StrikeResult.NO_ANCHOR 					or _distance(piece.cell(), cell) < _distance(piece.cell(), best):
				best = cell
	return best

## Frappe cette case et journalise, ou ne fait rien s'il n'y a pas de case.
func _strike_at(piece: Combatant, target: Vector2i) -> void:
	if target == StrikeResult.NO_ANCHOR:
		return
	var hit := _board.strike(piece.id(), target)
	if not hit.is_ok():
		return
	_log(piece, "frappe %s" % target, _tell(hit))

## Ce qu'un coup a fait, en une phrase.
func _tell(hit: StrikeResult) -> String:
	if hit.hit() == StrikeResult.Hit.NOTHING:
		return "dans le vide"
	var what := _name_of(hit.body()) if hit.hit() == StrikeResult.Hit.BODY \
		else "le bâti en %s" % hit.anchor()
	return "%d sur %s%s" % [hit.damage(), what, ", il tombe" if hit.felled() else ""]

func _log(piece: Combatant, gesture: String, effect: String) -> void:
	_lines.append("  %-6d %-10s %-22s %s" % [_board.round_number(),
		"ouvriers" if piece.is_friend() else "vague", gesture, effect])

## L'ennemi debout le plus proche de ce corps, ou null.
func _nearest_foe(piece: Combatant) -> Combatant:
	var camp := Combatant.Side.FOE if piece.is_friend() else Combatant.Side.FRIEND
	var prey: Combatant = null
	for other in _board.standing(camp):
		if prey == null or _distance(piece.cell(), other.cell()) \
				< _distance(piece.cell(), prey.cell()):
			prey = other
	return prey

# --- le damier --------------------------------------------------------------------------

## Le damier, décor ou coûts selon ce qu'on lui passe.
##
## Une seule fonction pour les deux tables, sans quoi la carte des coûts et celle du décor
## finiraient par ne plus montrer le même terrain — c'est la règle que `D2` a tirée des deux
## tables de ciblage, appliquée à une image.
func _draw(costs: Dictionary[Vector2i, int]) -> PackedStringArray:
	var window := _window()
	var rows := PackedStringArray()
	rows.append("     " + _column_ruler(window))
	for y in range(window.position.y, window.end.y):
		var row := ""
		for x in range(window.position.x, window.end.x):
			row += _glyph(Vector2i(x, y), costs)
		rows.append("%3d  %s" % [y, row])
	return rows

func _glyph(cell: Vector2i, costs: Dictionary[Vector2i, int]) -> String:
	var piece := _board.body_at(cell)
	if piece != null:
		var initial := _name_of(piece.id()).left(1)
		return initial.to_upper() if piece.is_friend() else initial.to_lower()
	if not costs.is_empty():
		return str(costs[cell]) if costs.has(cell) and costs[cell] < 10 else "·"
	var building := _board.city().at_cell(cell)
	if building != null and not _board.is_wrecked(building.anchor()):
		return "#" if building.is_complete() else "+"
	for tag in _combat.impassable_tags:
		if _board.terrain().has_tag(cell, tag):
			return "~" if tag == _combat.impassable_tags[0] else "^"
	return str(_board.terrain().height_at(cell) % 10)

## La fenêtre de damier : le bâti, plus la marge d'entrée, plus un cadre, bornée à la carte.
func _window() -> Rect2i:
	var area := BattleGround.built_area(_board.city())
	var pad := _combat.spawn_margin + FRAME
	var window := Rect2i(area.position - Vector2i.ONE * pad,
		area.size + Vector2i.ONE * pad * 2)
	return window.intersection(Rect2i(Vector2i.ZERO, _board.terrain().size()))

func _column_ruler(window: Rect2i) -> String:
	var ruler := ""
	for x in range(window.position.x, window.end.x):
		ruler += str(x % 10)
	return ruler

# --- fabrique ---------------------------------------------------------------------------

## Ouvre le plateau : les défenseurs sur leur poste, la vague à la lisière.
##
## Le déploiement passe par `InstantCombatResolver.deploy()`, c'est-à-dire la règle de `F1`
## employée comme **bouton par défaut**, ce que `DESIGN.md` 3.6 annonçait mot pour mot :
## « la règle automatique lui survivra comme bouton par défaut ». Le harnais ne réinvente
## donc pas qui monte sur la ligne.
func _open_board() -> CombatBoard:
	var city := _state.city().to_snapshot()
	var force := _state.roster().to_combat(_combat.combat_skill_family, _workforce,
		_combat)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var board := CombatBoard.open(_state.terrain(), city, _combat, rng)
	_line = InstantCombatResolver.deploy(force,
		InstantCombatResolver.slots_for(city, _combat))
	var posts := BattleGround.landing_cells(board, FROM_SIDE, _line.size())
	for rank in mini(_line.size(), posts.size()):
		board.deploy(force.unit(_line[rank]), posts[rank])
	var gates := BattleGround.entry_cells(board, FROM_SIDE, WAVE.size())
	for rank in mini(WAVE.size(), gates.size()):
		board.send(StringName("%s_%d" % [WAVE[rank], rank]),
			GameDatabase.get_enemy(WAVE[rank]), gates[rank])
	return board

## Ouvre un vrai run, **le fonde**, et lui bâtit un village autour du Cœur.
##
## La fondation n'est pas un détail de mise en scène : sans elle la ville est vide et les
## bâtiments se posent où le balayage commence, c'est-à-dire en bande contre le bord haut de
## la carte. La lisère du bâti touche alors le bord, et une vague qui arrive du nord n'a
## **aucune** case où entrer — la table l'a montré en toutes lettres au premier lancement,
## en annonçant « entrée de la vague : aucune » sous un damier parfaitement aligné.
##
## C'est le défaut de harnais que `CLAUDE.md` décrit depuis `F1`, dans sa variante la plus
## utile : la table n'a pas menti, elle a dit qu'elle n'avait rien à montrer. Le verdict en
## fin de fichier est ce qui l'a rendue lisible.
func _open_run(balance: BalanceData) -> RunState:
	var grid := TerrainGen.generate(SEED, balance.terrain_gen.map_size, balance.terrain_gen)
	var state := RunState.open(SEED, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance)
	RunOrchestrator.found(state, state.suggested_heart_anchor())
	for id in VILLAGE:
		_raise(state, GameDatabase.get_building(id))
	return state

## Pose ce bâtiment sur l'ancre libre la plus proche du Cœur et le mène à son dernier cran,
## sauf le dernier de la liste — laissé **en chantier**, pour que le damier montre les deux
## états et que l'échange ait quelque chose à interrompre.
##
## Autour du Cœur et non depuis l'origine : un village groupé est ce qu'une partie produit,
## et c'est la seule forme sur laquelle « la vague entre à la lisière du bâti » veuille dire
## quelque chose.
func _raise(state: RunState, data: BuildingData) -> void:
	for anchor in _rings(state):
		if not state.city().place(state.terrain(), data, anchor).is_ok():
			continue
		if data.id == VILLAGE[VILLAGE.size() - 1]:
			return
		while not state.city().building_at(anchor).is_complete():
			state.city().advance(anchor)
		return

## Les cases de la carte, du Cœur vers les bords.
##
## Même ordre que `RunState.suggested_heart_anchor()` emploie pour le Cœur lui-même, et
## totalement déterministe : à distance égale, le balayage en y puis en x départage.
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

## Les cases occupées par ce camp, en une chaîne courte.
func _cells_of(camp: Combatant.Side) -> String:
	var cells := PackedStringArray()
	for piece in _board.standing(camp):
		cells.append(str(piece.cell()))
	return ", ".join(cells) if not cells.is_empty() else "aucune"

func _first_of(camp: Combatant.Side) -> Combatant:
	var upright := _board.standing(camp)
	return null if upright.is_empty() else upright[0]

## La case de `within` la plus chère. Zéro sur un corps qui ne bouge pas.
func _dearest(within: Dictionary[Vector2i, int]) -> int:
	var top := 0
	for cell in within:
		top = maxi(top, within[cell])
	return top

## Combien de cases un corps atteindrait à plat, sans obstacle : le losange de Manhattan.
##
## Le point de comparaison sans lequel le compte de la table ne veut rien dire — c'est lui
## qui dit si le relief et les murs retirent quelque chose. Il se calcule et ne se mesure
## pas : le prendre sur le même plateau reviendrait à comparer un compteur à lui-même.
func _flat_count(points: int) -> int:
	return 2 * points * (points + 1) + 1

## Les cases voisines où ce corps peut poser le pied, sur ce plateau.
##
## Prise sur le **voisinage** et non sur le parcours, pour la raison que `CLAUDE.md` a
## tirée à `I2b` : une colonne qui doit corroborer une autre se prend ailleurs, sinon leur
## accord est une tautologie sur une ligne parfaitement alignée.
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

func _distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)

## Le prénom d'un corps : celui du roster pour un ouvrier, le libellé du type sinon.
func _name_of(id: StringName) -> String:
	if _state.roster().has(id):
		return _state.roster().worker(id).given_name()
	for known in GameDatabase.list_enemy_ids():
		if String(id).begins_with(String(known)):
			return GameDatabase.get_enemy(known).label
	return String(id).capitalize()

func _names_of(ids: Array[StringName]) -> PackedStringArray:
	var names := PackedStringArray()
	for id in ids:
		names.append(_name_of(id))
	return names

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

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.name = "BattleReport"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi le damier n'est plus un damier.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
