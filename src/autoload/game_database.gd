extends Node
## Charge et indexe les .tres de data/ au boot.
##
## L'index a deux niveaux : la catégorie est le sous-dossier de data/, l'identifiant
## est le nom de fichier sans extension. data/buildings/sawmill.tres est donc indexé
## sous (&"buildings", &"sawmill"). Le scan ne descend pas plus bas qu'un niveau.
##
## Couche adapter : le domaine ne lit jamais ce singleton. On lui passe en argument
## les Resource dont il a besoin.

const DATA_ROOT := "res://data"
const CATEGORY_BALANCE := &"balance"
const CATEGORY_TERRAIN := &"terrain"
const CATEGORY_BUILDINGS := &"buildings"
const CATEGORY_COMMODITIES := &"commodities"
const ID_BALANCE := &"balance"

## Catégorie -> (identifiant -> Resource).
var _index: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	_index.clear()
	_scan(DATA_ROOT)
	_assert_balance_is_complete()
	_assert_terrain_is_complete()
	_assert_buildings_are_complete()
	_assert_commodities_are_complete()
	_assert_resources_are_known()
	_assert_a_shelter_is_free()
	EventBus.database_ready.emit.call_deferred()

## Racine de l'équilibrage. Jamais null une fois le boot passé.
func get_balance() -> BalanceData:
	return get_resource(CATEGORY_BALANCE, ID_BALANCE) as BalanceData

## Terrain indexé, ou null si l'identifiant est inconnu.
func get_terrain(id: StringName) -> TerrainData:
	return get_resource(CATEGORY_TERRAIN, id) as TerrainData

## Identifiants de terrain connus, triés.
func list_terrain_ids() -> Array[StringName]:
	return list_ids(CATEGORY_TERRAIN)

## Bâtiment indexé, ou null si l'identifiant est inconnu.
func get_building(id: StringName) -> BuildingData:
	return get_resource(CATEGORY_BUILDINGS, id) as BuildingData

## Identifiants de bâtiment connus, triés.
func list_building_ids() -> Array[StringName]:
	return list_ids(CATEGORY_BUILDINGS)

## Ressource indexée, ou null si l'identifiant est inconnu.
func get_commodity(id: StringName) -> CommodityData:
	return get_resource(CATEGORY_COMMODITIES, id) as CommodityData

## Identifiants de ressource connus, triés.
func list_commodity_ids() -> Array[StringName]:
	return list_ids(CATEGORY_COMMODITIES)
## Resource indexée, ou null si la paire (catégorie, identifiant) est inconnue.
func get_resource(category: StringName, id: StringName) -> Resource:
	var bucket: Dictionary = _index.get(category, {})
	return bucket.get(id)

## Identifiants connus d'une catégorie, triés. Vide si la catégorie est inconnue.
func list_ids(category: StringName) -> Array[StringName]:
	var bucket: Dictionary = _index.get(category, {})
	var ids: Array[StringName] = []
	ids.assign(bucket.keys())
	return _sorted(ids)

## Catégories indexées, triées.
func list_categories() -> Array[StringName]:
	var categories: Array[StringName] = []
	categories.assign(_index.keys())
	return _sorted(categories)

## Un champ d'équilibrage non renseigné vaut 0 — les Resource de src/schema/ ne portent
## aucun défaut, pour que le chiffre reste dans data/. Le rattraper au boot évite qu'il
## se propage silencieusement dans une division ou une géométrie plate.
func _assert_balance_is_complete() -> void:
	var balance := get_balance()
	assert(balance != null,
		"data/balance/balance.tres est introuvable ou n'est pas une BalanceData")
	if balance == null:
		return
	var missing := balance.missing_fields()
	assert(missing.is_empty(),
		"champs d'équilibrage non renseignés dans data/balance/ : %s" % ", ".join(missing))

## Même contrôle sur les terrains : un TerrainData sans constructibilité renseignée
## se lirait comme non constructible, et la carte deviendrait muette au placement.
func _assert_terrain_is_complete() -> void:
	for id in list_terrain_ids():
		var terrain := get_terrain(id)
		assert(terrain != null, "data/terrain/%s.tres n'est pas un TerrainData" % id)
		if terrain == null:
			continue
		var missing := terrain.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/terrain/%s.tres : %s" % [id, ", ".join(missing)])

## Et sur les bâtiments : une empreinte vide, sans son ancre ou nommant deux fois la
## même cellule se charge sans erreur et ne casse qu'au moment de poser. La rattraper
## au boot vaut mieux que de la découvrir sous le curseur.
##
## Troisième copie de la même boucle, comme BalanceData recopie l'agrégation de ses
## blocs : il n'existe pas de classe parente commune aux Resource de src/schema/, et
## passer par une Resource nue pour appeler missing_fields() rendrait l'appel non
## typé. Le jour où il y aura six catégories, une base commune vaudra le coup.
func _assert_buildings_are_complete() -> void:
	for id in list_building_ids():
		var building := get_building(id)
		assert(building != null, "data/buildings/%s.tres n'est pas un BuildingData" % id)
		if building == null:
			continue
		var missing := building.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/buildings/%s.tres : %s" % [id, ", ".join(missing)])

## Et sur les ressources : sans libellé ni couleur, le HUD n'aurait rien à afficher.
##
## Quatrième copie de la même boucle. Le seuil annoncé à C1 — « le jour où il y aura
## six catégories, une base commune vaudra le coup » — se rapproche, mais l'écrire
## maintenant reviendrait à passer par une Resource nue pour appeler missing_fields(),
## donc à perdre le typage sur les quatre.
func _assert_commodities_are_complete() -> void:
	for id in list_commodity_ids():
		var commodity := get_commodity(id)
		assert(commodity != null, "data/commodities/%s.tres n'est pas une CommodityData" % id)
		if commodity == null:
			continue
		var missing := commodity.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/commodities/%s.tres : %s"
				% [id, ", ".join(missing)])
## Les identifiants de ressource nommés ailleurs existent-ils dans le catalogue ?
##
## C'est le seul contrôle que les Resource de src/schema/ ne peuvent pas faire
## elles-mêmes : ni une BuildingData ni une EconomyBalance ne lit l'index, et c'est
## très bien ainsi. Sans lui, un &"wodo" dans un coût créerait une ressource fantôme
## qui se stockerait, ne s'achèterait jamais et ne s'afficherait nulle part.
func _assert_resources_are_known() -> void:
	var known := list_commodity_ids()
	if known.is_empty():
		return
	var balance := get_balance()
	if balance != null and balance.economy != null:
		_assert_known(known, balance.economy.upkeep_resource,
			"balance/economy_balance.tres → upkeep_resource")
		for resource in balance.economy.starting_stock:
			_assert_known(known, resource, "balance/economy_balance.tres → starting_stock")
	for id in list_building_ids():
		var building := get_building(id)
		if building == null:
			continue
		for resource in building.cost:
			_assert_known(known, resource, "buildings/%s.tres → cost" % id)
		if not building.produces():
			continue
		for resource in building.production.yield_per_turn:
			_assert_known(known, resource,
				"buildings/%s.tres → production.yield_per_turn" % id)
## Cette ressource figure-t-elle au catalogue ?
## Existe-t-il un bâtiment qui loge sans coûter de travailleur ?
##
## C'est **l'interdit de blocage** de DESIGN.md 3.4, et c'est le seul contrôle du boot qui
## protège une règle de jeu plutôt qu'un champ de data.
##
## Sans lui, une partie peut mourir debout : tous les habitants immobilisés dans des
## bâtiments, le logement plein, donc plus un bras libre pour ouvrir un chantier et plus une
## place pour faire venir quelqu'un. Rien ne plante — le joueur clique et rien ne se passe,
## pour toujours.
##
## La soupape est l'habitation gratuite en bras : tant qu'il reste du bois et une case
## plate, on relève le plafond, la population repart, les bras reviennent. Encore faut-il
## qu'un tel bâtiment existe dans le catalogue, et c'est cette ligne qui le garantit.
##
## Il est ici et non dans BuildingData.missing_fields() parce qu'une BuildingData ne voit
## qu'elle-même : elle ne peut pas savoir qu'un *autre* bâtiment offre la sortie. C'est la
## question que CLAUDE.md fait poser avant tout missing_fields() — *cette Resource a-t-elle
## sous les yeux tout ce que la règle regarde ?* —, et la réponse est non, donc la règle
## monte d'un cran. Même partage que la règle du tour perdu, montée de PhaseDef à RunBalance
## dans le jeu d'avant.
##
## Il ne réclame pas que **tout** bâtiment qui loge soit gratuit : un manoir cher en bras
## resterait légitime. Un seul suffit à garder la porte ouverte.
##
## **Le bâtiment d'ouverture ne compte pas**, et c'est `I3` qui l'a trouvé en rendant le run
## jouable. Le Cœur loge quatre personnes et ne coûte aucun bras, donc il satisfaisait ce
## contrôle à lui seul — mais il est **posé une fois, à la fondation**, et aucun geste du
## jeu ne permet d'en bâtir un second. La soupape qu'il semblait offrir ne s'ouvre jamais.
## Le garde-fou de `N1` aurait donc laissé passer un catalogue où l'habitation coûte des
## bras, c'est-à-dire exactement la partie mortellement bloquée qu'il existe pour interdire.
##
## C'est la même famille de défaut que la règle qu'il protège : **une soupape se joue, elle
## ne se déclare pas.** `N1` l'avait écrit du mécanisme, et le contrôle lui-même y était
## soumis sans qu'on le voie — il vérifiait qu'un bâtiment gratuit *existe*, pas qu'on
## puisse le *bâtir*. Il fallait un tour pour que la différence se voie.
func _assert_a_shelter_is_free() -> void:
	var ids := list_building_ids()
	if ids.is_empty():
		return
	var balance := get_balance()
	var opener := &"" if balance == null or balance.run == null \
		else balance.run.starting_building
	for id in ids:
		if id == opener:
			continue
		var building := get_building(id)
		if building != null and building.housing > 0 and building.workers == 0:
			return
	assert(false,
		"aucun bâtiment constructible de data/buildings/ ne loge sans coûter de travailleur : "
		+ "une partie dont tout le monde est immobilisé ne pourrait plus rien bâtir")

func _assert_known(known: Array[StringName], resource: StringName, where: String) -> void:
	if known.has(resource):
		return
	var catalogue := PackedStringArray()
	for id in known:
		catalogue.append(String(id))
	assert(false, "ressource inconnue « %s » dans data/%s — le catalogue contient : %s"
		% [resource, where, ", ".join(catalogue)])

## Trie des StringName par leur texte.
##
## Array.sort() ne convient pas ici : comparer deux StringName compare leurs
## pointeurs internes et non leur contenu. L'ordre obtenu est arbitraire — stable
## le temps d'une session, différent à la suivante.
func _sorted(names: Array[StringName]) -> Array[StringName]:
	names.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second))
	return names

func _scan(root: String) -> void:
	for directory in DirAccess.get_directories_at(root):
		_scan_category(StringName(directory), root.path_join(directory))

func _scan_category(category: StringName, directory: String) -> void:
	var bucket: Dictionary[StringName, Resource] = {}
	for file in DirAccess.get_files_at(directory):
		var logical := _logical_name(file)
		if logical.is_empty():
			continue
		var resource := ResourceLoader.load(directory.path_join(logical))
		assert(resource != null, "échec du chargement de %s" % directory.path_join(logical))
		if resource == null:
			continue
		bucket[StringName(logical.get_basename())] = resource
	if not bucket.is_empty():
		_index[category] = bucket

## Nom de fichier réel d'un .tres, ou "" si l'entrée n'en est pas un.
## Un export binaire remappe data/x.tres en data/x.tres.remap : le chemin logique
## à charger reste x.tres, c'est le loader qui suit le remap.
func _logical_name(file: String) -> String:
	var logical := file
	if logical.ends_with(".remap"):
		logical = logical.get_basename()
	if logical.get_extension() != "tres":
		return ""
	return logical
