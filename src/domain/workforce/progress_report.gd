class_name ProgressReport
extends RefCounted
## Ce qu'un soir a fait progresser : qui a gagné quoi, et qui a franchi un palier.
##
## Produit par SkillResolver, consommé par les adapters — la fiche et le panneau de W2.
## Il reste dans domain/workforce/ et **n'entre pas dans contracts/**, comme PickResult
## est resté dans domain/terrain/ : aucun second système du domaine ne le franchit, et
## la table des DTO de CLAUDE.md ne le liste pas. Inventer une frontière que personne ne
## traverse la figerait avant qu'on sache sa forme.
##
## Il ne dit pas qui a chômé : ProductionReport.idle() le dit déjà, et le recopier
## laisserait deux listes diverger sur ce qui est la même soirée.
##
## Immuable.

var _gains: Array[SkillGain] = []

## Rapport d'un soir. Appelé une seule fois, en fin de distribution.
static func create(gains: Array[SkillGain]) -> ProgressReport:
	var report := ProgressReport.new()
	report._gains = gains.duplicate()
	return report

## Rapport d'un soir où personne n'a travaillé.
static func empty() -> ProgressReport:
	var none: Array[SkillGain] = []
	return ProgressReport.create(none)

## Tous les gains, dans l'ordre du journal de travail. Copie.
func gains() -> Array[SkillGain]:
	return _gains.duplicate()

## Personne n'a rien gagné ce soir ?
func is_empty() -> bool:
	return _gains.is_empty()

## XP totale distribuée. Comptée une fois : le même montant est allé aux deux axes, et
## la doubler ici ferait croire à deux fois plus de travail qu'il n'y en a eu.
func total_xp() -> int:
	var total := 0
	for gain in _gains:
		total += gain.xp()
	return total

## Les seuls gains qui ont fait franchir un palier de piste. Copie.
func skill_level_ups() -> Array[SkillGain]:
	var crossed: Array[SkillGain] = []
	for gain in _gains:
		if gain.is_skill_level_up():
			crossed.append(gain)
	return crossed

## Les seuls gains qui ont fait franchir un palier de niveau d'ouvrier. Copie.
##
## Séparé des paliers de piste parce que les deux ne s'annoncent pas de la même façon :
## une piste qui monte change un rendement, un niveau qui monte ouvrira un choix à X5.
func worker_level_ups() -> Array[SkillGain]:
	var crossed: Array[SkillGain] = []
	for gain in _gains:
		if gain.is_worker_level_up():
			crossed.append(gain)
	return crossed
