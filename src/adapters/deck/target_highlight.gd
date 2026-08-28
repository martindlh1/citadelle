class_name TargetHighlight
extends MultiMeshInstance3D
## Un jeu de cellules marquées d'une dalle : les cibles d'une carte, ou ce qu'un corps
## peut atteindre en combat.
##
## Vue pure. Elle ne décide RIEN : on lui donne une liste de cellules déjà validées et
## elle les marque. C'est la même discipline que PlacementGhost, qui reçoit un
## PlacementResult déjà calculé et se contente de le colorer — si la surbrillance
## réévaluait la moindre règle, l'écran et la pose pourraient se contredire.
##
## Elle montre les cibles **acceptées** et non le verdict de la cellule survolée, ce qui
## est l'autre moitié du travail et appartient à CellHighlight, déjà posée par DevWorld.
## Les deux se superposent sans se gêner : l'une dit « voilà où cette carte peut aller »,
## l'autre « voilà où je pointe ».
##
## Le jeu de cibles se recalcule quand la sélection change, jamais à chaque image. Un
## balayage de carte par image coûterait mille validations soixante fois par seconde
## pour un résultat qui ne bouge que lorsqu'on prend une autre carte, qu'on pose une
## action ou qu'on bâtit. C'est l'appelant qui décide quand rafraîchir ; cette classe ne
## garde rien.

## Épaisseur de la dalle, en fractions de tuile. Plus fine que CellHighlight : elle
## couvre potentiellement un tiers de la carte, et doit rester un voile.
const THICKNESS_RATIO := 0.03

## Décollement de la surface, en fractions de tuile. Comme ailleurs, il n'existe que
## pour les angles rasants où deux surfaces qui se touchent scintillent.
const LIFT_RATIO := 0.006

## Teinte des cibles acceptées. Franche mais très translucide : on doit lire le terrain
## à travers, puisque c'est lui qui explique pourquoi la case est une cible.
const TARGET_COLOR := Color(0.40, 0.90, 0.95, 0.30)

var _metrics: TerrainMetrics
var _tint := TARGET_COLOR

## Surbrillance prête à être ajoutée à l'arbre, invisible tant qu'aucune carte n'est
## tenue.
##
## La **teinte est un argument** depuis `F3a`, et c'est la seule chose que ce fichier ait
## gagnée en changeant de métier. Le combat en pose deux d'un coup — où l'on peut aller, ce
## qu'on peut frapper — et deux voiles de la même couleur seraient un seul voile. Rien
## d'autre ne bouge : la vue reçoit toujours une liste de cellules déjà validées et se
## contente de les marquer.
static func create(metrics: TerrainMetrics, tint := TARGET_COLOR) -> TargetHighlight:
	assert(metrics != null, "surbrillance de cibles sans métrique")
	var highlight := TargetHighlight.new()
	highlight.name = "TargetHighlight"
	highlight._metrics = metrics
	highlight._tint = tint
	highlight.material_override = _make_material()
	highlight.multimesh = _make_multimesh()
	# Un voile de cibles qui projetterait une ombre dessinerait un damier sombre à côté
	# des cases qu'il désigne.
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.visible = false
	return highlight

## Marque ces cellules, chacune à la hauteur donnée en regard.
##
## Les deux tableaux sont parallèles et de même longueur : une cible sans sa hauteur se
## dessinerait au niveau de la mer, sous le relief, et ne se verrait pas.
func show_targets(cells: Array[Vector2i], heights: PackedInt32Array) -> void:
	assert(_metrics != null, "surbrillance non initialisée — passer par create()")
	assert(cells.size() == heights.size(),
		"%d cibles pour %d hauteurs" % [cells.size(), heights.size()])
	if cells.is_empty():
		clear()
		return
	_reserve(cells.size())
	var tile := _metrics.tile_size()
	var thickness := THICKNESS_RATIO * tile
	for index in cells.size():
		var base := _metrics.cell_surface_center(cells[index], heights[index])
		base.y += thickness * 0.5 + LIFT_RATIO * tile
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), base))
		multimesh.set_instance_color(index, _tint)
	visible = true

## Retire toutes les marques. Aucune carte n'est tenue, ou aucune cible n'existe.
func clear() -> void:
	visible = false

## Assure que le tampon tient `count` dalles, sans le réallouer sans raison.
##
## instance_count ne fait que croître ; c'est visible_instance_count qui découpe. Même
## geste que PlacementGhost, et il compte davantage ici : le jeu de cibles passe
## couramment de trois cases à deux cents en changeant de carte.
func _reserve(count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count
	multimesh.visible_instance_count = count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre que TerrainRenderer et PlacementGhost : le format se fige au premier
	# instance_count non nul, et le régler après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairé, comme les deux autres marques : une cible doit garder sa teinte dans
	# un creux à l'ombre comme sur une crête au soleil. C'est un signal, pas un objet.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
