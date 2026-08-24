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
## indiscernables, et Godot n'écrit jamais false dans un .tres.

## Constructibilité du terrain. UNSET vaut 0 pour rester détectable.
enum Build {
	UNSET = 0,
	ALLOWED = 1,
	BLOCKED = 2,
}

## Identifiant stable, repris par les règles d'adjacence et les sorties de debug.
## Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Peut-on poser un bâtiment sur cette cellule ?
@export var build: Build

## Tags lus par les règles d'adjacence : forest, stone, water, blocker.
## Un terrain sans tag est légitime — la plaine n'en porte aucun.
@export var tags: Array[StringName]

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
	return missing
