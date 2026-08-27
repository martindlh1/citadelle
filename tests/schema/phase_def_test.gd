class_name PhaseDefTest
extends GdUnitTestSuite
## Une phase de la journée, et le filet de complétude qui la rattrape.
##
## Le cas qui porte le fichier n'est pas un contrôle de champ : c'est que **rien ici ne
## nomme une phase**. `DESIGN.md` 2 exige que le `DayCycle` ne code ni matin ni soir en
## dur, et une suite de tests qui écrirait `&"evening"` pour vérifier une règle serait la
## première à figer ce que le design garde ouvert. Les phases fabriquées ici portent donc
## des identifiants inventés sur place.

const ACTIONS := PhaseDef.ACTIONS

func test_a_blank_phase_reports_its_missing_fields() -> void:
	assert_array(PhaseDef.new().missing_fields()).contains(["id", "label", "allows"])

func test_a_complete_phase_reports_nothing() -> void:
	assert_array(_working().missing_fields()).is_empty()

func test_a_phase_without_an_id_is_reported() -> void:
	var phase := _working()
	phase.id = &""
	assert_array(phase.missing_fields()).contains(["id"])

func test_a_phase_without_a_label_is_reported() -> void:
	var phase := _working()
	phase.label = ""
	assert_array(phase.missing_fields()).contains(["label"])

## Un geste inconnu se poserait sur une phase sans que rien ne le refuse : la phase
## autoriserait quelque chose que personne ne demande jamais, donc rien.
func test_an_unknown_action_is_reported() -> void:
	var phase := _working()
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY, &"barter"]
	phase.allows = kinds
	assert_array(phase.missing_fields()).contains(["allows.barter.unknown"])

## Une phase qui n'autorise rien **et** ne résout pas est un tour perdu.
func test_a_phase_that_permits_nothing_and_resolves_nothing_is_reported() -> void:
	var phase := _working()
	var none: Array[StringName] = []
	phase.allows = none
	phase.resolves = false
	assert_array(phase.missing_fields()).contains(["allows"])

## Mais une phase qui n'autorise rien et **résout** est parfaitement légitime : c'est le
## soir du modèle asymétrique de DESIGN.md 2, où l'on regarde la journée se dérouler.
func test_a_resolving_phase_may_permit_nothing() -> void:
	var phase := _working()
	var none: Array[StringName] = []
	phase.allows = none
	phase.resolves = true
	assert_array(phase.missing_fields()).is_empty()

func test_a_phase_permits_only_what_it_declares() -> void:
	var phase := _working()
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY]
	phase.allows = kinds
	assert_bool(phase.permits(PhaseDef.ACTION_PLAY)).is_true()
	assert_bool(phase.permits(PhaseDef.ACTION_ASSIGN)).is_false()

## L'ensemble des gestes est fermé, comme CardData.POOLS. En ajouter un est une
## modification de code, et ce cas est là pour que l'ajout se voie.
func test_the_action_set_is_closed() -> void:
	assert_bool(PhaseDef.is_known_action(PhaseDef.ACTION_PLAY)).is_true()
	assert_bool(PhaseDef.is_known_action(PhaseDef.ACTION_ASSIGN)).is_true()
	assert_bool(PhaseDef.is_known_action(&"trade")).is_false()
	assert_array(ACTIONS).has_size(2)

## Une phase renseignée à la main, sur un nom qui n'existe dans aucun .tres.
func _working() -> PhaseDef:
	var phase := PhaseDef.new()
	phase.id = &"a_phase"
	phase.label = "Une phase"
	phase.color = Color(0.5, 0.5, 0.5)
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY, PhaseDef.ACTION_ASSIGN]
	phase.allows = kinds
	phase.resolves = false
	return phase
