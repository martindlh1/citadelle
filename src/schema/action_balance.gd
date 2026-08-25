class_name ActionBalance
extends Resource
## Réglages des actions jouées à cru : ce qu'une case nue accepte, ce qu'elle rend, et
## quels tags de terrain autorisent quel verbe.
##
## `DESIGN.md` 3.5 pose la règle qui donne aux bâtiments leur raison d'être sans les
## rendre obligatoires : une action jouée **à cru**, sur une case nue dont le tag
## l'autorise, rend peu ; la même jouée **dans un slot de bâtiment** rend bien davantage.
## Le versant « en slot » est déjà en data depuis E1b, sur le `ProductionBlock` de chaque
## bâtiment. Ce fichier est le versant « à cru », qui n'avait jusqu'ici nulle part où
## vivre.
##
## Et 3.1 : « Les tags de terrain cessent d'être décoratifs avec les actions : c'est eux
## qui décident où une action à cru peut se jouer. » `bare_sources` est cette phrase mise
## en data — elle sert **deux fois**, au ciblage pour dire où la carte peut se poser, et
## à la résolution pour dire ce qu'elle rend. Une seule table pour les deux, sinon les
## deux divergeraient et l'écran promettrait une récolte que le soir ne verserait pas.
##
## Ce que ce fichier ne contient **pas** : la liste des verbes. Une nature d'action est
## du code de `src/domain/`, `DESIGN.md` 4.2 le pose et ce jalon s'y tient. Ce que
## `bare_sources` nomme, ce sont les cartes qui se jouent à cru — un sous-ensemble, pas
## un catalogue —, et c'est ce qui permet au résolveur d'ignorer *Construire* et
## *Terraformer* sans avoir à les nommer.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Ouvriers qu'une action jouée à cru accepte sur une case nue.
##
## Un seul chiffre pour tous les verbes à cru, et non un par nature : `DESIGN.md` 4.2
## leur donne à tous le même « +1 », et une case nue n'a pas de postes à distinguer. Le
## jour où un verbe à cru voudra sa propre capacité, `bare_sources` a déjà la forme qui
## l'accueille — une table par carte.
@export_range(0, 8, 1) var bare_capacity: int

## Ce qu'un ouvrier tire d'une case nue en un soir, avant son multiplicateur.
##
## C'est le « rend peu » de 3.5, et le « +1 » de 4.2. Le rendement en slot, lui, vit sur
## le bâtiment : c'est l'écart entre les deux qui fait qu'on construit.
@export_range(0, 10, 1) var bare_yield: int

## Famille de compétence qu'une action à cru emploie.
##
## Elle décide du multiplicateur appliqué et de la piste que l'XP créditera en retour,
## exactement comme `ProductionBlock.skill_family` le fait pour un poste de bâtiment.
@export var bare_skill_family: StringName

## Carte -> (tag de terrain -> ressource qu'elle en tire à cru).
##
## Une carte absente de cette table ne se joue pas à cru : c'est le cas de *Construire*,
## qui vise un chantier, et de *Terraformer*, qui ne rend rien. C'est cette absence, et
## non un test sur leur nom, qui les fait ignorer par le résolveur.
##
## Le type de valeur reste `Dictionary` nu : GDScript ne sait pas déclarer le paramètre
## d'un type imbriqué dans un `Dictionary` typé. `sources_for()` le retype à la sortie,
## comme `Assignment.workers_on()` et `Hand.cards_in()` le font déjà.
##
## L'ordre des tags à l'intérieur d'une table compte : une cellule qui en porterait deux
## rendrait la ressource du premier trouvé. L'ordre d'insertion d'un `Dictionary` est
## stable, donc celui du .tres fait foi et deux runs partis du même seed ne divergent
## pas.
##
## Les identifiants de ressource ne sont pas contrôlés ici — une Resource de schéma ne
## lit jamais l'index. C'est `GameDatabase` qui les confronte au catalogue au démarrage.
@export var bare_sources: Dictionary[StringName, Dictionary]

## Cartes qui tiennent un **poste de production** quand elles sont jouées dans un
## bâtiment.
##
## Le pendant exact de `bare_sources` pour l'autre lecture de DESIGN.md 3.5, et il existe
## pour la même raison : que le résolveur sache ce qu'une action rapporte sans jamais
## nommer une carte. Sans lui, il ne lui resterait qu'une question — « ce bâtiment
## produit-il ? » —, et **toute** action posée sur une ferme achevée en tirerait une
## récolte, *Construire* comprise. Le ciblage l'interdit aujourd'hui en refusant
## *Construire* sur un bâtiment fini, mais faire reposer la justesse du soir sur une
## règle écrite dans un autre fichier est exactement le genre de dette qui se paie le
## jour où I1 avancera les chantiers pendant la résolution.
##
## Une carte absente ne tient aucun poste : c'est le cas de *Construire*, qui avance un
## chantier, et de *Terraformer*, qui ne se joue pas dans un bâtiment du tout.
@export var slot_cards: Array[StringName]

## Cette carte tient-elle un poste de production dans un bâtiment ?
func works_a_slot(card: StringName) -> bool:
	return slot_cards.has(card)

## Cette carte se joue-t-elle à cru ?
##
## Une méthode plutôt qu'un `bare_sources.has(card)` recopié, du même motif que
## `BuildingData.produces()` : le ciblage et le résolveur posent tous les deux cette
## question, et le jour où elle se lit autrement, elle reste posée au même endroit.
func is_bare_card(card: StringName) -> bool:
	return bare_sources.has(card)

## Table tag -> ressource de cette carte à cru. Vide si elle ne s'y joue pas. Copie.
func sources_for(card: StringName) -> Dictionary[StringName, StringName]:
	var sources: Dictionary[StringName, StringName] = {}
	if not bare_sources.has(card):
		return sources
	var table: Dictionary = bare_sources[card]
	for tag: StringName in table:
		var resource: StringName = table[tag]
		sources[tag] = resource
	return sources

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if bare_capacity <= 0:
		missing.append("bare_capacity")
	if bare_yield <= 0:
		missing.append("bare_yield")
	if bare_skill_family.is_empty():
		missing.append("bare_skill_family")
	if slot_cards.is_empty():
		missing.append("slot_cards")
	for card in slot_cards:
		if card.is_empty():
			missing.append("slot_cards.blank")
	missing.append_array(_source_fields())
	return missing

## Incohérences des tables de sources.
##
## Une carte à cru sans aucun tag ne pourrait se poser nulle part : ce n'est pas « elle
## ne se joue pas à cru », qui s'écrit en l'omettant, c'est une ligne qui ne veut rien
## dire. Même geste que `DeckBalance` sur un exemplaire à zéro.
func _source_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if bare_sources.is_empty():
		missing.append("bare_sources")
		return missing
	for card: StringName in bare_sources:
		var table: Dictionary = bare_sources[card]
		if table.is_empty():
			missing.append("bare_sources.%s" % card)
			continue
		for tag: StringName in table:
			var resource: StringName = table[tag]
			if tag.is_empty() or resource.is_empty():
				missing.append("bare_sources.%s.%s" % [card, tag])
	return missing
