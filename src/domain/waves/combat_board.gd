class_name CombatBoard
extends RefCounted
## La bataille, avancée par pas discrets : les corps marchent, les défenses tirent, les
## projectiles voyagent, ce qui tombe à zéro meurt.
##
## État mutable interne aux Vagues, comme `CityState` l'est de la Construction. Il ne mute
## **jamais** la ville ni la réserve : ce qui sort d'ici est un `BattleReport`, et c'est
## l'orchestrateur qui l'appliquera à `V4`. Un plateau qui retirerait un bâtiment serait la
## faute d'architecture que ce projet refuse en premier.
##
## ---
##
## **Un tick, quatre choses, toujours dans cet ordre**, et c'est celui que `DESIGN.md` 3.5
## énumère :
##
##     · chaque corps avance de sa vitesse le long de son chemin
##     · chaque défense décrémente son cooldown ; à zéro, elle tire → un projectile naît
##     · chaque projectile avance ; à l'arrivée, il inflige ses dégâts
##     · ce qui tombe à zéro meurt
##
## L'ordre n'est pas indifférent. Bouger avant de viser fait qu'une défense tire sur la case où
## le corps **est**, jamais sur celle qu'il vient de quitter ; résoudre les projectiles après
## les tirs donne à un projectile au moins un tick de vol, donc une cadence qui se ressent au
## lieu d'un dégât instantané.
##
## **Tout en entiers, donc déterministe.** Aucun flottant, aucun `randf()`, aucune horloge : le
## nombre de ticks est ce qui compte. C'est ce qui donne gratuitement la pause, la vitesse
## doublée, le saut de bataille et la chronique sans écran — `while not board.finished():
## board.tick()`.
##
## **Et rien n'attend le joueur.** Une bataille ne s'interrompt jamais pour une entrée, donc il
## n'y a ni état d'attente, ni seconde porte, ni bataille à reprendre. C'était la seule chose
## qui rendait nécessaire la coupure de l'ancien jeu, et elle ne revient pas.

## Ticks qu'un projectile met à parcourir une case.
##
## Une constante d'ici et non un champ de data, et c'est le seul chiffre du plateau dans ce cas.
## Ce que `DESIGN.md` 3.5 met en data est le **vocabulaire de défense** — portée, dégâts,
## cadence —, et la vitesse d'un trait n'en fait pas partie : elle ne distingue aucune défense
## de l'autre, elle donne seulement au surkill le temps de se produire. Le jour où une baliste
## voudra des traits plus lents qu'une tour, c'est un champ de `DefenceBlock`.
const PROJECTILE_TICKS_PER_CELL := 2

## Plafond de ticks avant qu'une bataille soit déclarée bloquée.
##
## **Un garde-fou et non une règle de jeu.** Une bataille finit d'elle-même : les corps meurent
## ou arrivent. Mais un `run_to_end()` sur un plateau qu'un bug aurait figé tournerait sans fin,
## et un harnais headless n'a personne pour l'interrompre — c'est la leçon du `assert` qui
## n'atteignait jamais son repli à `T4`, transposée à une boucle. Le plafond est large : la plus
## longue traversée imaginable d'une carte de trente-deux cases, au pas le plus lent, tient très
## en dessous.
const TICK_CEILING := 20000

var _terrain: TerrainQuery
var _city: CitySnapshot
var _balance: WaveBalance

## Les cases du Cœur, celles qui terminent un chemin.
var _heart: Dictionary[Vector2i, bool] = {}

var _bodies: Array[Combatant] = []

## Une défense en attente de tir : son ancre, son bloc, et ce qu'il lui reste à patienter.
var _guns: Array[Dictionary] = []

## Un trait en vol : sa cible, ses dégâts, et ce qu'il lui reste à voler.
var _shots: Array[Dictionary] = []

var _ticks: int = 0
var _killed: int = 0
var _fired: int = 0
var _arrived: int = 0
var _heart_damage: int = 0
var _damaged: Dictionary[Vector2i, int] = {}

## Plateau prêt à jouer : les corps ont leur chemin, les défenses leur cadence.
##
## Le chemin est calculé **une fois par espèce** et partagé par tous les corps qui la composent :
## il ne dépend que de la carte, de la ville et de la créature, dont aucun ne bouge pendant la
## bataille. Un chemin par corps aurait été le même calcul dix fois, et surtout dix occasions de
## diverger le jour où l'un d'eux perce un mur.
##
## Les corps entrent **espacés** : `WaveDef.spacing` distribue leurs délais. Sans ça, dix corps
## arriveraient sur la même case au même instant et une cadence de tir ne voudrait plus rien
## dire — or c'est la moitié du vocabulaire de défense.
static func open(terrain: TerrainQuery, city: CitySnapshot, heart: Vector2i, wave: WaveDef,
		balance: WaveBalance) -> CombatBoard:
	assert(terrain != null, "bataille sans terrain")
	assert(city != null, "bataille sans ville")
	assert(wave != null, "bataille sans vague")
	assert(balance != null, "bataille sans équilibrage")
	assert(wave.missing_fields().is_empty(),
		"vague inexploitable : %s" % ", ".join(wave.missing_fields()))

	var board := CombatBoard.new()
	board._terrain = terrain
	board._city = city
	board._balance = balance

	var target := city.at_cell(heart)
	if target == null:
		board._heart[heart] = true
	else:
		for cell in target.cells():
			board._heart[cell] = true

	var path := WavePathfinder.find(terrain, city, heart, wave.entry_cells(terrain.size()),
		balance, wave.enemy)
	for index in wave.count:
		# Le premier entre au premier tick, les suivants un espacement plus tard chacun.
		board._bodies.append(Combatant.create(wave.enemy, path, 1 + index * wave.spacing))

	for building in city.completed():
		if building.data().defence == null:
			continue
		board._guns.append({
			&"anchor": building.anchor(),
			&"cells": building.cells(),
			&"defence": building.data().defence,
			&"cooldown": 1,
		})
	return board

## Tout est-il joué ?
##
## Vrai quand plus aucun corps ne marche **et** qu'aucun trait n'est en vol : un projectile
## encore en l'air peut tuer, donc déclarer la fin avant lui perdrait un dégât et rendrait le
## rapport faux d'un point de vie.
##
## Le plafond de ticks y entre aussi, et c'est un garde-fou : une bataille figée doit finir en
## le disant plutôt que de tourner sans fin dans un harnais headless.
func finished() -> bool:
	if _ticks >= TICK_CEILING:
		return true
	if not _shots.is_empty():
		return false
	for body in _bodies:
		if not body.is_dead() and not body.has_arrived():
			return false
	return true

## Ticks écoulés.
func ticks() -> int:
	return _ticks

## Les corps, dans l'ordre de leur entrée. Copie du tableau ; les corps eux-mêmes sont l'état
## interne du plateau, et `V3` les lira pour dessiner.
func bodies() -> Array[Combatant]:
	return _bodies.duplicate()

## Combien de traits sont en vol. Sert au harnais et à `V3` ; la bataille n'en a pas besoin.
func shots_in_flight() -> int:
	return _shots.size()

## Avance d'un pas.
##
## Ne fait rien sur un plateau fini : appeler `tick()` de trop est le cas normal d'une boucle
## d'affichage qui tourne pendant qu'on regarde le résultat, pas une faute d'appelant.
func tick() -> void:
	if finished():
		return
	_ticks += 1
	_march()
	_aim()
	_fly()

## Joue la bataille jusqu'au bout et rend le rapport.
##
## C'est la même boucle que celle d'un écran, sans écran — donc la garantie que mesurer une
## bataille et la regarder donnent le **même** résultat au point de vie près.
func run_to_end() -> BattleReport:
	while not finished():
		tick()
	return report()

## Ce que la bataille a fait, à cet instant.
##
## Appelable en cours de route : un harnais qui imprime une chronique tick par tick veut le
## rapport partiel, et rien ici ne dépend de la fin.
func report() -> BattleReport:
	return BattleReport.create(_ticks, _killed, _arrived, _heart_damage, _damaged, _fired)

# --- les quatre temps d'un tick ----------------------------------------------

## Chaque corps avance, perce ce qu'il traverse, et frappe le Cœur s'il l'atteint.
##
## Les dégâts au bâti se paient **au moment où le corps entre** sur la case, une fois : un corps
## qui reste deux ticks sur une case de palissade ne la frappe pas deux fois. C'est ce que
## `step()` rend en disant s'il a changé de case.
func _march() -> void:
	for body in _bodies:
		if body.is_dead() or body.has_arrived():
			continue
		if not body.step():
			continue
		if not body.is_marching():
			continue
		if body.has_arrived():
			_heart_damage += body.def().damage
			_arrived += 1
			continue
		_bite(body)

## Ce que ce corps casse sur la case où il vient d'entrer.
##
## Le Cœur en est exclu : c'est l'arrivée, et ses dégâts se comptent une fois, sur la jauge du
## run. Compter les deux ferait payer le Cœur deux fois pour le même corps.
func _bite(body: Combatant) -> void:
	var cell := body.cell()
	if _heart.has(cell):
		return
	var building := _city.at_cell(cell)
	if building == null:
		return
	var anchor := building.anchor()
	_damaged[anchor] = _damaged.get(anchor, 0) + body.def().damage

## Chaque défense décrémente son cooldown ; à zéro, elle tire.
##
## **La cible est l'ennemi à portée le plus avancé sur son chemin**, et `DESIGN.md` 3.5 insiste :
## « une ligne de code, la même pour tous ». Pas de priorité réglable, pas de ciblage par type,
## pas de concentration de feu — ce sont autant de chiffres qu'on n'aura pas à équilibrer.
##
## Une défense sans cible **ne consomme pas** sa cadence : elle reste chargée. C'est ce qui fait
## qu'une tour posée sur un col tire au premier corps qui s'y présente, au lieu d'avoir gaspillé
## son tir sur le vide juste avant.
func _aim() -> void:
	for gun in _guns:
		var target := _best_target(gun[&"cells"], gun[&"defence"])
		if target == null:
			continue
		gun[&"cooldown"] = gun[&"cooldown"] - 1
		if gun[&"cooldown"] > 0:
			continue
		gun[&"cooldown"] = gun[&"defence"].cadence
		_fired += 1
		_shots.append({
			&"target": target,
			&"damage": gun[&"defence"].damage,
			&"flight": _flight_ticks(gun[&"cells"], target.cell()),
		})

## Le corps à portée le plus avancé sur son chemin, ou null.
##
## La portée se mesure depuis **n'importe quelle case** du bâtiment, comme l'adjacence et
## l'emprise le font depuis l'empreinte : une tour de deux cases voit d'un peu plus loin par son
## bout avancé, ce qui est ce qu'on attend d'un bâtiment large.
func _best_target(cells: Array[Vector2i], defence: DefenceBlock) -> Combatant:
	var found: Combatant = null
	for body in _bodies:
		if body.is_dead() or body.has_arrived() or not body.is_marching():
			continue
		if found != null and body.advance() <= found.advance():
			continue
		if not _within(cells, defence, body.cell()):
			continue
		found = body
	return found

## Cette case est-elle à portée d'une de ces cases ?
static func _within(cells: Array[Vector2i], defence: DefenceBlock, cell: Vector2i) -> bool:
	for from in cells:
		if defence.covers(from, cell):
			return true
	return false

## Ticks de vol jusqu'à cette case, depuis la plus proche de ces cases-là.
static func _flight_ticks(cells: Array[Vector2i], target: Vector2i) -> int:
	var nearest := -1
	for from in cells:
		var span := absi(from.x - target.x) + absi(from.y - target.y)
		if nearest < 0 or span < nearest:
			nearest = span
	# Au moins un tick, même à bout portant : un dégât instantané rendrait la cadence
	# illisible et supprimerait le surkill que 3.5 veut punir.
	return maxi(1, nearest * PROJECTILE_TICKS_PER_CELL)

## Chaque projectile avance ; à l'arrivée, il inflige ses dégâts.
##
## **Un projectile dont la cible meurt en vol est perdu**, et c'est une règle de `DESIGN.md` 3.5
## plutôt qu'un effet de bord : « ça punit le surkill, ça rend la cadence lisible, et c'est une
## règle de moins ». Deux tours qui tirent ensemble sur le même corps en gaspillent une.
##
## Un corps arrivé cesse aussi d'être touchable : le trait qui le visait tombe dans le vide
## derrière lui.
func _fly() -> void:
	var still_flying: Array[Dictionary] = []
	for shot in _shots:
		shot[&"flight"] = shot[&"flight"] - 1
		if shot[&"flight"] > 0:
			still_flying.append(shot)
			continue
		var target: Combatant = shot[&"target"]
		if target.is_dead() or target.has_arrived():
			continue
		target.take(shot[&"damage"])
		if target.is_dead():
			_killed += 1
	_shots = still_flying
