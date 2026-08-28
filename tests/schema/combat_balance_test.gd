class_name CombatBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage du Combat et son filet de complétude.
##
## Aucun chiffre de `data/balance/` n'est figé : ils bougeront tous à `I3`, et un test qui
## les figerait serait cassé en permanence. Ce qui est asserté, c'est le mécanisme qui
## refuse un bloc inexploitable — et, sur ce bloc en particulier, **lesquels des champs
## ont le droit d'être nuls**, qui est une décision de design et non un détail.
##
## Trois familles de champs y cohabitent depuis `F2a` : ceux du bouchon de `F1`, qui
## partiront avec lui à `F3` ; le profil d'un ouvrier engagé ; et les réglages du plateau.

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

# --- le profil d'un ouvrier engagé, et le plateau --------------------------------------

## Un défenseur sans point de vie tombe au premier coup et ne se distingue pas d'un champ
## oublié.
func test_a_fighter_without_hit_points_is_reported() -> void:
	var balance := _balance()
	balance.fighter_hit_points = 0
	assert_array(balance.missing_fields()).contains(["fighter_hit_points"])

## Un défenseur qui ne fait jamais de dégâts rend la piste Combat décorative : le
## multiplicateur d'un vétéran s'appliquerait à zéro.
func test_a_harmless_fighter_is_reported() -> void:
	var balance := _balance()
	balance.fighter_damage_max = 0
	assert_array(balance.missing_fields()).contains(["fighter_damage_max"])

## Une fourchette inversée ne veut rien dire, comme chez EnemyData.
func test_a_backwards_fighter_range_is_reported() -> void:
	var balance := _balance()
	balance.fighter_damage_min = 9
	assert_array(balance.missing_fields()).contains(["fighter_damage_min"])

## Un défenseur qui ne se déplace pas ne défend rien : le format de `DESIGN.md` 3.6 fait du
## déplacement la décision centrale, et sans lui il ne reste qu'un échange de coups sur
## place. C'est l'unique asymétrie avec `EnemyData`, où l'immobilité est jouable.
func test_a_rooted_fighter_is_reported() -> void:
	var balance := _balance()
	balance.fighter_move = 0
	assert_array(balance.missing_fields()).contains(["fighter_move"])

## **Une liste de tags vide est un champ perdu, pas un réglage.** Godot n'écrit pas un
## tableau vide dans un `.tres`, donc « oublié » et « délibérément vide » y sont
## indiscernables — c'est le piège de `resolves`, et l'issue de `PhaseDef` ne s'applique pas
## puisqu'aucun bloc au-dessus ne voit cette liste. Un combat où l'on marche sur l'eau n'est
## pas un modèle qu'on essaie.
func test_an_empty_impassable_list_is_reported() -> void:
	var balance := _balance()
	balance.impassable_tags = [] as Array[StringName]
	assert_array(balance.missing_fields()).contains(["impassable_tags"])

## Sans marge, la vague apparaîtrait dans les murs qu'elle vient casser.
func test_a_zero_spawn_margin_is_reported() -> void:
	var balance := _balance()
	balance.spawn_margin = 0
	assert_array(balance.missing_fields()).contains(["spawn_margin"])

## **Une montée gratuite est un modèle jouable** : le relief ne bloquerait plus que par les
## marches trop hautes, ce qui reste une des deux moitiés de `DESIGN.md` 3.6.
func test_a_free_climb_is_legitimate() -> void:
	var balance := _balance()
	balance.climb_cost = 0
	assert_array(balance.missing_fields()).is_empty()

## **Des défenseurs qui ne grimpent pas** font d'un plateau une forteresse dont ils ne
## sortent plus, ce qui est un modèle et non un oubli.
func test_fighters_who_never_climb_are_legitimate() -> void:
	var balance := _balance()
	balance.fighter_climb = 0
	assert_array(balance.missing_fields()).is_empty()

## Une fourchette de défenseur qui part de zéro est un homme qui rate parfois.
func test_a_fighter_range_starting_at_zero_is_legitimate() -> void:
	var balance := _balance()
	balance.fighter_damage_min = 0
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
