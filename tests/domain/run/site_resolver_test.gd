class_name SiteResolverTest
extends GdUnitTestSuite
## Ce que les verbes de chantier ordonnent, et ce qu'ils laissent tranquille.
##
## Le jumeau de `production_resolver_test.gd` pour l'autre moitié des actions jouées.
## Deux familles de cas s'y répondent : ce qu'une équipe pose, et ce qui **n'est pas**
## ordonné — parce qu'un ordre de trop mute la ville pour rien, et qu'un ordre manquant
## laisse une carte jouée sans effet, ce qui est exactement la panne de `D2`.
##
## Ville de travail :
##   - une ferme **en chantier**, 0 cran sur 3, ancrée en (2, 2) ;
##   - une cabane achevée en (5, 5).
##
## Aucun chiffre de `data/` : `DESIGN.md` 4.1 les fera bouger, la mécanique non. Le seul
## cas qui ouvre `data/` est celui de vacuité en fin de fichier, sur le motif de
## `action_targeting_test.gd`.

const SITE := Vector2i(2, 2)
const HUT := Vector2i(5, 5)
const GROUND := Vector2i(7, 7)

const SITE_ACTIONS := 3
const CONSTRUCTION := &"construction"
const HARVEST := &"harvest"

const UP := PlayedAction.DIRECTION_UP
const DOWN := PlayedAction.DIRECTION_DOWN

var _city: CitySnapshot
var _balance: ActionBalance

func before_test() -> void:
	_city = _make_city()
	_balance = _make_balance()

# --- Construire -----------------------------------------------------------------------

## Un ouvrier ordinaire pose un cran : son multiplicateur vaut 1, tronqué il vaut 1.
func test_one_plain_worker_lays_one_course() -> void:
	var report := _resolve(_build_action(1), {&"ana": 1.0})
	assert_int(report.advances()[SITE]).is_equal(1)
	assert_int(report.total_progress()).is_equal(1)

## Deux ouvriers posent deux crans. C'est le cas de référence sans lequel les suivants ne
## veulent rien dire.
func test_two_plain_workers_lay_two_courses() -> void:
	var report := _resolve(_build_action(3), {&"ana": 1.0, &"bo": 1.0})
	assert_int(report.advances()[SITE]).is_equal(2)

## Le cas qui porte le jalon côté Effectifs : la piste Construction **fait** quelque
## chose. Deux ouvriers à 1,5 valent trois crans là où deux bleus en valent deux, et c'est
## ce qui distingue un métier d'un compteur.
func test_an_experienced_crew_lays_more_courses() -> void:
	var report := _resolve(_build_action(3), {&"ana": 1.5, &"bo": 1.5})
	assert_int(report.advances()[SITE]).is_equal(3)

## Le total est tronqué vers le bas, jamais arrondi : deux ouvriers à 1,4 font 2,8 et
## posent deux crans. Un chantier ne gagne pas un cran sur une virgule.
func test_the_crew_total_is_floored() -> void:
	var report := _resolve(_build_action(3), {&"ana": 1.4, &"bo": 1.4})
	assert_int(report.advances()[SITE]).is_equal(2)

## Le plafond est celui que l'action porte, figé à la pose — pour un chantier, ce qu'il
## lui restait à bâtir. Aucun talent ne fait dépasser le dernier cran.
func test_no_crew_lays_more_than_the_action_accepts() -> void:
	var report := _resolve(_build_action(1), {&"ana": 1.75, &"bo": 1.75})
	assert_int(report.advances()[SITE]).is_equal(1)

## Les postes se remplissent dans l'ordre de l'affectation, et ceux qui arrivent au-delà
## de la capacité chôment. Même règle que sur un poste de production.
func test_workers_past_the_capacity_do_not_work() -> void:
	var report := _resolve(_build_action(1), {&"ana": 1.0, &"bo": 1.0})
	assert_array(report.work()).has_size(1)
	assert_str(String(report.work()[0].worker())).is_equal("ana")

## Une carte posée que personne ne tient n'ordonne rien. `DESIGN.md` 3.5 : la carte dit ce
## qu'on peut faire, les ouvriers disent combien on peut en faire — et zéro est une
## réponse.
func test_an_unmanned_action_orders_nothing() -> void:
	var report := _resolve(_build_action(3), {})
	assert_bool(report.is_empty()).is_true()
	assert_array(report.work()).is_empty()

## Un ouvrier que l'affectation nomme mais que la main-d'œuvre ignore est sauté sans un
## mot : une affectation peut avoir survécu à celui qui la portait, et un mort ne bâtit
## pas. Miroir exact du résolveur de production.
func test_a_worker_the_labor_force_does_not_know_is_skipped() -> void:
	var plan := ActionPlan.create([_build_action(3)])
	var staffing: Dictionary[StringName, int] = {}
	staffing[&"ghost"] = 1
	var report := SiteResolver.resolve(_city, plan, Assignment.create(staffing),
		LaborForce.empty(), _balance)
	assert_bool(report.is_empty()).is_true()

# --- Terraformer ----------------------------------------------------------------------

## Le sens vient de l'action, figé à la pose, et il s'ajoute tel quel à la hauteur.
func test_terraform_orders_a_signed_shift() -> void:
	var up := _resolve(_terraform_action(UP), {&"ana": 1.0})
	assert_int(up.shifts()[GROUND]).is_equal(1)
	var down := _resolve(_terraform_action(DOWN), {&"ana": 1.0})
	assert_int(down.shifts()[GROUND]).is_equal(-1)

## Un terrassement n'avance aucun chantier, et un chantier ne déplace aucune terre. Les
## deux tables sont distinctes parce que l'orchestrateur les applique à deux états
## différents.
func test_terraform_and_build_do_not_bleed_into_each_other() -> void:
	var up := _resolve(_terraform_action(UP), {&"ana": 1.0})
	assert_dict(up.advances()).is_empty()
	var site := _resolve(_build_action(3), {&"ana": 1.0})
	assert_dict(site.shifts()).is_empty()

## Un terrassement rend un cran parce que sa capacité vaut 1 dans `data/`, et non parce
## qu'un cas particulier serait écrit dans le résolveur. Le jour où une case nue acceptera
## deux ouvriers, elle se creusera de deux crans sans qu'une ligne bouge.
func test_terraform_follows_the_same_formula_as_a_site() -> void:
	_balance.bare_capacity = 2
	var action := PlayedAction.create(1, SiteResolver.CARD_TERRAFORM, GROUND,
		PlayedAction.Kind.BARE, 2, DOWN)
	var report := _resolve(action, {&"ana": 1.0, &"bo": 1.0})
	assert_int(report.shifts()[GROUND]).is_equal(-2)

# --- Ce qui n'est pas de son ressort ---------------------------------------------------

## Le pendant du cas de `production_resolver_test.gd` qui garde *Construire* hors de la
## production : ici c'est *Récolter* qui doit rester dehors. Sans ces deux gardes, une
## action produirait **et** bâtirait.
func test_a_productive_verb_orders_nothing() -> void:
	var action := PlayedAction.create(1, HARVEST, HUT, PlayedAction.Kind.BUILDING, 2)
	var report := _resolve(action, {&"ana": 1.0, &"bo": 1.0})
	assert_bool(report.is_empty()).is_true()
	assert_array(report.work()).is_empty()

## Les lignes de travail créditent la piste des chantiers, lue dans `data/balance/` et non
## écrite ici. C'est ce qui a refermé l'`OUVERT` de 3.2 sans qu'un nom de famille entre
## dans du GDScript.
func test_site_work_credits_the_family_data_names() -> void:
	_balance.site_skill_family = &"another_family"
	var report := _resolve(_build_action(3), {&"ana": 1.0})
	assert_str(String(report.work()[0].family())).is_equal("another_family")

## Une équipe dont le total tombe à zéro garde ses lignes de travail : l'ouvrier a tenu le
## poste et mérite son XP, il a juste mal travaillé. Règle du résolveur de production,
## mot pour mot.
func test_a_crew_that_lays_nothing_still_earns_its_shift() -> void:
	var report := _resolve(_build_action(3), {&"ana": 0.4})
	assert_bool(report.is_empty()).is_true()
	assert_array(report.work()).has_size(1)

# --- Le filet qui garde les verbes ------------------------------------------------------

## Le cas qui remplace la garantie que `D2` s'était donnée.
##
## `DESIGN.md` 4.2 affirmait qu'`ActionTargeting` était le seul endroit du projet où un
## identifiant de carte est écrit en dur. `I1` en ouvre un second, parce qu'**où** un verbe
## se pose et **ce qu'il fait** sont deux questions. Ce qui protégeait vraiment n'était pas
## le nombre de fichiers mais l'impossibilité qu'un verbe tombe dans le vide : c'est ce que
## ce cas tient, et il le tient mieux qu'une phrase.
##
## Un cinquième verbe entré dans `ActionTargeting` sans être ni productif ni exécuté se
## poserait, s'affecterait, et ne ferait rien — la panne exacte que `D2` a laissée
## derrière lui.
func test_every_targetable_verb_either_produces_or_builds() -> void:
	var balance := (load("res://data/balance/balance.tres") as BalanceData).actions
	for card in ActionTargeting.CARDS:
		var productive := balance.works_a_slot(card) or balance.is_bare_card(card)
		assert_bool(productive or SiteResolver.handles(card)) \
			.override_failure_message(
				"le verbe « %s » ne produit rien et n'est exécuté par personne" % card) \
			.is_true()

## Et le revers : un verbe de chantier ne doit pas être productif par ailleurs, sans quoi
## les deux résolveurs le serviraient tous les deux et une carte compterait double.
func test_no_verb_is_both_productive_and_a_site_verb() -> void:
	var balance := (load("res://data/balance/balance.tres") as BalanceData).actions
	for card in SiteResolver.CARDS:
		assert_bool(balance.works_a_slot(card)) \
			.override_failure_message("« %s » tient un poste ET bâtit" % card).is_false()
		assert_bool(balance.is_bare_card(card)) \
			.override_failure_message("« %s » se joue à cru ET bâtit" % card).is_false()

# --- La mise en place -------------------------------------------------------------------

func _resolve(action: PlayedAction,
		crew: Dictionary) -> SiteReport:
	var plan := ActionPlan.create([action])
	var staffing: Dictionary[StringName, int] = {}
	var units: Array[LaborUnit] = []
	for worker: StringName in crew:
		staffing[worker] = action.id()
		var multipliers: Dictionary[StringName, float] = {}
		multipliers[_balance.site_skill_family] = crew[worker]
		units.append(LaborUnit.create(worker, multipliers))
	return SiteResolver.resolve(_city, plan, Assignment.create(staffing),
		LaborForce.create(units), _balance)

func _build_action(capacity: int) -> PlayedAction:
	return PlayedAction.create(1, SiteResolver.CARD_BUILD, SITE,
		PlayedAction.Kind.BUILDING, capacity)

func _terraform_action(direction: int) -> PlayedAction:
	return PlayedAction.create(1, SiteResolver.CARD_TERRAFORM, GROUND,
		PlayedAction.Kind.BARE, 1, direction)

func _make_city() -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(_farm_site(), SITE, 0, 0, 0),
		BuildingSnapshot.create(_hut(), HUT, 0)]
	return CitySnapshot.create(placed)

func _farm_site() -> BuildingData:
	var data := _building(&"farm")
	data.build_actions = SITE_ACTIONS
	return data

func _hut() -> BuildingData:
	var data := _building(&"hut")
	var block := ProductionBlock.new()
	block.slots = 2
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = HARVEST
	data.production = block
	return data

func _building(id: StringName) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return data

func _make_balance() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = 1
	balance.bare_yield = 1
	balance.bare_skill_family = HARVEST
	balance.site_skill_family = CONSTRUCTION
	balance.terraform_floor = -4
	balance.terraform_ceiling = 4
	var slots: Array[StringName] = [HARVEST]
	balance.slot_cards = slots
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[HARVEST] = {&"forest": &"wood"}
	balance.bare_sources = sources
	return balance
