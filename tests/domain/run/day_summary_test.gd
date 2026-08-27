class_name DaySummaryTest
extends GdUnitTestSuite
## Le bilan d'une journée, composé de ce que ses phases ont rendu.
##
## Le cas qui porte le fichier est `test_it_counts_no_idle_worker`. Tous les autres
## vérifient une addition, ce qui est vite lu ; celui-là vérifie un **refus**, et un refus
## ne se relit nulle part. Un oisif est un état de phase — quelqu'un qui chôme le matin et
## travaille l'après-midi n'est pas un demi-oisif —, donc additionner deux ensembles de
## personnes rendrait un nombre qui ne désigne personne. Sans ce cas, le premier écran qui
## réclamerait « et les oisifs ? » l'obtiendrait.
##
## Aucun nom de phase n'est écrit ici, comme dans `DayCycleTest` et `RunBalanceTest` : les
## rapports fabriqués portent des identifiants inventés sur place.

const DUE := 6

func test_a_day_without_a_resolution_is_empty() -> void:
	var summary := _summary([])
	assert_int(summary.resolutions()).is_equal(0)
	assert_bool(summary.is_empty()).is_true()
	assert_dict(summary.produced()).is_empty()

## L'upkeep est dû même d'une journée entièrement chômée. C'est la séparation que
## `DESIGN.md` 2 tient depuis `I1` — une phase produit, une journée coûte —, et le bilan
## d'un matin qui commence doit déjà l'annoncer.
func test_an_empty_day_still_owes_its_upkeep() -> void:
	assert_int(_summary([]).upkeep_due()).is_equal(DUE)

func test_it_sums_what_the_phases_produced() -> void:
	var summary := _summary([
		_report({&"wood": 3, &"food": 1}, {&"wood": 3, &"food": 1}),
		_report({&"wood": 2, &"stone": 5}, {&"wood": 2, &"stone": 5})])
	assert_int(summary.resolutions()).is_equal(2)
	assert_int(summary.produced()[&"wood"]).is_equal(5)
	assert_int(summary.produced()[&"food"]).is_equal(1)
	assert_int(summary.produced()[&"stone"]).is_equal(5)
	assert_bool(summary.is_empty()).is_false()

## Ce qui déborde du plafond se somme aussi, et sur les deux phases : une réserve pleine le
## matin l'est encore l'après-midi, donc la perte d'une journée est la seule qui se lise.
func test_it_sums_what_the_ceiling_refused() -> void:
	var summary := _summary([
		_report({&"wood": 4}, {&"wood": 1}),
		_report({&"wood": 3}, {&"wood": 0})])
	assert_int(summary.stored()[&"wood"]).is_equal(1)
	assert_int(summary.wasted()[&"wood"]).is_equal(6)
	assert_int(summary.total_wasted()).is_equal(6)

## Une ressource qui n'a rien perdu n'entre pas dans l'écrêtage, comme sur le rapport de
## phase dont ce bilan hérite la forme : la table se lit alors comme la liste de ce qui a
## débordé, et non comme quatre lignes dont trois valent zéro.
func test_a_resource_that_lost_nothing_is_absent_from_the_waste() -> void:
	var summary := _summary([_report({&"wood": 2}, {&"wood": 2})])
	assert_dict(summary.wasted()).is_empty()
	assert_int(summary.total_wasted()).is_equal(0)

func test_it_gathers_the_sites_of_the_whole_day() -> void:
	var first := _report({}, {})
	first = _with_sites(first, {Vector2i(1, 1): 2}, {Vector2i(4, 4): 1}, [Vector2i(1, 1)])
	var second := _report({}, {})
	second = _with_sites(second, {Vector2i(2, 2): 1}, {}, [])
	var summary := _summary([first, second])
	assert_int(summary.advanced()).is_equal(3)
	assert_int(summary.shifted()).is_equal(1)
	assert_array(summary.completed()).contains([Vector2i(1, 1)])
	assert_array(summary.completed()).has_size(1)

func test_it_gathers_the_xp_and_the_landings_of_the_whole_day() -> void:
	var first := _with_progress(_report({}, {}), [_gain(&"ana", 4, 0, 1, 0, 0)])
	var second := _with_progress(_report({}, {}),
		[_gain(&"bo", 4, 0, 0, 0, 1), _gain(&"cy", 4, 1, 2, 0, 0)])
	var summary := _summary([first, second])
	assert_int(summary.total_xp()).is_equal(12)
	assert_array(summary.skill_level_ups()).has_size(2)
	assert_array(summary.worker_level_ups()).has_size(1)

## Les postes tenus s'additionnent parce que ce sont des **affectations** et non des gens :
## le même ouvrier compte deux fois s'il a travaillé deux phases, ce qui est exactement ce
## qu'on veut dire par « la journée a fait travailler trois fois quelqu'un ».
func test_it_sums_the_posts_that_were_manned() -> void:
	var first := _with_work(_report({}, {}), [&"ana", &"bo"])
	var second := _with_work(_report({}, {}), [&"ana"])
	assert_int(_summary([first, second]).manned()).is_equal(3)

## **Le cas qui porte le fichier.** Le bilan ne compte aucun oisif, et ce n'est pas zéro par
## hasard : il n'y a pas d'accesseur du tout. Les rapports de phase en portent, et le bilan
## les laisse là où ils veulent dire quelque chose.
func test_it_counts_no_idle_worker() -> void:
	var summary := _summary([_with_idle(_report({}, {}), [&"ana", &"bo"])])
	assert_bool(summary.has_method("idle")) \
		.override_failure_message("un bilan de journée ne compte pas d'oisif : voir 3.3") \
		.is_false()

## Les tables rendues sont des copies. Sans ça, un panneau qui trierait sa récolte pour
## l'afficher réordonnerait le bilan sous les autres lecteurs — le genre de fuite que
## `ProductionReport` ferme depuis `E1`.
func test_the_bundles_it_returns_are_copies() -> void:
	var summary := _summary([_report({&"wood": 2}, {&"wood": 2})])
	var taken := summary.produced()
	taken[&"wood"] = 99
	taken[&"gold"] = 1
	assert_int(summary.produced()[&"wood"]).is_equal(2)
	assert_bool(summary.produced().has(&"gold")).is_false()

func test_the_completed_list_it_returns_is_a_copy() -> void:
	var report := _with_sites(_report({}, {}), {Vector2i(1, 1): 1}, {}, [Vector2i(1, 1)])
	var summary := _summary([report])
	summary.completed().append(Vector2i(9, 9))
	assert_array(summary.completed()).has_size(1)

# --- La mise en place -----------------------------------------------------------------------

func _summary(reports: Array) -> DaySummary:
	var typed: Array[PhaseReport] = []
	typed.assign(reports)
	return DaySummary.of(3, typed, DUE)

## Un rapport de phase qui n'a fait que produire. Les autres fabriques l'enrichissent
## plutôt que de multiplier les paramètres : chaque cas ne parle que d'un seul champ.
func _report(produced: Dictionary, stored: Dictionary) -> PhaseReport:
	var made: Dictionary[StringName, int] = {}
	made.assign(produced)
	var kept: Dictionary[StringName, int] = {}
	kept.assign(stored)
	var work: Array[WorkLine] = []
	var idle: Array[StringName] = []
	var cells: Array[Vector2i] = []
	return PhaseReport.create(3, &"a_phase",
		ProductionReport.create(made, kept, work, idle), SiteReport.empty(),
		ProgressReport.empty(), idle, cells, null)

func _with_sites(report: PhaseReport, advances: Dictionary, shifts: Dictionary,
		completed: Array) -> PhaseReport:
	var crans: Dictionary[Vector2i, int] = {}
	crans.assign(advances)
	var moved: Dictionary[Vector2i, int] = {}
	moved.assign(shifts)
	var work: Array[WorkLine] = []
	var done: Array[Vector2i] = []
	done.assign(completed)
	var idle: Array[StringName] = []
	return PhaseReport.create(report.day(), report.phase(), report.production(),
		SiteReport.create(crans, moved, work), report.progress(), idle, done, null)

func _with_progress(report: PhaseReport, gains: Array) -> PhaseReport:
	var typed: Array[SkillGain] = []
	typed.assign(gains)
	var idle: Array[StringName] = []
	var cells: Array[Vector2i] = []
	return PhaseReport.create(report.day(), report.phase(), report.production(),
		report.sites(), ProgressReport.create(typed), idle, cells, null)

func _with_work(report: PhaseReport, workers: Array) -> PhaseReport:
	var work: Array[WorkLine] = []
	for worker in workers:
		work.append(WorkLine.create(worker, Vector2i(0, 0), &"harvest"))
	var made: Dictionary[StringName, int] = {}
	var kept: Dictionary[StringName, int] = {}
	var idle: Array[StringName] = []
	var cells: Array[Vector2i] = []
	return PhaseReport.create(report.day(), report.phase(),
		ProductionReport.create(made, kept, work, idle), report.sites(),
		report.progress(), idle, cells, null)

func _with_idle(report: PhaseReport, resting: Array) -> PhaseReport:
	var idle: Array[StringName] = []
	idle.assign(resting)
	var cells: Array[Vector2i] = []
	return PhaseReport.create(report.day(), report.phase(), report.production(),
		report.sites(), report.progress(), idle, cells, null)

func _gain(worker: StringName, xp: int, skill_before: int, skill_after: int,
		level_before: int, level_after: int) -> SkillGain:
	return SkillGain.create(worker, &"harvest", xp, skill_before, skill_after,
		level_before, level_after)
