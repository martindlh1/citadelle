class_name DraftPool
extends RefCounted
## Ce qu'un draft met sur la table : des cartes distinctes d'un même pool, tirées sur le
## rng du run.
##
## Fonction pure, comme TerrainGen. Elle ne touche à aucun deck et ne décide de rien :
## choisir dans l'offre, puis l'appliquer — Deck.add(), Deck.remove() —, appartient à
## l'appelant. C'est la même séparation que partout ailleurs dans le domaine, où une
## fonction rend un résultat et laisse l'appelant en faire quelque chose.
##
## Les pools se draftent **séparément** : une offre ne mêle jamais une action et un
## bâtiment. C'est la conséquence directe des trois pools de DESIGN.md 3.5, et c'est
## pourquoi le pool est un argument obligatoire et non une option.
##
## Des deux autres récompenses que 3.5 prévoit — retirer une carte définitivement, une
## récompense alternative —, la première est déjà jouable en offrant les cartes du deck
## et en appelant Deck.remove(). La seconde est un choix d'écran, elle viendra avec lui.

## Jusqu'à `count` cartes distinctes de ce pool, hors de `excluded`.
##
## Rend moins que demandé si le catalogue n'a pas de quoi remplir l'offre, jusqu'à rien.
## Un pool épuisé n'est pas une erreur : celui des powers est vide jusqu'à X4, et un
## draft de fin de run peut très bien avoir tout proposé.
##
## Les cartes sont distinctes parce qu'une offre où le même bâtiment apparaîtrait deux
## fois ne serait pas un choix. Rien n'empêche en revanche d'offrir une carte que le
## deck possède déjà — en prendre un second exemplaire est une décision de draft
## parfaitement sensée. Qui n'en veut pas la passe dans `excluded`.
static func offer(catalogue: CardCatalogue, pool: StringName, count: int,
		rng: RandomNumberGenerator,
		excluded: Array[StringName] = []) -> Array[StringName]:
	assert(catalogue != null, "offre de draft sans catalogue")
	assert(CardData.is_known_pool(pool), "offre de draft dans un pool inconnu : %s" % pool)
	assert(count >= 0, "offre de draft d'un nombre négatif de cartes : %d" % count)
	var eligible: Array[StringName] = []
	for id in catalogue.ids_in(pool):
		if not excluded.has(id):
			eligible.append(id)
	var mixed := CardShuffle.shuffled(eligible, rng)
	return mixed.slice(0, mini(count, mixed.size()))
