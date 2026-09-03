extends Node
## Harnais de dev des Vagues — jalon V2 : une bataille se résout sans écran, et se raconte.
##
## **Aucun rendu, et c'est ce que `DESIGN.md` demande à ce jalon** : « un harnais qui résout une
## bataille sans écran et imprime ce qui s'est passé ». La bataille à l'écran est `V3`, et elle
## interpolera entre deux états de ce même plateau — le domaine, lui, ne saura toujours pas
## qu'un écran existe.
##
## Il monte une carte générée, un village posé par une politique écrite, puis résout la vague de
## `data/waves/` et imprime trois tables.
##
## ---
##
## **Ce que ces tables doivent montrer**, et c'est le rôle du verdict en pied de fichier :
##
## - **la chronique** — qu'une bataille *avance*, tick par tick : des corps entrent, des traits
##   volent, des morts tombent. Une colonne qui ne bougerait jamais dirait qu'un des quatre
##   temps du tick ne se joue pas.
## - **le comparatif de défense** — que poser une tour **change** l'issue, et de combien. C'est
##   la seule table qui porte un argument de design : si le village tient aussi bien sans
##   défense qu'avec, le tower-defense n'existe pas.
##
##   *La colonne des tirs y est entrée après coup*, parce que sans elle la table invitait à la
##   mauvaise conclusion : une tour qui ne tue personne se lisait comme une tour qui ne marche
##   pas, alors qu'elle avait tiré une fois. Une table qui dit ce qu'on a **tenté** à côté de ce
##   qu'on a **obtenu** distingue « la mécanique ne répond pas » de « les chiffres sont
##   mauvais » — et les deux ne se corrigent pas au même endroit.
## - **le comparatif d'emplacement** — que « sur le chemin » et « à côté » ne valent pas la même
##   chose, ce que `DESIGN.md` 3.5 appelle l'arbitrage central du jeu.
##
## **Ce qu'elles ne montrent pas** : si les chiffres sont *bons*. Aucune colonne ici ne dit
## qu'une vague est amusante ni qu'une tour coûte le juste prix — ça se règle en jouant, et c'est
## `B1`. La table dit que la mécanique **répond**, ce qui est le plancher et non l'objectif.

## Seed de la carte. Fixe : deux lancements doivent se comparer.
const SEED := 1234

## La vague jouée, et l'assaillant de secours si `data/waves/` était vide.
const WAVE_ID := &"first_raid"

## Ticks entre deux lignes de la chronique. Une ligne par tick noierait la table sous des
## centaines de lignes dont la plupart ne disent rien.
const CHRONICLE_EVERY := 4

## Lignes de chronique imprimées avant qu'un pied ne compte le reste. Même règle que les listes
## du HUD : une table qui suit la partie se borne.
const CHRONICLE_LINES := 14

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	var params := balance.terrain_gen
	var grid := TerrainGen.generate(SEED, params.map_size, params)
	var wave := _wave()
	if wave == null:
		print("[battle_harness] aucune vague dans data/waves/ : rien à jouer.")
		get_tree().quit(FAILED)
		return

	print("[battle_harness] carte %d x %d, seed %d — vague « %s » : %d x %s par le %s"
		% [grid.size().x, grid.size().y, SEED, wave.id, wave.count, wave.enemy.label,
			_side_name(wave.side)])
	print("  L'assaillant : %d PV, %d tick(s)/case, %d de dégâts, patience %d case(s) de détour."
		% [wave.enemy.hit_points, wave.enemy.ticks_per_cell, wave.enemy.damage,
			balance.waves.patience_in_steps(wave.enemy)])

	var heart := _found(grid, balance)
	if heart == Vector2i(-1, -1):
		print("[battle_harness] aucun site de fondation sur cette carte.")
		get_tree().quit(FAILED)
		return

	_write_chronicle(grid, balance, wave, heart)
	_write_defence_table(grid, balance, wave, heart)
	_write_placement_table(grid, balance, wave, heart)
	print("[battle_harness] les tables disent que la mécanique répond, pas que les chiffres")
	print("[battle_harness] sont bons — ça se règle en jouant, et c'est B1.")
	get_tree().quit(OK)

# --- les trois tables --------------------------------------------------------

## Une bataille jouée tick par tick, avec une tour sur le chemin.
##
## **Le relevé se prend AVANT le tick et le rapport après**, ce qui est la seule façon d'obtenir
## une ligne cohérente : les corps en marche à un instant donné et les morts déjà comptés au même
## instant. Lire les deux après aurait mélangé deux moments — et c'est très exactement la famille
## de défauts que `CLAUDE.md` note depuis `F2b`.
func _write_chronicle(grid: HeightGrid, balance: BalanceData, wave: WaveDef,
		heart: Vector2i) -> void:
	var city := _village(grid, balance, heart, true)
	var board := CombatBoard.open(grid.to_query(), city.to_snapshot(), heart, wave,
		balance.waves)
	print("")
	print("Chronique — un village avec une tour sur le chemin")
	print("  %5s  %8s  %6s  %6s  %7s  %s" % ["tick", "en marche", "traits", "morts",
		"arrivés", "Cœur"])
	var lines := 0
	var skipped := 0
	while not board.finished():
		board.tick()
		if board.ticks() % CHRONICLE_EVERY != 0:
			continue
		if lines >= CHRONICLE_LINES:
			skipped += 1
			continue
		var report := board.report()
		print("  %5d  %8d  %6d  %6d  %7d  %d" % [board.ticks(), _marching(board),
			board.shots_in_flight(), report.killed(), report.arrived(),
			report.heart_damage()])
		lines += 1
	if skipped > 0:
		print("  ... %d relevé(s) de plus, jusqu'au tick %d" % [skipped, board.ticks()])
	var final := board.report()
	print("  fin    %d tick(s), %d mort(s), %d arrivé(s), Cœur %d, %d bâtiment(s) frappé(s)"
		% [final.ticks(), final.killed(), final.arrived(), final.heart_damage(),
			final.damaged().size()])

## La même vague contre trois villages, pour que « poser une tour change quelque chose » soit un
## chiffre et non une conviction.
func _write_defence_table(grid: HeightGrid, balance: BalanceData, wave: WaveDef,
		heart: Vector2i) -> void:
	print("")
	print("Ce qu'une défense change")
	print("  %-22s  %6s  %5s  %6s  %7s  %s" % ["village", "ticks", "tirs", "morts",
		"arrivés", "Cœur"])
	_battle_line("sans défense", grid, balance, wave, heart, _village(grid, balance, heart,
		false))
	_battle_line("une tour sur le chemin", grid, balance, wave, heart,
		_village(grid, balance, heart, true))
	_battle_line("deux tours", grid, balance, wave, heart,
		_village(grid, balance, heart, true, 2))

## Une tour sur le chemin contre la même tour à côté, ce que `DESIGN.md` 3.5 appelle l'arbitrage
## central : « sur le chemin, elle barre et se bat, mais elle meurt ; à côté, elle survit, mais
## il lui faut de la portée ».
##
## La table prend la tour **la plus proche du chemin** et la même reculée hors de portée, sur la
## même carte et la même vague : c'est le seul montage où l'écart mesure l'emplacement et rien
## d'autre.
func _write_placement_table(grid: HeightGrid, balance: BalanceData, wave: WaveDef,
		heart: Vector2i) -> void:
	var path := WavePathfinder.find(grid.to_query(), CitySnapshot.empty(), heart,
		wave.entry_cells(grid.size()), balance.waves, wave.enemy)
	if not path.reaches():
		print("")
		print("Ce que l'emplacement change : le Cœur est injoignable, rien à comparer.")
		return
	print("")
	print("Ce que l'emplacement change — chemin de %d cases" % path.length())
	print("  %-22s  %6s  %5s  %6s  %7s  %s" % ["tour posée", "ticks", "tirs", "morts",
		"arrivés", "Cœur"])
	var tower := _tower(balance)
	if tower == null:
		print("  aucun bâtiment de défense dans data/buildings/.")
		return
	var reach: int = tower.defence.reach
	for label in ["au contact du chemin", "à portée", "hors de portée"]:
		var gap: int = {"au contact du chemin": 1, "à portée": reach,
			"hors de portée": reach + 3}[label]
		var city := CityState.new()
		_plant_heart(city, grid, balance, heart)
		var spot := _spot_beside(grid, city, path, tower, gap)
		if spot == Vector2i(-1, -1):
			print("  %-22s  aucune case libre à %d case(s) du chemin" % [label, gap])
			continue
		_raise(city, grid, tower, spot)
		_battle_line(label, grid, balance, wave, heart, city)

## Une ligne de comparatif : la même vague contre ce village-là.
func _battle_line(label: String, grid: HeightGrid, balance: BalanceData, wave: WaveDef,
		heart: Vector2i, city: CityState) -> void:
	var report := CombatBoard.open(grid.to_query(), city.to_snapshot(), heart, wave,
		balance.waves).run_to_end()
	print("  %-22s  %6d  %5d  %6d  %7d  %d" % [label, report.ticks(), report.shots(),
		report.killed(), report.arrived(), report.heart_damage()])

# --- le montage --------------------------------------------------------------

## La vague de `data/waves/`, ou null s'il n'y en a aucune.
func _wave() -> WaveDef:
	var wave := GameDatabase.get_wave(WAVE_ID)
	if wave != null:
		return wave
	var ids := GameDatabase.list_wave_ids()
	return GameDatabase.get_wave(ids[0]) if not ids.is_empty() else null

## Le site de fondation que l'audit trouve sur cette carte, ou (-1, -1).
##
## Le **même** que celui que le jeu emploie : `MapAudit` le cherche au plus près du centre depuis
## `T4`, et le harnais n'a aucune raison d'en choisir un autre — une bataille mesurée sur un
## village posé ailleurs que là où le jeu le pose ne mesurerait pas le jeu.
func _found(grid: HeightGrid, balance: BalanceData) -> Vector2i:
	var params := balance.terrain_gen
	var report := MapAudit.inspect(grid.to_query(), TerrainGen.centre_of(grid.size()),
		params.max_climb, params.min_plateau_cells)
	return report.site() if report.plateau() > 0 else Vector2i(-1, -1)

## Un village : le Cœur, et `towers` tours posées au plus près du chemin.
##
## La politique est **écrite et bête**, comme celle de la chronique du Run : elle prend les cases
## libres les plus proches du chemin, dans l'ordre du balayage. Elle n'a pas à être bonne, elle a
## à être la même d'un lancement à l'autre pour que deux équilibrages se comparent.
func _village(grid: HeightGrid, balance: BalanceData, heart: Vector2i, defended: bool,
		towers := 1) -> CityState:
	var city := CityState.new()
	_plant_heart(city, grid, balance, heart)
	if not defended:
		return city
	var tower := _tower(balance)
	if tower == null:
		return city
	var wave := _wave()
	var path := WavePathfinder.find(grid.to_query(), city.to_snapshot(), heart,
		wave.entry_cells(grid.size()), balance.waves, wave.enemy)
	if not path.reaches():
		return city
	for _index in towers:
		var spot := _spot_beside(grid, city, path, tower, 1)
		if spot == Vector2i(-1, -1):
			break
		_raise(city, grid, tower, spot)
	return city

## Pose le Cœur, celui que `RunBalance` nomme.
func _plant_heart(city: CityState, grid: HeightGrid, balance: BalanceData,
		heart: Vector2i) -> void:
	var data := GameDatabase.get_building(balance.run.starting_building)
	if data != null:
		_raise(city, grid, data, heart)

## Pose ce bâtiment **et l'achève**.
##
## **C'est la première version de ce harnais qui l'a appris**, et la table l'a dit avant moi :
## `CityState.place()` ouvre un **chantier**, pas un bâtiment. La tour de guet dure trois tours,
## donc elle arrivait sur le plateau inachevée — et un chantier ne tire pas, par la même règle
## qui l'empêche de produire et d'étendre l'emprise. Les trois colonnes du comparatif rendaient
## rigoureusement le même chiffre.
##
## Le défaut n'aurait été visible nulle part ailleurs : les cas de test posent des tours à
## `site_turns = 0`, le domaine répondait correctement, et rien n'était faux — sinon le montage.
## C'est exactement ce que `CLAUDE.md` attend d'une table depuis `F1` : **une table dont les
## colonnes ne bougent pas dénonce son propre pilote.**
func _raise(city: CityState, grid: HeightGrid, data: BuildingData, anchor: Vector2i) -> void:
	if not city.place(grid.to_query(), data, anchor).is_ok():
		return
	for _notch in data.site_turns:
		city.advance(anchor)

## Le premier bâtiment de `data/buildings/` qui porte un bloc de défense.
##
## Cherché plutôt que nommé : le harnais ne doit pas connaître la tour de guet par son nom, pour
## la même raison que le renderer ne connaît aucun bâtiment par le sien. Ajouter une baliste doit
## rester une édition de data.
func _tower(_balance: BalanceData) -> BuildingData:
	for id in GameDatabase.list_building_ids():
		var data := GameDatabase.get_building(id)
		if data != null and data.defence != null:
			return data
	return null

## Une case libre à exactement `gap` cases du chemin, en Manhattan, ou (-1, -1).
##
## Le balayage est en x puis en y, donc le résultat est le même d'un lancement à l'autre — et il
## saute les cases que le chemin traverse : une tour posée **sur** le chemin le déplacerait, et
## la table ne comparerait plus la même bataille.
func _spot_beside(grid: HeightGrid, city: CityState, path: WavePath, tower: BuildingData,
		gap: int) -> Vector2i:
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if path.passes_through(cell):
				continue
			if _rings_to_path(path, cell) != gap:
				continue
			# Un essai à blanc : on pose, on regarde si la ville a accepté, on retire. C'est la
			# seule façon d'interroger les six règles de placement sans en recopier aucune —
			# et un adapter qui les recopierait serait la faute d'architecture que ce projet
			# refuse en premier.
			if city.place(grid.to_query(), tower, cell).is_ok():
				city.remove(cell)
				return cell
	return Vector2i(-1, -1)

## Distance de Manhattan de cette case à la plus proche du chemin.
func _rings_to_path(path: WavePath, cell: Vector2i) -> int:
	var nearest := -1
	for step in path.cells():
		var span := absi(step.x - cell.x) + absi(step.y - cell.y)
		if nearest < 0 or span < nearest:
			nearest = span
	return nearest

## Combien de corps sont entrés et vivants.
func _marching(board: CombatBoard) -> int:
	var count := 0
	for body in board.bodies():
		if body.is_marching() and not body.is_dead() and not body.has_arrived():
			count += 1
	return count

## Le nom du bord d'entrée, en clair. Un rapport qui dirait « côté 3 » ne se relit pas.
func _side_name(side: WaveDef.Side) -> String:
	match side:
		WaveDef.Side.NORTH:
			return "nord"
		WaveDef.Side.SOUTH:
			return "sud"
		WaveDef.Side.WEST:
			return "ouest"
		WaveDef.Side.EAST:
			return "est"
	return "?"
