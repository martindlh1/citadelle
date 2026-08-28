class_name CombatUnit
extends RefCounted
## Un ouvrier, tel que le Combat le voit : un nom, un rang, et ses chiffres.
##
## Le pendant de LaborUnit pour l'autre projection des Effectifs, et W1 avait raison de
## refuser de l'écrire à l'aveugle : « ou bien un clone strict de LaborForce qui ne
## prouve rien, ou bien une devinette sur des PV et de l'équipement ». Ce n'est ni l'un
## ni l'autre, et l'écart tient en un mot — **un** multiplicateur, pas un par famille.
##
## DESIGN.md 3.4 liste le Combat comme **une** famille parmi les autres. Un ouvrier rend
## différemment au camp de bûcheron et à l'atelier, donc LaborUnit doit répondre par
## métier ; il ne se bat que d'une seule façon, donc la question « dans quelle famille ? »
## ne se pose pas ici.
##
## **Les PV sont entrés à F2a, et ce docstring les annonçait.** Il disait : « Ce qu'il ne
## porte pas : ni PV, ni équipement, ni blessure. Le format de combat est OUVERT en 3.6 et
## c'est F2 qui le tranchera ; ce contrat lui laisse la place d'ajouter ce dont il aura
## besoin. » La place a servi, et l'échéance était la bonne — F1 aurait deviné.
##
## **Deux chiffres de nature différente, et il faut les distinguer pour lire ce fichier.**
## L'`efficiency` est un **rang** : elle dit à quel point cet ouvrier est aguerri, et c'est
## par elle qu'un déploiement classe. Le `CombatStats` porte ses **chiffres** : ce qu'il
## encaisse et ce qu'il porte. Les seconds dérivent aujourd'hui du premier — c'est la seule
## chose que la piste Combat sache faire —, et ils s'en détacheront le jour où un palier
## donnera des stats nommées ou où les PV se tireront à la création. Ce jour-là, **seule la
## projection change** : Worker.to_combat_unit(), un fichier, et le plateau ne bouge pas.
##
## C'est précisément pourquoi le contrat porte des chiffres résolus plutôt qu'un
## multiplicateur que le plateau aurait interprété. Un plateau qui multiplierait lui-même
## serait un plateau à rouvrir à chaque fois que la source d'un chiffre change.
##
## Ce qu'il ne porte toujours pas : ni équipement, ni blessure, ni état — X6 —, ni capacité
## — X5. Ni le niveau ni l'XP non plus, pour la raison qui vaut déjà côté Économie : la
## projection est exactement l'endroit où le consommateur cesse de savoir.
##
## Immuable.

## Multiplicateur d'un ouvrier qui n'a jamais combattu.
##
## Recopié de LaborUnit plutôt qu'importé, et pour la même raison que BuildingData
## recopie UNSET_COLOR : faire dépendre un contrat d'un autre pour une constante serait
## un couplage sans contrepartie, et il n'y a rien à gagner à ce que le Combat sache que
## l'Économie existe. Un cas de test épingle l'égalité des deux copies.
##
## 1.0 et non 0.0, avec ici un sens qui lui est propre : un paysan qui n'a jamais tenu
## une lance vaut quand même un corps sur la ligne. DESIGN.md 3.4 assume la limite —
## « si le combat devient très tactique, un paysan sans équipement y est peu utile » — et
## y répond par *S'entraîner*, pas en le comptant pour rien.
const BASE_EFFICIENCY := 1.0

var _id: StringName
var _efficiency: float
var _stats: CombatStats

## Combattant nommé, avec son rang et ses chiffres.
static func create(id: StringName, efficiency: float, stats: CombatStats) -> CombatUnit:
	assert(not id.is_empty(), "combattant sans identifiant")
	assert(efficiency >= 0.0, "multiplicateur de combat négatif pour %s : %f"
		% [id, efficiency])
	assert(stats != null, "combattant %s sans profil de combat" % id)
	var unit := CombatUnit.new()
	unit._id = id
	unit._efficiency = efficiency
	unit._stats = stats
	return unit

## Identifiant stable. C'est par lui qu'un déploiement l'engage et qu'un rapport le
## compte parmi les pertes.
func id() -> StringName:
	return _id

## Rang de ce combattant : à quel point il est aguerri.
##
## Elle ne se lit **pas** comme un chiffre de combat — ce que le corps encaisse et porte est
## dans stats(). Elle sert à classer, ce qui est une question que le déploiement pose et que
## le plateau ne pose jamais. Elle survivra donc au jour où les stats cesseront d'en dériver.
func efficiency() -> float:
	return _efficiency

## Ce que ce corps vaut sur le plateau.
func stats() -> CombatStats:
	return _stats
