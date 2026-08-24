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

## Tags lus par les règles d'adjacence : forest, stone, water, blocker.
## Un terrain sans tag est légitime — la plaine n'en porte aucun.
@export var tags: Array[StringName]

## Couleur du bloc au rendu, en attendant de vrais assets.
##
## Elle vit ici et non dans le renderer pour que celui-ci n'ait jamais à commuter sur
## un identifiant de terrain : ajouter un terrain doit rester une édition de data, pas
## de GDScript. Le jour où un vrai matériau arrive, il se pose au même endroit.
@export var color: Color

## Peut-on bâtir sur ce terrain ? Un terrain non renseigné ne l'est pas.
func is_buildable() -> bool:
	return build == Build.ALLOWED

## Ce terrain porte-t-il ce tag ?
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

## Champs non renseignés. Vide = terrain exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if build == Build.UNSET:
		missing.append("build")
	if color == UNSET_COLOR:
		missing.append("color")
	return missing
