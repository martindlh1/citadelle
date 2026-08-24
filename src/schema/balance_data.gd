class_name BalanceData
extends Resource
## Racine de l'équilibrage : un sous-bloc par système.
##
## Chaque système ajoute son champ ici quand il atterrit — economy, workforce,
## combat. Un champ n'est jamais retiré sans migrer les .tres qui le référencent.
##
## Point d'accès unique : GameDatabase.get_balance().

@export var terrain: TerrainBalance
