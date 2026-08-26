class_name WaveSlotTest
extends GdUnitTestSuite
## Un créneau du calendrier : une vague, et le jour où elle tombe.
##
## Aucun jour n'est figé ici, et c'est délibéré : la **fréquence des vagues** est un
## `OUVERT` de `DESIGN.md` 2 que `I3` tranchera devant un run entier. Ce fichier vérifie
## qu'un créneau incohérent se **voit**, jamais qu'il vaut cinq ou dix.
##
## Le croisement avec la durée du run n'est pas ici non plus : un créneau ne connaît pas
## `days`, et c'est `RunBalance` qui le vérifie — même partage qu'entre `PhaseDef` et
## l'unicité de son identifiant.

func test_a_blank_slot_reports_everything() -> void:
	assert_array(WaveSlot.new().missing_fields()).contains(["day", "wave"])

func test_a_complete_slot_reports_nothing() -> void:
	assert_array(_working().missing_fields()).is_empty()

func test_a_slot_without_a_day_is_reported() -> void:
	var slot := _working()
	slot.day = 0
	assert_array(slot.missing_fields()).contains(["day"])

func test_a_slot_without_a_wave_is_reported() -> void:
	var slot := _working()
	slot.wave = null
	assert_array(slot.missing_fields()).contains(["wave"])

## Les défauts de la vague remontent préfixés, comme `RunBalance` préfixe ceux d'une phase
## de son rang : sans ce préfixe, un `power` nul se lirait comme un défaut du créneau.
func test_a_broken_wave_is_reported_under_its_own_name() -> void:
	var slot := _working()
	slot.wave.power = 0
	assert_array(slot.missing_fields()).contains(["wave.power"])

## Un créneau renseigné à la main, sur une vague qui n'existe dans aucun `.tres`.
func _working() -> WaveSlot:
	var slot := WaveSlot.new()
	slot.day = 3
	slot.wave = _wave()
	return slot

func _wave() -> WaveDef:
	var wave := WaveDef.new()
	wave.id = &"tide"
	wave.label = "Marée"
	wave.power = 12
	return wave
