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
	assert_array(PhaseDef.new().missing_fields()).contains(["id", "label", "color"])

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

## La couleur est le second champ que l'écran lit, et le seul des deux que la doctrine du
## zéro ne rattraperait pas toute seule : un `Color` non renseigné vaut le noir opaque,
## qui est une couleur parfaitement dessinable. Sans ce cas, une phase à qui l'éditeur
## aurait mangé sa teinte se peindrait en noir sur un fond sombre — donc ne se
## distinguerait de rien, ce qui est exactement le défaut que `P1a` corrige.
func test_a_phase_without_a_colour_is_reported() -> void:
	var phase := _working()
	phase.color = PhaseDef.UNSET_COLOR
	assert_array(phase.missing_fields()).contains(["color"])

## Et le noir voulu reste écrivable, à un cheveu près. Le cas existe pour que personne ne
## « corrige » la sentinelle en interdisant le noir : c'est la valeur par défaut de Godot
## qu'on refuse, pas la couleur.
func test_a_near_black_colour_passes() -> void:
	var phase := _working()
	phase.color = Color(0.02, 0.02, 0.02)
	assert_array(phase.missing_fields()).is_empty()

## Un geste inconnu se poserait sur une phase sans que rien ne le refuse : la phase
## autoriserait quelque chose que personne ne demande jamais, donc rien.
func test_an_unknown_action_is_reported() -> void:
	var phase := _working()
	var kinds: Array[StringName] = [PhaseDef.ACTION_PLAY, &"barter"]
	phase.allows = kinds
	assert_array(phase.missing_fields()).contains(["allows.barter.unknown"])

## Une phase qui n'autorise rien et **résout** est parfaitement légitime : c'est le soir
## du modèle asymétrique de DESIGN.md 2, où l'on regarde la journée se dérouler.
func test_a_resolving_phase_may_permit_nothing() -> void:
	var phase := _working()
	var none: Array[StringName] = []
	phase.allows = none
	phase.resolves = true
	assert_array(phase.missing_fields()).is_empty()

## Et une phase qui n'autorise rien et ne résout pas **n'est plus jugée ici**.
##
## Ce fichier la refusait jusqu'à `I2b`, au motif qu'elle n'est qu'un tour perdu. Le motif
## était bon et la conclusion fausse : la dernière phase d'une journée ferme cette journée,
## donc prélève l'upkeep et fait tomber la vague — et une `PhaseDef` ne sait pas qu'elle
## est dernière. La règle est montée dans `RunBalance`, qui voit la liste, exactement comme
## l'unicité de `id`. Voir `RunBalanceTest.test_an_idle_phase_before_the_last_is_reported`
## et son pendant qui autorise le soir.
##
## Le cas reste ici, retourné, pour que personne ne « rétablisse » le contrôle en croyant
## à un trou : c'est un déplacement, pas un oubli.
func test_an_idle_phase_is_judged_by_the_day_and_not_by_itself() -> void:
	var phase := _working()
	var none: Array[StringName] = []
	phase.allows = none
	phase.resolves = false
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
