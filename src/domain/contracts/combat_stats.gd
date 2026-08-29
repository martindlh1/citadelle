class_name CombatStats
extends RefCounted
## Ce qu'un corps vaut sur le plateau : ce qu'il encaisse, ce qu'il porte, jusqu'où il
## atteint, jusqu'où il marche, et quelle marche il grimpe.
##
## **La même forme pour les deux camps**, et c'est toute sa raison d'être. Un ouvrier
## engagé tient ses chiffres d'une projection des Effectifs, un assaillant les tient de son
## `EnemyData` — mais le plateau ne peut pas se permettre de le savoir. Sans ce DTO, le
## déplacement, la portée et les dégâts s'écriraient deux fois, une par camp, et les deux
## copies finiraient par diverger sur ce que « grimper » veut dire.
##
## C'est la correction d'un défaut que `F1` portait sans le voir : `CombatBalance` décrivait
## *un* défenseur décliné en N exemplaires, pendant qu'`EnemyData` allait décrire des
## assaillants tous différents. Un camp spécifique contre un camp générique n'est pas un
## combat tactique, c'est une multiplication.
##
## **Il ne porte aucun état**, seulement un profil : les points de vie sont ici un maximum,
## et ce qu'il en reste appartient au `Combatant` que le plateau mute. C'est ce qui garde ce
## DTO immuable et partageable — deux ouvriers du même palier peuvent tenir le même profil
## sans que blesser l'un blesse l'autre.
##
## Ce qu'il ne porte pas non plus, et c'est délibéré : ni capacité — `X5` —, ni état, ni
## résistance — `X6`. `DESIGN.md` 3.6 est explicite : « `F2` ne doit pas en inventer un
## seul, il en inventerait quatre. »
##
## Immuable.

## Portée d'un corps-à-corps : la case d'à côté et rien de plus.
##
## Nommée plutôt qu'écrite en 1, parce que c'est elle qui sépare les deux natures d'attaque
## que `F2b` annoncera — au contact, on se déplace pour frapper ; à distance, on se poste.
## Un nombre nu à cet endroit serait le nombre magique que les conventions refusent.
const CONTACT := 1

var _hit_points: int
var _damage_min: int
var _damage_max: int
var _reach: int
var _move: int
var _climb: int

## Profil complet d'un corps.
##
## Les dégâts sont une **fourchette** et non un chiffre, et c'est une décision de design
## plutôt qu'une commodité : un combat entièrement déterministe se calcule au lieu de se
## jouer. Le tirage lui-même n'est pas ici — ce DTO décrit, il ne résout pas —, il
## appartient au plateau, qui seul tient le `RandomNumberGenerator` du run.
##
## Une fourchette dégénérée — `damage_min == damage_max` — reste légitime, et c'est ce
## qu'un cas de test emploie quand il veut vérifier une règle sans que l'aléatoire s'en
## mêle.
static func create(hit_points: int, damage_min: int, damage_max: int, reach: int,
		move: int, climb: int) -> CombatStats:
	assert(hit_points > 0, "profil de combat sans point de vie : %d" % hit_points)
	assert(damage_min >= 0, "dégâts minimaux négatifs : %d" % damage_min)
	assert(damage_max >= damage_min,
		"fourchette de dégâts inversée : %d..%d" % [damage_min, damage_max])
	assert(reach >= CONTACT, "portée inférieure au contact : %d" % reach)
	assert(move >= 0, "déplacement négatif : %d" % move)
	assert(climb >= 0, "hauteur de marche négative : %d" % climb)
	var stats := CombatStats.new()
	stats._hit_points = hit_points
	stats._damage_min = damage_min
	stats._damage_max = damage_max
	stats._reach = reach
	stats._move = move
	stats._climb = climb
	return stats

## Points de vie à plein.
##
## Ils sont la ressource **de la manche** et de rien d'autre : `DESIGN.md` 3.6 pose qu'un
## ouvrier à zéro meurt et que ce qu'un survivant emporte est un effet progressif de `X6`.
## Rien n'est donc reporté d'une bataille à la suivante, ce qui est aussi pourquoi ce
## chiffre n'a pas eu à monter sur le `Worker`.
func hit_points() -> int:
	return _hit_points

## Plancher des dégâts d'un coup.
func damage_min() -> int:
	return _damage_min

## Plafond des dégâts d'un coup.
func damage_max() -> int:
	return _damage_max

## Jusqu'où ce corps peut frapper, en cases. `CONTACT` pour un corps-à-corps.
func reach() -> int:
	return _reach

## Points de déplacement par tour.
##
## Zéro est légitime et n'est pas un oubli : un corps qui ne bouge pas est une pièce de
## siège, et le contrôle de `missing_fields()` d'`EnemyData` le laisse passer exprès.
func move() -> int:
	return _move

## Plus haute marche franchissable d'un seul pas, en crans de relief.
##
## `DESIGN.md` 3.6 : « monter coûte, une marche trop haute bloque ». C'est le second de
## ces deux effets, et il est **par corps** plutôt que global — ce qui laisse la place à
## un assaillant qui escalade là où personne d'autre ne passe, sans qu'une ligne du
## plateau ait à connaître son nom.
##
## Zéro veut dire « ne franchit aucune marche » : ce corps ne se déplace qu'à plat.
func climb() -> int:
	return _climb

## Un coup de ce corps peut-il porter jusque-là ?
##
## En distance de Manhattan, comme le déplacement est orthogonal : mélanger deux métriques
## sur la même grille produit des portées qu'on ne peut pas lire à l'œil.
##
## La question est ici et non dans le plateau parce que deux appelants la posent — celui
## qui frappe, et celui qui affiche les cases atteignables avant de frapper —, et deux
## copies d'une règle de portée finiraient par montrer autre chose que ce qu'elles font.
func can_reach(from: Vector2i, to: Vector2i) -> bool:
	return absi(to.x - from.x) + absi(to.y - from.y) <= _reach
