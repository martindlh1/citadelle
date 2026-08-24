class_name TerrainDecor
extends Resource
## Ce qu'une cellule porte SUR sa colonne : un arbre, un rocher, un affleurement.
##
## La décoration se décrit ici et non dans le renderer, pour la raison qui a mis la
## couleur sur TerrainData à T2 : le renderer ne doit jamais commuter sur un
## identifiant de terrain. Ajouter un terrain décoré reste une édition de data/.
##
## Les dimensions sont en FRACTIONS DE TUILE, jamais en unités de monde. C'est la
## leçon de métrique de T2 : régler tile_size doit redimensionner la carte entière,
## décorations comprises, et non laisser les arbres à leur ancienne taille au milieu
## de cellules qui ont changé.
##
## Une décoration est purement visuelle. Elle n'est jamais pickée — le CellPicker ne
## voit que des colonnes — et ne porte aucune règle : c'est le tag du TerrainData qui
## dit ce qu'une forêt vaut à l'adjacence.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Primitive dessinée, en attendant de vrais assets. UNSET vaut 0 pour rester
## détectable, comme TerrainData.Build.
##
## Le vocabulaire est volontairement court : deux formes suffisent aux trois terrains
## décorés du tableau de DESIGN.md 3.1, la proportion et la couleur faisant le reste.
## En ajouter une est une édition de GDScript, et c'est assumé — le jour où de vraies
## meshes arrivent, c'est ce champ qui devient une référence de Mesh et le vocabulaire
## disparaît.
##
## Une forme y a été essayée puis retirée : le prisme. Il porte une grande face
## verticale plate, et dès qu'elle regarde la caméra en tournant le dos au soleil, elle
## se lit comme un trou noir. Sous une caméra qui pivote par quarts de tour au-dessus
## d'un soleil fixe, aucune orientation n'y échappe. Les deux formes restantes n'ont
## pas de face plate : elles gardent un dégradé quel que soit l'angle.
enum Shape {
	UNSET = 0,
	CONE = 1,
	BOULDER = 2,
}

## Couleur qu'on lit comme « non renseignée ».
##
## Recopiée de TerrainData plutôt qu'importée : TerrainData référence déjà TerrainDecor
## par son @export, et lui répondre par une constante fermerait le cycle. Un cas de
## tests/schema/ épingle l'égalité des deux, pour que la copie ne dérive pas.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Primitive posée sur la cellule.
@export var shape: Shape

## Couleur de la primitive. Elle vaut pour toute la passe : une décoration ne varie
## pas de teinte d'une cellule à l'autre.
@export var color: Color

## Largeur au sol, en fractions de tuile. 1.0 remplit la cellule d'un bord à l'autre.
@export_range(0.0, 2.0, 0.05) var width: float

## Élévation au-dessus de la face supérieure, en fractions de tuile.
@export_range(0.0, 4.0, 0.05) var height: float

## Irrégularité de la dispersion, de 0 à 1 : dérive du centre de la cellule et
## dispersion d'échelle. À 0 les décorations sont toutes identiques et parfaitement
## alignées, ce qui se lit comme un damier plutôt que comme une forêt.
##
## 0 est une valeur légitime, donc absente de missing_fields() — voir la note de
## terrain_gen_balance.gd sur les limites du filet.
@export_range(0.0, 1.0, 0.05) var variation: float

## Champs non renseignés. Vide = décoration exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if shape == Shape.UNSET:
		missing.append("shape")
	if color == UNSET_COLOR:
		missing.append("color")
	if width <= 0.0:
		missing.append("width")
	if height <= 0.0:
		missing.append("height")
	return missing
