class_name Territory
extends RefCounted
## Jusqu'où le village a le droit de bâtir : la réunion des disques que ses bâtiments achevés
## projettent autour d'eux.
##
## Fonction pure sur un CityState. Elle ne mute rien et ne connaît ni le relief ni l'Économie :
## l'emprise est une affaire de **ce qui est bâti**, et de rien d'autre. Un rocher dans le
## territoire en fait partie — il n'est simplement pas constructible, ce qui est la réponse
## d'une autre règle.
##
## ---
##
## **Une réunion, jamais une distance au Cœur**, et c'est toute la mécanique. Un rayon central
## qui grandirait s'étendrait dans **toutes** les directions à la fois ; une réunion s'étend là
## où l'on a investi. Le contour cesse donc d'être un cercle dès le deuxième bâtiment : il
## pousse des lobes vers ce que le village est allé chercher, et se creuse ailleurs.
##
## **Seuls les bâtiments achevés comptent.** Un chantier occupe ses cases et paie son coût,
## mais il n'étend rien — même règle que la réserve qu'un entrepôt en travaux ne relève pas
## encore. Sans elle, on traverserait la carte en chaînant des chantiers qu'on n'achève jamais,
## et s'étendre ne coûterait que des ressources au lieu de coûter des **tours**.
##
## ---
##
## **Trois lectures, trois fonctions, et c'est délibéré.** Le validateur pose une question par
## cellule à chaque image sous le curseur : `reaches()` lui répond sans rien allouer. Le contour
## veut l'ensemble entier, une fois par changement de ville : `cells()` le lui donne. Une seule
## fonction aurait fait construire mille cellules soixante fois par seconde pour en tester
## quatre — c'est le tableau alloué dans une boucle de grille que `T4` a payé une fois.
##
## Et `would_cover()` répond de ce qu'un bâtiment **non posé** ouvrirait, pour le fantôme.
##
## Les trois lisent la **même** définition, à la ligne près : `_covers()`. Deux arithmétiques de
## distance à tenir d'accord seraient deux occasions de dessiner un contour qui ne correspond
## pas à ce que le placement accepte, et ce désaccord-là serait muet — on verrait une bordure
## et le clic refuserait dedans.

## Cette cellule est-elle dans l'emprise du village ?
##
## **Une ville vide n'a pas d'emprise, et rend `true`.** C'est le cas de la fondation, et il
## n'appelle aucune exception ailleurs : le Cœur ne se pose que quand rien n'existe, donc la
## seule pose qui échappe à la règle est précisément celle qui la crée. Rendre `false` aurait
## obligé l'orchestrateur à contourner le validateur pour fonder, c'est-à-dire à ouvrir un
## chemin de pose que rien ne vérifie.
static func reaches(city: CityState, cell: Vector2i) -> bool:
	assert(city != null, "emprise sans ville")
	if city.count() == 0:
		return true
	for building in city.buildings():
		if not building.is_complete():
			continue
		if _within(building, cell):
			return true
	return false

## Toutes les cellules de l'emprise, dans l'ordre de balayage, bornées par la carte.
##
## L'ordre est celui du balayage et non celui des bâtiments : le contour se dessine dessus, et
## un ensemble qui changerait d'ordre ferait scintiller la bordure d'une image à l'autre.
##
## Une ville vide rend un ensemble **vide**, là où `reaches()` rend `true` pour toute cellule.
## Les deux disent la même chose sous deux formes : il n'y a pas encore de frontière, donc rien
## à dessiner et rien à refuser.
static func cells(city: CityState, extent: Vector2i) -> Array[Vector2i]:
	assert(city != null, "emprise sans ville")
	var found: Array[Vector2i] = []
	if city.count() == 0:
		return found
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			for building in city.buildings():
				if not building.is_complete():
					continue
				if _within(building, cell):
					found.append(cell)
					break
	return found

## Ce qu'un bâtiment posé **ici** ouvrirait, sans qu'il soit posé.
##
## Elle reçoit une ancre et une orientation plutôt qu'un `PlacedBuilding`, exactement comme
## `Adjacency.inspect()` et pour la même raison : le fantôme sous le curseur n'existe pas
## encore, et c'est justement au moment de choisir sa case qu'on veut savoir ce qu'il
## ouvrirait. Un argument de bâtiment posé aurait rendu la prévisualisation impossible et
## forcé une seconde arithmétique de distance à côté de celle-ci.
##
## Le balayage se borne à l'enveloppe du disque au lieu de parcourir la carte : cette
## fonction-là est appelée **à chaque image**, sous une souris qui se promène.
static func would_cover(data: BuildingData, anchor: Vector2i, turns: int,
		extent: Vector2i) -> Array[Vector2i]:
	assert(data != null, "emprise sans bâtiment")
	var found: Array[Vector2i] = []
	var footprint := data.cells_at(anchor, turns)
	if footprint.is_empty():
		return found
	var area := data.neighbourhood_at(anchor, data.reach, turns)
	for y in range(maxi(area.position.y, 0), mini(area.end.y, extent.y)):
		for x in range(maxi(area.position.x, 0), mini(area.end.x, extent.x)):
			var cell := Vector2i(x, y)
			if _covers(footprint, data.reach, cell):
				found.append(cell)
	return found

## Cette cellule est-elle dans le disque de ce bâtiment posé ?
static func _within(building: PlacedBuilding, cell: Vector2i) -> bool:
	return _covers(building.cells(), building.data().reach, cell)

## Cette cellule est-elle à `reach` anneaux ou moins de l'une de ces cases ?
##
## La distance est prise en **anneaux** depuis la case la plus proche de l'empreinte, comme
## celle d'une règle d'adjacence : les diagonales comptent pour un, et un bâtiment de deux
## cases rayonne depuis ses deux bouts. Deux métriques différentes dans le même jeu seraient
## deux formes à apprendre pour rien.
##
## Les trois lectures de ce fichier passent par ici — le placement, le contour, la
## prévisualisation. C'est la seule façon de garantir qu'elles dessinent et refusent la même
## frontière, et ce désaccord-là serait muet : une bordure dans laquelle le clic refuse.
static func _covers(cells: Array[Vector2i], reach: int, cell: Vector2i) -> bool:
	for occupied in cells:
		if maxi(absi(cell.x - occupied.x), absi(cell.y - occupied.y)) <= reach:
			return true
	return false
