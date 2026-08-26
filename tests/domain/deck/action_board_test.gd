class_name ActionBoardTest
extends GdUnitTestSuite
## Ce que le joueur a posé dans la phase : poser, retirer, vider, projeter.
##
## Le cas qui porte le fichier est **deux actions sur la même cellule**. C'est la raison
## d'être de tout D2 : tant qu'un ouvrier s'affectait à une ancre, *Récolter* et
## *Chasser* sur la même forêt étaient indiscernables, et le board n'aurait pas pu tenir
## les deux. Il les tient, et elles ne se marchent pas dessus.
##
## Le second est **un identifiant qui ne revient jamais**. Un numéro réutilisé après un
## retrait rattacherait en silence une affectation oubliée à l'action suivante — un
## ouvrier qui se retrouve à bâtir parce qu'on a annulé sa récolte. Ce cas-là ne se
## verrait jamais à l'écran, seulement dans un rapport de fin de soirée.
##
## Relief de travail, 8 × 8, de la plaine partout et une forêt en (2, 2). Ville vide,
## sauf là où un cas a besoin d'un bâtiment.

const FOREST := Vector2i(2, 2)
const PLAIN := Vector2i(1, 1)
const OTHER := Vector2i(4, 4)
const OUTSIDE := Vector2i(30, 30)

const BARE_CAPACITY := 1

var _terrain: TerrainQuery
var _city: CitySnapshot
var _balance: ActionBalance
var _board: ActionBoard

func before_test() -> void:
	_terrain = _make_terrain()
	_city = CitySnapshot.empty()
	_balance = _make_balance()
	_board = ActionBoard.new()

func test_a_new_board_holds_nothing() -> void:
	assert_int(_board.count()).is_equal(0)
	assert_bool(_board.to_plan().is_empty()).is_true()

func test_posting_a_card_returns_the_action_it_created() -> void:
	var action := _post(ActionTargeting.CARD_HARVEST, FOREST)
	assert_object(action).is_not_null()
	assert_str(action.card()).is_equal(ActionTargeting.CARD_HARVEST)
	assert_vector(action.target()).is_equal(FOREST)
	assert_int(action.capacity()).is_equal(BARE_CAPACITY)
	assert_int(_board.count()).is_equal(1)

## Le board ne pose que ce que le ciblage accepte : c'est un invariant tenu par la
## structure, pas une consigne. Rien ne peut entrer sans être passé par ActionTargeting,
## exactement comme rien n'entre dans la ville sans PlacementValidator.
func test_a_refused_target_posts_nothing_at_all() -> void:
	assert_object(_post(ActionTargeting.CARD_HARVEST, PLAIN)).is_null()
	assert_object(_post(ActionTargeting.CARD_HARVEST, OUTSIDE)).is_null()
	assert_object(_post(&"farm", FOREST)).is_null()
	assert_int(_board.count()).is_equal(0)

## Le cas du fichier. Deux verbes sur la même forêt, chacun avec son identité et ses
## ouvriers à lui. C'est ce qu'une clé par cellule rendait impossible.
## Le board est le gardien de son propre invariant : rien n'entre sans passer par le
## ciblage. Depuis que celui-ci refuse une seconde action sur une cible occupée, la seconde
## pose est donc refusée ici aussi, sans qu'une ligne du board ait bougé — ce qui est
## exactement ce que ce partage garantissait.
func test_a_cell_carries_a_single_action() -> void:
	var harvest := _post(ActionTargeting.CARD_HARVEST, FOREST)
	assert_object(harvest).is_not_null()
	assert_object(_post(ActionTargeting.CARD_HUNT, FOREST)).is_null()
	assert_int(_board.count()).is_equal(1)
	assert_int(_board.at_cell(FOREST).size()).is_equal(1)

## Son revers, et il vient de la même règle : deux fois la **même** carte au même endroit
## rouvriraient des postes déjà ouverts. Le board le refuse parce que le ciblage le
## refuse, et n'a aucune règle à lui.
func test_the_same_card_cannot_be_posted_twice_on_one_cell() -> void:
	_post(ActionTargeting.CARD_HARVEST, FOREST)
	assert_object(_post(ActionTargeting.CARD_HARVEST, FOREST)).is_null()
	assert_int(_board.count()).is_equal(1)

## Et la place se libère avec le retrait : une carte reposée après coup n'est plus un
## doublon.
func test_withdrawing_frees_the_target_for_the_same_card_again() -> void:
	var first := _post(ActionTargeting.CARD_HARVEST, FOREST)
	_board.withdraw(first.id())
	assert_object(_post(ActionTargeting.CARD_HARVEST, FOREST)).is_not_null()

func test_at_cell_finds_nothing_where_nothing_is_posted() -> void:
	_post(ActionTargeting.CARD_HARVEST, FOREST)
	assert_array(_board.at_cell(OTHER)).is_empty()

## Les deux actions visent deux cellules depuis que le ciblage refuse d'en partager une.
## Ce que le cas tient n'a pas changé : un retrait emporte l'action nommée et **elle
## seule**.
func test_withdrawing_removes_exactly_one_action() -> void:
	var harvest := _post(ActionTargeting.CARD_HARVEST, FOREST)
	var dig := _post(ActionTargeting.CARD_TERRAFORM, PLAIN, PlayedAction.DIRECTION_UP)
	assert_bool(_board.withdraw(harvest.id())).is_true()
	assert_int(_board.count()).is_equal(1)
	assert_bool(_board.has(harvest.id())).is_false()
	assert_bool(_board.has(dig.id())).is_true()

func test_withdrawing_something_that_was_never_posted_says_so() -> void:
	assert_bool(_board.withdraw(ActionBoard.NO_ACTION)).is_false()
	assert_bool(_board.withdraw(99)).is_false()

## Le second cas du fichier. Le compteur monte et ne recule jamais, ni sur un retrait ni
## sur un vidage : une affectation périmée doit ne plus désigner personne, jamais
## désigner quelqu'un d'autre.
func test_an_identifier_is_never_handed_out_twice() -> void:
	var first := _post(ActionTargeting.CARD_HARVEST, FOREST)
	_board.withdraw(first.id())
	var second := _post(ActionTargeting.CARD_HARVEST, FOREST)
	assert_int(second.id()).is_not_equal(first.id())
	_board.clear()
	var third := _post(ActionTargeting.CARD_HUNT, FOREST)
	assert_int(third.id()).is_not_equal(first.id())
	assert_int(third.id()).is_not_equal(second.id())

func test_clearing_empties_the_board() -> void:
	_post(ActionTargeting.CARD_HARVEST, FOREST)
	_post(ActionTargeting.CARD_HUNT, FOREST)
	_board.clear()
	assert_int(_board.count()).is_equal(0)
	assert_bool(_board.to_plan().is_empty()).is_true()

func test_an_unknown_identifier_reads_as_nothing() -> void:
	assert_object(_board.at(ActionBoard.NO_ACTION)).is_null()
	assert_object(_board.at(99)).is_null()

## L'ordre de pose est celui du plan, et c'est lui que le résolveur suit. Deux phases
## identiques jouées dans un ordre différent ne doivent pas rendre autre chose.
## Trois cellules distinctes depuis que le ciblage refuse d'en partager une. Le sujet du
## cas est l'**ordre** et non les verbes : le troisième creuse là où le second monte,
## faute d'une seconde forêt où chasser.
func test_the_plan_keeps_the_order_the_actions_were_posted_in() -> void:
	var first := _post(ActionTargeting.CARD_HARVEST, FOREST)
	var second := _post(ActionTargeting.CARD_TERRAFORM, PLAIN,
		PlayedAction.DIRECTION_UP)
	var third := _post(ActionTargeting.CARD_TERRAFORM, OTHER,
		PlayedAction.DIRECTION_DOWN)
	var posted := _board.to_plan().actions()
	assert_int(posted[0].id()).is_equal(first.id())
	assert_int(posted[1].id()).is_equal(second.id())
	assert_int(posted[2].id()).is_equal(third.id())

## Le miroir de Deck.hand() et de CityState.to_snapshot() : la projection ne suit pas ce
## que le board fait ensuite.
func test_a_plan_does_not_follow_the_board_it_came_from() -> void:
	_post(ActionTargeting.CARD_HARVEST, FOREST)
	var plan := _board.to_plan()
	_board.clear()
	_post(ActionTargeting.CARD_HUNT, FOREST)
	assert_int(plan.count()).is_equal(1)
	assert_str(plan.actions()[0].card()).is_equal(ActionTargeting.CARD_HARVEST)

## Une carte posée sur un bâtiment vise son **ancre**, même désignée par une autre
## cellule de l'empreinte. C'est le ciblage qui canonicalise, et le board enregistre ce
## qu'on lui rend plutôt que ce qu'on lui a demandé.
func test_a_posted_action_records_the_canonical_target() -> void:
	var anchor := Vector2i(5, 5)
	_city = _city_with_a_hut_at(anchor)
	var action := _post(ActionTargeting.CARD_HARVEST, anchor + Vector2i(1, 0))
	assert_object(action).is_not_null()
	assert_vector(action.target()).is_equal(anchor)
	assert_int(action.kind()).is_equal(PlayedAction.Kind.BUILDING)

## La capacité est figée à la pose. Relire la ville au moment de résoudre rouvrirait la
## porte à ce que l'écran ait promis deux postes et que le soir n'en serve qu'un.
func test_the_capacity_of_a_slot_action_comes_from_the_building() -> void:
	_city = _city_with_a_hut_at(Vector2i(5, 5))
	var action := _post(ActionTargeting.CARD_HARVEST, Vector2i(5, 5))
	assert_int(action.capacity()).is_equal(2)

func _post(card: StringName, target: Vector2i,
		direction := PlayedAction.DIRECTION_NONE) -> PlayedAction:
	return _board.post(card, target, _terrain, _city, _balance, direction)

func _make_terrain() -> TerrainQuery:
	var plain := TerrainData.new()
	plain.id = &"plain"
	plain.build = TerrainData.Build.ALLOWED
	var forest := TerrainData.new()
	forest.id = &"forest"
	forest.build = TerrainData.Build.ALLOWED
	var tags: Array[StringName] = [&"forest"]
	forest.tags = tags
	var grid := HeightGrid.create(Vector2i(8, 8), 0, plain)
	grid.set_terrain(FOREST, forest)
	return grid.to_query()

## Une cabane à 2 postes, empreinte 2 × 1 pour que le clic hors ancre soit testable.
func _city_with_a_hut_at(anchor: Vector2i) -> CitySnapshot:
	var data := BuildingData.new()
	data.id = &"hut"
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	data.footprint = cells
	var block := ProductionBlock.new()
	block.slots = 2
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = &"harvest"
	data.production = block
	var placed: Array[BuildingSnapshot] = [BuildingSnapshot.create(data, anchor, 0)]
	return CitySnapshot.create(placed)

func _make_balance() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = BARE_CAPACITY
	balance.bare_yield = 1
	balance.bare_skill_family = &"harvest"
	balance.site_skill_family = &"construction"
	balance.terraform_floor = -1
	balance.terraform_ceiling = 1
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[ActionTargeting.CARD_HARVEST] = {&"forest": &"wood"}
	sources[ActionTargeting.CARD_HUNT] = {&"forest": &"food"}
	balance.bare_sources = sources
	return balance
