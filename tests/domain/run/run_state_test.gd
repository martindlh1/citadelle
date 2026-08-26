class_name RunStateTest
extends GdUnitTestSuite
## Ce qu'un run possède à l'ouverture, et le brouillon d'affectation qu'il tient.
##
## L'équilibrage de travail est le `.tres` réel **dupliqué en surface**, dont les cinq
## blocs que ces cas lisent sont remplacés par des blocs écrits à la main. Les trois
## autres — terrain, génération, caméra — restent ceux de `data/` et ne sont jamais mutés :
## `RunState.open()` exige un équilibrage complet, et fabriquer vingt chiffres de relief
## qu'aucune assertion ne lit serait du bruit. La duplication du seul objet racine suffit,
## puisqu'on **remplace** des champs au lieu de modifier des sous-ressources partagées.

const BALANCE_PATH := "res://data/balance/balance.tres"

const SEED := 4242
const MAP := Vector2i(8, 8)
const GROUND_HEIGHT := 2
const FOREST := Vector2i(2, 2)

const CARD_HUT := &"hut"
const HUT_COST := 10
const HUT_ACTIONS := 2
const BASE_CAP := 100
const OPENING_FOOD := 20
const OPENING_WOOD := 30
const HAND_ACTIONS := 9
const HAND_BUILDINGS := 3
const DAYS := 3

const CONSTRUCTION := &"construction"
const HARVEST := &"harvest"

func test_a_run_opens_on_its_seed_and_its_first_phase() -> void:
	var state := _open()
	assert_int(state.run_seed()).is_equal(SEED)
	assert_int(state.cycle().day()).is_equal(1)
	assert_int(state.cycle().phase_index()).is_equal(0)
	assert_bool(state.cycle().is_over()).is_false()

func test_a_run_opens_on_the_stock_data_names() -> void:
	var state := _open()
	assert_int(state.ledger().amount(&"food")).is_equal(OPENING_FOOD)
	assert_int(state.ledger().amount(&"wood")).is_equal(OPENING_WOOD)
	assert_int(state.ledger().capacity()).is_equal(BASE_CAP)

## Un run s'ouvre sur une main : sans elle, la première phase n'aurait rien à jouer.
func test_a_run_opens_on_a_hand() -> void:
	var state := _open()
	assert_int(state.deck().hand_size(CardData.POOL_ACTION)).is_equal(HAND_ACTIONS)
	assert_int(state.deck().hand_size(CardData.POOL_BUILDING)).is_equal(HAND_BUILDINGS)
	assert_int(state.deck().hand_size(CardData.POOL_POWER)).is_equal(0)

## Le cas qui porte le déterminisme du run. `CLAUDE.md` promet qu'un seed plus une suite
## d'actions rejoue à l'identique ; ça commence par la main, qui vient d'un mélange.
func test_two_runs_on_one_seed_open_on_the_same_hand() -> void:
	assert_array(_open().deck().hand().cards()) \
		.is_equal(_open().deck().hand().cards())

func test_two_seeds_do_not_open_on_the_same_rng() -> void:
	assert_int(_open().rng().randi()).is_not_equal(_open(SEED + 1).rng().randi())

## `DESIGN.md` 2 fait de la pose du Cœur une **étape** du run — « génération de carte →
## pose du Cœur → suite de journées ». `I1` l'avait bouchonnée en le posant au centre à
## l'ouverture ; depuis `I2` le run l'attend, et c'est `RunOrchestrator.found()` qui pose.
##
## Le bâtiment est nommé dans `data/balance/`, ce qui est la seule raison pour laquelle ces
## cas peuvent se passer d'écrire « heart ».
func test_a_run_awaits_its_heart_before_anything() -> void:
	var state := _open(SEED, CARD_HUT)
	assert_bool(state.awaits_its_heart()).is_true()
	assert_int(state.city().count()).is_equal(0)
	assert_vector(state.heart_anchor()).is_equal(RunState.NO_CELL)

## La main est tirée à la fondation et non à l'ouverture, sans quoi le premier écran
## promettrait des cartes que rien ne permet encore de jouer.
func test_a_run_that_awaits_its_heart_has_not_drawn() -> void:
	assert_int(_open(SEED, CARD_HUT).deck().hand().size()).is_equal(0)

## Vide est une réponse et non un oubli : c'est le run d'un harnais qui veut une carte
## nue. Celui-là n'attend rien et démarre sa journée aussitôt.
func test_a_run_without_a_starting_building_opens_on_an_empty_city() -> void:
	var state := _open()
	assert_bool(state.awaits_its_heart()).is_false()
	assert_int(state.city().count()).is_equal(0)

## La pose automatique de `I1` survit en **suggestion**, ce que `F1` annonçait mot pour mot
## du déploiement automatique : « la règle automatique lui survivra comme bouton par
## défaut ». Elle propose toujours la case que `I1` posait.
func test_the_suggested_anchor_is_the_one_I1_used_to_place() -> void:
	assert_vector(_open(SEED, CARD_HUT).suggested_heart_anchor()).is_equal(MAP / 2)

## Elle ne dépend pas du seed : c'est un balayage géométrique, pas un tirage.
func test_the_suggestion_lands_on_the_same_cell_every_time() -> void:
	assert_vector(_open(SEED, CARD_HUT).suggested_heart_anchor()) \
		.is_equal(_open(SEED + 7, CARD_HUT).suggested_heart_anchor())

## Un run sans bâtiment d'ouverture n'a rien à suggérer, et le dit plutôt que de proposer
## une case au hasard.
func test_a_run_without_a_starting_building_suggests_nothing() -> void:
	assert_vector(_open().suggested_heart_anchor()).is_equal(RunState.NO_CELL)

# --- Le brouillon d'affectation --------------------------------------------------------

func test_a_fresh_run_has_nobody_at_work() -> void:
	var state := _open()
	assert_array(state.free_workers()).has_size(3)
	assert_bool(state.is_staffed(&"ana")).is_false()
	assert_int(state.to_assignment().size()).is_equal(0)

func test_a_staffed_worker_leaves_the_free_list() -> void:
	var state := _open()
	state.assign_worker(&"ana", 1)
	assert_bool(state.is_staffed(&"ana")).is_true()
	assert_array(state.free_workers()).has_size(2)
	assert_array(state.staffed_on(1)).contains_exactly([&"ana"])

func test_releasing_a_worker_frees_them() -> void:
	var state := _open()
	state.assign_worker(&"ana", 1)
	assert_bool(state.release_worker(&"ana")).is_true()
	assert_bool(state.release_worker(&"ana")).is_false()
	assert_array(state.free_workers()).has_size(3)

func test_releasing_an_action_recalls_everyone_on_it() -> void:
	var state := _open()
	state.assign_worker(&"ana", 1)
	state.assign_worker(&"bo", 1)
	state.assign_worker(&"cy", 2)
	assert_array(state.release_action(1)).contains_exactly([&"ana", &"bo"])
	assert_array(state.staffed_on(1)).is_empty()
	assert_array(state.staffed_on(2)).contains_exactly([&"cy"])

## L'ordre d'affectation décide du remplissage des postes : sur une action sur-affectée,
## les premiers arrivés travaillent. Un brouillon qui ne le conserverait pas ferait
## diverger deux rejeux du même seed.
func test_the_assignment_keeps_the_order_workers_were_sent_in() -> void:
	var state := _open()
	state.assign_worker(&"cy", 1)
	state.assign_worker(&"ana", 1)
	assert_array(state.to_assignment().workers_on(1)).contains_exactly([&"cy", &"ana"])

func test_clearing_the_draft_empties_it() -> void:
	var state := _open()
	state.assign_worker(&"ana", 1)
	state.clear_staffing()
	assert_int(state.to_assignment().size()).is_equal(0)
	assert_array(state.free_workers()).has_size(3)

# --- Les vues -------------------------------------------------------------------------

## La query est une vue et non une copie : un terrassement appliqué à la grille se lit
## immédiatement à travers elle, sans invalidation. C'est ce qui permet à
## `RunOrchestrator` de muter le relief sans rien reconstruire.
func test_the_terrain_view_follows_the_grid_it_wraps() -> void:
	var state := _open()
	state.grid().set_height(FOREST, GROUND_HEIGHT + 3)
	assert_int(state.terrain().height_at(FOREST)).is_equal(GROUND_HEIGHT + 3)

## Reprojetée à chaque appel : une soirée d'XP change les multiplicateurs, et une
## projection gardée à côté vieillirait sans que rien ne le dise.
func test_the_labor_projection_follows_the_roster() -> void:
	var state := _open()
	assert_int(state.labor().size()).is_equal(3)
	state.roster().worker(&"ana").set_present(false)
	assert_int(state.labor().size()).is_equal(2)

func test_an_unknown_building_reads_as_nothing() -> void:
	assert_object(_open().building(&"nowhere")).is_null()

# --- La mise en place -------------------------------------------------------------------

func _open(run_seed := SEED, starting := &"") -> RunState:
	return RunState.open(run_seed, _make_grid(), _make_roster(), _make_catalogue(),
		_make_buildings(), _make_balance(starting))

func _make_grid() -> HeightGrid:
	var grid := HeightGrid.create(MAP, GROUND_HEIGHT, _terrain(&"plain", []))
	grid.set_terrain(FOREST, _terrain(&"forest", [&"forest"]))
	return grid

func _terrain(id: StringName, tags: Array) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	var typed: Array[StringName] = []
	typed.assign(tags)
	data.tags = typed
	return data

func _make_roster() -> Roster:
	var workers: Array[Worker] = [
		Worker.create(&"ana", "Ana"), Worker.create(&"bo", "Bo"),
		Worker.create(&"cy", "Cy")]
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = [
		_card(ActionTargeting.CARD_HARVEST, CardData.POOL_ACTION),
		_card(SiteResolver.CARD_BUILD, CardData.POOL_ACTION),
		_card(SiteResolver.CARD_TERRAFORM, CardData.POOL_ACTION),
		_card(CARD_HUT, CardData.POOL_BUILDING, CARD_HUT)]
	return CardCatalogue.create(cards)

func _card(id: StringName, pool: StringName, builds := &"") -> CardData:
	var data := CardData.new()
	data.id = id
	data.label = String(id).capitalize()
	data.pool = pool
	data.building = builds
	return data

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	table[CARD_HUT] = _hut()
	return table

func _hut() -> BuildingData:
	var data := BuildingData.new()
	data.id = CARD_HUT
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	data.build_actions = HUT_ACTIONS
	var cost: Dictionary[StringName, int] = {}
	cost[&"wood"] = HUT_COST
	data.cost = cost
	var block := ProductionBlock.new()
	block.slots = 2
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = HARVEST
	data.production = block
	return data

## Le .tres réel, dupliqué en surface, dont les cinq blocs lus ici sont remplacés. Voir le
## docstring de la suite.
func _make_balance(starting: StringName) -> BalanceData:
	var balance := (load(BALANCE_PATH) as BalanceData).duplicate() as BalanceData
	balance.economy = _economy()
	balance.workforce = _workforce()
	balance.deck = _deck()
	balance.actions = _actions()
	balance.run = _run(starting)
	assert_array(balance.missing_fields()) \
		.override_failure_message("équilibrage de test incomplet") \
		.is_empty()
	return balance

func _economy() -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = BASE_CAP
	economy.upkeep_per_worker = 1
	economy.upkeep_resource = &"food"
	var stock: Dictionary[StringName, int] = {}
	stock[&"food"] = OPENING_FOOD
	stock[&"wood"] = OPENING_WOOD
	economy.starting_stock = stock
	return economy

func _workforce() -> WorkforceBalance:
	var workforce := WorkforceBalance.new()
	workforce.base_roster_places = 10
	workforce.xp_per_shift = 4
	workforce.skill_xp_per_level = 25
	workforce.max_skill_level = 5
	workforce.efficiency_per_skill_level = 0.15
	workforce.worker_xp_per_level = 40
	workforce.max_worker_level = 10
	return workforce

## Le deck entier tient dans la main, exprès : les cas jouent une carte donnée sans
## dépendre de ce qu'un mélange a bien voulu servir.
func _deck() -> DeckBalance:
	var deck := DeckBalance.new()
	var copies: Dictionary[StringName, int] = {}
	copies[ActionTargeting.CARD_HARVEST] = 3
	copies[SiteResolver.CARD_BUILD] = 3
	copies[SiteResolver.CARD_TERRAFORM] = 3
	copies[CARD_HUT] = 3
	deck.starting_deck = copies
	var sizes: Dictionary[StringName, int] = {}
	sizes[CardData.POOL_ACTION] = HAND_ACTIONS
	sizes[CardData.POOL_BUILDING] = HAND_BUILDINGS
	sizes[CardData.POOL_POWER] = 0
	deck.hand_size = sizes
	deck.draft_choices = 3
	return deck

func _actions() -> ActionBalance:
	var actions := ActionBalance.new()
	actions.bare_capacity = 1
	actions.bare_yield = 1
	actions.bare_skill_family = HARVEST
	actions.site_skill_family = CONSTRUCTION
	actions.terraform_floor = 0
	actions.terraform_ceiling = 4
	var slots: Array[StringName] = [HARVEST]
	actions.slot_cards = slots
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[HARVEST] = {&"forest": &"wood"}
	actions.bare_sources = sources
	return actions

## Deux phases anonymes : la première pose, la seconde affecte et résout. Leurs noms ne
## sont lus par personne, ici pas plus qu'ailleurs.
func _run(starting: StringName) -> RunBalance:
	var run := RunBalance.new()
	run.days = DAYS
	run.starting_building = starting
	run.score_per_resource = 1
	run.score_per_building = 1
	run.score_per_worker = 1
	run.score_per_worker_level = 1
	var phases: Array[PhaseDef] = [
		_phase(&"first", [PhaseDef.ACTION_PLAY], false),
		_phase(&"second", [PhaseDef.ACTION_ASSIGN], true)]
	run.phases = phases
	return run

func _phase(id: StringName, allows: Array, resolves: bool) -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = id
	phase.label = String(id)
	var kinds: Array[StringName] = []
	kinds.assign(allows)
	phase.allows = kinds
	phase.resolves = resolves
	return phase
