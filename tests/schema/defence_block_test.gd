class_name DefenceBlockTest
extends GdUnitTestSuite
## Le bloc de défense : sa géométrie de portée, et le filet qui attrape un `.tres` mal rempli.
##
## **La portée est éprouvée ici et non sur le plateau de combat**, et c'est une leçon de `V2` :
## un premier cas avait tenté de la montrer sur une bataille, en posant une tour à côté d'un
## chemin en ligne droite. Il ne pouvait rien prouver — à distance égale d'une **rangée**,
## Manhattan et les anneaux rendent le même chiffre, puisque la case la plus proche est toujours
## celle qui est juste en face. Il fallait une géométrie nue pour séparer les deux, donc un cas
## de schéma.
##
## Ce que le plateau garde est l'autre moitié de la question : *qui* viser parmi ceux qui sont à
## portée. Ce n'est pas la même, et elle n'est pas géométrique.

func test_a_filled_block_lacks_nothing() -> void:
	assert_array(_block().missing_fields()).is_empty()

func test_a_block_straight_out_of_new_names_all_three_fields() -> void:
	assert_array(DefenceBlock.new().missing_fields()) \
		.contains(["reach", "damage", "cadence"])

## Les trois sont réclamés parce que le bloc est nullable : un bâtiment qui ne tire pas n'a pas
## de bloc, donc un bloc qui existe a forcément trois chiffres. Voir `BuildingData.defence`.
func test_each_missing_number_is_named() -> void:
	for field in ["reach", "damage", "cadence"]:
		var block := _block()
		block.set(field, 0)
		assert_array(block.missing_fields()) \
			.override_failure_message("%s à zéro devait être nommé" % field) \
			.is_equal([field])

# --- la portée est un losange ------------------------------------------------

func test_a_cell_in_a_straight_line_is_covered() -> void:
	assert_bool(_block(2).covers(Vector2i(4, 4), Vector2i(4, 6))).is_true()
	assert_bool(_block(2).covers(Vector2i(4, 4), Vector2i(6, 4))).is_true()

## **Le cas qui fixe la métrique.** Une diagonale à deux cases est à 4 en Manhattan : hors de
## portée d'une tour qui porte à 2. En anneaux, elle serait dedans — et la zone d'une tour serait
## un carré de 25 cases au lieu d'un losange de 13.
##
## `DESIGN.md` 3.5 le veut ainsi, et la conséquence de jeu est celle qui compte : une tour tient
## un **axe**, elle ne tient pas un carré. C'est ce qui rend l'arbitrage « sur le chemin ou à
## côté » lisible.
func test_a_diagonal_at_the_reach_is_not_covered() -> void:
	assert_bool(_block(2).covers(Vector2i(4, 4), Vector2i(6, 6))) \
		.override_failure_message("deux cases en diagonale valent 4 en Manhattan") \
		.is_false()

## Et la diagonale courte l'est : le losange n'exclut pas toute diagonale, seulement celles dont
## la somme dépasse. Sans ce cas, le précédent passerait sur une portée qui refuserait toute
## diagonale, ce qui serait une troisième métrique et non celle du document.
func test_a_short_diagonal_is_covered() -> void:
	assert_bool(_block(2).covers(Vector2i(4, 4), Vector2i(5, 5))).is_true()

func test_the_cell_itself_is_covered() -> void:
	assert_bool(_block(1).covers(Vector2i(4, 4), Vector2i(4, 4))).is_true()

func test_a_cell_one_past_the_reach_is_not_covered() -> void:
	assert_bool(_block(3).covers(Vector2i(0, 0), Vector2i(0, 4))).is_false()

# --- le montage --------------------------------------------------------------

func _block(reach := 4) -> DefenceBlock:
	var block := DefenceBlock.new()
	block.reach = reach
	block.damage = 3
	block.cadence = 20
	return block
