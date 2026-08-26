class_name CardData
extends Resource
## Une carte : son identité, le pool où elle vit, et le bâtiment qu'elle pose s'il y a
## lieu.
##
## Les .tres vivent dans data/cards/, un par carte. Le domaine les reçoit en argument et
## ne lit jamais GameDatabase, comme pour BuildingData et TerrainData.
##
## D1 n'y met que ce que le flux du deck consomme : de quoi piocher, tenir, défausser et
## drafter. Ce qu'une action **fait** — la ressource qu'elle rend à cru, le tag qu'elle
## exige, le chantier qu'elle avance — n'y est pas, et c'est délibéré : les sept verbes
## de DESIGN.md 4.2 se résolvent chacun autrement, donc la **nature** d'une action est du
## code de src/domain/ et non un champ de plus ici. C'est la règle de DESIGN.md 3.3,
## celle qui a déjà tenu ProductionBlock hors du résolveur — une Resource qui porterait
## une méthode de résolution serait du domaine déguisé.
##
## Le catalogue de D1 ne contient que les quatre actions marquées **MVP** en 4.2.
## S'entraîner, Fabriquer et Explorer arrivent avec X3, X2 et X1 : ce sont les trois
## seules que la colonne « Débloque » concerne, et c'est pourquoi cette colonne n'est
## pas encore dans data/. Un champ arrive avec le système qui le lit, et rien ne lit un
## déblocage tant qu'aucune carte n'est verrouillée.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Les trois pools de DESIGN.md 3.5. Ils se piochent, se défaussent et se draftent
## séparément.
##
## Un StringName plutôt qu'un enum, contre la convention générale — « enum plutôt que
## String pour les états » —, et pour une raison qui l'emporte ici : un enum non
## renseigné vaut 0, donc &"action" en silence, et la doctrine du zéro perdrait sa prise
## sur le seul champ qui décide de tout le classement d'une carte. Un &"" se détecte.
## Un pool est d'ailleurs un identifiant écrit dans data/, où la convention du projet est
## déjà le StringName — &"wood", &"harvest" —, et non un état en mémoire.
const POOL_ACTION := &"action"
const POOL_BUILDING := &"building"
const POOL_POWER := &"power"

## Les pools connus, dans l'ordre où on les présente.
##
## L'ensemble est fermé, et c'est la même frontière que partout ailleurs dans le
## projet : ajouter une **carte** est une édition de data/, ajouter un **pool** est une
## modification de code. Le pool des powers est vide jusqu'à X4 et existe quand même,
## pour que rien dans le Deck ne suppose qu'il n'y a que deux natures de cartes.
const POOLS: Array[StringName] = [POOL_ACTION, POOL_BUILDING, POOL_POWER]

## Identifiant stable, repris par le deck, la main et le draft.
## Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Libellé affichable. La main de D2 le lira, et le harnais l'imprime déjà ; rien dans
## le domaine ne le regarde.
@export var label: String

## Pool auquel elle appartient. L'une des trois constantes ci-dessus.
@export var pool: StringName

## Bâtiment qu'elle pose, pour une carte de bâtiment seulement.
##
## Vide sur toute autre carte, et missing_fields() le réclame **dans les deux sens** :
## une carte de bâtiment sans bâtiment n'aurait rien à poser, et une carte d'action qui
## en nommerait un ferait croire à un lien que rien ne suivra. C'est GameDatabase qui
## confronte ensuite l'identifiant au catalogue de data/buildings/, comme il le fait
## déjà des ressources nommées dans un coût — une Resource de schéma ne lit jamais
## l'index.
##
## Le champ existe alors qu'il recopie aujourd'hui l'identifiant de la carte, et c'est
## voulu : rien n'oblige une carte à porter le nom du bâtiment qu'elle pose, et deux
## cartes qui poseraient la même ferme à des conditions différentes sont exactement ce
## qu'un draft de méta-progression fera un jour. Le Cœur, lui, n'a pas de carte — il est
## posé au départ, DESIGN.md 4.1.
@export var building: StringName

## Ce pool est-il l'un des trois ?
##
## Statique et publique : DeckBalance s'en sert pour refuser une taille de main qui
## nommerait un pool inexistant, et le domaine pour vérifier ce qu'on lui passe.
static func is_known_pool(name: StringName) -> bool:
	return POOLS.has(name)

## Cette carte pose-t-elle un bâtiment ?
##
## Une méthode plutôt qu'un `pool == POOL_BUILDING` recopié partout, du même motif que
## BuildingData.produces() : le jour où le classement se lit autrement, la question
## reste posée au même endroit.
func places_a_building() -> bool:
	return pool == POOL_BUILDING

## Champs non renseignés ou incohérents. Vide = carte exploitable.
## Vérifié au boot par GameDatabase, comme les terrains, les bâtiments et les ressources.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if pool.is_empty():
		missing.append("pool")
	elif not is_known_pool(pool):
		missing.append("pool.unknown")
	if places_a_building() and building.is_empty():
		missing.append("building")
	if not places_a_building() and not building.is_empty():
		missing.append("building.unexpected")
	return missing
