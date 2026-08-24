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
const ID_BALANCE := &"balance"

## Catégorie -> (identifiant -> Resource).
var _index: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	_index.clear()
	_scan(DATA_ROOT)
	_assert_balance_is_complete()
	_assert_terrain_is_complete()
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
