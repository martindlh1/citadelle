class_name ProductionResolverTest
extends GdUnitTestSuite
## La résolution d'un soir : qui produit, qui chôme, qui mange.
##
## Ville de travail, trois bâtiments fabriqués à la main :
##   - une cabane à 2 slots qui rend 2 bois, en (1, 1) ;
##   - une ferme à 2 slots qui rend 3 nourriture, en (5, 5) ;
##   - un entrepôt **sans bloc de production** qui ajoute 100 de réserve, en (8, 8).
##
## Rien ne vient de data/ : les rendements des bâtiments de DESIGN.md 4.1 bougeront à
## la passe de contenu, et un test qui les figerait serait cassé en permanence.
##
## Les deux cas qui portent le plus sont la sur-affectation — trois ouvriers pour deux
## postes — et l'upkeep, qui compte le roster entier et non les seuls affectés.

const WOOD := &"wood"
const FOOD := &"food"
const HARVEST := &"harvest"

const HUT := Vector2i(1, 1)
const FARM := Vector2i(5, 5)
const STORE := Vector2i(8, 8)
const NOWHERE := Vector2i(20, 20)

var _hut: BuildingData
var _farm: BuildingData
var _store: BuildingData
var _city: CitySnapshot
var _balance: EconomyBalance

func before_test() -> void:
	_hut = _make_building(&"hut", 2, {WOOD: 2})
	_farm = _make_building(&"farm", 2, {FOOD: 3})
	_store = _make_building(&"store", 0, {})
	_store.storage_bonus = 100
	_city = _make_city([_hut, HUT, _farm, FARM, _store, STORE])
	_balance = _make_balance(100, 1)

func test_an_empty_evening_produces_nothing_and_owes_nothing() -> void:
	var report := _resolve(CitySnapshot.empty(), Assignment.empty(), LaborForce.empty(),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_int(report.upkeep()).is_equal(0)
	assert_bool(report.is_famine()).is_false()

func test_one_worker_on_a_two_slot_building_fills_one_slot() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]), _crew([&"ana"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(2)
	assert_int(report.work().size()).is_equal(1)

func test_two_workers_fill_both_slots() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT, &"bo", HUT]),
		_crew([&"ana", &"bo"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)

## Le cas qui porte le jalon. Les slots se remplissent dans l'ordre de l'affectation :
## le troisième arrive quand il n'y a plus de poste, et chôme.
func test_a_third_worker_on_two_slots_stays_idle() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT, &"bo", HUT, &"cy", HUT]),
		_crew([&"ana", &"bo", &"cy"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)
	assert_array(report.idle()).contains_exactly([&"cy"])

func test_a_worker_sent_to_an_empty_anchor_stays_idle() -> void:
	var report := _resolve(_city, _assign([&"ana", NOWHERE]), _crew([&"ana"]),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## Un entrepôt est un bâtiment parfaitement valide où personne ne travaille : il n'a
## pas zéro poste, il n'a pas de bloc de production. L'ouvrier envoyé là chôme sans
## qu'aucun refus ne soit prononcé.
func test_a_worker_sent_to_a_building_without_a_production_block_stays_idle() -> void:
	assert_bool(_store.produces()).is_false()
	var report := _resolve(_city, _assign([&"ana", STORE]), _crew([&"ana"]),
		Ledger.create(100))
	assert_array(report.idle()).contains_exactly([&"ana"])

## Un chantier n'offre AUCUN poste, même sur un bâtiment qui produira très bien une
## fois fini. C'est la moitié du couple qui porte C4 : sans son jumeau ci-dessous, il
## passerait tout aussi bien si plus rien ne produisait jamais.
func test_a_worker_sent_to_an_unfinished_site_stays_idle() -> void:
	var city := _city_at(_site(_farm, 2), FARM, 1)
	var report := _resolve(city, _assign([&"ana", FARM]), _crew([&"ana"]),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.work()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## Le jumeau : le même bâtiment, le même ouvrier, le dernier cran posé. Seul
## l'avancement change entre les deux cas.
func test_the_same_site_produces_once_it_is_finished() -> void:
	var city := _city_at(_site(_farm, 2), FARM, 2)
	var report := _resolve(city, _assign([&"ana", FARM]), _crew([&"ana"]),
		Ledger.create(100))
	assert_int(report.produced()[FOOD]).is_equal(3)
	assert_int(report.work().size()).is_equal(1)
	assert_array(report.idle()).is_empty()

func test_an_unassigned_worker_stays_idle() -> void:
	var report := _resolve(_city, Assignment.empty(), _crew([&"ana"]), Ledger.create(100))
	assert_array(report.idle()).contains_exactly([&"ana"])

## Une affectation peut avoir survécu à celui qui la portait. Il est ignoré sans un
## mot, et ne compte pas non plus comme oisif : un mort ne chôme pas.
func test_a_worker_absent_from_the_roster_is_ignored_entirely() -> void:
	var report := _resolve(_city, _assign([&"ghost", HUT]), LaborForce.empty(),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).is_empty()
	assert_int(report.work().size()).is_equal(0)

## Le second cas qui porte le jalon : l'upkeep tombe sur le roster entier, y compris
## sur les trois qui n'ont rien fait. C'est ce qui rend le pool tendu.
func test_upkeep_counts_the_whole_roster_including_the_idle() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]),
		_crew([&"ana", &"bo", &"cy", &"di"]), _stocked({FOOD: 50}))
	assert_int(report.upkeep()).is_equal(4)
	assert_int(report.consumed()).is_equal(4)

func test_a_skilled_worker_produces_more() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]), _skilled_crew(&"ana", 2.0),
		Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)

## Tronqué vers le bas : un multiplicateur sous 1.0 se paie vraiment, et un ouvrier ne
## rend jamais plus que ce que la data promet.
func test_a_fractional_multiplier_is_floored() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]), _skilled_crew(&"ana", 0.7),
		Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(1)

## Il a occupé le poste et mérite son XP ; il a juste mal produit. Sans cette ligne,
## les Effectifs ne sauraient pas qu'il a travaillé.
func test_a_worker_who_produces_nothing_still_gets_a_work_line() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]), _skilled_crew(&"ana", 0.1),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_int(report.work().size()).is_equal(1)
	assert_array(report.idle()).is_empty()

## C'est par elle que les Effectifs sauront quelle piste créditer, sans avoir à
## rouvrir la ville pour retrouver le bâtiment.
func test_a_work_line_carries_the_family_of_its_building() -> void:
	var report := _resolve(_city, _assign([&"ana", HUT]), _crew([&"ana"]), Ledger.create(100))
	var line := report.work()[0]
	assert_str(line.family()).is_equal(HARVEST)
	assert_vector(line.anchor()).is_equal(HUT)
	assert_str(line.worker()).is_equal(&"ana")

func test_the_harvest_enters_the_reserve() -> void:
	var ledger := Ledger.create(100)
	var report := _resolve(_city, _assign([&"ana", HUT]), _crew([&"ana"]), ledger)
	assert_int(ledger.amount(WOOD)).is_equal(2)
	assert_int(report.stored()[WOOD]).is_equal(2)
	assert_int(report.total_wasted()).is_equal(0)

## La réserve est pleine : la récolte tombe entière, et le rapport le dit. Sans ce
## chiffre, un joueur ne comprend pas pourquoi son bois n'augmente plus.
func test_a_harvest_that_overruns_the_reserve_is_reported_as_wasted() -> void:
	var ledger := _stocked({WOOD: 200})
	var report := _resolve(_city, _assign([&"ana", HUT]), _crew([&"ana"]), ledger)
	assert_int(report.produced()[WOOD]).is_equal(2)
	assert_int(report.total_wasted()).is_equal(2)
	assert_bool(report.stored().has(WOOD)).is_false()

## L'entrepôt est le seul à relever la réserve commune, et c'est sa seule raison
## d'être dans ce jalon.
func test_a_warehouse_raises_the_shared_capacity() -> void:
	assert_int(ProductionResolver.capacity_for(_city, _balance)).is_equal(200)
	assert_int(ProductionResolver.capacity_for(CitySnapshot.empty(), _balance)).is_equal(100)

## Un entrepôt en chantier a payé son coût et occupe ses cellules, mais il n'a pas de
## toit. Le laisser relever la réserve ne casserait rien — il mentirait, ce qui est
## précisément pourquoi ce cas existe.
func test_an_unfinished_warehouse_does_not_raise_the_capacity() -> void:
	var city := _city_at(_site(_store, 2), STORE, 1)
	assert_int(ProductionResolver.capacity_for(city, _balance)).is_equal(100)

func test_the_same_warehouse_raises_it_once_finished() -> void:
	var city := _city_at(_site(_store, 2), STORE, 2)
	assert_int(ProductionResolver.capacity_for(city, _balance)).is_equal(200)

func test_resolving_applies_the_capacity_of_the_evening() -> void:
	var ledger := Ledger.create(10)
	_resolve(_city, Assignment.empty(), LaborForce.empty(), ledger)
	assert_int(ledger.capacity()).is_equal(200)

## La production précède l'upkeep : ce que la ferme sort ce soir nourrit ce soir.
func test_the_evening_harvest_feeds_the_same_evening() -> void:
	var report := _resolve(_city, _assign([&"ana", FARM]), _crew([&"ana"]), Ledger.create(100))
	assert_int(report.produced()[FOOD]).is_equal(3)
	assert_int(report.consumed()).is_equal(1)
	assert_bool(report.is_famine()).is_false()

func test_exactly_enough_food_is_not_a_famine() -> void:
	var report := _resolve(_city, Assignment.empty(), _crew([&"ana", &"bo"]),
		_stocked({FOOD: 2}))
	assert_int(report.consumed()).is_equal(2)
	assert_int(report.unfed()).is_equal(0)
	assert_bool(report.is_famine()).is_false()

func test_a_short_reserve_leaves_workers_unfed() -> void:
	var ledger := _stocked({FOOD: 2})
	var report := _resolve(_city, Assignment.empty(), _crew([&"ana", &"bo", &"cy", &"di"]),
		ledger)
	assert_int(report.upkeep()).is_equal(4)
	assert_int(report.consumed()).is_equal(2)
	assert_int(report.unfed()).is_equal(2)
	assert_bool(report.is_famine()).is_true()
	assert_int(ledger.amount(FOOD)).is_equal(0)

func test_an_empty_reserve_leaves_everyone_unfed() -> void:
	var report := _resolve(_city, Assignment.empty(), _crew([&"ana", &"bo"]),
		Ledger.create(100))
	assert_int(report.consumed()).is_equal(0)
	assert_int(report.unfed()).is_equal(2)

## Arrondi vers le haut : à deux rations par ouvrier, un manque de trois laisse deux
## ouvriers sans ration entière. Une famine ne se sous-déclare jamais.
func test_a_partial_ration_still_counts_as_unfed() -> void:
	var balance := _make_balance(100, 2)
	var report := ProductionResolver.resolve(_city, Assignment.empty(),
		_crew([&"ana", &"bo", &"cy"]), _stocked({FOOD: 3}), balance)
	assert_int(report.upkeep()).is_equal(6)
	assert_int(report.consumed()).is_equal(3)
	assert_int(report.unfed()).is_equal(2)

## Un seed et une suite d'actions doivent rejouer un run à l'identique. Deux
## résolutions des mêmes entrées ne peuvent pas diverger.
func test_two_identical_resolutions_agree() -> void:
	var assign := _assign([&"ana", HUT, &"bo", HUT, &"cy", FARM])
	var crew := _crew([&"ana", &"bo", &"cy", &"di"])
	var first := _resolve(_city, assign, crew, _stocked({FOOD: 10}))
	var second := _resolve(_city, assign, crew, _stocked({FOOD: 10}))
	assert_dict(first.produced()).is_equal(second.produced())
	assert_dict(first.stored()).is_equal(second.stored())
	assert_array(first.idle()).is_equal(second.idle())
	assert_int(first.unfed()).is_equal(second.unfed())

func _resolve(city: CitySnapshot, assign: Assignment, labor: LaborForce,
		ledger: Ledger) -> ProductionReport:
	return ProductionResolver.resolve(city, assign, labor, ledger, _balance)

## Un bâtiment de travail. `slots` à 0 le laisse **sans bloc de production**, ce qui
## est la façon dont E1b dit « ne produit pas » : un entrepôt n'a pas zéro poste, il
## n'en a pas du tout.
func _make_building(id: StringName, slots: int,
		per_slot: Dictionary) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	if slots <= 0:
		return data
	var block := ProductionBlock.new()
	block.slots = slots
	var per: Dictionary[StringName, int] = {}
	for resource in per_slot:
		per[resource] = per_slot[resource]
	block.yield_per_slot = per
	block.skill_family = HARVEST
	data.production = block
	return data

## Le même bâtiment, mais réclamant un chantier. Les trois bâtiments de travail de ce
## fichier n'en réclament aucun et sont donc finis à la pose : les cas qui parlent de
## production parlent de production, et ceux qui parlent de chantier le disent.
func _site(data: BuildingData, actions: int) -> BuildingData:
	var copy := data.duplicate() as BuildingData
	copy.build_actions = actions
	return copy

## Ville d'un seul bâtiment, avec ce nombre de crans déjà posés.
func _city_at(data: BuildingData, anchor: Vector2i, progress: int) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(data, anchor, 0, 0, progress)]
	return CitySnapshot.create(placed)

## Ville depuis une liste plate — [données, ancre, données, ancre].
func _make_city(flat: Array) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	var index := 0
	while index < flat.size():
		placed.append(BuildingSnapshot.create(flat[index], flat[index + 1], 0))
		index += 2
	return CitySnapshot.create(placed)

## Affectation depuis une liste plate — [ouvrier, ancre, ouvrier, ancre].
## L'ordre de la liste est celui du remplissage des slots, ce dont un cas se sert.
func _assign(flat: Array) -> Assignment:
	var table: Dictionary[StringName, Vector2i] = {}
	var index := 0
	while index < flat.size():
		table[flat[index]] = flat[index + 1]
		index += 2
	return Assignment.create(table)

## Roster d'ouvriers sans aucune piste entamée.
func _crew(workers: Array) -> LaborForce:
	var units: Array[LaborUnit] = []
	for worker in workers:
		units.append(LaborUnit.novice(worker))
	return LaborForce.create(units)

## Roster d'un seul ouvrier, avec un multiplicateur dans la famille de récolte.
func _skilled_crew(worker: StringName, multiplier: float) -> LaborForce:
	var track: Dictionary[StringName, float] = {}
	track[HARVEST] = multiplier
	var units: Array[LaborUnit] = [LaborUnit.create(worker, track)]
	return LaborForce.create(units)

func _stocked(stock: Dictionary) -> Ledger:
	var typed: Dictionary[StringName, int] = {}
	for resource in stock:
		typed[resource] = stock[resource]
	return Ledger.from_stock(typed, 1000)

func _make_balance(cap: int, upkeep: int) -> EconomyBalance:
	var balance := EconomyBalance.new()
	balance.base_storage_cap = cap
	balance.upkeep_per_worker = upkeep
	balance.upkeep_resource = FOOD
	return balance
