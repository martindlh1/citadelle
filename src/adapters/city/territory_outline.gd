class_name TerritoryOutline
extends MultiMeshInstance3D
## Le périmètre de l'emprise du village, posé sur le relief.
##
## Il ne décide rien : il reçoit les cellules que `Territory` a calculées et dessine leur
## **bord**. La frontière affichée est donc exactement celle que le placement applique — c'est
## la même fonction du domaine qui répond aux deux, et un désaccord entre l'écran et le clic
## serait la panne la plus muette qui soit : une bordure dans laquelle poser refuse.
##
## ---
##
## **Il en existe deux exemplaires à l'écran**, et ils ne disent pas la même chose : l'emprise
## **acquise**, qui ne bouge qu'à la pose et à l'achèvement d'un chantier, et celle que le
## bâtiment sous le curseur **ouvrirait** s'il était posé là. Le second se refait à chaque
## image, comme le fantôme qu'il accompagne, et il est d'une teinte franchement différente —
## sans quoi les deux tracés qui se croisent n'en feraient qu'un.
##
## **Un contour et non une nappe**, et c'est la demande à la lettre. Une surface teintée sur un
## tiers de la carte cacherait le relief, les bosquets et les gisements, c'est-à-dire tout ce
## qu'on regarde au moment de choisir une case. Une frontière dit la même chose et ne masque
## rien.
##
## **Le bord se déduit case par case**, sans jamais raisonner sur des cercles : une cellule de
## l'emprise dont le voisin n'en est pas porte un segment de frontière de ce côté-là. C'est ce
## qui fait que la réunion de plusieurs disques rend un contour juste — lobes, creux et enclaves
## comprises — alors qu'un tracé de cercles aurait demandé de gérer leurs intersections, et se
## serait trompé exactement là où la forme devient intéressante.
##
## **Chaque segment s'assoit à la hauteur de sa propre case.** Le contour épouse donc les
## terrasses au lieu de flotter à une altitude moyenne, et il se lit comme une ligne tracée au
## sol plutôt que comme un plan de coupe.

## Teinte de l'emprise **en vigueur**. Une craie pâle, franchement translucide : c'est un
## repère, pas un objet de la scène, et il est affiché en permanence — ce qui interdit qu'il
## attire l'œil.
const SETTLED_COLOR := Color(0.98, 0.92, 0.62, 0.55)

## Teinte de l'emprise que le fantôme **ouvrirait**.
##
## Franchement froide là où l'autre est chaude, et c'est le point : les deux contours se
## croisent en permanence sous le curseur, et deux nuances d'une même teinte se seraient lues
## comme un seul tracé un peu épais. Ce qui est acquis est jaune, ce qui est promis est bleu.
const PROMISED_COLOR := Color(0.45, 0.80, 1.0, 0.60)

## Largeur d'un segment, en fractions de tuile.
const THICKNESS := 0.08

## Hauteur d'un segment, en fractions de tuile.
##
## Un ruban à peine debout plutôt qu'une pellicule au sol : posé à plat il disparaissait sous
## la caméra isométrique dès que la frontière suivait une arête de terrasse.
const HEIGHT := 0.10

## Décollement de la surface, en fractions de tuile. Même raison que sur le fantôme : deux
## surfaces qui se touchent scintillent aux angles rasants.
const LIFT_RATIO := 0.004

## Les quatre côtés d'une cellule : le voisin à tester, et l'axe le long duquel court le
## segment quand ce voisin est dehors.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, 0)]

var _metrics: TerrainMetrics
var _color := SETTLED_COLOR

## Contour prêt à être ajouté à l'arbre, invisible tant qu'aucune emprise n'est posée.
##
## La teinte est un argument plutôt qu'une constante parce que **le harnais en monte deux** :
## l'emprise acquise et celle que le fantôme ouvrirait. Deux classes jumelles pour une couleur
## auraient été le doublon que `N2` a déjà refusé sur les vues du HUD — et la seconde aurait
## fini par diverger sur l'épaisseur ou sur la façon d'épouser le relief.
static func create(metrics: TerrainMetrics, color := SETTLED_COLOR) -> TerritoryOutline:
	assert(metrics != null, "contour sans métrique")
	var outline := TerritoryOutline.new()
	outline.name = "TerritoryOutline"
	outline._metrics = metrics
	outline._color = color
	outline.material_override = _make_material()
	outline.multimesh = _make_multimesh()
	# Un contour qui projetterait une ombre dessinerait un muret qui n'existe pas.
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.visible = false
	return outline

## Dessine le bord de ces cellules, dont les hauteurs se lisent sur ce terrain.
##
## L'exemplaire de l'emprise acquise n'est rafraîchi que **quand la ville change** — la pose,
## la démolition, le cran qui achève un chantier —, celui du fantôme à chaque image. C'est
## l'appelant qui décide : le tampon ne se réalloue que s'il grandit, donc un appel par image
## sur un disque d'une trentaine de segments ne coûte rien, alors qu'un balayage de toute la
## carte soixante fois par seconde pour un contour identique en coûterait.
func show_cells(cells: Array[Vector2i], terrain: TerrainQuery) -> void:
	assert(terrain != null, "contour sans terrain")
	assert(_metrics != null, "contour non initialisé — passer par create()")
	if cells.is_empty():
		clear()
		return

	var inside: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		inside[cell] = true

	var tile := _metrics.tile_size()
	var segments: Array[Transform3D] = []
	for cell in cells:
		var level := terrain.height_at(cell) if terrain.in_bounds(cell) else 0
		for side in SIDES:
			if inside.has(cell + side):
				continue
			segments.append(_segment(cell, side, level, tile))
	_reserve(segments.size())
	for index in segments.size():
		multimesh.set_instance_transform(index, segments[index])
		multimesh.set_instance_color(index, _color)
	visible = true

## Retire le contour. Le village n'a pas encore d'emprise.
func clear() -> void:
	visible = false

## Le ruban qui ferme ce côté de cette cellule.
##
## Il court sur toute la largeur de la case dans l'axe perpendiculaire au côté, et n'a
## l'épaisseur du trait que dans l'autre : deux segments voisins se rejoignent alors sans
## laisser de trou d'angle, ce qu'un carré centré aurait fait.
func _segment(cell: Vector2i, side: Vector2i, level: int, tile: float) -> Transform3D:
	var centre := _metrics.cell_surface_center(cell, level)
	var thickness := THICKNESS * tile
	var height := HEIGHT * tile
	var span := Vector3(tile if side.x == 0 else thickness, height,
		tile if side.y == 0 else thickness)
	var offset := Vector3(float(side.x), 0.0, float(side.y)) * (tile - thickness) * 0.5
	centre += offset + Vector3(0.0, height * 0.5 + LIFT_RATIO * tile, 0.0)
	return Transform3D(Basis.IDENTITY.scaled(span), centre)

## Assure que le tampon tient `count` rubans, sans le réallouer à chaque appel.
func _reserve(count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count
	multimesh.visible_instance_count = count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre que TerrainRenderer : le format se fige au premier instance_count non nul.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairé, comme le fantôme : un repère garde sa teinte à l'ombre comme au soleil.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
