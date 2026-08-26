class_name ActionTargeting
extends RefCounted
## Où une carte d'action peut se jouer, et combien d'ouvriers elle y accepte.
##
## C'est ici qu'atterrit la **jouabilité** que D1 avait explicitement laissée dehors.
## DESIGN.md 3.5 pose qu'un jeu de carte est une *intention* que le système concerné
## accepte ou refuse ; le Deck ne connaît ni la grille, ni la ville, ni le placement,
## donc il ne pouvait pas répondre. Cette classe le peut, parce qu'on lui passe les deux.
##
## C'est aussi le **seul** endroit du projet où la nature d'un verbe est écrite. DESIGN.md
## 4.2 : « les sept verbes se résolvent chacun autrement, donc une *nature* d'action est
## du code de src/domain/ ». Les quatre constantes ci-dessous sont donc légitimes, et
## elles sont la seule liste de noms de cartes du domaine — le résolveur d'Économie n'en
## a aucune, il lit ce que la data lui dit.
##
## Fonction pure au sens du domaine : tout lui est fourni, elle ne mute rien, elle ne lit
## ni GameDatabase ni le moindre Node. Le fantôme de cibles l'interroge à chaque image,
## exactement comme celui de C2 interroge PlacementValidator, et pour le même prix — une
## poignée de lectures.
##
## Ce qu'elle ne juge **pas** : le coût. « Ai-je les 15 bois ? » ne regarde pas la carte,
## et DESIGN.md 3.2 pose que c'est la couche qui orchestre la journée qui enchaîne les
## deux questions. Une carte de bâtiment n'est d'ailleurs pas de son ressort du tout —
## elle se pose, elle ne s'affecte pas — et se voit refusée sous REASON_UNKNOWN_CARD.

## Les quatre actions marquées MVP en DESIGN.md 4.2, et les seules que data/cards/
## contienne. S'entraîner, Fabriquer et Explorer arrivent avec X3, X2 et X1.
const CARD_HARVEST := &"harvest"
const CARD_HUNT := &"hunt"
const CARD_BUILD := &"build"
const CARD_TERRAFORM := &"terraform"

## Les verbes que ce fichier sait cibler, dans l'ordre du tableau de 4.2.
##
## L'ensemble est fermé, comme CardData.POOLS : ajouter une **carte de bâtiment** reste
## une édition de data/, ajouter un **verbe** est une modification de code. Un cas de
## test confronte cette liste au catalogue réel, de sorte qu'une cinquième action entrée
## dans data/cards/ sans règle de ciblage fasse tomber la suite au lieu de se poser
## nulle part.
const CARDS: Array[StringName] = [CARD_HARVEST, CARD_HUNT, CARD_BUILD, CARD_TERRAFORM]

## Ce fichier sait-il cibler cette carte ?
static func handles(card: StringName) -> bool:
	return CARDS.has(card)

## Cette carte peut-elle se jouer sur cette cellule ? Oui avec la cible canonique, la
## nature et la capacité ; non avec la raison.
##
## La cellule reçue est celle qu'on désigne, pas forcément celle qu'on vise : sur un
## bâtiment, le résultat rend son **ancre**, retrouvée depuis n'importe quelle cellule de
## l'empreinte. C'est le chemin d'un clic, et le faire ici évite que deux clics sur la
## même ferme posent deux actions qui se croient différentes.
## `direction` n'est lu que par les verbes qui déplacent de la terre, et son défaut le
## rend invisible aux trois autres. C'est le sens que `I1` a rendu obligatoire pour
## *Terraformer* : `DESIGN.md` 4.2 lui en donne deux, `data/cards/` n'en porte qu'une
## carte, donc le sens est un choix fait à la pose — au même titre que l'orientation d'un
## bâtiment appartient au placement et non à sa `BuildingData`.
static func validate(card: StringName, target: Vector2i, terrain: TerrainQuery,
		city: CitySnapshot, plan: ActionPlan, balance: ActionBalance,
		direction := PlayedAction.DIRECTION_NONE) -> TargetResult:
	assert(terrain != null, "ciblage sans terrain")
	assert(city != null, "ciblage sans ville")
	assert(plan != null, "ciblage sans plan d'actions")
	assert(balance != null, "ciblage sans équilibrage")
	assert(PlayedAction.is_known_direction(direction),
		"ciblage sur un sens inconnu : %d" % direction)
	if not handles(card):
		return TargetResult.refused(TargetResult.REASON_UNKNOWN_CARD)
	if not terrain.in_bounds(target):
		return TargetResult.refused(TargetResult.REASON_OUT_OF_BOUNDS)
	var verdict := _place_of(card, target, terrain, city, balance, direction)
	if not verdict.is_ok():
		return verdict
	if _already_posted(verdict.target(), plan):
		return TargetResult.refused(TargetResult.REASON_ALREADY_POSTED)
	return verdict

## Où ce verbe se joue, avant de regarder ce qui est déjà posé.
static func _place_of(card: StringName, target: Vector2i, terrain: TerrainQuery,
		city: CitySnapshot, balance: ActionBalance, direction: int) -> TargetResult:
	match card:
		CARD_HARVEST:
			return _harvest(target, terrain, city, balance)
		CARD_HUNT:
			return _hunt(target, terrain, city, balance)
		CARD_BUILD:
			return _build(target, city)
		CARD_TERRAFORM:
			return _terraform(target, terrain, city, balance, direction)
	return TargetResult.refused(TargetResult.REASON_UNKNOWN_CARD)

## Quelque chose est-il déjà posé sur cette cible ?
##
## La comparaison se fait sur la cible **canonique**, celle que le verbe vient de rendre,
## et non sur la cellule désignée : deux clics sur deux coins d'une même ferme sont deux
## fois la même pose, et les laisser passer rouvrirait ses postes.
##
## **Une cible ne porte qu'une action, quelle qu'elle soit.** *(Renversé après `I2`.)* La
## règle ne portait jusqu'ici que sur la carte, et `DESIGN.md` 3.5 l'écrivait noir sur
## blanc : « deux cartes *différentes* sur une même cellule restent acceptées ; c'est le
## doublon qui est refusé, pas le partage ». C'était le cas pour lequel `D2` avait donné
## une identité aux actions — *Récolter* et *Chasser* sur une même forêt, « deux métiers
## sur une même terre ».
##
## Une partie jouée à la main a montré que le partage ne tient pas **à l'écran**. Deux
## actions sur une case donnent une case qu'on désigne d'un seul curseur : Espace, le clic
## droit et le survol ne peuvent en atteindre qu'une, et l'autre n'existe plus que dans une
## liste de panneau bornée à trois lignes. Le domaine autorisait un geste que rien ne
## pouvait viser.
##
## Le retour en arrière est donc **provisoire et assumé** : c'est la contrainte la moins
## chère qui rend la carte lisible, et elle se lève le jour où un écran sait désigner l'une
## des deux. Ce que 3.5 protégeait — que deux verbes puissent vivre sur la même terre —
## reste vrai d'une journée à l'autre, pas dans la même phase.
##
## Elle rend au passage inutile la limite que ce docstring signalait : le partage d'un
## bâtiment entre deux cartes à postes, que *Fabriquer* aurait ouvert, ne se pose plus.
static func _already_posted(target: Vector2i, plan: ActionPlan) -> bool:
	for action in plan.actions():
		if action.target() == target:
			return true
	return false

## *Récolter* : dans un poste de production, ou à cru sur une case au bon tag.
##
## Les deux lectures de DESIGN.md 3.5, et le bâtiment l'emporte quand il y en a un — on
## ne récolte pas à cru le sol sur lequel une ferme est posée.
##
## Aucune vérification de famille sur le poste : les quatre bâtiments qui produisent
## emploient tous la Récolte, et le premier qui emploiera l'Artisanat viendra avec
## *Fabriquer*, donc avec sa propre règle de ciblage. Exiger une famille aujourd'hui
## serait deviner laquelle X2 choisira.
static func _harvest(target: Vector2i, terrain: TerrainQuery, city: CitySnapshot,
		balance: ActionBalance) -> TargetResult:
	var building := city.at_cell(target)
	if building == null:
		return _bare(CARD_HARVEST, target, terrain, balance)
	if not building.is_complete():
		return TargetResult.refused(TargetResult.REASON_UNFINISHED)
	if not building.data().produces():
		return TargetResult.refused(TargetResult.REASON_NO_PRODUCTION)
	return TargetResult.accepted(PlayedAction.Kind.BUILDING, building.anchor(),
		building.data().production.slots)

## *Chasser* : à cru uniquement.
##
## DESIGN.md 4.2 lui laisse la colonne « En slot » vide — « pas de bâtiment de chasse
## pour l'instant ». Ce n'est donc pas une case oubliée mais un verbe sans version en
## bâtiment, et le jour où un pavillon de chasse existera, il entrera ici.
static func _hunt(target: Vector2i, terrain: TerrainQuery, city: CitySnapshot,
		balance: ActionBalance) -> TargetResult:
	if city.at_cell(target) != null:
		return TargetResult.refused(TargetResult.REASON_OCCUPIED)
	return _bare(CARD_HUNT, target, terrain, balance)

## *Construire* : sur un chantier inachevé, et nulle part ailleurs.
##
## La capacité est ce qu'il **reste** à poser et non ce que le bâtiment réclame : une
## ferme à 1/2 n'accepte qu'un ouvrier, parce que le second n'aurait plus rien à bâtir.
## C'est le pendant exact des slots d'un poste de production — la carte ouvre le
## chantier, les ouvriers disent de combien il avance.
static func _build(target: Vector2i, city: CitySnapshot) -> TargetResult:
	var building := city.at_cell(target)
	if building == null:
		return TargetResult.refused(TargetResult.REASON_NO_BUILDING)
	if building.is_complete():
		return TargetResult.refused(TargetResult.REASON_ALREADY_BUILT)
	return TargetResult.accepted(PlayedAction.Kind.BUILDING, building.anchor(),
		building.remaining())

## *Terraformer* : sur une case **constructible** que rien n'occupe, dans un sens choisi,
## et tant que ce sens ne sort pas des bornes de relief.
##
## Les trois refus sont trois questions ouvertes que `I1` referme, et l'ordre dans lequel
## ils tombent est celui de ce qui se voit le mieux à l'écran : un bâtiment d'abord, le
## sol ensuite, puis ce que le joueur tient.
##
## **Le terrain.** `DESIGN.md` 3.5 demandait « l'eau et le rocher se terrassent-ils ? ».
## Non, et la raison est mécanique plutôt que thématique : terrasser déplace la hauteur et
## non le `TerrainData`, donc monter une case d'eau la laisserait eau — inconstructible,
## toujours tagguée `water` — pour le prix d'une carte et d'un ouvrier. Le jour où un
## verbe voudra changer le sol lui-même, ce sera un *Défricher*, pas celui-ci.
##
## **Le sens.** Il n'a pas de valeur par défaut jouable : un terrassement sans sens choisi
## se refuse, ce qui est un état d'écran normal et non une faute d'appelant.
##
## **Les bornes.** Elles sont lues sur la hauteur **d'arrivée**, pas de départ : une case
## au plancher se monte encore, elle ne se descend plus.
static func _terraform(target: Vector2i, terrain: TerrainQuery, city: CitySnapshot,
		balance: ActionBalance, direction: int) -> TargetResult:
	if city.at_cell(target) != null:
		return TargetResult.refused(TargetResult.REASON_OCCUPIED)
	if not terrain.is_buildable(target):
		return TargetResult.refused(TargetResult.REASON_NOT_BUILDABLE)
	if direction == PlayedAction.DIRECTION_NONE:
		return TargetResult.refused(TargetResult.REASON_NO_DIRECTION)
	if not balance.in_terraform_range(terrain.height_at(target) + direction):
		return TargetResult.refused(TargetResult.REASON_HEIGHT_LIMIT)
	return TargetResult.accepted(PlayedAction.Kind.BARE, target, balance.bare_capacity,
		direction)

## Un verbe joué à cru : accepté si la cellule porte l'un des tags que sa table nomme.
##
## DESIGN.md 3.1 : « c'est eux qui décident où une action à cru peut se jouer ». La table
## consultée est celle-là même dont le résolveur tirera la ressource, et c'est ce qui
## garantit qu'une cible acceptée rendra vraiment quelque chose.
static func _bare(card: StringName, target: Vector2i, terrain: TerrainQuery,
		balance: ActionBalance) -> TargetResult:
	for tag in balance.sources_for(card):
		if terrain.has_tag(target, tag):
			return TargetResult.accepted(PlayedAction.Kind.BARE, target,
				balance.bare_capacity)
	return TargetResult.refused(TargetResult.REASON_WRONG_TAG)
