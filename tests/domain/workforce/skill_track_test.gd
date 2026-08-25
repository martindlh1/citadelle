class_name SkillTrackTest
extends GdUnitTestSuite
## Une piste de compétence : l'accumulation, les paliers, le plafond, le multiplicateur.
##
## Les réglages sont choisis pour que l'arithmétique se lise à l'œil nu — 10 d'XP par
## palier, plafond à 3, un cran d'efficacité à 0,5 — et n'ont rien à voir avec ceux de
## data/balance/. Un test qui reprendrait les vrais chiffres serait cassé à chaque passe
## d'équilibrage sans rien prouver de plus.
##
## Les deux cas qui portent sont le **franchissement au seuil exact** et le **plafond** :
## un palier qui tombe un point trop tôt ou un multiplicateur non borné passent
## inaperçus pendant des semaines et faussent tout l'équilibrage.

const HARVEST := &"harvest"

func test_a_fresh_track_is_at_zero() -> void:
	var track := SkillTrack.create(HARVEST)
	assert_str(String(track.family())).is_equal("harvest")
	assert_int(track.xp()).is_equal(0)
	assert_int(track.level(_balance())).is_equal(0)

## Une piste vierge veut dire « aucun bonus » et non « incapable ». C'est le contrat qui
## le pose, et la piste doit rendre exactement sa constante — pas 1.0 recopié.
func test_a_fresh_track_multiplies_by_the_contract_base() -> void:
	assert_float(SkillTrack.create(HARVEST).efficiency(_balance())) \
		.is_equal(LaborUnit.BASE_EFFICIENCY)

func test_xp_accumulates() -> void:
	var track := SkillTrack.create(HARVEST)
	track.gain(4)
	track.gain(3)
	assert_int(track.xp()).is_equal(7)

## Le palier tombe **au** seuil, pas un point avant. C'est la frontière que personne ne
## relit et que tout le monde décale d'un.
func test_a_level_lands_exactly_on_its_threshold() -> void:
	assert_int(SkillTrack.at_xp(HARVEST, 9).level(_balance())).is_equal(0)
	assert_int(SkillTrack.at_xp(HARVEST, 10).level(_balance())).is_equal(1)
	assert_int(SkillTrack.at_xp(HARVEST, 19).level(_balance())).is_equal(1)
	assert_int(SkillTrack.at_xp(HARVEST, 20).level(_balance())).is_equal(2)

func test_each_level_adds_one_step_of_efficiency() -> void:
	assert_float(SkillTrack.at_xp(HARVEST, 10).efficiency(_balance())).is_equal(1.5)
	assert_float(SkillTrack.at_xp(HARVEST, 20).efficiency(_balance())).is_equal(2.0)

## Sans plafond, une partie longue laisse le multiplicateur diverger et l'équilibrage
## n'a plus de prise. L'XP au-delà s'accumule quand même — elle n'est simplement plus
## convertie.
func test_the_level_stops_at_the_cap() -> void:
	var track := SkillTrack.at_xp(HARVEST, 1000)
	assert_int(track.level(_balance())).is_equal(3)
	assert_float(track.efficiency(_balance())).is_equal(2.5)
	assert_int(track.xp()).is_equal(1000)

func test_a_track_reports_when_it_is_capped() -> void:
	assert_bool(SkillTrack.at_xp(HARVEST, 29).is_capped(_balance())).is_false()
	assert_bool(SkillTrack.at_xp(HARVEST, 30).is_capped(_balance())).is_true()

## La même règle sert aux deux axes, avec d'autres réglages. Un palier qui accélérerait
## sur un axe et pas sur l'autre serait une décision d'équilibrage écrite dans du code.
func test_the_level_rule_is_shared_and_takes_its_settings_as_arguments() -> void:
	assert_int(SkillTrack.level_at(100, 40, 10)).is_equal(2)
	assert_int(SkillTrack.level_at(100, 10, 3)).is_equal(3)
	assert_int(SkillTrack.level_at(0, 40, 10)).is_equal(0)

func _balance() -> WorkforceBalance:
	var balance := WorkforceBalance.new()
	balance.base_roster_places = 10
	balance.xp_per_shift = 4
	balance.skill_xp_per_level = 10
	balance.max_skill_level = 3
	balance.efficiency_per_skill_level = 0.5
	balance.worker_xp_per_level = 40
	balance.max_worker_level = 10
	return balance
