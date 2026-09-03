class_name BuildingData
extends Resource
## Un bâtiment tel que le contenu le décrit : son identité et son empreinte.
##
## Les .tres vivent dans data/buildings/, un par bâtiment. Le domaine les reçoit en
## argument et ne lit jamais GameDatabase, comme pour TerrainData.
##
## C1 n'y mettait que ce que le placement consomme ; E1 y ajoute l'économie — coût,
## réserve, et la production à plat —, E1b sort cette dernière dans un bloc nullable, C4 le
## coût de chantier, F1 les PV, et N1 le coût en travailleurs et le plafond de logement.
## Seuls les quatre chiffres de défense de V2 restent dehors, de la même façon que BalanceData
## gagne un bloc quand un système atterrit. Un champ ajouté plus tard oblige à rouvrir les
## .tres ; un champ ajouté d'avance oblige à deviner sa forme, ce qui coûte plus cher.
##
## **C3 a fait le chemin inverse et retiré `production`.** Le bloc nullable d'E1b décrivait un
## rendement dû au seul fait d'exister ; il n'y en a plus, et ce qu'un bâtiment rend se lit
## désormais sur le sol autour de lui. C'est la deuxième fois qu'un champ de ce fichier part
## faute de lecteur — `defense` à I3 —, et la seule où c'est le **modèle** qui a changé.
##
## **I3 lui a retiré `defense`**, dernier résidu du combat tactique. DESIGN.md 4.1 : « La
## palissade perd sa `defense` et garde ses points de vie […] elle ne défend plus par un
## chiffre abstrait, parce qu'il n'y a plus de total de défense à opposer à une puissance. »
## Le champ valait 3 dans un .tres et **aucun système ne le lisait** — même geste que N1 sur
## les deux tiers du bloc de production. Ce qui le remplace est portée / dégâts / cadence, et
## c'est V2 qui l'écrit, avec le système qui le lit.
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

## Nom affichable, celui de la colonne Bâtiment de DESIGN.md 4.1.
##
## Il entre à N2 avec la fiche qui le lit, et **il ne nomme rien de neuf** : les neuf noms
## sont ceux que 4.1 a fixés, recopiés dans la data au lieu de rester dans un tableau de
## document. Sans lui la fiche d'un bâtiment s'intitule `lumberjack_hut`, c'est-à-dire un
## identifiant interne montré à qui regarde le jeu.
##
## Même partage que CommodityData, et pour la même raison qu'à E2 : un identifiant sert le
## code, un libellé sert l'écran, et le second n'a aucune raison d'être le premier traduit à
## la volée par un adapter. Il est **réclamé** comme là-bas — un libellé vide se lit comme
## une case blanche, ce qui est détectable, et la doctrine du zéro s'applique.
@export var label: String

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

## Le modèle dessiné, ou **null** pour la boîte colorée d'avant.
##
## Se choisit dans l'inspecteur : n'importe quel `.obj` de `assets/` s'importe en `Mesh` et
## apparaît dans le sélecteur. Changer l'allure d'un bâtiment est donc une édition de data, au
## même titre que sa couleur — le renderer, lui, ne connaît toujours aucun bâtiment par son nom.
##
## **Nullable, et le repli n'est pas honteux.** Un bâtiment sans modèle retrouve la boîte par
## cellule de `C1`, qui reste le seul rendu honnête d'une empreinte en L : un volume unique
## couvrirait le trou de l'enveloppe et mentirait sur la forme. C'est aussi ce qui permet
## d'ajouter un bâtiment et de le voir avant de lui avoir trouvé un asset.
@export var model: Mesh

## Combien de cases le modèle couvre en largeur.
##
## **Une envergure en cases et non un facteur d'échelle**, pour la raison exposée dans
## `ModelFit` : les assets d'un pack arrivent à la taille de leur monde, pas de la nôtre, et un
## facteur serait à retrouver asset par asset. Ce chiffre-ci parle du jeu — « la ferme couvre
## deux cases de large » — et survit à un changement de pack.
##
## Rien ne l'oblige à valoir l'empreinte : un toit peut avancer sur la rue, et une cabane peut
## se tenir au milieu de sa case sans la remplir. L'empreinte reste la seule vérité sur ce qu'un
## bâtiment **occupe** ; ceci ne dit que ce qu'il **montre**.
##
## Réclamé quand un modèle est là, ignoré sinon : à zéro, l'asset serait invisible et l'on
## chercherait longtemps pourquoi.
@export_range(0.0, 8.0, 0.05) var model_span: float

## Quarts de tour à appliquer au modèle **en plus** de l'orientation du bâtiment.
##
## Les assets d'un pack ne regardent pas tous dans la même direction, et rien n'oblige celle du
## pack à être la nôtre. Ce champ recale un modèle une fois pour toutes, dans sa data, plutôt
## que de faire tourner l'empreinte pour l'apparence — ce qui déplacerait ce que le bâtiment
## occupe pour corriger ce qu'il montre.
##
## 0 est la valeur la plus fréquente et parfaitement légitime : la doctrine du zéro ne s'y
## applique pas.
@export_range(0, 3, 1) var model_turns: int

## Hauteur de la boîte, en **fractions de tuile** et non en unités de monde.
##
## C'est la leçon des décorations à T3 : régler tile_size doit redimensionner la carte
## entière, bâtiments compris, et non laisser des maisons à leur ancienne taille au
## milieu de cellules qui ont changé.
@export_range(0.0, 4.0, 0.05) var height: float

## Combien de **tours** son chantier dure.
##
## C'est la colonne **Chantier** de DESIGN.md 4.1. Ouvrir un chantier n'est pas poser un
## bâtiment : il occupe ses cellules, paie son coût et immobilise ses bras tout de suite,
## mais ne produit rien et ne relève aucun plafond avant d'avoir reçu ce nombre de crans.
##
## **Un cran par tour, et personne ne le lui donne.** DESIGN.md 3.2 : « Chaque tour, chaque
## chantier ouvert avance d'un cran. » Le champ s'appelait `build_actions` jusqu'à I3, et
## le renommage n'est pas cosmétique : il comptait les actions *Construire* d'un deck que
## le rescope a supprimé, c'est-à-dire « autant de cartes qu'il faudra piocher ». Le
## chiffre est le même, ce qu'il compte a changé de nature — même geste que
## `upkeep_per_worker` → `upkeep_per_inhabitant` à N1.
##
## **0 est une valeur légitime** et veut dire « achevé à la pose ». La doctrine du zéro
## ne s'applique donc pas ici, exactement comme pour storage_bonus et housing
## juste en dessous — mais pour une raison qui lui est propre : le Cœur porte « — »
## dans cette colonne, comme il porte « posé au départ » dans celle du coût, et c'est
## déjà un cost vide qui représente la seconde. Représenter la première par un zéro est
## le même geste sur la même ligne du tableau.
##
## Le prix de ce choix est connu : un site_turns oublié dans un .tres vaut 0 et fait
## sauter le chantier en silence. Il est racheté par un cas de test qui charge tout
## data/ et exige qu'au moins un bâtiment en déclare un — un contrôle qui refuse de passer
## par vacuité.
##
## Il ne s'appelle pas `turns` tout court : ce nom désigne déjà les quarts de tour d'une
## orientation, partout dans le système — y compris sur le PlacedBuilding qui porte le
## chantier. Les confondre fabrique un bâtiment fini là où l'on croyait poser un chantier,
## ce qu'un cas de test de N1 a payé pour de vrai.
@export_range(0, 10, 1) var site_turns: int

## Anneaux dont il étend le territoire constructible du village, une fois **achevé**.
##
## Colonne **Emprise** de DESIGN.md 4.1, et à ne pas confondre avec la portée d'un tir que V2
## écrira. C'est ce qui fait qu'on bâtit près de chez soi puis un peu plus loin : le Cœur ouvre
## le premier disque, chaque bâtiment fini ajoute le sien, et ce qu'on peut poser est la
## **réunion** de tous. Le contour cesse d'être un cercle dès le deuxième — il pousse vers ce
## que le village est allé chercher.
##
## **Réclamé, et un minimum de 1.** Zéro serait une valeur défendable — « ce bâtiment n'étend
## rien au-delà de lui-même » — et c'est justement pour ça qu'il est refusé : indiscernable
## d'un champ oublié, il ferait d'un `.tres` incomplet un bâtiment qui rétrécit le jeu en
## silence. Tout ce qui tient debout revendique au moins la terre qu'il touche.
@export_range(1, 32, 1) var reach: int

## Ce qu'il coûte à poser, par ressource.
##
## Le coût ne participe **pas** à la validation du placement : « ai-je les 15 bois ? »
## ne regarde pas la carte, et c'est la couche qui orchestre la journée qui enchaîne
## les deux questions. Tranché à C1, voir DESIGN.md 3.2.
@export var cost: Dictionary[StringName, int]

## Ce qu'il produit, et **d'où** : une entrée par règle de voisinage. Vide s'il ne produit
## rien — ce qui est le cas de cinq bâtiments sur neuf.
##
## **Ce champ a remplacé `production` à `C3`**, et ce n'est pas un renommage. Un bloc de
## production déclarait un rendement à plat, dû au seul fait d'exister ; une règle dit ce que le
## sol autour rapporte. Un camp de bûcheron ne rend plus du bois parce qu'il est un camp de
## bûcheron, il en rend parce qu'il y a des arbres — et deux fois plus s'il y en a deux fois plus.
##
## Une **liste** et non un bloc nullable : chaque règle est déjà une `Resource` qui réclame ses
## quatre champs, donc un bloc englobant n'ajouterait rien à la doctrine du zéro — et un
## bâtiment peut vouloir deux règles, ce qu'un bloc unique interdirait.
##
## Une liste non vide est aussi une **condition de pose** : `PlacementValidator` refuse un
## bâtiment dont aucune règle ne trouve de case. Voir DESIGN.md 3.2.
@export var adjacency: Array[AdjacencyRule]

## Ce qu'il ajoute à la réserve commune. 0 pour tout ce qui n'est pas un entrepôt.
##
## En réserve commune, ce chiffre ne relève pas trois compteurs indépendants mais la
## seule capacité partagée : c'est ce qui donne à l'entrepôt une valeur d'arbitrage.
@export_range(0, 500, 1) var storage_bonus: int

## Ce qu'il ajoute au plafond de logement. 0 pour tout ce qui n'est pas une habitation.
## Colonne **Loge** de DESIGN.md 4.1.
##
## Champ plat et non bloc, exactement comme storage_bonus juste au-dessus, et pour la
## même raison : c'est un nombre qui relève un plafond global, pas une nature de
## bâtiment. La doctrine du zéro ne s'y applique donc pas non plus — la plupart des
## bâtiments ne logent personne, et le réclamer refuserait de démarrer sur des données
## correctes.
##
## Il s'appelait roster_places jusqu'à N1. Le renommage suit celui d'upkeep_per_worker :
## il n'y a plus de roster, il y a un plafond d'habitants.
@export_range(0, 20, 1) var housing: int

## Travailleurs qu'il **immobilise**, payés à l'ouverture du chantier et gardés à vie.
## Colonne **Trav.** de DESIGN.md 4.1.
##
## C'est un **coût de construction**, au même titre que `cost` juste au-dessus, et la seule
## différence tient en un mot : le bois est consommé, le travailleur est immobilisé. Il
## revient au pool quand le bâtiment est démoli ou détruit.
##
## Un seul champ suffit là où le modèle écarté à N1 en aurait demandé deux — un coût de
## chantier et un besoin de fonctionnement. Ceux qui l'ont bâti sont ceux qui y vivent.
##
## 0 est légitime et fréquent : une palissade ne loge aucun ouvrier. Mais un zéro est
## **obligatoire quelque part**, et c'est la seule règle de ce fichier qu'il ne peut pas
## vérifier lui-même : si aucun bâtiment qui loge n'était gratuit en travailleurs, une
## partie dont tout le monde est immobilisé et le logement plein ne pourrait plus rien
## bâtir — jamais. C'est GameDatabase qui tient cette règle, parce qu'elle regarde le
## catalogue entier et qu'une BuildingData ne voit qu'elle-même.
@export_range(0, 20, 1) var workers: int

## Ce qu'il encaisse avant de tomber. Colonne **PV** de DESIGN.md 4.1.
##
## **Réclamé**, à l'inverse des trois champs plats ci-dessus, et c'est le seul de la
## famille à l'être : un bâtiment à 0 PV tombe au premier coup sans que rien ne le
## signale, et la doctrine du zéro s'applique donc pleinement. Un entrepôt qui ne stocke
## rien est un choix de contenu ; un entrepôt qui n'existe plus dès la première vague est
## un .tres qu'on a oublié de remplir.
##
## Un **chantier** a les PV du bâtiment fini. Ce n'est pas un oubli : l'avancement n'est
## pas une barre de vie, et les mélanger ferait qu'un chantier bien avancé encaisserait
## mieux qu'un neuf, ce que rien dans DESIGN.md ne demande. Ce que 3.2 demande est qu'un
## chantier soit une **perte** quand il tombe, et interrupted() le dit.
@export_range(0, 100, 1) var hit_points: int

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

## Le centre de l'empreinte posée sur cette ancre, en cellules, décimales comprises.
##
## Une empreinte de deux par deux a son centre **entre** quatre cases : c'est le point sur
## lequel un modèle se pose, et il n'a aucune raison de tomber sur une case. Sur une forme en L
## il penche du côté du plein, ce qui est ce qu'on veut — un bâtiment se dessine autour de sa
## masse, pas autour du coin de son enveloppe.
##
## Il est calculé sur les cellules **déjà pivotées**, donc il suit l'orientation sans qu'aucun
## appelant ait à s'en occuper. Précondition : empreinte non vide.
func centre_at(anchor: Vector2i, turns: int = 0) -> Vector2:
	assert(not footprint.is_empty(), "empreinte vide sur %s" % id)
	var sum := Vector2.ZERO
	for cell in cells_at(anchor, turns):
		sum += Vector2(cell)
	return sum / float(footprint.size())

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

## Ce bâtiment produit-il quelque chose ?
##
## Une méthode plutôt qu'un `adjacency.is_empty()` recopié partout — c'était déjà l'argument
## quand elle répondait `production != null`, et il n'a pas bougé en changeant de réponse. Ce
## qui a changé est ce que « produire » veut dire : posséder une raison de produire, et non un
## chiffre à verser.
func produces() -> bool:
	return not adjacency.is_empty()

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
	if label.is_empty():
		missing.append("label")
	if color == UNSET_COLOR:
		missing.append("color")
	if height <= 0.0:
		missing.append("height")
	# Hors du bloc économie : le chantier est un chiffre de la Construction et les
	# places de roster un chiffre des Effectifs. Les ranger avec le coût et la réserve
	# ferait mentir le nom de cette fonction.
	if site_turns < 0:
		missing.append("site_turns")
	if housing < 0:
		missing.append("housing")
	if workers < 0:
		missing.append("workers")
	# Réclamé, contrairement aux champs plats ci-dessus : voir son docstring.
	if hit_points <= 0:
		missing.append("hit_points")
	if reach < 1:
		missing.append("reach")
	missing.append_array(_economy_fields())
	missing.append_array(_adjacency_fields())
	# Réclamé seulement quand un modèle est là : c'est la même cohérence structurelle que le
	# bloc de production nullable d'`E1b`, et elle vaut ici pour une raison très concrète —
	# une envergure nulle rend l'asset invisible, ce qui ne ressemble à rien de nommable.
	if model != null and model_span <= 0.0:
		missing.append("model_span")
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
	return missing

## Incohérences des règles d'adjacence, préfixées par leur rang.
##
## Le rang plutôt que le tag, parce qu'une règle dont le **tag** est justement le champ oublié
## se nommerait « adjacency[].tag » et ne désignerait rien. Un indice désigne toujours une
## ligne du .tres, y compris quand c'est son identité qui manque.
##
## Une liste vide est parfaitement légitime : cinq bâtiments sur neuf n'ont aucune règle. Ce
## qui ne l'est pas est une règle **présente et creuse**, et c'est ce que la doctrine du zéro
## attrape ici entièrement — voir AdjacencyRule.
func _adjacency_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	for index in adjacency.size():
		var rule := adjacency[index]
		if rule == null:
			missing.append("adjacency[%d]" % index)
			continue
		for field in rule.missing_fields():
			missing.append("adjacency[%d].%s" % [index, field])
	return missing

## L'empreinte nomme-t-elle deux fois la même cellule ?
func _has_duplicate_offset() -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	for offset in footprint:
		if seen.has(offset):
			return true
		seen[offset] = true
	return false
