class_name CombatBoardTest
extends GdUnitTestSuite
## La bataille, sur des cartes **fabriquées à la main** et avec des chiffres ronds.
##
## Ce que ce fichier éprouve est une mécanique de **pas discrets**, donc chaque cas compte des
## ticks à la main et sait ce qu'il devrait obtenir. C'est la seule façon de vérifier une
## cadence : sur une carte générée, on ne saurait pas dire au tick près quand une tour a tiré.
##
## Le montage de base est une plaine nue de 9 x 9, la vague entrant par l'ouest et visant
## (8, 4). Aucun relief, aucun bâtiment, sauf ce qu'un cas pose.
##
## **Les corps y sont volontairement rapides et fragiles** — une case par tick, peu de points de
## vie —, parce que ce qui doit se lire dans un cas est l'arithmétique du tick et non la durée
## d'une bataille plausible. Les chiffres jouables sont dans `data/`, et c'est `B1` qui les
## réglera.

const SIZE := Vector2i(9, 9)
const HEART := Vector2i(8, 4)
const STEP := 10
const CLIMB := 6

var _plain: TerrainData
var _grid: HeightGrid
var _city: CityState

func before_test() -> void:
	_plain = _terrain(&"plain")
	_grid = HeightGrid.create(SIZE, 0, _plain)
	_city = CityState.new()

# --- la marche ---------------------------------------------------------------

## Un corps seul, sans défense en face, traverse et frappe le Cœur. C'est le cas nu : si celui-ci
## échoue, aucun des autres ne veut rien dire.
func test_a_lone_body_walks_across_and_hits_the_heart() -> void:
	var report := _open(_wave(1)).run_to_end()
	assert_int(report.arrived()) \
		.override_failure_message("rien ne le gênait : il devait arriver") \
		.is_equal(1)
	assert_int(report.killed()).is_equal(0)
	assert_int(report.heart_damage()).is_equal(_enemy().damage)
	assert_bool(report.held()).is_false()

## **Ce n'est pas tout ou rien.** `DESIGN.md` 3.5 : « une vague à moitié arrêtée coûte la
## moitié ». Trois corps qui passent coûtent trois fois les dégâts d'un.
func test_the_heart_pays_once_per_body_that_arrives() -> void:
	var report := _open(_wave(3)).run_to_end()
	assert_int(report.arrived()).is_equal(3)
	assert_int(report.heart_damage()).is_equal(3 * _enemy().damage)

## Une lenteur de deux ticks par case double la durée de la traversée. C'est ce qui rend une
## cadence lisible : un corps lent reste plus longtemps sous le feu.
func test_a_slower_body_takes_twice_as_long() -> void:
	var quick := _open(_wave(1)).run_to_end().ticks()
	var slow := _enemy()
	slow.ticks_per_cell = 2
	var report := _open(_wave(1, slow)).run_to_end()
	assert_int(report.ticks()) \
		.override_failure_message("deux ticks par case : la traversée devait doubler") \
		.is_greater(quick)

## **Les corps entrent espacés**, et c'est ce qui donne un sens à une cadence : dix corps posés
## sur la même case au même instant rendraient toute défense inutile.
func test_bodies_enter_spaced_out() -> void:
	var board := _open(_wave(3))
	board.tick()
	assert_int(_marching(board)) \
		.override_failure_message("un seul corps devait être entré au premier tick") \
		.is_equal(1)
	for _turn in _wave(3).spacing:
		board.tick()
	assert_int(_marching(board)).is_equal(2)

## Un Cœur qu'aucun chemin n'atteint rend une bataille **immédiatement finie** et un Cœur
## intact : c'est le village invincible que `MapAudit` traque depuis `T4`, et le plateau ne doit
## ni tourner sans fin ni inventer des dégâts.
func test_an_unreachable_heart_ends_the_battle_at_once() -> void:
	var rock := _terrain(&"rock", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED)
	for y in SIZE.y:
		_grid.set_cell(Vector2i(4, y), 0, rock)
	var board := _open(_wave(3))
	assert_bool(board.finished()).is_true()
	var report := board.run_to_end()
	assert_int(report.heart_damage()).is_equal(0)
	assert_int(report.arrived()).is_equal(0)
	assert_bool(report.held()).is_true()

# --- ce que la vague casse ---------------------------------------------------

## Un corps qui perce un bâtiment le frappe. Le rapport nomme l'ancre et les dégâts, sans jamais
## toucher à la ville : retirer le bâtiment est l'affaire de l'orchestrateur, à `V4`.
func test_a_body_that_breaches_a_building_damages_it() -> void:
	_wall_across(range(SIZE.y))
	var report := _open(_wave(1)).run_to_end()
	assert_bool(report.damaged().has(Vector2i(4, 4))) \
		.override_failure_message("le mur barrait tout : il devait être frappé") \
		.is_true()
	assert_int(report.damaged()[Vector2i(4, 4)]).is_equal(_enemy().damage)

## Il le frappe **une fois par case traversée**, à l'entrée sur la case — pas une fois par tick
## qu'il y passe. Sans cette règle, un corps lent démolirait un mur en restant dessus.
func test_a_slow_body_does_not_hit_the_same_wall_twice() -> void:
	_wall_across(range(SIZE.y))
	var slow := _enemy()
	slow.ticks_per_cell = 5
	var report := _open(_wave(1, slow)).run_to_end()
	assert_int(report.damaged()[Vector2i(4, 4)]) \
		.override_failure_message("cinq ticks sur la case ne valent qu'un coup") \
		.is_equal(slow.damage)

## Le Cœur n'est pas compté deux fois : ses dégâts vont à la jauge du run, jamais à la liste des
## bâtiments abîmés. Les additionner ferait payer le même corps deux fois.
func test_the_heart_is_not_counted_among_the_damaged_buildings() -> void:
	_place(_building(&"heart", [Vector2i.ZERO] as Array[Vector2i]), HEART)
	var report := _open(_wave(1)).run_to_end()
	assert_int(report.heart_damage()).is_equal(_enemy().damage)
	assert_bool(report.damaged().has(HEART)).is_false()

# --- les défenses ------------------------------------------------------------

## **Le cas qui porte le jalon.** Une tour sur le chemin tue ce qui passe à sa portée, et le Cœur
## ne prend rien.
func test_a_tower_on_the_path_kills_what_walks_by() -> void:
	_place(_tower(&"tower", 12, 4), Vector2i(4, 2))
	var report := _open(_wave(1)).run_to_end()
	assert_int(report.killed()) \
		.override_failure_message("douze de dégâts par tir contre dix de vie : il devait tomber") \
		.is_equal(1)
	assert_int(report.arrived()).is_equal(0)
	assert_bool(report.held()).is_true()

## **Une tour hors de portée ne sert à rien**, et c'est l'arbitrage central de `DESIGN.md` 3.5 :
## « sur le chemin, elle barre et se bat, mais elle meurt ; à côté, elle survit, mais il lui faut
## de la portée ». Sans ce cas, le précédent passerait sur un plateau qui ferait tirer tout le
## monde sur tout le monde.
func test_a_tower_out_of_reach_never_fires() -> void:
	_place(_tower(&"tower", 99, 1), Vector2i(4, 0))
	var report := _open(_wave(1)).run_to_end()
	assert_int(report.killed()) \
		.override_failure_message("quatre cases d'écart pour une portée de 1 : aucun tir") \
		.is_equal(0)
	assert_int(report.arrived()).is_equal(1)

## **La cadence compte des ticks.** Une tour qui tire toutes les cinquante ticks n'a le temps que
## d'un tir, donc elle n'arrête qu'un corps sur trois.
func test_the_cadence_limits_how_many_a_tower_stops() -> void:
	_place(_tower(&"tower", 99, 4, 50), Vector2i(4, 2))
	var report := _open(_wave(3)).run_to_end()
	assert_int(report.killed()) \
		.override_failure_message("une cadence de 50 ne laisse pas le temps de trois tirs") \
		.is_less(3)
	assert_int(report.fielded()).is_equal(3)

## **Un projectile dont la cible meurt en vol est perdu**, et `DESIGN.md` 3.5 en fait une règle
## plutôt qu'un effet de bord : « ça punit le surkill, ça rend la cadence lisible, et c'est une
## règle de moins ». Deux tours qui tirent ensemble sur le même corps en gaspillent une.
func test_a_shot_whose_target_dies_in_flight_is_wasted() -> void:
	# Deux tours **au contact** du chemin, chacune assez forte pour tuer d'un coup, et une
	# cadence plus longue que la bataille : elles tirent une fois, ensemble, sur le même corps.
	#
	# Le contact n'est pas un détail, et c'est ce que la première version de ce cas a appris :
	# à portée 4, les traits mettent huit ticks à arriver et le corps a atteint le Cœur entre
	# temps — le tir était perdu, mais pour la mauvaise raison. Un cas qui montre le surkill doit
	# d'abord garantir que les deux traits **touchent**.
	_place(_tower(&"first", 99, 1, 50), Vector2i(4, 3))
	_place(_tower(&"second", 99, 1, 50), Vector2i(4, 5))
	var report := _open(_wave(2)).run_to_end()
	assert_int(report.killed()) \
		.override_failure_message("le surkill devait coûter un tir, donc laisser passer un corps") \
		.is_equal(1)
	assert_int(report.arrived()).is_equal(1)

## Un bâtiment **en chantier** ne tire pas. Même règle que la réserve qu'un entrepôt en travaux
## ne relève pas, et que l'emprise qu'un chantier n'étend pas : ce qui n'est pas fini ne fait
## rien.
func test_a_tower_under_construction_does_not_fire() -> void:
	var tower := _tower(&"tower", 99, 4)
	tower.site_turns = 2
	_place(tower, Vector2i(4, 2))
	assert_int(_open(_wave(1)).run_to_end().killed()) \
		.override_failure_message("un chantier ne tire pas") \
		.is_equal(0)

# --- le pas de simulation ----------------------------------------------------

## `run_to_end()` est la même boucle qu'un écran, sans écran. Les deux doivent rendre le même
## rapport au point de vie près, sans quoi mesurer une bataille et la regarder seraient deux
## choses — et c'est précisément ce que `DESIGN.md` 3.5 achète avec les ticks.
func test_running_to_the_end_matches_ticking_by_hand() -> void:
	_place(_tower(&"tower", 6, 4), Vector2i(4, 2))
	var scripted := _open(_wave(3))
	while not scripted.finished():
		scripted.tick()
	var looped := _open(_wave(3)).run_to_end()
	assert_int(scripted.report().ticks()).is_equal(looped.ticks())
	assert_int(scripted.report().killed()).is_equal(looped.killed())
	assert_int(scripted.report().heart_damage()).is_equal(looped.heart_damage())

## Deux batailles identiques rendent le même rapport. Sans ça, ni l'équilibrage, ni une
## chronique, ni le déterminisme du run que `DESIGN.md` 3.7 promet ne tiennent.
func test_the_same_battle_gives_the_same_report() -> void:
	_place(_tower(&"tower", 6, 4), Vector2i(4, 2))
	var first := _open(_wave(4)).run_to_end()
	var second := _open(_wave(4)).run_to_end()
	assert_int(first.ticks()).is_equal(second.ticks())
	assert_int(first.killed()).is_equal(second.killed())
	assert_int(first.heart_damage()).is_equal(second.heart_damage())
	assert_dict(first.damaged()).is_equal(second.damaged())

## Un `tick()` de trop ne change rien : c'est le cas normal d'une boucle d'affichage qui tourne
## pendant qu'on regarde le résultat, pas une faute d'appelant.
func test_ticking_a_finished_battle_changes_nothing() -> void:
	var board := _open(_wave(1))
	var report := board.run_to_end()
	for _extra in 10:
		board.tick()
	assert_int(board.report().ticks()).is_equal(report.ticks())
	assert_int(board.report().heart_damage()).is_equal(report.heart_damage())

## La bataille n'est pas finie tant qu'un trait est en vol : un projectile en l'air peut tuer,
## et déclarer la fin avant lui perdrait un dégât.
func test_a_battle_is_not_over_while_a_shot_is_in_flight() -> void:
	_place(_tower(&"tower", 99, 4), Vector2i(4, 2))
	var board := _open(_wave(1))
	var seen := false
	while not board.finished():
		board.tick()
		if board.shots_in_flight() > 0:
			seen = true
			assert_bool(board.finished()) \
				.override_failure_message("un trait est en vol : la bataille continue") \
				.is_false()
	assert_bool(seen) \
		.override_failure_message("aucun trait n'a volé : le cas ne prouve rien") \
		.is_true()

# --- le montage --------------------------------------------------------------

func _open(wave: WaveDef) -> CombatBoard:
	return CombatBoard.open(_grid.to_query(), _city.to_snapshot(), HEART, wave, _balance())

func _balance() -> WaveBalance:
	var balance := WaveBalance.new()
	balance.step_cost = STEP
	balance.climb_cost = CLIMB
	return balance

## Un assaillant rapide et fragile : une case par tick, dix points de vie.
func _enemy() -> EnemyDef:
	var enemy := EnemyDef.new()
	enemy.id = &"raider"
	enemy.label = "Pillard"
	enemy.hit_points = 10
	enemy.ticks_per_cell = 1
	enemy.damage = 4
	enemy.patience = 120
	enemy.climb = 2
	return enemy

## Une vague de `count` corps, entrant par l'ouest.
func _wave(count: int, enemy: EnemyDef = null) -> WaveDef:
	var wave := WaveDef.new()
	wave.id = &"raid"
	wave.enemy = enemy if enemy != null else _enemy()
	wave.count = count
	wave.side = WaveDef.Side.WEST
	wave.spacing = 3
	return wave

## Une tour d'une case, de ces dégâts, cette portée et cette cadence.
func _tower(id: StringName, damage: int, reach: int, cadence := 1) -> BuildingData:
	var data := _building(id, [Vector2i.ZERO] as Array[Vector2i])
	var defence := DefenceBlock.new()
	defence.damage = damage
	defence.reach = reach
	defence.cadence = cadence
	data.defence = defence
	return data

## Une palissade d'une case par ligne de `rows`, sur la colonne 4.
func _wall_across(rows) -> void:
	for y in rows:
		_place(_building(&"wall_%d" % y, [Vector2i.ZERO] as Array[Vector2i]), Vector2i(4, y))

## Pose ce bâtiment, en vérifiant que la ville l'a bien pris : un placement refusé rendrait un
## cas vert qui ne prouverait rien de la bataille.
func _place(data: BuildingData, anchor: Vector2i) -> void:
	var result := _city.place(_grid.to_query(), data, anchor)
	assert_bool(result.is_ok()) \
		.override_failure_message("le montage n'a pas posé %s en %s : %s"
			% [data.id, anchor, result.reason()]) \
		.is_true()

## Combien de corps sont entrés sur la carte.
func _marching(board: CombatBoard) -> int:
	var count := 0
	for body in board.bodies():
		if body.is_marching() and not body.is_dead():
			count += 1
	return count

func _building(id: StringName, offsets: Array[Vector2i]) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.footprint = offsets
	data.hit_points = 20
	data.reach = 4
	return data

func _terrain(id: StringName, build := TerrainData.Build.ALLOWED,
		walk := TerrainData.Walk.ALLOWED) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.walk = walk
	return data
