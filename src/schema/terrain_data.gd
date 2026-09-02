class_name TerrainData
extends Resource
## Un type de terrain : ce qu'une cellule porte en plus de sa hauteur.
##
## Les cinq types du tableau de DESIGN.md 3.1 vivent dans data/terrain/, un .tres
## chacun. Le domaine les reçoit en argument et ne lit jamais GameDatabase.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.
## C'est aussi pourquoi la constructibilité est un enum à trois états plutôt qu'un
## bool : sur un bool, « non renseigné » et « non constructible » seraient
## indiscernables, et Godot n'écrit jamais false dans un .tres. La couleur pose la
## même question et reçoit la même réponse, par sentinelle plutôt que par enum.

## Constructibilité du terrain. UNSET vaut 0 pour rester détectable.
enum Build {
	UNSET = 0,
	ALLOWED = 1,
	BLOCKED = 2,
}

## Franchissabilité du terrain. Même forme que Build, et pour la même raison : sur un
## bool, « non renseigné » et « infranchissable » seraient indiscernables.
##
## C'est la colonne **Franchissable** de DESIGN.md 3.1, qui existait dans le tableau du
## document sans exister nulle part dans la data. Elle entre à T4 avec son premier
## lecteur — la génération doit compter les accès à un plateau, donc marcher sur sa
## propre carte —, et V1 la lira ensuite pour le chemin d'une vague.
##
## **Elle coïncide aujourd'hui avec Build sur les cinq terrains**, et ce n'est pas une
## raison de la déduire. Les deux questions sont différentes — un marécage se traverse
## sans qu'on y bâtisse, une dalle se bâtit sans qu'on la traverse — et le jour où l'une
## d'elles arrive, une franchissabilité déduite se serait trompée en silence. Un champ
## qu'on remplit est aussi ce qui oblige à répondre à la question en ajoutant un terrain.
enum Walk {
	UNSET = 0,
	ALLOWED = 1,
	BLOCKED = 2,
}

## Couleur qu'on lit comme « non renseignée ».
##
## Le noir opaque est la valeur par défaut d'un Color en GDScript, donc exactement
## celle que Godot omet du .tres : un champ oublié et un noir délibéré y sont
## indiscernables. On tranche pour « oublié ». Un terrain qui voudrait vraiment du
## noir écrit Color(0.02, 0.02, 0.02) et personne ne verra la différence.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Identifiant stable, repris par les règles d'adjacence et les sorties de debug.
## Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Peut-on poser un bâtiment sur cette cellule ?
@export var build: Build

## Peut-on marcher sur cette cellule ? Colonne **Franchissable** de DESIGN.md 3.1.
##
## Ce que le relief ajoute par-dessus — une marche trop haute barre aussi — n'est pas ici :
## c'est une propriété du **marcheur**, pas de la case, et elle se pose là où l'on marche.
@export var walk: Walk

## Tags lus par les règles d'adjacence : forest, stone, water, blocker.
## Un terrain sans tag est légitime — la plaine n'en porte aucun.
@export var tags: Array[StringName]

## Couleur du bloc au rendu, en attendant de vrais assets.
##
## Elle vit ici et non dans le renderer pour que celui-ci n'ait jamais à commuter sur
## un identifiant de terrain : ajouter un terrain doit rester une édition de data, pas
## de GDScript. Le jour où un vrai matériau arrive, il se pose au même endroit.
@export var color: Color

## Ce que la cellule porte sur sa colonne, ou null si elle ne porte rien.
##
## Nullable à dessein, et c'est la seule exception au principe de sentinelle de ce
## fichier : la plaine et l'eau n'ont rien à porter, et « rien » y est évident plutôt
## que suspect. Une décoration à moitié remplie, elle, reste rattrapée — voir
## missing_fields().
@export var decor: TerrainDecor

## Peut-on bâtir sur ce terrain ? Un terrain non renseigné ne l'est pas.
func is_buildable() -> bool:
	return build == Build.ALLOWED

## Peut-on marcher sur ce terrain ? Un terrain non renseigné ne l'est pas.
##
## Le défaut prudent est le même que pour is_buildable(), et il l'est pour la raison
## inverse : un terrain oublié qui serait franchissable ouvrirait un accès que personne
## n'a voulu, et T4 compte les accès pour décider si une carte est jouable.
func is_walkable() -> bool:
	return walk == Walk.ALLOWED

## Ce terrain porte-t-il ce tag ?
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

## Champs non renseignés. Vide = terrain exploitable.
##
## L'absence de décoration ne se signale pas ; une décoration présente mais incomplète,
## si — préfixée « decor. », comme BalanceData préfixe ses blocs. C'est ce qui garde le
## filet du boot tendu sans transformer la plaine en terrain fautif.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if build == Build.UNSET:
		missing.append("build")
	if walk == Walk.UNSET:
		missing.append("walk")
	if color == UNSET_COLOR:
		missing.append("color")
	if decor != null:
		for field in decor.missing_fields():
			missing.append("decor.%s" % field)
	return missing
