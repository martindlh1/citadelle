class_name PlacedBuilding
extends RefCounted
## Un bâtiment posé sur la carte : son contenu, son ancre, sa hauteur, son avancement.
##
## **Son placement est figé, ce qu'il a vécu ne l'est pas.** Contenu, ancre, hauteur et
## orientation ne bougent jamais — rien ne déplace un bâtiment posé, et le déplacer
## reviendrait de toute façon à valider un nouveau placement. Deux choses changent :
## l'avancement de chantier, que C4 a ajouté parce que DESIGN.md 3.2 veut qu'un chantier
## soit « un **état** du bâtiment posé, pas un type de bâtiment à part » ; et les dégâts,
## que F1 ajoute pour la même raison — une vague n'abîme pas un autre bâtiment que celui
## qu'elle frappe.
##
## D'où le choix de le loger ici plutôt que dans un troisième index sur CityState : la
## ville tient deux index qui disent la même vérité — ce qui existe, et quelle cellule
## renvoie à quoi. Un avancement rangé à côté d'eux serait un état séparé du bâtiment
## qu'il décrit, à resynchroniser à chaque pose et à chaque retrait.
##
## La hauteur est stockée ici plutôt que relue sur le terrain à chaque besoin. Elle
## n'est bien définie que parce qu'un bâtiment exige toutes ses cellules à la même
## hauteur — c'est le bénéfice direct de cette règle, et c'est ce qui permettra au
## rendu de C2 de savoir où poser la boîte sans reparcourir l'empreinte ni interroger
## la grille.

var _data: BuildingData
var _anchor: Vector2i
var _height: int
var _turns: int
var _progress: int

## Points encaissés depuis la pose. Second état mutable, entré à F1.
##
## Il vit ici pour la raison qui a fait entrer l'avancement à C4, et elle est encore plus
## forte : des dégâts rangés dans un troisième index de la ville seraient un état séparé du
## bâtiment qu'ils décrivent, à resynchroniser à chaque pose, à chaque retrait et à chaque
## destruction.
##
## Il est **distinct de l'avancement**, et les deux ne se mélangent jamais. Un chantier
## encaisse les PV du bâtiment fini : l'avancement n'est pas une barre de vie, et les
## confondre ferait qu'un chantier bien avancé résisterait mieux qu'un neuf — ce que rien
## dans DESIGN.md ne demande. Ce que 3.2 demande est qu'un chantier détruit soit une perte
## qui se raconte, et c'est le DamageReport qui le dit.
var _damage: int

## Bâtiment posé sur cette ancre, à cette hauteur, dans cette orientation.
##
## Il naît **en chantier**, à zéro cran. Sur un bâtiment dont la data ne réclame aucune
## action — le Cœur —, ce zéro le rend achevé sur-le-champ, sans que la pose ait à
## connaître le cas.
static func create(data: BuildingData, anchor: Vector2i, height: int,
		turns: int = 0) -> PlacedBuilding:
	assert(data != null, "bâtiment posé sans données")
	assert(not data.footprint.is_empty(), "bâtiment posé sans empreinte : %s" % data.id)
	var building := PlacedBuilding.new()
	building._data = data
	building._anchor = anchor
	building._height = height
	building._turns = posmod(turns, BuildingData.QUARTER_TURNS)
	return building

## Contenu du bâtiment : son identité, son empreinte, et ce que les systèmes suivants
## y ajouteront.
func data() -> BuildingData:
	return _data

## Cellule d'ancrage. C'est la clé sous laquelle la ville le range.
func anchor() -> Vector2i:
	return _anchor

## Hauteur commune de ses cellules, en crans.
func height() -> int:
	return _height

## Orientation dans laquelle il a été posé, en quarts de tour, toujours dans [0, 3].
func turns() -> int:
	return _turns

## Crans de chantier déjà posés.
func progress() -> int:
	return _progress

## Crans qu'il reste à poser. 0 sur un bâtiment achevé.
func remaining() -> int:
	return maxi(0, _data.site_turns - _progress)

## Le chantier est-il achevé ?
##
## Tant que non, le bâtiment occupe ses cellules et ne fait rien d'autre : il ne produit
## pas, n'offre aucun slot et ne relève aucun plafond. Voir DESIGN.md 3.2.
func is_complete() -> bool:
	return _progress >= _data.site_turns

## Pose un cran de chantier. Rend vrai s'il a avancé, faux s'il était déjà achevé.
##
## L'avancement ne dépasse jamais ce que la data réclame : un chantier fini absorberait
## sinon les crans du tour sans que rien ne le dise, et remaining() finirait négatif. Le
## refus est rendu plutôt que tu, pour que l'appelant sache que le cran n'a servi à rien.
##
## Passer par CityState.advance() plutôt que d'appeler ceci directement : c'est la porte
## documentée, celle que la résolution d'un tour vise par une ancre.
func advance() -> bool:
	if is_complete():
		return false
	_progress += 1
	return true

## Points encaissés depuis la pose.
func damage() -> int:
	return _damage

## Ce qu'il peut encore encaisser. 0 sur un bâtiment tombé.
func hit_points_left() -> int:
	return maxi(0, _data.hit_points - _damage)

## Est-il tombé ?
##
## Un bâtiment tombé ne reste pas dans la ville : CityState.damage() le retire dans le
## même geste. Cette question n'est donc vraie que le temps d'un appel, et elle existe pour
## que ce soit **ce fichier** qui décide de ce que « tombé » veut dire — la ville n'a pas à
## recopier `damage >= hit_points`, exactement comme elle ne recopie pas l'arithmétique du
## chantier.
func is_destroyed() -> bool:
	return _damage >= _data.hit_points

## Encaisse des points et rend ce qu'il a **réellement** pris.
##
## Le retour est écrêté à ce qu'il lui restait : un bâtiment à 2 PV frappé de 10 en prend
## 2, et le rapport de vague dit 2. Sans cet écrêtage, une brèche se dépenserait sur des
## points de vie qui n'existent pas et une palissade absorberait la vague entière.
##
## Un bâtiment déjà tombé prend 0 — le cas ne devrait pas se présenter, la ville l'ayant
## retiré, mais un `take()` qui creuserait sous zéro rendrait `damage()` inexploitable.
##
## Passer par CityState.damage() plutôt que d'appeler ceci directement : c'est la porte
## documentée, celle qu'une vague vise par une ancre, et la seule qui retire le bâtiment
## quand il tombe.
func take(points: int) -> int:
	assert(points >= 0, "dégâts négatifs sur %s : %d" % [_data.id, points])
	var taken := mini(points, hit_points_left())
	_damage += taken
	return taken

## Cellules absolues qu'il occupe, dans l'ordre de son empreinte et dans son
## orientation. Rien en dehors d'ici n'a à savoir qu'une rotation est en jeu.
##
## Un chantier les occupe autant qu'un bâtiment fini : il les a payées à la pose, et
## rien ne se pose par-dessus en attendant.
func cells() -> Array[Vector2i]:
	return _data.cells_at(_anchor, _turns)
