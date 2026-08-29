class_name Combatant
extends RefCounted
## Un corps sur le plateau : où il est, ce qui lui reste, et ce qu'il a déjà fait ce tour.
##
## C'est l'état mutable du Combat, et il est à `domain/combat/` ce que `PlacedBuilding` est
## à la Construction : personne ne le voit du dehors. Ce qui traverse est le `DamageReport`
## que la manche rend au bout, et lui seul.
##
## **Un seul type pour les deux camps**, et c'est la moitié de ce que `CombatStats` achète.
## Le déplacement, la portée et les dégâts s'écrivent une fois ; ce qui sépare un ouvrier
## engagé d'un assaillant est le camp et la provenance de son profil, pas son
## comportement. Le jour où l'un fera quelque chose que l'autre ne sait pas faire, ce sera
## une capacité — donc `X5` — et non une seconde classe.
##
## **Il porte les points de vie de la manche et rien de durable.** `DESIGN.md` 3.6 : les PV
## sont la ressource d'une bataille, un ouvrier à zéro meurt, et ce qu'un survivant emporte
## est un effet progressif de `X6`. Rien ici ne se reporte donc au lendemain, et c'est
## pourquoi le `Worker` n'a pas eu à gagner un champ.
##
## Il ne porte **aucun état** — ni poison, ni étourdissement, ni saignement. `DESIGN.md`
## 3.6 est explicite : « `F2` ne doit pas en inventer un seul, il en inventerait quatre. »

## Camp d'un corps.
##
## Un `enum` et non un booléen `is_enemy`, par les conventions — et parce qu'un troisième
## camp est concevable, ne serait-ce qu'une bête neutre. Le plateau ne commute jamais
## dessus pour décider d'une **règle** : il ne s'en sert que pour dire qui vise qui.
enum Side { FRIEND, FOE }

var _id: StringName
var _side: Combatant.Side
var _cell: Vector2i
var _stats: CombatStats
var _hit_points: int
var _moved: bool = false
var _struck: bool = false

## Corps neuf, à plein, posé sur cette case.
static func create(id: StringName, side: Combatant.Side, cell: Vector2i,
		stats: CombatStats) -> Combatant:
	assert(not id.is_empty(), "corps sans identifiant")
	assert(stats != null, "corps %s sans profil" % id)
	var body := Combatant.new()
	body._id = id
	body._side = side
	body._cell = cell
	body._stats = stats
	body._hit_points = stats.hit_points()
	return body

## Identifiant stable. Pour un ouvrier engagé, c'est celui du roster — donc celui par
## lequel un rapport le compte parmi les pertes et lui crédite son XP.
func id() -> StringName:
	return _id

## Camp de ce corps.
func side() -> Combatant.Side:
	return _side

## Est-ce un ouvrier engagé ?
##
## Une question plutôt qu'un `side() == Side.FRIEND` recopié partout, sur le patron de
## `DamageReport.is_held()` : c'est la phrase que l'IA et les rapports diront, et elle se
## redéfinira ici le jour où un troisième camp existera.
func is_friend() -> bool:
	return _side == Side.FRIEND

## Case qu'il occupe.
func cell() -> Vector2i:
	return _cell

## Ce qu'il vaut sur le plateau.
func stats() -> CombatStats:
	return _stats

## Points de vie restants. Jamais négatifs.
func hit_points() -> int:
	return _hit_points

## Est-il tombé ?
##
## Zéro et non « moins de un » : `DESIGN.md` 3.6 pose qu'un ouvrier à zéro **meurt**, sans
## palier intermédiaire. C'est le choix le plus dur et il sert le pitch ; son revers — un
## combat qui n'a que deux issues, rien ou définitif — est nommé là-bas et confié à `X6`.
func is_down() -> bool:
	return _hit_points <= 0

## Lui retire des points. Précondition : un compte positif.
##
## Elle **borne à zéro** au lieu de laisser filer les négatifs : « il lui restait 2, il a
## pris 7 » et « il lui restait 2, il a pris 2 » sont la même fin, et un rapport qui les
## distinguerait raconterait une graduation que ce jalon n'a pas.
func take(points: int) -> void:
	assert(points > 0, "coup de %d point(s) sur %s" % [points, _id])
	_hit_points = maxi(0, _hit_points - points)

## Le déplace. Le plateau a déjà vérifié que la case est atteignable.
func place(cell: Vector2i) -> void:
	_cell = cell

## A-t-il déjà employé son déplacement ce tour ?
func has_moved() -> bool:
	return _moved

## A-t-il déjà frappé ce tour ?
func has_struck() -> bool:
	return _struck

## Consomme son déplacement du tour.
##
## **Un déplacement par tour, et non un budget qu'on dépense en plusieurs fois.** Le
## fractionner ferait de « bouger d'une case pour voir » un geste gratuit, et l'annulation
## de ce geste deviendrait un écran à écrire. Les points de `CombatStats.move()` bornent
## la **distance** d'un seul pas, pas le nombre de pas.
func spend_move() -> void:
	assert(not _moved, "%s se déplace deux fois dans le même tour" % _id)
	_moved = true

## Consomme son coup du tour.
func spend_strike() -> void:
	assert(not _struck, "%s frappe deux fois dans le même tour" % _id)
	_struck = true

## Lui rend son tour.
##
## Se déplacer **et** frapper dans le même tour, ce qui est la lettre de `DESIGN.md` 3.6 —
## « un tour où l'on déplace les ouvriers déployés et où chacun agit ». Les deux sont
## indépendants : on peut frapper puis reculer, ce qui est une décision tactique et non un
## effet de bord.
func refresh() -> void:
	_moved = false
	_struck = false
