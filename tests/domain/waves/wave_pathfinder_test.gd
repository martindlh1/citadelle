class_name WavePathfinderTest
extends GdUnitTestSuite
## Le chemin d'une vague, sur des grilles **fabriquées à la main**.
##
## C'est la consigne de `DESIGN.md` pour ce jalon en toutes lettres — « un chemin se vérifie sur
## une grille fabriquée à la main » — et elle vaut ici plus qu'ailleurs : ce que ce fichier
## éprouve est un **arbitrage de coûts**, et sur une carte générée on ne saurait pas dire quel
## chemin *aurait dû* gagner.
##
## Le montage de base est une plaine nue de 9 x 9 à hauteur zéro, la vague entrant par toute la
## colonne de gauche et visant (8, 4). Chaque cas pose le relief ou le bâti qui l'intéresse et
## connaît donc la réponse avant de la demander.
##
##     x=0                    x=8
##     →  .  .  .  .  .  .  .  .
##     →  .  .  .  .  .  .  .  .
##     →  .  .  .  .  .  .  .  .
##     →  .  .  .  .  .  .  .  ♥   y=4
##     →  .  .  .  .  .  .  .  .

const SIZE := Vector2i(9, 9)
const HEART := Vector2i(8, 4)
const STEP := 10
const CLIMB := 6
const BREACH := 120

var _plain: TerrainData
var _water: TerrainData
var _rock: TerrainData
var _grid: HeightGrid
var _city: CityState

func before_test() -> void:
	_plain = _terrain(&"plain", TerrainData.Build.ALLOWED, TerrainData.Walk.ALLOWED)
	_water = _terrain(&"water", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED)
	_rock = _terrain(&"rock", TerrainData.Build.BLOCKED, TerrainData.Walk.BLOCKED)
	_grid = HeightGrid.create(SIZE, 0, _plain)
	_city = CityState.new()

# --- le chemin nu ------------------------------------------------------------

## Sur une plaine vide, le chemin est la ligne droite, et il coûte un pas par case franchie.
## Le compte des cases inclut le départ **et** le Cœur ; le coût, lui, ne paie que les pas.
func test_a_bare_plain_gives_a_straight_line() -> void:
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_int(path.length()).is_equal(9)
	assert_int(path.cost()).is_equal(8 * STEP)
	assert_vector(path.cells()[0]).is_equal(Vector2i(0, 4))
	assert_vector(path.cells()[8]).is_equal(HEART)

## La vague entre par **la meilleure** case de la lisière et non par celle qu'on lui donne en
## premier : les sources sont toutes empilées au départ, donc un seul parcours les départage.
func test_the_wave_picks_its_way_in() -> void:
	# Un mur d'eau sur toute la colonne 1 sauf en (1, 0) : une seule entrée mène quelque part.
	for y in range(1, SIZE.y):
		_grid.set_cell(Vector2i(1, y), 0, _water)
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_vector(path.cells()[0]) \
		.override_failure_message("la vague devait entrer par la seule case qui passe") \
		.is_equal(Vector2i(0, 0))

## Un Cœur qu'aucun chemin n'atteint rend un chemin **vide** et non `null` : l'appelant lit
## alors zéro case au lieu de distinguer deux cas. Et il y a une conclusion à en tirer — un
## village invincible est pire qu'injouable, parce que rien ne le signale.
func test_a_walled_off_heart_is_reported_as_unreachable() -> void:
	for y in SIZE.y:
		_grid.set_cell(Vector2i(4, y), 0, _rock)
	var path := _find()
	assert_bool(path.reaches()).is_false()
	assert_int(path.length()).is_equal(0)
	assert_array(path.cells()).is_empty()

# --- ce qui barre, ce qui coûte ----------------------------------------------

## L'eau et le rocher barrent : la vague les contourne, quel qu'en soit le prix.
func test_water_and_rock_are_walked_around() -> void:
	_grid.set_cell(Vector2i(4, 4), 0, _water)
	_grid.set_cell(Vector2i(4, 3), 0, _rock)
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_bool(path.passes_through(Vector2i(4, 4))).is_false()
	assert_bool(path.passes_through(Vector2i(4, 3))).is_false()

## **Une marche trop haute barre**, et c'est la même question que `MapAudit` pose pour compter
## ses accès : deux définitions de « ça passe » auraient fini par diverger, et la carte aurait
## promis des cols qu'aucune vague n'emprunte.
func test_a_step_too_high_blocks() -> void:
	for y in SIZE.y:
		_grid.set_height(Vector2i(4, y), _enemy().climb + 1)
	assert_bool(_find().reaches()) \
		.override_failure_message("une falaise d'un cran de trop devait tout barrer") \
		.is_false()

## **La montée coûte, la descente est gratuite.** C'est la lecture de DESIGN.md 3.5, et elle a
## une conséquence de jeu : un village haut perché est naturellement plus loin qu'il n'en a
## l'air, sans qu'aucune règle ne le dise.
func test_climbing_costs_and_descending_does_not() -> void:
	var flat := _find().cost()
	# Une terrasse d'un cran sur la moitié droite : on la monte une fois, et on n'en redescend
	# pas — le Cœur est dessus.
	for y in SIZE.y:
		for x in range(4, SIZE.x):
			_grid.set_height(Vector2i(x, y), 1)
	assert_int(_find().cost()) \
		.override_failure_message("un cran gravi doit coûter exactement climb_cost de plus") \
		.is_equal(flat + CLIMB)

## Le pendant : une butte qu'on gravit **et** redescend ne coûte qu'une montée, donc la vague
## préfère la contourner dès que le détour est moins cher qu'elle.
##
## **Une seule entrée**, et c'est ce cas qui l'a appris : avec toute la lisière ouverte, la
## vague ne contourne pas la bosse — elle entre une ligne plus haut et ne la rencontre jamais.
## Le détour était alors gratuit, et le cas mesurait le choix de l'entrée au lieu du prix de la
## montée. Une grille fabriquée à la main ne suffit pas si l'on y laisse une porte de trop.
##
## **Et l'enjambée est relevée exprès**, ce qui est la seconde chose que ce cas a apprise : une
## bosse de trois crans sous une enjambée de deux n'est pas *chère*, elle est **infranchissable**,
## et le détour n'y prouve plus rien du prix de la montée. Ce sont deux règles différentes — le
## cas au-dessus mesure celle qui barre, celui-ci celle qui coûte —, et il fallait les séparer
## pour que chacune montre ce qu'elle annonce.
func test_a_hill_is_walked_around_when_the_detour_is_cheaper() -> void:
	var nimble := _enemy()
	nimble.climb = 4
	# Une bosse sur la seule case (4, 4) : la gravir coûte autant de fois CLIMB qu'elle a de
	# crans, la contourner coûte deux pas de plus, soit 20.
	_grid.set_height(Vector2i(4, 4), 3)
	assert_bool(_find_with(nimble).passes_through(Vector2i(4, 4))) \
		.override_failure_message("18 de montée contre 20 de détour : la bosse devait gagner") \
		.is_true()
	_grid.set_height(Vector2i(4, 4), 4)
	assert_bool(_find_with(nimble).passes_through(Vector2i(4, 4))) \
		.override_failure_message("24 de montée contre 20 de détour : le détour devait gagner") \
		.is_false()

# --- le troc du mur ----------------------------------------------------------

## **Le cas qui porte le jalon.** Un mur qui laisse un détour court se contourne : `DESIGN.md`
## veut que boucher soit un troc, pas une astuce.
func test_a_wall_with_a_short_way_round_is_walked_around() -> void:
	_wall_across(range(3, 6))
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_array(path.breached()) \
		.override_failure_message("deux cases de détour valent mieux que 120 de mur") \
		.is_empty()

## Et le mur qui ferme tout se **perce** : la vague paie son prix plutôt que de renoncer.
func test_a_wall_that_closes_everything_is_breached() -> void:
	_wall_across(range(SIZE.y))
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_bool(path.passes_through(Vector2i(4, 4))) \
		.override_failure_message("le mur barre partout : il fallait le percer") \
		.is_true()
	assert_int(path.cost()).is_equal(8 * STEP + BREACH)

## **Le seuil n'existe nulle part : il est le prix.** Même carte, même détour, deux valeurs de
## patience de part et d'autre — et la vague bascule sans qu'aucune règle ne le dise.
##
## C'est le **prix** qu'on fait varier et non la géométrie, parce que c'est lui le sujet : un
## seuil écrit à côté du chemin aurait rendu ce cas vert en étant faux là où deux détours se
## valent.
func test_the_wave_breaches_exactly_when_the_detour_costs_more() -> void:
	_corridor_with_gate_at(0)
	# Le détour par la porte coûte huit pas de plus que la ligne droite : 80.
	var detour := 80
	assert_int(_find_with(_priced(detour + 20)).cost()) \
		.override_failure_message("mur plus cher que le détour : il fallait contourner") \
		.is_equal(8 * STEP + detour)
	assert_array(_find_with(_priced(detour + 20)).breached()).is_empty()

	var cheap := _find_with(_priced(detour - 20))
	assert_array(cheap.breached()) \
		.override_failure_message("mur moins cher que le détour : il fallait percer") \
		.is_equal([Vector2i(2, 4)])
	assert_int(cheap.cost()).is_equal(8 * STEP + detour - 20)

## Un mur de deux cases d'épaisseur coûte deux brèches : percer un mur épais est plus cher que
## percer un mur mince, ce qui est la lecture qu'on veut d'une palissade.
func test_a_thick_wall_costs_two_breaches() -> void:
	_wall_across(range(SIZE.y))
	_wall_across(range(SIZE.y), 5)
	assert_int(_find().cost()).is_equal(8 * STEP + 2 * BREACH)

## **Elle ne se détourne pas pour manger.** Une ferme posée à côté du chemin ne rapporte rien à
## la vague, donc elle ne va pas la chercher : c'est ce qui fait du chemin toute l'histoire.
func test_the_wave_never_detours_to_eat() -> void:
	_place(_building(&"farm", [Vector2i.ZERO] as Array[Vector2i]), Vector2i(4, 2))
	var path := _find()
	assert_array(path.breached()).is_empty()
	assert_int(path.cost()).is_equal(8 * STEP)

## Les bâtiments percés se rendent par leur **ancre** et sans doublon : ce que `V2` en fera est
## de les retirer, et une empreinte traversée en son milieu ne doit pas être mangée deux fois.
func test_a_breached_building_is_named_once_by_its_anchor() -> void:
	# Un mur de deux cases de large, d'un seul bâtiment, qui ferme toute la carte.
	for y in SIZE.y:
		if y == 4:
			continue
		_grid.set_cell(Vector2i(4, y), 0, _rock)
	var wide: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	_place(_building(&"gate", wide), Vector2i(4, 4))
	var path := _find()
	assert_bool(path.reaches()).is_true()
	assert_array(path.breached()) \
		.override_failure_message("une empreinte traversée de part en part se nomme une fois") \
		.is_equal([Vector2i(4, 4)])

## Le Cœur lui-même n'est pas un mur : lui donner le prix d'une brèche ferait préférer un détour
## à une vague déjà arrivée.
func test_the_heart_is_an_arrival_and_not_an_obstacle() -> void:
	_place(_building(&"heart", [Vector2i.ZERO] as Array[Vector2i]), HEART)
	var path := _find()
	assert_int(path.cost()).is_equal(8 * STEP)
	assert_array(path.breached()).is_empty()

## Toucher **une** case du Cœur suffit : une empreinte de deux par deux n'a pas de bonne case
## d'arrivée, et exiger l'ancre ferait faire le tour du bâtiment à une vague qui l'a déjà atteint.
func test_touching_any_cell_of_the_heart_ends_the_walk() -> void:
	var square: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1)]
	_place(_building(&"heart", square), Vector2i(7, 4))
	var path := _find(Vector2i(8, 5))
	assert_bool(path.reaches()).is_true()
	assert_vector(path.cells()[path.length() - 1]) \
		.override_failure_message("la marche devait s'arrêter à la première case du Cœur") \
		.is_equal(Vector2i(7, 4))

# --- le déterminisme ---------------------------------------------------------

## Deux appels sur la même carte rendent le même chemin. Sans ça, rien de ce qui en dépend —
## une bataille, une table, une capture — n'est reproductible.
func test_the_same_map_gives_the_same_path() -> void:
	_grid.set_height(Vector2i(4, 4), 2)
	_wall_across(range(2, 7))
	assert_array(_find().cells()).is_equal(_find().cells())

# --- le montage --------------------------------------------------------------

func _find(heart := HEART) -> WavePath:
	var sources: Array[Vector2i] = []
	for y in SIZE.y:
		sources.append(Vector2i(0, y))
	return WavePathfinder.find(_grid.to_query(), _city.to_snapshot(), heart, sources,
		_balance(), _enemy())

func _balance() -> WaveBalance:
	var balance := WaveBalance.new()
	balance.step_cost = STEP
	balance.climb_cost = CLIMB
	return balance

## L'assaillant du montage : sa patience et son enjambée sont à lui, l'échelle est à
## l'équilibrage. C'est le partage que `V2` a corrigé — un bélier traverse un mur là où une
## meute le contourne.
func _enemy() -> EnemyDef:
	var enemy := EnemyDef.new()
	enemy.id = &"raider"
	enemy.label = "Pillard"
	enemy.hit_points = 10
	enemy.ticks_per_cell = 1
	enemy.damage = 1
	enemy.patience = BREACH
	enemy.climb = 2
	return enemy

## Une palissade d'une case par ligne de `rows`, sur la colonne `column`.
func _wall_across(rows, column := 4) -> void:
	for y in rows:
		_place(_building(&"wall_%d_%d" % [column, y], [Vector2i.ZERO] as Array[Vector2i]),
			Vector2i(column, y))

## Une barre de roche sur la colonne 2, percée de deux passages : un mur en (2, 4) sur la ligne
## droite, et une porte libre en `gate`. La vague a donc exactement deux façons de passer, et
## leur écart est connu d'avance.
func _corridor_with_gate_at(gate: int) -> void:
	for y in SIZE.y:
		if y != 4 and y != gate:
			_grid.set_cell(Vector2i(2, y), 0, _rock)
	_place(_building(&"wall", [Vector2i.ZERO] as Array[Vector2i]), Vector2i(2, 4))

## Le même assaillant, avec une autre patience.
##
## C'est **la créature** qu'on fait varier et non l'échelle, depuis que `V2` a rendu la patience
## à son propriétaire — et c'est plus juste : deux sortes d'assaillants devant le même mur ne
## prennent pas la même décision.
func _priced(patience: int) -> EnemyDef:
	var enemy := _enemy()
	enemy.patience = patience
	return enemy

## Le chemin de cet assaillant-là, en entrant par la seule case de la ligne du Cœur.
##
## Une seule entrée, à l'inverse de `_find()` : les cas qui mesurent un arbitrage de prix veulent
## que le détour coûte ce qu'ils croient, et une lisière ouverte offre toujours une porte de
## plus.
func _find_with(enemy: EnemyDef) -> WavePath:
	var sources: Array[Vector2i] = [Vector2i(0, 4)]
	return WavePathfinder.find(_grid.to_query(), _city.to_snapshot(), HEART, sources,
		_balance(), enemy)

## Pose ce bâtiment, en passant par la porte que la ville offre à tout le monde.
##
## Le montage **vérifie sa propre prémisse** : un placement refusé — hors emprise depuis `C7`,
## sur du rocher, à cheval sur une marche — rendrait une ville vide et un cas parfaitement vert
## qui ne prouverait rien du chemin.
func _place(data: BuildingData, anchor: Vector2i) -> void:
	var result := _city.place(_grid.to_query(), data, anchor)
	assert_bool(result.is_ok()) \
		.override_failure_message("le montage n'a pas posé %s en %s : %s"
			% [data.id, anchor, result.reason()]) \
		.is_true()

func _building(id: StringName, offsets: Array[Vector2i]) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.footprint = offsets
	data.hit_points = 1
	data.reach = 1
	return data

func _terrain(id: StringName, build: TerrainData.Build,
		walk: TerrainData.Walk) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = build
	data.walk = walk
	return data
