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
const CATEGORY_CARDS := &"cards"
const CATEGORY_WAVES := &"waves"
const CATEGORY_ENEMIES := &"enemies"
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
	_assert_cards_are_complete()
	_assert_waves_are_complete()
	_assert_enemies_are_complete()
	_assert_resources_are_known()
	_assert_cards_are_known()
	_assert_enemies_are_known()
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

## Carte indexée, ou null si l'identifiant est inconnu.
func get_card(id: StringName) -> CardData:
	return get_resource(CATEGORY_CARDS, id) as CardData

## Identifiants de carte connus, triés.
##
## Le tri compte plus ici qu'ailleurs : c'est dans cet ordre que le CardCatalogue reçoit
## les cartes, et c'est cet ordre que les offres de draft mélangent. Un catalogue chargé
## dans l'ordre d'un DirAccess tirerait différemment d'une machine à l'autre sur le même
## seed.
func list_card_ids() -> Array[StringName]:
	return list_ids(CATEGORY_CARDS)

## Vague indexée, ou null si l'identifiant est inconnu.
func get_wave(id: StringName) -> WaveDef:
	return get_resource(CATEGORY_WAVES, id) as WaveDef

## Identifiants de vague connus, triés.
func list_wave_ids() -> Array[StringName]:
	return list_ids(CATEGORY_WAVES)

## Assaillant indexé, ou null si l'identifiant est inconnu.
func get_enemy(id: StringName) -> EnemyData:
	return get_resource(CATEGORY_ENEMIES, id) as EnemyData

## Identifiants des assaillants, triés.
func list_enemy_ids() -> Array[StringName]:
	return list_ids(CATEGORY_ENEMIES)

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

## Et sur les cartes : un pool non renseigné rangerait la carte nulle part, et elle
## serait possédée sans jamais pouvoir être piochée.
##
## Cinquième copie de la même boucle. Le seuil annoncé à C1 — « le jour où il y aura six
## catégories, une base commune vaudra le coup » — n'est toujours pas franchi, et
## l'écrire maintenant coûterait le typage des cinq : il faudrait passer par une Resource
## nue pour appeler missing_fields().
func _assert_cards_are_complete() -> void:
	for id in list_card_ids():
		var card := get_card(id)
		assert(card != null, "data/cards/%s.tres n'est pas une CardData" % id)
		if card == null:
			continue
		var missing := card.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/cards/%s.tres : %s" % [id, ", ".join(missing)])

## Et sur les vagues : une puissance à zéro se contient toute seule, donc un fichier vide
## se lirait comme une vague facile au lieu de se signaler.
##
## Sixième copie de la même boucle, et le seuil annoncé à C1 est franchi — « le jour où il
## y aura six catégories, une base commune vaudra le coup ». Il ne l'a toujours pas : la
## base commune exigerait de passer par une Resource nue pour appeler missing_fields(), ce
## qui coûterait le typage des six. Le seuil était mal choisi, et c'est la sixième
## répétition qui le montre — ce n'est pas leur nombre qui déciderait, c'est le jour où
## GDScript saura contraindre une classe de base de Resource sans perdre le type.
func _assert_waves_are_complete() -> void:
	for id in list_wave_ids():
		var wave := get_wave(id)
		assert(wave != null, "data/waves/%s.tres n'est pas une WaveDef" % id)
		if wave == null:
			continue
		var missing := wave.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/waves/%s.tres : %s" % [id, ", ".join(missing)])

## Chaque assaillant de data/enemies/ est-il exploitable ?
##
## Septième répétition du même balayage, et le commentaire ci-dessus vaut toujours : ce
## n'est pas leur nombre qui déciderait de les factoriser, c'est le jour où GDScript saura
## contraindre une classe de base de Resource sans perdre le type.
func _assert_enemies_are_complete() -> void:
	for id in list_enemy_ids():
		var enemy := get_enemy(id)
		assert(enemy != null, "data/enemies/%s.tres n'est pas une EnemyData" % id)
		if enemy == null:
			continue
		var missing := enemy.missing_fields()
		assert(missing.is_empty(),
			"champs non renseignés dans data/enemies/%s.tres : %s"
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
	if balance != null and balance.actions != null:
		for card in balance.actions.bare_sources:
			for resource in balance.actions.sources_for(card).values():
				_assert_known(known, resource,
					"balance/action_balance.tres → bare_sources.%s" % card)
	for id in list_building_ids():
		var building := get_building(id)
		if building == null:
			continue
		for resource in building.cost:
			_assert_known(known, resource, "buildings/%s.tres → cost" % id)
		if not building.produces():
			continue
		for resource in building.production.yield_per_slot:
			_assert_known(known, resource,
				"buildings/%s.tres → production.yield_per_slot" % id)

## Ce que les cartes et le deck de départ nomment existe-t-il ?
##
## Même rôle que _assert_resources_are_known() juste au-dessus, et même raison d'être
## ici plutôt que dans le schéma : ni une CardData ni une DeckBalance ne lit l'index.
## Sans ce contrôle, une carte de bâtiment mal orthographiée ne casserait qu'à D2 sous
## le curseur, et un deck de départ nommant une carte disparue se composerait
## silencieusement avec un exemplaire de moins.
func _assert_cards_are_known() -> void:
	var known := list_card_ids()
	if known.is_empty():
		return
	var buildings := list_building_ids()
	for id in known:
		var card := get_card(id)
		if card == null or not card.places_a_building():
			continue
		assert(buildings.has(card.building),
			"la carte data/cards/%s.tres pose un bâtiment inconnu : %s" % [id, card.building])
	var balance := get_balance()
	if balance == null or balance.deck == null:
		return
	for card in balance.deck.starting_deck:
		assert(known.has(card),
			"carte inconnue « %s » dans balance/deck_balance.tres → starting_deck" % card)

## Les assaillants que les vagues nomment existent-ils ?
##
## Troisième contrôle croisé après les ressources et les cartes, et il est ici pour la même
## raison qu'eux : une WaveDef ne lit pas l'index, et c'est très bien ainsi. Sans lui, un
## &"raidre" dans une composition ferait entrer une vague avec un corps de moins, en
## silence — le défaut exact qu'un deck de départ mal orthographié aurait eu.
func _assert_enemies_are_known() -> void:
	var known := list_enemy_ids()
	if known.is_empty():
		return
	for id in list_wave_ids():
		var wave := get_wave(id)
		if wave == null:
			continue
		for enemy in wave.roster:
			assert(known.has(enemy),
				"la vague data/waves/%s.tres appelle un assaillant inconnu : %s"
					% [id, enemy])

## Cette ressource figure-t-elle au catalogue ?
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
