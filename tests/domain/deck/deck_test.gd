class_name DeckTest
extends GdUnitTestSuite
## Les piles : ce qu'on pioche, ce qu'on défausse, ce qui revient, et ce que le draft
## fait bouger.
##
## Deux cas portent le jalon. **L'indépendance des trois pools** d'abord : c'est la
## seule chose que « trois pools » veut dire mécaniquement, et si elle se perdait, un
## deck d'actions se remplirait de bâtiments sans que rien d'autre ne le remarque avant
## D2. **Le déterminisme** ensuite : un même seed et une même suite de gestes doivent
## rendre les mêmes cartes, sans quoi la promesse de CLAUDE.md — un run se rejoue — ne
## tient plus dès qu'une carte est piochée.
##
## Aucune carte de data/ ici : le catalogue est fabriqué à la main, comme les bâtiments
## de production_resolver_test.gd. Le contenu bougera à I3, le mécanisme non.

const SEED := 20260825
const OTHER_SEED := 7

func test_a_fresh_deck_holds_what_it_was_composed_of() -> void:
	var deck := _deck()
	assert_int(deck.size()).is_equal(11)
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(7)
	assert_int(deck.total(CardData.POOL_BUILDING)).is_equal(4)
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(7)
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(0)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(0)

func test_an_empty_deck_holds_nothing() -> void:
	assert_int(Deck.empty(_catalogue()).size()).is_equal(0)

func test_drawing_moves_cards_from_the_pile_to_the_hand() -> void:
	var deck := _deck()
	var drawn := deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	assert_int(drawn.size()).is_equal(3)
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(4)
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(3)
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(7)
	assert_array(deck.hand().cards_in(CardData.POOL_ACTION)).contains_exactly(drawn)

## Un deck non mélangé se pioche dans l'ordre où il a été composé. C'est ce qui rend
## create() assertable sans rng, et ce qui donne un point de départ connu au reste.
func test_an_unshuffled_deck_deals_in_composition_order() -> void:
	var deck := _deck()
	assert_array(deck.draw(CardData.POOL_ACTION, 4, _rng(SEED))) \
		.contains_exactly([&"harvest", &"harvest", &"harvest", &"hunt"])

## Le cas du jalon. Trois pools, trois flux : ce qu'on fait à l'un ne se voit pas chez
## les autres.
func test_the_three_pools_ignore_each_other() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 5, _rng(SEED))
	deck.discard_hand()
	assert_int(deck.draw_size(CardData.POOL_BUILDING)).is_equal(4)
	assert_int(deck.discard_size(CardData.POOL_BUILDING)).is_equal(0)
	assert_int(deck.hand_size(CardData.POOL_BUILDING)).is_equal(0)
	assert_int(deck.total(CardData.POOL_BUILDING)).is_equal(4)

## « Remélange quand le deck est vide », DESIGN.md 3.5 : la défausse redevient la
## pioche, et rien ne s'est perdu au passage.
func test_an_exhausted_pile_recycles_the_discard() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 7, _rng(SEED))
	deck.discard_hand()
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(0)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(7)
	var drawn := deck.draw(CardData.POOL_ACTION, 2, _rng(SEED))
	assert_int(drawn.size()).is_equal(2)
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(5)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(0)
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(7)

## Le remélange tombe **au milieu** d'une pioche et non entre deux : une main plus
## grande que ce qui reste doit se remplir quand même.
func test_a_recycle_happens_in_the_middle_of_a_draw() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 6, _rng(SEED))
	deck.discard_hand()
	var drawn := deck.draw(CardData.POOL_ACTION, 4, _rng(SEED))
	assert_int(drawn.size()).is_equal(4)
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(7)

## Les deux piles vides : on rend moins que demandé, sans boucler. C'est le cas normal
## du pool des powers, vide jusqu'à X4, et une phase le pioche quand même.
func test_two_empty_piles_deal_fewer_cards_than_asked() -> void:
	var deck := _deck()
	var drawn := deck.draw(CardData.POOL_POWER, 3, _rng(SEED))
	assert_array(drawn).is_empty()
	assert_int(deck.hand_size(CardData.POOL_POWER)).is_equal(0)

func test_a_pile_deals_everything_it_has_and_stops() -> void:
	var deck := _deck()
	assert_int(deck.draw(CardData.POOL_BUILDING, 9, _rng(SEED)).size()).is_equal(4)

func test_discarding_moves_one_copy_out_of_the_hand() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	assert_bool(deck.discard(&"harvest")).is_true()
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(2)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(1)
	assert_bool(deck.hand().has(&"harvest")).is_true()

func test_discarding_a_card_that_is_not_held_changes_nothing() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 2, _rng(SEED))
	assert_bool(deck.discard(&"farm")).is_false()
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(2)
	assert_int(deck.discard_size(CardData.POOL_BUILDING)).is_equal(0)

func test_discarding_the_hand_empties_the_three_pools_at_once() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	deck.draw(CardData.POOL_BUILDING, 2, _rng(SEED))
	assert_int(deck.discard_hand()).is_equal(5)
	assert_bool(deck.hand().is_empty()).is_true()
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(3)
	assert_int(deck.discard_size(CardData.POOL_BUILDING)).is_equal(2)

## La porte par laquelle passe le report de main de DESIGN.md 3.5 : un pool se défausse
## seul, et les deux autres ne bougent pas. Sans elle, « garder ses bâtiments et défausser
## ses actions » aurait été un cas particulier écrit dans l'orchestrateur au lieu d'un
## réglage — alors que 3.5 pose la question par pool, pas pour la main entière.
func test_discarding_one_pool_leaves_the_others_alone() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	deck.draw(CardData.POOL_BUILDING, 2, _rng(SEED))
	assert_int(deck.discard_pool(CardData.POOL_ACTION)).is_equal(3)
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(0)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(3)
	assert_int(deck.hand_size(CardData.POOL_BUILDING)).is_equal(2)
	assert_int(deck.discard_size(CardData.POOL_BUILDING)).is_equal(0)

## Une main de pool déjà vide se défausse sans rien casser : c'est l'état d'une phase
## entièrement jouée, et celui du pool des powers à tous les instants jusqu'à X4.
func test_discarding_an_empty_pool_is_not_an_error() -> void:
	var deck := _deck()
	assert_int(deck.discard_pool(CardData.POOL_POWER)).is_equal(0)
	assert_bool(deck.hand().is_empty()).is_true()

## L'inverse exact de `discard()`, et la porte qu'une annulation emprunte.
func test_taking_a_card_back_returns_it_to_the_hand() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	deck.discard(&"harvest")
	assert_bool(deck.take_back(&"harvest")).is_true()
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(3)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(0)
	assert_bool(deck.hand().has(&"harvest")).is_true()

## Le revers, sans lequel une fonction qui rendrait toujours vrai passerait le cas
## précédent : on ne reprend pas une carte que la défausse n'a pas.
func test_taking_back_a_card_the_discard_does_not_hold_changes_nothing() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 2, _rng(SEED))
	assert_bool(deck.take_back(&"harvest")).is_false()
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(2)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(0)

## Reprendre puis défausser laisse le deck exactement comme il était. C'est ce qui fait
## d'un retrait une **annulation** plutôt qu'un geste qui coûte : aucun exemplaire n'est
## créé, aucun n'est perdu, et le total du pool ne bouge à aucun moment.
func test_discarding_and_taking_back_leaves_the_deck_untouched() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	var before := deck.hand().cards_in(CardData.POOL_ACTION)
	var total := deck.total(CardData.POOL_ACTION)
	deck.discard(&"harvest")
	deck.take_back(&"harvest")
	assert_array(deck.hand().cards_in(CardData.POOL_ACTION)).contains(before)
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(before.size())
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(total)

## Premier geste du draft. La carte entre par la défausse et non par la pioche : elle
## ne doit pas passer devant celles qui attendent leur tour depuis deux phases.
func test_a_drafted_card_enters_through_the_discard() -> void:
	var deck := _deck()
	deck.add(&"mine")
	assert_int(deck.total(CardData.POOL_BUILDING)).is_equal(5)
	assert_int(deck.discard_size(CardData.POOL_BUILDING)).is_equal(1)
	assert_int(deck.draw_size(CardData.POOL_BUILDING)).is_equal(4)

## Second geste du draft — « en retirer une définitivement ».
func test_a_removed_card_leaves_the_deck_for_good() -> void:
	var deck := _deck()
	assert_bool(deck.remove(&"hunt")).is_true()
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(6)
	assert_bool(deck.remove(&"hunt")).is_true()
	assert_bool(deck.remove(&"hunt")).is_false()
	assert_int(deck.total(CardData.POOL_ACTION)).is_equal(5)

func test_removing_a_card_the_deck_does_not_hold_changes_nothing() -> void:
	var deck := _deck()
	assert_bool(deck.remove(&"mine")).is_false()
	assert_int(deck.size()).is_equal(11)

## L'ordre de recherche est arbitraire mais fixé : pioche, défausse, main. Un retrait
## qui dépendrait de l'endroit où la carte se trouve ferait diverger deux runs partis du
## même seed.
func test_removing_takes_from_the_draw_pile_first() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 1, _rng(SEED))
	assert_bool(deck.remove(&"harvest")).is_true()
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(1)
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(5)

func test_shuffling_touches_only_the_draw_pile() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 2, _rng(SEED))
	deck.discard(&"harvest")
	deck.shuffle(CardData.POOL_ACTION, _rng(SEED))
	assert_int(deck.draw_size(CardData.POOL_ACTION)).is_equal(5)
	assert_int(deck.hand_size(CardData.POOL_ACTION)).is_equal(1)
	assert_int(deck.discard_size(CardData.POOL_ACTION)).is_equal(1)

## Le cas du jalon. Trois phases complètes — mélange, pioche des deux pools, défausse de
## la main —, dont un remélange en cours de route, rendent exactement la même suite de
## cartes sur le même seed.
func test_the_same_seed_deals_the_same_cards() -> void:
	assert_array(_three_phases(SEED)).contains_exactly(_three_phases(SEED))

## Son complément : sans lui, un deck qui ne mélangerait jamais passerait le précédent.
func test_another_seed_deals_other_cards() -> void:
	assert_bool(_three_phases(SEED) == _three_phases(OTHER_SEED)).is_false()

# --- Le recensement des piles ---------------------------------------------------------
#
# P1b : « une pioche et une défausse consultables, plutôt que trois compteurs »,
# DESIGN.md 8. Les tailles existaient depuis D1 ; ce qui manquait est le contenu.

func test_a_fresh_draw_pile_censuses_the_composition() -> void:
	var census := _deck().draw_census(CardData.POOL_ACTION)
	assert_int(census.size()).is_equal(3)
	assert_int(census[&"harvest"]).is_equal(3)
	assert_int(census[&"hunt"]).is_equal(2)
	assert_int(census[&"build"]).is_equal(2)

## Piocher retire de la pioche, et de la pioche seule : la carte n'est plus au
## recensement, et le pool voisin n'a pas bougé.
func test_drawing_leaves_the_census_of_the_draw_pile() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 3, _rng(SEED))
	var census := deck.draw_census(CardData.POOL_ACTION)
	assert_bool(census.has(&"harvest")).is_false()
	assert_int(census[&"hunt"]).is_equal(2)
	assert_int(deck.discard_census(CardData.POOL_ACTION).size()).is_equal(0)
	assert_int(deck.draw_census(CardData.POOL_BUILDING)[&"farm"]).is_equal(2)

func test_discarding_shows_up_in_the_census_of_the_discard() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 4, _rng(SEED))
	deck.discard_hand()
	var census := deck.discard_census(CardData.POOL_ACTION)
	assert_int(census[&"harvest"]).is_equal(3)
	assert_int(census[&"hunt"]).is_equal(1)

## Le remélange déplace le recensement d'une pile à l'autre sans rien perdre — le même
## fait que test_an_exhausted_pile_recycles_the_discard(), vu par le contenu.
func test_recycling_moves_the_census_back_to_the_draw_pile() -> void:
	var deck := _deck()
	deck.draw(CardData.POOL_ACTION, 7, _rng(SEED))
	deck.discard_hand()
	deck.draw(CardData.POOL_ACTION, 1, _rng(SEED))
	assert_int(deck.discard_census(CardData.POOL_ACTION).size()).is_equal(0)
	var census := deck.draw_census(CardData.POOL_ACTION)
	var counted := 0
	for card: StringName in census:
		counted += census[card]
	assert_int(counted).is_equal(6)

## Un pool vide et un pool qui n'existe pas rendent la même chose : rien. Les powers sont
## le premier cas jusqu'à X4, et une vue qui les affiche ne doit pas avoir à distinguer.
func test_an_empty_or_unknown_pool_censuses_nothing() -> void:
	var deck := _deck()
	assert_int(deck.draw_census(CardData.POOL_POWER).size()).is_equal(0)
	assert_int(deck.draw_census(&"nowhere").size()).is_equal(0)
	assert_int(deck.discard_census(&"nowhere").size()).is_equal(0)

## Le recensement est une copie. Sans ce cas, une vue qui trierait ou viderait ce qu'on
## lui rend muterait le deck sans qu'aucune ligne ne le dise.
func test_the_census_is_a_copy() -> void:
	var deck := _deck()
	var census := deck.draw_census(CardData.POOL_ACTION)
	census[&"harvest"] = 99
	census.erase(&"hunt")
	assert_int(deck.draw_census(CardData.POOL_ACTION)[&"harvest"]).is_equal(3)
	assert_int(deck.draw_census(CardData.POOL_ACTION)[&"hunt"]).is_equal(2)

## Le cas qui porte la décision de design, et le seul qui la **prouve**. Deux decks
## mélangés sur deux seeds différents piochent dans un ordre différent — c'est ce que
## test_another_seed_deals_other_cards() épingle — et recensent pourtant à l'identique.
## Autrement dit : l'ordre de pioche n'est pas dans la réponse, donc aucune vue ne peut
## le montrer par accident. Le refus est structurel et pas seulement respecté.
func test_the_census_says_nothing_of_the_order() -> void:
	var one := _deck()
	one.shuffle(CardData.POOL_ACTION, _rng(SEED))
	var other := _deck()
	other.shuffle(CardData.POOL_ACTION, _rng(OTHER_SEED))
	assert_dict(one.draw_census(CardData.POOL_ACTION)) \
		.is_equal(other.draw_census(CardData.POOL_ACTION))

## Trois phases sur un deck neuf : ce qui a été pioché, à la suite.
func _three_phases(rng_seed: int) -> Array[StringName]:
	var rng := _rng(rng_seed)
	var deck := _deck()
	deck.shuffle(CardData.POOL_ACTION, rng)
	deck.shuffle(CardData.POOL_BUILDING, rng)
	var dealt: Array[StringName] = []
	for _phase in 3:
		dealt.append_array(deck.draw(CardData.POOL_ACTION, 3, rng))
		dealt.append_array(deck.draw(CardData.POOL_BUILDING, 2, rng))
		deck.discard_hand()
	return dealt

## Sept actions et quatre bâtiments, dont plusieurs exemplaires de la même carte : c'est
## le profil d'un vrai deck de départ, et c'est ce qui fait passer les piles par le
## remélange en trois phases.
func _deck() -> Deck:
	var copies: Dictionary[StringName, int] = {}
	copies[&"harvest"] = 3
	copies[&"hunt"] = 2
	copies[&"build"] = 2
	copies[&"farm"] = 2
	copies[&"house"] = 2
	return Deck.create(_catalogue(), copies)

func _catalogue() -> CardCatalogue:
	var cards: Array[CardData] = [
		_card(&"harvest", CardData.POOL_ACTION),
		_card(&"hunt", CardData.POOL_ACTION),
		_card(&"build", CardData.POOL_ACTION),
		_card(&"farm", CardData.POOL_BUILDING),
		_card(&"house", CardData.POOL_BUILDING),
		_card(&"mine", CardData.POOL_BUILDING),
		_card(&"blessing", CardData.POOL_POWER),
	]
	return CardCatalogue.create(cards)

func _card(id: StringName, pool: StringName) -> CardData:
	var card := CardData.new()
	card.id = id
	card.label = String(id)
	card.pool = pool
	if pool == CardData.POOL_BUILDING:
		card.building = id
	return card

func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
