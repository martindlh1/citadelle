class_name PopulationTest
extends GdUnitTestSuite
## Le compteur d'habitants et ses deux invariants.
##
## Population est le jumeau de Ledger : une quantité, un plafond que des bâtiments
## relèvent, et un écrêtage quand ce plafond baisse. Les cas suivent donc de près ceux de
## ledger_test.gd, ce qui est voulu — si les deux divergent un jour, c'est que l'un des
## deux a cessé d'être le miroir de l'autre et ça se discute.

func test_a_new_village_is_empty() -> void:
	var people := Population.create(10)
	assert_int(people.headcount()).is_equal(0)
	assert_int(people.places()).is_equal(10)
	assert_int(people.free_places()).is_equal(10)

func test_a_village_can_open_with_inhabitants() -> void:
	var people := Population.from_headcount(4, 10)
	assert_int(people.headcount()).is_equal(4)
	assert_int(people.free_places()).is_equal(6)

## L'écrêtage plutôt que l'assertion, comme Ledger.from_stock : un effectif d'ouverture
## qui dépasse le logement est une question d'équilibrage, refusée au boot par
## EconomyBalance.missing_fields(), pas un défaut de programmation.
func test_an_opening_headcount_over_the_housing_is_clipped() -> void:
	var people := Population.from_headcount(20, 6)
	assert_int(people.headcount()).is_equal(6)
	assert_int(people.free_places()).is_equal(0)

func test_growth_fills_a_free_place() -> void:
	var people := Population.from_headcount(2, 4)
	assert_int(people.grow()).is_equal(1)
	assert_int(people.headcount()).is_equal(3)

## Le frein spatial de DESIGN.md 3.4, et le seul : sans lit, personne n'arrive, quelle que
## soit la nourriture. C'est ce qui empêche la boucle nourriture -> population -> fermes
## de s'emballer.
func test_growth_stops_at_the_housing_cap() -> void:
	var people := Population.from_headcount(4, 4)
	assert_bool(people.is_full()).is_true()
	assert_int(people.grow()).is_equal(0)
	assert_int(people.headcount()).is_equal(4)

## Demander plus que la place disponible n'est pas une erreur : c'est la situation normale
## d'un village qui a de quoi manger et nulle part où loger. Ce qui entre est ce qui tient,
## exactement comme Ledger.add() rend ce que le plafond a refusé.
func test_growth_is_bounded_rather_than_refused() -> void:
	var people := Population.from_headcount(3, 5)
	assert_int(people.grow(4)).is_equal(2)
	assert_int(people.headcount()).is_equal(5)

func test_shrinking_removes_an_inhabitant() -> void:
	var people := Population.from_headcount(3, 6)
	assert_int(people.shrink()).is_equal(1)
	assert_int(people.headcount()).is_equal(2)

## Un village de deux qui en perdrait trois n'est pas un cas d'erreur : c'est une
## soustraction qui s'arrête à zéro. Ce que le run en fait — la défaite de DESIGN.md 5 —
## se décide plus haut.
func test_shrinking_stops_at_zero() -> void:
	var people := Population.from_headcount(2, 6)
	assert_int(people.shrink(5)).is_equal(2)
	assert_int(people.headcount()).is_equal(0)

func test_a_new_house_raises_the_cap_without_bringing_anyone() -> void:
	var people := Population.from_headcount(4, 6)
	assert_int(people.set_places(10)).is_equal(0)
	assert_int(people.headcount()).is_equal(4)
	assert_int(people.free_places()).is_equal(6)

## Le cas qui fait de ce fichier le jumeau de Ledger, et le seul où la population meurt
## sans famine : une habitation détruite par une vague abaisse le plafond sous l'effectif,
## et le surplus s'en va. Ledger.set_capacity() écrête la réserve de la même façon quand un
## entrepôt tombe.
func test_a_destroyed_house_costs_the_surplus() -> void:
	var people := Population.from_headcount(9, 10)
	assert_int(people.set_places(6)).is_equal(3)
	assert_int(people.headcount()).is_equal(6)
	assert_int(people.free_places()).is_equal(0)

## Rendre la perte plutôt que la taire est ce qui permet à l'appelant d'en faire une ligne
## de rapport. Un plafond qui baisse sans atteindre l'effectif ne coûte donc rien, et le
## dit.
func test_lowering_the_cap_above_the_headcount_costs_nothing() -> void:
	var people := Population.from_headcount(4, 10)
	assert_int(people.set_places(6)).is_equal(0)
	assert_int(people.headcount()).is_equal(4)
