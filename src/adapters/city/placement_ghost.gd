class_name PlacementGhost
extends MultiMeshInstance3D
## Le fantôme : les cellules que le bâtiment couvrirait, teintées par la réponse du
## domaine.
##
## Il ne décide RIEN. CellHighlight annonçait déjà à T3 qu'elle ne coderait aucune
## validité et que la question appartiendrait à C2 : la voici, et la réponse vient
## toujours du domaine. Le fantôme reçoit un PlacementResult déjà calculé et le
## colore. Vert accepté, rouge refusé — aucune règle n'est réévaluée ici, sans quoi
## l'écran et la pose pourraient se contredire.
##
## Il dessine TOUTES les cellules de l'empreinte, y compris celles qui débordent de la
## carte. Un bâtiment à moitié dans le vide se voit alors tel qu'il est, ce qui
## explique le refus mieux qu'une empreinte tronquée.

## Teintes du fantôme. Translucides : on doit lire le terrain à travers, sans quoi le
## fantôme cache exactement ce sur quoi on cherche à se décider.
const OK_COLOR := Color(0.45, 0.95, 0.5, 0.45)
const REFUSED_COLOR := Color(0.95, 0.33, 0.28, 0.45)

## Teinte des cases que les règles de voisinage ont trouvées.
##
## Un or franc, distinct des deux autres : elles ne disent ni « posable » ni « refusé », elles
## disent **d'où vient le rendement**. Les confondre avec le vert du oui aurait fait croire à
## une empreinte plus grande que celle du bâtiment.
##
## Une case qui est **à la fois** de l'empreinte et taggée garde la couleur de l'empreinte, et
## c'est le bon arbitrage : ce qu'on doit lire en premier sur une case qu'on s'apprête à
## occuper est si l'on peut l'occuper. Le compte, lui, est au cartouche — il n'oublie personne.
const MATCH_COLOR := Color(1.0, 0.82, 0.30, 0.50)

## Teinte de la portée : les cases où une règle *aurait* compté, si elles avaient porté le tag.
##
## Presque effacée, parce que c'est un contour et non une information : elle répond à « jusqu'où
## regarde ce bâtiment ». Une portée aussi visible que ce qu'elle contient noierait les cases
## qui comptent, qui sont le vrai sujet.
const RANGE_COLOR := Color(0.85, 0.88, 0.95, 0.13)

## Épaisseur des cases de voisinage, en fractions de tuile : une pellicule au sol.
##
## Le fantôme du bâtiment a la hauteur du bâtiment ; ces cases-là sont un marquage au sol et
## pas un volume. Leur donner du corps aurait fabriqué une ville de boîtes dorées autour du
## curseur, et caché le relief qu'on est justement en train de lire.
const MARK_HEIGHT := 0.06

## Distance du cartouche au-dessus du sol, en fractions de tuile.
const TAG_LIFT := 1.4

## Taille du texte du cartouche, en unités de monde par pixel.
##
## Réglée en capture et non au jugé : à 0,006 le chiffre était présent et illisible sous le
## zoom par défaut, ce qui est la pire des deux issues — on croit avoir informé.
const TAG_SIZE := 0.013

## Décollement de la surface, en fractions de tuile. La boîte repose déjà dessus ;
## cette marge n'existe que pour les angles rasants, où deux surfaces qui se touchent
## scintillent.
const LIFT_RATIO := 0.004

var _metrics: TerrainMetrics
var _tag: Label3D

## Fantôme prêt à être ajouté à l'arbre, invisible tant que rien n'est visé.
static func create(metrics: TerrainMetrics) -> PlacementGhost:
	assert(metrics != null, "fantôme sans métrique")
	var ghost := PlacementGhost.new()
	ghost.name = "PlacementGhost"
	ghost._metrics = metrics
	ghost.material_override = _make_material()
	ghost.multimesh = _make_multimesh()
	# Un fantôme qui projette une ombre dessinerait un bâtiment qui n'existe pas encore.
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost._tag = _make_tag()
	ghost.add_child(ghost._tag)
	ghost.visible = false
	return ghost

## Montre ce bâtiment posé sur cette ancre, dans cette orientation, au sol de hauteur
## `ground`, teinté par `result`.
##
## `ground` est passé à part et n'est pas lu sur le résultat : un refus n'a pas de
## hauteur — PlacementResult.height() lève sur un placement refusé, et c'est justement
## sur un refus qu'on a le plus besoin de voir le fantôme. La hauteur vient donc de la
## cellule survolée, qui est toujours connue.
##
## L'orientation est passée à part pour la même raison de fond : le fantôme redessine
## exactement ce que la validation vient d'examiner, et les deux doivent lire la même
## ancre et les mêmes crans, sans quoi la couleur cesserait de porter sur la forme
## affichée.
func show_at(data: BuildingData, anchor: Vector2i, turns: int, ground: int,
		result: PlacementResult, bonus: AdjacencyReport, terrain: TerrainQuery) -> void:
	assert(data != null, "fantôme sans données de bâtiment")
	assert(result != null, "fantôme sans résultat")
	assert(bonus != null, "fantôme sans relevé de voisinage")
	assert(_metrics != null, "fantôme non initialisé — passer par create()")
	var cells := data.cells_at(anchor, turns)
	if cells.is_empty():
		clear()
		return

	# L'ordre de peinture est l'ordre de lecture, et il est inverse de l'importance : la
	# portée d'abord, les cases qui comptent par-dessus, l'empreinte en dernier. Une case
	# peut appartenir aux trois — une cabane posée sur un arbre —, et c'est alors la plus
	# précise qui doit rester visible.
	var painted: Dictionary[Vector2i, Color] = {}
	for cell in _range_of(data, anchor, turns):
		painted[cell] = RANGE_COLOR
	for cell in bonus.highlights():
		painted[cell] = MATCH_COLOR
	var footprint := OK_COLOR if result.is_ok() else REFUSED_COLOR
	for cell in cells:
		painted[cell] = footprint

	var tile := _metrics.tile_size()
	var thickness := data.height * tile
	_reserve(painted.size())
	var index := 0
	for cell in painted:
		var solid := painted[cell] == footprint
		# Les cases de voisinage se posent au sol de la case qu'elles marquent et non à
		# celui du bâtiment : elles décrivent le terrain, donc elles doivent l'épouser.
		# Une pellicule flottant au niveau de l'ancre marquerait la mauvaise altitude.
		var level := ground if solid else _ground_of(terrain, cell, ground)
		var height := thickness if solid else MARK_HEIGHT * tile
		var base := _metrics.cell_surface_center(cell, level)
		base.y += height * 0.5 + LIFT_RATIO * tile
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(Vector3(tile, height, tile)), base))
		multimesh.set_instance_color(index, painted[cell])
		index += 1
	_show_tag(bonus, cells[0], ground, tile)
	visible = true

## Les cases qu'une règle de ce bâtiment regarde, quel que soit ce qu'elles portent.
##
## C'est la **portée**, et elle se calcule sur la géométrie seule — pas de terrain, donc pas de
## risque de désaccord avec ce que l'audit a compté. Deux règles de rayons différents rendent
## l'union des deux, ce qui est ce qu'un joueur veut voir : jusqu'où ce bâtiment regarde.
func _range_of(data: BuildingData, anchor: Vector2i, turns: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for rule in data.adjacency:
		var area := data.neighbourhood_at(anchor, rule.radius, turns)
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				if seen.has(cell):
					continue
				seen[cell] = true
				cells.append(cell)
	return cells

## L'altitude de cette case, ou celle du bâtiment si elle sort de la carte.
##
## Le repli existe parce que la portée déborde volontiers : `height_at()` exige une cellule
## dans la grille, et un fantôme promené au bord en sort à chaque image.
func _ground_of(terrain: TerrainQuery, cell: Vector2i, fallback: int) -> int:
	if terrain == null or not terrain.in_bounds(cell):
		return fallback
	return terrain.height_at(cell)

## Le cartouche posé au-dessus du bâtiment : ce que cette case rapporterait.
##
## **En 3D et non dans le HUD**, et c'est le sujet de la demande : on regarde la carte quand on
## choisit une case. Un chiffre rangé dans un coin oblige à un aller-retour entre la case et le
## panneau, ce qui revient à ne pas l'avoir.
##
## Il se tait quand le bâtiment n'a aucune règle : la plupart n'en ont pas, et un cartouche vide
## suspendu au-dessus d'une palissade serait du bruit à chaque image.
func _show_tag(bonus: AdjacencyReport, anchor_cell: Vector2i, ground: int,
		tile: float) -> void:
	_tag.visible = not bonus.is_empty()
	if bonus.is_empty():
		return
	var parts := PackedStringArray()
	for index in bonus.size():
		parts.append("+%d" % bonus.award(index))
	_tag.text = " ".join(parts)
	# Le rouge dit « rien ici », et il dit la même chose que le refus du placement, ce qui
	# est voulu : sur un bâtiment à règles, ne rien trouver EST le motif de refus.
	_tag.modulate = Color.WHITE if bonus.is_satisfied() else REFUSED_COLOR
	_tag.position = _metrics.cell_surface_center(anchor_cell, ground) \
		+ Vector3(0.0, TAG_LIFT * tile, 0.0)

## Retire le fantôme. Plus rien n'est visé.
func clear() -> void:
	visible = false

## Assure que le tampon tient `count` boîtes, sans le réallouer à chaque image.
##
## instance_count ne fait que croître ; c'est visible_instance_count qui découpe. Le
## fantôme est reconstruit à chaque image sous le curseur, et redimensionner le tampon
## soixante fois par seconde pour trois boîtes serait absurde.
func _reserve(count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count
	multimesh.visible_instance_count = count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# Même ordre que TerrainRenderer : le format se fige au premier instance_count non
	# nul, et le régler après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

## Le cartouche : un Label3D qui fait toujours face à la caméra et que rien ne masque.
##
## `NO_DEPTH_TEST` parce qu'il est posé au-dessus d'un bâtiment qui peut être derrière une
## crête : un chiffre à moitié enfoncé dans le relief est pire qu'absent, il se lit de travers.
## Billboard parce que la caméra pivote par quarts de tour et qu'un texte doit rester lisible
## aux quatre.
static func _make_tag() -> Label3D:
	var tag := Label3D.new()
	tag.name = "YieldTag"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 64
	tag.outline_size = 16
	tag.pixel_size = TAG_SIZE
	tag.modulate = Color.WHITE
	tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	tag.visible = false
	return tag

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairé : le fantôme doit garder sa teinte sur un flanc à l'ombre comme sur
	# une crête au soleil. Vert et rouge sont un signal, pas un objet de la scène.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
