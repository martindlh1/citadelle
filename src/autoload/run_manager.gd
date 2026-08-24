extends Node
## Possède l'état du run courant et publie les résultats du domaine sur EventBus.
##
## Unique pont domaine -> adapters : aucun autre Node n'appelle le domaine, et le
## domaine ne connaît ni ce fichier ni EventBus.
##
## I0 : coquille. Elle ne porte que le seed et le RNG, qui déménageront sur
## RunState à I1. DayCycle et la séquence de résolution arrivent avec.

var _rng: RandomNumberGenerator = null
var _run_seed: int = 0
var _is_running: bool = false

## Un run est-il ouvert ?
func is_running() -> bool:
	return _is_running

## Seed du run courant. Ce seed plus la même suite d'actions rejoue le run à l'identique.
func get_run_seed() -> int:
	return _run_seed

## RNG du run courant, ou null hors run. Tout l'aléatoire du jeu passe par lui.
func get_rng() -> RandomNumberGenerator:
	return _rng

## Ouvre un run sur ce seed.
func start_run(run_seed: int) -> void:
	assert(not _is_running, "un run est déjà ouvert")
	_run_seed = run_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = run_seed
	_is_running = true
	EventBus.run_started.emit(run_seed)

## Referme le run courant sur ce score.
func end_run(score: int) -> void:
	assert(_is_running, "aucun run n'est ouvert")
	_is_running = false
	_rng = null
	EventBus.run_ended.emit(score)
