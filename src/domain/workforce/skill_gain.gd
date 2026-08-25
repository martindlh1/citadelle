class_name SkillGain
extends RefCounted
## Ce qu'un ouvrier a gagné pour un poste tenu, et ce que ce gain lui a fait franchir.
##
## Une ligne par ligne de travail : le même montant crédite sa piste et son niveau — la
## règle des deux axes de DESIGN.md 3.4 —, donc les deux paliers se rapportent ensemble.
##
## Les niveaux d'avant et d'après y figurent tous les deux plutôt qu'un simple drapeau
## « a franchi ». Un franchissement de deux paliers d'un coup existe dès qu'un gain
## dépasse un seuil, et l'UI de W2 a besoin de savoir de combien pour l'annoncer.
##
## Immuable.

var _worker: StringName
var _family: StringName
var _xp: int
var _skill_level_before: int
var _skill_level_after: int
var _worker_level_before: int
var _worker_level_after: int

## Gain d'un ouvrier sur une soirée, dans cette famille.
static func create(worker: StringName, family: StringName, xp: int,
		skill_level_before: int, skill_level_after: int,
		worker_level_before: int, worker_level_after: int) -> SkillGain:
	assert(not worker.is_empty(), "gain sans ouvrier")
	assert(not family.is_empty(), "gain sans famille")
	assert(xp >= 0, "gain d'XP négatif : %d" % xp)
	assert(skill_level_after >= skill_level_before,
		"palier de piste en recul pour %s" % worker)
	assert(worker_level_after >= worker_level_before,
		"palier de niveau en recul pour %s" % worker)
	var gain := SkillGain.new()
	gain._worker = worker
	gain._family = family
	gain._xp = xp
	gain._skill_level_before = skill_level_before
	gain._skill_level_after = skill_level_after
	gain._worker_level_before = worker_level_before
	gain._worker_level_after = worker_level_after
	return gain

## Ouvrier crédité.
func worker() -> StringName:
	return _worker

## Famille de la piste créditée.
func family() -> StringName:
	return _family

## XP gagnée. Le même montant est allé à la piste et au niveau.
func xp() -> int:
	return _xp

## Palier de piste avant le gain.
func skill_level_before() -> int:
	return _skill_level_before

## Palier de piste après le gain.
func skill_level_after() -> int:
	return _skill_level_after

## Niveau d'ouvrier avant le gain.
func worker_level_before() -> int:
	return _worker_level_before

## Niveau d'ouvrier après le gain.
func worker_level_after() -> int:
	return _worker_level_after

## Ce gain a-t-il fait franchir un palier de piste ?
func is_skill_level_up() -> bool:
	return _skill_level_after > _skill_level_before

## Ce gain a-t-il fait franchir un palier de niveau d'ouvrier ?
func is_worker_level_up() -> bool:
	return _worker_level_after > _worker_level_before
