class_name CombatStatsTest
extends GdUnitTestSuite
## Le profil d'un corps : ce qu'il encaisse, ce qu'il porte, jusqu'où il atteint.
##
## Le contrat que les deux camps partagent, et c'est ce partage qui est vérifié ici — pas
## des chiffres. Aucun cas ne fige une valeur de `data/balance/` : elles bougeront toutes à
## `I3`, et un test qui les figerait serait cassé en permanence sans avoir rien prouvé.
##
## Ce qui est asserté, c'est la **portée** — parce qu'elle décide de ce qu'un écran allume
## et de ce qu'un coup atteint, et que les deux doivent dire la même chose.

const HERE := Vector2i(4, 4)

# --- la portée -------------------------------------------------------------------------

## Un corps atteint la case où il se tient. Ce n'est pas un cas tordu : c'est ce qui rend
## `can_reach()` utilisable pour allumer les cases visables sans traiter le centre à part.
func test_a_body_reaches_its_own_cell() -> void:
	assert_bool(_stats(CombatStats.CONTACT).can_reach(HERE, HERE)).is_true()

## Le contact, c'est les quatre voisines et rien d'autre.
func test_contact_reaches_the_four_neighbours() -> void:
	var stats := _stats(CombatStats.CONTACT)
	for step in CombatMovement.NEIGHBOURS:
		assert_bool(stats.can_reach(HERE, HERE + step)) \
			.override_failure_message("le contact n'atteint pas %s" % step) \
			.is_true()

## **La diagonale n'est pas à portée du contact**, et c'est la conséquence directe du choix
## de métrique. Le déplacement est orthogonal, donc la portée est en Manhattan : mélanger
## les deux ferait qu'une case atteignable en deux pas serait « au contact », et toute case
## allumée à l'écran mentirait.
func test_contact_does_not_reach_a_diagonal() -> void:
	assert_bool(_stats(CombatStats.CONTACT).can_reach(HERE, HERE + Vector2i(1, 1))) \
		.is_false()

## Une portée de 3 atteint trois cases en ligne, et pas la quatrième.
func test_range_counts_in_manhattan_steps() -> void:
	var stats := _stats(3)
	assert_bool(stats.can_reach(HERE, HERE + Vector2i(3, 0))).is_true()
	assert_bool(stats.can_reach(HERE, HERE + Vector2i(4, 0))).is_false()
	assert_bool(stats.can_reach(HERE, HERE + Vector2i(2, 1))).is_true()
	assert_bool(stats.can_reach(HERE, HERE + Vector2i(2, 2))).is_false()

## La portée ne regarde pas le relief ni les murs : elle dit une distance, et rien d'autre.
## C'est le plateau qui décide s'il y a quelque chose à toucher.
func test_range_is_symmetric() -> void:
	var stats := _stats(2)
	var there := HERE + Vector2i(0, 2)
	assert_bool(stats.can_reach(HERE, there)).is_equal(stats.can_reach(there, HERE))

# --- ce qu'un profil porte -------------------------------------------------------------

## Une fourchette **dégénérée** est légitime, et c'est elle que les cas de test emploient
## quand ils veulent vérifier une règle sans que l'aléatoire s'en mêle. Le cas est écrit
## pour que personne ne « répare » l'égalité en croyant corriger une incohérence.
func test_a_degenerate_damage_range_is_legitimate() -> void:
	var stats := CombatStats.create(10, 3, 3, CombatStats.CONTACT, 4, 1)
	assert_int(stats.damage_min()).is_equal(stats.damage_max())

## Un corps qui ne se déplace pas est une pièce de siège, pas un champ oublié.
func test_a_body_that_never_moves_is_legitimate() -> void:
	assert_int(CombatStats.create(10, 2, 4, CombatStats.CONTACT, 0, 1).move()).is_equal(0)

## Un corps qui ne grimpe pas ne franchit aucune marche. Zéro y est une affirmation.
func test_a_body_that_never_climbs_is_legitimate() -> void:
	assert_int(CombatStats.create(10, 2, 4, CombatStats.CONTACT, 4, 0).climb()).is_equal(0)

## Les points de vie sont un **maximum**, pas un état : deux corps du même palier partagent
## le même profil, et blesser l'un ne doit pas blesser l'autre. C'est ce qui autorise à
## partager une `CombatStats` entre plusieurs `Combatant`.
func test_a_shared_profile_is_not_a_shared_wound() -> void:
	var stats := CombatStats.create(10, 2, 4, CombatStats.CONTACT, 4, 1)
	var first := Combatant.create(&"ana", Combatant.Side.FRIEND, Vector2i.ZERO, stats)
	var second := Combatant.create(&"bo", Combatant.Side.FRIEND, Vector2i.ONE, stats)
	first.take(6)
	assert_int(first.hit_points()).is_equal(4)
	assert_int(second.hit_points()).is_equal(10)
	assert_int(stats.hit_points()).is_equal(10)

func _stats(reach: int) -> CombatStats:
	return CombatStats.create(10, 2, 4, reach, 4, 1)
