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
	assert_array(RunBalance.new().missing_fields()).contains(["days", "phases"])

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

## Un bloc renseigné à la main, sur des noms de phase qui n'existent dans aucun .tres.
func _working() -> RunBalance:
	var balance := RunBalance.new()
	balance.days = 3
	var phases: Array[PhaseDef] = [_phase(&"first", false), _phase(&"second", true)]
	balance.phases = phases
	return balance

func _phase(id: StringName, resolves: bool) -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = id
	phase.label = String(id).capitalize()
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY, PhaseDef.ACTION_ASSIGN]
	phase.allows = kinds
	phase.resolves = resolves
	return phase
