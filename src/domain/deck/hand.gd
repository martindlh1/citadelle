class_name Hand
extends RefCounted
## Ce que le joueur tient : les trois pools ensemble, chacun dans son ordre de pioche.
##
## Projection immuable, dont Deck.hand() est le seul producteur — le miroir exact de
## Roster.to_labor() et de CityState.to_snapshot(). Le Deck garde ses piles ; la main
## qu'il rend ne peut pas jouer à sa place.
##
## Une seule main pour trois pools, et non trois mains : le joueur en tient une, dont
## DESIGN.md 3.5 dit seulement qu'elle se pioche et se défausse pool par pool. Les
## sections sont une propriété de la main, pas trois objets à tenir cohérents.

## Pool -> cartes tenues, dans l'ordre de pioche.
##
## Le type de valeur reste Array nu : GDScript ne sait pas déclarer le paramètre d'un
## type imbriqué dans un Dictionary typé. cards_in() le retype à la sortie, comme
## Assignment.workers_at() le fait déjà.
var _by_pool: Dictionary[StringName, Array] = {}

## Main figée sur cette table. Les tableaux sont recopiés : ce que le Deck garde ensuite
## n'est plus atteignable d'ici.
static func create(cards_by_pool: Dictionary[StringName, Array]) -> Hand:
	var hand := Hand.new()
	for pool in cards_by_pool:
		assert(CardData.is_known_pool(pool), "main tenue dans un pool inconnu : %s" % pool)
		var held: Array[StringName] = []
		held.assign(cards_by_pool[pool])
		hand._by_pool[pool] = held
	return hand

## Main vide. Ce n'est pas une erreur : c'est l'état d'un début de phase, et celui d'une
## phase entièrement jouée.
static func empty() -> Hand:
	var none: Dictionary[StringName, Array] = {}
	return Hand.create(none)

## Nombre de cartes tenues, tous pools confondus.
func size() -> int:
	var held := 0
	for pool in _by_pool:
		held += _by_pool[pool].size()
	return held

## Ne tient-on rien ?
func is_empty() -> bool:
	return size() == 0

## Toutes les cartes tenues, pool par pool dans l'ordre de CardData.POOLS, et dans
## l'ordre de pioche à l'intérieur de chaque pool.
##
## L'ordre est fixé et non arbitraire : une main qui se lirait dans l'ordre d'un
## Dictionary changerait d'affichage au gré de l'ordre d'insertion, et un rapport de
## harnais cesserait d'être comparable d'un soir à l'autre.
func cards() -> Array[StringName]:
	var held: Array[StringName] = []
	for pool in CardData.POOLS:
		held.append_array(cards_in(pool))
	return held

## Cartes tenues dans ce pool, dans l'ordre de pioche. Vide si aucune. Copie.
func cards_in(pool: StringName) -> Array[StringName]:
	var held: Array[StringName] = []
	if _by_pool.has(pool):
		held.assign(_by_pool[pool])
	return held

## Nombre de cartes tenues dans ce pool.
func count_in(pool: StringName) -> int:
	if not _by_pool.has(pool):
		return 0
	return _by_pool[pool].size()

## Tient-on au moins un exemplaire de cette carte ?
##
## Un exemplaire, pas la carte : le deck de départ en contient plusieurs de la même, et
## la main aussi. Qui compte les exemplaires passe par cards_in().
func has(card: StringName) -> bool:
	for pool in _by_pool:
		if _by_pool[pool].has(card):
			return true
	return false
