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
const SCATTER_SEED_SALT := 0x5CA77E12

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
## **Épuiser les essais rend quand même une carte**, et c'est délibéré : un `assert` dit
## bruyamment que les réglages ne sont pas satisfiables, mais un `assert` est retiré d'un
## export, et rendre `null` ferait tomber le jeu bien plus loin, sur une pile qui ne
## nommerait plus la cause. Une carte qui déçoit se joue ; une carte absente ne se joue pas.
static func generate(run_seed: int, size: Vector2i, params: TerrainGenBalance) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de carte non positive : %s" % size)
	assert(params != null, "réglages de génération null")
	assert(params.missing_fields().is_empty(),
		"réglages de génération inexploitables : %s" % ", ".join(params.missing_fields()))
	var attempt := accepted_attempt(run_seed, size, params)
	if attempt < 0:
		assert(false, "aucune carte jouable en %d essais sur le seed %d — réglages de %s"
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
	if params.shape == TerrainGenBalance.Shape.RIDGES:
		relief.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var centre := centre_of(grid.size())
	var extent := grid.size()

	# Le champ est calculé en flottant, puis **étalé sur l'amplitude déclarée**, puis
	# seulement découpé en crans.
	#
	# L'étalement n'est pas de la coquetterie : un bruit fractal ne visite pas toute sa
	# plage, et un bruit **en crêtes** encore moins — il se serre vers le haut. Sans lui, la
	# technique `ridges` rendait une carte dont le point le plus bas était deux crans
	# au-dessus de la nappe, donc **sans un seul lac**, alors que `min_height` et
	# `water_level` disaient le contraire. Le réglage était juste, la carte ne l'était pas.
	#
	# Avec lui, `min_height..max_height` veut dire ce qu'il annonce pour toutes les
	# techniques : chaque carte descend jusqu'à son point bas et monte jusqu'à son sommet.
	var field := PackedFloat32Array()
	field.resize(extent.x * extent.y)
	var lowest := INF
	var highest := -INF
	for y in extent.y:
		for x in extent.x:
			var unit := _relief_at(Vector2i(x, y), centre, relief, detail, params)
			field[y * extent.x + x] = unit
			lowest = minf(lowest, unit)
			highest = maxf(highest, unit)

	var span := maxf(highest - lowest, 0.0001)
	var levels := params.max_height - params.min_height + 1
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var unit := (field[y * extent.x + x] - lowest) / span
			var height := params.min_height + mini(int(unit * levels), levels - 1)
			if height <= params.water_level:
				grid.set_cell(cell, params.water_level, params.water)
			else:
				grid.set_cell(cell, height, params.plain)

## La hauteur de cette cellule, en fraction de l'amplitude, avant découpage en crans.
##
## C'est le seul endroit où les techniques diffèrent, et elles diffèrent **par addition** :
## chacune part du même bruit et lui ajoute ce qui la caractérise. `RAW` n'ajoute rien et sert
## de témoin — on ne sait pas ce qu'une règle apporte sans la carte qui ne l'a pas.
static func _relief_at(cell: Vector2i, centre: Vector2i, relief: FastNoiseLite,
		detail: FastNoiseLite, params: TerrainGenBalance) -> float:
	var unit := _unit(relief, cell)
	if params.shape == TerrainGenBalance.Shape.RIDGES and params.detail_share > 0.0:
		unit = lerpf(unit, _unit(detail, cell), params.detail_share)
	if params.shape == TerrainGenBalance.Shape.RAW:
		return clampf(unit, 0.0, 1.0)

	var levels := float(maxi(params.max_height - params.min_height, 1))
	unit += params.dome_rise / levels * _falloff(cell, centre, params.dome_radius)
	if params.shape == TerrainGenBalance.Shape.CLEARING:
		# Un lissage **vers la hauteur du centre**, et non un aplanissement : à pleine force
		# on retrouverait la mesa qu'on vient de retirer. Le grain survit, il se calme.
		var pull := params.clearing_flatten * _falloff(cell, centre, params.clearing_radius)
		unit = lerpf(unit, _unit(relief, centre) + params.dome_rise / levels, pull)
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

# --- la dispersion ----------------------------------------------------------

## Répartit forêt, gisement et rocher sur les cellules émergées, en bandes cumulées.
##
## `CLEARING` y éclaircit le centre : les trois bandes y sont resserrées de `clearing_calm`,
## donc moins d'arbres et surtout moins de rochers là où l'on fonde. C'est la seconde moitié
## de « pas trop occupée », et elle compte autant que la première — un centre plat couvert de
## rochers ne se bâtit pas davantage qu'une pente.
static func _scatter(grid: HeightGrid, run_seed: int, params: TerrainGenBalance) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ SCATTER_SEED_SALT
	var centre := centre_of(grid.size())
	var clearing := params.shape == TerrainGenBalance.Shape.CLEARING
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if grid.terrain_at(cell) == params.water:
				continue
			# Le tirage est consommé même quand il ne donne rien : relever
			# forest_max_height ne doit pas décaler tout le reste du flux.
			var draw := rng.randf()
			var calm := 1.0
			if clearing:
				calm = lerpf(1.0, params.clearing_calm,
					_falloff(cell, centre, params.clearing_radius))
			var forest_band := params.forest_density * calm
			var stone_band := forest_band + params.stone_density * calm
			var rock_band := stone_band + params.rock_density * calm
			if draw < forest_band:
				if grid.height_at(cell) <= params.forest_max_height:
					grid.set_terrain(cell, params.forest)
			elif draw < stone_band:
				grid.set_terrain(cell, params.stone)
			elif draw < rock_band:
				grid.set_terrain(cell, params.rock)

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
