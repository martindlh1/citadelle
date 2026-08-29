class_name BodyRenderer
extends Node3D
## Les corps sur le champ de bataille : un pion par combattant debout.
##
## Vue pure, reconstruite quand le plateau bouge. Elle ne décide **rien** : on lui donne un
## plateau et une table de teintes, elle plante des pions. Un renderer qui déciderait de la
## couleur d'un assaillant commuterait sur son identifiant, ce que `CLAUDE.md` refuse depuis
## `TerrainData` — ajouter un type d'ennemi doit rester une édition de `data/`.
##
## **Deux passes, une par camp, parce que deux formes.** Une capsule pour les ouvriers, un
## cône pour les assaillants : une **forme** se lit à l'ombre là où une teinte se perd, et
## sous une caméra qui pivote par quarts de tour on regarde le champ depuis les quatre côtés.
## C'est aussi la seule chose qui distingue les camps quand un pillard se tient derrière une
## colline.
##
## Les deux formes respectent la règle de `T3` : **aucune grande face verticale plate**. Le
## soleil de `DevWorld` n'éclaire que ce qui regarde vers le haut, donc un pion à flancs
## plats se lirait comme un rectangle noir sous au moins une des quatre orientations. La
## capsule et le cône gardent un dégradé sous tous les angles, ce qui est exactement
## l'argument qui a fait retirer le `PrismMesh` du terrain.
##
## Les dimensions sont en **fractions de tuile** et jamais en unités de monde, comme les
## décorations de terrain : régler `tile_size` doit redimensionner la carte entière, pions
## compris.

## Hauteur d'un pion, en fractions de tuile. Assez haut pour se voir par-dessus une marche
## de relief, assez bas pour ne pas cacher la colonne derrière.
const HEIGHT_RATIO := 1.0

## Rayon d'un pion, en fractions de tuile. Nettement moins d'une demi-tuile : deux pions sur
## deux cases voisines doivent laisser voir le sol entre eux.
const RADIUS_RATIO := 0.30

## Rapport du sommet à la base pour le pion d'un assaillant. Voir `_make_foe_mesh()`.
const FOE_TAPER := 0.45

## Décollement du sol, en fractions de tuile. Comme partout ailleurs, il n'existe que pour
## les angles rasants où deux surfaces qui se touchent scintillent.
const LIFT_RATIO := 0.01

## Teinte des ouvriers engagés.
##
## Elle est une **constante de décor** et non un champ de `data/`, à l'inverse de celle d'un
## assaillant, et l'asymétrie est justifiée : les assaillants ont des types à distinguer, le
## camp du village n'en a pas. C'est le même raisonnement que pour `CellHighlight`, dont la
## couleur est aussi en dur — on ne met en data que ce que le contenu fait varier.
const FRIEND_COLOR := Color(0.42, 0.62, 0.86)

## Teinte de repli d'un corps dont personne n'a donné la couleur.
##
## Un magenta franc, choisi pour être **laid et impossible à manquer** : un pion de cette
## couleur dit qu'une table de teintes est incomplète, ce qui est un défaut d'appelant. Le
## replier sur une couleur plausible le rendrait invisible.
const UNKNOWN_COLOR := Color(1.0, 0.0, 0.8)

var _metrics: TerrainMetrics
var _friends: MultiMeshInstance3D
var _foes: MultiMeshInstance3D

## Renderer prêt à être ajouté à l'arbre, sans un pion tant qu'on ne l'a pas reconstruit.
static func create(metrics: TerrainMetrics) -> BodyRenderer:
	assert(metrics != null, "corps sans métrique")
	var renderer := BodyRenderer.new()
	renderer.name = "BodyRenderer"
	renderer._metrics = metrics
	renderer._friends = _make_pass("Friends", _make_friend_mesh(metrics))
	renderer._foes = _make_pass("Foes", _make_foe_mesh(metrics))
	renderer.add_child(renderer._friends)
	renderer.add_child(renderer._foes)
	return renderer

## Replante tous les pions debout de ce plateau.
##
## Les **tombés n'y sont pas**, et c'est une décision d'affichage plutôt qu'une omission :
## un mort ne barre plus rien et ne peut plus être visé, donc un pion qui resterait sur sa
## case promettrait un obstacle qui n'existe pas. Ce qu'il advient de lui se lit sur le
## panneau, qui le garde en liste — c'est le partage habituel entre la carte, qui montre
## l'état, et le panneau, qui raconte.
##
## `tints` associe un identifiant de corps à sa couleur. Elle vient de l'appelant parce que
## lui seul sait quel `EnemyData` il a envoyé : le plateau ne porte que des chiffres, et lui
## faire porter une couleur mettrait de l'affichage dans le domaine.
func rebuild(board: CombatBoard, tints: Dictionary[StringName, Color]) -> void:
	assert(board != null, "corps sans plateau")
	_fill(_friends, board, board.standing(Combatant.Side.FRIEND), tints)
	_fill(_foes, board, board.standing(Combatant.Side.FOE), tints)

## Retire tous les pions. Aucune bataille en cours.
func clear() -> void:
	_friends.multimesh.visible_instance_count = 0
	_foes.multimesh.visible_instance_count = 0

## Remplit une passe avec ces corps.
func _fill(pass_node: MultiMeshInstance3D, board: CombatBoard, bodies: Array[Combatant],
		tints: Dictionary[StringName, Color]) -> void:
	var multimesh := pass_node.multimesh
	if multimesh.instance_count < bodies.size():
		multimesh.instance_count = bodies.size()
	multimesh.visible_instance_count = bodies.size()
	var tile := _metrics.tile_size()
	for index in bodies.size():
		var body := bodies[index]
		var cell := body.cell()
		var base := _metrics.cell_surface_center(cell, board.terrain().height_at(cell))
		base.y += HEIGHT_RATIO * tile * 0.5 + LIFT_RATIO * tile
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, base))
		multimesh.set_instance_color(index, tints.get(body.id(), UNKNOWN_COLOR))

static func _make_pass(label: String, mesh: Mesh) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.material_override = _make_material()
	var multimesh := MultiMesh.new()
	# Même ordre que TerrainRenderer et TargetHighlight : le format se fige au premier
	# instance_count non nul, et le régler après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	node.multimesh = multimesh
	return node

## Le pion d'un ouvrier : une capsule.
static func _make_friend_mesh(metrics: TerrainMetrics) -> CapsuleMesh:
	var tile := metrics.tile_size()
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS_RATIO * tile
	mesh.height = HEIGHT_RATIO * tile
	return mesh

## Le pion d'un assaillant : un tronc de cône.
##
## **Pas un cône pur, et c'est la capture qui l'a dit** : `TerrainDecorRenderer` dessine une
## forêt en cônes sombres, et un assaillant conique n'en différait plus que par sa teinte —
## exactement ce que le docstring de cette classe refuse deux paragraphes plus haut. Le
## sommet tronqué rend la silhouette distincte d'un arbre sans la confondre avec le dôme
## d'un rocher, qui est l'autre primitive que le décor emploie.
##
## Les deux formes libres étaient prises ; celle-ci se glisse entre les deux, et elle garde
## ses flancs courbes, donc son dégradé sous tous les angles.
static func _make_foe_mesh(metrics: TerrainMetrics) -> CylinderMesh:
	var tile := metrics.tile_size()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS_RATIO * tile * FOE_TAPER
	mesh.bottom_radius = RADIUS_RATIO * tile
	mesh.height = HEIGHT_RATIO * tile
	return mesh

## Le matériau des pions.
##
## **Éclairé**, à l'inverse des marques au sol : un pion est un objet posé sur le terrain et
## non un signal, donc il doit prendre la lumière comme une colonne ou un bâtiment. C'est
## ce qui lui donne son volume et ce qui fait qu'on le voit debout plutôt qu'à plat.
static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material
