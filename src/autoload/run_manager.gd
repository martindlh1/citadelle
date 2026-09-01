extends Node
## Possède l'état du run courant et publie les résultats du domaine sur EventBus.
##
## Unique pont domaine -> adapters : aucun autre Node n'appelle le domaine, et le domaine
## ne connaît ni ce fichier ni EventBus.
##
## Ce qu'il fait, et c'est tout : il **traduit**. Un appel d'adapter devient un appel
## d'orchestrateur, et un résultat de domaine devient un signal. Il ne décide de rien —
## pas une règle, pas un chiffre, pas un ordre de résolution.
##
## ---
##
## **`R0` l'a ramené à une coquille**, et c'est la seconde fois de sa vie : `I0` l'avait
## écrit ainsi, `I1` l'avait rempli, le rescope le revide. Tout ce qu'il traduisait —
## jouer une carte, affecter un ouvrier, finir une phase, mener une bataille — appartient
## à des systèmes qui n'existent plus.
##
## Il reste un fichier plutôt que de disparaître pour une raison mécanique et non de
## design : `project.godot` le déclare comme autoload, et ce fichier appartient à l'humain
## *(cf. `CLAUDE.md`)*. Un autoload dont le script manque casse le boot.
##
## `I3` le remplit à nouveau, avec un tour au lieu d'une journée en phases. La coquille
## garde donc exactement ce qu'`I0` lui donnait : un état possédé, et de quoi dire s'il y
## en a un.

## Le run courant, ou null hors run. Le type reviendra avec `RunState`, que `I3` réécrit.
var _state: Object = null

## Un run est-il ouvert ?
##
## Il existe depuis `I0` et les vues le gardent : `DESIGN.md` 6.2 s'appuie dessus pour
## l'entre-deux-runs du menu, qui est le premier morceau du projet à vivre hors d'un run.
func is_running() -> bool:
	return _state != null

## Le run courant, ou null. C'est par lui que l'UI lira la ville et la réserve.
func state() -> Object:
	return _state

## Referme le run courant sans rien en publier.
##
## `R0` n'a plus de `RunOutcome` à porter — le signal `run_ended` est sorti d'`EventBus`
## avec les autres. `I3` rendra à cette porte ce qu'elle annonçait.
func close() -> void:
	_state = null
