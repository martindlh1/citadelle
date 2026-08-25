class_name SkillTrack
extends RefCounted
## Une piste de compétence : l'XP d'un ouvrier dans une famille, et ce qu'elle vaut.
##
## C'est l'axe qui dit **ce qu'un ouvrier sait faire**. Il monte par paliers, et chaque
## palier ajoute un cran au multiplicateur que l'Économie applique au rendement d'un
## slot. L'autre axe — le niveau d'ouvrier, qui dit ce qu'il a vécu — vit sur Worker et
## ne donne aucun multiplicateur. Voir DESIGN.md 3.4.
##
## État interne des Effectifs, comme le Ledger l'est de l'Économie : rien hors de
## domain/workforce/ n'en voit une. Ce qui sort du système est une LaborUnit, qui ne
## porte que des multiplicateurs déjà calculés — c'est ce qui permet à DESIGN.md 3.4 de
## promettre que l'Économie ne sait pas d'où viennent ses effectifs.
##
## Mutable par gain() et par rien d'autre. En particulier, Worker ne rend jamais une
## piste à l'extérieur : la faire créditer directement contournerait la règle « toute XP
## compte deux fois », qui est le seul invariant liant les deux axes.

var _family: StringName
var _xp: int = 0

## Piste vierge dans cette famille.
static func create(family: StringName) -> SkillTrack:
	assert(not family.is_empty(), "piste de compétence sans famille")
	var track := SkillTrack.new()
	track._family = family
	return track

## Piste déjà entamée. Sert aux tests et au chargement d'un roster existant ; le jeu,
## lui, ne fait jamais qu'appeler gain().
static func at_xp(family: StringName, xp: int) -> SkillTrack:
	assert(xp >= 0, "piste ouverte sur une XP négative : %d" % xp)
	var track := SkillTrack.create(family)
	track._xp = xp
	return track

## Palier atteint avec cette XP, sous ce seuil et ce plafond.
##
## Statique et publique parce que **les deux axes montent de la même façon** : le niveau
## d'ouvrier appelle exactement cette fonction avec ses propres réglages. Seuls les
## chiffres diffèrent, jamais la règle — une progression qui accélérerait sur un axe et
## pas sur l'autre serait une décision d'équilibrage déguisée en décision de code.
##
## Le seuil est constant d'un palier à l'autre : le troisième niveau coûte ce qu'a coûté
## le premier. Voir le docstring de WorkforceBalance.
static func level_at(xp: int, per_level: int, cap: int) -> int:
	assert(per_level > 0, "seuil de palier non renseigné : %d" % per_level)
	assert(cap >= 0, "plafond de palier négatif : %d" % cap)
	return mini(xp / per_level, cap)

## Famille de compétence que cette piste couvre.
func family() -> StringName:
	return _family

## XP accumulée.
func xp() -> int:
	return _xp

## Crédite cette piste. Un gain négatif est une erreur de programmation, pas une
## sanction : les conséquences de la famine ou d'une blessure restent OUVERT en
## DESIGN.md 3.3 et 3.4, et rien ici ne doit préempter leur forme.
func gain(amount: int) -> void:
	assert(amount >= 0, "gain d'XP négatif sur la piste %s : %d" % [_family, amount])
	_xp += amount

## Palier atteint dans cette piste.
func level(balance: WorkforceBalance) -> int:
	assert(balance != null, "palier demandé sans équilibrage")
	return level_at(_xp, balance.skill_xp_per_level, balance.max_skill_level)

## Multiplicateur d'efficacité que cette piste donne dans sa famille.
##
## Une piste vierge vaut LaborUnit.BASE_EFFICIENCY et non zéro : le contrat pose déjà
## qu'une piste non entamée veut dire « aucun bonus » et non « incapable », et reprendre
## sa constante plutôt qu'un 1.0 écrit ici garde les deux définitions liées.
func efficiency(balance: WorkforceBalance) -> float:
	assert(balance != null, "multiplicateur demandé sans équilibrage")
	return LaborUnit.BASE_EFFICIENCY + level(balance) * balance.efficiency_per_skill_level

## Cette piste a-t-elle atteint son plafond ? L'XP au-delà ne rend plus rien.
func is_capped(balance: WorkforceBalance) -> bool:
	return level(balance) >= balance.max_skill_level
