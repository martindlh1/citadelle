class_name BuildingData
extends Resource
## Un bâtiment tel que le contenu le décrit : son identité et son empreinte.
##
## Les .tres vivent dans data/buildings/, un par bâtiment. Le domaine les reçoit en
## argument et ne lit jamais GameDatabase, comme pour TerrainData.
##
## C1 n'y met que ce que le placement consomme. Coût, slots, rendement, défense, PV
## et bonus d'adjacence arrivent avec leur système — E1, C3, F1 — de la même façon que
## BalanceData gagne un bloc quand un système atterrit. Un champ ajouté plus tard
## oblige à rouvrir les .tres ; un champ ajouté d'avance oblige à deviner sa forme,
## ce qui coûte plus cher.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Identifiant stable, repris par les sorties de debug et par les cartes.
## Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Cellules occupées, en décalages depuis l'ancre.
##
## Une empreinte n'est pas forcément un rectangle : [(0,0), (1,0), (0,1)] décrit un L,
## et un 2x2 s'écrit avec ses quatre cellules. Le rectangle n'est qu'un cas
## particulier, ce qui évite d'avoir deux façons de dire la même chose et deux chemins
## à valider.
##
## L'ancre — le décalage (0, 0) — en fait toujours partie : c'est par elle que la
## ville retrouve le bâtiment, et une empreinte qui ne la couvrirait pas laisserait
## CityState.anchor_at() renvoyer vers une case vide. missing_fields() le vérifie.
##
## Rien n'impose en revanche que l'empreinte soit d'un seul tenant. Un bâtiment en
## deux morceaux disjoints serait bizarre mais se poserait correctement, et refuser
## une forme que rien ne casse serait une règle de contenu déguisée en règle de
## schéma.
@export var footprint: Array[Vector2i]

## Cellules absolues qu'une pose sur cette ancre couvrirait.
##
## L'ordre est celui de l'empreinte, donc identique d'un appel et d'un run à l'autre.
## Tout ce qui itère sur les cellules d'un bâtiment en dépend pour rester déterministe.
func cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in footprint:
		cells.append(anchor + offset)
	return cells

## Rectangle englobant de l'empreinte posée sur cette ancre.
##
## Sur une forme en L il couvre des cellules que le bâtiment n'occupe pas : c'est une
## enveloppe, pas l'empreinte. Ne pas s'en servir pour tester la constructibilité.
##
## Précondition : empreinte non vide.
func bounds_at(anchor: Vector2i) -> Rect2i:
	assert(not footprint.is_empty(), "empreinte vide sur %s" % id)
	var low := footprint[0]
	var high := footprint[0]
	for offset in footprint:
		low = Vector2i(mini(low.x, offset.x), mini(low.y, offset.y))
		high = Vector2i(maxi(high.x, offset.x), maxi(high.y, offset.y))
	return Rect2i(anchor + low, high - low + Vector2i.ONE)

## Zone de recherche autour du bâtiment posé sur cette ancre : son rectangle
## englobant élargi de `radius` cellules dans les quatre directions, empreinte
## comprise.
##
## Rien ne l'appelle à C1 — aucune règle de placement ne regarde le voisinage. Elle
## est écrite d'avance, ce qui se justifie ici et rarement ailleurs : c'est de la
## géométrie pure, elle se teste entièrement sans terrain ni ville, et C3 la
## consommera telle quelle pour les bonus d'adjacence.
##
## Elle n'engage pas C3 sur le sort de l'empreinte : compter les voisins sans se
## compter soi-même est un filtrage que l'appelant fait sur cette zone. Un prérequis
## dur d'adjacence, lui, a été écarté du placement à C1.
##
## La zone déborde volontiers de la carte. C'est à l'appelant de tester ses cellules
## contre TerrainQuery, dont les requêtes de constructibilité et de tag répondent
## hors grille.
func neighbourhood_at(anchor: Vector2i, radius: int) -> Rect2i:
	assert(radius >= 0, "rayon de voisinage négatif : %d" % radius)
	return bounds_at(anchor).grow(radius)

## Champs non renseignés ou incohérents. Vide = bâtiment exploitable.
## Vérifié au boot par GameDatabase, comme les terrains et l'équilibrage.
##
## L'empreinte est contrôlée au-delà de sa simple présence, parce qu'une empreinte
## sans ancre ou qui nomme deux fois la même cellule se charge sans erreur et ne casse
## que bien plus loin. Les deux remontent préfixées « footprint. », comme TerrainData
## préfixe « decor. ».
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if footprint.is_empty():
		missing.append("footprint")
		return missing
	if not footprint.has(Vector2i.ZERO):
		missing.append("footprint.anchor")
	if _has_duplicate_offset():
		missing.append("footprint.duplicate")
	return missing

## L'empreinte nomme-t-elle deux fois la même cellule ?
func _has_duplicate_offset() -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	for offset in footprint:
		if seen.has(offset):
			return true
		seen[offset] = true
	return false
