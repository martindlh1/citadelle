class_name RunOrchestratorTest
extends GdUnitTestSuite
## Les quatre gestes d'un tour, et l'ordre dans lequel un tour se résout.
##
## C'est la suite qui porte I3. Deux cas la portent elle-même, et ils sont marqués : l'ordre
## a-b de DESIGN.md 2, et l'**interdit de blocage** joué de bout en bout — N1 avait prouvé
## que la soupape existait, celui-ci prouve qu'on peut s'en servir.
##
## ---
##
## **L'équilibrage est chargé depuis data/ puis surchargé**, pour la raison exposée dans
## run_state_test.gd : RunState.open() refuse un BalanceData incomplet, et remplir à la main
## les trois blocs qui ne regardent pas le run serait une trentaine de champs de bruit.
## Aucun chiffre de data/ n'est donc figé ici — les deux blocs qui comptent sont remplacés
## entièrement, et rien n'est assert sur les trois autres.
##
## **Les bâtiments sont fabriqués et non chargés**, pour la raison inverse : les cas parlent
## de règles, et un coût de data/ qui bouge à B1 les casserait tous.

const SIZE := Vector2i(8, 8)
const HEART := Vector2i(0, 0)

## Le tag que les producteurs de ce fichier cherchent, et le pas de son semis.
const SOIL_TAG := &"soil"
const SOIL_STRIDE := 3
const HEART_HIT_POINTS := 40

## Cellules libres hors de l'empreinte 2x2 du Cœur.
const A := Vector2i(3, 3)
const B := Vector2i(4, 3)
const C := Vector2i(5, 3)
const D := Vector2i(6, 3)

var _grid: HeightGrid
var _balance: BalanceData

func before_test() -> void:
	_grid = _flat_grid()
	_balance = _make_balance(_economy(), _run())

## Sol nu, semé d'un tag tous les trois pas.
##
## **Trois exactement, et c'est ce qui fait tenir tous les chiffres de ce fichier.** Depuis C3
## un bâtiment ne produit que par voisinage : il lui faut donc une case taggée à portée, sans
## quoi le placement le refuse et la récolte est nulle. Or trois entiers consécutifs contiennent
## toujours un et un seul multiple de trois — donc la zone de rayon 1 d'un bâtiment d'une case
## en contient exactement un, **où qu'il soit posé**. « +3 nourriture » reste « +3 nourriture »
## et aucune attente n'a eu à bouger.
##
## Un semis uniforme aurait rendu neuf cases par zone, un semis clairsemé zéro ici et deux là :
## dans les deux cas, ce fichier se serait mis à mesurer la géométrie du sol au lieu du tour.
func _flat_grid() -> HeightGrid:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	plain.color = Color(0.4, 0.6, 0.3)
	var soil := TerrainData.new()
	soil.id = SOIL_TAG
	soil.build = TerrainData.Build.ALLOWED
	soil.color = Color(0.5, 0.45, 0.3)
	soil.tags.append(SOIL_TAG)
	var grid := HeightGrid.create(SIZE, 0, plain)
	for y in range(0, SIZE.y, SOIL_STRIDE):
		for x in range(0, SIZE.x, SOIL_STRIDE):
			grid.set_terrain(Vector2i(x, y), soil)
	return grid

func _make_balance(economy: EconomyBalance, run: RunBalance) -> BalanceData:
	var balance := (load("res://data/balance/balance.tres") as BalanceData).duplicate()
	balance.economy = economy
	balance.run = run
	return balance

func _economy(food := 20, wood := 50, housing := 6, population := 4,
		cap := 100) -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = cap
	economy.base_housing = housing
	economy.starting_population = population
	economy.upkeep_per_inhabitant = 1
	economy.upkeep_resource = &"food"
	var stock: Dictionary[StringName, int] = {}
	if food > 0:
		stock[&"food"] = food
	if wood > 0:
		stock[&"wood"] = wood
	economy.starting_stock = stock
	return economy

func _run(turns := 20) -> RunBalance:
	var run := RunBalance.new()
	run.turns = turns
	run.starting_building = &"heart"
	run.score_per_resource = 1
	run.score_per_building = 5
	run.score_per_inhabitant = 10
	run.score_per_heart_hit_point = 2
	return run

## `site_turns` à 0 veut dire « achevé à la pose », ce qui est la valeur du Cœur dans
## DESIGN.md 4.1 et non un cas dégénéré. Deux bâtiments du catalogue de test s'en servent,
## pour produire dès le tour où on les pose.
func _building(id: StringName, footprint: Array[Vector2i], site_turns: int, workers: int,
		cost: Dictionary[StringName, int], yields: Dictionary[StringName, int],
		housing := 0, storage := 0, hit_points := 6) -> BuildingData:
	var data := BuildingData.new()
	# Une emprise large, pour que la règle d'emprise de `C7` ne se mette pas en travers des
	# cas qui parlent d'autre chose : un `reach` laissé à zéro n'ouvrirait même pas la case
	# voisine, et toute ville de plus d'un bâtiment serait refusée.
	data.reach = 12
	data.id = id
	data.footprint = footprint
	data.site_turns = site_turns
	data.workers = workers
	data.cost = cost
	data.housing = housing
	data.storage_bonus = storage
	data.hit_points = hit_points
	# Ce que le bâtiment rendait à plat devient une règle de voisinage par ressource : depuis
	# C3 il n'y a plus d'autre source de production. Le tag est celui que `_ground()` pose sous
	# chaque ancre, une case et une seule, de sorte que « +3 nourriture » reste « +3
	# nourriture » et qu'aucune attente de ce fichier n'ait à bouger.
	for resource in yields:
		var rule := AdjacencyRule.new()
		rule.tag = SOIL_TAG
		rule.radius = 1
		rule.resource = resource
		rule.per_cell = yields[resource]
		data.adjacency.append(rule)
	return data

func _catalogue() -> Dictionary[StringName, BuildingData]:
	var square: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(1, 1)]
	var one: Array[Vector2i] = [Vector2i.ZERO]
	var none: Dictionary[StringName, int] = {}
	return {
		# Posé au départ, gratuit en tout, achevé à la pose.
		&"heart": _building(&"heart", square, 0, 0, none, none, 4, 0, HEART_HIT_POINTS),
		# Deux bras, un tour, gratuit : le chantier le plus court du catalogue.
		&"hut": _building(&"hut", one, 1, 2, none,
			{&"wood": 2} as Dictionary[StringName, int]),
		# Quatre bras, deux tours, dix bois : le gros consommateur de main-d'œuvre.
		&"farm": _building(&"farm", one, 2, 4,
			{&"wood": 10} as Dictionary[StringName, int],
			{&"food": 3} as Dictionary[StringName, int]),
		# **Zéro bras**, et c'est la soupape de DESIGN.md 3.4.
		&"house": _building(&"house", one, 2, 0,
			{&"wood": 20} as Dictionary[StringName, int], none, 4),
		# Un bras, un tour : il relève la réserve de cent au moment où il s'achève.
		&"store": _building(&"store", one, 1, 1,
			{&"wood": 20} as Dictionary[StringName, int], none, 0, 100),
		# Achevé à la pose et gratuit en bras : il produit dès le tour de sa pose, ce dont
		# l'ordre a-b a besoin pour être observable.
		&"quarry": _building(&"quarry", one, 0, 0, none,
			{&"stone": 5} as Dictionary[StringName, int]),
	} as Dictionary[StringName, BuildingData]

func _open() -> RunState:
	return RunState.open(1234, _grid, _catalogue(), _balance)

## Run dont le Cœur est posé en HEART : l'état de départ de tous les cas de tour.
func _founded() -> RunState:
	var state := _open()
	var result := RunOrchestrator.found(state, HEART)
	assert_bool(result.is_ok()) \
		.override_failure_message("le montage n'a pas réussi à fonder le village") \
		.is_true()
	return state

# --- la fondation ------------------------------------------------------------

func test_founding_places_the_heart_and_stops_the_wait() -> void:
	var state := _open()
	var result := RunOrchestrator.found(state, HEART)
	assert_bool(result.is_ok()).is_true()
	assert_vector(result.anchor()).is_equal(HEART)
	assert_bool(state.awaits_its_heart()).is_false()
	assert_vector(state.heart_anchor()).is_equal(HEART)
	assert_int(state.city().count()).is_equal(1)

## « C'est la seule pose gratuite du jeu, et elle l'est parce qu'elle est le jeu qui
## commence. » Le facturer ferait dépendre l'ouverture d'un run du stock de départ.
func test_founding_costs_nothing() -> void:
	var state := _open()
	var before := state.ledger().total()
	RunOrchestrator.found(state, HEART)
	assert_int(state.ledger().total()).is_equal(before)

## Le Cœur loge, donc il relève le plafond **au moment où il est posé** et non au tour
## suivant : les plafonds sont réaccordés par le geste qui change la ville.
func test_founding_raises_the_housing_cap_at_once() -> void:
	var state := _open()
	assert_int(state.people().places()).is_equal(6)
	RunOrchestrator.found(state, HEART)
	assert_int(state.people().places()).is_equal(10)

func test_a_second_founding_is_refused() -> void:
	var state := _founded()
	var result := RunOrchestrator.found(state, C)
	assert_bool(result.is_ok()).is_false()
	assert_str(String(result.reason())).is_equal("already_founded")

## Les raisons de PlacementResult traversent **telles quelles** : c'est ce que son docstring
## annonçait depuis C1, et c'est pourquoi elles sont des StringName et non un enum.
func test_founding_off_the_map_gives_the_placement_reason() -> void:
	var result := RunOrchestrator.found(_open(), Vector2i(99, 99))
	assert_str(String(result.reason())).is_equal("out_of_bounds")

# --- ouvrir un chantier ------------------------------------------------------

func test_nothing_can_be_built_before_the_heart_is_placed() -> void:
	var result := RunOrchestrator.open_site(_open(), &"hut", A)
	assert_str(String(result.reason())).is_equal("no_heart")

## « Un chantier paie tout à l'ouverture, ressources et travailleurs. » Le premier se lit sur
## la réserve, le second sur le plan d'occupation — et **les bras ne sont écrits nulle part**,
## ce qui est le meilleur signe que le modèle de N1 est le bon.
func test_opening_a_site_pays_its_resources_and_takes_its_hands_at_once() -> void:
	var state := _founded()
	var result := RunOrchestrator.open_site(state, &"farm", A)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.workers()).is_equal(4)
	assert_dict(result.spent()).is_equal({&"wood": 10} as Dictionary[StringName, int])
	assert_int(state.ledger().amount(&"wood")).is_equal(40)
	assert_int(state.staffing().committed()).is_equal(4)
	assert_int(state.staffing().available()).is_equal(0)
	assert_int(state.open_sites()).is_equal(1)

## Le Cœur se fonde, il ne se bâtit pas. Il est gratuit, sans chantier, et loge quatre
## personnes : pouvoir en poser un second en ferait le meilleur bâtiment du jeu, et rendrait
## décoratif le refus d'une seconde fondation. Trouvé en capture, sur un catalogue de harnais
## qui le proposait au clic comme les autres.
func test_a_second_heart_cannot_be_built() -> void:
	var state := _founded()
	var result := RunOrchestrator.open_site(state, &"heart", A)
	assert_str(String(result.reason())).is_equal("the_heart")
	assert_int(state.city().count()).is_equal(1)

func test_an_unknown_building_is_refused() -> void:
	var result := RunOrchestrator.open_site(_founded(), &"cathedral", A)
	assert_str(String(result.reason())).is_equal("unknown_building")

func test_a_site_on_an_occupied_cell_is_refused() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"hut", A)
	var result := RunOrchestrator.open_site(state, &"hut", A)
	assert_str(String(result.reason())).is_equal("occupied")

## Rien ne borne le nombre de chantiers ouverts **en dehors des bras**, depuis que la file de
## chantiers est retirée. Le cas est écrit à l'endroit où le refus vivait, pour que personne
## ne la réintroduise en croyant corriger un oubli : un bâtiment gratuit en bras s'ouvre
## autant de fois que la réserve et la place au sol le permettent.
func test_nothing_but_hands_limits_how_many_sites_are_open() -> void:
	# Assez de bois pour quatre habitations : le cas parle des bras, et une réserve trop
	# courte le ferait passer sur le mauvais refus.
	_balance = _make_balance(_economy(20, 80), _run())
	var state := _founded()
	for cell in [A, B, C, D]:
		assert_bool(RunOrchestrator.open_site(state, &"house", cell).is_ok()) \
			.override_failure_message("l'habitation en %s a été refusée" % cell) \
			.is_true()
	assert_int(state.open_sites()).is_equal(4)
	assert_int(state.staffing().committed()).is_equal(0)

func test_a_village_without_free_hands_cannot_open_a_site() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	var result := RunOrchestrator.open_site(state, &"hut", B)
	assert_str(String(result.reason())).is_equal("not_enough_workers")

func test_an_empty_purse_refuses_a_site() -> void:
	_balance = _make_balance(_economy(20, 5), _run())
	var state := _founded()
	var result := RunOrchestrator.open_site(state, &"farm", A)
	assert_str(String(result.reason())).is_equal("not_enough_resources")

## L'ordre des refus est une décision : la **carte** passe avant les trois coûts, parce que
## c'est elle qu'un joueur corrige en bougeant la souris et parce que le fantôme l'affiche
## déjà. Une cellule prise **et** impayable rend donc « occupied ».
func test_the_map_answers_before_the_costs_do() -> void:
	_balance = _make_balance(_economy(20, 5), _run())
	var state := _founded()
	RunOrchestrator.open_site(state, &"hut", A)
	var result := RunOrchestrator.open_site(state, &"farm", A)
	assert_str(String(result.reason())).is_equal("occupied")

## Le refus ne laisse **aucune trace** : ni la réserve ni la ville ne bougent. C'est la même
## garantie que CityState.place() donne depuis C1, remontée d'un cran.
func test_a_refused_site_changes_nothing() -> void:
	var state := _founded()
	var wood := state.ledger().amount(&"wood")
	RunOrchestrator.open_site(state, &"farm", Vector2i(99, 99))
	assert_int(state.ledger().amount(&"wood")).is_equal(wood)
	assert_int(state.city().count()).is_equal(1)

# --- la résolution d'un tour -------------------------------------------------

func test_a_turn_advances_the_open_sites_and_finishes_them() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"hut", A)
	var report := RunOrchestrator.end_turn(state)
	assert_array(report.advanced()).is_equal([A])
	assert_array(report.completed()).is_equal([A])
	assert_array(report.stalled()).is_empty()
	assert_int(state.open_sites()).is_equal(0)

## Un chantier de deux tours avance sans finir au premier : avancé oui, achevé non. Les deux
## listes sont rendues séparément parce qu'elles ne disent pas la même chose à l'écran.
func test_a_two_turn_site_advances_before_it_finishes() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	var first := RunOrchestrator.end_turn(state)
	assert_array(first.advanced()).is_equal([A])
	assert_array(first.completed()).is_empty()
	var second := RunOrchestrator.end_turn(state)
	assert_array(second.completed()).is_equal([A])

func test_a_finished_building_pays_from_the_turn_after_it_is_done() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"hut", A)
	var first := RunOrchestrator.end_turn(state)
	assert_bool(first.production().is_empty()).is_true()
	var second := RunOrchestrator.end_turn(state)
	assert_int(second.production().produced()[&"wood"]).is_equal(2)

func test_the_meal_takes_one_per_head_and_the_report_says_so() -> void:
	var state := _founded()
	var report := RunOrchestrator.end_turn(state)
	assert_int(report.upkeep().due()).is_equal(4)
	assert_int(report.upkeep().paid()).is_equal(4)
	assert_int(state.ledger().amount(&"food")).is_equal(16)

func test_a_turn_that_leaves_food_and_a_bed_brings_someone_in() -> void:
	var state := _founded()
	var report := RunOrchestrator.end_turn(state)
	assert_int(report.upkeep().arrived()).is_equal(1)
	assert_int(state.people().headcount()).is_equal(5)

func test_the_turn_counter_moves_on() -> void:
	var state := _founded()
	assert_int(state.turn()).is_equal(1)
	var report := RunOrchestrator.end_turn(state)
	assert_int(report.turn()).is_equal(1)
	assert_int(state.turn()).is_equal(2)
	assert_object(state.last_report()).is_same(report)

# --- L'ORDRE A-B, la règle héritée qui survit intacte ------------------------

## **Le cas qui porte la moitié du jalon.** DESIGN.md 2 : « La production se calcule sur la
## ville d'avant l'avancement des chantiers, sans quoi un entrepôt achevé ce tour-ci
## relèverait la réserve du même tour, et l'ordre dans lequel les chantiers ont été lancés
## déciderait du résultat. »
##
## Le montage met les deux moitiés en tension dans **le même tour** : une réserve à deux
## unités du plafond, une carrière qui rend cinq, et un entrepôt qui s'achève ce tour-ci.
## Si l'ordre était b-a, la carrière déposerait sous un plafond de 200 et rien ne serait
## écrêté.
##
## Les deux prémisses sont vérifiées plutôt que supposées — que l'entrepôt s'achève bien ce
## tour, et que le plafond monte bien ensuite —, sans quoi le cas passerait aussi sur un
## entrepôt qui n'a jamais fini.
func test_production_runs_on_the_city_from_before_the_sites_advance() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"quarry", A)
	RunOrchestrator.open_site(state, &"store", B)
	state.ledger().add(&"stone", state.ledger().free_space() - 2)
	assert_int(state.ledger().free_space()).is_equal(2)

	var report := RunOrchestrator.end_turn(state)

	assert_array(report.completed()) \
		.override_failure_message("l'entrepôt ne s'est pas achevé ce tour : le cas ne prouve rien") \
		.is_equal([B])
	assert_int(state.ledger().capacity()) \
		.override_failure_message("le plafond n'a pas monté : le cas ne prouve rien") \
		.is_equal(200)
	assert_int(report.production().produced()[&"stone"]).is_equal(5)
	assert_int(report.production().stored()[&"stone"]).is_equal(2)
	assert_int(report.production().overflow()).is_equal(3)

## Le corollaire de l'ordre a-b : deux villes identiques bâties dans un ordre différent
## rendent la même chose. La contrainte ne vaut que **si rien ne dort** — voir le cas
## suivant, où l'ordre décide, et c'est la règle.
func test_two_villages_built_in_a_different_order_end_up_identical() -> void:
	_balance = _make_balance(_economy(60, 60, 20, 12, 200), _run())
	var first := _founded()
	RunOrchestrator.open_site(first, &"hut", A)
	RunOrchestrator.open_site(first, &"farm", B)
	var second := _founded()
	RunOrchestrator.open_site(second, &"farm", B)
	RunOrchestrator.open_site(second, &"hut", A)
	for _turn in 4:
		RunOrchestrator.end_turn(first)
		RunOrchestrator.end_turn(second)
	assert_dict(first.ledger().amounts()).is_equal(second.ledger().amounts())
	assert_int(first.people().headcount()).is_equal(second.people().headcount())

## L'exception, et c'en est une **règle** : quand les bras manquent, l'ordre de pose décide
## qui dort, parce que « l'ordre de construction est la priorité que le joueur a exprimée ».
## Le cas est écrit pour que personne ne lise le précédent comme une promesse générale.
func test_when_hands_are_short_the_order_decides_who_sleeps() -> void:
	var first := _founded()
	RunOrchestrator.open_site(first, &"hut", A)
	RunOrchestrator.end_turn(first)
	var second := _founded()
	RunOrchestrator.open_site(second, &"hut", A)
	RunOrchestrator.end_turn(second)
	# Deux huttes de plus chacun, dans un ordre inverse, alors qu'il ne reste des bras que
	# pour une seule.
	RunOrchestrator.open_site(first, &"hut", B)
	RunOrchestrator.open_site(second, &"hut", C)
	assert_array(first.staffing().asleep()).is_empty()
	assert_array(second.staffing().asleep()).is_empty()
	first.people().shrink(3)
	second.people().shrink(3)
	assert_array(first.staffing().asleep()).is_equal([B])
	assert_array(second.staffing().asleep()).is_equal([C])

# --- ce qu'une famine coûte au-delà de la récolte ---------------------------

## « Un chantier endormi n'avance pas » est la même règle que « un bâtiment endormi ne
## produit rien », dite pour l'autre moitié de la ville. C'est la moitié la plus coûteuse :
## une famine ne suspend pas seulement une récolte, elle **allonge** tout ce qui est en cours.
func test_a_dormant_site_does_not_advance() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	state.people().shrink(2)
	var report := RunOrchestrator.end_turn(state)
	assert_array(report.stalled()).is_equal([A])
	assert_array(report.advanced()).is_empty()
	assert_int(state.city().building_at(A).progress()).is_equal(0)

## Le pendant : dès que les bras reviennent, le chantier repart tout seul. Rien n'a été
## mémorisé, donc il n'y a rien à réveiller.
func test_a_site_starts_again_on_its_own_when_the_hands_come_back() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	state.people().shrink(2)
	RunOrchestrator.end_turn(state)
	state.people().grow(2)
	assert_array(RunOrchestrator.end_turn(state).advanced()).is_equal([A])

# --- démolir -----------------------------------------------------------------

func test_demolishing_frees_the_cells_and_the_hands() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	var result := RunOrchestrator.demolish(state, A)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.workers()).is_equal(4)
	assert_bool(state.city().is_occupied(A)).is_false()
	assert_int(state.staffing().committed()).is_equal(0)
	assert_int(state.open_sites()).is_equal(0)

## « Rien, et ne rend aucune ressource » — DESIGN.md 4.2. Les dix bois de la ferme sont
## perdus, et c'est ce qui fait d'une démolition un vrai coût.
func test_demolishing_gives_no_resource_back() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	var wood := state.ledger().amount(&"wood")
	RunOrchestrator.demolish(state, A)
	assert_int(state.ledger().amount(&"wood")).is_equal(wood)

## Une cellule quelconque de l'empreinte suffit : c'est le chemin pour lequel
## CityState.anchor_at() existe, et il vaut pour la démolition comme pour la pose.
func test_any_cell_of_the_footprint_demolishes_the_building() -> void:
	var state := _founded()
	var result := RunOrchestrator.demolish(state, Vector2i(1, 1))
	assert_str(String(result.reason())).is_equal("the_heart")

func test_demolishing_an_empty_cell_is_refused() -> void:
	assert_str(String(RunOrchestrator.demolish(_founded(), C).reason())) \
		.is_equal("nothing_here")

## DESIGN.md 4.2 ne l'exclut pas de « Démolir », et 5 fait du Cœur détruit une défaite : les
## deux mis bout à bout donnent un bouton « perdre la partie » sans confirmation.
func test_the_heart_cannot_be_demolished() -> void:
	var state := _founded()
	assert_str(String(RunOrchestrator.demolish(state, HEART).reason())).is_equal("the_heart")
	assert_bool(state.has_its_heart()).is_true()

## Abattre une habitation abaisse le plafond de logement, et ce qui dépassait s'en va. Le
## geste ne rend rien mais il **coûte**, et le taire ferait disparaître des habitants sans
## que l'écran puisse le dire.
func test_tearing_down_a_house_puts_its_surplus_out() -> void:
	_balance = _make_balance(_economy(80, 60, 4, 4, 200), _run())
	var state := _founded()
	RunOrchestrator.open_site(state, &"house", A)
	# Le temps que l'habitation s'achève, puis que le village grandisse jusqu'au nouveau
	# plafond : sans ce surplus, la démolition ne chasserait personne et le cas passerait
	# sans rien prouver.
	for _turn in 8:
		RunOrchestrator.end_turn(state)
	assert_int(state.people().places()).is_equal(12)
	assert_int(state.people().headcount()) \
		.override_failure_message("le village n'a pas rempli l'habitation : le cas ne prouve rien") \
		.is_equal(12)
	var result := RunOrchestrator.demolish(state, A)
	assert_int(result.homeless()).is_equal(4)
	assert_int(state.people().headcount()).is_equal(8)

## Le même geste sur un entrepôt renverse ce que la réserve ne peut plus tenir.
func test_tearing_down_a_warehouse_spills_what_no_longer_fits() -> void:
	var state := _founded()
	RunOrchestrator.open_site(state, &"store", A)
	RunOrchestrator.end_turn(state)
	state.ledger().add(&"stone", state.ledger().free_space())
	assert_int(state.ledger().total()).is_equal(200)
	var result := RunOrchestrator.demolish(state, A)
	assert_int(result.spilled()).is_equal(100)
	assert_int(state.ledger().total()).is_equal(100)

# --- L'INTERDIT DE BLOCAGE, joué ---------------------------------------------

## **Le cas qui porte le jalon.** N1 a prouvé que la soupape existait ; celui-ci prouve
## qu'on peut s'en servir dans une partie.
##
## Le montage est la situation que DESIGN.md 3.4 décrit comme mortelle : tous les habitants
## immobilisés, le logement plein. « Il faudrait des travailleurs libres, et il n'y en aura
## plus jamais. Le village est mort debout. »
##
## Les trois assertions sont l'enchaînement complet — le village est bien bloqué, l'habitation
## gratuite en bras passe quand même, et la population repart. Sans la première, le cas
## pourrait passer sur un village qui n'a jamais été coincé.
func test_a_village_with_every_hand_taken_and_no_bed_can_still_be_unblocked() -> void:
	# Beaucoup de nourriture et juste le bois de la soupape : le village doit tenir assez
	# longtemps pour que l'habitation s'achève, sinon la famine masquerait le déblocage.
	_balance = _make_balance(_economy(80, 20, 4, 4), _run())
	var state := _founded()
	# Le Cœur loge quatre personnes de plus : le village se remplit avant d'être coincé,
	# ce que quelques tours feraient aussi et plus lentement.
	state.people().grow(4)
	RunOrchestrator.open_site(state, &"hut", A)
	RunOrchestrator.open_site(state, &"hut", B)
	RunOrchestrator.open_site(state, &"hut", C)
	RunOrchestrator.end_turn(state)
	RunOrchestrator.open_site(state, &"hut", D)
	RunOrchestrator.end_turn(state)

	assert_bool(state.people().is_full()) \
		.override_failure_message("le logement n'est pas plein : le cas ne prouve rien") \
		.is_true()
	assert_int(state.staffing().available()) \
		.override_failure_message("il reste des bras : le cas ne prouve rien") \
		.is_equal(0)
	assert_str(String(RunOrchestrator.open_site(state, &"farm", Vector2i(3, 5)).reason())) \
		.is_equal("not_enough_workers")

	# La soupape : elle ne coûte aucun bras, donc elle passe, et elle ne dort jamais.
	assert_bool(RunOrchestrator.open_site(state, &"house", Vector2i(3, 5)).is_ok()).is_true()
	for _turn in 3:
		RunOrchestrator.end_turn(state)
	assert_int(state.people().places()).is_equal(12)
	assert_int(state.people().headcount()).is_greater(8)
	assert_int(state.staffing().available()).is_greater(0)

## La **seconde soupape** de DESIGN.md 3.4, et elle compte parce que la première ne suffit
## pas toujours : l'habitation est gratuite en bras mais pas en bois. Un village dont tous les
## bras sont pris et dont la réserve ne couvre plus une habitation n'a qu'une sortie, et c'est
## de démolir.
func test_demolishing_is_the_way_out_when_the_free_shelter_is_unaffordable() -> void:
	_balance = _make_balance(_economy(40, 10, 4, 4), _run())
	var state := _founded()
	state.people().grow(4)
	for cell in [A, B, C, D]:
		RunOrchestrator.open_site(state, &"hut", cell)

	assert_int(state.staffing().available()) \
		.override_failure_message("il reste des bras : le cas ne prouve rien") \
		.is_equal(0)
	assert_str(String(RunOrchestrator.open_site(state, &"house", Vector2i(3, 5)).reason())) \
		.override_failure_message("l'habitation était payable : le cas ne prouve rien") \
		.is_equal("not_enough_resources")

	RunOrchestrator.demolish(state, A)
	assert_int(state.staffing().available()).is_equal(2)
	assert_bool(RunOrchestrator.open_site(state, &"hut", Vector2i(3, 5)).is_ok()).is_true()

# --- la fin d'un run ---------------------------------------------------------

## « Un run paisible se gagne en le survivant », et c'est ce qui rend le verdict atteignable
## dès I3, où aucune vague n'existe.
func test_the_last_turn_ends_the_run_on_a_victory() -> void:
	_balance = _make_balance(_economy(), _run(2))
	var state := _founded()
	RunOrchestrator.end_turn(state)
	assert_bool(state.is_over()).is_false()
	var report := RunOrchestrator.end_turn(state)
	assert_bool(report.ends_the_run()).is_true()
	assert_bool(state.is_over()).is_true()
	assert_bool(state.outcome().is_victory()).is_true()
	assert_int(state.outcome().turn()).is_equal(2)

## Les quatre termes sont vérifiés **contre l'état** et non contre des nombres écrits ici :
## le risque d'une somme de quatre produits est de brancher un compte sur le mauvais poids,
## et c'est exactement ce que cette comparaison attrape.
func test_the_verdict_counts_what_the_village_really_has() -> void:
	_balance = _make_balance(_economy(), _run(2))
	var state := _founded()
	RunOrchestrator.open_site(state, &"hut", A)
	RunOrchestrator.end_turn(state)
	RunOrchestrator.end_turn(state)
	var outcome := state.outcome()
	assert_int(outcome.resources()).is_equal(state.ledger().total())
	assert_int(outcome.inhabitants()).is_equal(state.people().headcount())
	assert_int(outcome.heart_hit_points()).is_equal(HEART_HIT_POINTS)
	assert_int(outcome.buildings()).is_equal(2)
	assert_int(outcome.score()).is_equal(outcome.resources() + outcome.buildings() * 5
		+ outcome.inhabitants() * 10 + HEART_HIT_POINTS * 2)

## Un chantier laissé en plan n'est pas un bâtiment intact — la règle de C4, appliquée au
## score de DESIGN.md 5.
func test_an_unfinished_site_does_not_count_as_a_building() -> void:
	_balance = _make_balance(_economy(), _run(1))
	var state := _founded()
	RunOrchestrator.open_site(state, &"farm", A)
	RunOrchestrator.end_turn(state)
	assert_int(state.outcome().buildings()).is_equal(1)

## La seule défaite atteignable avant V4, et elle l'est vraiment : la famine de
## DESIGN.md 3.4, un cran par tour, jusqu'à zéro.
func test_a_village_that_starves_to_nothing_loses_the_run() -> void:
	_balance = _make_balance(_economy(2, 0), _run())
	var state := _founded()
	for _turn in 4:
		RunOrchestrator.end_turn(state)
	assert_int(state.people().headcount()).is_equal(0)
	assert_bool(state.is_over()).is_true()
	assert_str(String(state.outcome().cause())).is_equal("population")
	assert_bool(state.outcome().is_victory()).is_false()

## **Les défaites passent avant la victoire.** On ne gagne pas en tombant sur la ligne
## d'arrivée : un dernier tour où le village meurt de faim n'est pas un run survécu.
func test_dying_on_the_last_turn_is_a_defeat_and_not_a_victory() -> void:
	_balance = _make_balance(_economy(0, 0, 6, 1), _run(1))
	var state := _founded()
	var report := RunOrchestrator.end_turn(state)
	assert_bool(report.ends_the_run()).is_true()
	assert_str(String(state.outcome().cause())).is_equal("population")

## Un run fini n'avance plus, et refuse tous les gestes plutôt que de les ignorer.
func test_a_finished_run_refuses_every_gesture() -> void:
	_balance = _make_balance(_economy(), _run(1))
	var state := _founded()
	RunOrchestrator.end_turn(state)
	assert_int(state.turn()).is_equal(1)
	assert_str(String(RunOrchestrator.open_site(state, &"hut", A).reason())) \
		.is_equal("run_over")
	assert_str(String(RunOrchestrator.demolish(state, HEART).reason())).is_equal("run_over")
	assert_str(String(RunOrchestrator.found(state, C).reason())).is_equal("run_over")

# --- déterminisme ------------------------------------------------------------

## CLAUDE.md : « un seed plus une liste d'actions doit rejouer un run à l'identique ».
##
## Rien à I3 ne consomme le RNG — les vagues sont V4 —, donc ce que ce cas garde vraiment
## n'est pas le tirage mais la **stabilité d'ordre** : l'itération des Dictionary de la
## production, le tri des StringName dans l'écrêtage du Ledger, l'ordre de pose dans
## Staffing. Ce sont les trois endroits où un run pourrait diverger de lui-même, et le
## piège des StringName triés par pointeur est nommé dans CLAUDE.md précisément parce qu'il
## est stable le temps d'une session et différent à la suivante.
##
## L'écrêtage est déclenché exprès : sans lui, la moitié la plus fragile ne serait jamais
## empruntée.
func test_the_same_seed_and_the_same_gestures_replay_the_same_run() -> void:
	var first := _replay()
	var second := _replay()
	assert_dict(first.ledger().amounts()).is_equal(second.ledger().amounts())
	assert_int(first.people().headcount()).is_equal(second.people().headcount())
	assert_int(first.turn()).is_equal(second.turn())
	assert_int(first.open_sites()).is_equal(second.open_sites())

## La même suite de gestes, jouée depuis un run neuf.
func _replay() -> RunState:
	var state := _founded()
	RunOrchestrator.open_site(state, &"quarry", A)
	RunOrchestrator.open_site(state, &"hut", B)
	state.ledger().add(&"stone", state.ledger().free_space() - 1)
	for _turn in 5:
		RunOrchestrator.end_turn(state)
	return state
