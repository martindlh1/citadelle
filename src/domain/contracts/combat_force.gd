class_name CombatForce
extends RefCounted
## Les combattants projetés par les Effectifs pour le Combat.
##
## DESIGN.md 3.4 : ni l'Économie ni le Combat ne savent d'où viennent ces effectifs.
## Rien ici ne permet de deviner s'il y a un vivier ou deux, ce qui est exactement ce qui
## rend cette question reportable — elle est tranchée depuis W1, et ce contrat continue
## de ne pas en dépendre.
##
## **Elle porte tout le roster présent, et non les seuls engagés.** C'est le miroir strict
## de LaborForce, qui porte tout le roster et non les seuls affectés : le filtre appartient
## au consommateur. L'Économie n'emploie que ce que l'Assignment place ; le Combat n'engage
## que ce que le déploiement de 3.6 tient. Projeter ici les seuls déployés donnerait aux
## Effectifs à connaître un plafond qui vient de la ville, ce qui leur ferait traverser une
## frontière qu'ils n'ont aucune raison de franchir.
##
## Elle n'a **pas** de size() qui veuille dire quelque chose de comparable à celui de
## LaborForce. Là-bas c'est le compte que l'upkeep multiplie, ce qui est une règle ; ici
## c'est le nombre de corps disponibles, dont seule une partie ira sur la ligne. Le nom
## est le même, la portée non, et c'est écrit ici pour que personne ne lise l'un pour
## l'autre.
##
## Immuable.

## Combattants, dans l'ordre où les Effectifs les ont donnés.
var _units: Array[CombatUnit] = []

## Identifiant -> combattant.
var _by_id: Dictionary[StringName, CombatUnit] = {}

## Force composée de ces combattants, dans cet ordre.
static func create(units: Array[CombatUnit]) -> CombatForce:
	var force := CombatForce.new()
	for unit in units:
		assert(unit != null, "force de combat avec un combattant nul")
		assert(not force._by_id.has(unit.id()), "deux combattants nommés %s" % unit.id())
		force._units.append(unit)
		force._by_id[unit.id()] = unit
	return force

## Force vide. Un village sans personne ne défend que par ses murs, ce qui est une
## situation légitime et non une erreur.
static func empty() -> CombatForce:
	var none: Array[CombatUnit] = []
	return CombatForce.create(none)

## Combattants disponibles. **Pas** le nombre d'engagés : voir le docstring de la classe.
func size() -> int:
	return _units.size()

## Identifiants des combattants, dans l'ordre donné.
##
## L'ordre est celui du roster, et il compte : c'est lui qui départage deux combattants
## d'égale valeur au déploiement, donc lui qui garantit que deux runs partis du même seed
## envoient les mêmes gens sur la ligne.
func fighters() -> Array[StringName]:
	var ids: Array[StringName] = []
	for unit in _units:
		ids.append(unit.id())
	return ids

## Ce combattant fait-il partie de la force ?
##
## Le résultat n'est pas toujours vrai d'un ouvrier qu'un rapport nomme : une force
## projetée avant un soir peut avoir perdu quelqu'un depuis. C'est au résolveur de le
## constater, pas de s'y casser — même clause que LaborForce.has().
func has(fighter: StringName) -> bool:
	return _by_id.has(fighter)

## Combattant nommé. Précondition : has(fighter).
func unit(fighter: StringName) -> CombatUnit:
	assert(has(fighter), "combattant inconnu de la force : %s" % fighter)
	return _by_id[fighter]

## Rang de ce combattant. Précondition : has(fighter).
func efficiency(fighter: StringName) -> float:
	return unit(fighter).efficiency()

## Ce que ce combattant vaut sur le plateau. Précondition : has(fighter).
##
## Un raccourci sur unit(fighter).stats(), et il a le même appelant que efficiency() a du
## côté du déploiement : le plateau, qui ouvre une manche en lisant les chiffres de ceux
## qu'on lui donne, et qui n'a aucune raison de traverser le CombatUnit pour ça.
func stats(fighter: StringName) -> CombatStats:
	return unit(fighter).stats()
