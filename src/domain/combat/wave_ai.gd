class_name WaveAI
extends RefCounted
## Ce que les assaillants annoncent, et ce qu'ils font ensuite.
##
## Fonctions pures, aucun état : le décideur est ici, l'état est dans `CombatBoard`, et
## l'écran ne fait que lire les deux. Le partage a une raison pratique autant que
## doctrinale — le harnais joue la vague à la main depuis `F3a`, et un plateau qui
## déciderait tout seul le lui interdirait. C'est aussi ce qui laisse rejouer le **même**
## plateau des deux façons, ce qui est le banc d'essai que `F3a` a rendu possible en passant
## devant ce jalon.
##
## **Une seule ligne d'IA**, et `DESIGN.md` 3.6 la donne en toutes lettres : « Ils visent les
## ouvriers à portée, les bâtiments sinon. » Elle n'est pas là pour faire un adversaire
## malin, elle est là pour tuer la stratégie dominante la plus bête du format : sur une carte
## de 32×32 très majoritairement vide, fuir en rond serait autrement gratuit. Ici fuir est un
## **troc** — on garde ses gens, ils mangent les murs.
##
## Le vocabulaire d'annonce est celui de `CombatIntent`, et sa règle tient en une phrase :
## *un corps annonce une case exactement quand il peut frapper sans bouger*. Ce fichier en
## est l'application, et il n'y a donc **aucun cas par type d'assaillant** : un tireur posté
## et un corps-à-corps déjà collé annoncent de la même façon, parce que ce qui décide est la
## situation et non la fiche.
##
## Ce qu'il ne fait pas, et c'est délibéré : aucune coordination entre assaillants, aucune
## feinte, aucun repli. Trois corps qui appliquent la même règle chacun de leur côté
## produisent déjà de l'encerclement et du blocage de porte, ce que `F2a` a livré sans le
## chercher. Une IA qui *manœuvre* est un jeu entier, et 3.6 refuse le même genre de dérive
## pour les capacités.
##
## Il ne connaît **pas** la vague : ni composition, ni borne de tours. Ce sont des questions
## de `WaveDef` et de plateau. Lui ne sait que ce qu'un corps voit d'où il est.

## Depuis cette case, ce corps frapperait un défenseur.
const ON_A_BODY := 0

## Depuis cette case, il frapperait un mur — mais personne.
const ON_A_WALL := 1

## Depuis cette case, il ne frappe rien.
const NO_TARGET := 2

## Distance rendue quand il n'y a plus rien à convoiter sur le plateau.
##
## Un très grand nombre plutôt qu'une sentinelle négative : il ne sert qu'à comparer des
## distances entre elles, et toutes les cases se valent alors — ce qui est exactement la
## réponse voulue, un corps qui n'a plus de proie ne se déplace pas.
const NO_PREY := 1 << 30

# --- annoncer ---------------------------------------------------------------------------

## Ce que chaque assaillant debout annonce pour son prochain tour.
##
## Pure : elle rend une table sans toucher au plateau, ce dont les cas de test se servent
## pour lire une annonce sans la jouer. `declare()` juste en dessous est celle qui écrit.
##
## Elle se prend sur le plateau **tel que le joueur va le trouver**, donc avant qu'il joue.
## C'est ce qui rend l'esquive possible : ce qui est annoncé l'a été contre des positions
## que le joueur peut encore changer.
static func announce(board: CombatBoard) -> Dictionary[StringName, CombatIntent]:
	assert(board != null, "annonce sans plateau")
	var table: Dictionary[StringName, CombatIntent] = {}
	for piece in board.standing(Combatant.Side.FOE):
		var target := prey_from(board, piece, piece.cell())
		table[piece.id()] = (CombatIntent.advance() if target == CombatIntent.NO_CELL
			else CombatIntent.strike(target))
	return table

## Annonce, et l'écrit sur le plateau.
##
## À appeler une fois à l'ouverture, après avoir fait entrer la vague — sans quoi le premier
## tour du joueur se jouerait devant des assaillants muets. `take_turn()` s'en charge pour
## tous les suivants.
static func declare(board: CombatBoard) -> void:
	board.announce(announce(board))

# --- jouer ------------------------------------------------------------------------------

## Joue le tour entier de la vague, rend la main aux ouvriers, et annonce le tour suivant.
##
## **Une seule porte, parce que l'ordre compte et qu'aucun appelant ne doit avoir à s'en
## souvenir.** `CLAUDE.md` en a fait une règle à `E2` : ce que deux écrans doivent se
## rappeler, un troisième l'oubliera. Le harnais et l'orchestrateur de `F3b` appellent donc
## la même ligne.
##
## L'ordre lui-même n'est pas indifférent — la manche se ferme **entre** l'exécution et
## l'annonce suivante, parce que c'est à cette fermeture que le butin se compte et que la
## borne avance. Annoncer avant reviendrait à décrire un plateau d'une manche en retard.
static func take_turn(board: CombatBoard) -> Array[StrikeResult]:
	var blows := play(board)
	board.end_turn()
	declare(board)
	return blows

## Exécute ce que chaque assaillant avait annoncé, sans fermer le tour.
##
## Séparée de `take_turn()` pour que les cas de test puissent regarder le plateau **entre**
## l'exécution et la fermeture, qui est le seul moment où l'on voit ce qu'une manche a fait
## sans que la suivante ait déjà commencé.
##
## Les corps jouent dans l'ordre d'entrée, ce qui est le seul ordre déterministe dont on
## dispose — et il compte : un pillard qui avance libère ou barre une case pour celui qui
## joue après lui.
static func play(board: CombatBoard) -> Array[StrikeResult]:
	assert(board != null, "tour de vague sans plateau")
	assert(board.side() == Combatant.Side.FOE,
		"la vague joue pendant le tour des ouvriers")
	var blows: Array[StrikeResult] = []
	for piece in board.standing(Combatant.Side.FOE):
		var blow := _act(board, piece)
		if blow == null:
			continue
		blows.append(blow)
	return blows

# --- la seule règle ---------------------------------------------------------------------

## Ce que ce corps frapperait depuis cette case : un défenseur d'abord, un mur sinon.
##
## **C'est la ligne d'IA de `DESIGN.md` 3.6, et elle n'est écrite qu'ici.** Elle sert trois
## fois — pour annoncer, pour noter une case où aller, et pour frapper après s'être déplacé
## — et trois copies auraient fini par promettre autre chose que ce qu'elles font, ce qui est
## l'argument qui a mis `CombatBoard.strikeable()` dans le domaine à `F3a`.
##
## Elle rend une **case** et non une cible, ce qui est la lettre de 3.6 : un coup vise une
## case, et ce qui s'y trouve à l'exécution encaisse — fût-ce un autre assaillant.
##
## Les deux départages ne sont pas les mêmes, et chacun a sa raison. Entre deux **corps**
## également proches, l'ordre d'entrée tranche, ce que `CombatBoard.standing()` promet depuis
## `F2a` : c'est l'ordre du déploiement, donc une chose que le joueur a décidée. Entre deux
## **murs**, c'est l'ancre, donc un ordre indépendant de la pose — deux villages identiques
## bâtis dans un ordre différent doivent perdre la même chose, ce que 3.3 exige déjà de
## l'écrêtage.
static func prey_from(board: CombatBoard, piece: Combatant, from: Vector2i) -> Vector2i:
	assert(board != null, "cible cherchée sans plateau")
	assert(not piece.is_friend(), "la ligne d'IA de 3.6 est celle de la vague")
	var quarry := _closest_body(board, piece, from)
	if quarry != CombatIntent.NO_CELL:
		return quarry
	return _closest_wall(board, piece, from)

# --- privé ------------------------------------------------------------------------------

## Le tour d'un corps, et ce qu'il a frappé s'il a frappé.
##
## **Une annonce engage.** Un corps qui avait annoncé une case ne bouge pas et frappe cette
## case, qu'il y ait encore quelqu'un dessus ou non : c'est ce qui donne à l'esquive de 3.6
## sa valeur, et c'est aussi ce qui la fait payer — un coup annoncé qui part dans le vide est
## un tour d'assaillant perdu.
##
## Un corps qui n'avait annoncé qu'une avance se déplace puis frappe ce qu'il trouve, ce que
## 3.6 autorise en toutes lettres : « un tour où l'on déplace les ouvriers déployés et où
## chacun agit ». La cible se prend **après** le pas, donc contre le plateau réel — c'est ce
## qui fait que le blocage cesse d'être un cas à traiter.
static func _act(board: CombatBoard, piece: Combatant) -> StrikeResult:
	if piece.is_down():
		return null
	var intent := board.intent_of(piece.id())
	if intent.is_bound():
		return board.strike(piece.id(), intent.cell())
	var step := _best_step(board, piece)
	if step != piece.cell():
		board.move(piece.id(), step)
	var target := prey_from(board, piece, piece.cell())
	if target == CombatIntent.NO_CELL:
		return null
	return board.strike(piece.id(), target)

## Où ce corps va, ce tour-ci.
##
## Trois rangs, dans cet ordre : une case d'où il frappe un défenseur, une case d'où il
## frappe un mur, une case qui le rapproche. Le second est ce qui rend la fuite coûteuse, le
## troisième ce qui l'empêche de tourner en rond sur une carte vide.
##
## À rang égal, c'est le **pas le moins cher** qui gagne, et non le plus proche de la proie.
## La nuance décide du comportement d'un tireur : préférer se rapprocher le collerait à sa
## cible, alors que sa portée est précisément ce qui lui permet de se poster. Un
## corps-à-corps, lui, n'a de toute façon aucune case à portée qui ne soit adjacente.
##
## Au rang le plus bas, où rien n'est à portée d'où qu'il aille, c'est la distance à la proie
## la plus proche qui décide — corps et murs confondus, les corps l'emportant à égalité.
## Aucune des deux ne se choisit à ce stade : ce qu'il vise sera décidé en arrivant.
static func _best_step(board: CombatBoard, piece: Combatant) -> Vector2i:
	var within := board.reachable(piece.id())
	var order: Array[Vector2i] = []
	for cell in within:
		order.append(cell)
	order.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var lead := _rank_of(board, piece, first)
		var trail := _rank_of(board, piece, second)
		if lead != trail:
			return lead < trail
		if lead == NO_TARGET:
			var near := _gap_to_prey(board, piece, first)
			var far := _gap_to_prey(board, piece, second)
			if near != far:
				return near < far
		if within[first] != within[second]:
			return within[first] < within[second]
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	return order[0]

## Ce que ce corps atteindrait depuis cette case, du meilleur au pire.
static func _rank_of(board: CombatBoard, piece: Combatant, from: Vector2i) -> int:
	if _closest_body(board, piece, from) != CombatIntent.NO_CELL:
		return ON_A_BODY
	if _closest_wall(board, piece, from) != CombatIntent.NO_CELL:
		return ON_A_WALL
	return NO_TARGET

## Distance à la proie la plus proche, portée mise à part.
##
## Elle ignore la portée exprès : c'est l'aiguille qui sert quand **rien** n'est à portée, et
## elle n'a alors qu'un travail — dire de quel côté est le village.
static func _gap_to_prey(board: CombatBoard, piece: Combatant, from: Vector2i) -> int:
	var gap := NO_PREY
	for other in board.standing(Combatant.Side.FRIEND):
		gap = mini(gap, _span(from, other.cell()))
	if gap < NO_PREY:
		return gap
	for cell in _wall_cells(board):
		gap = mini(gap, _span(from, cell))
	return gap

## Le corps adverse debout le plus proche que ce corps frapperait d'ici, ou `NO_CELL`.
static func _closest_body(board: CombatBoard, piece: Combatant,
		from: Vector2i) -> Vector2i:
	var found := CombatIntent.NO_CELL
	var closest := NO_PREY
	for other in board.standing(Combatant.Side.FRIEND):
		if not piece.stats().can_reach(from, other.cell()):
			continue
		var span := _span(from, other.cell())
		if span >= closest:
			continue
		found = other.cell()
		closest = span
	return found

## La case bâtie la plus proche que ce corps frapperait d'ici, ou `NO_CELL`.
static func _closest_wall(board: CombatBoard, piece: Combatant,
		from: Vector2i) -> Vector2i:
	var found := CombatIntent.NO_CELL
	var closest := NO_PREY
	for cell in _wall_cells(board):
		if not piece.stats().can_reach(from, cell):
			continue
		var span := _span(from, cell)
		if span > closest:
			continue
		if span == closest and not _before(cell, found):
			continue
		found = cell
		closest = span
	return found

## Les cases des bâtiments encore debout.
##
## Les chantiers y sont, par la règle qui vaut depuis `C4` : ils occupent leurs cellules et
## se font casser, et `DESIGN.md` 3.2 tient à ce qu'« un chantier à moitié fini détruit la
## veille de la vague » soit une perte qui se raconte.
static func _wall_cells(board: CombatBoard) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for building in board.city().buildings():
		if board.is_wrecked(building.anchor()):
			continue
		cells.append_array(building.cells())
	return cells

## Cette case passe-t-elle avant l'autre ? Par ligne, puis par colonne.
static func _before(cell: Vector2i, other: Vector2i) -> bool:
	if other == CombatIntent.NO_CELL:
		return true
	if cell.y != other.y:
		return cell.y < other.y
	return cell.x < other.x

## Distance de Manhattan, comme la portée et comme le déplacement orthogonal.
static func _span(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)
