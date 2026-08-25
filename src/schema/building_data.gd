class_name BuildingData
extends Resource
## Un bâtiment tel que le contenu le décrit : son identité et son empreinte.
##
## Les .tres vivent dans data/buildings/, un par bâtiment. Le domaine les reçoit en
## argument et ne lit jamais GameDatabase, comme pour TerrainData.
##
## C1 n'y mettait que ce que le placement consomme ; E1 y ajoute l'économie — coût,
## réserve, et la production à plat —, E1b sort cette dernière dans un bloc nullable, W1
## les places de roster, et C4 le coût de chantier. Défense, PV et bonus d'adjacence
## arriveront avec leur système — C3, F1 — de la même façon que BalanceData gagne un
## bloc quand un système atterrit. Un champ ajouté plus tard oblige à rouvrir les .tres ;
## un champ ajouté d'avance oblige à deviner sa forme, ce qui coûte plus cher.
##
## Ajouter un **bâtiment** doit rester une édition de data/. Ajouter une **nature** de
## bâtiment est légitimement une modification de code — mais dans src/domain/, jamais
## ici : une Resource qui porterait une méthode de résolution serait du domaine
## déguisé. Voir DESIGN.md 3.3.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Couleur qu'on lit comme « non renseignée ».
##
## Recopiée de TerrainData plutôt qu'importée, comme TerrainDecor la recopie déjà.
## Là-bas c'était pour ne pas fermer un cycle de types ; ici il n'y en a pas, mais
## faire dépendre un bâtiment du schéma du terrain pour une constante serait un
## couplage sans contrepartie. Un cas de test épingle l'égalité des copies.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Orientations possibles d'un placement. Quatre, comme les crans de la caméra.
const QUARTER_TURNS := 4

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

## Couleur de la boîte au rendu, en attendant de vrais assets.
##
## Elle vit ici et non dans le renderer pour la raison qui vaut déjà pour les
## terrains : ajouter un bâtiment doit rester une édition de data, et un renderer qui
## commuterait sur un identifiant obligerait à toucher au GDScript à chaque ajout.
@export var color: Color

## Hauteur de la boîte, en **fractions de tuile** et non en unités de monde.
##
## C'est la leçon des décorations à T3 : régler tile_size doit redimensionner la carte
## entière, bâtiments compris, et non laisser des maisons à leur ancienne taille au
## milieu de cellules qui ont changé.
@export_range(0.0, 4.0, 0.05) var height: float

## Combien d'actions *Construire* il faut lui jeter dessus pour l'achever.
##
## C'est la colonne **Chantier** de DESIGN.md 4.1. Poser une carte de bâtiment ouvre un
## chantier et non un bâtiment : il occupe ses cellules et paie son coût tout de suite,
## mais ne produit rien et n'offre aucun slot avant d'avoir reçu ce nombre de crans.
##
## **0 est une valeur légitime** et veut dire « achevé à la pose ». La doctrine du zéro
## ne s'applique donc pas ici, exactement comme pour storage_bonus et roster_places
## juste en dessous — mais pour une raison qui lui est propre : le Cœur porte « — »
## dans cette colonne, comme il porte « posé au départ » dans celle du coût, et c'est
## déjà un cost vide qui représente la seconde. Représenter la première par un zéro est
## le même geste sur la même ligne du tableau.
##
## Le prix de ce choix est connu : un build_actions oublié dans un .tres vaut 0 et fait
## sauter le chantier en silence. Il est racheté par un cas de test qui charge tout
## data/ et exige qu'au moins un bâtiment en déclare un — le motif de
## production_block_test.gd, qui refuse de passer par vacuité.
##
## Le champ ne s'appelle pas `turns` : ce nom désigne déjà les quarts de tour d'une
## orientation, partout dans le système.
@export_range(0, 10, 1) var build_actions: int

## Ce qu'il coûte à poser, par ressource.
##
## Le coût ne participe **pas** à la validation du placement : « ai-je les 15 bois ? »
## ne regarde pas la carte, et c'est la couche qui orchestre la journée qui enchaîne
## les deux questions. Tranché à C1, voir DESIGN.md 3.2.
@export var cost: Dictionary[StringName, int]

## Ce qu'il produit, ou **null** s'il ne produit pas.
##
## Nullable, et c'est tout l'intérêt : l'entrepôt et l'habitation n'ont pas « zéro
## slot », ils n'ont pas de bloc. Les trois champs de production — postes, rendement,
## famille — vivent ou meurent ensemble, ce qui rend la cohérence structurelle au lieu
## de vérifiée. Tranché avant E1b, voir DESIGN.md 3.3 et le docstring de
## ProductionBlock.
##
## Cinq bâtiments de DESIGN.md 4.1 — tour de guet, caserne, marché, atelier, camp
## d'exploration — portent un slot dans le tableau et arrivent pourtant sans bloc. Ce
## n'est pas un oubli : leur poste n'est pas un poste de production, il héberge une
## défense, un échange ou une action débloquée, et le système qui le lira n'existe pas
## encore — F1, I3, X1, X2, X3. Leur bloc viendra avec lui, et de la bonne nature.
@export var production: ProductionBlock

## Ce qu'il ajoute à la réserve commune. 0 pour tout ce qui n'est pas un entrepôt.
##
## En réserve commune, ce chiffre ne relève pas trois compteurs indépendants mais la
## seule capacité partagée : c'est ce qui donne à l'entrepôt une valeur d'arbitrage.
@export_range(0, 500, 1) var storage_bonus: int

## Ce qu'il ajoute au plafond de places du roster. 0 pour tout ce qui n'est pas une
## habitation.
##
## Champ plat et non bloc, exactement comme storage_bonus juste au-dessus, et pour la
## même raison : c'est un nombre qui relève un plafond global, pas une nature de
## bâtiment. La doctrine du zéro ne s'y applique donc pas non plus — douze bâtiments
## sur treize ne logent personne, et le réclamer refuserait de démarrer sur des données
## correctes.
##
## Entré à W1 avec le système qui le lit, comme DESIGN.md 4.1 l'avait annoncé à E1b.
@export_range(0, 20, 1) var roster_places: int

## Ce décalage, pivoté de `turns` quarts de tour dans le sens horaire.
##
## La grille va +x vers la droite et +y vers le fond, ce que le monde reprend en +X et
## +Z : vue de dessus, un quart de tour horaire envoie donc (x, y) sur (-y, x).
##
## L'ancre est le décalage (0, 0), et elle est **invariante** par cette
## transformation. C'est ce qui fait tenir tout le reste : une empreinte pivotée
## contient toujours son ancre, donc missing_fields() n'a rien à revérifier et la forme
## pivote sous le curseur au lieu de sauter à côté.
##
## `turns` est ramené dans [0, 3] : un appelant qui compte les crans sans jamais les
## replier — comme le fait CameraRig — n'a pas à s'en soucier.
static func rotate_offset(offset: Vector2i, turns: int) -> Vector2i:
	var rotated := offset
	for _turn in posmod(turns, QUARTER_TURNS):
		rotated = Vector2i(-rotated.y, rotated.x)
	return rotated

## Cellules absolues qu'une pose sur cette ancre couvrirait, dans cette orientation.
##
## L'ordre est celui de l'empreinte, donc identique d'un appel et d'un run à l'autre.
## Tout ce qui itère sur les cellules d'un bâtiment en dépend pour rester déterministe.
func cells_at(anchor: Vector2i, turns: int = 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in footprint:
		cells.append(anchor + rotate_offset(offset, turns))
	return cells

## Rectangle englobant de l'empreinte posée sur cette ancre.
##
## Sur une forme en L il couvre des cellules que le bâtiment n'occupe pas : c'est une
## enveloppe, pas l'empreinte. Ne pas s'en servir pour tester la constructibilité.
##
## Précondition : empreinte non vide.
func bounds_at(anchor: Vector2i, turns: int = 0) -> Rect2i:
	assert(not footprint.is_empty(), "empreinte vide sur %s" % id)
	var first := rotate_offset(footprint[0], turns)
	var low := first
	var high := first
	for offset in footprint:
		var rotated := rotate_offset(offset, turns)
		low = Vector2i(mini(low.x, rotated.x), mini(low.y, rotated.y))
		high = Vector2i(maxi(high.x, rotated.x), maxi(high.y, rotated.y))
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
func neighbourhood_at(anchor: Vector2i, radius: int, turns: int = 0) -> Rect2i:
	assert(radius >= 0, "rayon de voisinage négatif : %d" % radius)
	return bounds_at(anchor, turns).grow(radius)

## Ce bâtiment tient-il des postes de production ?
##
## Une méthode plutôt qu'un `production != null` recopié partout : la nullité est la
## façon dont E1b représente « ne produit pas », et le jour où le bloc devient une
## classe de base, cette question restera posée au même endroit.
func produces() -> bool:
	return production != null

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
	if color == UNSET_COLOR:
		missing.append("color")
	if height <= 0.0:
		missing.append("height")
	# Hors du bloc économie : le chantier est un chiffre de la Construction et les
	# places de roster un chiffre des Effectifs. Les ranger avec le coût et la réserve
	# ferait mentir le nom de cette fonction.
	if build_actions < 0:
		missing.append("build_actions")
	if roster_places < 0:
		missing.append("roster_places")
	missing.append_array(_economy_fields())
	if footprint.is_empty():
		missing.append("footprint")
		return missing
	if not footprint.has(Vector2i.ZERO):
		missing.append("footprint.anchor")
	if _has_duplicate_offset():
		missing.append("footprint.duplicate")
	return missing

## Incohérences du bloc économie.
##
## Ici la doctrine « non renseigné vaut 0, donc détectable » **ne s'applique pas** : un
## coût vide et un storage_bonus nul sont deux valeurs légitimes du tableau de
## DESIGN.md 4.1 — la cabane de bûcheron est gratuite, presque rien ne stocke. Les
## réclamer refuserait de démarrer sur des données correctes.
##
## Ce que E1 devait ajouter ici et qui n'y est plus : le contrôle de cohérence entre
## slots, rendement et famille. La doctrine du zéro s'applique de nouveau à ces
## trois-là depuis qu'ils ont quitté ce fichier, et ProductionBlock les réclame
## simplement — un bloc qui existe produit. C'est le gain du jalon, et il se lit à ce
## que cette fonction a perdu.
##
## Les clés de cost ne sont pas contrôlées ici, ni celles du rendement dans le bloc :
## une Resource de schéma ne lit jamais l'index. C'est GameDatabase qui les confronte
## au catalogue.
func _economy_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if storage_bonus < 0:
		missing.append("storage_bonus")
	for resource in cost:
		if cost[resource] <= 0:
			missing.append("cost.%s" % resource)
	if production == null:
		return missing
	for field in production.missing_fields():
		missing.append("production.%s" % field)
	return missing

## L'empreinte nomme-t-elle deux fois la même cellule ?
func _has_duplicate_offset() -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	for offset in footprint:
		if seen.has(offset):
			return true
		seen[offset] = true
	return false
