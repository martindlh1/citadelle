class_name ActionTargetingTest
extends GdUnitTestSuite
## Où une carte d'action peut se jouer, et combien d'ouvriers elle y accepte.
##
## C'est la jouabilité que D1 avait laissée dehors, et le seul fichier du projet où la
## nature des quatre verbes est écrite. Chaque verbe a ici son cas d'acceptation et ses
## refus : un ciblage qui ne refuserait rien poserait des actions sur n'importe quoi, et
## un ciblage qui refuserait tout serait indiscernable d'un ciblage qui marche tant que
## personne ne joue.
##
## Relief de travail, 8 × 8 :
##   - de la plaine partout, sans aucun tag ;
##   - une forêt en (2, 2) — récoltable et chassable ;
##   - un gisement en (3, 3) — récoltable, pas chassable.
##
## Ville de travail :
##   - une cabane à 2 postes, achevée, ancrée en (5, 5), empreinte 2 × 1 ;
##   - un entrepôt achevé **sans bloc de production**, en (0, 5) ;
##   - une ferme **en chantier**, 1 cran sur 3, en (7, 0).
##
## Rien ne vient de data/ sauf le cas de vacuité en fin de fichier : les chiffres de
## DESIGN.md 4.1 bougeront, la mécanique non.

const CARD_ROOT := "res://data/cards"

const PLAIN := Vector2i(1, 1)
const FOREST := Vector2i(2, 2)
const STONE := Vector2i(3, 3)
const HUT := Vector2i(5, 5)
const HUT_TAIL := Vector2i(6, 5)
const STORE := Vector2i(0, 5)
const SITE := Vector2i(7, 0)
const OUTSIDE := Vector2i(30, 30)

const BARE_CAPACITY := 1
const HUT_SLOTS := 2
const SITE_ACTIONS := 3
const SITE_PROGRESS := 1

var _terrain: TerrainQuery
var _city: CitySnapshot
var _balance: ActionBalance

func before_test() -> void:
	_terrain = _make_terrain()
	_city = _make_city()
	_balance = _make_balance()

# --- Récolter -----------------------------------------------------------------------

## La première des deux lectures de DESIGN.md 3.5 : dans un slot de bâtiment, où la
## capacité est le nombre de postes.
func test_harvest_lands_on_a_producing_building_and_opens_all_its_slots() -> void:
	var result := _validate(ActionTargeting.CARD_HARVEST, HUT)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BUILDING)
	assert_int(result.capacity()).is_equal(HUT_SLOTS)

## La seconde lecture : à cru, sur une case nue dont le tag l'autorise. Elle rend peu —
## un seul poste — là où le bâtiment en ouvre deux, et c'est tout l'écart qui fait qu'on
## construit.
func test_harvest_lands_bare_on_a_tagged_cell() -> void:
	var result := _validate(ActionTargeting.CARD_HARVEST, FOREST)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BARE)
	assert_int(result.capacity()).is_equal(BARE_CAPACITY)

func test_harvest_lands_bare_on_any_tag_its_table_names() -> void:
	assert_bool(_validate(ActionTargeting.CARD_HARVEST, STONE).is_ok()).is_true()

## DESIGN.md 3.1 : ce sont les tags qui décident où une action à cru peut se jouer. La
## plaine n'en porte aucun, donc rien ne s'y récolte.
func test_harvest_is_refused_on_an_untagged_cell() -> void:
	_assert_refused(ActionTargeting.CARD_HARVEST, PLAIN,
		TargetResult.REASON_WRONG_TAG)

## Un entrepôt n'a pas « zéro poste », il n'a pas de bloc. C'est la façon dont E1b dit
## « ne produit pas », et le ciblage la relit telle quelle.
func test_harvest_is_refused_on_a_building_without_a_production_block() -> void:
	_assert_refused(ActionTargeting.CARD_HARVEST, STORE,
		TargetResult.REASON_NO_PRODUCTION)

## Le pendant de C4 côté cartes : un chantier occupe ses cellules et n'offre aucun poste.
func test_harvest_is_refused_on_an_unfinished_site() -> void:
	_assert_refused(ActionTargeting.CARD_HARVEST, SITE, TargetResult.REASON_UNFINISHED)

## Le bâtiment l'emporte sur le tag : on ne récolte pas à cru le sol sur lequel une
## ferme est posée. Sans ce cas, une cabane bâtie sur une forêt donnerait deux réponses.
func test_a_building_wins_over_the_tag_beneath_it() -> void:
	var city := _city_with_a_hut_on(FOREST)
	var result := ActionTargeting.validate(ActionTargeting.CARD_HARVEST, FOREST,
		_terrain, city, _balance)
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BUILDING)

# --- Chasser ------------------------------------------------------------------------

func test_hunt_lands_bare_on_a_forest() -> void:
	var result := _validate(ActionTargeting.CARD_HUNT, FOREST)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BARE)

## Sa table ne nomme que la forêt : le gisement se récolte et ne se chasse pas. C'est le
## cas qui prouve que les deux verbes lisent bien des tables **distinctes**.
func test_hunt_is_refused_where_harvest_is_accepted() -> void:
	assert_bool(_validate(ActionTargeting.CARD_HARVEST, STONE).is_ok()).is_true()
	_assert_refused(ActionTargeting.CARD_HUNT, STONE, TargetResult.REASON_WRONG_TAG)

## DESIGN.md 4.2 laisse sa colonne « En slot » vide — pas de bâtiment de chasse pour
## l'instant. Ce n'est pas une case oubliée, c'est un verbe sans version en bâtiment.
func test_hunt_is_refused_on_a_building() -> void:
	_assert_refused(ActionTargeting.CARD_HUNT, HUT, TargetResult.REASON_OCCUPIED)

# --- Construire ---------------------------------------------------------------------

## La capacité est ce qu'il **reste** à poser et non ce que le bâtiment réclame : une
## ferme à 1/3 n'accepte que deux ouvriers, le troisième n'aurait plus rien à bâtir.
func test_build_lands_on_a_site_and_opens_what_remains() -> void:
	var result := _validate(ActionTargeting.CARD_BUILD, SITE)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BUILDING)
	assert_int(result.capacity()).is_equal(SITE_ACTIONS - SITE_PROGRESS)

func test_build_is_refused_on_a_finished_building() -> void:
	_assert_refused(ActionTargeting.CARD_BUILD, HUT, TargetResult.REASON_ALREADY_BUILT)

func test_build_is_refused_on_bare_ground() -> void:
	_assert_refused(ActionTargeting.CARD_BUILD, FOREST, TargetResult.REASON_NO_BUILDING)

# --- Terraformer --------------------------------------------------------------------

## Aucun tag n'est exigé : DESIGN.md 4.2 dit « monte ou descend une case d'un cran »
## sans restreindre le terrain.
func test_terraform_lands_on_any_free_cell() -> void:
	var result := _validate(ActionTargeting.CARD_TERRAFORM, PLAIN)
	assert_bool(result.is_ok()).is_true()
	assert_int(result.kind()).is_equal(PlayedAction.Kind.BARE)
	assert_int(result.capacity()).is_equal(BARE_CAPACITY)

func test_terraform_is_refused_under_a_building() -> void:
	_assert_refused(ActionTargeting.CARD_TERRAFORM, HUT, TargetResult.REASON_OCCUPIED)

# --- Les règles communes ------------------------------------------------------------

## On désigne un coin de la ferme, on vise la ferme. Sans cette canonicalisation, deux
## clics sur la même cabane poseraient deux actions qui se croient différentes — et un
## *Terraformer* passerait sur une cellule qu'un bâtiment couvre sans y être ancré.
func test_a_footprint_cell_targets_the_anchor_it_belongs_to() -> void:
	var result := _validate(ActionTargeting.CARD_HARVEST, HUT_TAIL)
	assert_bool(result.is_ok()).is_true()
	assert_vector(result.target()).is_equal(HUT)
	_assert_refused(ActionTargeting.CARD_TERRAFORM, HUT_TAIL,
		TargetResult.REASON_OCCUPIED)

## Le curseur sort de la carte en permanence, et les quatre verbes doivent y répondre
## plutôt que d'y casser. Même convention que TerrainQuery.is_buildable().
func test_every_verb_refuses_a_target_outside_the_map() -> void:
	for card in ActionTargeting.CARDS:
		_assert_refused(card, OUTSIDE, TargetResult.REASON_OUT_OF_BOUNDS)

## Une carte de bâtiment se pose, elle ne s'affecte pas : le ciblage n'est pas son
## chemin, et il le dit au lieu de la laisser passer.
func test_a_building_card_has_no_targeting_rule() -> void:
	assert_bool(ActionTargeting.handles(&"farm")).is_false()
	_assert_refused(&"farm", FOREST, TargetResult.REASON_UNKNOWN_CARD)

## Le cas qui refuse de passer par vacuité, sur le motif de production_block_test.gd.
##
## Il charge le vrai data/cards/ et exige que **toute** carte du pool des actions ait une
## règle de ciblage. Une cinquième action ajoutée à data/ sans venir ici se poserait
## nulle part et ne dirait rien ; ce cas la rattrape le jour où elle entre, et il tombe
## aussi si le catalogue se vidait.
func test_every_action_card_in_data_has_a_targeting_rule() -> void:
	var found := 0
	for file in DirAccess.get_files_at(CARD_ROOT):
		if file.get_extension() != "tres":
			continue
		var card := load("%s/%s" % [CARD_ROOT, file]) as CardData
		if card == null or card.pool != CardData.POOL_ACTION:
			continue
		found += 1
		assert_bool(ActionTargeting.handles(card.id)) \
			.override_failure_message("la carte d'action « %s » n'a pas de règle de ciblage"
				% card.id) \
			.is_true()
	assert_int(found) \
		.override_failure_message("aucune carte d'action dans data/cards/") \
		.is_greater(0)

func _validate(card: StringName, target: Vector2i) -> TargetResult:
	return ActionTargeting.validate(card, target, _terrain, _city, _balance)

func _assert_refused(card: StringName, target: Vector2i, reason: StringName) -> void:
	var result := _validate(card, target)
	assert_bool(result.is_ok()) \
		.override_failure_message("« %s » accepté en %s alors qu'on attend « %s »"
			% [card, target, reason]) \
		.is_false()
	assert_str(result.reason()).is_equal(reason)

## De la plaine partout, une forêt et un gisement posés à la main.
func _make_terrain() -> TerrainQuery:
	var grid := HeightGrid.create(Vector2i(8, 8), 0, _tagged(&"plain", []))
	grid.set_terrain(FOREST, _tagged(&"forest", [&"forest"]))
	grid.set_terrain(STONE, _tagged(&"stone", [&"stone"]))
	return grid.to_query()

func _tagged(id: StringName, tags: Array) -> TerrainData:
	var data := TerrainData.new()
	data.id = id
	data.build = TerrainData.Build.ALLOWED
	var typed: Array[StringName] = []
	typed.assign(tags)
	data.tags = typed
	return data

func _make_city() -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		BuildingSnapshot.create(_hut(), HUT, 0),
		BuildingSnapshot.create(_store(), STORE, 0),
		BuildingSnapshot.create(_farm_site(), SITE, 0, 0, SITE_PROGRESS)]
	return CitySnapshot.create(placed)

## La même cabane, posée ailleurs. Sert au seul cas où le bâtiment recouvre un tag.
func _city_with_a_hut_on(anchor: Vector2i) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [BuildingSnapshot.create(_hut(), anchor, 0)]
	return CitySnapshot.create(placed)

## Deux cellules d'empreinte, exprès : c'est ce qui rend testable le clic sur une
## cellule qui n'est pas l'ancre.
func _hut() -> BuildingData:
	var data := _building(&"hut")
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	data.footprint = cells
	var block := ProductionBlock.new()
	block.slots = HUT_SLOTS
	var per: Dictionary[StringName, int] = {}
	per[&"wood"] = 2
	block.yield_per_slot = per
	block.skill_family = &"harvest"
	data.production = block
	return data

func _store() -> BuildingData:
	return _building(&"store")

func _farm_site() -> BuildingData:
	var data := _building(&"farm")
	data.build_actions = SITE_ACTIONS
	return data

func _building(id: StringName) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return data

func _make_balance() -> ActionBalance:
	var balance := ActionBalance.new()
	balance.bare_capacity = BARE_CAPACITY
	balance.bare_yield = 1
	balance.bare_skill_family = &"harvest"
	var sources: Dictionary[StringName, Dictionary] = {}
	sources[ActionTargeting.CARD_HARVEST] = {&"forest": &"wood", &"stone": &"stone"}
	sources[ActionTargeting.CARD_HUNT] = {&"forest": &"food"}
	balance.bare_sources = sources
	return balance
