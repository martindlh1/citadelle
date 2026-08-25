class_name BuildingSnapshot
extends RefCounted
## Un bâtiment posé, tel que les autres systèmes le voient.
##
## C'est la projection de PlacedBuilding, qui vit dans domain/city/ et n'a donc pas à
## traverser la frontière : l'Économie qui en dépendrait dépendrait des internes de
## Construction.
##
## Il porte exactement ce que PlacedBuilding sait déjà — c'est une projection, pas une
## invention, et rien n'y est ajouté d'avance pour un consommateur qui n'existe pas.
## Les PV que le Combat voudra viendront à F1, avec le champ qui les porte.
##
## Immuable. La ville en fabrique une série à chaque to_snapshot() et les jette après.
## L'avancement de chantier voyage donc **figé** : un instantané pris ce soir ne suit
## pas les crans posés demain, exactement comme il ne suit pas une destruction.

var _data: BuildingData
var _anchor: Vector2i
var _height: int
var _turns: int
var _progress: int

## Projection d'un bâtiment posé sur cette ancre, à cette hauteur, dans cette
## orientation, avec ce nombre de crans de chantier déjà posés.
##
## `progress` vaut 0 par défaut — « rien n'est encore bâti », le zéro honnête. Sur un
## BuildingData sans coût de chantier, ce zéro suffit à rendre le bâtiment achevé : un
## appelant n'a à nommer l'avancement que là où il compte vraiment.
static func create(data: BuildingData, anchor: Vector2i, height: int,
		turns: int = 0, progress: int = 0) -> BuildingSnapshot:
	assert(data != null, "instantané de bâtiment sans données")
	assert(progress >= 0, "instantané de bâtiment à l'avancement négatif : %d" % progress)
	var snapshot := BuildingSnapshot.new()
	snapshot._data = data
	snapshot._anchor = anchor
	snapshot._height = height
	snapshot._turns = posmod(turns, BuildingData.QUARTER_TURNS)
	snapshot._progress = progress
	return snapshot

## Contenu du bâtiment : son identité, son empreinte, son bloc économie.
func data() -> BuildingData:
	return _data

## Cellule d'ancrage. C'est la clé sous laquelle une affectation le désigne.
func anchor() -> Vector2i:
	return _anchor

## Hauteur commune de ses cellules, en crans.
func height() -> int:
	return _height

## Orientation dans laquelle il a été posé, en quarts de tour, toujours dans [0, 3].
func turns() -> int:
	return _turns

## Crans de chantier déjà posés. 0 sur un bâtiment qu'on vient de poser.
func progress() -> int:
	return _progress

## Le chantier est-il achevé ?
##
## C'est la question que les consommateurs posent vraiment, et la seule chose que C4
## ajoute à ce contrat au-delà d'un compteur. L'Économie ignore un bâtiment inachevé —
## il ne produit rien, n'offre aucun slot et ne relève aucun plafond ; le Combat, lui,
## le voit très bien, et c'est pourquoi CitySnapshot.buildings() continue de tout
## rendre. Voir DESIGN.md 3.2.
##
## Un bâtiment sans coût de chantier est achevé dès la pose : 0 >= 0. C'est ainsi que
## le Cœur, posé au départ et sans carte, n'a besoin d'aucun chemin particulier.
func is_complete() -> bool:
	return _progress >= _data.build_actions

## Crans qu'il reste à poser. 0 sur un bâtiment achevé.
func remaining() -> int:
	return maxi(0, _data.build_actions - _progress)

## Cellules absolues qu'il occupe, dans l'ordre de son empreinte et dans son
## orientation.
##
## Un chantier occupe ses cellules exactement comme un bâtiment fini : il les a payées
## à la pose, et rien ne peut se poser par-dessus en attendant.
func cells() -> Array[Vector2i]:
	return _data.cells_at(_anchor, _turns)
