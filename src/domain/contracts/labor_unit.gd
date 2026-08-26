class_name LaborUnit
extends RefCounted
## Un ouvrier, tel que l'Économie le voit : un nom, un multiplicateur par famille, et où
## il en est dans chacune.
##
## C'est tout ce que la production consomme d'un effectif. Ni les traits, ni les blessures,
## ni même le fait qu'il puisse aussi se battre : DESIGN.md 3.4 pose que l'Économie ne sait
## pas d'où viennent ses effectifs, et cette classe est l'endroit où cette ignorance se
## matérialise. Un vivier ou deux ne se devine pas d'ici.
##
## **L'XP de piste y est entrée après `I2`**, et c'est le premier contrat qui bouge depuis
## `F1`. Ce docstring disait « ni l'XP » et le refus était juste tant que rien ne posait la
## question ; le bouton d'auto-affectation de 3.4 la pose. Un multiplicateur vient d'un
## **palier**, donc six ouvriers frais rendent tous 1.00 dans toutes les familles, et
## classer sur cette seule valeur revenait à classer par ordre du roster jusqu'au premier
## palier — c'est-à-dire pendant les journées où le bouton sert le plus.
##
## Ce qui entre est bien l'XP et non le niveau : le niveau est un palier de plus, donc la
## même égalité un cran plus haut. Ce qui manquait était **où l'on en est à l'intérieur d'un
## palier**, et il n'y a que l'XP pour le dire.
##
## Elle ne donne aucun rendement et n'en donnera jamais : `efficiency()` reste la seule
## chose que la production multiplie. Elle sert à **départager**, ce qui est une question
## d'ordre et non de calcul.
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

## Famille -> XP accumulée dans cette piste.
var _track_xp: Dictionary[StringName, int] = {}

## Ouvrier nommé, avec ses multiplicateurs par famille de compétence.
##
## Les familles absentes valent BASE_EFFICIENCY : les Effectifs n'ont pas à renseigner
## les trois pistes d'un ouvrier qui n'en a entamé aucune.
static func create(id: StringName, efficiency: Dictionary[StringName, float],
		track_xp: Dictionary[StringName, int] = {}) -> LaborUnit:
	assert(not id.is_empty(), "ouvrier sans identifiant")
	var unit := LaborUnit.new()
	unit._id = id
	for family in efficiency:
		assert(efficiency[family] >= 0.0,
			"multiplicateur négatif pour %s en %s" % [id, family])
		unit._efficiency[family] = efficiency[family]
	for family in track_xp:
		assert(track_xp[family] >= 0,
			"XP négative pour %s en %s" % [id, family])
		unit._track_xp[family] = track_xp[family]
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

## XP accumulée dans cette piste, ou 0 faute de piste.
##
## Zéro et non BASE_EFFICIENCY : une piste vierge vaut « aucun bonus » côté rendement mais
## « rien de fait » côté progrès, et les deux valeurs neutres ne sont pas la même.
func track_xp(family: StringName) -> int:
	if not _track_xp.has(family):
		return 0
	return _track_xp[family]

## Familles dans lesquelles il a une piste, dans l'ordre où elles ont été données.
func families() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(_efficiency.keys())
	return names
