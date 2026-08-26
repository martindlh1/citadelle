class_name WaveSlot
extends Resource
## Une vague, et le jour où elle tombe.
##
## Le calendrier que `DESIGN.md` 8 réclamait pour `I2` : « Le calendrier des vagues est un
## bloc de `data/balance/` qui n'existe pas encore, exprès — un champ que personne ne lit
## serait la frontière que ce document refuse depuis `E1`. » Il est lu à partir de ce
## jalon, donc il entre.
##
## **Un jour et une vague, rien d'autre.** La forme retenue est la liste explicite plutôt
## qu'une période — « une vague tous les N jours » — et l'argument tient en deux points.
## Une liste **dit** une période en l'écrivant, alors qu'une période ne sait exprimer ni un
## creux ni deux vagues rapprochées. Et surtout la **vague finale** de `DESIGN.md` 2 tombe
## ici sur le dernier jour parce qu'on l'y a mise ; avec une période, elle n'y tomberait que
## par coïncidence arithmétique, et changer `days` la déplacerait sans qu'on le veuille.
##
## Elle vit dans `RunBalance` et non dans `CombatBalance`, qui s'en défausse en toutes
## lettres — « ni la liste des vagues, ni leur calendrier ». Le contrôle qui compte croise
## d'ailleurs `days` : un jour hors bornes est une vague que personne ne verra jamais
## tomber, et seul le bloc qui tient la durée du run peut le dire.
##
## La `WaveDef` est **référencée** et non recopiée : les vagues sont du contenu de
## `data/waves/`, indexé par `GameDatabase`, et un calendrier qui les redécrirait aurait
## deux endroits où lire la même puissance. C'est ce que `balance.tres` fait déjà de ses
## dix blocs.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Jour du run où cette vague tombe, à partir de 1.
##
## Elle tombe à la **fermeture** de la journée, après l'upkeep, à la place que la séquence
## de `DESIGN.md` 2 lui garde. Un jour au-delà de `days` est une incohérence et non une
## vague désactivée : `RunBalance` le rapporte.
@export_range(1, 100, 1) var day: int

## La vague qui tombe ce jour-là.
@export var wave: WaveDef

## Champs non renseignés ou incohérents. Vide = créneau exploitable.
##
## Le croisement avec `days` n'est **pas** ici : ce fichier ne connaît pas la durée du run,
## et l'y faire descendre demanderait de lui passer un chiffre qui ne lui appartient pas.
## C'est `RunBalance` qui le vérifie, comme il vérifie déjà l'unicité des identifiants de
## phase que `PhaseDef` ne peut pas voir seule.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if day <= 0:
		missing.append("day")
	if wave == null:
		missing.append("wave")
	else:
		for field in wave.missing_fields():
			missing.append("wave.%s" % field)
	return missing
