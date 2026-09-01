extends Node
## Possède l'état du run courant et publie les résultats du domaine sur EventBus.
##
## Unique pont domaine -> adapters : aucun autre Node n'appelle le domaine, et le domaine
## ne connaît ni ce fichier ni EventBus.
##
## Ce qu'il fait, et c'est tout : il **traduit**. Un appel d'adapter devient un appel
## d'orchestrateur, et un résultat de domaine devient un signal. Il ne décide de rien —
## pas une règle, pas un chiffre, pas un ordre de résolution. Les quatre portes de geste
## ci-dessous ne contiennent pas un seul `if` : elles délèguent et rendent la réponse telle
## quelle, ce qui est le seul moyen de garantir que l'écran et l'état ne divergent pas.
##
## ---
##
## **`I3` le remplit pour la troisième fois de sa vie** — `I0` l'avait écrit en coquille,
## `I1` l'avait rempli, `R0` l'avait revidé. Il compte quatre gestes là où il en avait
## quinze, et l'écart n'est pas un manque : jouer une carte, la cibler, affecter un ouvrier,
## le rappeler, auto-affecter, franchir une phase, fermer une journée et mener une bataille
## appartiennent tous à des systèmes que le rescope a supprimés.
##
## Ce qui reste est la liste de `DESIGN.md` 4.2 moins ce qui n'est pas écrit : fonder,
## bâtir, démolir, passer le tour. Terrasser arrive à `C5`, réparer à `C6`, et ni l'un ni
## l'autre ne demandera à ce fichier autre chose qu'une ligne de plus.
##
## **Il tient le catalogue de bâtiments**, et c'est sa seule vraie tâche au-delà de la
## traduction. `GameDatabase` est un autoload que le domaine ne lit jamais ; quelqu'un doit
## donc lui passer les `BuildingData` en argument, et cet endroit est le pont.

## Le run courant, ou null hors run.
var _state: RunState = null

## Un run est-il ouvert ?
##
## Il existe depuis `I0` et les vues le gardent : `DESIGN.md` 6.2 s'appuie dessus pour
## l'entre-deux-runs du menu, qui est le premier morceau du projet à vivre hors d'un run.
func is_running() -> bool:
	return _state != null

## Le run courant, ou null. C'est par lui que l'UI lit la ville, la réserve et la population.
func state() -> RunState:
	return _state

## Ouvre un run sur ce seed et ce relief, et le rend.
##
## Le catalogue est monté ici, à partir de l'index du boot : c'est la traduction que ce
## fichier existe pour faire. Le relief arrive **de l'appelant** plutôt que d'être généré
## ici — `TerrainGen` prend un seed et des paramètres, et le harnais qui l'affiche a déjà
## la grille sous la main.
func open(run_seed: int, grid: HeightGrid) -> RunState:
	_state = RunState.open(run_seed, grid, _catalogue(), GameDatabase.get_balance())
	return _state

## Referme le run courant sans rien en publier.
func close() -> void:
	_state = null

## Pose le Cœur sur cette cellule.
func found(cell: Vector2i, turns := 0) -> PlayResult:
	assert(is_running(), "fondation hors run")
	return RunOrchestrator.found(_state, cell, turns)

## Ouvre un chantier pour ce bâtiment sur cette cellule.
func build(id: StringName, cell: Vector2i, turns := 0) -> PlayResult:
	assert(is_running(), "chantier ouvert hors run")
	return RunOrchestrator.open_site(_state, id, cell, turns)

## Démolit ce qui occupe cette cellule.
func demolish(cell: Vector2i) -> PlayResult:
	assert(is_running(), "démolition hors run")
	return RunOrchestrator.demolish(_state, cell)

## Passe le tour, publie ce qu'il a rendu, et le rend aussi.
##
## Les deux, et ce n'est pas une redondance : le signal sert aux vues qui n'ont pas déclenché
## le geste, le retour sert à celle qui l'a déclenché et qui doit enchaîner tout de suite.
##
## **Le rapport est publié avant d'être rendu**, ce qui compte pour l'ordre des lignes chez
## l'appelant : ce qu'un auditeur fait du signal s'exécute **à l'intérieur** de cet appel.
## `P2b` a payé cette leçon en refermant un bilan après une porte qui rouvrait la vue
## suivante ; la règle qui en sort est que ce qu'on range avant un appel appartient à ce qui
## précède, et ce qu'on ouvre après à ce qui suit.
##
## Elle assert au lieu de refuser, comme `RunOrchestrator.end_turn()` et pour la même
## raison : les deux seuls refus possibles se lisent sur le run avant l'appel.
func end_turn() -> TurnReport:
	assert(is_running(), "tour passé hors run")
	var report := RunOrchestrator.end_turn(_state)
	EventBus.turn_resolved.emit(report)
	return report

## Tous les bâtiments indexés au boot, par identifiant.
func _catalogue() -> Dictionary[StringName, BuildingData]:
	var buildings: Dictionary[StringName, BuildingData] = {}
	for id in GameDatabase.list_building_ids():
		var data := GameDatabase.get_building(id)
		if data != null:
			buildings[id] = data
	return buildings
