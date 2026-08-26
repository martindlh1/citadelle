class_name LaborForce
extends RefCounted
## La main-d'œuvre projetée par les Effectifs pour l'Économie.
##
## DESIGN.md 3.4 : ni l'Économie ni le Combat ne savent d'où viennent ces effectifs.
## Rien ici ne permet de deviner s'il y a un vivier ou deux, ce qui est exactement ce
## qui rend cette question reportable.
##
## size() est le **roster**, et non le nombre d'affectés : l'upkeep se paie sur tout le
## monde, oisifs compris. C'est ce qui rend un ouvrier non affecté coûteux, donc le
## pool tendu, ce qui est la tension centrale du jeu.
##
## « Le roster » veut dire les ouvriers **présents**, ce que W1 a tranché en ne
## projetant pas les absents : un ouvrier parti en expédition ne mange pas. La bascule
## inverse demanderait de distinguer ici « qui peut travailler » de « qui mange », soit
## un champ de plus sur ce contrat. Voir DESIGN.md 3.4 et 3.9.
##
## Immuable.

## Ouvriers, dans l'ordre où les Effectifs les ont donnés.
var _units: Array[LaborUnit] = []

## Identifiant -> ouvrier.
var _by_id: Dictionary[StringName, LaborUnit] = {}

## Main-d'œuvre composée de ces ouvriers, dans cet ordre.
static func create(units: Array[LaborUnit]) -> LaborForce:
	var force := LaborForce.new()
	for unit in units:
		assert(unit != null, "main-d'œuvre avec un ouvrier nul")
		assert(not force._by_id.has(unit.id()), "deux ouvriers nommés %s" % unit.id())
		force._units.append(unit)
		force._by_id[unit.id()] = unit
	return force

## Main-d'œuvre vide. Un roster à zéro ne mange rien et ne produit rien.
static func empty() -> LaborForce:
	var none: Array[LaborUnit] = []
	return LaborForce.create(none)

## Taille du roster. C'est cette valeur que l'upkeep multiplie, et non le nombre
## d'ouvriers effectivement au travail.
func size() -> int:
	return _units.size()

## Identifiants des ouvriers, dans l'ordre donné.
func workers() -> Array[StringName]:
	var ids: Array[StringName] = []
	for unit in _units:
		ids.append(unit.id())
	return ids

## Cet ouvrier fait-il partie du roster ?
##
## Le résultat n'est pas toujours vrai pour un ouvrier nommé par une affectation : une
## affectation peut avoir survécu à celui qui la portait. C'est au résolveur de le
## constater, pas de s'y casser.
func has(worker: StringName) -> bool:
	return _by_id.has(worker)

## Ouvrier nommé. Précondition : has(worker).
func unit(worker: StringName) -> LaborUnit:
	assert(has(worker), "ouvrier inconnu de la main-d'œuvre : %s" % worker)
	return _by_id[worker]

## XP de cet ouvrier dans cette piste. Zéro pour un inconnu, comme pour une piste vierge.
##
## Un repli plutôt qu'une précondition, à l'inverse de `efficiency()` juste en dessous, et
## l'écart est délibéré. Un rendement demandé pour quelqu'un qui n'est pas là est une
## erreur d'appel — la production ne multiplie que ce qu'une `Assignment` a placé. Un
## progrès, lui, se demande couramment d'une liste de **candidats** que l'appelant vient de
## filtrer autrement, et « il n'est pas là, donc il n'a rien fait » est la bonne réponse
## plutôt qu'un plantage.
func track_xp(worker: StringName, family: StringName) -> int:
	if not has(worker):
		return 0
	return _by_id[worker].track_xp(family)

## Multiplicateur de cet ouvrier dans cette famille. Précondition : has(worker).
func efficiency(worker: StringName, family: StringName) -> float:
	return unit(worker).efficiency(family)
