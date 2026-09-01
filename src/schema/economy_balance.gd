class_name EconomyBalance
extends Resource
## Réglages de l'économie : la réserve, la population, l'upkeep, le stock d'ouverture.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Capacité de la réserve avant tout entrepôt, **toutes ressources confondues**.
##
## C'est une réserve commune et non un plafond par ressource : cent unités partagées
## entre le bois, la pierre et la nourriture, de sorte que remplir sa réserve de bois
## revient à renoncer à stocker de la pierre. Tranché à E1, voir DESIGN.md 3.3.
@export_range(0, 1000, 1) var base_storage_cap: int

## Places de logement avant toute habitation.
##
## Le pendant exact de base_storage_cap pour la population, et le parallèle va plus loin
## qu'un nom : les deux plafonds sont relevés par un bâtiment, les deux écrêtent ce qu'ils
## contiennent quand ils baissent. Un entrepôt détruit fait perdre des ressources, une
## habitation détruite fait perdre des habitants — même geste, deux compteurs.
##
## C'est le **frein spatial** de DESIGN.md 3.4 : la boucle de la population ne se borne pas
## toute seule, et ce qui la borne est le logement, donc la terre plate qu'il occupe.
@export_range(0, 100, 1) var base_housing: int

## Habitants à l'ouverture d'un run.
##
## Il tient dans base_housing, sans quoi le premier tour tuerait des gens pour respecter un
## plafond que le run n'a jamais dépassé. Le contrôle est plus bas.
@export_range(0, 100, 1) var starting_population: int

## Nourriture due par habitant et par tour, **immobilisés compris**.
##
## Il s'appelait upkeep_per_worker jusqu'à N1, et le renommage n'est pas cosmétique : un
## ouvrier était une fiche qu'on affectait, un habitant est une unité d'un compteur. Le
## chiffre est le même, ce qu'il compte a changé de nature.
##
## Il reste **plat**, et c'est un choix de DESIGN.md 3.4 : un upkeep qui grossirait avec la
## population freinerait la boucle par un chiffre que le joueur ne voit pas. Le frein est
## le logement, qui est sur la carte.
@export_range(0, 10, 1) var upkeep_per_inhabitant: int

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
## Deux contrôles de cohérence plutôt que de présence, et les deux disent la même chose sur
## un plafond commun : un chiffre d'ouverture qui dépasse son plafond serait écrêté au
## premier tour, et le .tres mentirait sur ce que le run reçoit vraiment. Le stock contre la
## capacité, la population contre le logement.
##
## Ce que ce fichier ne peut **pas** contrôler, et c'est la question que CLAUDE.md pose
## avant tout missing_fields() : qu'il existe quelque part un bâtiment qui loge sans coûter
## de travailleur. Une EconomyBalance ne voit pas le catalogue, donc la règle monte d'un
## cran, dans GameDatabase.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if base_storage_cap <= 0:
		missing.append("base_storage_cap")
	if base_housing <= 0:
		missing.append("base_housing")
	if starting_population <= 0:
		missing.append("starting_population")
	if upkeep_per_inhabitant <= 0:
		missing.append("upkeep_per_inhabitant")
	if upkeep_resource.is_empty():
		missing.append("upkeep_resource")
	for resource in starting_stock:
		if starting_stock[resource] < 0:
			missing.append("starting_stock.%s" % resource)
	if base_storage_cap > 0 and _starting_total() > base_storage_cap:
		missing.append("starting_stock.over_capacity")
	if base_housing > 0 and starting_population > base_housing:
		missing.append("starting_population.over_housing")
	return missing

## Total du stock d'ouverture, toutes ressources confondues.
func _starting_total() -> int:
	var total := 0
	for resource in starting_stock:
		total += starting_stock[resource]
	return total
