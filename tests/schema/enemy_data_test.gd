class_name EnemyDataTest
extends GdUnitTestSuite
## Un assaillant, et le filet qui refuse un fichier inexploitable.
##
## Aucun chiffre de `data/enemies/` n'est figé : ils bougeront tous à `I3`. Ce qui est
## asserté, c'est le mécanisme qui refuse un fichier vide — et surtout **lesquels des
## champs ont le droit d'être nuls**, qui est une décision de contenu et non un détail.

func test_a_blank_enemy_reports_all_its_required_fields() -> void:
	assert_array(EnemyData.new().missing_fields()) \
		.contains(["id", "label", "hit_points", "damage_max", "reach", "color"])

func test_a_filled_enemy_reports_nothing() -> void:
	assert_array(_enemy().missing_fields()).is_empty()

## Un assaillant sans nom s'annoncerait par son identifiant interne, en anglais, au milieu
## d'un rapport français. Même exigence que pour une `PhaseDef` et une `WaveDef`.
func test_a_nameless_enemy_is_reported() -> void:
	var enemy := _enemy()
	enemy.label = ""
	assert_array(enemy.missing_fields()).contains(["label"])

## Un corps sans point de vie tombe au premier coup et ne se distingue pas d'un champ
## oublié.
func test_an_enemy_without_hit_points_is_reported() -> void:
	var enemy := _enemy()
	enemy.hit_points = 0
	assert_array(enemy.missing_fields()).contains(["hit_points"])

## Un assaillant qui ne fait jamais de dégâts est un figurant, pas un assaillant.
func test_a_harmless_enemy_is_reported() -> void:
	var enemy := _enemy()
	enemy.damage_max = 0
	assert_array(enemy.missing_fields()).contains(["damage_max"])

## Une fourchette **inversée** ne veut rien dire et ne se distingue pas d'un oubli. C'est
## le seul contrôle de cohérence entre deux champs de ce fichier, sur le geste de
## `WaveSlot` — contrôler l'accord de deux champs plutôt que la présence de chacun.
func test_a_backwards_damage_range_is_reported() -> void:
	var enemy := _enemy()
	enemy.damage_min = 9
	enemy.damage_max = 4
	assert_array(enemy.missing_fields()).contains(["damage_min"])

## Une portée sous le contact n'atteint rien, pas même la case d'à côté.
func test_a_reach_below_contact_is_reported() -> void:
	var enemy := _enemy()
	enemy.reach = 0
	assert_array(enemy.missing_fields()).contains(["reach"])

# --- les trois zéros légitimes ---------------------------------------------------------

## **Une fourchette qui part de zéro est un assaillant qui rate parfois**, ce qui est un
## modèle jouable. Le cas est écrit pour que personne ne « répare » cette absence en
## croyant corriger un oubli.
func test_a_damage_range_starting_at_zero_is_legitimate() -> void:
	var enemy := _enemy()
	enemy.damage_min = 0
	assert_array(enemy.missing_fields()).is_empty()

## **Un corps immobile est une pièce de siège**, que le terrain rend redoutable ou
## inoffensive selon où elle entre. Le réclamer interdirait de l'essayer sans toucher au
## GDScript.
func test_an_enemy_that_never_moves_is_legitimate() -> void:
	var enemy := _enemy()
	enemy.move = 0
	assert_array(enemy.missing_fields()).is_empty()

## **Un corps qui ne grimpe pas** contourne le relief au lieu de le franchir, ce qui est
## exactement ce que `DESIGN.md` 3.6 veut rendre jouable.
func test_an_enemy_that_never_climbs_is_legitimate() -> void:
	var enemy := _enemy()
	enemy.climb = 0
	assert_array(enemy.missing_fields()).is_empty()

## Le noir opaque est le défaut d'un `Color` en GDScript, donc exactement ce que Godot omet
## d'un `.tres` : un champ oublié y est indiscernable d'un noir délibéré, et on tranche pour
## « oublié ». Même sentinelle que `TerrainData` et `PhaseDef`.
func test_an_unpainted_enemy_is_reported() -> void:
	var enemy := _enemy()
	enemy.color = EnemyData.UNSET_COLOR
	assert_array(enemy.missing_fields()).contains(["color"])

# --- la projection ---------------------------------------------------------------------

## Le profil rendu porte les chiffres du fichier, sans en inventer ni en perdre. C'est le
## seul point de passage entre `data/` et le plateau, et il rend **la même forme** qu'un
## ouvrier engagé — c'est ce qui permet au déplacement et aux dégâts de s'écrire une fois.
func test_the_profile_carries_the_file_unchanged() -> void:
	var stats := _enemy().to_stats()
	assert_int(stats.hit_points()).is_equal(12)
	assert_int(stats.damage_min()).is_equal(2)
	assert_int(stats.damage_max()).is_equal(5)
	assert_int(stats.reach()).is_equal(3)
	assert_int(stats.move()).is_equal(4)
	assert_int(stats.climb()).is_equal(2)

# --- ce que data/ porte ----------------------------------------------------------------

## `data/enemies/` doit décrire au moins un assaillant **à distance**, sans quoi la portée
## ne serait exercée par personne et le vocabulaire d'intentions de `F2b` n'aurait qu'un
## seul mot. Le cas ne nomme aucun fichier : c'est la propriété du catalogue qui compte.
func test_the_catalogue_holds_a_ranged_attacker() -> void:
	assert_bool(_catalogue_declares(func(data: EnemyData) -> bool:
			return data.reach > CombatStats.CONTACT)) \
		.override_failure_message("aucun assaillant de data/ ne frappe à distance") \
		.is_true()

## Et au moins un au **contact**, pour la raison symétrique.
func test_the_catalogue_holds_a_melee_attacker() -> void:
	assert_bool(_catalogue_declares(func(data: EnemyData) -> bool:
			return data.reach == CombatStats.CONTACT)) \
		.override_failure_message("aucun assaillant de data/ ne frappe au contact") \
		.is_true()

func _catalogue_declares(predicate: Callable) -> bool:
	for id in GameDatabase.list_enemy_ids():
		if predicate.call(GameDatabase.get_enemy(id)):
			return true
	return false

func _enemy() -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = &"test_enemy"
	enemy.label = "Assaillant d'essai"
	enemy.hit_points = 12
	enemy.damage_min = 2
	enemy.damage_max = 5
	enemy.reach = 3
	enemy.move = 4
	enemy.climb = 2
	enemy.color = Color(0.5, 0.4, 0.3, 1.0)
	return enemy
