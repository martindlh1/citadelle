class_name RunBalanceTest
extends GdUnitTestSuite
## Le bloc d'équilibrage du run, et le seul filet qui puisse rattraper un booléen effacé.
##
## Aucun chiffre n'est figé et aucun nom de phase n'est écrit : la durée d'un run et la
## structure d'une journée sont deux `OUVERT` de `DESIGN.md` 2, et un test qui les figerait
## rendrait plus coûteux le playtest de `I2b` — dont c'est précisément le travail.
##
## Le cas qui porte le fichier est `test_a_day_that_never_resolves_is_reported`. `resolves`
## est le seul champ de tout `data/balance/` que la doctrine du zéro ne protège pas : un
## booléen faux étant la valeur par défaut de Godot, un champ effacé par un
## réenregistrement est indiscernable d'un champ volontairement faux. Le filet est posé
## un cran plus haut — au moins une phase de la journée doit résoudre —, exactement comme
## `C4` a exigé qu'au moins un bâtiment de `data/` déclare un `build_actions`.

const BALANCE_PATH := "res://data/balance/run_balance.tres"

func test_a_blank_block_reports_everything() -> void:
	assert_array(RunBalance.new().missing_fields()).contains(
		["days", "phases", "score.none_counts"])

func test_a_complete_block_reports_nothing() -> void:
	assert_array(_working().missing_fields()).is_empty()

func test_a_run_without_days_is_reported() -> void:
	var balance := _working()
	balance.days = 0
	assert_array(balance.missing_fields()).contains(["days"])

## Le cas qui porte le fichier. Une journée dont aucune phase ne résout produirait un run
## entier sans une seule récolte, sans qu'aucune erreur ne soit levée nulle part.
func test_a_day_that_never_resolves_is_reported() -> void:
	var balance := _working()
	for phase in balance.phases:
		phase.resolves = false
	assert_array(balance.missing_fields()).contains(["phases.none_resolves"])

## Deux phases du même identifiant se distingueraient dans un rapport et dans un signal,
## qui sont les deux seuls endroits où l'identifiant sert.
func test_two_phases_sharing_an_id_are_reported() -> void:
	var balance := _working()
	balance.phases[1].id = balance.phases[0].id
	assert_array(balance.missing_fields()).contains(["phases.1.id.duplicate"])

## Les défauts d'une phase remontent préfixés de son rang, comme BalanceData préfixe les
## siens du nom de leur bloc : sans le rang, un `label` manquant ne dirait pas laquelle.
func test_a_broken_phase_is_reported_under_its_index() -> void:
	var balance := _working()
	balance.phases[1].label = ""
	assert_array(balance.missing_fields()).contains(["phases.1.label"])

func test_a_null_phase_is_reported_under_its_index() -> void:
	var balance := _working()
	balance.phases[0] = null
	assert_array(balance.missing_fields()).contains(["phases.0"])

func test_the_resolving_phases_come_out_in_order() -> void:
	var balance := _working()
	balance.phases[0].resolves = true
	balance.phases[1].resolves = true
	var resolving := balance.resolving_phases()
	assert_array(resolving).has_size(2)
	assert_str(String(resolving[0].id)).is_equal(String(balance.phases[0].id))

# --- Le calendrier des vagues -----------------------------------------------------------

## Un calendrier vide est une réponse, pas un oubli : c'est le run paisible d'un harnais
## qui mesure une économie sans qu'on lui casse ses murs. Même statut que
## `starting_building` vide, et le cas est ici pour que personne ne « corrige » l'absence
## de contrôle en croyant à un trou.
func test_an_empty_calendar_is_legitimate() -> void:
	var balance := _working()
	var none: Array[WaveSlot] = []
	balance.waves = none
	assert_array(balance.missing_fields()).is_empty()

func test_a_wave_falls_on_its_day_and_on_no_other() -> void:
	var balance := _working()
	var slots: Array[WaveSlot] = [_slot(2, &"tide")]
	balance.waves = slots
	assert_object(balance.wave_on(2)).is_not_null()
	assert_object(balance.wave_on(1)).is_null()
	assert_object(balance.wave_on(3)).is_null()

## Une vague datée au-delà de la dernière journée ne tomberait jamais. C'est le seul
## contrôle qui ait besoin de voir à la fois le calendrier et la durée, et c'est la raison
## pour laquelle le calendrier vit dans ce bloc plutôt que dans `CombatBalance`.
func test_a_wave_beyond_the_last_day_is_reported() -> void:
	var balance := _working()
	var slots: Array[WaveSlot] = [_slot(balance.days + 1, &"tide")]
	balance.waves = slots
	assert_array(balance.missing_fields()).contains(["waves.0.day.beyond_the_run"])

## Deux vagues le même jour rendraient la seconde inatteignable : une seule peut attendre
## à la fois, donc la seconde disparaîtrait sans qu'aucune erreur ne soit levée.
func test_two_waves_sharing_a_day_are_reported() -> void:
	var balance := _working()
	var slots: Array[WaveSlot] = [_slot(2, &"tide"), _slot(2, &"surge")]
	balance.waves = slots
	assert_array(balance.missing_fields()).contains(["waves.1.day.duplicate"])

func test_a_null_slot_is_reported_under_its_index() -> void:
	var balance := _working()
	var slots: Array[WaveSlot] = [null]
	balance.waves = slots
	assert_array(balance.missing_fields()).contains(["waves.0"])

## Les défauts d'un créneau remontent préfixés de son rang, comme ceux d'une phase.
func test_a_broken_slot_is_reported_under_its_index() -> void:
	var balance := _working()
	var slot := _slot(2, &"tide")
	slot.wave = null
	var slots: Array[WaveSlot] = [slot]
	balance.waves = slots
	assert_array(balance.missing_fields()).contains(["waves.0.wave"])

# --- Le barème de score ------------------------------------------------------------------

## Un poids nul est un choix d'équilibrage lisible — « la thésaurisation ne rapporte
## rien » — donc aucun des quatre n'est réclamé isolément.
func test_a_single_zero_weight_is_legitimate() -> void:
	var balance := _working()
	balance.score_per_resource = 0
	assert_array(balance.missing_fields()).is_empty()

## Le pendant exact de `phases.none_resolves` : quatre poids nuls sont un run qui vaut zéro
## quoi qu'on y fasse, donc la disparition du barème entier et non un réglage. C'est le
## filet qu'un contrôle champ par champ ne peut pas poser.
func test_a_score_that_counts_nothing_is_reported() -> void:
	var balance := _working()
	balance.score_per_resource = 0
	balance.score_per_building = 0
	balance.score_per_worker = 0
	balance.score_per_worker_level = 0
	assert_array(balance.missing_fields()).contains(["score.none_counts"])

## Le .tres réel se charge-t-il avec ses sous-ressources ?
##
## Un `Array[PhaseDef]` est le premier tableau typé sur une classe de script du projet, et
## rien dans le schéma ne garantit que le format texte l'écrit correctement : mal formé,
## il se chargerait **vide**, et la journée n'aurait plus aucune phase. C'est le pendant
## exact du cas qui garde la table imbriquée d'`ActionBalance`.
func test_the_real_file_carries_its_phases() -> void:
	var balance := load(BALANCE_PATH) as RunBalance
	assert_object(balance).is_not_null()
	assert_array(balance.phases).is_not_empty()
	assert_array(balance.resolving_phases()).is_not_empty()
	for phase in balance.phases:
		assert_object(phase).is_instanceof(PhaseDef)
		assert_array(phase.missing_fields()).is_empty()

## Chaîné depuis data/balance/balance.tres : un .tres déplacé priverait la journée de sa
## structure sans casser le chargement de l'équilibrage.
func test_the_block_is_wired_into_the_balance_root() -> void:
	var balance := load("res://data/balance/balance.tres") as BalanceData
	assert_object(balance.run).is_not_null()
	assert_object(balance.run).is_instanceof(RunBalance)

## Le calendrier réel voyage-t-il avec ses vagues ?
##
## Même piège que pour les phases, en pire d'un cran : un `Array[WaveSlot]` mal écrit se
## chargerait **vide**, ce qui est un format légitime — un run paisible. La disparition du
## calendrier serait donc silencieuse et se lirait comme un choix, alors qu'un `.tres` de
## vague déplacé la provoquerait. C'est aussi le premier tableau du projet dont les
## éléments référencent une `Resource` externe.
func test_the_real_file_carries_its_calendar() -> void:
	var balance := load(BALANCE_PATH) as RunBalance
	assert_array(balance.waves).is_not_empty()
	for slot in balance.waves:
		assert_object(slot).is_instanceof(WaveSlot)
		assert_array(slot.missing_fields()).is_empty()
		assert_object(slot.wave).is_instanceof(WaveDef)

## Le fichier livré est-il exploitable de bout en bout ?
##
## Il double le contrôle de `GameDatabase` au boot, et c'est voulu : le boot refuse de
## démarrer, donc il ne dit jamais *quoi* dans une suite de tests. Celui-ci le nomme.
func test_the_real_file_reports_nothing() -> void:
	assert_array((load(BALANCE_PATH) as RunBalance).missing_fields()).is_empty()

## Un bloc renseigné à la main, sur des noms de phase et de vague qui n'existent dans aucun
## .tres — la même discipline que `DayCycleTest` : figer un nom livré rendrait plus coûteux
## l'arbitrage de `I2b`.
func _working() -> RunBalance:
	var balance := RunBalance.new()
	balance.days = 3
	var phases: Array[PhaseDef] = [_phase(&"first", false), _phase(&"second", true)]
	balance.phases = phases
	var slots: Array[WaveSlot] = [_slot(3, &"tide")]
	balance.waves = slots
	balance.score_per_resource = 1
	balance.score_per_building = 2
	balance.score_per_worker = 3
	balance.score_per_worker_level = 4
	return balance

func _slot(day: int, id: StringName) -> WaveSlot:
	var slot := WaveSlot.new()
	slot.day = day
	var wave := WaveDef.new()
	wave.id = id
	wave.label = String(id).capitalize()
	wave.power = 12
	slot.wave = wave
	return slot

func _phase(id: StringName, resolves: bool) -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = id
	phase.label = String(id).capitalize()
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY, PhaseDef.ACTION_ASSIGN]
	phase.allows = kinds
	phase.resolves = resolves
	return phase
