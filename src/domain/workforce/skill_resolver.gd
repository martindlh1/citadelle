class_name SkillResolver
extends RefCounted
## La distribution d'XP d'un soir : ce que le journal de travail vaut aux ouvriers.
##
## Point d'entrée du système Effectifs, exactement comme ProductionResolver l'est de
## l'Économie, et de même profil — il mute le Roster et rend un rapport. Le roster est
## l'état **interne** des Effectifs, ce qui est précisément pourquoi il ne figure dans
## aucune ligne de contrat.
##
## Il ferme la boucle que E1 avait laissée ouverte. Le ProductionReport porte un journal
## de travail — qui a tenu quel poste, dans quelle famille — et ne calcule aucune XP,
## parce que combien vaut une soirée est un chiffre des Effectifs. C'est ce chiffre-là
## qui s'applique ici, et la famille figure dans la ligne pour qu'on n'ait pas à rouvrir
## la ville pour retrouver le bâtiment.
##
## Ce qu'il ne fait pas : aucune conséquence de famine — le compte des non-nourris est
## dans le rapport de production et son sort reste OUVERT en DESIGN.md 3.3 —, et aucune
## XP de combat, qui viendra du DamageReport à F1 et passera par le même gain().

## Distribue l'XP d'un soir de travail et rend ce qui a bougé.
##
## Une ligne du journal vaut xp_per_shift, quel que soit ce que le poste a rapporté.
## L'XP se gagne **à l'usage** : l'indexer sur la récolte ferait composer le bon ouvrier
## avec lui-même, et deux soirs suffiraient à faire diverger la courbe.
##
## Chaque ligne est créditée et rapportée séparément plutôt que regroupée par ouvrier.
## Aujourd'hui les deux reviennent au même — une Assignment envoie un ouvrier à une
## seule ancre, donc il tient au plus un poste par soir —, mais rien ici n'en dépend :
## deux lignes du même ouvrier cumuleraient correctement, et leurs paliers seraient
## rapportés dans l'ordre où ils ont été franchis.
##
## Un ouvrier que le journal nomme mais que le roster ignore est sauté sans un mot.
## C'est le miroir exact de ProductionResolver._work_lines() et pour la même raison :
## une affectation peut avoir survécu à celui qui la portait, et un mort ne progresse
## pas. Un absent, lui, n'apparaît pas au journal : la projection ne l'a pas montré.
static func award(roster: Roster, report: ProductionReport,
		balance: WorkforceBalance) -> ProgressReport:
	assert(roster != null, "distribution d'XP sans roster")
	assert(report != null, "distribution d'XP sans rapport de production")
	assert(balance != null, "distribution d'XP sans équilibrage")
	assert(balance.xp_per_shift > 0,
		"XP par poste non renseignée : %d" % balance.xp_per_shift)

	var gains: Array[SkillGain] = []
	for line in report.work():
		if not roster.has(line.worker()):
			continue
		gains.append(_award_one(roster.worker(line.worker()), line.family(), balance))
	return ProgressReport.create(gains)

## Crédite un ouvrier pour un poste tenu, et rend ce que ça lui a fait.
##
## Les quatre paliers sont relevés autour du seul gain(), et non recalculés depuis l'XP :
## la règle des deux axes vit dans Worker.gain(), et la recopier ici pour prédire son
## effet ouvrirait la porte à ce que les deux divergent.
static func _award_one(worker: Worker, family: StringName,
		balance: WorkforceBalance) -> SkillGain:
	var skill_before := worker.skill_level(family, balance)
	var level_before := worker.level(balance)
	worker.gain(family, balance.xp_per_shift)
	return SkillGain.create(worker.id(), family, balance.xp_per_shift,
		skill_before, worker.skill_level(family, balance),
		level_before, worker.level(balance))
