class_name TerritoryTest
extends GdUnitTestSuite
## L'emprise du village : la réunion des disques de ses bâtiments achevés.
##
## Villes montées à la main, une ou deux cabanes, sur une plaine nue de 20 x 20. Ce qui est
## éprouvé ici est la **forme** du territoire, donc rien d'autre que la géométrie ne doit
## entrer dans le montage : un relief varié ne changerait aucune réponse et rendrait chaque cas
## plus difficile à relire.
##
## Les deux lectures sont vérifiées **l'une contre l'autre** dans un cas dédié. C'est la seule
## chose que ce fichier ne pourrait pas remplacer par de l'attention : le validateur interroge
## `reaches()` et le contour dessine `cells()`, donc un désaccord entre les deux ferait une
## bordure dans laquelle poser refuse — et rien ne le signalerait.

const SIZE := Vector2i(20, 20)
const HEART := Vector2i(5, 5)
const REACH := 2

var _plain: TerrainData
var _grid: HeightGrid
var _city: CityState

func before_test() -> void:
	_plain = TerrainData.new()
	_plain.id = &"plain"
	_plain.build = TerrainData.Build.ALLOWED
	_plain.walk = TerrainData.Walk.ALLOWED
	_grid = HeightGrid.create(SIZE, 0, _plain)
	_city = CityState.new()

# --- la ville vide ----------------------------------------------------------

## **Une ville vide n'a pas de frontière, donc elle n'en oppose aucune.** C'est le cas de la
## fondation : le Cœur ne se pose que quand rien n'existe, donc la seule pose qui échappe à la
## règle est celle qui la crée. Rendre faux ici aurait obligé l'orchestrateur à contourner le
## validateur pour fonder.
func test_an_empty_city_reaches_everywhere() -> void:
	assert_bool(Territory.reaches(_city, Vector2i(19, 19))).is_true()
	assert_bool(Territory.reaches(_city, HEART)).is_true()

## Et rien à dessiner : les deux lectures disent la même chose sous deux formes.
func test_an_empty_city_has_no_cells_to_draw() -> void:
	assert_array(Territory.cells(_city, SIZE)).is_empty()

# --- le disque d'un bâtiment ------------------------------------------------

func test_the_cell_under_a_building_is_inside() -> void:
	_place(_hut(), HEART)
	assert_bool(Territory.reaches(_city, HEART)).is_true()

## Le rayon se mesure en anneaux : le coin en diagonale est à la même distance que le côté.
func test_the_reach_is_counted_in_rings() -> void:
	_place(_hut(), HEART)
	assert_bool(Territory.reaches(_city, HEART + Vector2i(REACH, REACH))) \
		.override_failure_message("le coin du carré doit être dedans") \
		.is_true()
	assert_bool(Territory.reaches(_city, HEART + Vector2i(REACH + 1, 0))) \
		.override_failure_message("une case de plus est dehors") \
		.is_false()

## Un carré de côté 2 x rayon + 1, et rien de plus. Le compte est ce qui attrape un rayon
## appliqué depuis le mauvais bord, ou une distance euclidienne déguisée.
func test_a_lone_building_covers_exactly_its_square() -> void:
	_place(_hut(), HEART)
	var side := 2 * REACH + 1
	assert_int(Territory.cells(_city, SIZE).size()).is_equal(side * side)

## Un bâtiment de deux cases rayonne depuis ses **deux bouts**, comme une règle d'adjacence
## mesure depuis l'empreinte entière. Sans ça, la moitié d'un bâtiment serait hors de son
## propre territoire dès que le rayon vaut zéro d'un côté.
func test_a_two_cell_building_reaches_from_both_ends() -> void:
	_place(_gallery(), HEART)
	assert_bool(Territory.reaches(_city, HEART + Vector2i(1 + REACH, 0))) \
		.override_failure_message("la seconde case ne rayonne pas") \
		.is_true()

## L'emprise est bornée par la carte : une frontière dessinée hors grille désignerait des cases
## sur lesquelles personne ne peut bâtir.
func test_the_territory_stops_at_the_edge_of_the_map() -> void:
	_place(_hut(), Vector2i(0, 0))
	for cell in Territory.cells(_city, SIZE):
		assert_bool(_grid.in_bounds(cell)) \
			.override_failure_message("case hors carte dans l'emprise : %s" % cell) \
			.is_true()
	assert_int(Territory.cells(_city, SIZE).size()).is_equal((REACH + 1) * (REACH + 1))

# --- la réunion -------------------------------------------------------------

## **Le cas qui porte la mécanique.** Un second bâtiment posé au bord du disque du premier
## pousse la frontière **de son côté**, et de ce côté seulement : c'est ce qui distingue cette
## règle d'un rayon central qui grandirait, lequel s'étendrait dans toutes les directions à la
## fois. Le village prend la forme de ce qu'il est allé chercher.
func test_a_second_building_pushes_the_border_its_way() -> void:
	_place(_hut(), HEART)
	var beyond := HEART + Vector2i(2 * REACH, 0)
	assert_bool(Territory.reaches(_city, beyond)) \
		.override_failure_message("la case devait être hors du premier disque") \
		.is_false()
	_place(_hut(), HEART + Vector2i(REACH, 0))
	assert_bool(Territory.reaches(_city, beyond)) \
		.override_failure_message("le second bâtiment devait ouvrir au-delà") \
		.is_true()
	# Et rien de gagné derrière : l'emprise ne s'étend que du côté où l'on a bâti.
	assert_bool(Territory.reaches(_city, HEART - Vector2i(REACH + 1, 0))) \
		.override_failure_message("l'autre côté ne devait pas bouger") \
		.is_false()

## **Deux disques disjoints n'existent pas**, et c'est une propriété émergente plutôt qu'une
## règle écrite : toute pose doit être dans l'emprise, donc tout disque neuf recouvre un ancien.
## Le territoire d'un village est d'un seul tenant sans que rien ne l'impose — et ce cas est là
## pour qu'on s'en aperçoive le jour où une règle future voudrait le contraire.
func test_the_territory_cannot_be_split_in_two() -> void:
	_place(_hut(), HEART)
	var far := HEART + Vector2i(2 * REACH + 3, 0)
	var result := _city.place(_grid.to_query(), _hut(), far)
	assert_str(result.reason()) \
		.override_failure_message("poser hors de l'emprise devait être refusé") \
		.is_equal(PlacementResult.REASON_OUT_OF_REACH)

## Deux disques qui se chevauchent ne comptent pas deux fois la case commune, et la réunion
## reste une réunion : le contour aurait sinon dessiné une frontière intérieure fantôme.
func test_overlapping_discs_do_not_double_count() -> void:
	_place(_hut(), HEART)
	_place(_hut(), HEART + Vector2i(1, 0))
	var side := 2 * REACH + 1
	assert_int(Territory.cells(_city, SIZE).size()).is_equal(side * (side + 1))

# --- le chantier ------------------------------------------------------------

## **Un chantier n'étend rien tant qu'il n'est pas fini.** Même règle que la réserve qu'un
## entrepôt en travaux ne relève pas — et c'est elle qui empêche de traverser la carte en
## chaînant des chantiers qu'on n'achève jamais.
func test_an_unfinished_site_extends_nothing() -> void:
	_place(_hut(2), HEART)
	assert_bool(Territory.reaches(_city, HEART)) \
		.override_failure_message("un chantier n'ouvre même pas sa propre case") \
		.is_false()
	assert_array(Territory.cells(_city, SIZE)).is_empty()

## Le pendant, sans quoi le cas ci-dessus passerait aussi bien sur une emprise qui ne
## s'ouvrirait jamais : le cran qui achève le chantier ouvre le territoire.
func test_the_notch_that_finishes_a_site_opens_the_territory() -> void:
	_place(_hut(2), HEART)
	_city.advance(HEART)
	assert_bool(Territory.reaches(_city, HEART)).is_false()
	_city.advance(HEART)
	assert_bool(Territory.reaches(_city, HEART)) \
		.override_failure_message("le chantier achevé doit ouvrir son disque") \
		.is_true()

# --- ce qu'un fantôme ouvrirait ---------------------------------------------

## Ce que le bâtiment sous le curseur ouvrirait, sans qu'il soit posé. C'est ce que le second
## contour dessine, et il se calcule sur une ancre plutôt que sur un bâtiment placé — pour la
## même raison qu'`Adjacency` : au moment où l'on choisit une case, rien n'est encore posé.
func test_a_ghost_covers_the_square_it_would_open() -> void:
	var side := 2 * REACH + 1
	assert_int(Territory.would_cover(_hut(), HEART, 0, SIZE).size()).is_equal(side * side)

## Elle rend la **même** chose que la lecture du bâtiment posé, sans quoi le contour bleu
## promettrait une frontière que le contour jaune ne tiendrait pas une fois le bâtiment fini.
func test_what_a_ghost_promises_is_what_it_delivers() -> void:
	var promised := Territory.would_cover(_hut(), HEART, 0, SIZE)
	_place(_hut(), HEART)
	assert_array(promised).is_equal(Territory.cells(_city, SIZE))

## Un chantier promet le même disque qu'un bâtiment fini : ce qu'on prévisualise est ce que la
## pose **finira** par ouvrir, pas ce qu'elle ouvre à l'instant. Un contour qui disparaîtrait
## à la pose pour revenir deux tours plus tard se lirait comme un défaut d'affichage.
func test_a_ghost_promises_what_the_finished_building_will_open() -> void:
	assert_array(Territory.would_cover(_hut(2), HEART, 0, SIZE)) 		.is_equal(Territory.would_cover(_hut(), HEART, 0, SIZE))

## L'orientation déplace l'empreinte, donc le disque. Un aperçu qui lirait l'ancre sans les
## crans dessinerait la frontière d'une autre pose.
func test_turning_the_ghost_moves_what_it_would_open() -> void:
	var flat := Territory.would_cover(_gallery(), HEART, 0, SIZE)
	var turned := Territory.would_cover(_gallery(), HEART, 1, SIZE)
	assert_int(flat.size()) 		.override_failure_message("les deux orientations couvrent autant de cases") 		.is_equal(turned.size())
	assert_array(flat) 		.override_failure_message("l'empreinte pivotée devait déplacer le disque") 		.is_not_equal(turned)

# --- les deux lectures d'accord ---------------------------------------------

## **Le cas qui protège du désaccord muet.** `reaches()` répond au placement, `cells()` dessine
## la bordure : sur une ville quelconque, les deux doivent nommer exactement les mêmes cases.
## Une divergence ferait une frontière dans laquelle le clic refuse, et rien ne l'annoncerait.
func test_both_readings_name_the_same_cells() -> void:
	# Une ville qui a poussé comme une vraie : chaque pose tombe dans l'emprise de la
	# précédente, et la dernière est un chantier — donc un bâtiment qui n'y ajoute rien.
	_place(_hut(), HEART)
	_place(_gallery(), HEART + Vector2i(1, 1))
	_place(_hut(2), HEART + Vector2i(2 * REACH, 2))
	var drawn: Dictionary[Vector2i, bool] = {}
	for cell in Territory.cells(_city, SIZE):
		drawn[cell] = true
	assert_bool(drawn.is_empty()) \
		.override_failure_message("emprise vide : le cas ne prouve rien") \
		.is_false()
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			assert_bool(drawn.has(cell)) \
				.override_failure_message("désaccord en %s" % cell) \
				.is_equal(Territory.reaches(_city, cell))

# --- le montage -------------------------------------------------------------

func _place(data: BuildingData, anchor: Vector2i) -> void:
	var result := _city.place(_grid.to_query(), data, anchor)
	assert_bool(result.is_ok()) \
		.override_failure_message("le montage n'a pas posé %s en %s : %s"
			% [data.id, anchor, result.reason()]) \
		.is_true()

## Une cabane d'une case, de rayon REACH, achevée sauf si un chantier est demandé.
func _hut(site_turns := 0) -> BuildingData:
	var data := BuildingData.new()
	data.id = &"hut"
	data.footprint = [Vector2i.ZERO] as Array[Vector2i]
	data.hit_points = 1
	data.reach = REACH
	data.site_turns = site_turns
	return data

## Deux cases en x : une empreinte d'une seule case ne dirait rien du rayonnement par les bouts.
func _gallery() -> BuildingData:
	var data := _hut()
	data.id = &"gallery"
	data.footprint = [Vector2i.ZERO, Vector2i(1, 0)] as Array[Vector2i]
	return data
