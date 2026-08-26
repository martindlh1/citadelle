class_name StaffingAdvisorTest
extends GdUnitTestSuite
## Qui envoyer où : la famille qu'une action crédite, le classement, et le plan.
##
## La suite travaille sur des objets nus plutôt que sur un `RunState` : l'advisor est
## pur, et le tenir à distance d'un run est la seule façon de fabriquer les situations
## qui comptent — un poste à moitié pris, un ouvrier absent de la projection, une action
## que rien ne crédite. `run_orchestrator_test.gd` couvre l'autre versant, celui du geste
## appliqué à un vrai run.
##
## Deux familles opposées d'un bout à l'autre, `harvest` et `construction`, parce que
## tout le jalon repose sur le fait qu'un spécialiste ne soit pas interchangeable. Une
## suite qui n'en aurait qu'une passerait sur une auto-affectation qui prend le premier
## venu, ce qui est précisément le bouchon que `W2` remplace.

const MAP := Vector2i(8, 8)
const GROUND := 2

const FOREST := Vector2i(2, 2)
const OTHER_FOREST := Vector2i(3, 2)
const DIRT := Vector2i(1, 6)
const HUT := Vector2i(4, 4)
const SITE := Vector2i(6, 6)

const CARD_HUT := &"hut"

const HARVEST := &"harvest"
const CONSTRUCTION := &"construction"

const HUT_SLOTS := 2
const HUT_ACTIONS := 2
const BARE_CAPACITY := 1
const BARE_YIELD := 1

## Trois ouvriers aux profils opposés : une récoltante, un bâtisseur, un bleu. Les
## multiplicateurs sont écrits à la main plutôt que gagnés — la courbe de paliers est le
## sujet de `skill_track_test.gd`, pas celui-ci.
const ANA := &"ana"
const BO := &"bo"
const CY := &"cy"

const GOOD := 1.6
const FAIR := 1.3
const PLAIN := 1.0

var _next_action := 1

# --- La famille qu'une action crédite ---------------------------------------------------

func test_a_production_slot_credits_the_family_of_its_building() -> void:
	assert_str(_family(_on_building(HARVEST, HUT, HUT_SLOTS))).is_equal(HARVEST)

func test_a_bare_action_credits_the_bare_family() -> void:
	assert_str(_family(_bare(HARVEST, FOREST))).is_equal(HARVEST)

func test_building_a_site_credits_the_site_family() -> void:
	assert_str(_family(_on_building(SiteResolver.CARD_BUILD, SITE, HUT_ACTIONS))) \
		.is_equal(CONSTRUCTION)

## Les deux verbes de chantier remuent la même terre, et `I1` leur a donné la même piste.
func test_terraforming_credits_the_site_family() -> void:
	var dig := _bare(SiteResolver.CARD_TERRAFORM, DIRT, 1, PlayedAction.DIRECTION_DOWN)
	assert_str(_family(dig)).is_equal(CONSTRUCTION)

## Une action devenue creuse ne crédite personne, et c'est ce &"" qui la fait sauter par
## le plan. Rien ne détruit un bâtiment aujourd'hui, mais le `DamageReport` de `F1` le
## fera, et une action posée survivra à sa cible comme une affectation survit à son
## action.
func test_an_action_whose_target_vanished_credits_nobody() -> void:
	var orphan := _on_building(HARVEST, Vector2i(7, 7), HUT_SLOTS)
	assert_str(_family(orphan)).is_empty()

## L'ordre des deux questions n'est pas indifférent. `ProductionResolver` répond en
## premier parce que c'est lui qui **refuse** *Construire* posé sur un bâtiment qui
## produit ; inverser laisserait un poste de récolte crédité en Construction dès qu'une
## carte de chantier viendrait à s'y poser.
func test_the_production_reading_is_asked_before_the_site_one() -> void:
	var on_the_hut := _on_building(SiteResolver.CARD_BUILD, HUT, 1)
	assert_str(ProductionResolver.family_of(on_the_hut, _terrain(), _city(), _actions())) \
		.is_empty()
	assert_str(_family(on_the_hut)).is_equal(CONSTRUCTION)

## **Le cas qui porte la suite.** La famille annoncée est celle que le soir crédite
## vraiment — sans quoi l'écran classerait les ouvriers sur une piste que personne ne
## gagne, et le défaut ne se verrait que sur une courbe d'XP au bout de dix journées.
## Les deux résolveurs sont interrogés pour de bon, et chaque ligne de travail est
## confrontée à la réponse de l'advisor pour son action.
func test_the_announced_family_is_the_one_the_evening_credits() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var bare := _bare(HARVEST, FOREST)
	var site := _on_building(SiteResolver.CARD_BUILD, SITE, HUT_ACTIONS)
	var posted := _plan_of([slot, bare, site])
	var assign := _assign({ANA: slot.id(), BO: bare.id(), CY: site.id()})
	var labor := _labor()

	var lines: Array[WorkLine] = []
	lines.append_array(ProductionResolver.resolve(_terrain(), _city(), posted, assign,
		labor, Ledger.create(999), _economy(), _actions()).work())
	lines.append_array(SiteResolver.resolve(_city(), posted, assign, labor,
		_actions()).work())

	var by_cell: Dictionary[Vector2i, PlayedAction] = {}
	for action in [slot, bare, site]:
		by_cell[action.target()] = action
	assert_int(lines.size()).is_equal(3)
	for line in lines:
		assert_str(line.family()) \
			.override_failure_message("la ligne de %s ne porte pas la famille annoncée"
				% line.cell()) \
			.is_equal(_family(by_cell[line.cell()]))

# --- Le classement -----------------------------------------------------------------------

func test_the_best_of_a_family_comes_first() -> void:
	var expected: Array[StringName] = [ANA, CY, BO]
	assert_array(StaffingAdvisor.ranked_for(_everyone(), _labor(), HARVEST)) \
		.is_equal(expected)

func test_another_family_gives_another_order() -> void:
	var expected: Array[StringName] = [BO, ANA, CY]
	assert_array(StaffingAdvisor.ranked_for(_everyone(), _labor(), CONSTRUCTION)) \
		.is_equal(expected)

## Une famille que personne n'a entamée laisse tout le monde à `BASE_EFFICIENCY`, donc
## l'ordre reçu intact. C'est le cas du premier soir d'un run, et il ne doit surtout pas
## rendre un ordre arbitraire.
func test_a_family_nobody_practises_keeps_the_order_it_was_given() -> void:
	var ranked := StaffingAdvisor.ranked_for(_everyone(), _labor(), &"smithing")
	assert_array(ranked).is_equal(_everyone())

## À efficacité égale, c'est le rang reçu qui départage — donc l'ordre du roster. Sans
## cette règle, deux runs partis du même seed enverraient deux ouvriers différents sur le
## même poste, et le déterminisme tomberait sans qu'aucun test de production ne bronche.
func test_a_tie_is_broken_by_the_order_received() -> void:
	var reversed: Array[StringName] = [CY, BO, ANA]
	assert_array(StaffingAdvisor.ranked_for(_everyone(), _labor(), &"smithing")) \
		.is_equal(_everyone())
	assert_array(StaffingAdvisor.ranked_for(reversed, _labor(), &"smithing")) \
		.is_equal(reversed)

# --- Les postes qui restent ---------------------------------------------------------------

func test_an_untouched_action_offers_all_its_posts() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	assert_int(StaffingAdvisor.room_on(slot, Assignment.empty())).is_equal(HUT_SLOTS)

func test_a_half_staffed_action_offers_what_is_left() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	assert_int(StaffingAdvisor.room_on(slot, _assign({ANA: slot.id()}))).is_equal(1)

## Jamais négatif : une action sur-affectée n'offre pas des postes en creux. Le cas
## existe — le résolveur laisse chômer ceux qui débordent plutôt que de les refuser.
func test_an_overstaffed_action_offers_nothing() -> void:
	var bare := _bare(HARVEST, FOREST)
	assert_int(StaffingAdvisor.room_on(bare, _assign({ANA: bare.id(), BO: bare.id()}))) \
		.is_equal(0)

# --- Le plan ------------------------------------------------------------------------------

## La décision de fond de `DESIGN.md` 3.4 : chacun sur son métier. La récoltante va à la
## cabane, le bâtisseur au chantier — et non l'inverse, qui est exactement ce que
## « le premier ouvrier libre » produisait jusqu'ici.
func test_each_worker_goes_to_the_family_he_is_good_at() -> void:
	var slot := _on_building(HARVEST, HUT, 1)
	var site := _on_building(SiteResolver.CARD_BUILD, SITE, 1)
	var orders := _plan([slot, site], Assignment.empty())
	assert_int(orders[ANA]).is_equal(slot.id())
	assert_int(orders[BO]).is_equal(site.id())

## L'ordre de pose est la priorité que le joueur a déjà exprimée, et le bouton s'y tient.
## Il ne choisit jamais quelle action mérite un ouvrier — seulement qui.
func test_the_posting_order_decides_who_gets_served_first() -> void:
	var first := _bare(HARVEST, FOREST)
	var second := _bare(HARVEST, OTHER_FOREST)
	var orders := _plan([first, second], Assignment.empty())
	assert_int(orders[ANA]).is_equal(first.id())
	assert_int(orders[CY]).is_equal(second.id())

func test_a_plan_never_exceeds_what_an_action_accepts() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var orders := _plan([slot], Assignment.empty())
	assert_int(orders.size()).is_equal(HUT_SLOTS)

## La surcharge manuelle, et c'est la moitié du bouton : on place à la main ceux dont on
## se soucie, le bouton fait le reste sans jamais y toucher.
func test_a_worker_already_placed_by_hand_is_left_alone() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var site := _on_building(SiteResolver.CARD_BUILD, SITE, 1)
	var orders := _plan([slot, site], _assign({ANA: site.id()}))
	assert_bool(orders.has(ANA)).is_false()
	assert_int(orders[BO]).is_equal(slot.id())

func test_an_action_that_is_already_full_gets_nobody() -> void:
	var bare := _bare(HARVEST, FOREST)
	assert_dict(_plan([bare], _assign({BO: bare.id()}))).is_empty()

## Y envoyer quelqu'un est l'erreur évidente que le bouton doit éviter, pas commettre.
func test_an_action_that_credits_nobody_is_skipped() -> void:
	var orphan := _on_building(HARVEST, Vector2i(7, 7), HUT_SLOTS)
	assert_dict(_plan([orphan], Assignment.empty())).is_empty()

## La main-d'œuvre ne porte que les présents, donc un absent ne peut pas être planifié.
## La contrainte de `DESIGN.md` 3.9 se paie une seule fois, dans `Roster.to_labor()`, et
## ce fichier n'a pas à la connaître — ce cas le vérifie plutôt que de le supposer.
func test_a_worker_the_projection_does_not_carry_is_never_planned() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var here: Array[LaborUnit] = [_unit(ANA, GOOD, PLAIN), _unit(CY, FAIR, PLAIN)]
	var orders := StaffingAdvisor.plan(_terrain(), _city(), _plan_of([slot]),
		Assignment.empty(), LaborForce.create(here), _actions())
	assert_bool(orders.has(BO)).is_false()
	assert_int(orders.size()).is_equal(HUT_SLOTS)

func test_nothing_posted_plans_nothing() -> void:
	assert_dict(_plan([], Assignment.empty())).is_empty()

func test_everyone_already_at_work_plans_nothing() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var busy := _assign({ANA: slot.id(), BO: slot.id(), CY: slot.id()})
	assert_dict(_plan([slot], busy)).is_empty()

## Le déterminisme, qui n'est pas une propriété esthétique ici : `CLAUDE.md` promet qu'un
## seed plus une suite de gestes rejoue un run à l'identique, et le bouton est un geste.
func test_the_same_state_always_plans_the_same_thing() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var site := _on_building(SiteResolver.CARD_BUILD, SITE, 1)
	var posted: Array[PlayedAction] = [slot, site]
	assert_dict(_plan(posted, Assignment.empty())) \
		.is_equal(_plan(posted, Assignment.empty()))

## Et le revers : le plan **ordonne**, il ne mute rien. Deux appels d'affilée sur la même
## affectation rendent le même plan parce que rien n'a bougé entre les deux — c'est ce qui
## permet à un écran de l'appeler pour prévisualiser sans rien engager.
func test_planning_twice_changes_nothing_in_between() -> void:
	var slot := _on_building(HARVEST, HUT, HUT_SLOTS)
	var assign := _assign({ANA: slot.id()})
	_plan([slot], assign)
	assert_int(assign.size()).is_equal(1)
	assert_int(StaffingAdvisor.room_on(slot, assign)).is_equal(1)

# --- La mise en place -----------------------------------------------------------------------

func _family(action: PlayedAction) -> StringName:
	return StaffingAdvisor.family_of(action, _terrain(), _city(), _actions())

func _plan(posted: Array, assign: Assignment) -> Dictionary[StringName, int]:
	return StaffingAdvisor.plan(_terrain(), _city(), _plan_of(posted), assign, _labor(),
		_actions())

func _plan_of(posted: Array) -> ActionPlan:
	var typed: Array[PlayedAction] = []
	typed.assign(posted)
	return ActionPlan.create(typed)

func _assign(table: Dictionary) -> Assignment:
	var typed: Dictionary[StringName, int] = {}
	for worker: StringName in table:
		typed[worker] = table[worker]
	return Assignment.create(typed)

## Une action posée sur une cellule nue.
func _bare(card: StringName, cell: Vector2i, capacity := BARE_CAPACITY,
		direction := PlayedAction.DIRECTION_NONE) -> PlayedAction:
	return _post(card, cell, PlayedAction.Kind.BARE, capacity, direction)

## Une action posée sur l'ancre d'un bâtiment.
func _on_building(card: StringName, anchor: Vector2i, capacity: int) -> PlayedAction:
	return _post(card, anchor, PlayedAction.Kind.BUILDING, capacity,
		PlayedAction.DIRECTION_NONE)

## Les identifiants montent sans jamais reculer, comme ceux du board : deux actions d'un
## même cas ne peuvent pas se confondre, y compris après un retrait.
func _post(card: StringName, cell: Vector2i, kind: PlayedAction.Kind, capacity: int,
		direction: int) -> PlayedAction:
	var action := PlayedAction.create(_next_action, card, cell, kind, capacity, direction)
	_next_action += 1
	return action

func _everyone() -> Array[StringName]:
	var all: Array[StringName] = [ANA, BO, CY]
	return all

## Ana récolte bien et bâtit passablement, Bo l'inverse, Cy n'a rien de mieux que la
## moyenne dans les deux. Trois profils suffisent : le meilleur, son contraire, et celui
## qui ne départage rien.
func _labor() -> LaborForce:
	var units: Array[LaborUnit] = [
		_unit(ANA, GOOD, FAIR), _unit(BO, PLAIN, GOOD), _unit(CY, FAIR, PLAIN)]
	return LaborForce.create(units)

func _unit(id: StringName, harvest: float, construction: float) -> LaborUnit:
	var multipliers: Dictionary[StringName, float] = {}
	multipliers[HARVEST] = harvest
	multipliers[CONSTRUCTION] = construction
	return LaborUnit.create(id, multipliers)

## Une cabane achevée et un chantier à peine ouvert : les deux lectures de `CitySnapshot`
## que `C4` a séparées, et les deux seules dont la famille d'une action dépende.
func _city() -> CitySnapshot:
	var city := CityState.new()
	var terrain := _terrain()
	city.place(terrain, _hut(), HUT)
	for _step in HUT_ACTIONS:
		city.advance(HUT)
	city.place(terrain, _hut(), SITE)
	return city.to_snapshot()

func _terrain() -> TerrainQuery:
	var grid := HeightGrid.create(MAP, GROUND, _ground(&"plain", []))
	grid.set_terrain(FOREST, _ground(&"forest", [&"forest"]))
	grid.set_terrain(OTHER_FOREST, _ground(&"forest", [&"forest"]))
	return grid.to_query()

func _ground(id: StringName, tags: Array) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	var typed: Array[StringName] = []
	typed.assign(tags)
	data.tags = typed
	return data

func _hut() -> BuildingData:
	var data := BuildingData.new()
	data.id = CARD_HUT
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	data.build_actions = HUT_ACTIONS
	var free: Dictionary[StringName, int] = {}
	data.cost = free
	var block := ProductionBlock.new()
	block.slots = HUT_SLOTS
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = HARVEST
	data.production = block
	return data

func _actions() -> ActionBalance:
	var actions := ActionBalance.new()
	actions.bare_capacity = BARE_CAPACITY
	actions.bare_yield = BARE_YIELD
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

func _economy() -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = 999
	economy.upkeep_per_worker = 1
	economy.upkeep_resource = &"food"
	var nothing: Dictionary[StringName, int] = {}
	economy.starting_stock = nothing
	return economy
