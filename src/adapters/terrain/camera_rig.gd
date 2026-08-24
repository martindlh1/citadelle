class_name CameraRig
extends Node3D
## Caméra isométrique : orbite par quarts de tour, zoom, pan dans le plan de la carte.
##
## Le rig porte piqué et lacet, la Camera3D enfant recule sur l'axe local. L'ordre
## d'Euler YXZ — le défaut de Node3D, réaffirmé ici parce que tout en dépend —
## applique le lacet AVANT le piqué : rotation_degrees.y fait donc bien tourner la
## caméra autour de l'axe vertical du monde, et pas autour d'un axe déjà penché.
##
## La projection est orthogonale, donc le zoom est camera.size et non une distance.
## Le recul de la caméra ne joue que sur le plan proche.
##
## Le rig lit son propre input, derrière input_enabled. Une scène de jeu qui veut ses
## propres liaisons coupe le drapeau et appelle l'API : rotate_steps, zoom_by, pan_by.
## Aucune action d'input n'est utilisée — que des touches brutes et la molette — pour
## que le rig fonctionne sans rien ajouter à project.godot.

## Piqué de l'isométrique vrai : -atan(1/sqrt(2)). Décision figée de CLAUDE.md, pas un
## réglage — il n'a donc rien à faire dans CameraBalance.
const ISO_PITCH_DEGREES := -35.264

## Lacet de départ. Le piqué seul ne fait pas l'isométrique : il y faut aussi ces 45°,
## qui sont ce qui projette une grille carrée en losanges. Ils changent tout au rendu
## d'un relief en blocs — à lacet nul la vue est alignée sur les axes, chaque colonne
## ne montre qu'un seul de ses flancs, et les marches se lisent comme des traits. À 45°
## deux flancs sont visibles, à deux éclairements différents, et le volume apparaît.
const ISO_YAW_DEGREES := 45.0

## Amplitude d'un cran de rotation. La caméra ne s'arrête qu'aux quatre orientations
## dérivées de ISO_YAW_DEGREES, où la carte se présente de la même façon d'un coin ou
## d'un autre.
const YAW_STEP_DEGREES := 90.0

## Fraction d'une distance horizontale qui se retrouve à la verticale de l'écran au
## piqué isométrique, soit sin(35.264°). Cadrer sur cette fraction plutôt que sur
## l'emprise entière évite de démarrer inutilement loin.
const PITCH_FORESHORTENING := 0.5774

## Recul de la caméra sur son axe local. Sans effet sur l'échelle en projection
## orthogonale : il ne sert qu'à garder toute la carte devant le plan proche.
const ORBIT_DISTANCE := 120.0

const NEAR_PLANE := 0.05
const FAR_PLANE := 600.0

## Le rig répond-il au clavier et à la souris ? Une scène qui pilote la caméra
## elle-même met ce drapeau à false et garde l'API.
var input_enabled := true

var _balance: CameraBalance
var _camera: Camera3D
var _yaw_steps := 0
var _rotation_tween: Tween
var _is_dragging := false
var _framed_center := Vector3.ZERO
var _framed_extent := Vector2.ZERO

## Rig prêt à être ajouté à l'arbre, caméra comprise. Cadrer ensuite avec frame().
static func create(balance: CameraBalance) -> CameraRig:
	assert(balance != null, "réglages de caméra null")
	assert(balance.missing_fields().is_empty(),
		"réglages de caméra inexploitables : %s" % ", ".join(balance.missing_fields()))
	var rig := CameraRig.new()
	rig.name = "CameraRig"
	rig._balance = balance
	# Explicite bien que ce soit le défaut : l'orbite autour de l'axe vertical du
	# monde n'est correcte que si le lacet s'applique avant le piqué.
	rig.rotation_order = EULER_ORDER_YXZ
	rig.rotation_degrees = Vector3(ISO_PITCH_DEGREES, ISO_YAW_DEGREES, 0.0)
	rig._camera = _make_camera(balance)
	rig.add_child(rig._camera)
	return rig

## Caméra du rig. C'est elle qui fournira origin et dir au CellPicker à T3.
func get_camera() -> Camera3D:
	return _camera

## Vise ce point et règle le zoom pour que cette emprise au sol tienne à l'écran.
## Le cadrage est mémorisé : refit() y revient.
func frame(center: Vector3, extent: Vector2) -> void:
	_framed_center = center
	_framed_extent = extent
	position = center
	# La diagonale, et non le plus grand côté : à 45° de lacet, c'est la diagonale de
	# la carte qui barre l'écran, et elle reste la même aux quatre orientations.
	_set_zoom(extent.length() * PITCH_FORESHORTENING * _balance.frame_margin)

## Revient au dernier cadrage et remet la carte d'aplomb. Sans frame() préalable,
## ne fait rien.
func refit() -> void:
	if _framed_extent == Vector2.ZERO:
		return
	frame(_framed_center, _framed_extent)
	rotate_steps(-_yaw_steps)

## Fait pivoter le rig de ce nombre de quarts de tour, en interpolant.
##
## Le cran cible s'accumule et n'est jamais ramené dans [0, 360) : enchaîner quatre
## quarts de tour doit faire un tour complet, alors qu'une valeur repliée ferait
## rebrousser chemin au quatrième.
func rotate_steps(steps: int) -> void:
	if steps == 0:
		return
	_yaw_steps += steps
	var target := ISO_YAW_DEGREES + _yaw_steps * YAW_STEP_DEGREES
	if _rotation_tween != null and _rotation_tween.is_valid():
		_rotation_tween.kill()
	if not is_inside_tree():
		rotation_degrees.y = target
		return
	_rotation_tween = create_tween()
	_rotation_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_rotation_tween.tween_property(self, "rotation_degrees:y", target,
		_balance.rotation_seconds)

## Zoome de ce nombre de crans de molette. Positif rapproche. Clampé sur la plage
## d'équilibrage, donc toujours sans effet de bord.
func zoom_by(notches: int) -> void:
	if notches == 0:
		return
	_set_zoom(_camera.size * pow(_balance.zoom_factor, -notches))

## Déplace le rig dans le plan XZ, d'un delta exprimé en pixels d'écran.
##
## Le delta est converti au zoom courant : un même geste parcourt toujours la même
## distance à l'écran. Le rig SUIT le delta ; pour un pan « on attrape la carte »,
## l'appelant passe l'opposé du déplacement du curseur.
func pan_by(screen_delta: Vector2) -> void:
	if screen_delta == Vector2.ZERO:
		return
	var height := _viewport_height()
	if height <= 0.0:
		return
	_pan_world(screen_delta * (_camera.size / height))

func _process(delta: float) -> void:
	if not input_enabled or _camera == null:
		return
	var direction := _pan_direction()
	if direction == Vector2.ZERO:
		return
	# pan_speed est en hauteurs d'écran par seconde : la vitesse ressentie ne dépend
	# donc pas du zoom, alors que la distance parcourue dans le monde, si.
	_pan_world(direction * (_balance.pan_speed * _camera.size * delta))

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or _camera == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_by(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_by(-1)
		MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_dragging:
		return
	# On attrape la carte : elle suit le curseur, donc le rig part à l'opposé.
	pan_by(-event.relative)
	get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			rotate_steps(1)
		KEY_E:
			rotate_steps(-1)
		KEY_R:
			refit()
		_:
			return
	get_viewport().set_input_as_handled()

## Direction du pan au clavier, normalisée, dans les axes de l'écran.
##
## Lue en direct et non en évènements : une touche maintenue doit faire glisser en
## continu, pas répéter au rythme du clavier.
func _pan_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	return direction.normalized()

## Déplace le rig d'un delta exprimé dans les axes de l'écran, en unités de monde :
## x vers la droite de l'écran, y vers le bas de l'écran.
func _pan_world(delta: Vector2) -> void:
	# basis.x reste horizontal quel que soit le piqué, qui tourne autour de X. basis.z,
	# lui, plonge : le rabattre dans le plan XZ est ce qui empêche le pan de faire
	# décoller ou s'enfoncer la caméra.
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0:
		return
	global_position += global_basis.x * delta.x - forward.normalized() * delta.y

func _set_zoom(size: float) -> void:
	_camera.size = clampf(size, _balance.zoom_min, _balance.zoom_max)

func _viewport_height() -> float:
	if not is_inside_tree():
		return 0.0
	return get_viewport().get_visible_rect().size.y

static func _make_camera(balance: CameraBalance) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = balance.zoom_max
	camera.near = NEAR_PLANE
	camera.far = FAR_PLANE
	camera.position = Vector3(0.0, 0.0, ORBIT_DISTANCE)
	return camera
