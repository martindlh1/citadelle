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

## Orientation du soleil. Volontairement décalée de l'axe de la caméra : c'est ce
## décalage qui donne aux quatre flancs d'une colonne quatre valeurs différentes, donc
## au relief son volume. Un éclairage frontal aplatirait tout.
const SUN_ROTATION_DEGREES := Vector3(-52.0, -125.0, 0.0)
const SUN_ENERGY := 1.15

## Marge de portée des ombres au-delà du recul du rig. Elle doit couvrir la moitié
## arrière de ce que la caméra voit au zoom le plus large ; en dessous, le fond de la
## carte perd son ombre, au-dessus chaque texel de la carte d'ombre couvre plus de
## monde pour rien et tout se floute.
const SUN_SHADOW_MARGIN := 60.0

var _metrics: TerrainMetrics
var _renderer: TerrainRenderer
var _decor: Array[TerrainDecorRenderer]
var _rig: CameraRig
var _cursor: CellCursor

## Plateau prêt à être ajouté à l'arbre, déjà peuplé pour cette grille et cadré dessus.
static func create(grid: HeightGrid, metrics: TerrainMetrics, balance: BalanceData) -> DevWorld:
	assert(grid != null, "plateau sans grille")
	assert(metrics != null, "plateau sans métrique")
	assert(balance != null, "plateau sans équilibrage")
	var world := DevWorld.new()
	world.name = "DevWorld"
	world._metrics = metrics
	world.add_child(_make_environment())
	world.add_child(_make_sun())
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
	return world

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
