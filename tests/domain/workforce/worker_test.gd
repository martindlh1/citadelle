class_name WorkerTest
extends GdUnitTestSuite
## Un ouvrier : ses deux axes, sa présence, et ce qu'il projette.
##
## Réglages lisibles à l'œil nu, sans rapport avec data/balance/ : 10 d'XP par palier de
## piste, 25 par palier de niveau, un cran d'efficacité à 0,5. Les deux seuils sont
## volontairement différents — s'ils étaient égaux, un test ne saurait pas dire lequel
## des deux axes il observe.
##
## Le cas qui porte le jalon est **la spécialisation** : monter en Récolte doit rendre
## meilleur au camp de bûcheron et laisser l'atelier exactement où il était. C'est la
## promesse de DESIGN.md 3.4, et rien avant W1 ne la vérifiait.
##
## Vient ensuite **toute XP compte deux fois** : c'est le seul invariant qui lie les
## deux axes, et il n'existe que parce que gain() est la seule porte d'entrée.

const HARVEST := &"harvest"
const CRAFT := &"craft"

func test_a_fresh_worker_has_nothing_and_is_here() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	assert_str(String(worker.id())).is_equal("alaric")
	assert_str(worker.given_name()).is_equal("Alaric")
	assert_bool(worker.is_present()).is_true()
	assert_int(worker.xp()).is_equal(0)
	assert_array(worker.families()).is_empty()

## Un ouvrier neuf produit ce que le bâtiment promet, dans n'importe quelle famille et
## même dans une qu'aucun bâtiment n'emploie encore.
func test_a_fresh_worker_multiplies_by_the_base_everywhere() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	assert_float(worker.efficiency(HARVEST, _balance())).is_equal(LaborUnit.BASE_EFFICIENCY)
	assert_float(worker.efficiency(&"combat", _balance())).is_equal(LaborUnit.BASE_EFFICIENCY)

## La promesse de DESIGN.md 3.4 : spécialiser rend excellent à un poste et ordinaire
## ailleurs. Sans ce cas, une piste qui créditerait toutes les familles passerait.
func test_specialising_lifts_one_family_and_leaves_the_others_flat() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 20)
	assert_float(worker.efficiency(HARVEST, _balance())).is_equal(2.0)
	assert_float(worker.efficiency(CRAFT, _balance())).is_equal(LaborUnit.BASE_EFFICIENCY)
	assert_int(worker.skill_level(HARVEST, _balance())).is_equal(2)
	assert_int(worker.skill_level(CRAFT, _balance())).is_equal(0)

## L'invariant du jalon. Le même montant part dans la piste **et** dans le niveau, et
## comme les deux seuils diffèrent, les deux paliers ne bougent pas ensemble.
func test_every_xp_counts_twice() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 25)
	assert_int(worker.track_xp(HARVEST)).is_equal(25)
	assert_int(worker.xp()).is_equal(25)
	assert_int(worker.skill_level(HARVEST, _balance())).is_equal(2)
	assert_int(worker.level(_balance())).is_equal(1)

## Le niveau agrège ce que les pistes séparent : deux métiers exercés à mi-temps
## laissent deux pistes basses et un niveau qui, lui, a tout compté.
func test_the_worker_level_aggregates_what_the_tracks_split() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 15)
	worker.gain(CRAFT, 15)
	assert_int(worker.skill_level(HARVEST, _balance())).is_equal(1)
	assert_int(worker.skill_level(CRAFT, _balance())).is_equal(1)
	assert_int(worker.xp()).is_equal(30)
	assert_int(worker.level(_balance())).is_equal(1)

## Une piste s'ouvre au premier gain : un ouvrier n'a pas trois pistes vierges, il en a
## autant qu'il a exercé de métiers. C'est ce qui rend families() lisible comme un CV.
func test_a_track_opens_on_its_first_gain_and_the_others_stay_shut() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	assert_bool(worker.has_track(HARVEST)).is_false()
	worker.gain(HARVEST, 4)
	assert_bool(worker.has_track(HARVEST)).is_true()
	assert_bool(worker.has_track(CRAFT)).is_false()
	assert_array(worker.families()).contains_exactly([HARVEST])
	assert_int(worker.track_xp(CRAFT)).is_equal(0)

func test_the_worker_level_stops_at_its_own_cap() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 10000)
	assert_int(worker.level(_balance())).is_equal(4)
	assert_bool(worker.is_capped(_balance())).is_true()

## Les deux plafonds sont indépendants : une piste au bout n'empêche pas le niveau de
## monter, ce qui est exactement la situation que X5 exploitera.
func test_a_capped_track_does_not_cap_the_worker() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 40)
	assert_bool(worker.is_skill_capped(HARVEST, _balance())).is_true()
	assert_bool(worker.is_capped(_balance())).is_false()

## DESIGN.md 3.9 : absent n'est pas mort. Il garde sa place, son XP et ses pistes.
func test_an_absent_worker_keeps_everything_but_his_availability() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 20)
	worker.set_present(false)
	assert_bool(worker.is_present()).is_false()
	assert_int(worker.xp()).is_equal(20)
	assert_float(worker.efficiency(HARVEST, _balance())).is_equal(2.0)
	worker.set_present(true)
	assert_bool(worker.is_present()).is_true()

## La projection est l'endroit où l'Économie cesse de savoir : ni niveau, ni XP, ni
## présence ne la traversent. Ce qui en sort est un nom et des multiplicateurs.
func test_the_projection_carries_only_the_started_tracks() -> void:
	var worker := Worker.create(&"alaric", "Alaric")
	worker.gain(HARVEST, 20)
	var unit := worker.to_labor_unit(_balance())
	assert_str(String(unit.id())).is_equal("alaric")
	assert_array(unit.families()).contains_exactly([HARVEST])
	assert_float(unit.efficiency(HARVEST)).is_equal(2.0)
	assert_float(unit.efficiency(CRAFT)).is_equal(LaborUnit.BASE_EFFICIENCY)

func test_a_fresh_worker_projects_a_novice() -> void:
	var unit := Worker.create(&"alaric", "Alaric").to_labor_unit(_balance())
	assert_array(unit.families()).is_empty()
	assert_float(unit.efficiency(HARVEST)).is_equal(LaborUnit.BASE_EFFICIENCY)

func _balance() -> WorkforceBalance:
	var balance := WorkforceBalance.new()
	balance.base_roster_places = 10
	balance.xp_per_shift = 4
	balance.skill_xp_per_level = 10
	balance.max_skill_level = 4
	balance.efficiency_per_skill_level = 0.5
	balance.worker_xp_per_level = 25
	balance.max_worker_level = 4
	return balance
