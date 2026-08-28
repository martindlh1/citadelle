class_name CombatBalance
extends Resource
## Réglages du Combat : combien de monde tient la ligne, ce qu'un homme y vaut, et ce
## qu'une brèche coûte.
##
## Neuvième bloc de BalanceData. Cinq chiffres à F1, et ils portaient tout le bouchon — le
## signe qu'un bouchon est bien un bouchon. F2a y ajoute le **profil d'un ouvrier engagé**
## et les réglages du **plateau**, ce qui triple le fichier et dit exactement ce que le vrai
## combat coûte de plus qu'une soustraction.
##
## Le profil d'un ouvrier est ici et pas ailleurs pour une raison qu'il faut lire une fois :
## ce sont des chiffres de **combat**, donc ils vivent dans le bloc du Combat, et c'est la
## projection des Effectifs qui vient les chercher — Roster.to_combat() reçoit ce bloc en
## argument, comme le résolveur de production reçoit le sien depuis E1. L'inverse — des PV
## dans WorkforceBalance — aurait mis des chiffres de bataille dans le fichier qu'on ouvre
## pour régler une courbe d'XP.
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

# --- le profil d'un ouvrier engagé, entré à F2a --------------------------------------

## Points de vie d'un ouvrier engagé.
##
## **Il ne passe pas par l'efficacité, et c'est une décision.** Le multiplicateur de la
## piste Combat dit ce qu'un homme *porte*, pas ce qu'il *encaisse* : un entraînement fait
## frapper plus fort, survivre relève de l'équipement et de la constitution, donc de X5 et
## de X6. Le lui faire multiplier les deux rendrait un vétéran deux fois meilleur sur deux
## axes à la fois, ce qui est une courbe qu'on ne peut plus régler.
##
## Tous les ouvriers ont donc les mêmes PV aujourd'hui. Ce n'est **pas** une généralité de
## contrat pour autant : le chiffre voyage sur le CombatStats de chaque unité, si bien que
## le jour où un palier en donnera ou où l'on voudra les tirer à la création, seule la
## projection change et le plateau ne s'en aperçoit pas.
@export_range(1, 200, 1) var fighter_hit_points: int

## Plancher des dégâts d'un ouvrier engagé, avant son multiplicateur.
##
## Zéro est légitime — une fourchette qui part de zéro est un homme qui rate parfois —,
## donc c'est le plafond qui porte le contrôle. Voir EnemyData, qui tranche pareil.
@export_range(0, 100, 1) var fighter_damage_min: int

## Plafond des dégâts d'un ouvrier engagé, avant son multiplicateur.
##
## C'est **ce chiffre-là** que la piste Combat écarte, avec son plancher. Le pendant exact
## de ActionBalance.bare_yield pour l'autre moitié du jeu : une base que la piste de
## l'ouvrier multiplie ensuite, ce qui fait de la piste un métier plutôt qu'un compteur.
@export_range(1, 100, 1) var fighter_damage_max: int

## Jusqu'où un ouvrier engagé frappe, en cases.
##
## CombatStats.CONTACT tant que rien ne l'arme : DESIGN.md 3.4 assume qu'« un paysan sans
## équipement y est peu utile » et y répond par *S'entraîner*, pas par une portée gratuite.
@export_range(1, 20, 1) var fighter_reach: int

## Points de déplacement d'un ouvrier engagé par tour.
@export_range(0, 20, 1) var fighter_move: int

## Plus haute marche qu'un ouvrier engagé franchit d'un seul pas.
##
## Zéro est légitime : des défenseurs qui ne grimpent pas font d'un plateau une forteresse
## dont ils ne sortent plus, ce qui est un modèle jouable et non un champ oublié.
@export_range(0, 20, 1) var fighter_climb: int

# --- le plateau, entré à F2a ---------------------------------------------------------

## Points de déplacement qu'un cran de montée coûte, par-dessus le pas lui-même.
##
## C'est la première moitié de DESIGN.md 3.6, « monter coûte, une marche trop haute
## bloque » ; la seconde est le `climb` de chaque corps. Descendre ne coûte rien de plus
## qu'un pas, ce qui fait d'une hauteur un avantage qu'on **tient** plutôt qu'un mur.
##
## Zéro est légitime et n'est pas un oubli : le relief ne bloquerait plus que par les
## marches trop hautes, ce qui reste un modèle qu'on a le droit d'essayer sans toucher au
## GDScript.
@export_range(0, 10, 1) var climb_cost: int

## Tags de terrain qu'aucun corps ne traverse.
##
## En data et jamais dans le code : le domaine écrirait sinon `&"water"`, qui est
## exactement le nombre magique que les conventions refusent. Même geste que
## `combat_skill_family`, et même raison — la palette de terrains de DESIGN.md 3.1 vit
## dans data/terrain/ et personne ne l'énumère.
##
## **Réclamé non vide**, à l'inverse des zéros ci-dessus. Godot n'écrit pas un tableau vide
## dans un .tres, donc « oublié » et « délibérément vide » y sont indiscernables — c'est le
## piège de `resolves`. Et l'issue de PhaseDef ne s'applique pas : aucun bloc au-dessus ne
## voit cette liste. Un combat où l'on marche sur l'eau n'est pas un réglage, c'est un
## champ perdu.
@export var impassable_tags: Array[StringName]

## Cases entre la lisière du bâti et la case d'entrée de la vague.
##
## DESIGN.md 3.6 : « la vague entre à la lisière du bâti et non au bord de la carte —
## seize cases de marche avant le premier contact seraient quatre tours où personne ne
## décide rien ». C'est ce chiffre qui achète ces tours, donc celui qui décide si une
## manche commence par une décision ou par une marche.
@export_range(1, 20, 1) var spawn_margin: int

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## Trois familles de champs cohabitent ici, et il vaut mieux le savoir en le lisant : ceux
## du bouchon de F1 — `defense_per_fighter`, `breach_per_casualty`, `plunder_per_breach` —,
## qui partiront avec lui à F3 ; le profil d'un ouvrier engagé ; et les réglages du plateau.
## Seul `base_deployment_slots` sert aux deux époques, ce qui est normal : le déploiement
## capé est une règle de design et non une arithmétique.
##
## Deux champs échappent à la doctrine du zéro, chacun pour une raison de contenu écrite
## sur lui : `plunder_per_breach` depuis F1, `fighter_climb` et `climb_cost` depuis F2a.
## `fighter_damage_min` non plus, puisqu'une fourchette part légitimement de zéro — c'est
## son **inversion** qui est signalée, comme chez EnemyData.
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
	if fighter_hit_points <= 0:
		missing.append("fighter_hit_points")
	if fighter_damage_max <= 0:
		missing.append("fighter_damage_max")
	if fighter_damage_min > fighter_damage_max:
		missing.append("fighter_damage_min")
	if fighter_reach < CombatStats.CONTACT:
		missing.append("fighter_reach")
	if fighter_move <= 0:
		missing.append("fighter_move")
	if impassable_tags.is_empty():
		missing.append("impassable_tags")
	if spawn_margin <= 0:
		missing.append("spawn_margin")
	return missing
