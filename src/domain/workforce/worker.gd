class_name Worker
extends RefCounted
## Un ouvrier : un nom, deux axes de progression, et le fait d'être là ou non.
##
## C'est l'individu que DESIGN.md 3.4 oppose à un compteur. Il porte une **piste par
## famille** — ce qu'il sait faire — et un **niveau d'ouvrier** — ce qu'il a vécu —, et
## la règle qui les relie est la seule chose que cette classe garantit vraiment :
## **toute XP compte deux fois**, une fois pour la piste, une fois pour le niveau.
##
## C'est pourquoi les pistes ne sortent jamais d'ici. Rendre une SkillTrack laisserait
## un appelant la créditer seule, et la règle deviendrait une consigne au lieu d'un
## invariant. Les accesseurs délèguent, ce qui est le prix à payer et il est faible.
##
## Le niveau est un **compteur réel et non la somme des pistes**. Aujourd'hui les deux
## coïncident, puisque le travail est la seule source d'XP écrite ; ils divergeront dès
## qu'une XP n'appartiendra à aucune famille — celle d'un événement — ou qu'un gain de
## combat arrivera avec F1. Le dériver maintenant obligerait alors à inventer une
## famille fourre-tout pour l'y loger.
##
## Ce que le niveau **offre** n'existe pas : il se gagne et se lit, rien de plus. Le
## choix de compétence au passage de palier est X5.
##
## Vivier unique : ce même objet est la source de la LaborForce et le sera de la
## CombatForce à F1. Rien hors de domain/workforce/ n'en voit un — DESIGN.md 3.4.

## Identifiant stable. Une affectation le désigne par lui, un rapport le nomme par lui.
var _id: StringName

## Prénom d'affichage. Deux ouvriers peuvent le partager, l'identifiant non.
var _given_name: String

## Est-il disponible ce soir ?
##
## DESIGN.md 3.9 : des ouvriers peuvent être absents sans être morts. Rien ne rend
## personne absent avant X1 ; l'état existe pour que rien ne suppose le roster entier
## disponible, ce qui ne se rattrape pas après coup.
var _present: bool = true

## Famille -> piste, dans l'ordre où les familles ont été entamées.
var _tracks: Dictionary[StringName, SkillTrack] = {}

## XP totale, toutes sources confondues. C'est l'axe du niveau d'ouvrier.
var _xp: int = 0

## Ouvrier neuf : aucune piste, niveau zéro, présent.
static func create(id: StringName, given_name: String) -> Worker:
	assert(not id.is_empty(), "ouvrier sans identifiant")
	var worker := Worker.new()
	worker._id = id
	worker._given_name = given_name
	return worker

## Identifiant stable.
func id() -> StringName:
	return _id

## Prénom d'affichage.
func given_name() -> String:
	return _given_name

## Est-il disponible ce soir ?
func is_present() -> bool:
	return _present

## Le marque présent ou absent. Un absent reste au roster : il n'est pas mort, et son
## XP l'attend.
func set_present(present: bool) -> void:
	_present = present

## XP totale gagnée, tous axes confondus.
func xp() -> int:
	return _xp

## Niveau d'ouvrier atteint.
##
## Même règle de palier que les pistes, avec ses propres réglages : voir
## SkillTrack.level_at().
func level(balance: WorkforceBalance) -> int:
	assert(balance != null, "niveau demandé sans équilibrage")
	return SkillTrack.level_at(_xp, balance.worker_xp_per_level, balance.max_worker_level)

## Le niveau d'ouvrier a-t-il atteint son plafond ?
func is_capped(balance: WorkforceBalance) -> bool:
	return level(balance) >= balance.max_worker_level

## Familles dans lesquelles il a entamé une piste, dans l'ordre où il les a entamées.
func families() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(_tracks.keys())
	return names

## A-t-il entamé cette piste ?
func has_track(family: StringName) -> bool:
	return _tracks.has(family)

## XP accumulée dans cette famille. 0 si la piste n'est pas entamée.
func track_xp(family: StringName) -> int:
	if not _tracks.has(family):
		return 0
	return _tracks[family].xp()

## Palier atteint dans cette famille. 0 si la piste n'est pas entamée.
func skill_level(family: StringName, balance: WorkforceBalance) -> int:
	if not _tracks.has(family):
		return 0
	return _tracks[family].level(balance)

## Cette piste a-t-elle atteint son plafond ? Faux si elle n'est pas entamée.
func is_skill_capped(family: StringName, balance: WorkforceBalance) -> bool:
	if not _tracks.has(family):
		return false
	return _tracks[family].is_capped(balance)

## Multiplicateur dans cette famille, ou BASE_EFFICIENCY faute de piste.
##
## Le repli est la même valeur que celle du contrat, et pour la même raison : un ouvrier
## neuf produit ce que le bâtiment promet, ni plus ni moins.
func efficiency(family: StringName, balance: WorkforceBalance) -> float:
	assert(balance != null, "multiplicateur demandé sans équilibrage")
	if not _tracks.has(family):
		return LaborUnit.BASE_EFFICIENCY
	return _tracks[family].efficiency(balance)

## Crédite cette famille, et le niveau d'ouvrier du même montant.
##
## C'est le seul chemin d'entrée de l'XP, et c'est ce qui rend la règle des deux axes
## structurelle plutôt que respectée. La piste s'ouvre au premier gain : un ouvrier
## n'a pas trois pistes vierges, il en a autant qu'il a exercé de métiers.
func gain(family: StringName, amount: int) -> void:
	assert(not family.is_empty(), "gain d'XP sans famille")
	assert(amount >= 0, "gain d'XP négatif pour %s : %d" % [_id, amount])
	if not _tracks.has(family):
		_tracks[family] = SkillTrack.create(family)
	_tracks[family].gain(amount)
	_xp += amount

## Ce que l'Économie voit de lui : un nom, un multiplicateur par piste entamée, et où il en
## est dans chacune.
##
## Les pistes vierges n'y figurent pas — LaborUnit replie sur BASE_EFFICIENCY et sur zéro,
## donc le résultat est le même et le dictionnaire se lit comme la liste de ce qu'il a
## exercé. Ni le niveau ni la présence ne traversent : la projection est exactement
## l'endroit où DESIGN.md 3.4 veut que l'Économie cesse de savoir.
##
## **L'XP de piste traverse depuis I2**, et ce docstring disait le contraire. Elle ne
## traverse pas pour produire quoi que ce soit — c'est efficiency() qui multiplie, et ça ne
## bouge pas — mais pour **départager** deux ouvriers que le même palier rend identiques.
## Le niveau, lui, reste dehors : c'est un palier de plus, donc la même égalité un cran plus
## haut, et 3.4 le réserve à ce qu'un ouvrier a vécu plutôt qu'à ce qu'il sait faire.
func to_labor_unit(balance: WorkforceBalance) -> LaborUnit:
	assert(balance != null, "projection sans équilibrage")
	var multipliers: Dictionary[StringName, float] = {}
	var progress: Dictionary[StringName, int] = {}
	for family in _tracks:
		multipliers[family] = _tracks[family].efficiency(balance)
		progress[family] = _tracks[family].xp()
	return LaborUnit.create(_id, multipliers, progress)

## Ce que le Combat voit de lui : un nom et **un** multiplicateur.
##
## La seconde projection annoncée depuis W1, et elle prouve que le vivier est unique sans
## que le Combat puisse le deviner : elle sort du même objet, lit la même piste par le même
## efficiency(), et ne rend pourtant rien qui ressemble à une LaborUnit.
##
## La famille est un **argument** et non une constante de ce fichier, pour la raison qui
## vaut depuis I1 : DESIGN.md 3.4 pose que la liste des familles n'est pas close et
## qu'aucun code ne l'énumère. Écrire &"combat" ici rouvrirait l'énumération que la
## Construction a pu rejoindre sans une ligne de GDScript. Elle vient de
## CombatBalance.combat_skill_family, que l'appelant lit.
##
## Une piste vierge replie sur BASE_EFFICIENCY, comme côté Économie et pour une raison qui
## lui est propre : un paysan qui n'a jamais tenu une lance vaut quand même un corps sur la
## ligne. DESIGN.md 3.4 assume la limite et y répond par *S'entraîner*, pas en le comptant
## pour rien.
##
## **C'est ici, et nulle part ailleurs, que la piste Combat devient des chiffres.** F2a a
## donné au contrat un profil complet plutôt qu'un multiplicateur, et cette fonction est
## tout ce qui les relie : le jour où un palier donnera des stats nommées, où les PV se
## tireront à la création, ou où un équipement s'en mêlera, c'est cette dizaine de lignes
## qui change — et le plateau, qui ne lit que le profil, ne s'en aperçoit pas.
##
## **La piste multiplie les dégâts et rien d'autre.** L'argument est dans CombatBalance :
## un entraînement fait frapper plus fort, encaisser relève de X5 et de X6. Le plancher
## comme le plafond passent par elle, sans quoi un vétéran verrait sa fourchette s'étirer
## au lieu de se déplacer — deux vétérans identiques rendraient alors des coups plus
## dispersés que ceux d'un bleu.
##
## Le combat reçoit son bloc en argument comme l'Économie reçoit le sien depuis E1. Les
## Effectifs ne lisent donc rien qu'on ne leur ait donné, et ne connaissent du Combat que
## le fichier de chiffres qu'on leur tend.
func to_combat_unit(family: StringName, workforce: WorkforceBalance,
		combat: CombatBalance) -> CombatUnit:
	assert(workforce != null, "projection sans équilibrage des effectifs")
	assert(combat != null, "projection sans équilibrage du combat")
	assert(not family.is_empty(), "projection de combat sans famille")
	var rank := efficiency(family, workforce)
	return CombatUnit.create(_id, rank, CombatStats.create(
		combat.fighter_hit_points,
		floori(combat.fighter_damage_min * rank),
		floori(combat.fighter_damage_max * rank),
		combat.fighter_reach, combat.fighter_move, combat.fighter_climb))
