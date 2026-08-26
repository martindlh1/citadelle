class_name CityState
extends RefCounted
## Ce qui est bâti : les bâtiments posés et les cellules qu'ils occupent.
##
## État interne du système Construction, comme HeightGrid l'est du Terrain. Il ignore
## délibérément les dimensions de la carte — c'est TerrainQuery qui les connaît, et
## une ville qui les recopierait aurait à les resynchroniser pour rien. La ville ne
## sait que ce qu'elle a posé.
##
## Deux index pour la même vérité :
##   - ancre -> bâtiment, la liste de ce qui existe ;
##   - cellule -> ancre, la « référence vers l'ancre » de DESIGN.md 3.2, qui rend
##     immédiat le survol d'une cellule quelconque d'une empreinte.
##
## place() est la SEULE porte d'entrée mutante, et elle valide avant de muter. Rien ne
## peut donc entrer dans la ville sans être passé par PlacementValidator : c'est un
## invariant tenu par la structure, et non une consigne qu'un appelant doit respecter.
##
## advance() est une seconde porte mutante depuis C4, mais d'une autre nature, et il
## faut être honnête sur ce qu'elle garantit : elle n'est **pas** exclusive. Un appelant
## qui tient un PlacedBuilding — le renderer en tient toute une liste depuis C2 — peut
## l'avancer sans passer par ici. Fermer ça demanderait de ne plus jamais laisser sortir
## un PlacedBuilding, ce dont le rendu dépend. advance() est donc la porte documentée,
## celle qu'une action vise par son ancre ; elle n'est pas un verrou.
##
## damage() est la troisième, entrée à F1, et elle est la seule des deux mutantes non
## exclusives qui **compte vraiment** : un cran de chantier posé dans le dos de la ville
## ne casse qu'un compteur, un bâtiment détruit dans son dos reste debout dans les deux
## index, occupe ses cellules et relève encore la réserve. C'est pourquoi elle retire
## elle-même, plutôt que de rendre un booléen que l'appelant aurait à honorer.

## Ancre -> bâtiment posé. L'ordre d'insertion d'un Dictionary est l'ordre de pose :
## c'est lui qui rend buildings() déterministe pour un même seed et une même suite
## d'actions, sans avoir à trier quoi que ce soit.
var _buildings: Dictionary[Vector2i, PlacedBuilding] = {}

## Cellule occupée -> ancre du bâtiment qui l'occupe.
var _anchors: Dictionary[Vector2i, Vector2i] = {}

## Nombre de bâtiments posés.
func count() -> int:
	return _buildings.size()

## Bâtiments posés, dans l'ordre de pose.
func buildings() -> Array[PlacedBuilding]:
	var placed: Array[PlacedBuilding] = []
	placed.assign(_buildings.values())
	return placed

## Cette cellule porte-t-elle un bâtiment ?
##
## Répond hors carte, et le doit : la ville ne connaît pas les bornes, et « rien n'est
## posé là » reste vrai d'une cellule qui n'existe pas. C'est le contrat Terrain qui
## tranche l'existence, pas celui-ci.
func is_occupied(cell: Vector2i) -> bool:
	return _anchors.has(cell)

## Bâtiment qui occupe cette cellule, ou null si elle est libre.
##
## Null plutôt qu'un assert : un adapter interroge la cellule survolée à chaque image
## et la plupart sont libres. Même exception que decor sur TerrainData — « rien ici »
## est une réponse, pas une faute d'appelant.
func building_at(cell: Vector2i) -> PlacedBuilding:
	if not _anchors.has(cell):
		return null
	return _buildings[_anchors[cell]]

## Ancre du bâtiment qui occupe cette cellule. Précondition : is_occupied(cell).
##
## C'est le chemin d'une démolition au clic : l'adapter tient une cellule quelconque
## de l'empreinte, remove() veut l'ancre.
func anchor_at(cell: Vector2i) -> Vector2i:
	assert(is_occupied(cell), "ancre demandée à une cellule libre : %s" % cell)
	return _anchors[cell]

## Un bâtiment est-il ancré sur cette cellule ? Faux sur une cellule qu'une empreinte
## couvre sans y être ancrée.
func has_anchor(anchor: Vector2i) -> bool:
	return _buildings.has(anchor)

## Vue figée de la ville, pour les systèmes qui la consomment sans la connaître.
##
## Le miroir de HeightGrid.to_query() : l'Économie et le Combat lisent un CitySnapshot
## et n'ont jamais accès à cet objet-ci, ni à PlacedBuilding qui est un interne de
## Construction. C'est la seule sortie du système vers ses consommateurs.
##
## L'ordre est celui de la pose, comme buildings().
##
## L'avancement traverse **figé**, comme le reste : un instantané pris ce soir ne suit
## pas les crans posés demain.
func to_snapshot() -> CitySnapshot:
	var projected: Array[BuildingSnapshot] = []
	for building in buildings():
		projected.append(BuildingSnapshot.create(
			building.data(), building.anchor(), building.height(), building.turns(),
			building.progress(), building.damage()))
	return CitySnapshot.create(projected)

## Pose ce bâtiment sur cette ancre, dans cette orientation, si le placement est valide.
## Ne mute rien sinon.
##
## L'orientation est enregistrée sur le bâtiment posé et n'apparaît nulle part dans les
## index : ceux-ci ne voient que des cellules, déjà pivotées.
##
## Rend le PlacementResult de la validation tel quel, de sorte qu'un appelant qui
## prévisualisait déjà retrouve exactement la réponse qu'il affichait — le fantôme de
## C2 et la pose ne peuvent pas diverger.
func place(terrain: TerrainQuery, data: BuildingData, anchor: Vector2i,
		turns: int = 0) -> PlacementResult:
	var result := PlacementValidator.validate(self, terrain, data, anchor, turns)
	if not result.is_ok():
		return result
	_buildings[anchor] = PlacedBuilding.create(data, anchor, result.height(), turns)
	for cell in result.cells():
		_anchors[cell] = anchor
	return result

## Pose un cran de chantier sur le bâtiment ancré ici. Rend vrai s'il a avancé, faux
## s'il était déjà achevé.
##
## Précondition : has_anchor(anchor). Passer par anchor_at() quand on tient une cellule
## quelconque plutôt que l'ancre — c'est le chemin d'une action jouée au clic, le même
## que celui d'une démolition.
##
## Profil de remove() et non de place() : une précondition, pas un PlacementResult. Un
## refus de placement est le résultat normal d'un curseur promené sur toute la carte,
## et le fantôme l'interroge à chaque image ; ici les deux seuls refus possibles — rien
## à cette ancre, chantier déjà fini — se posent avant l'appel, et un booléen suffit à
## dire lequel s'est produit quand même.
##
## Le cran est délégué au bâtiment plutôt que compté ici. La ville sait qui est posé où ;
## combien il lui reste à bâtir est son affaire à lui.
func advance(anchor: Vector2i) -> bool:
	assert(has_anchor(anchor), "chantier avancé sur une cellule qui n'ancre rien : %s" % anchor)
	return _buildings[anchor].advance()

## Fait encaisser des points au bâtiment ancré ici, et le **retire s'il tombe**. Rend vrai
## s'il est tombé.
##
## Précondition : has_anchor(anchor). Passer par anchor_at() quand on tient une cellule
## quelconque plutôt que l'ancre.
##
## Elle retire elle-même plutôt que de laisser l'appelant le faire, et c'est ce qui la
## distingue d'advance() : un chantier qu'on oublie d'avancer reste un chantier, un
## bâtiment détruit qu'on oublie de retirer reste **debout** dans la ville, occupe ses
## cellules et relève encore la réserve. L'invariant est tenu par la structure, comme
## place() valide avant de muter ; le laisser à un appelant serait le laisser à tous ceux
## qui viendront.
##
## Le compte des points encaissés est délégué au bâtiment, comme le cran de chantier :
## la ville sait qui est posé où, ce qu'il peut encore encaisser est son affaire à lui.
func damage(anchor: Vector2i, points: int) -> bool:
	assert(has_anchor(anchor), "dégâts sur une cellule qui n'ancre rien : %s" % anchor)
	var building := _buildings[anchor]
	building.take(points)
	if not building.is_destroyed():
		return false
	remove(anchor)
	return true

## Retire le bâtiment ancré ici et libère toutes ses cellules.
##
## Précondition : has_anchor(anchor). Passer par anchor_at() quand on tient une
## cellule quelconque plutôt que l'ancre.
func remove(anchor: Vector2i) -> void:
	assert(has_anchor(anchor), "retrait sur une cellule qui n'ancre rien : %s" % anchor)
	for cell in _buildings[anchor].cells():
		_anchors.erase(cell)
	_buildings.erase(anchor)
