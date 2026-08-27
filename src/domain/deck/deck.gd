class_name Deck
extends RefCounted
## Les cartes du run : trois pioches, trois défausses, une main.
##
## État mutable du système Cartes, comme CityState l'est de Construction, le Ledger de
## l'Économie et le Roster des Effectifs. Il manipule des **identifiants** de carte et
## interroge le catalogue quand il a besoin d'en savoir plus, exactement comme le Ledger
## manipule des identifiants de ressource.
##
## Les trois pools de DESIGN.md 3.5 sont trois flux indépendants : piocher une action ne
## touche pas aux bâtiments, et une défausse d'actions ne remplit que la pioche
## d'actions. C'est la seule chose que « trois pools » veut dire mécaniquement, et c'est
## ce qu'un cas de test épingle.
##
## Deux choses qu'il ne fait pas, et qui ne sont pas des oublis :
##
##   - **il ne juge aucune jouabilité.** DESIGN.md 3.5 dit qu'un jeu de carte est une
##     *intention* que le système concerné accepte ou refuse. Le Deck ne connaît ni la
##     grille, ni la bourse, ni le placement — c'est écrit dans son contrat. Jouer une
##     carte, vu d'ici, c'est l'appelant qui la défausse une fois la réponse obtenue.
##   - **il ne décide pas quand on pioche ni quand on défausse.** Les tailles de main
##     vivent dans DeckBalance, le moment appartient à la journée, donc à I1. C'est ce
##     qui laisse entier l'OUVERT de 3.5 sur le sort de la main non jouée : le Deck
##     offre les gestes, il n'en impose aucun.
##
## Le RNG est un **argument** et jamais un membre. Le Deck ne possède pas de flux
## d'aléatoire, il consomme celui du run — RunState.rng, dont DESIGN.md fait passer tout
## l'aléatoire. Un Deck qui garderait le sien serait un second flux à seeder, et un
## second endroit où un run cesserait d'être rejouable.

## Ce qui existe comme carte. Jamais null.
var _catalogue: CardCatalogue

## Pool -> pioche. L'index 0 est le sommet : c'est de là que draw() prend.
##
## Le type de valeur reste Array nu, comme dans Hand et Assignment : GDScript ne sait
## pas déclarer le paramètre d'un type imbriqué dans un Dictionary typé.
var _draw: Dictionary[StringName, Array] = {}

## Pool -> défausse, dans l'ordre où les cartes y sont tombées.
var _discard: Dictionary[StringName, Array] = {}

## Pool -> main, dans l'ordre de pioche.
var _hand: Dictionary[StringName, Array] = {}

## Deck composé de ces exemplaires : carte -> nombre.
##
## Les trois pioches sortent dans l'ordre du catalogue, **non mélangées**. Le mélange
## est un geste séparé et public, que l'ouverture d'un run fait sur les trois pools :
## create() ne prend donc pas de rng, ce qui permet d'asserter la composition d'un deck
## sans en tirer un. C'est le même partage que HeightGrid, qui se construit vide et se
## fait creuser ensuite.
static func create(catalogue: CardCatalogue, copies: Dictionary[StringName, int]) -> Deck:
	assert(catalogue != null, "deck composé sans catalogue")
	var deck := Deck.new()
	deck._catalogue = catalogue
	for pool in CardData.POOLS:
		deck._draw[pool] = _empty_pile()
		deck._discard[pool] = _empty_pile()
		deck._hand[pool] = _empty_pile()
	for card in copies:
		assert(catalogue.has(card), "deck composé sur une carte inconnue : %s" % card)
		var count: int = copies[card]
		assert(count > 0, "nombre d'exemplaires non positif pour %s : %d" % [card, count])
		if not catalogue.has(card):
			continue
		for _copy in count:
			deck._draw[catalogue.pool_of(card)].append(card)
	return deck

## Deck sans aucune carte, sur ce catalogue.
static func empty(catalogue: CardCatalogue) -> Deck:
	var none: Dictionary[StringName, int] = {}
	return Deck.create(catalogue, none)

## Mélange la pioche de ce pool. La défausse et la main n'y touchent pas.
##
## À faire sur les trois pools à l'ouverture d'un run. Ce n'est pas fait par create()
## pour que composer un deck reste sans aléatoire — voir son docstring.
func shuffle(pool: StringName, rng: RandomNumberGenerator) -> void:
	assert(CardData.is_known_pool(pool), "mélange d'un pool inconnu : %s" % pool)
	var pile: Array[StringName] = []
	pile.assign(_draw[pool])
	_draw[pool] = CardShuffle.shuffled(pile, rng)

## Pioche jusqu'à `count` cartes de ce pool et les met en main. Rend celles qui ont
## été piochées, dans l'ordre.
##
## Quand la pioche s'épuise en cours de route, la défausse est remélangée et devient la
## nouvelle pioche — « remélange quand le deck est vide », DESIGN.md 3.5. Le remélange
## tombe donc **au milieu** d'une pioche et non entre deux, ce qui est le comportement
## attendu d'une main plus grande que ce qui reste.
##
## Si les deux piles sont vides, on rend moins que demandé, jusqu'à rien. Ce n'est pas
## une erreur mais le cas normal : le pool des powers est vide et le restera jusqu'à X4,
## et une phase le pioche quand même.
func draw(pool: StringName, count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	assert(CardData.is_known_pool(pool), "pioche dans un pool inconnu : %s" % pool)
	assert(count >= 0, "pioche d'un nombre négatif de cartes : %d" % count)
	assert(rng != null, "pioche sans générateur")
	var drawn: Array[StringName] = []
	for _card in count:
		if _draw[pool].is_empty():
			_recycle(pool, rng)
		if _draw[pool].is_empty():
			break
		var card: StringName = _draw[pool].pop_front()
		_hand[pool].append(card)
		drawn.append(card)
	return drawn

## Ce que le joueur tient, figé.
func hand() -> Hand:
	return Hand.create(_hand)

## Défausse un exemplaire de cette carte depuis la main. Rend false si la main n'en
## tient aucun.
##
## C'est aussi ce qui arrive à une carte **jouée**, et le Deck ne distingue pas les
## deux : la distinction appartient à la phase, pas aux piles. Le jour où une carte
## jouée irait ailleurs — exilée, consommée, gardée —, c'est ici que ça s'écrira, et ce
## jour-là l'OUVERT de DESIGN.md 3.5 aura été tranché.
func discard(card: StringName) -> bool:
	for pool in CardData.POOLS:
		var at: int = _hand[pool].find(card)
		if at < 0:
			continue
		_hand[pool].remove_at(at)
		_discard[pool].append(card)
		return true
	return false

## Reprend en main un exemplaire de cette carte depuis la défausse. Rend false si la
## défausse n'en tient aucun.
##
## L'exact inverse de discard(), et il existe pour un geste précis : **annuler**. Retirer
## une action posée est un jeu de carte à l'envers — rien n'a encore été consommé, aucun
## ouvrier n'a travaillé, aucune ressource n'est sortie —, donc la carte doit revenir là
## d'où elle vient. Sans cette porte, le retrait était un sacrifice qui punissait un clic
## raté plutôt qu'une décision.
##
## **Ce n'est pas une réponse à l'OUVERT de DESIGN.md 3.5.** Celui-ci porte sur le sort
## des cartes **non jouées en fin de phase** ; celle-ci a été jouée et reprise dans la
## phase même. Les deux gestes ne tombent ni au même moment ni sur les mêmes cartes, et
## I2b garde sa question entière.
##
## L'exemplaire repris est le **dernier tombé**, ce qui n'a aucune conséquence observable
## — deux exemplaires d'une même carte sont interchangeables — mais fixe l'ordre, donc
## garde deux runs partis du même seed identiques jusque dans la composition des piles.
func take_back(card: StringName) -> bool:
	for pool in CardData.POOLS:
		var at: int = _discard[pool].rfind(card)
		if at < 0:
			continue
		_discard[pool].remove_at(at)
		_hand[pool].append(card)
		return true
	return false

## Défausse toute la main, les trois pools, et rend le nombre de cartes défaussées.
##
## Une capacité, pas une politique : rien ici ne dit qu'une phase se termine ainsi. Qui
## l'appelle, et s'il l'appelle, est la question que DESIGN.md 3.5 garde ouverte.
func discard_hand() -> int:
	var count := 0
	for pool in CardData.POOLS:
		count += _hand[pool].size()
		_discard[pool].append_array(_hand[pool])
		_hand[pool] = _empty_pile()
	return count

## Ajoute un exemplaire de cette carte au deck. Elle entre par la **défausse**.
##
## Premier des deux gestes du draft. La défausse plutôt que la pioche : une carte gagnée
## en cours de run ne doit pas s'intercaler dans une pioche déjà entamée, ce qui la
## rendrait tirable avant des cartes qui attendaient leur tour depuis deux phases. Entre
## deux runs la question ne se pose pas — tout est recomposé et remélangé.
func add(card: StringName) -> void:
	assert(_catalogue.has(card), "carte inconnue ajoutée au deck : %s" % card)
	if not _catalogue.has(card):
		return
	_discard[_catalogue.pool_of(card)].append(card)

## Retire définitivement un exemplaire de cette carte. Rend false si le deck n'en a
## aucun, où que ce soit.
##
## Second geste du draft — « en retirer une définitivement », DESIGN.md 3.5. L'exemplaire
## est cherché dans la pioche, puis dans la défausse, puis dans la main. L'ordre est
## arbitraire mais **fixé** : un retrait qui dépendrait de l'endroit où la carte se
## trouve ferait diverger deux runs partis du même seed.
func remove(card: StringName) -> bool:
	assert(_catalogue.has(card), "carte inconnue retirée du deck : %s" % card)
	if not _catalogue.has(card):
		return false
	var pool := _catalogue.pool_of(card)
	for pile in [_draw[pool], _discard[pool], _hand[pool]]:
		var at: int = pile.find(card)
		if at >= 0:
			pile.remove_at(at)
			return true
	return false

## Cartes restant dans la pioche de ce pool.
func draw_size(pool: StringName) -> int:
	return _pile_size(_draw, pool)

## Cartes tombées dans la défausse de ce pool.
func discard_size(pool: StringName) -> int:
	return _pile_size(_discard, pool)

## Cartes tenues en main dans ce pool.
func hand_size(pool: StringName) -> int:
	return _pile_size(_hand, pool)

## Ce que la pioche de ce pool contient : carte -> nombre d'exemplaires.
##
## Un **recensement** et non une liste, et c'est la seule décision de design de cette
## paire. La pioche est ordonnée — l'index 0 est le sommet, c'est écrit sur _draw — donc
## en rendre le contenu dans l'ordre dirait au joueur non seulement *ce qu'il reste* mais
## *quand ça vient*. Ce serait répondre par accident à l'OUVERT de DESIGN.md 3.5 sur la
## main non jouée : la question « que fait-on d'une main qu'on ne peut pas jouer » cesse
## d'être un pari dès qu'on lit les trois prochaines cartes.
##
## Le refus vit donc **ici** et pas dans une vue. Rendre l'ordre puis demander à
## l'adapter de ne pas le montrer laisserait la règle dans un commentaire, à un appel de
## distance de la fuite ; un recensement n'a pas d'ordre à trahir. Même geste que le bloc
## production nullable de E1b — la cohérence devient structurelle au lieu d'être vérifiée.
##
## Le dictionnaire est neuf à chaque appel : le muter ne touche pas au deck.
func draw_census(pool: StringName) -> Dictionary[StringName, int]:
	return _census(_draw, pool)

## Ce que la défausse de ce pool contient : carte -> nombre d'exemplaires.
##
## Recensement lui aussi, par symétrie plutôt que par nécessité — l'ordre d'une défausse
## ne prédit rien, puisque _recycle() le détruit au premier remélange. Deux formes pour
## deux piles auraient été deux choses à écrire et deux à lire, pour une information qui
## expire.
func discard_census(pool: StringName) -> Dictionary[StringName, int]:
	return _census(_discard, pool)

## Cartes possédées dans ce pool, les trois piles réunies. C'est ce que le draft fait
## bouger, et rien d'autre.
func total(pool: StringName) -> int:
	return draw_size(pool) + discard_size(pool) + hand_size(pool)

## Cartes possédées, tous pools confondus.
func size() -> int:
	var owned := 0
	for pool in CardData.POOLS:
		owned += total(pool)
	return owned

## Remet la défausse dans la pioche, mélangée. Sans effet si la défausse est vide.
func _recycle(pool: StringName, rng: RandomNumberGenerator) -> void:
	if _discard[pool].is_empty():
		return
	var recycled: Array[StringName] = []
	recycled.assign(_discard[pool])
	_draw[pool] = CardShuffle.shuffled(recycled, rng)
	_discard[pool] = _empty_pile()

## Recensement d'une pile de ce pool. Vide si le pool est inconnu, comme _pile_size()
## rend 0 : un pool qui n'existe pas ne contient rien, ce n'est pas une erreur.
func _census(piles: Dictionary[StringName, Array],
		pool: StringName) -> Dictionary[StringName, int]:
	var census: Dictionary[StringName, int] = {}
	if not piles.has(pool):
		return census
	for card: StringName in piles[pool]:
		census[card] = census.get(card, 0) + 1
	return census

## Taille d'une pile de ce pool, 0 si le pool est inconnu.
func _pile_size(piles: Dictionary[StringName, Array], pool: StringName) -> int:
	if not piles.has(pool):
		return 0
	return piles[pool].size()

## Pile vide et typée. GDScript ne sait pas écrire ce littéral en place dans un
## Dictionary dont la valeur est un Array nu.
static func _empty_pile() -> Array[StringName]:
	var pile: Array[StringName] = []
	return pile
