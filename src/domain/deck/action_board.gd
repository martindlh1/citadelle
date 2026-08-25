class_name ActionBoard
extends RefCounted
## Ce que le joueur a posé dans la phase courante.
##
## État mutable du système Cartes au même titre que le Deck, comme CityState l'est de
## Construction, le Ledger de l'Économie et le Roster des Effectifs. Le Deck tient les
## piles ; le board tient ce qui en est sorti et qui a trouvé une cible.
##
## post() est la SEULE porte d'entrée, et elle valide avant de muter : rien ne peut être
## posé sans être passé par ActionTargeting, exactement comme rien n'entre dans la ville
## sans passer par PlacementValidator. C'est un invariant tenu par la structure, pas une
## consigne qu'un appelant doit respecter.
##
## Ce qu'il ne fait pas, et ce n'est pas un oubli :
##
##   - **il ne défausse pas la carte.** Poser une action et faire tomber la carte dans la
##     défausse sont deux gestes sur deux états, et c'est la phase qui les enchaîne. Un
##     board qui tiendrait le Deck déciderait au passage du sort d'une carte retirée,
##     alors que c'est justement l'OUVERT de DESIGN.md 3.5.
##   - **il ne décide d'aucun moment.** clear() est une capacité, pas une politique :
##     rien ici ne dit qu'une phase se termine ainsi. Même refus que discard_hand() à D1,
##     et pour la même raison — la journée appartient à I1.
##   - **il ne tient pas les ouvriers.** Ils vivent dans Assignment, que les Effectifs
##     produisent. Le board dit ce qu'on peut faire et combien de postes ça ouvre ; qui
##     les tient est une autre question, posée à un autre système.

## Valeur qu'aucune action posée ne porte, reprise d'Assignment pour que les deux
## s'accordent sans que l'une ait à connaître l'autre.
const NO_ACTION := 0

## Identifiant -> action posée. L'ordre d'insertion d'un Dictionary est l'ordre de pose :
## c'est lui qui rend to_plan() déterministe pour un même seed et une même suite
## d'actions, sans avoir à trier quoi que ce soit.
var _actions: Dictionary[int, PlayedAction] = {}

## Prochain identifiant à distribuer.
##
## Il ne recule **jamais**, ni sur withdraw() ni sur clear(). Un identifiant réutilisé
## ferait qu'une affectation oubliée sur une action retirée se rattacherait en silence à
## la suivante — un ouvrier qui se retrouve à bâtir parce qu'on a annulé sa récolte. Le
## compteur monte, et une affectation périmée ne désigne plus rien, ce que le résolveur
## sait traiter.
var _next_id := NO_ACTION + 1

## Pose cette carte sur cette cellule, si le ciblage l'accepte. Rend l'action posée, ou
## null sur un refus, sans rien muter.
##
## La cellule reçue est celle qu'on désigne ; celle qui est enregistrée est la cible
## canonique que le ciblage rend — l'ancre du bâtiment quand l'action s'y joue.
##
## Null plutôt qu'un TargetResult, à l'inverse de CityState.place() : l'appelant a
## presque toujours déjà le verdict sous la main, parce que la surbrillance des cibles le
## calcule à chaque image. Ce qui lui manque au moment du clic, c'est l'identifiant que
## l'action vient de recevoir — sans lui il ne pourrait pas y affecter un ouvrier.
## Le sens ne concerne que les verbes qui déplacent de la terre, et son défaut le rend
## invisible aux autres. Celui qui est enregistré est celui que le ciblage a accepté, et
## non celui qu'on a demandé : c'est la même règle que pour la cible.
func post(card: StringName, target: Vector2i, terrain: TerrainQuery, city: CitySnapshot,
		balance: ActionBalance,
		direction := PlayedAction.DIRECTION_NONE) -> PlayedAction:
	var result := ActionTargeting.validate(card, target, terrain, city, to_plan(), balance,
		direction)
	if not result.is_ok():
		return null
	var action := PlayedAction.create(_next_id, card, result.target(), result.kind(),
		result.capacity(), result.direction())
	_actions[action.id()] = action
	_next_id += 1
	return action

## Retire une action posée. Rend false si le board n'en a aucune sous cet identifiant.
##
## Les ouvriers qui la tenaient ne sont pas libérés ici : l'affectation vit ailleurs, et
## une affectation qui survit à son action est un état que le résolveur sait traiter — il
## la saute, et l'ouvrier compte comme oisif. Le rattraper serait à l'UI d'affectation de
## le faire, pas au board.
func withdraw(id: int) -> bool:
	return _actions.erase(id)

## Vide le board. Une capacité, pas une politique : voir le docstring de la classe.
##
## Les identifiants distribués ne reviennent pas au pot, exprès. Voir _next_id.
func clear() -> void:
	_actions.clear()

## Nombre d'actions posées.
func count() -> int:
	return _actions.size()

## Une action est-elle posée sous cet identifiant ?
func has(id: int) -> bool:
	return _actions.has(id)

## Action posée sous cet identifiant, ou null s'il n'y en a pas.
func at(id: int) -> PlayedAction:
	if not _actions.has(id):
		return null
	return _actions[id]

## Actions posées sur cette cellule, dans l'ordre de pose. Vide si aucune.
##
## Plusieurs sont possibles, et c'est tout l'intérêt d'avoir donné une identité aux
## actions plutôt que de les indexer par leur cible : *Terraformer* et *Récolter* peuvent
## viser la même case nue, *Récolter* et *Chasser* la même forêt. Rien ne l'interdit, et
## si un jour quelque chose doit l'interdire, ce sera une règle écrite dans
## ActionTargeting — pas une impossibilité de représentation.
##
## Un filtre plutôt qu'un second index : une phase pose une poignée d'actions, et seul le
## rendu appelle cette fonction. Un index à tenir cohérent coûterait plus qu'il ne
## rapporte, exactement comme CardCatalogue.ids_in().
func at_cell(cell: Vector2i) -> Array[PlayedAction]:
	var found: Array[PlayedAction] = []
	for id in _actions:
		var action: PlayedAction = _actions[id]
		if action.target() == cell:
			found.append(action)
	return found

## Vue figée de ce qui est posé, pour les systèmes qui la consomment sans la connaître.
##
## Le miroir de Deck.hand() et de CityState.to_snapshot() : l'Économie lit un ActionPlan
## et n'a jamais accès à cet objet-ci. C'est la seule sortie du board vers ses
## consommateurs.
func to_plan() -> ActionPlan:
	var posted: Array[PlayedAction] = []
	for id in _actions:
		posted.append(_actions[id])
	return ActionPlan.create(posted)
