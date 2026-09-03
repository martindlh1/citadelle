class_name BuildingRenderer
extends Node3D
## Les bâtiments posés : une passe MultiMesh par modèle, plus celle des boîtes.
##
## Le renderer ne connaît aucun bâtiment par son nom. Il lit le modèle, l'envergure, la couleur
## et la hauteur sur le `BuildingData`, comme celui du terrain les lit sur le `TerrainData` :
## ajouter un bâtiment reste une édition de data, et lui donner une allure aussi.
##
## Passe soeur de TerrainRenderer et non une variante : le relief et les bâtiments se peuplent
## depuis deux états différents et se reconstruisent à des moments différents.
##
## ---
##
## **Une passe par modèle**, créée à la première apparition et jamais retirée. Un village fait
## quelques dizaines de bâtiments pour une poignée de types, donc une poignée de draw calls —
## et une passe vidée ne coûte rien, là où détruire un nœud au milieu d'une reconstruction
## ferait clignoter ce qui vient d'être posé.
##
## Ce fichier était un unique `MultiMeshInstance3D` jusqu'à l'arrivée des assets, et il ne
## pouvait pas le rester : un `MultiMesh` porte **une** mesh, or chaque type de bâtiment a
## désormais la sienne. C'est le même partage que la décoration du terrain, qui a une passe par
## terrain décoré depuis `T3`.
##
## **Deux chemins, et le second n'est pas un repli honteux.** Un bâtiment sans modèle retrouve
## la boîte par cellule de `C1` — qui reste le seul rendu honnête d'une empreinte en L, où un
## volume unique couvrirait le trou de l'enveloppe et mentirait sur la forme. C'est aussi ce
## qui permet d'ajouter un bâtiment et de le voir avant de lui avoir trouvé un asset.
##
## Depuis C4 il dessine aussi les chantiers, et il les dessine **autrement**. Ce que data/
## décide reste ce qu'un bâtiment FINI vaut ; l'écart qu'un chantier montre est une décision
## d'affichage, donc des constantes d'adapter, exactement comme PlacementGhost tient ses deux
## teintes ici plutôt que dans data/.

## Part de sa hauteur finale qu'un chantier atteint au tout premier cran, avant même
## qu'une action ait été jouée.
##
## Non nulle, et c'est le seul chiffre des trois qui compte vraiment : à zéro, un
## chantier fraîchement posé serait invisible, et on ne verrait pas qu'on vient de payer une
## case. Il faut qu'il se voie POUR se lire comme inachevé.
const SITE_BASE_RATIO := 0.2

## Teinte vers laquelle la couleur d'un chantier est tirée — un gris de fondation.
##
## Sa part décroît à mesure que le chantier monte, pilotée par le même nombre que la
## hauteur : un bâtiment reprend sa couleur en même temps qu'il prend sa taille. Voir
## _raised().
const SITE_COLOR := Color(0.62, 0.60, 0.55, 1.0)

## Teinte vers laquelle la couleur d'un bâtiment **endormi** est tirée, et la part qu'elle
## prend.
##
## Froide, là où celle d'un chantier est chaude : les deux états se ressemblent — ni l'un ni
## l'autre ne produit — et se distinguent pourtant, parce que ce qu'ils demandent au joueur
## n'est pas la même chose. Un chantier veut qu'on attende ; un endormi veut un toit.
##
## **C'est la seule réponse honnête à « lesquels dorment ? »** de `DESIGN.md` 3.3. La phrase
## qu'un joueur doit pouvoir se dire est « cette ferme dort, il me manque un toit », et
## « cette » désigne une case : la lire ailleurs sous forme de coordonnées demanderait de
## chercher sur la carte ce que la carte peut montrer elle-même. Un texte dit combien et de
## quelle nature, le plateau seul dit **lesquels**.
const SLEEP_COLOR := Color(0.34, 0.38, 0.50, 1.0)
const SLEEP_MIX := 0.62

## Teinte neutre d'une instance : le matériau du modèle passe alors intact.
##
## Un asset porte ses propres couleurs par son atlas ; ce que la teinte par instance fait est
## de les **multiplier**. Blanc ne change donc rien, et c'est l'état normal d'un bâtiment fini
## et actif — les deux autres états tirent vers le gris ou vers le froid depuis là.
const PLAIN_TINT := Color.WHITE

var _metrics: TerrainMetrics

## La boîte des bâtiments sans modèle. Une seule pour tout le village : le repli n'a pas de
## raison d'avoir une passe par bâtiment, puisque c'est la même forme pour tous.
var _box: BoxMesh

## Mesh -> la passe qui la dessine. Les clés sont les `Mesh` eux-mêmes, donc deux bâtiments qui
## partagent un asset partagent leur passe sans que rien n'ait à le remarquer.
var _passes: Dictionary[Mesh, MultiMeshInstance3D] = {}

## Renderer prêt à être ajouté à l'arbre, déjà peuplé pour cette ville.
static func create(city: CityState, metrics: TerrainMetrics) -> BuildingRenderer:
	assert(city != null, "rendu d'une ville null")
	assert(metrics != null, "rendu sans métrique")
	var renderer := BuildingRenderer.new()
	renderer.name = "BuildingRenderer"
	renderer._metrics = metrics
	renderer._box = BoxMesh.new()
	renderer._box.size = Vector3.ONE
	renderer.rebuild(city)
	return renderer

## Repeuple le rendu depuis cette ville.
##
## Une passe sur les bâtiments posés, à chaque pose et à chaque destruction. Une ville
## en compte quelques dizaines, là où le terrain en compte mille cellules : ce qui
## méritait une réserve chez TerrainRenderer n'en demande pas ici.
## Les ancres de `hidden` ne sont **pas** dessinées.
##
## Ajouté à `F3a`, et générique exprès : le Combat en est le premier consommateur — un
## bâtiment tombé pendant une bataille doit disparaître alors que la ville l'ignore encore,
## puisque le plateau ne mute rien et que le rapport ne s'applique qu'à la fin. Le renderer
## n'apprend pas pour autant ce qu'est une bataille : on lui donne des ancres à sauter.
##
## Le défaut est une liste vide, donc les cinq appelants d'avant `F3a` n'ont pas bougé.
##
## `asleep` suit le même patron depuis `N2` : on lui donne des ancres, il les **éteint**. Il
## n'apprend pas pour autant ce qu'est le sommeil — que ce soit `StaffingPlan.asleep()` qui
## les fournisse ne le regarde pas, exactement comme `hidden` ignore qu'une bataille existe.
func rebuild(city: CityState, hidden: Array[Vector2i] = [],
		asleep: Array[Vector2i] = []) -> void:
	assert(city != null, "rendu d'une ville null")
	assert(_metrics != null, "renderer non initialisé — passer par create()")

	# Un tampon par mesh, rempli en une passe sur la ville : on ne connaît le nombre
	# d'instances d'une mesh qu'une fois tous les bâtiments parcourus.
	var drawn: Dictionary[Mesh, Array] = {}
	var tile := _metrics.tile_size()
	for building in city.buildings():
		if hidden.has(building.anchor()):
			continue
		var data := building.data()
		var raised := _raised(building)
		var tint := SITE_COLOR.lerp(
			data.color if data.model == null else PLAIN_TINT, raised)
		# Le sommeil s'applique APRÈS le gris de chantier et non à sa place : un chantier
		# endormi est les deux à la fois — il n'est pas fini et il n'avance pas —, et ne
		# montrer que l'un des deux ferait disparaître l'autre.
		if asleep.has(building.anchor()):
			tint = tint.lerp(SLEEP_COLOR, SLEEP_MIX)
		if data.model == null:
			_add_boxes(drawn, building, tile, raised, tint)
		else:
			_add_model(drawn, building, tile, raised, tint)

	for mesh in drawn:
		_fill(_pass_for(mesh), drawn[mesh])
	# Les passes qu'aucun bâtiment n'a demandées ce tour-ci se vident au lieu de disparaître :
	# une ville dont on démolit le dernier entrepôt ne doit pas en garder l'image.
	for mesh in _passes:
		if not drawn.has(mesh):
			_fill(_passes[mesh], [])

## Le modèle d'un bâtiment, posé une fois au centre de son empreinte.
##
## `raised` n'écrase que la **hauteur** : un chantier sort de terre au lieu de rétrécir sur
## place, ce qui est la lecture que `C4` a choisie et qui vaut autant pour un asset que pour
## une boîte.
func _add_model(drawn: Dictionary[Mesh, Array], building: PlacedBuilding, tile: float,
		raised: float, tint: Color) -> void:
	var data := building.data()
	var ground := _metrics.spot_surface(data.centre_at(building.anchor(), building.turns()),
		building.height())
	# L'orientation du bâtiment ET le recalage du modèle : le premier est un état de jeu, le
	# second corrige une convention de pack. Les additionner ici est ce qui évite de faire
	# tourner l'empreinte pour l'apparence.
	_queue(drawn, data.model, ModelFit.stand(data.model, data.model_span,
		building.turns() + data.model_turns, tile, ground, raised), tint)

## Le rendu de `C1` : une boîte par cellule occupée, à la hauteur du bâtiment.
##
## Ce chemin sert les bâtiments qu'aucun asset ne dessine encore, et ceux qu'il ne dessinerait
## pas bien — un ouvrage linéaire suit ses cases.
func _add_boxes(drawn: Dictionary[Mesh, Array], building: PlacedBuilding, tile: float,
		raised: float, tint: Color) -> void:
	# La hauteur est en fractions de tuile : c'est tile_size qui la met à l'échelle du monde,
	# pour qu'un réglage de la taille des cellules emporte les bâtiments.
	var thickness := building.data().height * tile * raised
	for cell in building.cells():
		var base := _metrics.cell_surface_center(cell, building.height())
		# La BoxMesh est centrée sur son origine : on monte d'une demi-hauteur pour que ce
		# soit sa FACE DU DESSOUS qui repose sur la surface de la cellule.
		base.y += thickness * 0.5
		_queue(drawn, _box,
			Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), base), tint)

## Range une instance dans le tampon de sa mesh.
func _queue(drawn: Dictionary[Mesh, Array], mesh: Mesh, body: Transform3D,
		tint: Color) -> void:
	if not drawn.has(mesh):
		drawn[mesh] = []
	drawn[mesh].append([body, tint])

## La passe de cette mesh, créée à sa première apparition.
##
## Le matériau est une **copie teintable** de celui du modèle : elle garde l'atlas du pack et
## laisse `set_instance_color()` multiplier l'albedo, sans quoi le gris d'un chantier et le
## froid d'un endormi seraient sans effet sur un asset. Voir `ModelFit.tintable_material()`.
func _pass_for(mesh: Mesh) -> MultiMeshInstance3D:
	if _passes.has(mesh):
		return _passes[mesh]
	var multimesh := MultiMesh.new()
	# L'ordre compte : Godot fige le format du tampon d'instances au premier instance_count
	# non nul. Régler transform_format ou use_colors après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	var pass_node := MultiMeshInstance3D.new()
	pass_node.name = "Pass%d" % _passes.size()
	pass_node.multimesh = multimesh
	pass_node.material_override = ModelFit.tintable_material(mesh)
	add_child(pass_node)
	_passes[mesh] = pass_node
	return pass_node

## Verse ces instances dans cette passe.
func _fill(pass_node: MultiMeshInstance3D, instances: Array) -> void:
	pass_node.multimesh.instance_count = instances.size()
	pass_node.visible = not instances.is_empty()
	for index in instances.size():
		var entry: Array = instances[index]
		pass_node.multimesh.set_instance_transform(index, entry[0])
		pass_node.multimesh.set_instance_color(index, entry[1])

## Part de sa hauteur et de sa couleur finales que ce bâtiment montre : 1.0 une fois
## achevé, et entre SITE_BASE_RATIO et 1.0 tant qu'il est en chantier.
##
## Les deux signaux — la taille et la couleur — sont pilotés par le MÊME nombre, et
## c'est délibéré : réglés séparément, ils finiraient par se contredire, une boîte
## presque haute encore grise. Ici un chantier reprend sa couleur en même temps qu'il
## prend sa taille.
##
## L'achèvement est testé avant tout calcul : sur un bâtiment sans coût de chantier —
## le Cœur —, le rapport diviserait par zéro.
func _raised(building: PlacedBuilding) -> float:
	if building.is_complete():
		return 1.0
	var done := float(building.progress()) / float(building.data().site_turns)
	return SITE_BASE_RATIO + (1.0 - SITE_BASE_RATIO) * done
