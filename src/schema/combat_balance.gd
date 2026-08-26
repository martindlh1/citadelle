class_name CombatBalance
extends Resource
## Réglages du Combat : combien de monde tient la ligne, ce qu'un homme y vaut, et ce
## qu'une brèche coûte.
##
## Neuvième bloc de BalanceData. Quatre chiffres, et ils portent tout le bouchon de F1 —
## c'est le signe qu'un bouchon est bien un bouchon.
##
## Ce qu'il ne contient **pas** : l'XP d'un combat. WorkforceBalance.xp_per_shift dit déjà
## ce que vaut un poste tenu un soir, et tenir la ligne en est un. Un second montant aurait
## donné deux courbes à régler et à garder d'accord pour la même question — c'est
## exactement l'argument qui a mis un seul gain d'XP sur les deux axes de W1.
##
## Ni la liste des vagues, ni leur calendrier : les vagues sont du contenu et vivent dans
## data/waves/, et *quand* elles tombent est un OUVERT de DESIGN.md 2 que I2 datera.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Places de déploiement avant tout bâtiment.
##
## Exactement le rôle que base_roster_places tient pour le vivier et base_storage_cap pour
## la réserve : les bâtiments la relèvent, et rien d'autre. C'est ce plafond qui fait
## exister la tension du pitch au combat — sans lui, tout le roster se bat et « envoyer son
## meilleur récoltant en milice » ne coûte rien puisqu'on les envoie tous. Voir DESIGN.md
## 3.6, « Le déploiement, et pourquoi il est capé ».
@export_range(0, 50, 1) var base_deployment_slots: int

## Ce qu'un homme apporte à la défense, avant son multiplicateur.
##
## Le pendant exact de ActionBalance.bare_yield pour l'autre moitié du jeu : un chiffre de
## base que la piste de l'ouvrier écarte ensuite. C'est ce qui fait qu'un vétéran vaut deux
## bleus sur la ligne, et donc que la piste Combat soit un métier plutôt qu'un compteur.
@export_range(0, 100, 1) var defense_per_fighter: int

## Famille de compétence que le combat crédite.
##
## Elle décide du multiplicateur appliqué et de la piste que l'XP créditera en retour,
## exactement comme bare_skill_family pour une action à cru et site_skill_family pour un
## chantier. Elle vit ici et non dans le code pour la raison qui vaut depuis I1 : DESIGN.md
## 3.4 pose que la liste des familles n'est pas close et qu'aucun code ne l'énumère. La
## Construction est entrée sans une ligne de GDScript ; le Combat entre de même.
@export var combat_skill_family: StringName

## Points de brèche qu'il faut pour emporter un homme.
##
## Le seul chiffre qui décide de la létalité d'une vague, et le plus fragile des quatre :
## un cran trop bas efface un roster en une nuit, un cran trop haut rend le combat
## indolore. C'est un candidat direct pour I3, qui le règlera devant un run entier.
@export_range(1, 500, 1) var breach_per_casualty: int

## Unités de réserve volées par point de brèche.
##
## Le pillage de DESIGN.md 3.6. Il se prend **au prorata du stock**, comme la réserve
## commune écrête au prorata de ce qu'un soir produit : une vague ne choisit pas ce qu'elle
## emporte, et deux villages aux mêmes réserves rangées dans un ordre différent doivent
## perdre la même chose.
@export_range(0, 100, 1) var plunder_per_breach: int

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## `plunder_per_breach` est le seul à échapper à la doctrine du zéro, et c'est une décision
## de contenu qui se tient : une vague qui casse sans voler est un modèle jouable, et le
## réclamer interdirait de l'essayer sans toucher au GDScript. Les quatre autres cassent
## quelque chose à zéro — pas une place de déploiement, pas un homme qui compte, une piste
## sans nom, ou une division par zéro.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if base_deployment_slots <= 0:
		missing.append("base_deployment_slots")
	if defense_per_fighter <= 0:
		missing.append("defense_per_fighter")
	if combat_skill_family.is_empty():
		missing.append("combat_skill_family")
	if breach_per_casualty <= 0:
		missing.append("breach_per_casualty")
	return missing
