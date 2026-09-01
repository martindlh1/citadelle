class_name TerrainGen
extends RefCounted
## Génération de terrain seedée, et **garantie**.
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
## **T4 la retourne, et DESIGN.md 3.1 dit pourquoi.** Ce qui existait était du bruit de
## Perlin plus des seuils : du relief crédible, et **aucune promesse**. Ça n'avait pas
## d'importance tant que le relief ne faisait que gêner la pose ; depuis le rescope il *est*
## la carte de tower-defense, et une carte sans topographie est une partie sans jeu.
##
## **La méthode est « poser la structure, décorer au bruit ».** L'inverse — bruiter puis
## espérer — est exactement ce qui ne peut rien garantir, et c'est ce que faisait la version
## d'avant. Ici la forme est posée en clair :
##
##     1. une plaine basse, ondulée dans une amplitude **bornée**, et ses étangs ;
##     2. un plateau central au-dessus, hors d'enjambée de cette plaine ;
##     3. deux à quatre rampes, seules montées, taillées en marches franchissables ;
##     4. la décoration — forêts, gisements, rochers — par-dessus tout ça.
##
## **La borne du 1 est ce qui rend le 2 inviolable**, et c'est `TerrainGenBalance` qui la
## tient : tant que le plateau surplombe la plaine de plus d'une enjambée, aucun bruit jeté
## sur la plaine ne peut ouvrir un accès que personne n'a voulu. La garantie n'est pas
## vérifiée après coup, elle est **structurelle**.
##
## **Et ce qui reste vérifié l'est vraiment.** La décoration, elle, peut encore défaire une
## promesse : un étang qui coupe le pied d'une rampe, deux rochers qui la bouchent, un
## plateau où aucun gisement n'est tombé. D'où l'audit et le **rejet du seed** — et d'où le
## fait que `MapAudit` ne sait rien de ce fichier : il retrouve le plateau et compte les
## accès en marchant, sinon il ne ferait que répéter ce qu'on vient d'écrire.
##
## L'aléatoire reste entier partout ailleurs : où sont les accès, comment le relief se
## plisse, où tombent les étangs, les gisements et les forêts.

## Décorrèle les quatre flux de bruit. Sans ces décalages ils partiraient tous du même seed
## et leurs motifs seraient corrélés — des forêts qui suivent les lignes de crête, des
## étangs qui épousent le bord du plateau.
const RELIEF_SEED_SALT := 0x1E5C0F17
const WATER_SEED_SALT := 0x2B7A9C41
const PLATEAU_SEED_SALT := 0x3F1D6E83
const RAMP_SEED_SALT := 0x4C8B2D59
const SCATTER_SEED_SALT := 0x5CA77E12

## Écart entre deux essais successifs d'un même seed.
##
## Une constante impaire et large, multipliée par le rang de l'essai : deux essais voisins
## doivent donner des cartes **sans rapport**, et `FastNoiseLite` rend des motifs proches
## pour des seeds proches. Ajouter 1 aurait redessiné la même carte à peine bougée, donc
## rejeté pour le même motif, autant de fois qu'il y a d'essais.
const ATTEMPT_STRIDE := 0x9E3779B9

## Garde-fou de marche pour la taille d'une rampe, en cellules.
const RAMP_MARCH_LIMIT := 64

## Le centre d'une carte de cette taille.
##
## Une fonction plutôt qu'un calcul recopié, parce que **trois endroits doivent tomber
## d'accord** : la génération y bâtit son plateau, l'audit y cherche le sien, et le harnais y
## pose sa question. Deux divisions entières écrites séparément finissent par différer d'une
## case sur les tailles impaires, et l'audit rendrait alors un plateau d'une cellule sans que
## rien n'explique pourquoi.
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
##
## Le prix est un brouillon de plus, redessiné par `generate()` une fois le rang connu. C'est
## une carte de mille cellules ; ce que ça achète est qu'une table ne puisse pas diverger de
## ce que le jeu joue.
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
## imprimer la distribution de ce que la structure produit *avant* qu'on en écarte quoi que
## ce soit. Une distribution mesurée après rejet ne dirait pas si les promesses sont serrées
## ou lâches — elle serait bonne par construction.
static func draft(run_seed: int, size: Vector2i, params: TerrainGenBalance) -> HeightGrid:
	assert(size.x > 0 and size.y > 0, "taille de carte non positive : %s" % size)
	assert(params != null, "réglages de génération null")
	var grid := HeightGrid.create(size, params.lowland_height, params.plain)
	# Le plateau est **dessiné avant d'être posé**, et la plaine se range autour de lui : sans
	# ça, `water_share` compterait une part de la carte entière dont le plateau reprendrait
	# ensuite le milieu, et le champ mentirait sur ce qu'il noie.
	var plateau := _plateau_cells(size, run_seed, params)
	_lay_lowland(grid, run_seed, params, plateau)
	_raise_plateau(grid, params, plateau)
	_carve_ramps(grid, run_seed, params)
	_scatter(grid, run_seed, params)
	return grid

# --- 1. la plaine et ses étangs ---------------------------------------------

## Ondule la plaine dans son amplitude bornée, et y creuse ses étangs.
##
## L'amplitude est `lowland_relief` crans au-dessus de la base, **et pas un de plus** : c'est
## la moitié structurelle de la garantie, celle qui empêche le bruit de fabriquer un accès.
##
## **Les étangs sont une part et non un seuil.** La première version comparait le bruit à
## `water_share` directement, ce qui paraissait la même chose et ne l'était pas : un bruit
## simplex se serre autour de sa moyenne, si bien qu'un « douze pour cent » demandé rendait
## **zéro** case d'eau sur mille. Le champ portait un nom de proportion et faisait un seuil.
## On classe donc les cases de plaine par leur bruit et l'on noie les plus basses, ce qui
## rend au champ le sens qu'il annonce — et garde les étangs d'un tenant, puisque le bruit
## est lissé.
static func _lay_lowland(grid: HeightGrid, run_seed: int, params: TerrainGenBalance,
		plateau: Array[Vector2i]) -> void:
	var on_plateau: Dictionary[Vector2i, bool] = {}
	for cell in plateau:
		on_plateau[cell] = true
	var relief := _noise(run_seed ^ RELIEF_SEED_SALT, params)
	var levels := params.lowland_relief + 1
	var lowland: Array[Vector2i] = []
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if on_plateau.has(cell):
				continue
			lowland.append(cell)
			var step := mini(int(_unit(relief, cell) * levels), levels - 1)
			grid.set_cell(cell, params.lowland_height + step, params.plain)
	for cell in _drowned(lowland, run_seed, params):
		grid.set_cell(cell, params.water_level, params.water)

## Les cellules de plaine que la nappe recouvre : la part `water_share` dont le bruit d'eau
## est le plus bas.
##
## Le tri départage à valeur égale par la position, jamais par l'ordre du tableau : deux
## lancements doivent noyer les mêmes cases.
static func _drowned(lowland: Array[Vector2i], run_seed: int,
		params: TerrainGenBalance) -> Array[Vector2i]:
	var count := int(float(lowland.size()) * params.water_share)
	if count <= 0:
		return []
	var pools := _noise(run_seed ^ WATER_SEED_SALT, params)
	var sorted := lowland.duplicate()
	sorted.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var left := _unit(pools, first)
		var right := _unit(pools, second)
		if not is_equal_approx(left, right):
			return left < right
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	return sorted.slice(0, mini(count, sorted.size()))

# --- 2. le plateau ----------------------------------------------------------

## Les cellules du plateau central : un disque au bord déformé, ramené à ce qui tient au
## centre.
##
## **Seule la partie rattachée au centre est gardée.** Le bruit de bord détache volontiers
## des îlots à la limite du rayon, et un îlot à hauteur de plateau au milieu de la plaine
## serait une table volante qu'aucune règle ne justifie — infranchissable, inatteignable, et
## comptée nulle part. Les jeter garde la structure lisible : il y a **un** plateau.
static func _plateau_cells(size: Vector2i, run_seed: int,
		params: TerrainGenBalance) -> Array[Vector2i]:
	var edge := _noise(run_seed ^ PLATEAU_SEED_SALT, params)
	var centre := centre_of(size)
	var claimed: Dictionary[Vector2i, bool] = {}
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var reach := float(params.plateau_radius) \
				* (1.0 + params.plateau_jitter * edge.get_noise_2d(x, y))
			if Vector2(cell - centre).length() <= reach:
				claimed[cell] = true
	return _linked_to(claimed, centre)

## Pose ces cellules à la hauteur du plateau.
static func _raise_plateau(grid: HeightGrid, params: TerrainGenBalance,
		plateau: Array[Vector2i]) -> void:
	for cell in plateau:
		grid.set_cell(cell, params.plateau_height, params.plain)

## Les cellules réclamées qui se rattachent au centre de proche en proche.
static func _linked_to(claimed: Dictionary[Vector2i, bool],
		centre: Vector2i) -> Array[Vector2i]:
	if not claimed.has(centre):
		return []
	var kept: Array[Vector2i] = [centre]
	var seen: Dictionary[Vector2i, bool] = { centre: true }
	var head := 0
	while head < kept.size():
		var cell := kept[head]
		head += 1
		for step in MapAudit.NEIGHBOURS:
			var side := cell + step
			if seen.has(side) or not claimed.has(side):
				continue
			seen[side] = true
			kept.append(side)
	return kept

# --- 3. les rampes ----------------------------------------------------------

## Taille les seules montées du plateau, réparties tout autour.
##
## Le nombre est tiré dans l'intervalle des promesses, et les directions sont **étalées** —
## une part de tour chacune, plus un écart borné à la moitié de cette part. Tirer des angles
## indépendants aurait laissé deux rampes se coller la moitié du temps, donc rendu un accès
## là où l'on en voulait deux : le rejet aurait alors mesuré la maladresse du tirage plutôt
## que la carte.
## **Toutes les rampes sont planifiées avant d'être posées, et le plus haut l'emporte.**
##
## C'est le correctif d'un défaut qui a coûté une heure et que seule une carte imprimée en
## chiffres montrait. Une rampe en diagonale passe par des cases d'angle, ses voies se
## chevauchent d'un cran à l'autre, et « le dernier qui écrit gagne » veut alors dire que le
## cran **bas** efface le cran haut. L'escalier y perdait une marche, donc devenait une
## marche de deux crans, donc infranchissable : la rampe était parfaitement dessinée à
## l'écran et ne se montait pas. Deux des cinq crans d'une rampe disparaissaient ainsi, sans
## rien casser et sans qu'aucune image ne le dise.
##
## Garder le maximum rend l'escalier **monotone par construction**, ce qui est la seule forme
## de garantie que ce fichier accepte : il n'y a plus à vérifier qu'une rampe se monte.
##
## Le nombre est tiré dans l'intervalle des promesses, et les directions sont **étalées** —
## une part de tour chacune, plus un écart borné au quart de cette part. Tirer des angles
## indépendants aurait laissé deux rampes se coller la moitié du temps, donc rendu un accès
## là où l'on en voulait deux : le rejet aurait alors mesuré la maladresse du tirage plutôt
## que la carte.
static func _carve_ramps(grid: HeightGrid, run_seed: int,
		params: TerrainGenBalance) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ RAMP_SEED_SALT
	var count := rng.randi_range(params.min_accesses, params.max_accesses)
	var share := TAU / float(count)
	var start := rng.randf() * TAU
	var carved: Dictionary[Vector2i, int] = {}
	for index in count:
		var jitter := rng.randf_range(-share * 0.25, share * 0.25)
		_plan_ramp(grid, params, start + share * float(index) + jitter, carved)
	# Une rampe est un **remblai** et jamais une tranchée : elle ne descend rien de ce qui
	# était là. Le plateau n'est donc pas entamé par une voie qui mord son bord, et un étang
	# traversé se comble au lieu de garder son trou.
	# Les voies d'un cran peuvent déborder de la carte : c'est le plan qui les porte, la pose
	# qui les écarte. Filtrer plus tôt aurait demandé la grille à une fonction qui n'a rien à
	# y lire.
	for cell in carved:
		if grid.in_bounds(cell):
			grid.set_cell(cell, maxi(carved[cell], grid.height_at(cell)), params.plain)

## Taille une rampe depuis le bord du plateau, dans cette direction.
##
## Elle descend d'une enjambée par cran et s'arrête **au niveau de la base** de la plaine, et
## non à son plafond : une plaine ondulée porte des cases à la base comme au plafond, et un
## pied de rampe posé au plafond serait injoignable depuis les premières. Finir en bas rend
## le pied atteignable de partout, ce qui est ce qu'on veut d'un col — visible et ouvert.
static func _plan_ramp(grid: HeightGrid, params: TerrainGenBalance, angle: float,
		carved: Dictionary[Vector2i, int]) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var side := Vector2(-direction.y, direction.x)
	var cells := _ray_cells(grid, centre_of(grid.size()), direction)
	# On sort du plateau en marchant : c'est son bord **réel**, déformé par le bruit, et non
	# le rayon nominal. Une rampe calée sur le rayon aurait commencé dans le vide sur les
	# secteurs creusés et dans le plateau sur les secteurs bombés.
	var index := 0
	while index < cells.size() and grid.height_at(cells[index]) == params.plateau_height:
		index += 1
	var height := params.plateau_height - params.max_climb
	while index < cells.size():
		_plan_rank(params, cells[index], side, maxi(height, params.lowland_height), carved)
		if height <= params.lowland_height:
			return
		height -= params.max_climb
		index += 1

## Les cellules distinctes que traverse un rayon parti du centre, dans l'ordre, **sans jamais
## sauter en diagonale**.
##
## Le détour par la case intermédiaire n'est pas de l'esthétique : un marcheur se déplace en
## quatre voisins, donc une rampe dont deux crans successifs ne se touchent que par un coin
## **ne se monte pas**. Elle serait pourtant parfaitement dessinée à l'écran, et l'audit
## rendrait un accès de moins sans que rien ne dise pourquoi — le pire des deux mondes.
##
## Il s'arrête au bord de la carte, et c'est la seule façon dont une rampe se tronque : une
## rampe qui n'atteint pas la plaine n'ouvre aucun accès, l'audit en compte un de moins, et
## le seed se fait rejeter. Mieux vaut ça qu'une rampe qui déborderait en silence.
static func _ray_cells(grid: HeightGrid, from: Vector2i, direction: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var probe := Vector2(from) + Vector2(0.5, 0.5)
	var last := from
	cells.append(from)
	for _step in RAMP_MARCH_LIMIT * 2:
		probe += direction * 0.5
		var cell := Vector2i(floori(probe.x), floori(probe.y))
		if cell == last:
			continue
		# Le pas en x d'abord, toujours : un choix arbitraire mais **fixe**, sans quoi deux
		# rampes symétriques ne se ressembleraient pas.
		if cell.x != last.x and cell.y != last.y:
			var corner := Vector2i(cell.x, last.y)
			if not grid.in_bounds(corner):
				break
			cells.append(corner)
		if not grid.in_bounds(cell):
			break
		cells.append(cell)
		last = cell
	return cells

## Inscrit un cran de rampe au plan, large de `ramp_width`, centré sur l'axe.
##
## **La largeur se compte sur un axe entier**, celui des deux que la perpendiculaire suit le
## plus. Étaler les voies sur la perpendiculaire réelle paraissait plus juste et ne l'était
## pas : sur une rampe en diagonale, un décalage d'un demi-pas arrondit sur la **même**
## cellule, si bien qu'une rampe déclarée large de deux n'en faisait qu'une. Rien ne le
## disait — elle se dessinait, elle se montait, elle était simplement deux fois plus fragile
## qu'annoncé.
##
## Le terrain repassera en plaine à la pose : une rampe est un **col**, donc une case où l'on
## bâtit, et un rocher ou un étang qui y traînait la fermerait avant même que la décoration
## n'ait son tour. Ce que la décoration y jettera ensuite, en revanche, y reste — et c'est ce
## que l'audit constate.
static func _plan_rank(params: TerrainGenBalance, cell: Vector2i, side: Vector2,
		height: int, carved: Dictionary[Vector2i, int]) -> void:
	var axis := Vector2i(1, 0) if absf(side.x) >= absf(side.y) else Vector2i(0, 1)
	var first := -(params.ramp_width - 1) / 2
	for lane in params.ramp_width:
		var here := cell + axis * (first + lane)
		carved[here] = maxi(carved.get(here, height), height)

# --- 4. la décoration -------------------------------------------------------

## Répartit forêt, gisement et rocher sur les cellules émergées, en bandes cumulées.
static func _scatter(grid: HeightGrid, run_seed: int, params: TerrainGenBalance) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ SCATTER_SEED_SALT
	var forest_band := params.forest_density
	var stone_band := forest_band + params.stone_density
	var rock_band := stone_band + params.rock_density
	var extent := grid.size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if grid.terrain_at(cell) == params.water:
				continue
			# Le tirage est consommé même quand il ne donne rien : relever
			# forest_max_height ne doit pas décaler tout le reste du flux.
			var draw := rng.randf()
			if draw < forest_band:
				if grid.height_at(cell) <= params.forest_max_height:
					grid.set_terrain(cell, params.forest)
			elif draw < stone_band:
				grid.set_terrain(cell, params.stone)
			elif draw < rock_band:
				grid.set_terrain(cell, params.rock)

# --- le bruit ---------------------------------------------------------------

static func _noise(noise_seed: int, params: TerrainGenBalance) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = params.noise_frequency
	noise.fractal_octaves = params.noise_octaves
	return noise

## Le bruit de cette cellule ramené en [0, 1].
static func _unit(noise: FastNoiseLite, cell: Vector2i) -> float:
	return clampf((noise.get_noise_2d(cell.x, cell.y) + 1.0) * 0.5, 0.0, 1.0)
