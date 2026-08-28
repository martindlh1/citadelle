class_name CombatBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage du Combat et son filet de complétude.
##
## Aucun chiffre de `data/balance/` n'est figé : ils bougeront tous à `I3`, et un test qui
## les figerait serait cassé en permanence. Ce qui est asserté, c'est le mécanisme qui
## refuse un bloc inexploitable — et, sur ce bloc en particulier, **lequel des cinq champs
## a le droit d'être nul**, qui est une décision de design et non un détail.

func test_a_blank_block_reports_all_its_required_fields() -> void:
	assert_array(CombatBalance.new().missing_fields()) \
		.contains(["base_deployment_slots", "defense_per_fighter", "combat_skill_family",
			"breach_per_casualty"])

func test_a_filled_block_reports_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

## Sans place de déploiement, personne ne monte jamais sur la ligne et le village ne se
## défend que par ses murs — tout `DESIGN.md` 3.6 disparaîtrait en silence.
func test_a_zero_deployment_cap_is_reported() -> void:
	var balance := _balance()
	balance.base_deployment_slots = 0
	assert_array(balance.missing_fields()).contains(["base_deployment_slots"])

## Un homme qui ne vaut rien sur la ligne rend le déploiement décoratif, et la piste
## Combat avec lui : le multiplicateur d'un vétéran s'appliquerait à zéro.
func test_a_worthless_fighter_is_reported() -> void:
	var balance := _balance()
	balance.defense_per_fighter = 0
	assert_array(balance.missing_fields()).contains(["defense_per_fighter"])

## Sans famille, l'XP de combat n'aurait aucune piste à créditer. C'est aussi le seul
## endroit du projet qui nomme cette famille — `DESIGN.md` 3.4 interdit qu'un code
## l'énumère, donc un champ vide ne se rattraperait nulle part.
func test_a_missing_skill_family_is_reported() -> void:
	var balance := _balance()
	balance.combat_skill_family = &""
	assert_array(balance.missing_fields()).contains(["combat_skill_family"])

## Zéro y serait une division par zéro au premier mort calculé.
func test_a_zero_casualty_threshold_is_reported() -> void:
	var balance := _balance()
	balance.breach_per_casualty = 0
	assert_array(balance.missing_fields()).contains(["breach_per_casualty"])

## **Le seul des cinq qui a le droit d'être nul**, et c'est une décision de contenu : une
## vague qui casse sans voler est un modèle jouable, et le réclamer interdirait de
## l'essayer sans toucher au GDScript. Le cas est écrit pour que personne ne « répare »
## cette absence en croyant corriger un oubli.
func test_a_wave_that_steals_nothing_is_legitimate() -> void:
	var balance := _balance()
	balance.plunder_per_breach = 0
	assert_array(balance.missing_fields()).is_empty()

func _balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.base_deployment_slots = 3
	balance.defense_per_fighter = 2
	balance.combat_skill_family = &"combat"
	balance.breach_per_casualty = 6
	balance.plunder_per_breach = 1
	balance.fighter_hit_points = 10
	balance.fighter_damage_min = 2
	balance.fighter_damage_max = 4
	balance.fighter_reach = 1
	balance.fighter_move = 5
	balance.fighter_climb = 1
	balance.climb_cost = 1
	balance.impassable_tags = [&"water"] as Array[StringName]
	balance.spawn_margin = 3
	return balance
