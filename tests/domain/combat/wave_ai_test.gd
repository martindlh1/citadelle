class_name WaveAITest
extends GdUnitTestSuite
## Ce que les assaillants annoncent, et ce qu'ils font ensuite.
##
## Deux règles de `DESIGN.md` 3.6 tiennent tout ce fichier, et rien d'autre n'y est asserté :
##
## - **Un corps annonce une case exactement quand il peut frapper sans bouger**, et cette
##   annonce engage. C'est la réponse que `F2b` donne à la question rouverte à `F2a`, et
##   c'est ce qui fait de l'esquive un geste plutôt qu'une clause de résolution.
## - **Ils visent les ouvriers à portée, les bâtiments sinon.** Une seule ligne d'IA, dont
##   toute la raison d'être est que fuir soit un troc.
##
## **Terrain de travail**, 11×11 plat en plaine, sans eau ni relief : ce que le sol fait à un
## déplacement est le sujet de `CombatMovementTest`, et le mélanger ici rendrait chaque
## échec ambigu. Le seul bâtiment vit dans le coin `(8, 8)`, à l'écart, pour que les cas qui
## parlent d'ouvriers ne rencontrent pas un mur par accident ; ceux qui parlent de murs vont
## le chercher.
##
## Les fourchettes de dégâts sont **dégénérées** partout : l'aléatoire a sa suite, et il n'a
## rien à dire sur une décision.

const EXTENT := Vector2i(11, 11)

## Le seul bâtiment du terrain, dans un coin.
const WALL := Vector2i(8, 8)
const WALL_HP := 6

## Où les ouvriers et les assaillants se tiennent par défaut.
const POST := Vector2i(5, 5)
const NORTH_GATE := Vector2i(5, 0)

const ROUNDS := 20
const SEED := 4413

# --- ce qu'un corps annonce -------------------------------------------------------------

## **La règle du jalon.** Un corps qui peut frapper d'où il est annonce la case, et cette
## annonce engage. C'est elle qui rend l'esquive de 3.6 jouable : on ne peut pas esquiver ce
## qui n'est pas annoncé.
func test_a_body_that_can_strike_where_it_stands_names_the_cell() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", POST + Vector2i(0, -1))
	var intent := WaveAI.announce(board)[&"orc"]
	assert_bool(intent.is_bound()).is_true()
	assert_vector(intent.cell()).is_equal(POST)

## Et un corps qui doit fermer la distance n'annonce que sa nature. Annoncer son trajet
## serait ou bien conditionnel — le joueur agit après —, ou bien rigide, et un ennemi enfermé
## cognerait l'air. C'est l'objection qui a fait rouvrir le paragraphe à `F2a`.
func test_a_body_that_must_close_only_announces_that_it_comes() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", NORTH_GATE)
	var intent := WaveAI.announce(board)[&"orc"]
	assert_bool(intent.is_bound()).is_false()
	assert_int(intent.kind()).is_equal(CombatIntent.Kind.ADVANCE)

## **La question littérale de 3.6** — « une attaque à distance annonce-t-elle sa case ? » —
## et la réponse y est oui. Mais elle ne tombe pas d'une règle sur les tireurs : elle tombe
## de la règle générale, parce qu'un tireur posté n'a pas besoin de bouger.
func test_a_posted_shooter_names_its_cell_from_three_squares_away() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"archer", POST + Vector2i(0, -3), 3)
	var intent := WaveAI.announce(board)[&"archer"]
	assert_bool(intent.is_bound()).is_true()
	assert_vector(intent.cell()).is_equal(POST)

## Un corps-à-corps déjà collé annonce sa case lui aussi, et c'est ce qui distingue cette
## règle d'une règle sur les portées : ce qui varie est la **situation**, pas la fiche.
func test_the_rule_is_about_the_situation_and_not_about_reach() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"brute", POST + Vector2i(1, 0))
	assert_bool(WaveAI.announce(board)[&"brute"].is_bound()).is_true()

## `DESIGN.md` 3.6 : « Ils visent les ouvriers à portée, les bâtiments sinon. »
func test_a_worker_within_reach_outranks_a_wall() -> void:
	var board := _open()
	_worker(board, &"ana", WALL + Vector2i(-1, 0))
	_foe(board, &"orc", WALL + Vector2i(0, -1), 2)
	assert_vector(WaveAI.announce(board)[&"orc"].cell()).is_equal(WALL + Vector2i(-1, 0))

## Et à défaut d'ouvrier, le mur. C'est la moitié de la règle qui rend la fuite coûteuse :
## on garde ses gens, ils mangent les murs.
func test_a_wall_is_named_when_no_worker_is_within_reach() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", WALL + Vector2i(0, -1))
	assert_vector(WaveAI.announce(board)[&"orc"].cell()).is_equal(WALL)

## La ligne d'IA ne vise pas ses propres corps. Le coup peut en toucher un — c'est la règle
## de la case —, mais il ne se **décide** jamais contre lui.
func test_the_wave_never_aims_at_its_own() -> void:
	var board := _open()
	_foe(board, &"orc", Vector2i(0, 0))
	_foe(board, &"pal", Vector2i(0, 1))
	assert_bool(WaveAI.announce(board)[&"orc"].is_bound()).is_false()

## À portée égale, l'ordre d'entrée départage : c'est celui du déploiement, donc une chose
## que le joueur a décidée. `CombatBoard.standing()` le promet depuis `F2a`.
func test_two_workers_equally_close_are_settled_by_entry_order() -> void:
	assert_vector(_tie_between(&"ana", &"bo")).is_equal(POST + Vector2i(-1, 0))
	assert_vector(_tie_between(&"bo", &"ana")).is_equal(POST + Vector2i(1, 0))

## Entre deux murs, c'est l'ancre et non l'ordre de pose. Deux villages identiques bâtis
## dans un ordre différent doivent perdre la même chose, ce que 3.3 exige déjà de
## l'écrêtage.
func test_two_walls_equally_close_are_settled_by_anchor_and_not_by_order() -> void:
	var north := POST + Vector2i(0, -1)
	assert_vector(_wall_tie([north, POST + Vector2i(0, 1)])).is_equal(north)
	assert_vector(_wall_tie([POST + Vector2i(0, 1), north])).is_equal(north)

## **Une vague repartie n'annonce rien.** Trouvé en capture et non par un test : la borne
## franchie, le plateau gardait les quatre cases de la dernière manche et l'écran promettait
## des coups qui ne tomberaient jamais.
func test_a_wave_that_has_left_announces_nothing() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", POST + Vector2i(0, -1))
	assert_dict(WaveAI.announce(board)).is_not_empty()
	while not board.is_over():
		board.end_turn()
	assert_dict(WaveAI.announce(board)).is_empty()

# --- ce qu'une annonce engage -----------------------------------------------------------

## **Esquiver annule le coup, et coûte son tour à l'assaillant.** C'est ce que 3.6 achète en
## faisant frapper la case plutôt que la cible, et c'est ce qui fait du déplacement la
## décision centrale plutôt qu'un préambule à l'attaque.
func test_stepping_aside_makes_the_announced_blow_fall_into_the_void() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	var lair := POST + Vector2i(0, -1)
	_foe(board, &"orc", lair)
	WaveAI.declare(board)
	board.move(&"ana", POST + Vector2i(2, 0))
	board.end_turn()
	var blows := WaveAI.play(board)
	assert_int(blows[0].hit()).is_equal(StrikeResult.Hit.NOTHING)
	assert_int(board.body(&"ana").hit_points()).is_equal(board.body(&"ana").stats()
		.hit_points())
	assert_vector(board.body(&"orc").cell()).is_equal(lair)

## Et l'annonce engage jusqu'au bout : si un **autre** corps se trouve sur la case au moment
## de l'exécution, c'est lui qui prend. 3.6 garde la conséquence ouverte en toutes lettres,
## et l'écrit dans ce sens dès maintenant pour n'avoir pas à la retourner le jour où des
## effets de poussée arriveront.
func test_whoever_stands_on_the_announced_cell_takes_the_blow() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_worker(board, &"bo", POST + Vector2i(-1, 0))
	_foe(board, &"orc", POST + Vector2i(0, -1))
	WaveAI.declare(board)
	board.move(&"ana", POST + Vector2i(2, 0))
	board.move(&"bo", POST)
	board.end_turn()
	assert_str(WaveAI.play(board)[0].body()).is_equal("bo")

# --- ce qu'un corps qui avance fait -----------------------------------------------------

## Il se rapproche **puis** frappe, ce que 3.6 autorise en toutes lettres. La cible est prise
## après le pas, donc contre le plateau réel : c'est ce qui fait que le blocage cesse d'être
## un cas à traiter.
func test_an_advancing_body_closes_then_strikes_what_it_finds() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", NORTH_GATE, CombatStats.CONTACT, 5)
	WaveAI.declare(board)
	board.end_turn()
	var blows := WaveAI.play(board)
	assert_vector(board.body(&"orc").cell()).is_equal(POST + Vector2i(0, -1))
	assert_str(blows[0].body()).is_equal("ana")

## **Un tireur ne se colle pas à sa cible.** À rang égal c'est le pas le moins cher qui
## gagne, et non le plus proche : préférer se rapprocher rendrait la portée inutile, alors
## que c'est elle qui lui permet de se poster.
func test_a_shooter_stops_as_soon_as_its_target_is_within_reach() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"archer", NORTH_GATE, 3, 4)
	WaveAI.declare(board)
	board.end_turn()
	WaveAI.play(board)
	assert_vector(board.body(&"archer").cell()).is_equal(POST + Vector2i(0, -3))

## Faute d'ouvrier atteignable, il va manger le mur. C'est le troc de 3.6, et le seul
## comportement qui empêche la stratégie dominante du format — fuir en rond sur une carte
## très majoritairement vide.
func test_an_unreachable_worker_sends_the_wave_at_the_walls() -> void:
	var board := _open()
	_worker(board, &"ana", Vector2i(0, 0))
	_foe(board, &"orc", WALL + Vector2i(0, -2), CombatStats.CONTACT, 2)
	WaveAI.declare(board)
	board.end_turn()
	var blows := WaveAI.play(board)
	assert_int(blows[0].hit()).is_equal(StrikeResult.Hit.BUILDING)
	assert_vector(blows[0].anchor()).is_equal(WALL)

## **Un corps enfermé ne cogne pas l'air.** C'était l'objection qui a écarté le trajet
## annoncé ; en ne déclarant que la nature, un corps qui ne peut rien atteindre ne fait
## simplement rien, et aucun cas particulier n'a eu à être écrit pour lui.
func test_a_body_that_can_reach_nothing_simply_does_nothing() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"siege", Vector2i(0, 0), CombatStats.CONTACT, 0)
	WaveAI.declare(board)
	board.end_turn()
	assert_array(WaveAI.play(board)).is_empty()
	assert_int(board.body(&"ana").hit_points()).is_equal(board.body(&"ana").stats()
		.hit_points())

# --- la manche entière ------------------------------------------------------------------

## `take_turn()` est la seule porte, et l'ordre qu'elle tient compte : la manche se ferme
## **entre** l'exécution et l'annonce suivante. Annoncer avant décrirait un plateau d'une
## manche en retard.
func test_taking_a_turn_closes_the_round_and_announces_the_next_one() -> void:
	var board := _open()
	_worker(board, &"ana", POST)
	_foe(board, &"orc", NORTH_GATE, CombatStats.CONTACT, 5)
	WaveAI.declare(board)
	board.end_turn()
	WaveAI.take_turn(board)
	assert_int(board.side()).is_equal(Combatant.Side.FRIEND)
	assert_int(board.round_number()).is_equal(2)
	assert_bool(board.intent_of(&"orc").is_bound()).is_true()

## **Deux batailles du même seed jouées pareil finissent pareil.** Le déterminisme promis
## depuis `I0` porte désormais sur le rapport entier, ce qu'aucun cas ne vérifiait tant qu'il
## n'y avait pas de producteur.
func test_the_same_seed_played_the_same_way_yields_the_same_report() -> void:
	var first := _skirmish()
	var second := _skirmish()
	assert_int(first.plunder()).is_equal(second.plunder())
	assert_bool(first.swept()).is_equal(second.swept())
	assert_array(first.lost()).is_equal(second.lost())
	assert_array(first.destroyed()).is_equal(second.destroyed())
	assert_dict(first.damaged()).is_equal(second.damaged())

# --- fabrique ---------------------------------------------------------------------------

## Trois manches jouées d'affilée, la vague seule contre un village. Rien n'y est asserté :
## elle sert au cas de déterminisme, qui compare deux exécutions.
func _skirmish() -> DamageReport:
	var board := _open()
	_worker(board, &"ana", WALL + Vector2i(-2, 0))
	_foe(board, &"orc", WALL + Vector2i(0, -3), CombatStats.CONTACT, 3, 2)
	_foe(board, &"pal", WALL + Vector2i(-3, 0), CombatStats.CONTACT, 3, 1)
	WaveAI.declare(board)
	for _round in 3:
		board.end_turn()
		WaveAI.take_turn(board)
	return board.to_report()

## Deux ouvrières à égale distance, dans l'ordre demandé. Rend la case annoncée.
func _tie_between(first: StringName, second: StringName) -> Vector2i:
	var board := _open()
	var west := POST + Vector2i(-1, 0)
	var east := POST + Vector2i(1, 0)
	_worker(board, first, west if first == &"ana" else east)
	_worker(board, second, east if first == &"ana" else west)
	_foe(board, &"orc", POST)
	return WaveAI.announce(board)[&"orc"].cell()

## Deux murs à égale distance, posés dans l'ordre donné. Rend la case annoncée.
func _wall_tie(anchors: Array) -> Vector2i:
	var placed: Array[BuildingSnapshot] = []
	for anchor in anchors:
		placed.append(BuildingSnapshot.create(_make_building(), anchor, 0, 0, 1))
	var board := CombatBoard.open(_make_grid().to_query(), CitySnapshot.create(placed),
		_make_balance(), _make_rng(), ROUNDS)
	_foe(board, &"orc", POST)
	return WaveAI.announce(board)[&"orc"].cell()

func _open() -> CombatBoard:
	return CombatBoard.open(_make_grid().to_query(), _make_city(), _make_balance(),
		_make_rng(), ROUNDS)

func _worker(board: CombatBoard, id: StringName, cell: Vector2i, reach := 1) -> void:
	board.deploy(CombatUnit.create(id, CombatUnit.BASE_EFFICIENCY,
		CombatStats.create(10, 2, 2, reach, 3, 1)), cell)

func _foe(board: CombatBoard, id: StringName, cell: Vector2i, reach := 1, move := 2,
		loot := 0) -> void:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.label = String(id).capitalize()
	enemy.hit_points = 8
	enemy.damage_min = 3
	enemy.damage_max = 3
	enemy.reach = reach
	enemy.move = move
	enemy.climb = 1
	enemy.plunder = loot
	board.send(id, enemy, cell)

func _make_city() -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(_make_building(), WALL, 0, 0, 1)]
	return CitySnapshot.create(placed)

func _make_building() -> BuildingData:
	var data := BuildingData.new()
	data.id = &"hut"
	data.hit_points = WALL_HP
	data.build_actions = 1
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return data

func _make_grid() -> HeightGrid:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	return HeightGrid.create(EXTENT, 0, plain)

func _make_balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.climb_cost = 1
	balance.impassable_tags = [&"water"] as Array[StringName]
	balance.spawn_margin = 2
	balance.combat_skill_family = &"combat"
	return balance

func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng
