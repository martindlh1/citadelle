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
## C'est aussi le **milieu de la course** ci-dessous, et le soleil y passe à midi. Une
## journée à deux phases ne montre donc jamais cette valeur-là : elle en montre les deux
## bords. C'est voulu — T2 l'a réglée comme le meilleur compromis d'une image fixe, et la
## question d'un soleil qui bouge est ailleurs.
const SUN_ROTATION_DEGREES := Vector3(-52.0, -125.0, 0.0)
const SUN_ENERGY := 1.15

## Le lacet que le soleil gagne du matin au soir, de part et d'autre de midi.
##
## Quatre-vingt-dix degrés en tout, et ce n'est pas un chiffre rond choisi pour être rond :
## les colonnes du terrain sont alignées sur la grille, donc leurs quatre flancs regardent
## 0, 90, 180 et 270. Un soleil dont le lacet tombe sur un multiple de 45 donne la même
## valeur à deux flancs et **aplatit le relief** — c'est la même raison qui a décalé le
## soleil de l'axe de la caméra à T2. À ±45° de −125, les deux bouts de la course tombent
## à dix degrés d'un multiple de 45, exactement comme la valeur de midi. La course est donc
## la plus large qui garde ses deux extrémités aussi lisibles que le réglage d'origine.
const SUN_YAW_SWEEP := 45.0

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

## La nuit : une lune froide, basse en énergie, et son lacet.
##
## Elle garde un lacet **décalé** pour la raison qui vaut au soleil : une nuit qui aplatit
## le relief est une nuit où l'on ne voit plus où poser un bâtiment. Elle vient de l'autre
## côté, ce qui inverse les flancs éclairés et se lit tout de suite comme un autre moment.
const MOON_ROTATION_DEGREES := Vector3(-58.0, 55.0, 0.0)
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

## Durée du glissement d'un moment à l'autre.
##
## Court : c'est une **transition** et non un cycle jour/nuit qui tourne tout seul. Le
## soleil ne bouge qu'aux moments où la partie change de phase, et le glissement est là
## pour qu'on voie *que* ça a changé, pas pour qu'on le regarde.
const LIGHT_SLIDE_SECONDS := 0.9

## Marge de portée des ombres au-delà du recul du rig. Elle doit couvrir la moitié
## arrière de ce que la caméra voit au zoom le plus large ; en dessous, le fond de la
## carte perd son ombre, au-dessus chaque texel de la carte d'ombre couvre plus de
## monde pour rien et tout se floute.
const SUN_SHADOW_MARGIN := 60.0

## La nuit, et « rien n'a encore été éclairé ». Deux valeurs hors de [0, 1], donc hors de
## toute progression de journée possible : le premier appel glisse donc toujours.
const NIGHT := -1.0
const UNLIT := -2.0

var _metrics: TerrainMetrics
var _renderer: TerrainRenderer
var _decor: Array[TerrainDecorRenderer]
var _rig: CameraRig
var _cursor: CellCursor
var _sun: DirectionalLight3D
var _environment: Environment

## Le glissement en cours, gardé pour être tué par le suivant. Sans ça, deux transitions
## rapprochées — une phase franchie puis une bataille armée — tirent la même propriété
## chacune de son côté et le soleil hésite à mi-chemin. Même précaution que le tween de
## rotation de `CameraRig`.
var _slide: Tween

## Le moment actuellement éclairé : 0 au lever, 1 au coucher, et NIGHT pour la nuit.
##
## Il existe pour que `light_day()` soit appelable **à chaque image** sans relancer son
## glissement, exactement comme les vues du HUD se mettent à jour sur place plutôt que de
## se reconstruire. L'appelant n'a donc aucune liste de gestes à énumérer — et c'est ce qui
## évite l'oubli que `CLAUDE.md` décrit : un moment qui ne changerait qu'à la phase
## résoudrait mal une bataille armée ou une fin de run.
var _moment := UNLIT

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
## `progress` est la position de la phase dans sa journée, et **pas** un nom de phase :
## `DESIGN.md` 2 pose qu'aucun nom n'apparaît dans le code, et le prendre en fraction rend
## la chose vraie sans effort. Une journée à deux phases montre le matin et le soir ; une
## journée à trois gagne un midi sans qu'une ligne change. C'est la même promesse que
## `PhaseDef` tient depuis `I1` — changer la journée est une édition de `.tres`.
##
## Appelable à chaque image : sans changement de moment, elle ne fait rien.
func light_day(progress: float) -> void:
	_light(clampf(progress, 0.0, 1.0))

## Éclaire la nuit. Ce que le harnais en fait — une bataille, une fin de run, une journée
## refermée — ne regarde pas le plateau.
func light_night() -> void:
	_light(NIGHT)

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

## Fait glisser le plateau vers ce moment, s'il n'y est pas déjà.
##
## Cinq propriétés glissent ensemble : l'orientation du soleil, sa teinte, son énergie,
## puis le ciel et l'ambiante. Les cinq sur le **même** tween en parallèle, sinon le soleil
## se coucherait pendant que le ciel serait encore à midi.
func _light(moment: float) -> void:
	if is_equal_approx(moment, _moment):
		return
	_moment = moment
	if _slide != null and _slide.is_valid():
		_slide.kill()
	var night := is_equal_approx(moment, NIGHT)
	# La hauteur suit un arc : rasante aux deux bouts, haute au milieu. Un sinus le dit
	# en une ligne là où deux interpolations dos à dos demanderaient de traiter le milieu
	# comme un cas.
	var noon := 0.0 if night else sin(moment * PI)
	var rotation := MOON_ROTATION_DEGREES if night else Vector3(
		lerpf(SUN_HORIZON_PITCH, SUN_ROTATION_DEGREES.x, noon),
		SUN_ROTATION_DEGREES.y + lerpf(-SUN_YAW_SWEEP, SUN_YAW_SWEEP, moment),
		0.0)
	var horizon := SUN_DAWN_COLOR.lerp(SUN_DUSK_COLOR, moment)
	var colour := MOON_COLOR if night else horizon.lerp(SUN_HIGH_COLOR, noon)
	var energy := MOON_ENERGY if night \
		else SUN_ENERGY * lerpf(SUN_LOW_ENERGY, 1.0, noon)
	var edge_sky := DAWN_SKY_COLOR.lerp(DUSK_SKY_COLOR, moment)
	var sky := NIGHT_SKY_COLOR if night else edge_sky.lerp(SKY_COLOR, noon)
	var edge_ambient := DAWN_AMBIENT_COLOR.lerp(DUSK_AMBIENT_COLOR, moment)
	var ambient := NIGHT_AMBIENT_COLOR if night \
		else edge_ambient.lerp(AMBIENT_COLOR, noon)
	var ambient_energy := NIGHT_AMBIENT_ENERGY if night \
		else lerpf(DUSK_AMBIENT_ENERGY, AMBIENT_ENERGY, noon)

	_slide = create_tween().set_parallel(true)
	_slide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_property(_sun, "rotation_degrees", rotation, LIGHT_SLIDE_SECONDS)
	_slide.tween_property(_sun, "light_color", colour, LIGHT_SLIDE_SECONDS)
	_slide.tween_property(_sun, "light_energy", energy, LIGHT_SLIDE_SECONDS)
	_slide.tween_property(_environment, "background_color", sky, LIGHT_SLIDE_SECONDS)
	_slide.tween_property(_environment, "ambient_light_color", ambient,
		LIGHT_SLIDE_SECONDS)
	_slide.tween_property(_environment, "ambient_light_energy", ambient_energy,
		LIGHT_SLIDE_SECONDS)

## Pose le plateau sur ce moment **sans glisser**. Ce dont une capture a besoin : trois
## images de chauffe ne suffisent pas à une transition de neuf dixièmes de seconde, donc
## une capture scriptée photographierait un soleil à mi-course.
func settle_light(moment: float) -> void:
	_light(moment)
	if _slide != null and _slide.is_valid():
		_slide.custom_step(LIGHT_SLIDE_SECONDS)

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
