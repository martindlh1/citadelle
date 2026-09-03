class_name WaveBalanceTest
extends GdUnitTestSuite
## L'échelle d'une marche : le filet qui attrape un `.tres` mal rempli, et la lecture qui traduit
## la patience d'un assaillant en cases de détour.
##
## **Deux champs et non quatre depuis `V2`.** La patience et l'enjambée sont parties chez
## `EnemyDef`, parce que `DESIGN.md` 3.5 en fait des chiffres de la créature — un bélier traverse
## un mur là où une meute le contourne. Ce qui reste est ce qui n'a pas de propriétaire : le prix
## d'un pas, celui d'un cran, c'est-à-dire l'unité dans laquelle les trois se comparent.
##
## Le filet est **complet** : zéro est invalide pour les deux, et ça tient à ce que les deux sont
## des prix — un prix nul n'est jamais un choix de contenu, c'est un champ qu'on a oublié.

func test_a_filled_block_lacks_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

func test_a_block_straight_out_of_new_names_both_fields() -> void:
	assert_array(WaveBalance.new().missing_fields()) \
		.contains(["step_cost", "climb_cost"])

## **Un pas gratuit est refusé**, et pas seulement pour éviter une division : à zéro, tous les
## chemins qui ne montent ni ne cassent auraient le même prix, et la vague prendrait le premier
## venu dans l'ordre de balayage plutôt que le plus court.
func test_a_free_step_is_reported() -> void:
	var balance := _balance()
	balance.step_cost = 0
	assert_array(balance.missing_fields()).is_equal(["step_cost"])

## **Une montée gratuite aussi**, et c'est un des rares champs où la doctrine du zéro sert un
## argument de design : un relief qui ne coûterait rien à gravir serait muet pour les vagues,
## alors qu'il est la moitié du sujet de `DESIGN.md` 3.5.
func test_a_free_climb_is_reported() -> void:
	var balance := _balance()
	balance.climb_cost = 0
	assert_array(balance.missing_fields()).is_equal(["climb_cost"])

# --- la patience, en cases ---------------------------------------------------

## La patience se lit en cases de détour, parce que c'est l'unité dans laquelle on la ressent.
## Elle ne se règle nulle part : elle se déduit du prix d'un pas et de la patience de
## l'assaillant, et c'est ce qui garantit qu'elle ne peut pas mentir sur ce que le chemin fait.
func test_the_patience_reads_as_a_detour_in_steps() -> void:
	var balance := _balance()
	balance.step_cost = 10
	assert_int(balance.patience_in_steps(_enemy(120))).is_equal(12)

## **Deux assaillants sur la même échelle n'ont pas la même patience**, et c'est tout l'intérêt
## d'avoir déplacé le champ : le chiffre lu dépend de la créature, pas du réglage global.
func test_two_enemies_on_the_same_scale_read_differently() -> void:
	var balance := _balance()
	balance.step_cost = 10
	assert_int(balance.patience_in_steps(_enemy(120))) \
		.override_failure_message("le bélier doit être plus impatient que la meute") \
		.is_greater(balance.patience_in_steps(_enemy(20)))

## Un mur moins cher qu'un pas donne zéro : l'assaillant ne détourne jamais pour lui. Le cas est
## là pour que ce réglage extrême rende un chiffre plutôt qu'une surprise.
func test_a_wall_cheaper_than_a_step_is_never_worth_a_detour() -> void:
	var balance := _balance()
	balance.step_cost = 10
	assert_int(balance.patience_in_steps(_enemy(4))).is_equal(0)

# --- le montage --------------------------------------------------------------

func _balance() -> WaveBalance:
	var balance := WaveBalance.new()
	balance.step_cost = 10
	balance.climb_cost = 6
	return balance

## Un assaillant dont seule la patience compte pour ces cas-là.
func _enemy(patience: int) -> EnemyDef:
	var enemy := EnemyDef.new()
	enemy.id = &"raider"
	enemy.label = "Pillard"
	enemy.hit_points = 6
	enemy.ticks_per_cell = 4
	enemy.damage = 4
	enemy.patience = patience
	enemy.climb = 2
	return enemy
