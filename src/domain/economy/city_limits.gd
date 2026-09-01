class_name CityLimits
extends RefCounted
## Les deux plafonds que le bâti relève : la réserve et le logement.
##
## Un seul fichier pour deux fonctions de quatre lignes, et c'est leur **raison commune** qui
## le justifie plutôt que leur longueur. N1 l'a écrite dans Population : Ledger et Population
## sont deux plafonds bâtis sur le même modèle — une quantité, une capacité qu'un bâtiment
## relève, et un écrêtage quand cette capacité baisse. Un entrepôt détruit fait perdre des
## ressources, une habitation détruite fait perdre des habitants. Ce fichier est l'endroit où
## cette symétrie est visible ; les séparer la rendrait invisible.
##
## **Aucun des deux ne pouvait vivre chez celui qu'il plafonne.** Population ne connaît pas
## les bâtiments, et son docstring en fait une frontière : « ce partage garde la population
## hors de toute connaissance des bâtiments — elle est une ressource, ce sont eux qui la
## dépensent ». Ledger ne connaît pas la ville pour la même raison. Ranger le logement sur
## ProductionResolver, où la capacité de réserve vivait avant R0, ferait mentir son nom.
##
## Il **calcule et ne mute rien** : c'est l'orchestrateur qui applique, parce qu'appliquer
## les deux ensemble est ce qui garantit qu'aucun des deux ne soit oublié.
##
## Les deux lisent completed() et jamais buildings(), et c'est la même règle que depuis C4 :
## un entrepôt en chantier a payé son coût et occupe ses cellules, mais il n'a pas de toit.
## L'oubli serait silencieux — un entrepôt inachevé qui relève quand même la réserve ne casse
## rien, il ment.

## Capacité de la réserve pour cette ville : la base, plus ce que les entrepôts achevés
## ajoutent.
##
## Appelable seule, et le HUD en dépend : afficher « 47 / 200 » ne doit rien résoudre.
static func storage_for(city: CitySnapshot, balance: EconomyBalance) -> int:
	assert(city != null, "capacité demandée sans ville")
	assert(balance != null, "capacité demandée sans équilibrage")
	var capacity := balance.base_storage_cap
	for building in city.completed():
		capacity += building.data().storage_bonus
	return capacity

## Places de logement pour cette ville : la base, plus ce que les habitations achevées
## ajoutent.
##
## C'est le **frein spatial** de DESIGN.md 3.4, et le seul que la boucle de population
## reçoive : « une habitation occupe une case qu'une ferme n'aura pas. C'est tout le frein,
## et il est du même métal que le jeu. » Le chiffre qui sort d'ici est donc littéralement
## posé sur la carte, ce qu'un upkeep croissant n'aurait jamais été.
static func housing_for(city: CitySnapshot, balance: EconomyBalance) -> int:
	assert(city != null, "logement demandé sans ville")
	assert(balance != null, "logement demandé sans équilibrage")
	var places := balance.base_housing
	for building in city.completed():
		places += building.data().housing
	return places
