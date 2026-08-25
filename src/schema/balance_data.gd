class_name BalanceData
extends Resource
## Racine de l'équilibrage : un sous-bloc par système.
##
## Chaque système ajoute son champ ici quand il atterrit — economy, workforce, combat.
## Un champ n'est jamais retiré sans migrer les .tres qui le référencent.
##
## Point d'accès unique : GameDatabase.get_balance().

## Géométrie du terrain : taille de cellule et hauteur d'un cran.
@export var terrain: TerrainBalance

## Génération du terrain : relief, nappe d'eau, dispersion, palette.
@export var terrain_gen: TerrainGenBalance

## Caméra isométrique : zoom, pan, rotation, cadrage.
@export var camera: CameraBalance

## Économie : réserve commune, upkeep, stock d'ouverture.
@export var economy: EconomyBalance

## Effectifs : places du roster, valeur d'une soirée, courbes de paliers.
@export var workforce: WorkforceBalance

## Champs non renseignés de tous les blocs, préfixés du nom de leur bloc.
## Vide = équilibrage exploitable. Vérifié au boot par GameDatabase.
##
## L'agrégation est recopiée bloc par bloc plutôt que factorisée : il n'existe pas de
## classe parente commune aux blocs d'équilibrage, et passer par un Resource nu pour
## appeler missing_fields() rendrait l'appel non typé. La répétition est le prix du
## typage strict ; le jour où il y aura six blocs, une base commune vaudra le coup.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if terrain == null:
		missing.append("terrain")
	else:
		for field in terrain.missing_fields():
			missing.append("terrain.%s" % field)
	if terrain_gen == null:
		missing.append("terrain_gen")
	else:
		for field in terrain_gen.missing_fields():
			missing.append("terrain_gen.%s" % field)
	if camera == null:
		missing.append("camera")
	else:
		for field in camera.missing_fields():
			missing.append("camera.%s" % field)
	if economy == null:
		missing.append("economy")
	else:
		for field in economy.missing_fields():
			missing.append("economy.%s" % field)
	if workforce == null:
		missing.append("workforce")
	else:
		for field in workforce.missing_fields():
			missing.append("workforce.%s" % field)
	return missing
