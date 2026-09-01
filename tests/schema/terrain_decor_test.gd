class_name TerrainDecorTest
extends GdUnitTestSuite
## La décoration d'un terrain : son filet de complétude, et sa remontée dans celui du
## terrain qui la porte.
##
## Comme terrain_data_test.gd, aucune dimension ni couleur de data/ n'est figée ici —
## elles bougeront à la première passe visuelle. Ce qui est asserté, c'est le mécanisme
## qui détecte leur absence, et le fait que « pas de décoration » ne soit pas une faute.

const TERRAIN_ROOT := "res://data/terrain"

func test_a_blank_decor_reports_its_four_required_fields() -> void:
	var missing := TerrainDecor.new().missing_fields()
	assert_array(missing).contains(["shape", "color", "width", "height"])

## variation n'est pas dans la liste : 0 y est une valeur légitime — une décoration
## parfaitement régulière — et non un oubli. Le filet est court par nature.
func test_a_zero_variation_is_not_a_missing_field() -> void:
	assert_array(TerrainDecor.new().missing_fields()).not_contains(["variation"])

func test_a_filled_decor_reports_nothing() -> void:
	assert_array(_filled().missing_fields()).is_empty()

## La sentinelle est recopiée de TerrainData pour ne pas fermer un cycle de types.
## Ce cas est ce qui empêche la copie de dériver de l'original.
func test_both_unset_colour_sentinels_agree() -> void:
	assert_bool(TerrainDecor.UNSET_COLOR == TerrainData.UNSET_COLOR) \
		.override_failure_message("les deux sentinelles ont divergé : %s contre %s"
			% [TerrainDecor.UNSET_COLOR, TerrainData.UNSET_COLOR]) \
		.is_true()

## Une cellule sans rien à porter est un terrain valide, pas un terrain incomplet.
## C'est le cas de la plaine et de l'eau.
func test_a_terrain_without_decor_is_complete() -> void:
	assert_array(_terrain(null).missing_fields()).is_empty()

## Mais une décoration présente et à moitié remplie remonte, préfixée, jusqu'au
## contrôle de boot. C'est là tout l'intérêt de l'agrégation.
func test_a_half_filled_decor_surfaces_on_the_terrain() -> void:
	var decor := _filled()
	decor.shape = TerrainDecor.Shape.UNSET
	assert_array(_terrain(decor).missing_fields()).contains(["decor.shape"])

## Et une décoration complète ne salit pas le rapport du terrain.
func test_a_complete_decor_leaves_the_terrain_clean() -> void:
	assert_array(_terrain(_filled()).missing_fields()).is_empty()

## Le format lui-même : une décoration écrite en sous-ressource dans un .tres revient
## bien en TerrainDecor, et pas en Resource nue.
##
## Ce cas est le seul à toucher data/, et il le fait sans figer quoi que ce soit : il
## ne dit pas QUELS terrains sont décorés, seulement qu'au moins un l'est et que sa
## décoration est exploitable. Sans lui, un sous-bloc mal formé rendrait decor null en
## silence — missing_fields() ne signale pas une décoration absente, et le boot
## passerait vert sur une carte devenue chauve.
func test_a_decor_written_in_a_tres_comes_back_typed() -> void:
	var decorated: Array[String] = []
	for file in DirAccess.get_files_at(TERRAIN_ROOT):
		if file.get_extension() != "tres":
			continue
		var terrain := load("%s/%s" % [TERRAIN_ROOT, file]) as TerrainData
		if terrain.decor == null:
			continue
		decorated.append(file.get_basename())
		assert_array(terrain.decor.missing_fields()) \
			.override_failure_message("décoration inexploitable dans %s" % file) \
			.is_empty()
	assert_array(decorated) \
		.override_failure_message("aucun terrain de data/ ne porte de décoration typée") \
		.is_not_empty()

func _filled() -> TerrainDecor:
	var decor := TerrainDecor.new()
	decor.shape = TerrainDecor.Shape.CONE
	decor.color = Color(0.2, 0.4, 0.2)
	decor.width = 0.5
	decor.height = 0.7
	return decor

func _terrain(decor: TerrainDecor) -> TerrainData:
	var terrain := TerrainData.new()
	terrain.id = &"forest"
	terrain.build = TerrainData.Build.ALLOWED
	terrain.walk = TerrainData.Walk.ALLOWED
	terrain.color = Color(0.2, 0.4, 0.2)
	terrain.decor = decor
	return terrain
