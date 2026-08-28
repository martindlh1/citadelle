class_name CombatBoard
extends RefCounted
## La bataille en cours : les corps, ce que la ville a pris, et à qui c'est le tour.
##
## **C'est un état, et c'est tout le sujet de `F2`.** `DESIGN.md` 3.6 a corrigé une promesse
## que le document portait depuis toujours — « on échange l'implémentation dans
## l'orchestrateur : une ligne » — parce qu'elle est fausse pour un format au tour par tour.
## Un résolveur rend un rapport ; un combat tactique **attend le joueur**, pendant des
## dizaines de gestes, et le domaine n'a pas le droit d'`await`. Le producteur cesse donc
## d'être une fonction pour devenir ce fichier : un plateau mutable, des gestes qui
## s'appliquent un à un, et un `DamageReport` au bout — que `F2b` composera.
##
## Il **ne mute que lui-même**. Ni la ville, ni le roster, ni la réserve : il reçoit un
## `CitySnapshot` figé et tient à part ce que les coups y ont fait. C'est ce qui laisse
## l'applicateur de `RunOrchestrator.fight()` intact, comme `F1` l'avait livré sans le
## chercher, et ce qui rend une bataille rejouable — deux plateaux ouverts pareils et joués
## pareil finissent pareils.
##
## **L'aléatoire y entre par la porte que `CLAUDE.md` impose** : un `RandomNumberGenerator`
## fourni, jamais `randf()`. C'est celui de `RunState` quand la bataille sera branchée, un
## seedé au harnais et aux tests. Un seed plus une suite de gestes rejoue donc une bataille
## à l'identique, ce que le déterminisme du projet exige depuis `I0`.
##
## Ce qu'il **ne fait pas**, et c'est `F2b` : les intentions ennemies, l'IA qui les décide,
## la borne de tours, le départ de la vague et le rapport. Ce qu'il ne fera **jamais** :
## des capacités — `X5` — et des états — `X6`.

## Le tour en cours appartient à ce camp.
var _side: Combatant.Side = Combatant.Side.FRIEND

## Manche en cours, à partir de 1. Une manche est un tour par camp.
var _round: int = 1

var _terrain: TerrainQuery
var _city: CitySnapshot
var _balance: CombatBalance
var _rng: RandomNumberGenerator

## Corps, dans l'ordre où ils sont entrés sur le plateau. Les tombés y restent.
var _bodies: Array[Combatant] = []

## Identifiant -> corps.
var _by_id: Dictionary[StringName, Combatant] = {}

## Ancre -> points encaissés depuis l'ouverture de cette bataille.
##
## Tenus ici et non sur le `CitySnapshot`, qui est immuable par contrat : ce que la
## bataille casse n'existe que pour elle jusqu'à ce que le rapport soit appliqué. C'est
## aussi ce qui permet de rejouer une manche sans avoir abîmé la ville.
var _taken: Dictionary[Vector2i, int] = {}

## Ancres des bâtiments tombés, dans l'ordre où ils sont tombés.
var _wrecked: Array[Vector2i] = []

## Ouvriers tombés, dans l'ordre où ils sont tombés.
var _fallen: Array[StringName] = []

## Plateau vide, prêt à recevoir des corps.
##
## Il s'ouvre nu et se remplit par `deploy()` et `send()` plutôt que de tout recevoir d'un
## coup, sur le patron de `RunState.open()` suivi des poses : le déploiement est un
## **geste** que `DESIGN.md` 3.6 promet au joueur, et un plateau qui exigerait la liste
## complète à l'ouverture obligerait l'écran de `F3` à la constituer avant de pouvoir
## montrer quoi que ce soit.
static func open(terrain: TerrainQuery, city: CitySnapshot, balance: CombatBalance,
		rng: RandomNumberGenerator) -> CombatBoard:
	assert(terrain != null, "plateau sans relief")
	assert(city != null, "plateau sans ville")
	assert(balance != null, "plateau sans équilibrage")
	assert(rng != null, "plateau sans générateur — voir CLAUDE.md, déterminisme")
	var board := CombatBoard.new()
	board._terrain = terrain
	board._city = city
	board._balance = balance
	board._rng = rng
	return board

# --- mise en place ---------------------------------------------------------------------

## Un corps peut-il se tenir là ?
##
## Publique et posée **avant** les deux poses ci-dessous, sur le patron de
## `PlacementValidator` : on demande, puis on pose. Un écran promène un curseur et la
## plupart des cases lui sont refusées ; lui faire découvrir le refus par un `assert` serait
## lui interdire de dessiner.
func can_stand(cell: Vector2i) -> bool:
	return CombatMovement.is_open(_terrain, obstacles(), cell, _balance)

## Engage un ouvrier sur cette case. Précondition : `can_stand(cell)`.
##
## Elle prend un `CombatUnit` et non des chiffres nus : c'est la projection des Effectifs
## qui dit ce que cet homme vaut, et le plateau ne recalcule rien.
func deploy(unit: CombatUnit, cell: Vector2i) -> void:
	assert(unit != null, "déploiement d'un combattant nul")
	assert(can_stand(cell), "ouvrier déployé sur une case occupée ou barrée : %s" % cell)
	_enter(Combatant.create(unit.id(), Combatant.Side.FRIEND, cell, unit.stats()))

## Fait entrer un assaillant sur cette case. Précondition : `can_stand(cell)`.
##
## L'identifiant est **donné** et non tiré de l'`EnemyData` : une vague porte trois pillards
## et il faut pouvoir les distinguer. Le nommer ici plutôt que de compter les homonymes dans
## le plateau garde la nomenclature chez l'appelant, qui est le seul à savoir ce qu'il
## composera.
func send(id: StringName, enemy: EnemyData, cell: Vector2i) -> void:
	assert(enemy != null, "entrée d'un assaillant nul")
	assert(can_stand(cell), "assaillant posé sur une case occupée ou barrée : %s" % cell)
	_enter(Combatant.create(id, Combatant.Side.FOE, cell, enemy.to_stats()))

# --- lecture ---------------------------------------------------------------------------

## Le relief sur lequel la bataille se joue.
func terrain() -> TerrainQuery:
	return _terrain

## La ville telle qu'elle était à l'ouverture. Ce que les coups lui ont fait est à part.
func city() -> CitySnapshot:
	return _city

## Les réglages sous lesquels cette bataille se joue.
##
## Lus par la géométrie de BattleGround, qui a besoin de la marge d'entrée et des tags
## infranchissables sans avoir à se les faire passer à côté d'un plateau qui les porte déjà.
func balance() -> CombatBalance:
	return _balance

## Manche en cours, à partir de 1.
func round_number() -> int:
	return _round

## Camp dont c'est le tour.
func side() -> Combatant.Side:
	return _side

## Ce corps est-il sur le plateau ? Vrai même s'il est tombé.
func has_body(id: StringName) -> bool:
	return _by_id.has(id)

## Corps nommé. Précondition : `has_body(id)`.
func body(id: StringName) -> Combatant:
	assert(has_body(id), "corps inconnu du plateau : %s" % id)
	return _by_id[id]

## Tous les corps, tombés compris, dans l'ordre d'entrée. Copie.
func bodies() -> Array[Combatant]:
	return _bodies.duplicate()

## Les corps encore debout de ce camp, dans l'ordre d'entrée.
##
## L'ordre compte : c'est lui qui départage deux cibles également proches pour l'IA de
## `F2b`, donc lui qui garantit que deux runs du même seed voient les mêmes gens tomber.
func standing(camp: Combatant.Side) -> Array[Combatant]:
	var upright: Array[Combatant] = []
	for piece in _bodies:
		if piece.is_down() or piece.side() != camp:
			continue
		upright.append(piece)
	return upright

## Corps debout sur cette case, ou null.
##
## Null plutôt qu'un `assert`, comme `CitySnapshot.at_cell()` : la plupart des cases sont
## vides, et « rien ici » est une réponse et non une faute d'appelant.
func body_at(cell: Vector2i) -> Combatant:
	for piece in _bodies:
		if piece.is_down() or piece.cell() != cell:
			continue
		return piece
	return null

## Toutes les cases qu'aucun corps ne peut traverser : les bâtiments **encore debout** et
## les corps **encore debout**.
##
## Les deux sont fondus, et c'est ce que `CombatMovement` attend : un mur, un chantier et un
## pillard barrent de la même façon. Un chantier barre comme un bâtiment fini, par la règle
## qui vaut depuis `C4` — il a payé ses cellules à la pose.
##
## Recalculée à chaque appel plutôt que tenue à jour. Sur une poignée de corps et quelques
## dizaines de cellules bâties, l'économie serait invisible et le risque de désynchronisation
## réel : un index qui oublie de retirer un mort barre une case pour le reste de la manche,
## et rien ne le dirait.
func obstacles() -> Dictionary[Vector2i, bool]:
	var barred: Dictionary[Vector2i, bool] = {}
	for building in _city.buildings():
		if is_wrecked(building.anchor()):
			continue
		for cell in building.cells():
			barred[cell] = true
	for piece in _bodies:
		if piece.is_down():
			continue
		barred[piece.cell()] = true
	return barred

## Les cases où ce corps peut aller, et ce que chacune lui coûte.
## Précondition : `has_body(id)`.
func reachable(id: StringName) -> Dictionary[Vector2i, int]:
	var piece := body(id)
	return CombatMovement.reachable(_terrain, obstacles(), piece.cell(), piece.stats(),
		_balance)

## Ce bâtiment est-il tombé pendant cette bataille ?
func is_wrecked(anchor: Vector2i) -> bool:
	if not _taken.has(anchor):
		return false
	var building := _city.at_anchor(anchor)
	if building == null:
		return true
	return _taken[anchor] >= building.hit_points_left()

## Ancre -> points encaissés pendant cette bataille. Copie.
##
## Le journal complet des coups, tombés compris : c'est exactement la table que
## `DamageReport` attend, dans l'ordre où la vague a frappé.
func damage_taken() -> Dictionary[Vector2i, int]:
	return _taken.duplicate()

## Ancres des bâtiments tombés, dans l'ordre où ils sont tombés. Copie.
func wrecked() -> Array[Vector2i]:
	return _wrecked.duplicate()

## Ancres des seuls **chantiers** tombés, dans le même ordre. Copie.
##
## Un sous-ensemble strict de `wrecked()`, séparé pour la raison de récit que `DESIGN.md`
## 3.2 donne : « un chantier à moitié fini détruit la veille de la vague, c'est le genre de
## perte qui se raconte ». Le recouper après coup demanderait la ville d'avant, que plus
## personne ne tient une fois les ordres appliqués.
func interrupted() -> Array[Vector2i]:
	var sites: Array[Vector2i] = []
	for anchor in _wrecked:
		var building := _city.at_anchor(anchor)
		if building == null or building.is_complete():
			continue
		sites.append(anchor)
	return sites

## Ouvriers tombés, dans l'ordre où ils sont tombés. Copie.
##
## L'ordre est celui de la **chute** et non celui du déploiement, à l'inverse du bouchon de
## `F1` : ici les morts arrivent un à un et cet ordre est une information — qui est tombé en
## premier se raconte. Il reste parfaitement déterministe, ce qui est tout ce que le projet
## demande à un ordre.
func fallen() -> Array[StringName]:
	return _fallen.duplicate()

# --- les deux verbes -------------------------------------------------------------------

## Déplace ce corps sur cette case.
##
## Un déplacement par tour, borné par les points du profil et par le relief. Les trois
## refus de distance — trop loin, barré, derrière une marche trop haute — se confondent en
## un seul, parce qu'ils se confondent aussi pour qui joue.
func move(id: StringName, to: Vector2i) -> MoveResult:
	if not has_body(id):
		return MoveResult.refused(MoveResult.UNKNOWN_BODY)
	var piece := body(id)
	if piece.is_down():
		return MoveResult.refused(MoveResult.IS_DOWN)
	if piece.side() != _side:
		return MoveResult.refused(MoveResult.WRONG_SIDE)
	if piece.has_moved():
		return MoveResult.refused(MoveResult.ALREADY_MOVED)
	var within := reachable(id)
	if not within.has(to):
		return MoveResult.refused(MoveResult.OUT_OF_REACH)
	piece.place(to)
	piece.spend_move()
	return MoveResult.moved(within[to])

## Frappe cette case.
##
## **On vise une case, jamais une cible.** `DESIGN.md` 3.6 en fait la règle qui donne au
## déplacement sa valeur : esquiver annule le coup, et si un autre corps se trouve là au
## moment de l'exécution, c'est lui qui prend — ennemi compris. Rien ici ne demande donc à
## qui appartient ce qu'on frappe : le coup part sur une case et trouve ce qui s'y trouve.
##
## Un corps debout passe avant un bâtiment. Le cas ne se présente qu'après une ruine — un
## bâtiment debout barre sa case, donc personne n'y est —, et il fallait trancher : ce qui
## respire d'abord.
func strike(id: StringName, cell: Vector2i) -> StrikeResult:
	if not has_body(id):
		return StrikeResult.refused(StrikeResult.UNKNOWN_BODY)
	var piece := body(id)
	if piece.is_down():
		return StrikeResult.refused(StrikeResult.IS_DOWN)
	if piece.side() != _side:
		return StrikeResult.refused(StrikeResult.WRONG_SIDE)
	if piece.has_struck():
		return StrikeResult.refused(StrikeResult.ALREADY_STRUCK)
	if not _terrain.in_bounds(cell):
		return StrikeResult.refused(StrikeResult.OFF_MAP)
	if not piece.stats().can_reach(piece.cell(), cell):
		return StrikeResult.refused(StrikeResult.OUT_OF_RANGE)

	piece.spend_strike()
	var blow := _roll(piece.stats())
	var victim := body_at(cell)
	if victim != null:
		return _hit_body(cell, blow, victim)
	var building := _city.at_cell(cell)
	if building != null and not is_wrecked(building.anchor()):
		return _hit_building(cell, blow, building)
	return StrikeResult.into_the_void(cell)

## Passe la main au camp d'en face.
##
## Une **manche** est un tour par camp, donc le compteur avance quand la main revient aux
## ouvriers. C'est ce compteur que la borne de tours de `F2b` lira, et la seule chose que
## `F2a` ait à en savoir.
##
## Le camp qui prend la main retrouve ses gestes. Rafraîchir à l'entrée plutôt qu'à la
## sortie évite de rendre son tour à quelqu'un qui n'a pas encore joué le sien.
func end_turn() -> void:
	_side = (Combatant.Side.FOE if _side == Combatant.Side.FRIEND
		else Combatant.Side.FRIEND)
	if _side == Combatant.Side.FRIEND:
		_round += 1
	for piece in _bodies:
		if piece.side() != _side:
			continue
		piece.refresh()

# --- privé -----------------------------------------------------------------------------

## Pose un corps sur le plateau.
func _enter(piece: Combatant) -> void:
	assert(not _by_id.has(piece.id()), "deux corps nommés %s" % piece.id())
	_bodies.append(piece)
	_by_id[piece.id()] = piece

## Ce qu'un coup de ce corps porte, cette fois-ci.
##
## Le seul tirage du plateau, et il passe par le générateur qu'on lui a donné. Une
## fourchette dégénérée rend toujours le même chiffre, ce dont les cas de test se servent
## pour vérifier une règle sans que l'aléatoire s'en mêle.
func _roll(stats: CombatStats) -> int:
	return _rng.randi_range(stats.damage_min(), stats.damage_max())

## Applique un coup à un corps.
##
## Les points sont **écrêtés à ce qui restait**, et le résultat annonce l'écrêté. « Il lui
## restait 2, il a pris 7 » et « il lui restait 2, il a pris 2 » sont la même fin, et un
## rapport qui les distinguerait raconterait une graduation que ce jalon n'a pas. C'est
## aussi ce qui garde la même lecture des deux côtés — un bâtiment est écrêté pareil.
func _hit_body(cell: Vector2i, blow: int, victim: Combatant) -> StrikeResult:
	var dealt := mini(blow, victim.hit_points())
	if dealt <= 0:
		return StrikeResult.on_body(cell, 0, victim.id(), false)
	victim.take(dealt)
	if victim.is_down() and victim.is_friend():
		_fallen.append(victim.id())
	return StrikeResult.on_body(cell, dealt, victim.id(), victim.is_down())

## Applique un coup à un bâtiment, par son ancre.
##
## Une empreinte de quatre cases n'a qu'un jeu de points de vie : frapper un coin de la
## ferme, c'est frapper la ferme. C'est la même lecture que le ciblage d'une action depuis
## `D2`, et elle évite d'avoir à décider ce que « la moitié d'un mur » voudrait dire.
func _hit_building(cell: Vector2i, blow: int, building: BuildingSnapshot) -> StrikeResult:
	var anchor := building.anchor()
	var already: int = _taken.get(anchor, 0)
	var dealt := mini(blow, building.hit_points_left() - already)
	if dealt <= 0:
		return StrikeResult.on_building(cell, 0, anchor, false)
	_taken[anchor] = already + dealt
	var down := is_wrecked(anchor)
	if down:
		_wrecked.append(anchor)
	return StrikeResult.on_building(cell, dealt, anchor, down)
