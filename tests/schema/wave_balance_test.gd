class_name WaveBalanceTest
extends GdUnitTestSuite
## Les coûts d'une vague : le filet qui attrape un `.tres` mal rempli, et la lecture qui traduit
## la patience en cases.
##
## Le filet est **complet** ici : zéro est invalide pour les quatre champs, donc aucun oubli ne
## passe. C'est rare dans `src/schema/`, et ça tient à ce que les quatre sont des prix — un prix
## nul n'est jamais un choix de contenu, c'est un champ qu'on a oublié.

func test_a_filled_block_lacks_nothing() -> void:
	assert_array(_balance().missing_fields()).is_empty()

func test_a_block_straight_out_of_new_names_all_four_fields() -> void:
	assert_array(WaveBalance.new().missing_fields()) \
		.contains(["step_cost", "climb_cost", "breach_cost", "max_climb"])

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

## Un mur gratuit ferait de tout bâtiment un passage, donc de la palissade une décoration.
func test_a_free_breach_is_reported() -> void:
	var balance := _balance()
	balance.breach_cost = 0
	assert_array(balance.missing_fields()).is_equal(["breach_cost"])

# --- la patience, en cases ---------------------------------------------------

## La patience se lit en cases de détour, parce que c'est l'unité dans laquelle on la ressent.
## Elle ne se règle nulle part : elle se déduit des deux prix, et c'est ce qui garantit qu'elle
## ne peut pas mentir sur ce que le chemin fait vraiment.
func test_the_patience_reads_as_a_detour_in_steps() -> void:
	var balance := _balance()
	balance.step_cost = 10
	balance.breach_cost = 120
	assert_int(balance.patience_in_steps()).is_equal(12)

## Un mur moins cher qu'un pas donne zéro : la vague ne détourne jamais pour lui. Le cas est là
## pour que ce réglage extrême rende un chiffre plutôt qu'une surprise.
func test_a_wall_cheaper_than_a_step_is_never_worth_a_detour() -> void:
	var balance := _balance()
	balance.step_cost = 10
	balance.breach_cost = 4
	assert_int(balance.patience_in_steps()).is_equal(0)

# --- le montage --------------------------------------------------------------

func _balance() -> WaveBalance:
	var balance := WaveBalance.new()
	balance.step_cost = 10
	balance.climb_cost = 6
	balance.breach_cost = 120
	balance.max_climb = 2
	return balance
