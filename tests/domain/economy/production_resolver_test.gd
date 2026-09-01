class_name ProductionResolverTest
extends GdUnitTestSuite
## Ce qui produit, et ce qui n'a pas le droit de produire.
##
## Trois conditions gouvernent ce fichier, et chacune a son cas de refus **et** son cas
## d'acceptation. Un contrôle qui n'aurait que la moitié refusante passerait aussi bien sur
## un résolveur qui ne produit jamais rien.

const HIT_POINTS := 4
const CAPACITY := 100

func _balance() -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = CAPACITY
	balance.base_housing = 6
	balance.starting_population = 4
	balance.upkeep_per_inhabitant = 1
	balance.upkeep_resource = &"food"
	return balance

## Bâtiment qui rend ce lot chaque tour, ou rien du tout si le lot est vide — auquel cas il
## n'a **pas de bloc**, ce qui est la façon dont E1b représente « ne produit pas ».
func _building(id: StringName, workers: int, yields: Dictionary[StringName, int],
		site_turns: int = 0) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = HIT_POINTS
	data.workers = workers
	data.site_turns = site_turns
	if not yields.is_empty():
		var block := ProductionBlock.new()
		block.yield_per_turn = yields
		data.production = block
	return data

func _farm(id: StringName, workers := 2, site_turns := 0) -> BuildingData:
	return _building(id, workers, {&"food": 3} as Dictionary[StringName, int], site_turns)

## Ville de ces bâtiments, un par ancre, avec cet avancement chacun.
func _city(buildings: Array[BuildingData], progress: Array[int] = []) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	for i in buildings.size():
		var done: int = progress[i] if i < progress.size() else buildings[i].site_turns
		placed.append(BuildingSnapshot.create(buildings[i], Vector2i(i, 0), 0, 0, done))
	return CitySnapshot.create(placed)

func _resolve(city: CitySnapshot, headcount: int, ledger: Ledger) -> ProductionReport:
	return ProductionResolver.resolve(city, Staffing.resolve(city, headcount), ledger,
		_balance())

# --- ce qui produit ----------------------------------------------------------

func test_an_empty_city_produces_nothing() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(CitySnapshot.empty(), 4, ledger)
	assert_bool(report.is_empty()).is_true()
	assert_int(ledger.total()).is_equal(0)

func test_a_finished_and_staffed_building_pays_its_yield() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"farm")]), 4, ledger)
	assert_int(report.produced()[&"food"]).is_equal(3)
	assert_int(ledger.amount(&"food")).is_equal(3)
	assert_array(report.producers()).is_equal([Vector2i(0, 0)])

## Personne ne le lui demande, et c'est le renversement de DESIGN.md 2 : la production ne
## dépend plus d'une action jouée. Deux tours sur la même ville rendent deux fois.
func test_the_same_city_pays_again_every_turn() -> void:
	var ledger := Ledger.create(CAPACITY)
	var city := _city([_farm(&"farm")])
	_resolve(city, 4, ledger)
	_resolve(city, 4, ledger)
	assert_int(ledger.amount(&"food")).is_equal(6)

func test_several_producers_add_up_resource_by_resource() -> void:
	var ledger := Ledger.create(CAPACITY)
	var mill := _building(&"mill", 2, {&"wood": 2} as Dictionary[StringName, int])
	var report := _resolve(_city([_farm(&"farm"), _farm(&"farm2"), mill]), 8, ledger)
	assert_int(report.produced()[&"food"]).is_equal(6)
	assert_int(report.produced()[&"wood"]).is_equal(2)

# --- la première condition : achevé ------------------------------------------

## Un chantier ne produit rien. C'est la règle de C4, et elle est ici et non chez
## l'appelant : CitySnapshot.completed() la porte une fois pour tous ses consommateurs.
func test_a_site_under_construction_pays_nothing() -> void:
	var ledger := Ledger.create(CAPACITY)
	var city := _city([_farm(&"farm", 2, 2)], [1])
	assert_array(city.completed()) \
		.override_failure_message("le montage a fabriqué un bâtiment fini") \
		.is_empty()
	assert_bool(_resolve(city, 4, ledger).is_empty()).is_true()

## Le pendant : le cran qui achève le chantier est celui qui le fait produire.
func test_the_notch_that_finishes_a_site_starts_the_yield() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"farm", 2, 2)], [2]), 4, ledger)
	assert_int(report.produced()[&"food"]).is_equal(3)

# --- la deuxième condition : actif -------------------------------------------

## « Un bâtiment en sommeil ne rend rien » — DESIGN.md 3.3, tout ou rien, jamais au prorata.
## Trois fermes à deux bras pour cinq habitants : la dernière dort, et elle ne rend pas
## une demi-récolte, elle ne rend rien.
func test_a_dormant_building_pays_nothing_at_all() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"a"), _farm(&"b"), _farm(&"c")]), 5, ledger)
	assert_int(report.produced()[&"food"]).is_equal(6)
	assert_array(report.producers()).is_equal([Vector2i(0, 0), Vector2i(1, 0)])
	assert_array(report.dormant()).is_equal([Vector2i(2, 0)])
	assert_bool(report.has_dormant()).is_true()

## Le repeuplement automatique de N1, vu depuis la production : rien n'est mémorisé, donc
## un effectif qui remonte fait reproduire la ferme sans qu'un geste l'ordonne.
func test_a_village_that_grows_back_makes_the_farm_pay_again() -> void:
	var city := _city([_farm(&"a"), _farm(&"b"), _farm(&"c")])
	var starved := Ledger.create(CAPACITY)
	assert_int(_resolve(city, 5, starved).produced()[&"food"]).is_equal(6)
	var fed := Ledger.create(CAPACITY)
	assert_int(_resolve(city, 6, fed).produced()[&"food"]).is_equal(9)

## Un bâtiment gratuit en bras ne dort jamais — la règle qu'N1 a trouvée en jouant sa
## soupape. Vue d'ici : une ferme sans ouvrier produit même quand le village est vide.
func test_a_building_that_costs_no_hands_pays_even_with_nobody() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"free", 0)]), 0, ledger)
	assert_int(report.produced()[&"food"]).is_equal(3)

# --- la troisième condition : porteur d'un bloc ------------------------------

## L'entrepôt et l'habitation n'ont pas « zéro rendement », ils n'ont pas de bloc. Le
## résolveur les ignore sans jamais les nommer, et ils ne comptent pas non plus parmi les
## endormis — un entrepôt à l'arrêt ne manque à aucune récolte.
func test_a_building_without_a_block_is_neither_producer_nor_dormant() -> void:
	var ledger := Ledger.create(CAPACITY)
	var store := _building(&"store", 2, {} as Dictionary[StringName, int])
	var report := _resolve(_city([store]), 0, ledger)
	assert_bool(report.is_empty()).is_true()
	assert_array(report.producers()).is_empty()
	assert_array(report.dormant()).is_empty()

# --- ce que le plafond mange -------------------------------------------------

## produced et stored sont gardés séparément parce que leur écart **est** l'arbitrage de la
## réserve commune. Une réserve pleine à deux unités près ne garde que deux unités.
func test_the_cap_eats_what_does_not_fit_and_the_report_says_how_much() -> void:
	var ledger := Ledger.from_stock({&"wood": 98} as Dictionary[StringName, int], CAPACITY)
	var report := _resolve(_city([_farm(&"farm")]), 4, ledger)
	assert_int(report.produced()[&"food"]).is_equal(3)
	assert_int(report.stored()[&"food"]).is_equal(2)
	assert_int(report.overflow()).is_equal(1)
	assert_bool(ledger.is_full()).is_true()

func test_nothing_is_lost_when_the_reserve_has_room() -> void:
	var ledger := Ledger.create(CAPACITY)
	assert_int(_resolve(_city([_farm(&"farm")]), 4, ledger).overflow()).is_equal(0)

## Une ressource entièrement écrêtée ne figure pas dans stored(), de sorte que ce lot se
## lise comme la liste de ce qui est **entré**. C'est le contrat de Ledger.deposit(), rendu
## tel quel plutôt que réinterprété.
func test_a_resource_entirely_clipped_is_absent_from_what_was_stored() -> void:
	var ledger := Ledger.from_stock({&"wood": CAPACITY} as Dictionary[StringName, int],
		CAPACITY)
	var report := _resolve(_city([_farm(&"farm")]), 4, ledger)
	assert_bool(report.stored().has(&"food")).is_false()
	assert_int(report.overflow()).is_equal(3)

# --- déterminisme ------------------------------------------------------------

## Deux villes identiques bâties dans un ordre différent doivent rendre la même chose. La
## règle porte sur le tour entier (DESIGN.md 2) ; ici on tient sa moitié production, qui
## est celle où l'écrêtage pourrait choisir une victime selon l'ordre des clés.
func test_placement_order_does_not_change_what_is_stored() -> void:
	var farm := _farm(&"farm")
	var mill := _building(&"mill", 2, {&"wood": 3} as Dictionary[StringName, int])
	var first := Ledger.from_stock({&"stone": 96} as Dictionary[StringName, int], CAPACITY)
	var second := Ledger.from_stock({&"stone": 96} as Dictionary[StringName, int], CAPACITY)
	var one := _resolve(_city([farm, mill]), 8, first)
	var two := _resolve(_city([mill, farm]), 8, second)
	assert_dict(one.stored()).is_equal(two.stored())
	assert_dict(first.amounts()).is_equal(second.amounts())
