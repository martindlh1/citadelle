class_name ProductionResolverTest
extends GdUnitTestSuite
## Ce qui produit, et ce qui n'a pas le droit de produire.
##
## Trois conditions gouvernent ce fichier, et chacune a son cas de refus **et** son cas
## d'acceptation. Un contrôle qui n'aurait que la moitié refusante passerait aussi bien sur
## un résolveur qui ne produit jamais rien.

const HIT_POINTS := 4
const CAPACITY := 100

## Le tag que les producteurs de ce fichier cherchent, et le pas de son semis.
const SOIL_TAG := &"soil"
const SOIL_STRIDE := 3

func _balance() -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = CAPACITY
	balance.base_housing = 6
	balance.starting_population = 4
	balance.upkeep_per_inhabitant = 1
	balance.upkeep_resource = &"food"
	return balance

## Bâtiment qui rend ce lot chaque tour, ou rien du tout si le lot est vide — auquel cas il
## n'a **aucune règle**, ce qui est la façon dont C3 représente « ne produit pas ».
##
## Le lot devient une règle de voisinage par ressource, à `per_cell` égal au rendement voulu :
## le sol de `_ground()` pose exactement une case taggée dans la zone de chaque bâtiment, donc
## « +3 nourriture » reste « +3 nourriture ».
func _building(id: StringName, workers: int, yields: Dictionary[StringName, int],
		site_turns: int = 0) -> BuildingData:
	var data := BuildingData.new()
	# Une emprise large, pour que la règle d'emprise de `C7` ne se mette pas en travers des
	# cas qui parlent d'autre chose : un `reach` laissé à zéro n'ouvrirait même pas la case
	# voisine, et toute ville de plus d'un bâtiment serait refusée.
	data.reach = 12
	data.id = id
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = HIT_POINTS
	data.workers = workers
	data.site_turns = site_turns
	for resource in yields:
		data.adjacency.append(_rule(resource, yields[resource]))
	return data

## +`per_cell` de cette ressource par case de sol à un anneau.
func _rule(resource: StringName, per_cell: int) -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	rule.tag = SOIL_TAG
	rule.radius = 1
	rule.resource = resource
	rule.per_cell = per_cell
	return rule

func _farm(id: StringName, workers := 2, site_turns := 0) -> BuildingData:
	return _building(id, workers, {&"food": 3} as Dictionary[StringName, int], site_turns)

## Ville de ces bâtiments, un par ancre, avec cet avancement chacun.
func _city(buildings: Array[BuildingData], progress: Array[int] = []) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	for i in buildings.size():
		var done: int = progress[i] if i < progress.size() else buildings[i].site_turns
		placed.append(BuildingSnapshot.create(buildings[i], Vector2i(i, 0), 0, 0, done))
	return CitySnapshot.create(placed)

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
func _ground() -> HeightGrid:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	plain.walk = TerrainData.Walk.ALLOWED
	var soil := TerrainData.new()
	soil.id = SOIL_TAG
	soil.build = TerrainData.Build.ALLOWED
	soil.walk = TerrainData.Walk.ALLOWED
	soil.tags.append(SOIL_TAG)
	var grid := HeightGrid.create(Vector2i(9, 9), 0, plain)
	for y in range(0, 9, SOIL_STRIDE):
		for x in range(0, 9, SOIL_STRIDE):
			grid.set_terrain(Vector2i(x, y), soil)
	return grid

func _resolve(city: CitySnapshot, headcount: int, ledger: Ledger,
		ground: HeightGrid = null) -> ProductionReport:
	var grid := ground if ground != null else _ground()
	return ProductionResolver.resolve(city, Staffing.resolve(city, headcount),
		grid.to_query(), ledger, _balance())

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

# --- ce que la case rapporte -------------------------------------------------

## **La récolte suit le sol, et c'est tout le jalon.** Deux cases de plus à portée, deux fois
## plus de rendement : rien ne borne le produit depuis que le voisinage est la seule source de
## production, et c'est ce qui fait qu'un emplacement vaut mieux qu'un autre.
func test_the_harvest_follows_what_the_ground_carries() -> void:
	var lean := Ledger.create(CAPACITY)
	assert_int(_resolve(_city([_farm(&"farm")]), 4, lean).produced()[&"food"]) \
		.override_failure_message("une case de sol, un rendement simple") \
		.is_equal(3)

	# Deux cases de sol de plus dans la zone du bâtiment posé en (0, 0).
	var rich_ground := _ground()
	rich_ground.set_terrain(Vector2i(1, 0), _soil())
	rich_ground.set_terrain(Vector2i(0, 1), _soil())
	var rich := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"farm")]), 4, rich, rich_ground)
	assert_int(report.produced()[&"food"]) \
		.override_failure_message("trois cases de sol : trois fois le rendement") \
		.is_equal(9)
	assert_int(rich.amount(&"food")).is_equal(9)

## Un bâtiment dont aucune règle ne trouve rien ne verse rien, et **ne casse pas**. Le
## placement l'aurait refusé — c'est la garantie que la Construction rend à l'Économie —, mais
## le résolveur ne s'y fie pas : un terrassement de `C5` pourrait retirer le sol sous un
## bâtiment déjà posé, et ce jour-là il faudra que cette ligne tienne.
func test_a_building_that_finds_nothing_pays_nothing() -> void:
	var barren := _bare_ground()
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"farm")]), 4, ledger, barren)
	assert_array(report.producers()) \
		.override_failure_message("il compte parmi les producteurs : il a une raison de produire") \
		.is_equal([Vector2i(0, 0)])
	assert_bool(report.is_empty()).is_true()
	assert_int(ledger.total()).is_equal(0)

## Un bâtiment endormi ne touche **rien du tout**, si riche que soit son sol. La règle de
## DESIGN.md est « tout ou rien » ; verser la récolte d'un bâtiment à l'arrêt en aurait fait
## une exception que rien n'annonce.
func test_a_dormant_building_harvests_nothing() -> void:
	var ledger := Ledger.create(CAPACITY)
	var report := _resolve(_city([_farm(&"farm", 9)]), 2, ledger)
	assert_array(report.dormant()) \
		.override_failure_message("le bâtiment devait dormir : le cas ne prouve rien") \
		.is_equal([Vector2i(0, 0)])
	assert_bool(report.is_empty()).is_true()

## L'orientation déplace l'empreinte, donc la zone, donc la récolte. Un résolveur qui lirait
## l'ancre sans les crans paierait le rendement d'une autre pose.
func test_the_orientation_is_the_one_the_building_was_placed_in() -> void:
	var ground := _bare_ground()
	ground.set_terrain(Vector2i(3, 1), _soil())
	var flat := _placed(_gallery(&"gallery"), 0)
	var turned := _placed(_gallery(&"gallery"), 1)
	assert_int(_resolve(flat, 4, Ledger.create(CAPACITY), ground).produced().get(&"food", 0)) \
		.override_failure_message("à plat, l'empreinte s'étend en x et voit la case") \
		.is_equal(3)
	assert_int(_resolve(turned, 4, Ledger.create(CAPACITY), ground).produced().get(&"food", 0)) \
		.override_failure_message("pivotée, elle s'étend en y et ne la voit plus") \
		.is_equal(0)

## Sol nu, sans un seul tag : le cas qui veut mesurer une absence le monte lui-même.
func _bare_ground() -> HeightGrid:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	plain.walk = TerrainData.Walk.ALLOWED
	return HeightGrid.create(Vector2i(9, 9), 0, plain)

## Une case de sol, taggée comme celles du semis.
func _soil() -> TerrainData:
	var data := TerrainData.new()
	data.id = SOIL_TAG
	data.build = TerrainData.Build.ALLOWED
	data.walk = TerrainData.Walk.ALLOWED
	data.tags.append(SOIL_TAG)
	return data

## Une ferme de deux cases en x : une empreinte carrée ne dirait rien de la rotation.
func _gallery(id: StringName) -> BuildingData:
	var data := _farm(id)
	data.footprint = [Vector2i.ZERO, Vector2i(1, 0)] as Array[Vector2i]
	return data

## Ce bâtiment posé en (1, 1), dans cette orientation.
func _placed(data: BuildingData, turns: int) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(data, Vector2i(1, 1), 0, turns, data.site_turns)]
	return CitySnapshot.create(placed)

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
