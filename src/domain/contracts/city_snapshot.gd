class_name CitySnapshot
extends RefCounted
## Ce qui est bâti, tel que l'Économie et le Combat le voient.
##
## Le miroir exact de HeightGrid.to_query() : un état mutable du domaine — ici
## CityState — se fige en une vue que les autres systèmes consomment sans jamais
## toucher à l'original. CityState.to_snapshot() en est le seul producteur.
##
## L'index par ancre existe parce qu'une affectation désigne un bâtiment par son
## ancre : sans lui, le résolveur de production balaierait toute la ville une fois par
## ouvrier.
##
## L'index par cellule a été ajouté à D2, qui est le premier à pousser la porte que ce
## docstring gardait fermée. Une action se joue au clic sur une cellule quelconque de
## l'empreinte — on désigne un coin de la ferme, on vise la ferme —, exactement comme une
## démolition, et c'est ce que CityState.anchor_at() fait déjà côté Construction.
##
## Il ne coûte aucune entrée de plus au contrat : les cellules se déduisent des
## BuildingSnapshot que create() reçoit déjà, puisque chacun sait son empreinte et son
## orientation.
##
## Depuis C4 il transporte aussi l'état d'avancement des chantiers, et il le fait sans
## trier : buildings() rend tout, completed() rend les finis. C'est le contrat de
## DESIGN.md 3.2 — « CityState en garde l'avancement, et CitySnapshot le dit à qui le
## consomme » —, et les deux lectures existent parce que les deux ont un consommateur.
##
## Immuable.

## Bâtiments, dans l'ordre où la ville les a posés.
var _buildings: Array[BuildingSnapshot] = []

## Ancre -> bâtiment.
var _by_anchor: Dictionary[Vector2i, BuildingSnapshot] = {}

## Cellule occupée -> bâtiment qui l'occupe, ancre comprise.
var _by_cell: Dictionary[Vector2i, BuildingSnapshot] = {}

## Vue figée de ces bâtiments, dans cet ordre.
static func create(buildings: Array[BuildingSnapshot]) -> CitySnapshot:
	var snapshot := CitySnapshot.new()
	for building in buildings:
		assert(building != null, "instantané de ville avec un bâtiment nul")
		assert(not snapshot._by_anchor.has(building.anchor()),
			"deux bâtiments sur la même ancre : %s" % building.anchor())
		snapshot._buildings.append(building)
		snapshot._by_anchor[building.anchor()] = building
		for cell in building.cells():
			assert(not snapshot._by_cell.has(cell),
				"deux bâtiments se recouvrent en %s" % cell)
			snapshot._by_cell[cell] = building
	return snapshot

## Vue d'une ville sans aucun bâtiment.
static func empty() -> CitySnapshot:
	var none: Array[BuildingSnapshot] = []
	return CitySnapshot.create(none)

## Nombre de bâtiments.
func count() -> int:
	return _buildings.size()

## Bâtiments, dans l'ordre de pose, **chantiers compris**. Copie : le tableau interne
## ne sort jamais.
##
## Tout est rendu, et c'est délibéré : le Combat voit les chantiers — DESIGN.md 3.2
## veut qu'un chantier à moitié fini détruit la veille de la vague soit une vraie
## perte. Qui ne veut que les bâtiments finis passe par completed().
func buildings() -> Array[BuildingSnapshot]:
	return _buildings.duplicate()

## Les seuls bâtiments achevés, dans l'ordre de pose. Copie.
##
## Trois consommateurs posent exactement cette question — la réserve que les entrepôts
## relèvent, les places que les habitations ajoutent, et demain les défenses. Leur
## faire recopier la clause à chacun la ferait oublier au quatrième, et l'oubli serait
## silencieux : un entrepôt en chantier qui relève quand même la réserve ne casse rien,
## il ment.
##
## L'implémentation vit donc ici, une fois, du côté du DTO qui sait déjà tout ce qu'il
## faut pour répondre.
func completed() -> Array[BuildingSnapshot]:
	var finished: Array[BuildingSnapshot] = []
	for building in _buildings:
		if building.is_complete():
			finished.append(building)
	return finished

## Un bâtiment est-il ancré ici ?
func has_anchor(anchor: Vector2i) -> bool:
	return _by_anchor.has(anchor)

## Bâtiment ancré ici, ou null si l'ancre ne porte rien.
##
## Null plutôt qu'un assert, pour la même raison que CityState.building_at() : une
## affectation peut désigner une ancre dont le bâtiment vient d'être détruit, et
## « rien ici » est une réponse que le résolveur sait traiter.
func at_anchor(anchor: Vector2i) -> BuildingSnapshot:
	if not _by_anchor.has(anchor):
		return null
	return _by_anchor[anchor]

## Bâtiment qui occupe cette cellule, ou null si elle est libre.
##
## Le pendant de CityState.building_at(), et null pour la même raison : un adapter
## interroge la cellule survolée à chaque image et la plupart sont libres. « Rien ici »
## est une réponse, pas une faute d'appelant.
##
## Répond hors carte comme dedans : la ville ne connaît pas les bornes, et « rien n'est
## posé là » reste vrai d'une cellule qui n'existe pas.
func at_cell(cell: Vector2i) -> BuildingSnapshot:
	if not _by_cell.has(cell):
		return null
	return _by_cell[cell]
