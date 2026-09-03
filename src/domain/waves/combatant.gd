class_name Combatant
extends RefCounted
## Un corps qui marche vers le Cœur : où il en est, ce qu'il lui reste, et ce qu'il est.
##
## État **mutable**, interne au plateau de combat, comme `PlacedBuilding` l'est de la ville.
## Personne d'autre ne le tient : ce qui sort de la bataille est un rapport, pas des corps.
##
## ---
##
## **Aucun flottant, et c'est la règle qui rend tout le reste possible.** `DESIGN.md` 3.5 :
## « un corps est *sur la case X, avec un compteur de progression vers la suivante*. La grille
## reste la source de vérité, et la fraction n'est qu'une indication de rendu. » Le corps porte
## donc un **index sur son chemin** et un **compteur de ticks**, tous deux entiers.
##
## Ce que ça achète : une bataille se rejoue à l'identique, se met en pause, s'accélère et se
## saute sans qu'un point de vie change — et `V3` interpolera entre deux états pour obtenir du
## mouvement continu, sans que le domaine sache qu'un écran existe.

## Ce qu'il est : ses points de vie de départ, sa lenteur, ses dégâts.
var _def: EnemyDef

## Le chemin qu'il suit, calculé pour **son** espèce. Deux sortes d'assaillants n'empruntent pas
## forcément le même, puisque leur patience et leur enjambée diffèrent.
var _path: WavePath

## Où il en est sur ce chemin. -1 tant qu'il n'est pas entré.
var _step: int = -1

## Ticks accumulés vers la case suivante. Remis à zéro à chaque pas.
var _progress: int = 0

## Ticks à attendre avant d'entrer. C'est l'espacement de la vague qui les distribue.
var _delay: int = 0

## Ce qu'il lui reste à encaisser.
var _life: int = 0

## Corps prêt à entrer dans `delay` ticks.
static func create(def: EnemyDef, path: WavePath, delay: int) -> Combatant:
	assert(def != null, "corps sans espèce")
	assert(path != null, "corps sans chemin")
	assert(delay >= 0, "délai d'entrée négatif : %d" % delay)
	var body := Combatant.new()
	body._def = def
	body._path = path
	body._delay = delay
	body._life = def.hit_points
	return body

## Ce qu'il est.
func def() -> EnemyDef:
	return _def

## Ce qu'il lui reste à encaisser. 0 = mort.
func life() -> int:
	return _life

## Est-il mort ?
func is_dead() -> bool:
	return _life <= 0

## A-t-il atteint le bout de son chemin ?
##
## Distinct de « mort » et distinct de « en marche » : un corps arrivé cesse d'être une cible et
## cesse d'avancer, mais ce qu'il fait au Cœur est l'affaire du plateau.
func has_arrived() -> bool:
	return _step >= _path.length() - 1

## Est-il entré sur la carte ?
##
## Un corps qui attend son tour n'est **ni visible ni ciblable** : le laisser à portée d'une
## tour dès le premier tick ferait tirer sur un ennemi qui n'existe pas encore, et une vague
## espacée de vingt ticks se ferait décimer avant d'arriver.
func is_marching() -> bool:
	return _step >= 0

## La case qu'il occupe. Précondition : il est entré.
##
## La case et non une position : c'est elle que le chemin, le blocage et la portée interrogent.
## `progress()` ne sert qu'à un écran qui interpole.
func cell() -> Vector2i:
	assert(is_marching(), "case d'un corps qui n'est pas entré")
	return _path.cells()[_step]

## Ticks accumulés vers la case suivante, de 0 à `def().ticks_per_cell - 1`.
##
## **La seule chose de ce fichier qui ne serve pas au domaine.** `V3` s'en servira pour placer
## un corps entre deux cases ; la bataille, elle, n'en a jamais besoin.
func progress() -> int:
	return _progress

## Combien de cases il a franchies. Sert au ciblage : la cible est le plus **avancé** à portée.
func advance() -> int:
	return _step

## Lui retire ces points de vie, et rend ce qu'il a réellement encaissé.
##
## Rend l'encaissé plutôt que rien, parce qu'un rapport de bataille veut des dégâts infligés et
## non des dégâts tentés. Frapper un mort n'inflige rien — mais ce cas ne devrait pas arriver :
## `DESIGN.md` 3.5 veut qu'un projectile dont la cible meurt en vol soit **perdu**.
func take(points: int) -> int:
	assert(points >= 0, "dégâts négatifs : %d" % points)
	var dealt := mini(points, _life)
	_life -= dealt
	return dealt

## Avance d'un tick. Rend vrai s'il a changé de case.
##
## Trois états successifs et pas un de plus : il attend, il marche, il est arrivé. L'ordre des
## tests compte — un corps qui entre au tick où son délai s'épuise ne doit pas avancer dans le
## même tick, sans quoi l'espacement d'une vague vaudrait une case de moins qu'annoncé.
func step() -> bool:
	if is_dead() or has_arrived():
		return false
	if not is_marching():
		_delay -= 1
		if _delay > 0:
			return false
		_step = 0
		return true
	_progress += 1
	if _progress < _def.ticks_per_cell:
		return false
	_progress = 0
	_step += 1
	return true
