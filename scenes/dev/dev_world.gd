class_name DevWorld
extends Node3D
## Le plateau commun aux harnais de dev : ciel, soleil, caméra, relief, survol.
##
## Ni un système ni un adapter — c'est la scène sur laquelle un harnais travaille. Il
## existe parce que le harnais Construction a besoin exactement de ce que le harnais
## Terrain montait déjà : on ne pose pas un bâtiment sur un terrain qu'on ne voit pas.
##
## Recopier ces soixante lignes aurait fait exister en double le soleil réglé à T2 et
## le raisonnement qui l'accompagne. CLAUDE.md prévient que les bâtiments, qui sont des
## boîtes, pourraient obliger à le déplacer : le jour où ça arrive, il doit n'y avoir
## qu'un seul endroit à changer.
##
## Il ne connaît aucun système. On lui donne une grille et une métrique, il rend un
## plateau ; ce qu'on pose dessus ensuite regarde le harnais.

## Fond de la vue, au-delà de la carte.
const SKY_COLOR := Color(0.09, 0.11, 0.14)

## Lumière ambiante. Sans elle les flancs à l'ombre tombent au noir et le relief se
## lit comme des trous plutôt que comme des marches.
const AMBIENT_COLOR := Color(0.45, 0.52, 0.62)
const AMBIENT_ENERGY := 0.55

## Orientation du soleil à midi. Volontairement décalée de l'axe de la caméra : c'est ce
## décalage qui donne aux quatre flancs d'une colonne quatre valeurs différentes, donc
## au relief son volume. Un éclairage frontal aplatirait tout.
##
## C'est aussi le **milieu de la course** ci-dessous, le soleil y passe à midi, et depuis
## `I3b` c'est là qu'il se **repose** entre deux tours. Réglée à `T2` comme le meilleur
## compromis d'une image fixe, elle est donc devenue l'image fixe elle-même — ce qui est le
## meilleur usage qu'on pouvait en faire.
const SUN_ROTATION_DEGREES := Vector3(-52.0, -125.0, 0.0)
const SUN_ENERGY := 1.15

## Le lacet fait **un tour complet** par journée, à vitesse constante.
##
## Il balayait ±45° autour de midi jusqu'à `I3b`, ce qui suffisait à une image fixe : le
## soleil ne montrait alors que deux moments, et la nuit était une lumière **posée** ailleurs.
## Une course animée ne peut pas s'en contenter — passer du crépuscule à la lune demandait
## alors de faire virer la lumière de cent trente-cinq degrés en un dixième de la course, et
## ça se voyait comme un à-coup. Mesuré : **48,8° de pire pas** contre 5° de pas moyen.
##
## Une révolution entière n'a plus rien à faire virer : la direction tourne du même pas d'un
## bout à l'autre, et la nuit est le même luminaire arrivé de l'autre côté.
##
## **Ce que la calibration de `T2` demandait est intégralement préservé**, et par une jolie
## coïncidence arithmétique. Les colonnes du terrain regardent 0, 90, 180 et 270 : un lacet
## sur un multiple de 45 donne la même valeur à deux flancs et **aplatit le relief**. Or
## −125 vaut 10 modulo 45, et ajouter des quarts de tour ne change pas ce reste — les quatre
## moments cardinaux (aube, midi, crépuscule, minuit) tombent donc tous à dix degrés d'un
## multiple de 45, exactement comme le réglage d'origine. La lumière traverse bien ces angles
## entre deux quarts, mais **en mouvement**, ce que la règle n'a jamais interdit : elle porte
## sur ce qu'on regarde à l'arrêt.
const QUARTER_DEGREES := 90.0

## Hauteur du soleil au lever et au coucher, contre celle de midi.
##
## Rasante aux deux bouts : c'est elle qui allonge les ombres et qui **donne l'heure** sans
## qu'un chiffre l'écrive. Pas plus rasante que ça, en revanche — la portée d'ombre est
## serrée sur ce que la caméra voit, et une ombre plus longue que cette portée se coupe net
## au milieu de la carte.
const SUN_HORIZON_PITCH := -30.0

## Teinte du soleil aux deux bouts de la course, et à midi.
##
## Les deux bouts ne sont **pas** la même lumière retournée, et c'est le seul écart assumé
## à la physique : une journée à deux phases les pose tous les deux au ras de l'horizon,
## donc un soleil symétrique ne différerait que par le côté où tombent les ombres — trop
## discret pour dire l'heure.
##
## L'aube est **rosée** et non bleue. La première version l'avait poussée au bleu froid
## pour l'éloigner du crépuscule, et ça l'éloignait surtout d'une aube : une lumière
## franchement bleue se lit comme un clair de lune ou un temps couvert, pas comme un lever.
## Le rose garde la chaleur d'un soleil bas tout en restant à distance de l'ambre du soir,
## qui tire l'herbe vers l'olive là où l'aube la laisse verte.
const SUN_DAWN_COLOR := Color(1.0, 0.83, 0.78)
const SUN_DUSK_COLOR := Color(1.0, 0.72, 0.45)
const SUN_HIGH_COLOR := Color(1.0, 0.97, 0.92)

## Ce que le soleil rend au ras de l'horizon, en part de son énergie de midi.
const SUN_LOW_ENERGY := 0.82

## La nuit : une lune froide et basse en énergie.
##
## Elle **n'a plus d'orientation à elle** depuis `I3b`, et elle n'en a pas besoin : la course
## l'amène. Le lacet qu'elle portait était 55°, et minuit tombe exactement dessus une fois le
## tour complet écrit — la lune était déjà « de l'autre côté », à un demi-tour du soleil de
## midi. Ce qui était une constante à tenir d'accord avec une autre est devenu une
## conséquence.
##
## Ce qui reste d'elle est ce qui la distingue vraiment : sa teinte froide, et le peu qu'elle
## éclaire.
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const MOON_ENERGY := 0.34

## Ce que la nuit fait au ciel et à l'ambiante.
const NIGHT_SKY_COLOR := Color(0.03, 0.04, 0.07)
const NIGHT_AMBIENT_COLOR := Color(0.30, 0.36, 0.54)
const NIGHT_AMBIENT_ENERGY := 0.40

## Ce que l'aube et le crépuscule font au ciel et à l'ambiante.
const DAWN_SKY_COLOR := Color(0.13, 0.11, 0.16)
const DUSK_SKY_COLOR := Color(0.15, 0.10, 0.10)
## Violine au lever, chaude au coucher : le même partage que la teinte du soleil.
const DAWN_AMBIENT_COLOR := Color(0.52, 0.49, 0.58)
const DUSK_AMBIENT_COLOR := Color(0.52, 0.46, 0.44)
const DUSK_AMBIENT_ENERGY := 0.48

## Marge de portée des ombres au-delà du recul du rig. Elle doit couvrir la moitié
## arrière de ce que la caméra voit au zoom le plus large ; en dessous, le fond de la
## carte perd son ombre, au-dessus chaque texel de la carte d'ombre couvre plus de
## monde pour rien et tout se floute.
const SUN_SHADOW_MARGIN := 60.0

## Le cycle entier, en fraction de révolution : 0 à l'aube, 0,25 à midi, 0,5 au crépuscule,
## 0,75 au cœur de la nuit, et 1 qui **est** 0 — la course se referme exactement sur
## elle-même, ce qui est la seule façon de la rejouer sans saut visible.
##
## Une seule valeur pilote les six propriétés éclairées, au lieu des six tweens parallèles
## que `I1` employait pour glisser d'un moment nommé à un autre. C'est ce qui rend une
## **course** possible plutôt qu'une transition : on ne peut pas traverser midi en
## interpolant directement de l'aube au crépuscule.
const DAWN := 0.0
const NOON := 0.25
const DUSK := 0.5
const MIDNIGHT := 0.75

## Où le soleil se repose entre deux tours : **midi**, toujours le même.
##
## C'est un changement d'`I3b` sur `I3`, et il vaut d'être écrit parce qu'il répare deux
## choses d'un coup. Le soleil suivait l'avancement du run — aube au premier tour, nuit au
## vingtième —, si bien que la lumière **dérivait** sans qu'aucune règle du jeu ne le
## demande : le tour 12 se lisait autrement que le tour 3, et la carte devenait moins
## lisible à mesure qu'on avançait. Un repos fixe rend la carte identique à tous les tours,
## et laisse la course dire le temps qui passe.
##
## Midi et non le matin : c'est l'orientation calibrée à `T2`, celle dont les quatre flancs
## d'une colonne prennent quatre valeurs différentes.
const REST := NOON

## Profondeur sous l'horizon à laquelle la nuit est pleine, en part de la course.
##
## Elle ne gouverne plus que la **teinte et l'énergie**, la direction étant devenue continue :
## il n'y a donc plus d'à-coup à craindre d'un fondu court, seulement une nuit qui tomberait
## trop vite au goût. Étalée jusqu'à minuit, elle donne un crépuscule qui dure.
const NIGHT_DEPTH := 1.0

## Durée d'une révolution, en secondes.
##
## C'est une **ponctuation** et non un cycle qui tourne tout seul : le soleil ne bouge qu'au
## moment où un tour se résout. Assez lent pour qu'on voie un soleil traverser le ciel, et
## non un fondu — à un peu plus d'une seconde la course se lisait comme un clignotement.
const DAY_SECONDS := 3.0

var _metrics: TerrainMetrics
var _renderer: TerrainRenderer
var _decor: Array[TerrainDecorRenderer]
var _rig: CameraRig
var _cursor: CellCursor
var _sun: DirectionalLight3D
var _environment: Environment

## La course en cours, gardée pour être tuée par la suivante. Sans ça, deux tours passés
## coup sur coup tirent la même propriété chacun de son côté et le soleil hésite à
## mi-chemin. Même précaution que le tween de rotation de `CameraRig`.
var _slide: Tween

## Le moment actuellement éclairé, dans [0, 1[.
##
## Il n'existe plus pour éviter de relancer une transition — `_apply()` est instantanée et se
## rappelle sans effet de bord — mais pour que la course sache **d'où** elle part.
var _moment := REST

## Plateau prêt à être ajouté à l'arbre, déjà peuplé pour cette grille et cadré dessus.
static func create(grid: HeightGrid, metrics: TerrainMetrics, balance: BalanceData) -> DevWorld:
	assert(grid != null, "plateau sans grille")
	assert(metrics != null, "plateau sans métrique")
	assert(balance != null, "plateau sans équilibrage")
	var world := DevWorld.new()
	world.name = "DevWorld"
	world._metrics = metrics
	var environment := _make_environment()
	world._environment = environment.environment
	world.add_child(environment)
	world._sun = _make_sun()
	world.add_child(world._sun)
	world._renderer = TerrainRenderer.create(grid, metrics)
	world.add_child(world._renderer)
	world._decor = TerrainDecorRenderer.create_all(_palette(), metrics)
	for decor_pass in world._decor:
		world.add_child(decor_pass)
	world._rig = CameraRig.create(balance.camera)
	world.add_child(world._rig)
	world._rig.frame(metrics.world_center(grid.size()), metrics.world_extent(grid.size()))
	world._cursor = CellCursor.create(grid, metrics, world._rig.get_camera())
	world.add_child(world._cursor)
	# Indispensable, et pas une précaution : TerrainRenderer.create() se peuple tout
	# seul, TerrainDecorRenderer.create_all() non — elle construit une passe par
	# terrain, vide, que seul rebuild() remplit. Sans cette ligne le plateau sort sans
	# un arbre ni un rocher, et le harnais Terrain ne s'en apercevait pas parce qu'il
	# enchaînait sur son propre show_grid().
	world.show_grid(grid)
	return world

## Éclaire ce moment de la journée : 0 au lever, 1 au coucher.
##
## `moment` est une fraction de révolution et **pas** un nom de moment : `DESIGN.md` 2 pose
## qu'aucun nom de moment n'apparaît dans le code, et le prendre en fraction rend la chose
## vraie sans effort. Les quatre constantes ci-dessus sont des repères de lecture, pas des
## états.
func settle_at(moment: float) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_apply(moment)

## Fait passer un jour : le soleil parcourt **une révolution entière** et revient se poser à
## midi.
##
## C'est la ponctuation d'un tour, et c'est tout ce qu'elle est. Elle ne dit pas *quel* jour
## on est — la lumière est identique au premier tour et au vingtième —, elle dit qu'un jour
## vient de passer. Faire dériver la lumière avec l'avancement du run rendait la carte moins
## lisible à mesure qu'on jouait, pour une information que le rapport donne en chiffres.
##
## Une course relancée pendant une autre tue la précédente et **finit le jour en cours** au
## lieu d'en commencer un second : passer deux tours coup sur coup montre donc une course et
## non deux, ce qui est le comportement qu'on veut d'une ponctuation — elle ponctue, elle ne
## s'accumule pas.
func pass_a_day(seconds := DAY_SECONDS) -> void:
	_sweep_to(REST, seconds, true)

## Fait tomber la nuit et l'y laisse : le soleil descend de midi au crépuscule puis s'éteint.
##
## Une demi-révolution et non une entière, parce que ce qui la déclenche est une **fin** —
## un run qui se termine — et qu'y répondre par un jour de plus dirait le contraire.
func fall_to_night(seconds := DAY_SECONDS) -> void:
	_sweep_to(MIDNIGHT, seconds, false)

## Une transition est-elle en cours ?
##
## **C'est le moment où le plateau parle et où le joueur se tait**, et c'est le seul verrou
## d'entrée du projet. Un geste posé pendant qu'une animation joue arrive dans un état que le
## joueur ne regarde pas encore : il pose un bâtiment sur une ville qu'il n'a pas vue, et
## découvre les deux ensemble. Rien ne casse — le domaine répond correctement, la course
## n'est que décor — mais l'écran a menti par omission.
##
## Il est ici, dans un adapter, et **jamais dans le domaine**. `DESIGN.md` 3.5 : « la fin de
## tour reste atomique — il n'y a ni état d'attente, ni seconde porte ». C'était la seule
## chose qui rendait nécessaire la coupure que le jeu d'avant avait dû écrire, et le rescope
## l'a défaite ; y remettre une attente parce qu'une **animation** dure trois secondes serait
## la rouvrir pour une raison encore plus faible. Le domaine ignore qu'un écran existe.
##
## Aujourd'hui la seule transition est la course du soleil. `V3` en ajoutera une — une
## bataille qui se regarde —, et elle se déclarera **ici** plutôt que d'inventer son propre
## verrou : deux verrous à tenir d'accord finissent par diverger, et celui qui serait oublié
## laisserait passer les gestes en silence.
func is_in_transition() -> bool:
	return _slide != null and _slide.is_valid() and _slide.is_running()

## Où le soleil se trouve dans son cycle, dans [0, 1[.
##
## Lu par la sonde de capture, et par elle seule : rien de ce qui se dessine n'a de raison de
## poser la question, puisque le plateau s'éclaire lui-même.
func moment() -> float:
	return _moment

## Fait avancer la course en cours de ce temps, sur-le-champ.
##
## Ce dont une capture a besoin : trois images de chauffe ne suffisent pas à une course de
## trois secondes, donc une capture prise après un tour photographierait un soleil arrêté à
## mi-chemin.
##
## C'est aussi ce qui rend la course **observable sans écran**, et ça vaut d'être écrit parce
## que la première version portait un bug qu'aucune capture n'aurait pu montrer : elle ne se
## jouait qu'au premier jour. Une image fixe dit où le soleil est ; elle ne dit rien d'un
## mouvement **absent**. Pas à pas, on lit le chemin.
func step_the_course(seconds: float) -> void:
	if _slide != null and _slide.is_valid():
		_slide.custom_step(seconds)

## Direction dans laquelle la lumière voyage, à l'instant.
##
## Lue par la sonde de capture, et par elle seule. Elle existe pour rendre mesurable une
## phrase qui ne l'était pas — « le passage à la nuit fait un saut » —, en la ramenant à
## l'écart angulaire entre deux pas de la course.
func sun_direction() -> Vector3:
	return -_sun.global_basis.z

## La caméra et son rig : rotation, zoom, cadrage.
func rig() -> CameraRig:
	return _rig

## Le survol. Un harnais le coupe et le pilote à la main pour une capture.
func cursor() -> CellCursor:
	return _cursor

## La métrique du plateau, celle sur laquelle tout ce qu'on y posera doit s'aligner.
func metrics() -> TerrainMetrics:
	return _metrics

## Montre cette grille : le sol, ses décorations, et le survol qui la désigne.
## La métrique ne change pas — elle vient de l'équilibrage et vaut pour la partie.
func show_grid(grid: HeightGrid) -> void:
	assert(grid != null, "plateau sans grille")
	_renderer.rebuild(grid)
	for decor_pass in _decor:
		decor_pass.rebuild(grid)
	_cursor.set_grid(grid)

## Tous les terrains connus, décorés ou non.
##
## Les passes de décoration se construisent sur la palette et non sur la grille : un
## seed qui ne sortirait aucun rocher ne doit pas supprimer la passe des rochers, que
## le seed suivant remplirait.
static func _palette() -> Array[TerrainData]:
	var terrains: Array[TerrainData] = []
	for id in GameDatabase.list_terrain_ids():
		terrains.append(GameDatabase.get_terrain(id))
	return terrains

## Fait avancer le soleil **vers l'avant** jusqu'à ce moment du cycle.
##
## `whole_turn` demande une révolution entière quand on y est déjà, ce qui est le cas normal
## d'un tour passé depuis le repos ; sans lui, « aller à midi » depuis midi ne bougerait pas.
##
## **La cible est relative et jamais absolue.** La première version visait `REST + 1.0` et
## `_apply()` gardait le moment sans le replier : le premier tour menait le soleil à 1,25, et
## tous les suivants lui demandaient d'aller là où il était déjà — **la course ne se jouait
## qu'une fois, au premier jour**. Rien ne plantait, rien ne compilait de travers, et aucune
## capture ne pouvait le montrer, puisqu'une image fixe ne dit rien d'un mouvement absent.
##
## Le défaut demandait **les deux moitiés à la fois**, et je m'en suis aperçu en essayant de
## le refaire pour vérifier que la sonde le voyait : avec le repli, la cible absolue est
## inoffensive. Le repli est donc la cause, la cible relative est la ceinture. Les deux
## restent, parce que chacune se justifie seule — mais l'ordre des mots comptait, et je
## l'avais écrit à l'envers avant de le vérifier.
##
## La durée suit l'angle parcouru, de sorte que la vitesse angulaire soit **constante** :
## une course interrompue à mi-chemin finit son jour en moins de temps, au lieu de ralentir.
##
## `tween_method` et non six `tween_property` en parallèle : une révolution passe par midi,
## et six interpolations directes couperaient au plus court d'un bout à l'autre — le soleil
## descendrait sous la carte au lieu de la traverser. Une seule valeur animée, six propriétés
## dérivées, et la trajectoire est celle qu'on veut par construction.
##
## Linéaire, et sans adoucissement : une horloge ne ralentit pas au milieu, et adoucir la
## course la ferait traîner précisément dans la nuit, qui est la partie qu'on veut voir
## passer vite.
func _sweep_to(moment: float, seconds: float, whole_turn: bool) -> void:
	var ahead := fposmod(moment - _moment, 1.0)
	if whole_turn and is_zero_approx(ahead):
		ahead = 1.0
	if is_zero_approx(ahead):
		return
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
	_slide.tween_method(_apply, _moment, _moment + ahead, maxf(seconds * ahead, 0.01))

## Éclaire ce moment du cycle, **sur-le-champ**.
##
## Trois quantités en sortent, et elles suffisent à tout :
##
##   - `noon` — la hauteur du soleil, nulle à l'horizon et en dessous, pleine à midi. C'est
##     elle qui décide de la teinte chaude, de l'énergie et de la hauteur d'incidence.
##   - `progress` — où l'on en est du lever au coucher, et **périodique** : 0 à l'aube, 1 au
##     crépuscule, et de retour à 0 en repassant par la nuit. C'est elle qui fait passer la
##     teinte de l'aube à celle du soir.
##   - `night` — le poids de la lune, nul tant que le soleil est levé, et **étalé sur toute
##     la descente** : c'est la direction de la lumière qui bascule avec lui, pas seulement
##     son intensité, et un fondu court se voit comme un à-coup.
##
## La **direction**, elle, ne se mélange pas : elle se calcule. Le lacet tourne d'un tour
## complet à vitesse constante, et l'inclinaison suit `|sin|`, donc la lumière reste toujours
## au-dessus de l'horizon — haute à midi, rasante aux deux bouts du jour, haute à nouveau à
## minuit. C'est ce qui supprime l'à-coup : il n'y a plus de virage vers un luminaire posé
## ailleurs, il n'y a qu'une rotation.
func _apply(moment: float) -> void:
	# Replié ici et non chez l'appelant : la course avance sur une valeur croissante, et
	# c'est ce repli qui empêche `_moment` de dériver d'un tour à l'autre — donc qui rend
	# la cible relative de `_sweep_to()` correcte au dixième jour comme au premier.
	_moment = fposmod(moment, 1.0)
	var angle := _moment * TAU
	var noon := maxf(0.0, sin(angle))
	var progress := (1.0 - cos(angle)) * 0.5
	var night := smoothstep(0.0, 1.0, clampf(-sin(angle) / NIGHT_DEPTH, 0.0, 1.0))

	var horizon := SUN_DAWN_COLOR.lerp(SUN_DUSK_COLOR, progress)
	var day_colour := horizon.lerp(SUN_HIGH_COLOR, noon)
	var day_energy := SUN_ENERGY * lerpf(SUN_LOW_ENERGY, 1.0, noon)
	var day_sky := DAWN_SKY_COLOR.lerp(DUSK_SKY_COLOR, progress).lerp(SKY_COLOR, noon)
	var day_ambient := DAWN_AMBIENT_COLOR.lerp(DUSK_AMBIENT_COLOR, progress) \
		.lerp(AMBIENT_COLOR, noon)
	var day_ambient_energy := lerpf(DUSK_AMBIENT_ENERGY, AMBIENT_ENERGY, noon)

	_sun.rotation_degrees = Vector3(
		lerpf(SUN_HORIZON_PITCH, SUN_ROTATION_DEGREES.x, absf(sin(angle))),
		SUN_ROTATION_DEGREES.y + rad_to_deg(angle) - QUARTER_DEGREES,
		0.0)
	_sun.light_color = day_colour.lerp(MOON_COLOR, night)
	_sun.light_energy = lerpf(day_energy, MOON_ENERGY, night)
	_environment.background_color = day_sky.lerp(NIGHT_SKY_COLOR, night)
	_environment.ambient_light_color = day_ambient.lerp(NIGHT_AMBIENT_COLOR, night)
	_environment.ambient_light_energy = lerpf(day_ambient_energy, NIGHT_AMBIENT_ENERGY,
		night)

static func _make_environment() -> WorldEnvironment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = AMBIENT_ENERGY
	var node := WorldEnvironment.new()
	node.name = "Environment"
	node.environment = environment
	return node

static func _make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION_DEGREES
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	# Une seule carte d'ombre, pas de cascades.
	#
	# Le défaut de Godot en découpe quatre selon la profondeur, chacune à une
	# résolution différente et sans fondu entre elles. Sous une caméra orthogonale la
	# profondeur croît linéairement du bas vers le haut de l'écran : ces frontières
	# deviennent des lignes horizontales FIXES à l'écran, nettes d'un côté et floues de
	# l'autre, que le terrain traverse quand on déplace la vue. Les cascades servent à
	# couvrir un horizon lointain ; ici la scène est bornée et tient dans une carte.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# Serrer la portée sur ce que la caméra voit réellement : la même carte d'ombre
	# étalée sur 400 unités au lieu de 180 divise par deux et demi sa densité de texels.
	sun.directional_shadow_max_distance = CameraRig.ORBIT_DISTANCE + SUN_SHADOW_MARGIN
	return sun
