class_name LaborUnit
extends RefCounted
## Un ouvrier, tel que l'Économie le voit : un nom et un multiplicateur par famille.
##
## C'est tout ce que la production consomme d'un effectif. Ni les traits, ni l'XP, ni
## les blessures, ni même le fait qu'il puisse aussi se battre : DESIGN.md 3.4 pose que
## l'Économie ne sait pas d'où viennent ses effectifs, et cette classe est l'endroit où
## cette ignorance se matérialise. Un vivier ou deux ne se devine pas d'ici.
##
## Immuable.

## Multiplicateur d'un ouvrier sans aucune piste dans la famille demandée.
##
## 1.0 et non 0.0 : une piste vierge veut dire « aucun bonus », pas « incapable ». Un
## ouvrier neuf produit ce que le bâtiment promet, ni plus ni moins, et c'est
## l'expérience qui l'en écarte ensuite.
const BASE_EFFICIENCY := 1.0

var _id: StringName
var _efficiency: Dictionary[StringName, float] = {}

## Ouvrier nommé, avec ses multiplicateurs par famille de compétence.
##
## Les familles absentes valent BASE_EFFICIENCY : les Effectifs n'ont pas à renseigner
## les trois pistes d'un ouvrier qui n'en a entamé aucune.
static func create(id: StringName, efficiency: Dictionary[StringName, float]) -> LaborUnit:
	assert(not id.is_empty(), "ouvrier sans identifiant")
	var unit := LaborUnit.new()
	unit._id = id
	for family in efficiency:
		assert(efficiency[family] >= 0.0,
			"multiplicateur négatif pour %s en %s" % [id, family])
		unit._efficiency[family] = efficiency[family]
	return unit

## Ouvrier sans aucune piste entamée. Il rend exactement ce que le bâtiment promet.
static func novice(id: StringName) -> LaborUnit:
	var none: Dictionary[StringName, float] = {}
	return LaborUnit.create(id, none)

## Identifiant stable. C'est par lui qu'une affectation le désigne et qu'un rapport le
## nomme.
func id() -> StringName:
	return _id

## Multiplicateur dans cette famille, ou BASE_EFFICIENCY faute de piste.
func efficiency(family: StringName) -> float:
	if not _efficiency.has(family):
		return BASE_EFFICIENCY
	return _efficiency[family]

## Familles dans lesquelles il a une piste, dans l'ordre où elles ont été données.
func families() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(_efficiency.keys())
	return names
