class_name CommodityData
extends Resource
## Une ressource stockable : bois, pierre, nourriture.
##
## Nommée « Commodity » et non « Resource » pour deux raisons qui se cumulent :
## Resource est déjà le type de base de Godot dont ce fichier hérite, et
## GameDatabase.get_resource() est déjà l'accesseur générique de l'index — un
## get_resource(&"resources", &"wood") serait illisible. Le vocabulaire du jeu ne bouge
## pas pour autant : DESIGN.md dit « ressource », les identifiants restent &"wood",
## &"stone" et &"food", et seul le nom de la classe de schéma diffère.
##
## Le catalogue existe pour que l'ensemble des ressources vive dans data/ plutôt que
## dans une énumération du code : DESIGN.md 3.3 garde leur nombre ouvert, et en ajouter
## une doit rester une édition de data. Il rend aussi refusable au démarrage un coût
## qui nommerait une ressource inexistante — sans lui, un &"wodo" dans un .tres
## créerait une ressource fantôme en silence, qui se stockerait et ne s'achèterait
## jamais.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Couleur qu'on lit comme « non renseignée ».
## Recopiée de TerrainData, comme BuildingData la recopie déjà.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Identifiant stable, repris par les coûts, les rendements et le ledger.
## Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Libellé affichable. Le HUD de E2 le lit ; rien dans le domaine ne le regarde.
@export var label: String

## Couleur au HUD, en attendant de vraies icônes. Même rôle que sur un terrain.
@export var color: Color

## Rang d'affichage, de gauche à droite. Le HUD le lit ; le domaine l'ignore.
##
## Il existe parce que l'ordre des ressources à l'écran est une décision, et qu'elle
## n'avait aucun endroit où vivre. GameDatabase.list_commodity_ids() trie par
## identifiant, donc en anglais interne — la nourriture, qui est celle qui tue,
## atterrissait entre le minerai et la pierre. La seule alternative était une liste
## d'identifiants écrite dans un .gd, c'est-à-dire exactement ce que DESIGN.md 3.3
## refuse en sortant l'ensemble des ressources de l'énumération du code.
##
## Il commence à 1 et non à 0, pour la raison qui vaut sur tout data/balance/ : un
## champ non renseigné vaut 0, et un rang 0 légitime le rendrait indétectable.
##
## Deux ressources ne doivent pas le partager — ce fichier ne peut pas le vérifier
## seul, une Resource de schéma ne lisant jamais l'index, et c'est un cas de test qui
## le tient. Des rangs égaux rendraient l'ordre de la barre arbitraire, donc différent
## d'une session à l'autre : le même piège que le tri de deux StringName.
@export_range(1, 99, 1) var order: int

## Champs non renseignés. Vide = ressource exploitable.
## Vérifié au boot par GameDatabase, comme les terrains et les bâtiments.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if color == UNSET_COLOR:
		missing.append("color")
	if order <= 0:
		missing.append("order")
	return missing
