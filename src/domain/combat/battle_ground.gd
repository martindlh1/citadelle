class_name BattleGround
extends RefCounted
## Où la vague entre, et où les défenseurs se postent.
##
## La géométrie d'une bataille, séparée du plateau parce que ce n'est pas la même question :
## `CombatBoard` sait ce qui se passe, ce fichier sait **où ça commence**. Fonctions pures.
##
## `DESIGN.md` 3.6 : « Le champ de bataille est le village, entier. Pas de recadrage ni
## d'arène. La contrepartie est que **la vague entre à la lisière du bâti et non au bord de
## la carte** — seize cases de marche avant le premier contact seraient quatre tours où
## personne ne décide rien. » Tout ce fichier est cette phrase.
##
## Le côté par lequel la vague arrive est un **argument**. D'où il vient — un champ du
## calendrier, un tirage sur le seed — appartient à `F3`, qui branchera la bataille sur le
## run ; 3.6 veut seulement qu'il soit connu des jours à l'avance, ce qui est une question
## de data et non de plateau.
##
## Le placement des défenseurs est un **bouchon utile**, exactement comme
## `InstantCombatResolver.deploy()` choisit *qui* depuis `F1` : « la règle automatique lui
## survivra comme bouton par défaut ». L'écran qui laisse poser ses hommes est `F3`.

## Les quatre côtés possibles, dans un ordre figé.
##
## Par quarts de tour comme la caméra et comme l'orientation d'un bâtiment : c'est le même
## vocabulaire dans tout le projet, et une vague qui arriverait en diagonale n'aurait pas de
## lisière à longer.
const SIDES: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## Rectangle englobant tout ce qui est bâti, chantiers compris.
##
## Chantiers compris parce qu'ils occupent leurs cellules depuis `C4` et qu'ils se font
## casser : un village dont la moitié est en travaux est un village, et faire entrer la
## vague à la lisière du seul bâti **fini** la ferait apparaître au milieu des chantiers.
##
## Précondition : la ville n'est pas vide. Une lisière n'existe pas sans bâti, et un run en
## a toujours un — le Cœur est posé à la fondation. Une ville vide est légitime ailleurs,
## d'où l'assert plutôt qu'un rectangle nul qui se propagerait en silence.
static func built_area(city: CitySnapshot) -> Rect2i:
	assert(city != null, "lisière demandée sans ville")
	assert(city.count() > 0, "lisière d'un village sans un seul bâtiment")
	var low := Vector2i.MAX
	var high := Vector2i.MIN
	for building in city.buildings():
		for cell in building.cells():
			low = low.min(cell)
			high = high.max(cell)
	return Rect2i(low, high - low + Vector2i.ONE)

## Les cases par lesquelles la vague entre, au plus `count`.
##
## Elles sont cherchées sur la ligne à `spawn_margin` cases de la lisière, du **centre vers
## les bords** pour qu'une vague arrive groupée plutôt qu'étalée sur toute la largeur de la
## carte. Si cette ligne n'offre pas assez de place — un lac, une falaise, un bord de carte
## —, la recherche s'éloigne d'une case et recommence.
##
## Elle peut rendre **moins** que demandé, et c'est une réponse et non un échec : un village
## acculé dans un coin n'a pas de place pour une vague entière de ce côté-là. C'est à
## l'appelant de dire ce qu'il en fait, et `F2b` le dira.
static func entry_cells(board: CombatBoard, from_side: Vector2i,
		count: int) -> Array[Vector2i]:
	assert(board != null, "entrée de vague sans plateau")
	assert(SIDES.has(from_side), "côté d'arrivée qui n'est pas un quart de tour : %s"
		% from_side)
	assert(count >= 0, "vague de %d assaillants" % count)
	var depths: Array[int] = []
	var reach: int = board.terrain().size().x + board.terrain().size().y
	for depth in range(board.balance().spawn_margin, reach):
		depths.append(depth)
	return _gather(board, from_side, depths, count)

## Les cases où les défenseurs se postent, au plus `count`.
##
## Devant le village et du côté menacé : la ligne de la lisière d'abord — c'est-à-dire les
## trous entre les bâtiments, puisqu'une case bâtie ne se tient pas —, puis vers la vague,
## puis vers l'intérieur si le village est trop serré.
##
## L'ordre a une conséquence de jeu qu'il faut assumer : les défenseurs commencent **au
## contact des murs** plutôt qu'en avant. C'est le placement qui fait le mieux jouer la
## règle de 3.6 — « ils visent les ouvriers à portée, les bâtiments sinon » —, puisqu'il met
## les corps là où ils protègent quelque chose.
static func landing_cells(board: CombatBoard, from_side: Vector2i,
		count: int) -> Array[Vector2i]:
	assert(board != null, "déploiement sans plateau")
	assert(SIDES.has(from_side), "côté d'arrivée qui n'est pas un quart de tour : %s"
		% from_side)
	assert(count >= 0, "déploiement de %d hommes" % count)
	var depths: Array[int] = []
	for depth in board.balance().spawn_margin:
		depths.append(depth)
	var inward: int = board.terrain().size().x + board.terrain().size().y
	for step in range(1, inward):
		depths.append(-step)
	return _gather(board, from_side, depths, count)

## Récolte des cases libres en parcourant ces profondeurs dans l'ordre.
static func _gather(board: CombatBoard, from_side: Vector2i, depths: Array[int],
		count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if count <= 0:
		return found
	var area := built_area(board.city())
	for depth in depths:
		for cell in _line(board, area, from_side, depth):
			if not board.can_stand(cell):
				continue
			found.append(cell)
			if found.size() >= count:
				return found
	return found

## La ligne à cette profondeur du côté donné, ordonnée du centre du bâti vers les bords.
##
## Elle balaie **toute** la carte sur l'axe perpendiculaire et non la seule largeur du
## village : un village de trois cases de large n'offrirait sinon que trois entrées, ce qui
## ferait tenir une vague par un couloir que personne n'a bâti. L'ordre centre-sortant rend
## la largeur du bâti à ce qu'elle doit être — une préférence, pas une borne.
static func _line(board: CombatBoard, area: Rect2i, from_side: Vector2i,
		depth: int) -> Array[Vector2i]:
	var extent := board.terrain().size()
	var cells: Array[Vector2i] = []
	if from_side.x != 0:
		var column := area.position.x if from_side.x < 0 else area.end.x - 1
		column += from_side.x * depth
		for row in _centre_out(extent.y, (area.position.y + area.end.y) / 2):
			cells.append(Vector2i(column, row))
		return cells
	var line := area.position.y if from_side.y < 0 else area.end.y - 1
	line += from_side.y * depth
	for column in _centre_out(extent.x, (area.position.x + area.end.x) / 2):
		cells.append(Vector2i(column, line))
	return cells

## Les indices de `0` à `span - 1`, du plus proche de `middle` au plus lointain.
##
## À distance égale, le plus petit d'abord. C'est ce départage qui rend deux batailles du
## même seed identiques jusque dans la case où chaque pillard entre.
static func _centre_out(span: int, middle: int) -> Array[int]:
	var order: Array[int] = []
	for index in span:
		order.append(index)
	order.sort_custom(func(first: int, second: int) -> bool:
		var near := absi(first - middle)
		var far := absi(second - middle)
		if near != far:
			return near < far
		return first < second)
	return order
