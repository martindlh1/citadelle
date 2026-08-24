class_name CellHighlight
extends MeshInstance3D
## La marque posée sur la cellule survolée : une dalle fine sur sa face supérieure.
##
## Vue pure, sans input ni domaine. On lui dit quelle cellule marquer, elle la marque.
## C'est CellCursor qui décide laquelle.
##
## Elle ne code AUCUNE validité. Une surbrillance verte ou rouge selon qu'on peut y
## bâtir préempterait Construction, qui n'existe pas encore et à qui la question
## appartient — c'est C2. Ici, une seule couleur : « c'est cette cellule-là ».
##
## Les chiffres vivent en constantes nommées plutôt qu'en data. C'est du décor de
## survol, pas de l'équilibrage, et la vraie mise en forme viendra avec le HUD.

## Épaisseur de la dalle, en fractions de tuile. Assez pour se voir de biais, assez peu
## pour ne pas faire flotter la marque au-dessus du sol.
const THICKNESS_RATIO := 0.06

## Décollement de la face supérieure, en fractions de tuile. La dalle est déjà
## entièrement au-dessus de la colonne ; cette marge n'existe que pour les angles
## rasants, où deux surfaces qui se touchent scintillent.
const LIFT_RATIO := 0.004

## Teinte de la marque. Chaude et translucide : elle doit se lire aussi bien sur le
## vert d'une forêt que sur le bleu de l'eau, sans masquer ce qu'elle désigne.
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.35, 0.55)

var _metrics: TerrainMetrics

## Marque prête à être ajoutée à l'arbre, invisible tant qu'aucune cellule n'est
## désignée.
static func create(metrics: TerrainMetrics) -> CellHighlight:
	assert(metrics != null, "surbrillance sans métrique")
	var highlight := CellHighlight.new()
	highlight.name = "CellHighlight"
	highlight._metrics = metrics
	highlight.mesh = _make_mesh(metrics.tile_size())
	highlight.material_override = _make_material()
	# Une marque de survol qui projette une ombre dessinerait un carré sombre à côté
	# de la cellule qu'elle désigne.
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.visible = false
	return highlight

## Pose la marque sur cette cellule, dont la colonne monte à `height` crans.
func show_cell(cell: Vector2i, height: int) -> void:
	assert(_metrics != null, "surbrillance non initialisée — passer par create()")
	var tile := _metrics.tile_size()
	var anchor := _metrics.cell_surface_center(cell, height)
	# La BoxMesh est centrée sur son origine : on monte d'une demi-épaisseur pour que
	# ce soit sa face du DESSOUS qui repose sur la surface de la cellule.
	anchor.y += (THICKNESS_RATIO * 0.5 + LIFT_RATIO) * tile
	position = anchor
	visible = true

## Retire la marque. Le curseur ne désigne plus rien.
func clear() -> void:
	visible = false

static func _make_mesh(tile: float) -> BoxMesh:
	var box := BoxMesh.new()
	# Exactement une cellule, pas un iota de plus : c'est la marque qui donne au joueur
	# la taille d'une cellule, et l'élargir mentirait sur l'empreinte d'un bâtiment.
	box.size = Vector3(tile, THICKNESS_RATIO * tile, tile)
	return box

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Non éclairée : la marque doit garder la même teinte sur un flanc à l'ombre et
	# sur une crête en plein soleil, sans quoi elle disparaît dans les creux.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = HIGHLIGHT_COLOR
	return material
