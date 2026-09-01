class_name Population
extends RefCounted
## Combien de gens vivent au village, et combien de lits il y a pour eux.
##
## État interne de l'Économie, exactement comme Ledger l'est de la réserve — et le
## parallèle entre les deux est délibéré, parce que ce sont **deux plafonds bâtis sur le
## même modèle** : une quantité, une capacité que des bâtiments relèvent, et un écrêtage
## quand cette capacité baisse. Un entrepôt détruit fait perdre des ressources
## (Ledger.set_capacity), une habitation détruite fait perdre des habitants
## (Population.set_places). Les deux rendent ce que l'opération a coûté.
##
## ---
##
## **C'est un compteur, jamais une liste**, et c'est la frontière que tout le rescope
## repose sur elle (DESIGN.md 3.4). Pas de noms, pas de pistes de compétence, pas d'XP,
## pas de traits, pas d'affectation. Le jour où l'on se surprend à vouloir savoir *lequel*
## des douze habitants fait quoi, on est en train de réécrire ce que R0 vient de couper.
##
## Ce fichier ne sait donc **pas** qui travaille où. Il ne connaît que trois nombres, et
## deux seulement lui appartiennent — le troisième, ce que la ville immobilise, se demande
## à Staffing, qui lit le plan de la ville. C'est ce partage qui garde la population hors
## de toute connaissance des bâtiments : elle est une ressource, ce sont eux qui la
## dépensent.
##
## Invariant tenu par construction : `0 <= headcount <= places`.

## Habitants. Jamais négatif, jamais au-dessus de _places.
var _headcount: int = 0

## Places de logement, base d'équilibrage plus ce que les habitations ajoutent.
var _places: int = 0

## Village vide de ce nombre de places.
static func create(places: int) -> Population:
	assert(places >= 0, "places de logement négatives")
	var people := Population.new()
	people._places = maxi(0, places)
	return people

## Village peuplé de cet effectif, écrêté à ces places s'il les dépasse.
##
## L'écrêtage plutôt que l'assertion, comme Ledger.from_stock : un stock d'ouverture qui
## déborde est une question d'équilibrage que GameDatabase refuse au boot, pas un défaut de
## programmation que le domaine doive constater à l'exécution.
static func from_headcount(headcount: int, places: int) -> Population:
	var people := Population.create(places)
	people._headcount = clampi(headcount, 0, people._places)
	return people

## Habitants présents.
func headcount() -> int:
	return _headcount

## Places de logement, habitations comprises.
func places() -> int:
	return _places

## Lits libres. Jamais négatif.
func free_places() -> int:
	return maxi(0, _places - _headcount)

## Le logement est-il plein ? C'est ce qui arrête la croissance.
func is_full() -> bool:
	return _headcount >= _places

## Change le plafond de logement et rend combien d'habitants l'opération a fait perdre.
##
## Jumeau exact de Ledger.set_capacity(), et pour la même raison : une habitation détruite
## par une vague abaisse ce plafond sous l'effectif, et le surplus doit partir quelque part.
## Rendre la perte plutôt que de la taire est ce qui permet à l'appelant d'en faire une
## ligne de rapport — un village qui perd trois habitants doit pouvoir le dire.
##
## La montée ne fait rien perdre et ne fait venir personne : la croissance est un geste du
## tour, pas un effet de bord d'un chantier qui s'achève.
func set_places(places: int) -> int:
	assert(places >= 0, "places de logement négatives")
	_places = maxi(0, places)
	if _headcount <= _places:
		return 0
	var lost := _headcount - _places
	_headcount = _places
	return lost

## Fait venir jusqu'à ce nombre d'habitants et rend combien sont vraiment arrivés.
##
## Bornée par les lits libres : c'est le **frein spatial** de DESIGN.md 3.4, et il est le
## seul. Demander plus que la place disponible n'est pas une erreur — c'est la situation
## normale d'un village qui a de quoi manger et nulle part où loger.
func grow(by: int = 1) -> int:
	assert(by >= 0, "croissance négative")
	var arrived := mini(maxi(0, by), free_places())
	_headcount += arrived
	return arrived

## En fait partir jusqu'à ce nombre et rend combien sont vraiment partis.
##
## Bornée par l'effectif, pour la même raison que grow() l'est par les lits : un village de
## deux habitants qui en perdrait trois n'est pas un cas d'erreur, c'est une soustraction
## qui s'arrête à zéro. Ce que l'appelant en fait — annoncer la famine, terminer le run —
## se décide plus haut.
func shrink(by: int = 1) -> int:
	assert(by >= 0, "décroissance négative")
	var lost := mini(maxi(0, by), _headcount)
	_headcount -= lost
	return lost
