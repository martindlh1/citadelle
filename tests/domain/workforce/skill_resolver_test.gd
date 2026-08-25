class_name SkillResolverTest
extends GdUnitTestSuite
## La distribution d'XP d'un soir : ce que le journal de travail vaut aux ouvriers.
##
## Le cas qui porte le jalon est le dernier du fichier, et c'est le seul de tout le
## projet qui fasse tourner deux systèmes ensemble : **résoudre un soir, distribuer
## l'XP, reprojeter, résoudre le suivant — et la récolte a monté.** E1 avait écrit un
## journal de travail que personne ne lisait ; c'est ce cas qui prouve qu'il sert.
##
## Réglages choisis pour que la boucle se voie en deux soirs : un poste tenu vaut
## exactement un palier, et un palier vaut la moitié du rendement en plus. Rien de tout
## ça ne vient de data/balance/ — ces chiffres bougeront, la mécanique non.

const HARVEST := &"harvest"

## La carte qui met la piste de récolte au travail. Le même mot que la famille sans être
## la même chose : l'une est une piste des Effectifs, l'autre un identifiant de data/cards/.
const HARVEST_CARD := &"harvest"
const CRAFT := &"craft"
const WOOD := &"wood"
const FOOD := &"food"
const HUT := Vector2i(1, 1)

## L'identifiant de la seule action que ces deux soirs posent.
const HUT_ACTION := 1

func test_an_evening_without_work_credits_nobody() -> void:
	var roster := _roster([&"ana", &"bo"])
	var progress := SkillResolver.award(roster, _report([]), _balance())
	assert_bool(progress.is_empty()).is_true()
	assert_int(progress.total_xp()).is_equal(0)
	assert_int(roster.worker(&"ana").xp()).is_equal(0)

## Une ligne crédite exactement la famille qu'elle porte, et pas une autre. C'est pour
## ça que WorkLine transporte la famille : sans elle, il faudrait rouvrir la ville.
func test_a_work_line_credits_the_family_it_names() -> void:
	var roster := _roster([&"ana"])
	SkillResolver.award(roster, _report([_line(&"ana", HARVEST)]), _balance())
	assert_int(roster.worker(&"ana").track_xp(HARVEST)).is_equal(10)
	assert_int(roster.worker(&"ana").track_xp(CRAFT)).is_equal(0)
	assert_int(roster.worker(&"ana").xp()).is_equal(10)

func test_each_worker_is_credited_once_per_post_held() -> void:
	var roster := _roster([&"ana", &"bo"])
	var progress := SkillResolver.award(roster,
		_report([_line(&"ana", HARVEST), _line(&"bo", HARVEST)]), _balance())
	assert_int(progress.gains().size()).is_equal(2)
	assert_int(progress.total_xp()).is_equal(20)

## Rien ici ne dépend du fait qu'une Assignment envoie un ouvrier à une seule action.
## Le jour où elle en autoriserait deux, les gains cumulent au lieu de s'écraser.
func test_two_lines_for_the_same_worker_accumulate() -> void:
	var roster := _roster([&"ana"])
	SkillResolver.award(roster,
		_report([_line(&"ana", HARVEST), _line(&"ana", HARVEST)]), _balance())
	assert_int(roster.worker(&"ana").track_xp(HARVEST)).is_equal(20)
	assert_int(roster.worker(&"ana").skill_level(HARVEST, _balance())).is_equal(2)

## Miroir de ProductionResolver._work_lines() : une affectation peut avoir survécu à
## celui qui la portait, et un mort ne progresse pas.
func test_a_line_naming_someone_who_left_the_roster_is_skipped() -> void:
	var roster := _roster([&"ana"])
	var progress := SkillResolver.award(roster,
		_report([_line(&"ana", HARVEST), _line(&"zed", HARVEST)]), _balance())
	assert_int(progress.gains().size()).is_equal(1)
	assert_str(String(progress.gains()[0].worker())).is_equal("ana")

func test_a_crossed_skill_level_is_reported_with_both_sides() -> void:
	var roster := _roster([&"ana"])
	var progress := SkillResolver.award(roster, _report([_line(&"ana", HARVEST)]), _balance())
	var gain := progress.gains()[0]
	assert_int(gain.skill_level_before()).is_equal(0)
	assert_int(gain.skill_level_after()).is_equal(1)
	assert_bool(gain.is_skill_level_up()).is_true()
	assert_int(progress.skill_level_ups().size()).is_equal(1)

## Les deux axes ne franchissent pas ensemble, et les deux listes du rapport le disent.
## Un palier de piste change un rendement ; un palier de niveau ouvrira un choix à X5.
func test_the_two_axes_are_reported_apart() -> void:
	var roster := _roster([&"ana"])
	var progress := SkillResolver.award(roster, _report([_line(&"ana", HARVEST)]), _balance())
	assert_int(progress.skill_level_ups().size()).is_equal(1)
	assert_int(progress.worker_level_ups().size()).is_equal(0)
	assert_int(roster.worker(&"ana").level(_balance())).is_equal(0)

func test_a_capped_worker_still_gets_his_line_but_crosses_nothing() -> void:
	var roster := _roster([&"ana"])
	roster.worker(&"ana").gain(HARVEST, 1000)
	var progress := SkillResolver.award(roster, _report([_line(&"ana", HARVEST)]), _balance())
	assert_int(progress.gains().size()).is_equal(1)
	assert_array(progress.skill_level_ups()).is_empty()

## Le cas qui ferme la boucle E1 → W1, et le seul qui compose deux systèmes.
##
## Même ville, même affectation, même ouvrier. Entre les deux soirs, la seule chose qui
## change est l'XP distribuée — et la reprojection, sans laquelle le second soir
## rendrait exactement le premier. C'est ce que l'oublier coûterait, et c'est
## précisément le genre d'oubli silencieux qu'un test doit attraper.
func test_a_worker_who_learned_yesterday_harvests_more_today() -> void:
	var roster := _roster([&"ana"])
	var city := _city()
	var assign := Assignment.create(_at_the_hut(&"ana"))
	var ledger := Ledger.from_stock(_stock(), 500)
	var economy := _economy()

	var first := ProductionResolver.resolve(_terrain(), city, _plan(), assign,
		roster.to_labor(_balance()), ledger, economy, _actions())
	assert_int(first.produced()[WOOD]).is_equal(2)

	SkillResolver.award(roster, first, _balance())

	var second := ProductionResolver.resolve(_terrain(), city, _plan(), assign,
		roster.to_labor(_balance()), ledger, economy, _actions())
	assert_int(second.produced()[WOOD]).is_equal(3)

## L'autre moitié du même constat : sans distribution, rien ne bouge. Sans ce cas, le
## précédent passerait aussi bien si la production montait toute seule.
func test_without_the_award_the_second_evening_repeats_the_first() -> void:
	var roster := _roster([&"ana"])
	var city := _city()
	var assign := Assignment.create(_at_the_hut(&"ana"))
	var ledger := Ledger.from_stock(_stock(), 500)
	var economy := _economy()

	var first := ProductionResolver.resolve(_terrain(), city, _plan(), assign,
		roster.to_labor(_balance()), ledger, economy, _actions())
	var second := ProductionResolver.resolve(_terrain(), city, _plan(), assign,
		roster.to_labor(_balance()), ledger, economy, _actions())
	assert_int(second.produced()[WOOD]).is_equal(first.produced()[WOOD])

func _roster(ids: Array[StringName]) -> Roster:
	var workers: Array[Worker] = []
	for id in ids:
		workers.append(Worker.create(id, String(id)))
	return Roster.create(workers)

func _line(worker: StringName, family: StringName) -> WorkLine:
	return WorkLine.create(worker, HUT, family)

## Rapport de production réduit à son journal de travail : c'est la seule chose que le
## résolveur d'XP lit, et lui fabriquer une récolte ferait croire le contraire.
func _report(work: Array) -> ProductionReport:
	var lines: Array[WorkLine] = []
	lines.assign(work)
	var none: Dictionary[StringName, int] = {}
	var idle: Array[StringName] = []
	return ProductionReport.create(none, none, lines, idle, 0, 0, 0)

## Une cabane à un poste qui rend 2 bois — assez pour que le premier palier fasse
## passer la récolte de 2 à 3, ce qu'un rendement de 1 ne montrerait pas.
func _city() -> CitySnapshot:
	var harvest: Dictionary[StringName, int] = {}
	harvest[WOOD] = 2
	var hut := BuildingData.new()
	hut.id = &"hut"
	hut.production = ProductionBlock.new()
	hut.production.slots = 1
	hut.production.skill_family = HARVEST
	hut.production.yield_per_slot = harvest
	var placed: Array[BuildingSnapshot] = []
	placed.append(BuildingSnapshot.create(hut, HUT, 0))
	return CitySnapshot.create(placed)

## Le plan d'un soir : une récolte posée sur la cabane, un poste.
##
## Fabriqué à la main plutôt que par un ActionBoard : ce fichier compose l'Économie et
## les Effectifs, et lui ajouter le ciblage lui demanderait un vrai relief pour rien.
func _plan() -> ActionPlan:
	var posted: Array[PlayedAction] = [
		PlayedAction.create(HUT_ACTION, HARVEST_CARD, HUT, PlayedAction.Kind.BUILDING, 1)]
	return ActionPlan.create(posted)

func _at_the_hut(worker: StringName) -> Dictionary[StringName, int]:
	var table: Dictionary[StringName, int] = {}
	table[worker] = HUT_ACTION
	return table

## Un relief quelconque. Ces deux soirs se jouent dans un bâtiment, mais le résolveur
## réclame le contrat Terrain depuis que les actions se jouent aussi à cru.
func _terrain() -> TerrainQuery:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	return HeightGrid.create(Vector2i(8, 8), 0, plain).to_query()

## Équilibrage des actions à cru, sans table de sources : rien ici ne se joue à cru.
func _actions() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = 1
	balance.bare_yield = 1
	balance.bare_skill_family = HARVEST
	var slots: Array[StringName] = [HARVEST_CARD]
	balance.slot_cards = slots
	return balance

func _stock() -> Dictionary[StringName, int]:
	var stock: Dictionary[StringName, int] = {}
	stock[FOOD] = 50
	return stock

func _economy() -> EconomyBalance:
	var economy := EconomyBalance.new()
	economy.base_storage_cap = 500
	economy.upkeep_per_worker = 1
	economy.upkeep_resource = FOOD
	return economy

## Un poste tenu vaut exactement un palier de piste, et un palier vaut la moitié du
## rendement en plus. Le seuil de niveau est mis hors de portée d'un seul soir, pour
## que les deux axes ne se confondent jamais dans une assertion.
func _balance() -> WorkforceBalance:
	var balance := WorkforceBalance.new()
	balance.base_roster_places = 10
	balance.xp_per_shift = 10
	balance.skill_xp_per_level = 10
	balance.max_skill_level = 4
	balance.efficiency_per_skill_level = 0.5
	balance.worker_xp_per_level = 100
	balance.max_worker_level = 4
	return balance
