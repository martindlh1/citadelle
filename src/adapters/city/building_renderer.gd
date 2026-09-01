class_name BuildingRenderer
extends MultiMeshInstance3D
## Les bâtiments posés : une boîte par cellule occupée, un seul draw call.
##
## Une boîte par CELLULE, et non une par bâtiment. Sur une empreinte en L, un volume
## unique couvrirait le trou de l'enveloppe et mentirait sur la forme — or c'est
## précisément la forme que C1 a rendue libre. Le rendu suit l'empreinte, comme la
## validation, et pour la même raison : bounds_at() est une enveloppe, pas un bâtiment.
##
## Passe soeur de TerrainRenderer et non une variante : le relief et les bâtiments se
## peuplent depuis deux états différents et se reconstruisent à des moments différents.
##
## Le renderer ne connaît aucun bâtiment par son nom. Il lit couleur et hauteur sur le
## BuildingData, comme celui du terrain les lit sur le TerrainData : ajouter un
## bâtiment reste une édition de data.
##
## Depuis C4 il dessine aussi les chantiers, et il les dessine **autrement**. Ce que
## data/ décide reste ce qu'un bâtiment FINI vaut ; l'écart qu'un chantier montre est
## une décision d'affichage, donc des constantes d'adapter, exactement comme
## PlacementGhost tient ses deux teintes ici plutôt que dans data/.

## Part de sa hauteur finale qu'un chantier atteint au tout premier cran, avant même
## qu'une action ait été jouée.
##
## Non nulle, et c'est le seul chiffre des trois qui compte vraiment : à zéro, un
## chantier fraîchement posé serait une boîte d'épaisseur nulle, donc invisible, et on
## ne verrait pas qu'on vient de payer une case. Il faut qu'il se voie POUR se lire
## comme inachevé.
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
## « cette » désigne une case : la lire dans un HUD sous forme de coordonnées demanderait de
## chercher sur la carte ce que la carte peut montrer elle-même. Le panneau dit combien et de
## quelle nature, le plateau dit lesquels.
const SLEEP_COLOR := Color(0.34, 0.38, 0.50, 1.0)
const SLEEP_MIX := 0.62

var _metrics: TerrainMetrics

## Renderer prêt à être ajouté à l'arbre, déjà peuplé pour cette ville.
static func create(city: CityState, metrics: TerrainMetrics) -> BuildingRenderer:
	assert(city != null, "rendu d'une ville null")
	assert(metrics != null, "rendu sans métrique")
	var renderer := BuildingRenderer.new()
	renderer.name = "BuildingRenderer"
	renderer._metrics = metrics
	renderer.material_override = _make_material()
	renderer.multimesh = _make_multimesh()
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
	var placed: Array[PlacedBuilding] = []
	for building in city.buildings():
		if not hidden.has(building.anchor()):
			placed.append(building)
	multimesh.instance_count = _cell_count(placed)
	var tile := _metrics.tile_size()
	var index := 0
	for building in placed:
		var data := building.data()
		var raised := _raised(building)
		# La hauteur est en fractions de tuile : c'est tile_size qui la met à l'échelle
		# du monde, pour qu'un réglage de la taille des cellules emporte les bâtiments.
		# Un chantier n'en montre qu'une part, qui monte avec ses crans.
		var thickness := data.height * tile * raised
		var color := SITE_COLOR.lerp(data.color, raised)
		# Le sommeil s'applique APRÈS le gris de chantier et non à sa place : un chantier
		# endormi est les deux à la fois — il n'est pas fini et il n'avance pas —, et ne
		# montrer que l'un des deux ferait disparaître l'autre.
		if asleep.has(building.anchor()):
			color = color.lerp(SLEEP_COLOR, SLEEP_MIX)
		for cell in building.cells():
			var base := _metrics.cell_surface_center(cell, building.height())
			# La BoxMesh est centrée sur son origine : on monte d'une demi-hauteur pour
			# que ce soit sa FACE DU DESSOUS qui repose sur la surface de la cellule.
			base.y += thickness * 0.5
			multimesh.set_instance_transform(index,
				Transform3D(Basis.IDENTITY.scaled(Vector3(tile, thickness, tile)), base))
			multimesh.set_instance_color(index, color)
			index += 1

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

## Combien de boîtes cette ville demande : la somme des cellules de ses empreintes.
func _cell_count(placed: Array[PlacedBuilding]) -> int:
	var count := 0
	for building in placed:
		count += building.data().footprint.size()
	return count

static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	# L'ordre compte : Godot fige le format du tampon d'instances au premier
	# instance_count non nul. Régler transform_format ou use_colors après ne prend pas.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	return multimesh

static func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Les couleurs des .tres sont choisies dans un sélecteur, donc en sRGB, alors que
	# le rendu travaille en linéaire. Sans cette conversion elles ressortent délavées.
	material.vertex_color_is_srgb = true
	return material
