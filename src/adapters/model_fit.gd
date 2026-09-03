class_name ModelFit
extends RefCounted
## Comment poser un modèle importé sur notre grille : à quelle échelle, et à quelle hauteur.
##
## Deux fonctions, et c'est tout ce que les renderers partagent quand ils cessent de dessiner
## des primitives. Le reste — combien de passes, quelle teinte, quelle dispersion — leur est
## propre et le reste.
##
## ---
##
## **Un modèle se met à l'échelle par sa boîte englobante, jamais par un facteur écrit à la
## main.** Les assets d'un pack arrivent à la taille de *leur* monde : ceux du pack médiéval
## tiennent dans un hexagone de deux unités, un autre pack les livrerait au mètre ou au
## centimètre. Un facteur codé en data serait à retrouver à chaque asset, et à refaire le jour
## où l'on change de pack.
##
## Ce que la data déclare est donc une **envergure en cases** — « ce bâtiment couvre deux cases
## de large » —, un chiffre qui parle du jeu et non du fichier. C'est la même leçon de métrique
## que `T2` a tirée pour les décorations : ce qui est en fractions de tuile suit `tile_size`, ce
## qui est en unités de monde ne le suit pas.
##
## **Les proportions sont conservées.** Une échelle par axe permettrait d'écraser un modèle pour
## le faire entrer, et c'est précisément ce qu'on ne veut pas d'un asset : une maison aplatie se
## voit tout de suite, et le réglage qui l'a produite ne se retrouve jamais.

## L'échelle uniforme qui donne à ce modèle `span` cases de large.
##
## L'envergure se mesure sur la plus grande des deux dimensions **horizontales** et non sur la
## diagonale ni sur la hauteur : ce qu'on veut contrôler est l'emprise au sol, parce que c'est
## elle qui doit s'accorder aux cases. Un clocher reste haut.
##
## Une boîte englobante plate dans les deux axes horizontaux — un modèle vide, ou une mesh que
## l'import n'a pas produite — rend 1.0 plutôt que de diviser par zéro. Un modèle à sa taille
## native est visible, donc réparable ; un modèle infini ne l'est pas.
static func span_scale(mesh: Mesh, span: float, tile: float) -> float:
	assert(mesh != null, "mise à l'échelle d'un modèle null")
	assert(span > 0.0, "envergure non positive : %f" % span)
	var box := mesh.get_aabb().size
	var widest := maxf(box.x, box.z)
	if widest <= 0.0:
		return 1.0
	return span * tile / widest

## De combien remonter un modèle mis à cette échelle pour que sa **base** repose sur le sol.
##
## Les assets sont modélisés debout sur l'origine, donc le bas de leur boîte est à zéro ou tout
## près — mais « tout près » n'est pas zéro, et un modèle qui s'enfonce d'un centimètre dans le
## relief se lit comme un défaut de terrain. On lit donc le bas de la boîte plutôt que de le
## supposer.
##
## C'est l'inverse exact de la correction des primitives, qui sont centrées sur leur origine et
## qu'il faut monter d'une demi-hauteur. Les deux disent la même chose : ce qui touche le sol
## est le bas de la forme, pas son milieu.
static func ground_lift(mesh: Mesh, scale: float) -> float:
	assert(mesh != null, "pose d'un modèle null")
	return -mesh.get_aabb().position.y * scale

## La transformée qui pose ce modèle sur ce point de sol, dans cette orientation.
##
## **Elle est ici parce que deux vues la partagent** : le renderer, qui dessine les bâtiments
## posés, et le fantôme, qui montre celui qu'on s'apprête à poser. Deux calculs auraient
## divergé, et le désaccord aurait été le pire qui soit sur une vue de placement — l'aperçu
## aurait menti sur l'endroit où le bâtiment atterrit, et on ne s'en apercevrait qu'après avoir
## cliqué. C'est le même argument que celui qui a fait sortir le voisinage dans `Adjacency` à
## `C3` et l'emprise dans `Territory` à `C7`.
##
## `turns` est le **total** des quarts de tour : l'orientation du bâtiment plus le recalage du
## modèle. Les additionner est l'affaire de l'appelant, qui seul sait lequel est un état de jeu
## et lequel corrige une convention de pack.
##
## `rise` n'écrase que la hauteur, et sert au chantier qui sort de terre. À 1.0 elle ne fait
## rien, ce qui est le cas de tout ce qui est fini — et du fantôme.
static func stand(mesh: Mesh, span: float, turns: int, tile: float, ground: Vector3,
		rise := 1.0) -> Transform3D:
	var scale := span_scale(mesh, span, tile)
	var seat := ground
	seat.y += ground_lift(mesh, scale) * rise
	# La grille va +x vers la droite et +y vers le fond, ce que le monde reprend en +X et +Z :
	# un quart de tour horaire vu de dessus est donc une rotation NÉGATIVE autour de Y. C'est
	# la même convention que `BuildingData.rotate_offset()`, et il faut que ce soit la même —
	# une silhouette qui tournerait dans l'autre sens que ses cases se décalerait sur trois
	# orientations sur quatre.
	var spin := Basis.from_euler(Vector3(0.0,
		-TAU * float(turns) / BuildingData.QUARTER_TURNS, 0.0))
	return Transform3D(spin.scaled(Vector3(scale, scale * rise, scale)), seat)

## Le matériau d'un modèle, prêt à recevoir une teinte par instance.
##
## Une **copie** du matériau que l'import a produit, avec la couleur de sommet activée : la
## copie garde l'atlas et tous les réglages du pack, l'activation fait que
## `set_instance_color()` multiplie l'albedo au lieu d'être ignoré. Sans elle, un chantier et un
## bâtiment endormi seraient indiscernables d'un bâtiment neuf — les deux signaux que `C4` et
## `N2` ont mis sur la couleur disparaîtraient en même temps que les boîtes.
##
## Muter le matériau original serait pire qu'un doublon : une `Resource` importée est partagée
## par tout ce qui la charge, et l'éditeur la réécrirait au prochain scan.
##
## Un modèle sans matériau — une primitive de Godot — en reçoit un neuf, ce qui est le cas de la
## boîte de repli.
static func tintable_material(mesh: Mesh) -> StandardMaterial3D:
	assert(mesh != null, "matériau d'un modèle null")
	var source: StandardMaterial3D = null
	if mesh.get_surface_count() > 0:
		source = mesh.surface_get_material(0) as StandardMaterial3D
	var material := source.duplicate() as StandardMaterial3D if source != null \
		else StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Les couleurs des .tres sont choisies dans un sélecteur, donc en sRGB, alors que le rendu
	# travaille en linéaire. Sans cette conversion elles ressortent délavées.
	material.vertex_color_is_srgb = true
	return material

## Le matériau d'un modèle **fantôme** : translucide, et teinté par la réponse du domaine.
##
## Une copie du matériau du pack, comme celle du dessus, mais poussée vers la transparence : on
## doit lire le terrain à travers, sans quoi le fantôme cache exactement ce sur quoi on cherche
## à se décider — c'est la règle que `PlacementGhost` tient depuis `C2` sur ses boîtes.
##
## La teinte passe par `albedo_color`, qui **multiplie** la texture : un vert franc éteindrait
## tout ce que l'atlas porte de rouge, donc on l'éclaircit vers le blanc avant de l'appliquer.
## Le modèle garde alors ses formes lisibles sous un voile coloré, au lieu de devenir une
## silhouette monochrome.
static func ghost_material(mesh: Mesh, tint: Color) -> StandardMaterial3D:
	var material := tintable_material(mesh)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	# Un fantôme qui recevrait l'ombre du soleil se lirait comme un bâtiment déjà là.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
