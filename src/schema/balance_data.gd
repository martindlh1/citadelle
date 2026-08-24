class_name BalanceData
extends Resource
## Racine de l'équilibrage : un sous-bloc par système.
##
## Chaque système ajoute son champ ici quand il atterrit — economy, workforce, combat.
## Un champ n'est jamais retiré sans migrer les .tres qui le référencent.
##
## Point d'accès unique : GameDatabase.get_balance().

@export var terrain: TerrainBalance

## Champs non renseignés de tous les blocs, préfixés du nom de leur bloc.
## Vide = équilibrage exploitable. Vérifié au boot par GameDatabase.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if terrain == null:
		missing.append("terrain")
	else:
		for field in terrain.missing_fields():
			missing.append("terrain.%s" % field)
	return missing
