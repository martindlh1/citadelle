class_name TerrainGen
extends RefCounted
## Génération de terrain seedée, et vérifiée.
##
## Fonction pure : même seed et mêmes réglages rendent exactement la même grille.
## C'est ce qui rend un run rejouable et un bug d'équilibrage reproductible à partir
## d'un seed et d'une suite d'actions.
##
## Le seed est passé en argument plutôt que pris sur un RNG partagé. La génération ne
## consomme donc pas le flux du run : elle se rejoue seule en test, sans dépendre de
## ce qui a été tiré avant elle.
##
## ---
##
## **Du bruit, penché par des règles qui ne se voient pas.** La première version de `T4`
## dessinait la topographie en clair — un plateau, une plaine, des rampes numérotées — et
## rendait des cartes qui tenaient toutes leurs promesses en ayant perdu ce qui faisait leur
## intérêt : on y lisait le générateur au lieu d'y lire un paysage. Elle est retirée.
##
## Ce qui reste est le bruit d'avant, **penché** : un centre un peu plus haut, un centre un
## peu plus calme, des crêtes qui barrent parce qu'elles sont hautes. Aucune de ces règles
## n'a de bord ; toutes s'ajoutent au bruit **avant** qu'il soit découpé en crans, si bien
## qu'aucune ne laisse de trace qu'on puisse montrer du doigt.
##
## Le prix est que la carte ne garantit plus rien **par construction** : c'est le bruit qui
## décide, donc un seed peut rendre une carte sans centre bâtissable ou sans aucun goulot.
## D'où l'audit et le **rejet du seed** — et d'où le fait que `MapAudit` ne sache rien de ce
## fichier. Il retrouve le replat en marchant et compte les accès en marchant, ce qui le rend
## indifférent à la technique employée : c'est ce qui permet de les essayer.
##
## `TerrainGenBalance.Shape` dit laquelle on essaie. C'est un champ d'**exploration**, et il
## se réduira à ce qu'on aura retenu.

## Décorrèle les flux de bruit. Sans ces décalages ils partiraient tous du même seed et
## leurs motifs seraient corrélés — des forêts qui suivent les lignes de crête.
const RELIEF_SEED_SALT := 0x1E5C0F17
const DETAIL_SEED_SALT := 0x2B7A9C41
const FOREST_SEED_SALT := 0x5CA77E12
const STONE_SEED_SALT := 0x6D3E8B27
const ROCK_SEED_SALT := 0x7A19F4D3

## Écart entre deux essais successifs d'un même seed.
##
## Une constante impaire et large, multipliée par le rang de l'essai : deux essais voisins
## doivent donner des cartes **sans rapport**, et `FastNoiseLite` rend des motifs proches
## pour des seeds proches. Ajouter 1 aurait redessiné la même carte à peine bougée, donc
## rejeté pour le même motif, autant de fois qu'il y a d'essais.
const ATTEMPT_STRIDE := 0x9E3779B9

## Le centre d'une carte de cette taille.
##
## Une fonction plutôt qu'un calcul recopié, parce que **trois endroits doivent tomber
## d'accord** : la génération y penche son relief, l'audit y cherche son replat, et le harnais
## y pose sa question. Deux divisions entières écrites séparément finissent par différer d'une
## case sur les tailles impaires.
static func centre_of(size: Vector2i) -> Vector2i:
	return size / 2

## Le seed du n-ième essai pour ce run.
##
## Publique parce que le harnais rejoue la même suite d'essais pour mesurer combien il en
## faut. Lui laisser réinventer la dérivation aurait été deux règles à tenir d'accord, et
## celle qu'on mesure n'aurait pas été celle qu'on joue.
static func seed_for(run_seed: int, attempt: int) -> int:
	return run_seed ^ (ATTEMPT_STRIDE * (attempt + 1))

## Grille générée pour ce seed, aux dimensions demandées, et qui tient ses promesses.
##
## Essaie des seeds dérivés jusqu'à ce que l'audit accepte, dans la limite de
## `max_attempts`. C'est le « rejet du seed » de DESIGN.md 3.1, et le plafond existe pour
## qu'un jeu de réglages impossible s'arrête en le disant plutôt que de tourner sans fin.
##
## **Épuiser les essais rend quand même une carte**, et c'est délibéré : une carte qui déçoit
## se joue, une carte absente ne se joue pas.
##
## Le signal est un `push_warning` et **non un `assert`**, ce qui est un correctif et pas un
## goût. Un `assert` qui échoue interrompt la fonction : le repli écrit juste en dessous
## n'était jamais atteint, l'appelant recevait `null`, et le harnais partait en cascade de
## milliers d'erreurs sur un plateau qui n'avait pas été monté. Le commentaire promettait une
## carte, le code n'en rendait aucune — et seul un réglage impossible pouvait le montrer.
## `CLAUDE.md` réserve d'ailleurs l'`assert` aux préconditions : un jeu de promesses trop
## serré est une **situation**, pas un bug d'appelant.
static func generate(run_seed: int, size: Vector2i, params: TerrainGenBalance) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de carte non positive : %s" % size)
	assert(params != null, "réglages de génération null")
	assert(params.missing_fields().is_empty(),
		"réglages de génération inexploitables : %s" % ", ".join(params.missing_fields()))
	var attempt := accepted_attempt(run_seed, size, params)
	if attempt < 0:
		push_warning("aucune carte jouable en %d essais sur le seed %d — réglages de %s"
			% [params.max_attempts, run_seed, "data/balance/terrain_gen_balance.tres"])
		return draft(seed_for(run_seed, params.max_attempts - 1), size, params)
	return draft(seed_for(run_seed, attempt), size, params)

## Le rang de l'essai que generate() retient, ou -1 si aucun ne tient ses promesses.
##
## **La boucle de rejet est ici et nulle part ailleurs.** `generate()` s'en sert pour rendre
## une carte, le harnais pour compter combien d'essais elle coûte : deux besoins, une seule
## écriture. Une boucle recopiée dans le harnais aurait mesuré la copie — c'est le raccourci
## que `CLAUDE.md` nomme depuis `F1`, et il se serait présenté sous sa forme la plus
## trompeuse, puisque les deux boucles auraient été justes le jour où on les a écrites.
static func accepted_attempt(run_seed: int, size: Vector2i,
		params: TerrainGenBalance) -> int:
	var centre := centre_of(size)
	for attempt in params.max_attempts:
		var grid := draft(seed_for(run_seed, attempt), size, params)
		var report := MapAudit.inspect(grid.to_query(), centre, params.max_climb)
		if MapAudit.shortcomings(report, params).is_empty():
			return attempt
	return -1

## Une carte, **sans audit ni rejet**. C'est ce que `generate()` essaie.
##
## Publique parce que la mesure en a besoin : le harnais tire deux cents brouillons pour
## imprimer la distribution de ce que la technique produit *avant* qu'on en écarte quoi que
## ce soit. Une distribution mesurée après rejet ne dirait pas si les promesses sont serrées
## ou lâches — elle serait bonne par construction.
##
## Trois passes, et les deux dernières sont communes à toutes les techniques : le relief, la
## nappe, la dispersion. Ce qui distingue une technique d'une autre tient donc entièrement
## dans `_carve_relief()`, ce qui est ce qui permet de les comparer à décor égal.
static func draft(run_seed: int, size: Vector2i, params: TerrainGenBalance) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de carte non positive : %s" % size)
	assert(params != null, "réglages de génération null")
	var grid := HeightGrid.create(size, params.min_height, params.plain)
	_carve_relief(grid, run_seed, params)
	_drain_puddles(grid, params)
	_scatter(grid, run_seed, params)
	return grid

# --- le relief --------------------------------------------------------------

## Pose la hauteur de chaque cellule, et l'eau partout où le relief passe au niveau
## de la nappe ou en dessous. L'eau est aplanie : une nappe est plate.
##
## Le champ de hauteurs est calculé **en flottant** puis découpé en crans une seule fois, à
## la toute fin. C'est ce qui rend les règles invisibles : un relèvement du centre ajouté
## après le découpage se lirait comme une marche, ajouté avant il ne se lit pas du tout.
static func _carve_relief(grid: HeightGrid, run_seed: int,
		params: TerrainGenBalance) -> void:
	var relief := _noise(run_seed ^ RELIEF_SEED_SALT, params, params.noise_frequency)
	var detail := _noise(run_seed ^ DETAIL_SEED_SALT, params,
		params.noise_frequency * params.detail_scale)
	if params.relief == TerrainGenBalance.Relief.RIDGED:
		relief.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var extent := grid.size()

	# **Le bruit est étalé d'abord, penché ensuite**, et l'ordre est tout.
	#
	# Il a été l'inverse pendant deux essais, et les deux ont raté d'une façon différente.
	# Pencher puis étaler donne une **île** : la colline pousse le centre bien au-dessus de 1,
	# l'étalement ramène tout le monde dans l'amplitude, et le pourtour se retrouve poussé
	# sous la nappe. Pencher puis **borner** donne un sommet **plat** de cent cases, c'est-à-
	# dire la mesa qu'on venait de retirer, revenue par une porte de derrière.
	#
	# Étaler d'abord règle les deux : le bruit occupe toute l'amplitude déclarée quelle que
	# soit sa nature — un bruit en crêtes se serre vers le haut et n'y arriverait pas seul —,
	# et la colline en prend ensuite une **part**, sans jamais la déborder.
	var field := PackedFloat32Array()
	field.resize(extent.x * extent.y)
	var lowest := INF
	var highest := -INF
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var unit := _unit(relief, cell)
			if params.detail_share > 0.0:
				unit = lerpf(unit, _unit(detail, cell), params.detail_share)
			field[y * extent.x + x] = unit
			lowest = minf(lowest, unit)
			highest = maxf(highest, unit)
	var span := maxf(highest - lowest, 0.0001)

	var centre := centre_of(extent)
	var middle := (field[centre.y * extent.x + centre.x] - lowest) / span
	var levels := params.max_height - params.min_height + 1
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var unit := _tilt((field[y * extent.x + x] - lowest) / span, cell, centre,
				middle, params)
			var height := params.min_height + mini(int(unit * levels), levels - 1)
			if height <= params.water_level:
				grid.set_cell(cell, params.water_level, params.water)
			else:
				grid.set_cell(cell, height, params.plain)

## Ce que les deux règles centrales font de cette hauteur, déjà étalée en [0, 1].
##
## **Trois axes qui se composent**, et chacun s'éteint en mettant son nombre à zéro : le bruit
## de fond, la colline, la clairière. Les avoir empilés dans un enum exclusif interdisait la
## combinaison qu'on cherchait — des crêtes **et** une colline au milieu.
##
## La colline prend une **part** de l'amplitude au lieu de s'y ajouter : le terrain garde son
## grain partout, il est simplement d'autant plus haut qu'on approche du milieu, et le résultat
## ne peut pas sortir de [0, 1]. C'est ce qui lui évite d'être un cône posé sur une plaine.
static func _tilt(unit: float, cell: Vector2i, centre: Vector2i, middle: float,
		params: TerrainGenBalance) -> float:
	var levels := float(maxi(params.max_height - params.min_height, 1))
	var share := clampf(params.dome_rise / levels, 0.0, 1.0)
	if share > 0.0:
		unit = unit * (1.0 - share) + share * _falloff(cell, centre, params.dome_radius)
	# Un lissage **vers la hauteur du centre**, et non un aplanissement : à pleine force on
	# retrouverait la mesa qu'on vient de retirer. Le grain survit, il se calme.
	var pull := params.clearing_flatten * _falloff(cell, centre, params.clearing_radius)
	if pull > 0.0:
		unit = lerpf(unit, middle * (1.0 - share) + share, pull)
	return clampf(unit, 0.0, 1.0)

## Ce qui reste de l'effet à cette distance du centre : 1 au centre même, 0 au-delà de la
## portée, en cloche entre les deux.
##
## En cloche et non linéaire, parce qu'une décroissance linéaire laisse une **arête** à la
## portée — la dérivée y saute — et cette arête finit par se voir comme un cercle sur la
## carte. C'est exactement le genre de bord qu'on cherche à ne pas dessiner.
static func _falloff(cell: Vector2i, centre: Vector2i, reach: int) -> float:
	if reach <= 0:
		return 0.0
	var near := Vector2(cell - centre).length() / float(reach)
	if near >= 1.0:
		return 0.0
	return 1.0 - near * near * (3.0 - 2.0 * near)

# --- l'eau ------------------------------------------------------------------

## Comble les étendues d'eau trop petites pour être des lacs.
##
## **Un lac ou rien.** Un relief découpé en crans laisse partout des cuvettes d'une ou deux
## cases sous le niveau de la nappe, et chacune ressort en bleu : la carte se retrouve
## mouchetée de flaques qui ne barrent rien, ne se contournent pas et ne veulent rien dire.
## Ce qu'on garde est ce qu'on longe.
##
## Les flaques remontent à un cran au-dessus de la nappe, c'est-à-dire au ras de leurs
## voisines les plus basses : combler n'invente pas une bosse là où il y avait un trou.
static func _drain_puddles(grid: HeightGrid, params: TerrainGenBalance) -> void:
	if params.min_lake_cells <= 1:
		return
	var extent := grid.size()
	var seen: Dictionary[Vector2i, bool] = {}
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if seen.has(cell) or grid.terrain_at(cell) != params.water:
				continue
			var pond := _pond_at(grid, params, cell, seen)
			if pond.size() >= params.min_lake_cells:
				continue
			for drained in pond:
				grid.set_cell(drained, params.water_level + 1, params.plain)

## L'étendue d'eau d'un seul tenant qui porte cette cellule.
static func _pond_at(grid: HeightGrid, params: TerrainGenBalance, from: Vector2i,
		seen: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var pond: Array[Vector2i] = [from]
	seen[from] = true
	var head := 0
	while head < pond.size():
		var cell := pond[head]
		head += 1
		for step in MapAudit.NEIGHBOURS:
			var side := cell + step
			if seen.has(side) or not grid.in_bounds(side):
				continue
			if grid.terrain_at(side) != params.water:
				continue
			seen[side] = true
			pond.append(side)
	return pond

# --- la dispersion ----------------------------------------------------------

## Répartit forêt, gisement et rocher sur les cellules émergées, **par zones**.
##
## Chaque famille a son bruit et son penchant pour l'altitude ; les cellules sont classées par
## ce score et les meilleures reçoivent le terrain, jusqu'à la part demandée. D'où des
## bosquets, des futaies, des éboulis de crête et des veines de pierre, là où un tirage par
## cellule donnait un semis régulier qui ne racontait rien.
##
## **Trois passes dans l'ordre, et l'ordre est une décision.** La forêt d'abord parce que
## c'est elle qui couvre le plus et qu'elle doit pouvoir tapisser une vallée entière ; le
## rocher en dernier parce qu'il **barre**, et qu'un caillou de plus se pose n'importe où
## alors qu'une forêt trouée se remarque.
##
## Le centre est éclairci par `clearing_calm` : le score y est rabattu, donc les familles s'y
## classent moins bien et le milieu reste dégagé. À 1, rien n'est éclairci. C'est la seconde moitié de
## « pas trop occupée », et elle compte autant que la première — un centre plat couvert de
## rochers ne se bâtit pas davantage qu'une pente.
static func _scatter(grid: HeightGrid, run_seed: int, params: TerrainGenBalance) -> void:
	var extent := grid.size()
	var free: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if grid.terrain_at(cell) != params.water:
				free.append(cell)
	var budget := free.size()
	var taken: Dictionary[Vector2i, bool] = {}
	_plant(grid, params, free, taken, run_seed ^ FOREST_SEED_SALT,
		params.forest_height_bias, int(budget * params.forest_density), params.forest,
		params.forest_max_height)
	_plant(grid, params, free, taken, run_seed ^ STONE_SEED_SALT,
		params.stone_height_bias, int(budget * params.stone_density), params.stone,
		params.max_height)
	_plant(grid, params, free, taken, run_seed ^ ROCK_SEED_SALT,
		params.rock_height_bias, int(budget * params.rock_density), params.rock,
		params.max_height)

## Pose ce terrain sur les `wanted` cellules libres qui lui conviennent le mieux.
##
## Le classement départage à score égal par la position, jamais par l'ordre du tableau : deux
## lancements doivent planter le même bois.
static func _plant(grid: HeightGrid, params: TerrainGenBalance, candidates: Array[Vector2i],
		taken: Dictionary[Vector2i, bool], noise_seed: int, bias: float, wanted: int,
		terrain: TerrainData, ceiling: int) -> void:
	if wanted <= 0:
		return
	var noise := _noise(noise_seed, params, params.noise_frequency * params.decor_scale)
	var centre := centre_of(grid.size())
	var span := float(maxi(params.max_height - params.min_height, 1))
	var scores: Dictionary[Vector2i, float] = {}
	var pool: Array[Vector2i] = []
	for cell in candidates:
		if taken.has(cell) or grid.height_at(cell) > ceiling:
			continue
		var score := _unit(noise, cell) \
			+ bias * (float(grid.height_at(cell) - params.min_height) / span)
		score *= lerpf(1.0, params.clearing_calm,
			_falloff(cell, centre, params.clearing_radius))
		scores[cell] = score
		pool.append(cell)
	pool.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		if not is_equal_approx(scores[first], scores[second]):
			return scores[first] > scores[second]
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	for index in mini(wanted, pool.size()):
		taken[pool[index]] = true
		grid.set_terrain(pool[index], terrain)

# --- le bruit ---------------------------------------------------------------

static func _noise(noise_seed: int, params: TerrainGenBalance,
		frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = params.noise_octaves
	return noise

## Le bruit de cette cellule ramené en [0, 1].
static func _unit(noise: FastNoiseLite, cell: Vector2i) -> float:
	return clampf((noise.get_noise_2d(cell.x, cell.y) + 1.0) * 0.5, 0.0, 1.0)
