class_name StaffingTest
extends GdUnitTestSuite
## Qui tourne, qui dort, et l'interdit de blocage qui porte le jalon.
##
## Le sommeil n'est pas un état mémorisé mais un calcul refait à chaque demande : ces cas
## vérifient donc une **fonction**, et c'est ce qui permet de les écrire sans jamais
## mettre un bâtiment en sommeil à la main.

const HIT_POINTS := 4

## Ville de bâtiments finis, dans cet ordre de pose, coûtant ces travailleurs.
##
## L'ordre du tableau est l'ordre de pose, ce que CityState garantit par l'ordre
## d'insertion de son Dictionary et que CitySnapshot transporte.
func _city(costs: Array[int]) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	for i in costs.size():
		placed.append(BuildingSnapshot.create(
			_building(StringName("b%d" % i), costs[i]), Vector2i(i, 0), 0, 0, 0, 0))
	return CitySnapshot.create(placed)

## `build_actions` est ce qui fait d'un bâtiment un chantier tant que son avancement ne
## l'a pas rattrapé. À zéro — le défaut — il est achevé dès la pose, comme le Cœur.
##
## Ce n'est **pas** le `turns` de BuildingSnapshot.create(), qui est une orientation. Les
## confondre fabrique un bâtiment fini là où le cas croyait poser un chantier, et le test
## passe alors sur autre chose que ce qu'il annonce.
func _building(id: StringName, workers: int, housing: int = 0,
		build_actions: int = 0) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = HIT_POINTS
	data.build_actions = build_actions
	data.workers = workers
	data.housing = housing
	return data

# --- ce qui tourne quand tout tient -----------------------------------------

func test_an_empty_city_commits_nobody() -> void:
	var plan := Staffing.resolve(CitySnapshot.empty(), 5)
	assert_int(plan.committed()).is_equal(0)
	assert_int(plan.available()).is_equal(5)
	assert_bool(plan.has_sleepers()).is_false()

func test_a_city_the_headcount_covers_runs_whole() -> void:
	var plan := Staffing.resolve(_city([2, 3]), 6)
	assert_int(plan.committed()).is_equal(5)
	assert_int(plan.available()).is_equal(1)
	assert_array(plan.asleep()).is_empty()

func test_workers_are_committed_exactly_once_each() -> void:
	var plan := Staffing.resolve(_city([2, 3, 1]), 10)
	assert_int(plan.committed()).is_equal(6)
	assert_int(Staffing.demand(_city([2, 3, 1]))).is_equal(6)

# --- ce qui dort quand les bras manquent ------------------------------------

## La règle de DESIGN.md 3.4 : le dernier bâti s'éteint le premier. Trois bâtiments à deux
## bras pour cinq habitants — le troisième dort, et rend ses deux bras.
func test_the_newest_building_sleeps_first() -> void:
	var plan := Staffing.resolve(_city([2, 2, 2]), 5)
	assert_int(plan.committed()).is_equal(4)
	assert_array(plan.asleep()).is_equal([Vector2i(2, 0)])
	assert_bool(plan.is_active(Vector2i(0, 0))).is_true()
	assert_bool(plan.is_active(Vector2i(2, 0))).is_false()

## « On répète tant qu'il le faut » : un effectif qui s'effondre endort plusieurs
## bâtiments, toujours par le bout le plus récent.
func test_several_sleep_when_the_headcount_collapses() -> void:
	var plan := Staffing.resolve(_city([2, 2, 2]), 1)
	assert_int(plan.committed()).is_equal(0)
	assert_array(plan.asleep()).is_equal(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])

## Le corollaire de « on éteint par le bout » : un bâtiment qui ne tient pas emporte tous
## ceux d'après, même moins chers. Le contraire ferait dépendre le résultat du coût des
## voisins, donc rendrait imprévisible ce que la prochaine famine coûte.
func test_a_building_that_does_not_fit_takes_the_later_ones_with_it() -> void:
	var plan := Staffing.resolve(_city([1, 5, 1]), 3)
	assert_int(plan.committed()).is_equal(1)
	assert_array(plan.asleep()).is_equal([Vector2i(1, 0), Vector2i(2, 0)])

## Le sommeil se **redérive**, il ne se mémorise pas : la population remonte, tout
## repeuple, et aucun geste n'a eu à l'ordonner. C'est ce que DESIGN.md 3.4 réclame en
## toutes lettres, et c'est gratuit parce que rien n'était stocké.
func test_a_recovered_headcount_repopulates_on_its_own() -> void:
	var city := _city([2, 2, 2])
	assert_bool(Staffing.resolve(city, 3).has_sleepers()).is_true()
	assert_bool(Staffing.resolve(city, 6).has_sleepers()).is_false()

# --- l'interdit de blocage ---------------------------------------------------

## **Le cas qui porte le jalon.** Un bâtiment gratuit en bras ne dort jamais, même derrière
## un bâtiment qui, lui, ne tient pas.
##
## Sans cette règle la soupape de DESIGN.md 3.4 ne s'ouvre jamais : l'habitation qu'on bâtit
## pour sortir d'un blocage est le bâtiment **le plus récent**, donc le premier qu'un
## préfixe strict endort — et un chantier endormi n'avance pas. Le village resterait bloqué
## en tenant sa sortie à la main.
func test_a_building_that_costs_nobody_never_sleeps() -> void:
	var placed: Array[BuildingSnapshot] = []
	placed.append(BuildingSnapshot.create(
		_building(&"farm", 4), Vector2i(0, 0), 0, 0, 0, 0))
	placed.append(BuildingSnapshot.create(
		_building(&"house", 0, 4, 2), Vector2i(1, 0), 0, 0, 0, 0))
	var plan := Staffing.resolve(CitySnapshot.create(placed), 1)
	assert_bool(plan.is_active(Vector2i(0, 0))).is_false()
	assert_bool(plan.is_active(Vector2i(1, 0))).is_true()
	assert_int(plan.committed()).is_equal(0)

## Le blocage, joué de bout en bout : tout le monde immobilisé, le logement plein.
##
## C'est l'état que DESIGN.md 3.4 déclare mortel s'il n'a pas de sortie — plus un bras libre
## pour bâtir, plus une place pour faire venir quelqu'un. La sortie est l'habitation
## gratuite, et ce cas vérifie qu'elle **fonctionne vraiment** plutôt que d'exister dans la
## data : elle s'ouvre sans bras, elle avance sans bras, et le plafond monte au bout.
func test_a_fully_committed_village_can_still_build_its_way_out() -> void:
	var people := Population.from_headcount(4, 4)
	var placed: Array[BuildingSnapshot] = []
	placed.append(BuildingSnapshot.create(
		_building(&"farm", 4), Vector2i(0, 0), 0, 0, 0, 0))

	var stuck := Staffing.resolve(CitySnapshot.create(placed), people.headcount())
	assert_int(stuck.available()).is_equal(0)
	assert_bool(people.is_full()).is_true()

	# La soupape : une habitation ne coûte aucun bras, donc son chantier s'ouvre.
	var shelter := _building(&"house", 0, 4, 2)
	assert_int(shelter.workers).is_equal(0)
	placed.append(BuildingSnapshot.create(shelter, Vector2i(1, 0), 0, 0, 0, 0))

	# Et il n'est pas endormi malgré la ferme qui, elle, ne tient plus.
	var opened := Staffing.resolve(CitySnapshot.create(placed), people.headcount())
	assert_bool(opened.is_active(Vector2i(1, 0))).is_true()

	# Achevé, il relève le plafond : le village repart.
	people.set_places(4 + shelter.housing)
	assert_int(people.free_places()).is_equal(4)
	assert_int(people.grow()).is_equal(1)

# --- les chantiers comptent comme le reste ----------------------------------

## Un chantier immobilise dès son ouverture (DESIGN.md 3.4), donc il pèse sur le plan comme
## un bâtiment fini. Un plan qui ne compterait que les achevés laisserait ouvrir des
## chantiers avec des bras déjà dépensés.
func test_a_construction_site_commits_like_a_finished_building() -> void:
	var placed: Array[BuildingSnapshot] = []
	placed.append(BuildingSnapshot.create(
		_building(&"site", 3, 0, 2), Vector2i(0, 0), 0, 0, 0, 0))
	var city := CitySnapshot.create(placed)
	assert_array(city.completed()).is_empty()
	assert_int(Staffing.resolve(city, 5).committed()).is_equal(3)
