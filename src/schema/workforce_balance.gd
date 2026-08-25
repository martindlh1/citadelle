class_name WorkforceBalance
extends Resource
## Réglages des Effectifs : les places du roster, ce que vaut une soirée de travail, et
## les deux courbes de paliers.
##
## Deux axes de progression, tranchés à W1 et décrits en DESIGN.md 3.4. La **piste**
## dit ce qu'un ouvrier sait faire et donne un multiplicateur ; le **niveau d'ouvrier**
## dit ce qu'il a vécu et n'en donne aucun. Ils ont chacun leur seuil et leur plafond,
## réglables séparément — un ouvrier peut plafonner sa spécialité en continuant à monter
## en niveau, et c'est cette situation-là qui rendra X5 intéressant.
##
## Un seul chiffre de gain les alimente tous les deux : toute XP compte deux fois, une
## fois pour la piste concernée et une fois pour le niveau. Deux montants distincts
## auraient donné un levier de plus à régler par source d'XP, et deux chiffres à tenir
## cohérents pour rien.
##
## Le seuil est **constant d'un palier à l'autre** : le troisième niveau coûte ce qu'a
## coûté le premier. Une courbe qui accélère demanderait un second paramètre par axe, et
## rien aujourd'hui ne dit qu'elle est nécessaire — le harnais est là pour le dire.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Places de roster avant toute habitation.
##
## Exactement le rôle que base_storage_cap tient pour la réserve : les habitations le
## relèvent, et rien d'autre. Ce qui **remplit** ces places reste ouvert — DESIGN.md
## 3.4 garde le recrutement sous un OUVERT.
@export_range(0, 100, 1) var base_roster_places: int

## XP qu'un ouvrier gagne pour un poste tenu un soir.
##
## Une ligne du journal de travail vaut ce montant, quel que soit ce que le poste a
## rapporté. L'XP se gagne **à l'usage** et non au prorata du produit : indexer le gain
## sur la récolte ferait composer le bon ouvrier avec lui-même, et la courbe
## divergerait sans que rien ne le signale.
@export_range(0, 100, 1) var xp_per_shift: int

## XP à accumuler dans une piste pour en franchir un palier.
@export_range(0, 1000, 1) var skill_xp_per_level: int

## Palier de piste au-delà duquel l'XP n'apporte plus rien.
##
## Le multiplicateur est borné pour la même raison que la réserve : sans plafond, une
## partie longue le laisse diverger et l'équilibrage n'a plus de prise.
@export_range(0, 20, 1) var max_skill_level: int

## Ce qu'un palier de piste ajoute au multiplicateur d'efficacité.
##
## Un ouvrier sans piste vaut LaborUnit.BASE_EFFICIENCY ; chaque palier ajoute ce cran.
## C'est le seul des sept champs qui touche directement la production d'un soir.
@export_range(0.0, 2.0, 0.01) var efficiency_per_skill_level: float

## XP à accumuler, toutes sources confondues, pour franchir un palier de niveau.
##
## Distinct de skill_xp_per_level : le niveau agrège ce que les pistes séparent, donc il
## n'y a aucune raison qu'ils avancent au même rythme.
@export_range(0, 1000, 1) var worker_xp_per_level: int

## Palier de niveau au-delà duquel l'XP n'élève plus l'ouvrier.
##
## Il ne borne aucun multiplicateur — un niveau n'en donne pas. Il borne ce que X5
## pourra offrir : un niveau sans plafond serait une liste de compétences infinie.
@export_range(0, 50, 1) var max_worker_level: int

## Champs non renseignés. Vide = bloc exploitable.
##
## Les sept sont réclamés sans condition. Aucun ne casse au chargement : un seuil à zéro
## divise par zéro au premier palier calculé, un plafond à zéro fige tout le monde au
## niveau 0 en silence, et des places à zéro refusent un roster que rien n'interdit.
## C'est précisément pourquoi le boot les réclame.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if base_roster_places <= 0:
		missing.append("base_roster_places")
	if xp_per_shift <= 0:
		missing.append("xp_per_shift")
	if skill_xp_per_level <= 0:
		missing.append("skill_xp_per_level")
	if max_skill_level <= 0:
		missing.append("max_skill_level")
	if efficiency_per_skill_level <= 0.0:
		missing.append("efficiency_per_skill_level")
	if worker_xp_per_level <= 0:
		missing.append("worker_xp_per_level")
	if max_worker_level <= 0:
		missing.append("max_worker_level")
	return missing
