class_name WorkforceBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage des Effectifs et son filet de complétude.
##
## Aucun chiffre de data/balance/ n'est figé : les deux courbes de paliers bougeront à
## chaque passe d'équilibrage, et un test qui les figerait serait cassé en permanence.
## Ce qui est asserté, c'est le mécanisme qui refuse un bloc inexploitable.
##
## Les sept champs sont réclamés sans condition, ce qui est le cas normal du projet
## depuis I0 — le bloc économie était l'exception, et E1b l'a levée. Chacun des sept se
## charge sans erreur à zéro et casse plus loin : c'est ce décalage que le boot ferme.

func test_a_blank_block_reports_all_its_required_fields() -> void:
	assert_array(WorkforceBalance.new().missing_fields()) \
		.contains(["base_roster_places", "xp_per_shift", "skill_xp_per_level",
			"max_skill_level", "efficiency_per_skill_level", "worker_xp_per_level",
			"max_worker_level"])

func test_a_filled_block_reports_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

## Un seuil à zéro divise par zéro au premier palier calculé. C'est la seule des sept
## valeurs qui casse bruyamment, et encore : seulement le soir où quelqu'un travaille.
func test_a_zero_skill_threshold_is_reported() -> void:
	var balance := _balance()
	balance.skill_xp_per_level = 0
	assert_array(balance.missing_fields()).contains(["skill_xp_per_level"])

func test_a_zero_worker_threshold_is_reported() -> void:
	var balance := _balance()
	balance.worker_xp_per_level = 0
	assert_array(balance.missing_fields()).contains(["worker_xp_per_level"])

## Un plafond à zéro fige tout le monde au palier 0 : personne ne progresse jamais, et
## rien ne le signale. C'est le pire des sept, parce qu'il ne casse nulle part.
func test_a_zero_skill_cap_is_reported() -> void:
	var balance := _balance()
	balance.max_skill_level = 0
	assert_array(balance.missing_fields()).contains(["max_skill_level"])

func test_a_zero_worker_cap_is_reported() -> void:
	var balance := _balance()
	balance.max_worker_level = 0
	assert_array(balance.missing_fields()).contains(["max_worker_level"])

## Un cran d'efficacité nul rend la spécialisation invisible : les pistes montent, le
## rendement ne bouge pas, et DESIGN.md 3.4 devient déclaratif.
func test_a_zero_efficiency_step_is_reported() -> void:
	var balance := _balance()
	balance.efficiency_per_skill_level = 0.0
	assert_array(balance.missing_fields()).contains(["efficiency_per_skill_level"])

## Un gain nul supprime toute progression d'un coup, sur les deux axes.
func test_a_zero_shift_gain_is_reported() -> void:
	var balance := _balance()
	balance.xp_per_shift = 0
	assert_array(balance.missing_fields()).contains(["xp_per_shift"])

## Zéro place de base est un roster qu'aucune habitation ne peut sauver au premier jour.
func test_zero_base_places_is_reported() -> void:
	var balance := _balance()
	balance.base_roster_places = 0
	assert_array(balance.missing_fields()).contains(["base_roster_places"])

func _balance() -> WorkforceBalance:
	var balance := WorkforceBalance.new()
	balance.base_roster_places = 10
	balance.xp_per_shift = 4
	balance.skill_xp_per_level = 25
	balance.max_skill_level = 5
	balance.efficiency_per_skill_level = 0.15
	balance.worker_xp_per_level = 40
	balance.max_worker_level = 10
	return balance
