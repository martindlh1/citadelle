class_name CardCatalogue
extends RefCounted
## Ce qui existe comme carte, indexé par identifiant.
##
## Il dit ce qu'une carte **est** — son pool, son libellé, le bâtiment qu'elle pose —,
## jamais qui la possède. Le Deck s'en sert pour savoir dans quelle pile ranger un
## identifiant, le draft pour savoir quoi proposer.
##
## C'est ce que GameDatabase fait pour les adapters, mais du côté du domaine et sans
## singleton : on le passe en argument, comme un TerrainQuery ou une BuildingData. Le
## domaine ne lit jamais l'index.
##
## Immuable une fois créé.

## Cartes, dans l'ordre où le catalogue les a reçues.
var _ids: Array[StringName] = []

## Identifiant -> carte.
var _by_id: Dictionary[StringName, CardData] = {}

## Catalogue de ces cartes, dans cet ordre.
##
## L'ordre est conservé et il compte : c'est lui que les offres de draft mélangent, donc
## deux catalogues chargés dans un ordre différent tireraient différemment sur le même
## seed. GameDatabase.list_card_ids() trie, ce qui donne au chargement un ordre stable
## d'une session à l'autre.
static func create(cards: Array[CardData]) -> CardCatalogue:
	var catalogue := CardCatalogue.new()
	for card in cards:
		assert(card != null, "carte nulle au catalogue")
		assert(not card.id.is_empty(), "carte sans identifiant au catalogue")
		assert(not catalogue._by_id.has(card.id),
			"deux cartes portent l'identifiant %s" % card.id)
		catalogue._ids.append(card.id)
		catalogue._by_id[card.id] = card
	return catalogue

## Catalogue vide. Aucune carte n'existe, donc aucun deck ne peut se composer.
static func empty() -> CardCatalogue:
	var none: Array[CardData] = []
	return CardCatalogue.create(none)

## Nombre de cartes connues.
func size() -> int:
	return _ids.size()

## Cette carte existe-t-elle ?
func has(id: StringName) -> bool:
	return _by_id.has(id)

## Carte nommée. Précondition : has(id).
func card(id: StringName) -> CardData:
	assert(has(id), "carte inconnue du catalogue : %s" % id)
	return _by_id[id]

## Pool de cette carte. Précondition : has(id).
##
## Raccourci sur card(id).pool, parce que c'est la seule question que le Deck pose au
## catalogue et qu'il la pose à chaque carte qu'il range.
func pool_of(id: StringName) -> StringName:
	return card(id).pool

## Toutes les cartes, dans l'ordre de création. Copie.
func ids() -> Array[StringName]:
	return _ids.duplicate()

## Les cartes de ce pool, dans l'ordre de création.
##
## Un filtre plutôt qu'un second index : le catalogue tient une vingtaine d'entrées et
## seul le draft appelle cette fonction, une fois par offre. Un index à tenir cohérent
## coûterait plus qu'il ne rapporte.
func ids_in(pool: StringName) -> Array[StringName]:
	assert(CardData.is_known_pool(pool), "pool inconnu : %s" % pool)
	var found: Array[StringName] = []
	for id in _ids:
		if _by_id[id].pool == pool:
			found.append(id)
	return found
