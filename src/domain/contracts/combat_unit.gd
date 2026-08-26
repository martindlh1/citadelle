class_name CombatUnit
extends RefCounted
## Un ouvrier, tel que le Combat le voit : un nom et un multiplicateur.
##
## Le pendant de LaborUnit pour l'autre projection des Effectifs, et W1 avait raison de
## refuser de l'écrire à l'aveugle : « ou bien un clone strict de LaborForce qui ne
## prouve rien, ou bien une devinette sur des PV et de l'équipement ». Ce n'est ni l'un
## ni l'autre, et l'écart tient en un mot — **un** multiplicateur, pas un par famille.
##
## DESIGN.md 3.4 liste le Combat comme **une** famille parmi les autres. Un ouvrier rend
## différemment au camp de bûcheron et à l'atelier, donc LaborUnit doit répondre par
## métier ; il ne se bat que d'une seule façon, donc la question « dans quelle famille ? »
## ne se pose pas ici. Ce qui aurait fait le clone est précisément ce qui a disparu.
##
## Ce qu'il ne porte pas : ni PV, ni équipement, ni blessure. Le format de combat est
## OUVERT en 3.6 et c'est F2 qui le tranchera ; ce contrat lui laisse la place d'ajouter
## ce dont il aura besoin, plutôt que de deviner aujourd'hui de quoi il s'agira. Ni le
## niveau ni l'XP non plus, pour la raison qui vaut déjà côté Économie : la projection
## est exactement l'endroit où le consommateur cesse de savoir.
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

## Combattant nommé, avec son multiplicateur.
static func create(id: StringName, efficiency: float) -> CombatUnit:
	assert(not id.is_empty(), "combattant sans identifiant")
	assert(efficiency >= 0.0, "multiplicateur de combat négatif pour %s : %f"
		% [id, efficiency])
	var unit := CombatUnit.new()
	unit._id = id
	unit._efficiency = efficiency
	return unit

## Combattant sans aucune piste de combat entamée.
static func novice(id: StringName) -> CombatUnit:
	return CombatUnit.create(id, BASE_EFFICIENCY)

## Identifiant stable. C'est par lui qu'un déploiement l'engage et qu'un rapport le
## compte parmi les pertes.
func id() -> StringName:
	return _id

## Multiplicateur de combat.
func efficiency() -> float:
	return _efficiency
