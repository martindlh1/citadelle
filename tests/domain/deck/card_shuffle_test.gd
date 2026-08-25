class_name CardShuffleTest
extends GdUnitTestSuite
## Le mélange : qu'il permute sans rien perdre, et qu'il ne dépende **que** du rng
## qu'on lui donne.
##
## Le cas qui porte le fichier est le dernier — celui qui reseede le générateur global
## entre deux mélanges et exige le même résultat. C'est le seul qui distinguerait cette
## implémentation d'un `Array.shuffle()`, et c'est précisément la substitution qu'un
## relecteur pressé ferait un jour pour « simplifier ». Sans lui, le déterminisme du
## run se perdrait sans qu'aucun test ne bronche.

const SEED := 20260825
const OTHER_SEED := 991

func test_a_shuffle_keeps_every_card() -> void:
	var mixed := CardShuffle.shuffled(_cards(), _rng(SEED))
	assert_array(mixed).contains_exactly_in_any_order(_cards())

func test_a_shuffle_leaves_the_source_untouched() -> void:
	var source := _cards()
	CardShuffle.shuffled(source, _rng(SEED))
	assert_array(source).contains_exactly(_cards())

func test_the_same_seed_shuffles_the_same_way() -> void:
	var first := CardShuffle.shuffled(_cards(), _rng(SEED))
	var second := CardShuffle.shuffled(_cards(), _rng(SEED))
	assert_array(first).contains_exactly(second)

## Le complément du précédent : sans lui, un mélange qui ne mélangerait rien passerait
## les deux.
func test_another_seed_shuffles_another_way() -> void:
	var first := CardShuffle.shuffled(_cards(), _rng(SEED))
	var second := CardShuffle.shuffled(_cards(), _rng(OTHER_SEED))
	assert_bool(first == second).is_false()

func test_an_empty_pile_shuffles_to_nothing() -> void:
	var none: Array[StringName] = []
	assert_array(CardShuffle.shuffled(none, _rng(SEED))).is_empty()

func test_a_single_card_shuffles_to_itself() -> void:
	var one: Array[StringName] = [&"harvest"]
	assert_array(CardShuffle.shuffled(one, _rng(SEED))).contains_exactly([&"harvest"])

## Le cas du fichier. Le générateur global est reseedé entre les deux mélanges : une
## implémentation qui tirerait sur lui — c'est ce que fait Array.shuffle() — rendrait
## deux ordres différents, et un même seed de run cesserait de rejouer à l'identique.
func test_the_global_generator_has_no_say() -> void:
	seed(1)
	var first := CardShuffle.shuffled(_cards(), _rng(SEED))
	randomize()
	var second := CardShuffle.shuffled(_cards(), _rng(SEED))
	assert_array(first).contains_exactly(second)

func _cards() -> Array[StringName]:
	var cards: Array[StringName] = [
		&"harvest", &"hunt", &"build", &"terraform", &"farm",
		&"house", &"quarry", &"mine", &"palisade", &"warehouse",
	]
	return cards

func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
