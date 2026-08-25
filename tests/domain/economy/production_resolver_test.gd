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

## La famille de compétence, et la carte qui la met au travail. Le même mot désigne les
## deux — « récolte » — sans qu'elles soient la même chose : l'une est une piste des
## Effectifs, l'autre un identifiant de data/cards/. Deux constantes plutôt qu'une, pour
## que le jour où l'une bouge, l'autre ne suive pas par accident.
const HARVEST := &"harvest"
const HARVEST_CARD := &"harvest"

const HUNT_CARD := &"hunt"

const HUT := Vector2i(1, 1)
const FARM := Vector2i(5, 5)
const STORE := Vector2i(8, 8)
const NOWHERE := Vector2i(20, 20)

## Une forêt, et une plaine sans le moindre tag. Les cas « à cru » se jouent là.
const WOODS := Vector2i(3, 1)
const BARREN := Vector2i(4, 1)

## Où les deux cas qui posent *Construire* installent leur chantier, loin des trois
## bâtiments de la ville de travail.
const SITE_CELL := Vector2i(6, 1)

## Ce qu'un ouvrier tire d'une case nue, dans l'équilibrage de ce fichier.
const BARE_YIELD := 1

## Capacité donnée à une action que le ciblage aurait refusée — une ancre vide, un
## entrepôt, un chantier. Large exprès : c'est ainsi que les cas qui les visent prouvent
## bien ce qu'ils annoncent, l'ouvrier chôme parce que rien ne produit là et non parce
## qu'un plafond l'a écarté.
const OPEN_CAPACITY := 9

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
	var report := _resolve(CitySnapshot.empty(), [], LaborForce.empty(),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_int(report.upkeep()).is_equal(0)
	assert_bool(report.is_famine()).is_false()

func test_one_worker_on_a_two_slot_building_fills_one_slot() -> void:
	var report := _resolve(_city, [&"ana", HUT], _crew([&"ana"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(2)
	assert_int(report.work().size()).is_equal(1)

func test_two_workers_fill_both_slots() -> void:
	var report := _resolve(_city, [&"ana", HUT, &"bo", HUT],
		_crew([&"ana", &"bo"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)

## Le cas qui porte le jalon. Les slots se remplissent dans l'ordre de l'affectation :
## le troisième arrive quand il n'y a plus de poste, et chôme.
func test_a_third_worker_on_two_slots_stays_idle() -> void:
	var report := _resolve(_city, [&"ana", HUT, &"bo", HUT, &"cy", HUT],
		_crew([&"ana", &"bo", &"cy"]), Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)
	assert_array(report.idle()).contains_exactly([&"cy"])

func test_a_worker_sent_to_an_empty_anchor_stays_idle() -> void:
	var report := _resolve(_city, [&"ana", NOWHERE], _crew([&"ana"]),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## Un entrepôt est un bâtiment parfaitement valide où personne ne travaille : il n'a
## pas zéro poste, il n'a pas de bloc de production. L'ouvrier envoyé là chôme sans
## qu'aucun refus ne soit prononcé.
func test_a_worker_sent_to_a_building_without_a_production_block_stays_idle() -> void:
	assert_bool(_store.produces()).is_false()
	var report := _resolve(_city, [&"ana", STORE], _crew([&"ana"]),
		Ledger.create(100))
	assert_array(report.idle()).contains_exactly([&"ana"])

## Un chantier n'offre AUCUN poste, même sur un bâtiment qui produira très bien une
## fois fini. C'est la moitié du couple qui porte C4 : sans son jumeau ci-dessous, il
## passerait tout aussi bien si plus rien ne produisait jamais.
func test_a_worker_sent_to_an_unfinished_site_stays_idle() -> void:
	var city := _city_at(_site(_farm, 2), FARM, 1)
	var report := _resolve(city, [&"ana", FARM], _crew([&"ana"]),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.work()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## Le jumeau : le même bâtiment, le même ouvrier, le dernier cran posé. Seul
## l'avancement change entre les deux cas.
func test_the_same_site_produces_once_it_is_finished() -> void:
	var city := _city_at(_site(_farm, 2), FARM, 2)
	var report := _resolve(city, [&"ana", FARM], _crew([&"ana"]),
		Ledger.create(100))
	assert_int(report.produced()[FOOD]).is_equal(3)
	assert_int(report.work().size()).is_equal(1)
	assert_array(report.idle()).is_empty()

func test_an_unassigned_worker_stays_idle() -> void:
	var report := _resolve(_city, [], _crew([&"ana"]), Ledger.create(100))
	assert_array(report.idle()).contains_exactly([&"ana"])

## Une affectation peut avoir survécu à celui qui la portait. Il est ignoré sans un
## mot, et ne compte pas non plus comme oisif : un mort ne chôme pas.
func test_a_worker_absent_from_the_roster_is_ignored_entirely() -> void:
	var report := _resolve(_city, [&"ghost", HUT], LaborForce.empty(),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).is_empty()
	assert_int(report.work().size()).is_equal(0)

## Le second cas qui porte le jalon : l'upkeep tombe sur le roster entier, y compris
## sur les trois qui n'ont rien fait. C'est ce qui rend le pool tendu.
func test_upkeep_counts_the_whole_roster_including_the_idle() -> void:
	var report := _resolve(_city, [&"ana", HUT],
		_crew([&"ana", &"bo", &"cy", &"di"]), _stocked({FOOD: 50}))
	assert_int(report.upkeep()).is_equal(4)
	assert_int(report.consumed()).is_equal(4)

func test_a_skilled_worker_produces_more() -> void:
	var report := _resolve(_city, [&"ana", HUT], _skilled_crew(&"ana", 2.0),
		Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(4)

## Tronqué vers le bas : un multiplicateur sous 1.0 se paie vraiment, et un ouvrier ne
## rend jamais plus que ce que la data promet.
func test_a_fractional_multiplier_is_floored() -> void:
	var report := _resolve(_city, [&"ana", HUT], _skilled_crew(&"ana", 0.7),
		Ledger.create(100))
	assert_int(report.produced()[WOOD]).is_equal(1)

## Il a occupé le poste et mérite son XP ; il a juste mal produit. Sans cette ligne,
## les Effectifs ne sauraient pas qu'il a travaillé.
func test_a_worker_who_produces_nothing_still_gets_a_work_line() -> void:
	var report := _resolve(_city, [&"ana", HUT], _skilled_crew(&"ana", 0.1),
		Ledger.create(100))
	assert_dict(report.produced()).is_empty()
	assert_int(report.work().size()).is_equal(1)
	assert_array(report.idle()).is_empty()

## C'est par elle que les Effectifs sauront quelle piste créditer, sans avoir à
## rouvrir la ville pour retrouver le bâtiment.
func test_a_work_line_carries_the_family_of_its_building() -> void:
	var report := _resolve(_city, [&"ana", HUT], _crew([&"ana"]), Ledger.create(100))
	var line := report.work()[0]
	assert_str(line.family()).is_equal(HARVEST)
	assert_vector(line.cell()).is_equal(HUT)
	assert_str(line.worker()).is_equal(&"ana")

# --- Les actions jouées à cru ---------------------------------------------------------

## La seconde lecture de DESIGN.md 3.5, et la moitié qui n'avait aucun code avant D2.
## Une case nue rend ce que son tag dicte, et beaucoup moins qu'un poste de bâtiment.
func test_a_bare_harvest_yields_what_the_tag_dictates() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)], [&"ana", 1],
		_crew([&"ana"]))
	assert_int(report.produced()[WOOD]).is_equal(BARE_YIELD)
	assert_int(report.work().size()).is_equal(1)
	assert_array(report.idle()).is_empty()

## L'écart qui fait qu'on construit : la même carte, le même ouvrier, deux fois plus sur
## un poste de cabane. Sans ce couple, « rend peu » ne voudrait rien dire.
func test_the_same_card_yields_more_in_a_building_than_bare() -> void:
	var bare := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)], [&"ana", 1],
		_crew([&"ana"]))
	var slot := _resolve(_city, [&"ana", HUT], _crew([&"ana"]), Ledger.create(100))
	assert_int(slot.produced()[WOOD]).is_greater(bare.produced()[WOOD])

## Deux verbes sur la même forêt, chacun avec son ouvrier et sa ressource. C'est ce que
## D2 achète en donnant une identité aux actions : tant que l'affectation désignait une
## cellule, ces deux-là étaient indiscernables.
func test_two_actions_on_the_same_cell_both_resolve() -> void:
	var report := _resolve_bare(
		[_bare(1, HARVEST_CARD, WOODS), _bare(2, HUNT_CARD, WOODS)],
		[&"ana", 1, &"bo", 2], _crew([&"ana", &"bo"]))
	assert_int(report.produced()[WOOD]).is_equal(BARE_YIELD)
	assert_int(report.produced()[FOOD]).is_equal(BARE_YIELD)
	assert_int(report.work().size()).is_equal(2)

## La ligne porte la famille des actions à cru, celle de data/balance/, et sa cellule est
## la case nue. C'est par elle que les Effectifs sauront quoi créditer.
func test_a_bare_work_line_carries_the_bare_family_and_its_cell() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)], [&"ana", 1],
		_crew([&"ana"]))
	var line := report.work()[0]
	assert_str(line.family()).is_equal(HARVEST)
	assert_vector(line.cell()).is_equal(WOODS)

func test_a_skilled_worker_produces_more_bare_too() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)], [&"ana", 1],
		_skilled_crew(&"ana", 3.0))
	assert_int(report.produced()[WOOD]).is_equal(3 * BARE_YIELD)

## Le ciblage refuserait cette pose, et le résolveur n'en dépend pas : une action dont la
## cible a perdu son tag ne rend rien plutôt que de verser une ressource vide.
func test_a_bare_action_on_an_untagged_cell_yields_nothing() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, BARREN)], [&"ana", 1],
		_crew([&"ana"]))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## Le périmètre assumé de D2, et il vaut mieux qu'un test le dise qu'un commentaire :
## *Construire* et *Terraformer* se posent et s'affectent, et ne produisent rien tant que
## I1 ne les exécute pas. Leurs ouvriers comptent comme oisifs.
##
## Les deux sont écartés pour des raisons **structurelles** et non par leur nom, et le
## cas les met chacune sous la bonne : *Terraformer* vise une forêt parfaitement
## récoltable et ne rend rien parce que data/balance/ ne lui donne aucune table ;
## *Construire* vise un vrai chantier, sur un bâtiment qui produira très bien une fois
## fini, et ne rend rien parce qu'il n'est pas achevé. Sans cette précision, tous deux
## passeraient aussi bien en visant dans le vide.
func test_build_and_terraform_are_posted_but_yield_nothing_yet() -> void:
	var city := _city_at(_site(_farm, 2), SITE_CELL, 1)
	var report := ProductionResolver.resolve(_terrain(), city, ActionPlan.create([
			_bare(1, &"terraform", WOODS),
			PlayedAction.create(2, &"build", SITE_CELL, PlayedAction.Kind.BUILDING, 1)]),
		_on([&"ana", 1, &"bo", 2]), _crew([&"ana", &"bo"]), Ledger.create(100),
		_balance, _actions())
	assert_dict(report.produced()).is_empty()
	assert_array(report.work()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana", &"bo"])

## Son jumeau, et il est indispensable : le cas ci-dessus passerait tout aussi bien si
## plus rien ne produisait jamais. Le même chantier achevé, la même cellule, mais une
## carte *Récolter* — et cette fois le soir paie.
func test_the_same_site_finished_pays_a_harvest_but_still_not_a_build() -> void:
	var city := _city_at(_site(_farm, 2), SITE_CELL, 2)
	var harvest := ProductionResolver.resolve(_terrain(), city, ActionPlan.create([
			PlayedAction.create(1, HARVEST_CARD, SITE_CELL,
				PlayedAction.Kind.BUILDING, 1)]),
		_on([&"ana", 1]), _crew([&"ana"]), Ledger.create(100), _balance, _actions())
	assert_int(harvest.produced()[FOOD]).is_equal(3)
	var build := ProductionResolver.resolve(_terrain(), city, ActionPlan.create([
			PlayedAction.create(1, &"build", SITE_CELL, PlayedAction.Kind.BUILDING, 1)]),
		_on([&"ana", 1]), _crew([&"ana"]), Ledger.create(100), _balance, _actions())
	assert_dict(build.produced()).is_empty()

## Une action retirée après qu'on y a mis quelqu'un. L'affectation lui survit, ne
## désigne plus rien, et son ouvrier chôme sans que rien ne casse.
func test_an_assignment_naming_a_withdrawn_action_leaves_its_worker_idle() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)], [&"ana", 9],
		_crew([&"ana"]))
	assert_dict(report.produced()).is_empty()
	assert_array(report.idle()).contains_exactly([&"ana"])

## La capacité voyage figée sur l'action, et c'est elle qui plafonne — pas une relecture
## de la ville. Deux ouvriers sur une case nue qui n'en accepte qu'un : le second chôme.
func test_the_frozen_capacity_of_a_bare_action_caps_it() -> void:
	var report := _resolve_bare([_bare(1, HARVEST_CARD, WOODS)],
		[&"ana", 1, &"bo", 1], _crew([&"ana", &"bo"]))
	assert_int(report.produced()[WOOD]).is_equal(BARE_YIELD)
	assert_array(report.idle()).contains_exactly([&"bo"])

func test_the_harvest_enters_the_reserve() -> void:
	var ledger := Ledger.create(100)
	var report := _resolve(_city, [&"ana", HUT], _crew([&"ana"]), ledger)
	assert_int(ledger.amount(WOOD)).is_equal(2)
	assert_int(report.stored()[WOOD]).is_equal(2)
	assert_int(report.total_wasted()).is_equal(0)

## La réserve est pleine : la récolte tombe entière, et le rapport le dit. Sans ce
## chiffre, un joueur ne comprend pas pourquoi son bois n'augmente plus.
func test_a_harvest_that_overruns_the_reserve_is_reported_as_wasted() -> void:
	var ledger := _stocked({WOOD: 200})
	var report := _resolve(_city, [&"ana", HUT], _crew([&"ana"]), ledger)
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
	_resolve(_city, [], LaborForce.empty(), ledger)
	assert_int(ledger.capacity()).is_equal(200)

## La production précède l'upkeep : ce que la ferme sort ce soir nourrit ce soir.
func test_the_evening_harvest_feeds_the_same_evening() -> void:
	var report := _resolve(_city, [&"ana", FARM], _crew([&"ana"]), Ledger.create(100))
	assert_int(report.produced()[FOOD]).is_equal(3)
	assert_int(report.consumed()).is_equal(1)
	assert_bool(report.is_famine()).is_false()

func test_exactly_enough_food_is_not_a_famine() -> void:
	var report := _resolve(_city, [], _crew([&"ana", &"bo"]),
		_stocked({FOOD: 2}))
	assert_int(report.consumed()).is_equal(2)
	assert_int(report.unfed()).is_equal(0)
	assert_bool(report.is_famine()).is_false()

func test_a_short_reserve_leaves_workers_unfed() -> void:
	var ledger := _stocked({FOOD: 2})
	var report := _resolve(_city, [], _crew([&"ana", &"bo", &"cy", &"di"]),
		ledger)
	assert_int(report.upkeep()).is_equal(4)
	assert_int(report.consumed()).is_equal(2)
	assert_int(report.unfed()).is_equal(2)
	assert_bool(report.is_famine()).is_true()
	assert_int(ledger.amount(FOOD)).is_equal(0)

func test_an_empty_reserve_leaves_everyone_unfed() -> void:
	var report := _resolve(_city, [], _crew([&"ana", &"bo"]),
		Ledger.create(100))
	assert_int(report.consumed()).is_equal(0)
	assert_int(report.unfed()).is_equal(2)

## Arrondi vers le haut : à deux rations par ouvrier, un manque de trois laisse deux
## ouvriers sans ration entière. Une famine ne se sous-déclare jamais.
func test_a_partial_ration_still_counts_as_unfed() -> void:
	var balance := _make_balance(100, 2)
	var report := ProductionResolver.resolve(_terrain(), _city, ActionPlan.empty(),
		Assignment.empty(), _crew([&"ana", &"bo", &"cy"]), _stocked({FOOD: 3}),
		balance, _actions())
	assert_int(report.upkeep()).is_equal(6)
	assert_int(report.consumed()).is_equal(3)
	assert_int(report.unfed()).is_equal(2)

## Un seed et une suite d'actions doivent rejouer un run à l'identique. Deux
## résolutions des mêmes entrées ne peuvent pas diverger.
func test_two_identical_resolutions_agree() -> void:
	var played: Array = [&"ana", HUT, &"bo", HUT, &"cy", FARM]
	var crew := _crew([&"ana", &"bo", &"cy", &"di"])
	var first := _resolve(_city, played, crew, _stocked({FOOD: 10}))
	var second := _resolve(_city, played, crew, _stocked({FOOD: 10}))
	assert_dict(first.produced()).is_equal(second.produced())
	assert_dict(first.stored()).is_equal(second.stored())
	assert_array(first.idle()).is_equal(second.idle())
	assert_int(first.unfed()).is_equal(second.unfed())

## Résout un soir décrit par une liste plate — [ouvrier, cellule, ouvrier, cellule].
##
## Depuis D2, le résolveur part des **actions posées** et non des bâtiments. La liste
## décrit donc deux choses à la fois : une action de récolte par cellule distincte, et
## les ouvriers qui la tiennent. C'est exactement ce que la phase produira — on joue la
## carte sur une cible, puis on y met des gens —, en sautant l'étape de ciblage dont
## aucun de ces cas n'a besoin.
func _resolve(city: CitySnapshot, played: Array, labor: LaborForce,
		ledger: Ledger) -> ProductionReport:
	return ProductionResolver.resolve(_terrain(), city, _plan(city, played),
		_assign(city, played), labor, ledger, _balance, _actions())

## Capacité qu'un ciblage aurait donnée à une action de récolte sur cette cellule.
##
## Recopiée d'ActionTargeting plutôt qu'obtenue de lui : ce fichier teste le résolveur,
## et passer par le ciblage lui demanderait un vrai relief que ces villes fabriquées à
## la main n'ont pas.
func _capacity_at(city: CitySnapshot, cell: Vector2i) -> int:
	var building := city.at_cell(cell)
	if building == null or not building.is_complete() or not building.data().produces():
		return OPEN_CAPACITY
	return building.data().production.slots

## Une action de récolte par cellule distincte, dans l'ordre de première apparition.
func _plan(city: CitySnapshot, played: Array) -> ActionPlan:
	var posted: Array[PlayedAction] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var index := 0
	while index < played.size():
		var cell: Vector2i = played[index + 1]
		if not seen.has(cell):
			seen[cell] = true
			posted.append(PlayedAction.create(posted.size() + 1, HARVEST_CARD, cell,
				PlayedAction.Kind.BUILDING, _capacity_at(city, cell)))
		index += 2
	return ActionPlan.create(posted)

## Chaque ouvrier sur l'action de sa cellule, dans l'ordre de la liste.
## Cet ordre est celui du remplissage des postes, ce dont un cas se sert.
func _assign(city: CitySnapshot, played: Array) -> Assignment:
	var plan := _plan(city, played)
	var by_cell: Dictionary[Vector2i, int] = {}
	for action in plan.actions():
		by_cell[action.target()] = action.id()
	var table: Dictionary[StringName, int] = {}
	var index := 0
	while index < played.size():
		table[played[index]] = by_cell[played[index + 1]]
		index += 2
	return Assignment.create(table)

## Résout un soir dont les actions sont données telles quelles, avec leurs ouvriers.
##
## Les cas « à cru » ont besoin de nommer la carte et la nature de chaque action, ce que
## la liste plate de _resolve() ne permet pas — elle ne pose que des récoltes en slot. Ils
## passent donc par ici, et la ville qu'ils voient est vide : rien de ce qu'ils testent
## n'est bâti.
func _resolve_bare(posted: Array, workers: Array,
		labor: LaborForce) -> ProductionReport:
	var actions: Array[PlayedAction] = []
	actions.assign(posted)
	return ProductionResolver.resolve(_terrain(), CitySnapshot.empty(),
		ActionPlan.create(actions), _on(workers), labor, Ledger.create(100),
		_balance, _actions())

## Une action posée sur une case nue.
func _bare(id: int, card: StringName, cell: Vector2i) -> PlayedAction:
	return PlayedAction.create(id, card, cell, PlayedAction.Kind.BARE, 1)

## Affectation depuis une liste plate — [ouvrier, action, ouvrier, action].
func _on(flat: Array) -> Assignment:
	var table: Dictionary[StringName, int] = {}
	var index := 0
	while index < flat.size():
		table[flat[index]] = flat[index + 1]
		index += 2
	return Assignment.create(table)

## Un relief plat et constructible, avec une forêt en (3, 1) et rien de taggé en (4, 1).
##
## Les cas « en slot » n'en lisent jamais les tags — ils visent un bâtiment —, mais le
## résolveur réclame le contrat Terrain depuis que la seconde lecture de DESIGN.md 3.5
## existe, et les cas « à cru » ont besoin d'une cellule qui rend et d'une qui ne rend
## rien.
func _terrain() -> TerrainQuery:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	var forest := TerrainData.new()
	forest.id = &"forest"
	forest.build = TerrainData.Build.ALLOWED
	var tags: Array[StringName] = [&"forest"]
	forest.tags = tags
	var grid := HeightGrid.create(Vector2i(24, 24), 0, plain)
	grid.set_terrain(WOODS, forest)
	return grid.to_query()

## Équilibrage des actions à cru : la forêt rend du bois à *Récolter* et de la nourriture
## à *Chasser*. *Terraformer* n'a pas de table, et c'est par là qu'il sort de la
## production sans que le résolveur ait à le nommer.
func _actions() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = 1
	balance.bare_yield = BARE_YIELD
	balance.bare_skill_family = HARVEST
	var slots: Array[StringName] = [HARVEST_CARD]
	balance.slot_cards = slots
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[HARVEST_CARD] = {&"forest": WOOD}
	sources[HUNT_CARD] = {&"forest": FOOD}
	balance.bare_sources = sources
	return balance

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
