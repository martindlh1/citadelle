class_name EconomyBalance
extends Resource
## Réglages de l'économie : la réserve, l'upkeep, le stock d'ouverture.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Capacité de la réserve avant tout entrepôt, **toutes ressources confondues**.
##
## C'est une réserve commune et non un plafond par ressource : cent unités partagées
## entre le bois, la pierre et la nourriture, de sorte que remplir sa réserve de bois
## revient à renoncer à stocker de la pierre. Tranché à E1, voir DESIGN.md 3.3.
@export_range(0, 1000, 1) var base_storage_cap: int

## Nourriture due par ouvrier et par soir, **oisifs compris**. C'est ce qui rend un
## ouvrier non affecté coûteux, donc le pool tendu.
@export_range(0, 10, 1) var upkeep_per_worker: int

## Ressource que l'upkeep consomme.
##
## Elle est ici et non en constante dans le résolveur, parce qu'un &"food" écrit en dur
## dans src/domain/ serait précisément le nombre magique que les conventions
## interdisent, et parce qu'il survivrait à un renommage dans data/commodities/ sans
## que rien ne le signale. Le jour où l'upkeep se paie en autre chose, c'est une
## édition de data.
@export var upkeep_resource: StringName

## Ce que la réserve contient à l'ouverture d'un run.
##
## Les clés sont des identifiants de data/commodities/. Ce fichier ne peut pas les
## contrôler seul — une Resource de schéma ne lit jamais l'index —, c'est GameDatabase
## qui s'en charge au démarrage.
@export var starting_stock: Dictionary[StringName, int]

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## Le stock d'ouverture est confronté à la capacité : en réserve commune, un stock de
## départ qui la dépasse serait écrêté dès le premier soir, et le chiffre écrit dans le
## .tres mentirait sur ce que le run reçoit vraiment.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if base_storage_cap <= 0:
		missing.append("base_storage_cap")
	if upkeep_per_worker <= 0:
		missing.append("upkeep_per_worker")
	if upkeep_resource.is_empty():
		missing.append("upkeep_resource")
	for resource in starting_stock:
		if starting_stock[resource] < 0:
			missing.append("starting_stock.%s" % resource)
	if base_storage_cap > 0 and _starting_total() > base_storage_cap:
		missing.append("starting_stock.over_capacity")
	return missing

## Total du stock d'ouverture, toutes ressources confondues.
func _starting_total() -> int:
	var total := 0
	for resource in starting_stock:
		total += starting_stock[resource]
	return total
