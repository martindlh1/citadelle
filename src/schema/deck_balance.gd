class_name DeckBalance
extends Resource
## Réglages du deck : ce qu'on commence avec, ce qu'on tient en main, ce qu'un draft
## met sur la table.
##
## DESIGN.md 3.5 garde sous un OUVERT la taille de la main et du deck, et le sort des
## cartes non jouées — « la question se pose désormais par pool, ce qui la complique :
## trois pioches, trois défausses, trois tailles de main ». Elle se règle donc ici et
## nulle part ailleurs, ce qui est exactement la raison d'être de data/balance/ : un
## playtest qui bouge ces chiffres ne touche pas à du GDScript.
##
## Ce que ce fichier ne décide **pas**, et c'est volontaire : le *moment* où l'on pioche
## et où l'on défausse. Le Deck offre les gestes, la journée choisit quand les faire —
## donc I1. C'est ce qui laisse l'OUVERT entier au lieu de le trancher par accident.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Ce que le deck contient à l'ouverture d'un run : carte -> exemplaires.
##
## Les clés sont des identifiants de data/cards/. Ce fichier ne peut pas les contrôler
## seul — une Resource de schéma ne lit jamais l'index —, c'est GameDatabase qui les
## confronte au catalogue au démarrage.
##
## « Deck de départ fixe » (DESIGN.md 3.5) : il n'y en a qu'un. Les gouverneurs de la
## méta-progression en voudront plusieurs, et ce jour-là c'est une catégorie data/decks/
## qui les portera — pas un second champ ici.
@export var starting_deck: Dictionary[StringName, int]

## Cartes piochées par phase, pool par pool.
##
## Les trois pools sont **réclamés**, celui des powers compris, dont la valeur est 0
## tant que X4 ne l'a pas rempli. C'est la présence de la clé qui vaut déclaration : un
## pool omis serait un pool qu'on ne pioche jamais sans que rien ne le dise, alors qu'un
## zéro écrit dit « on n'en pioche pas », ce qui est une réponse. La doctrine du zéro
## garde ainsi sa prise là où trois champs plats l'auraient perdue — c'est le même geste
## que le bloc nullable de E1b, appliqué à une table.
##
## Au moins un pool doit se piocher, sinon la phase ne distribue rien du tout.
@export var hand_size: Dictionary[StringName, int]

## Cartes non jouées qui survivent à une phase qui résout, pool par pool.
##
## C'est le bouton de l'`OUVERT` de `DESIGN.md` 3.5 — « que fait-on d'une main qu'on ne
## peut pas jouer » — et il est ici plutôt qu'en dur dans l'orchestrateur pour la raison
## que le docstring de ce fichier annonce depuis `D1` : la question se règle en data, et
## `I2b` la tourne sans toucher à du GDScript.
##
## Deux valeurs par pool, et deux seulement :
##
##   - **zéro** défausse tout, ce que la boucle fait depuis `I1`. C'est la lecture qui
##     « crée de la tension et empêche la thésaurisation ».
##   - **`hand_size` du même pool** garde tout, et la pioche **complète** au lieu de tirer
##     une main neuve. C'est la « main persistante » de 3.5, et elle se paie toute seule :
##     garder une carte, c'est une carte de moins piochée. La « limite de jeu par tour »
##     que 3.5 lui adjoignait devient inutile.
##
## **Le milieu est refusé**, et c'est un refus structurel plutôt qu'un manque. Garder deux
## cartes sur cinq demande de dire *lesquelles*, et la seule règle qui ne choisisse pas à
## la place du joueur est qu'il choisisse — donc un geste de fin de phase, donc un écran
## qui n'existe pas. Un report intermédiaire résolu par une règle d'ancienneté aurait
## répondu à l'`OUVERT` par un arbitraire, ce qui est exactement ce que `P1b` a refusé au
## recensement des piles. Le jour où le geste existe, c'est ce contrôle-ci qui se desserre
## et rien d'autre.
##
## Un entier plutôt qu'un booléen : `hand_size` diffère d'un pool à l'autre, donc « tout
## garder » n'est pas le même nombre partout, et l'écrire permet au contrôle de croiser
## les deux champs. Un booléen n'aurait rien à croiser.
@export var carry_over: Dictionary[StringName, int]

## Cartes qu'un draft met sur la table, parmi lesquelles on en prend une.
##
## DESIGN.md 3.5 prévoit aussi d'en retirer une définitivement et une récompense
## alternative : ce sont des choix de contenu et d'UI, ils n'ont pas de chiffre ici tant
## que l'écran de draft n'existe pas.
@export_range(0, 10, 1) var draft_choices: int

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if draft_choices <= 0:
		missing.append("draft_choices")
	missing.append_array(_starting_deck_fields())
	missing.append_array(_hand_size_fields())
	missing.append_array(_carry_over_fields())
	return missing

## Incohérences du deck de départ.
##
## Un exemplaire à zéro n'est pas une carte absente du deck, c'est une ligne qui ne veut
## rien dire : on l'omet. L'écrire est une faute de contenu, exactement comme un
## rendement à zéro dans un ProductionBlock.
func _starting_deck_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if starting_deck.is_empty():
		missing.append("starting_deck")
		return missing
	for card in starting_deck:
		if starting_deck[card] <= 0:
			missing.append("starting_deck.%s" % card)
	return missing

## Incohérences des tailles de main : les trois pools présents, aucun négatif, aucun
## pool inconnu, et au moins une carte piochée quelque part.
func _hand_size_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	var drawn := 0
	for pool in CardData.POOLS:
		if not hand_size.has(pool):
			missing.append("hand_size.%s" % pool)
			continue
		var size: int = hand_size[pool]
		if size < 0:
			missing.append("hand_size.%s" % pool)
			continue
		drawn += size
	for pool in hand_size:
		if not CardData.is_known_pool(pool):
			missing.append("hand_size.%s.unknown" % pool)
	if missing.is_empty() and drawn <= 0:
		missing.append("hand_size.all_zero")
	return missing

## Incohérences du report de main : les trois pools présents, aucun négatif, aucun pool
## inconnu, et **rien entre les deux valeurs jouables**.
##
## Les trois pools sont réclamés par le même argument que `hand_size` : la présence de la
## clé vaut déclaration, et un zéro écrit dit « ce pool défausse tout », ce qui est une
## réponse là où une clé absente ne serait qu'un oubli.
##
## Le contrôle du milieu croise `hand_size`, donc il ne peut pas vivre sur un champ isolé
## — c'est le même partage qu'entre `PhaseDef` et `RunBalance`, où seul le bloc qui voit
## la liste entière peut juger d'une phase. Il se tait quand le `hand_size` du pool est
## lui-même en défaut : deux fois le même défaut sous deux noms différents ferait chercher
## deux fois.
func _carry_over_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	for pool in CardData.POOLS:
		if not carry_over.has(pool):
			missing.append("carry_over.%s" % pool)
			continue
		var kept: int = carry_over[pool]
		if kept < 0:
			missing.append("carry_over.%s" % pool)
			continue
		if not hand_size.has(pool):
			continue
		var drawn: int = hand_size[pool]
		if drawn < 0:
			continue
		if kept > drawn:
			missing.append("carry_over.%s.above_the_hand" % pool)
		elif kept > 0 and kept < drawn:
			missing.append("carry_over.%s.partial" % pool)
	for pool in carry_over:
		if not CardData.is_known_pool(pool):
			missing.append("carry_over.%s.unknown" % pool)
	return missing
