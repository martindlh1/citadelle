class_name WaveDefTest
extends GdUnitTestSuite
## Une vague, et le filet qui refuse un fichier vide.
##
## Elle ne porte que trois champs, et c'est délibéré : `DESIGN.md` 3.6 garde sept questions
## sous un `OUVERT` que `F2` tranchera. Cette suite est donc courte par construction, et le
## restera jusque-là.
##
## Elle vérifie aussi ce que `data/waves/` contient vraiment, parce que c'est le seul
## endroit qui le fasse — le catalogue n'a pas encore de lecteur dans le domaine, la
## fréquence des vagues étant l'`OUVERT` de 2 que `I2` datera.

func test_a_blank_wave_reports_all_its_fields() -> void:
	assert_array(WaveDef.new().missing_fields()).contains(["id", "label", "power"])

func test_a_filled_wave_reports_nothing() -> void:
	assert_array(_wave().missing_fields()).is_empty()

## Une vague à zéro se contient toute seule, ne casse rien et ne se distingue en rien
## d'une journée sans combat. Ce n'est pas une vague facile, c'est un fichier qu'on a
## oublié de remplir — et Godot n'écrivant jamais un 0 dans un `.tres`, les deux y seraient
## indiscernables.
func test_a_powerless_wave_is_reported() -> void:
	var wave := _wave()
	wave.power = 0
	assert_array(wave.missing_fields()).contains(["power"])

## Sans libellé, une vague s'annoncerait par son identifiant interne, en anglais, au milieu
## d'un rapport français. Même exigence que sur une `PhaseDef`.
func test_a_nameless_wave_is_reported() -> void:
	var wave := _wave()
	wave.label = ""
	assert_array(wave.missing_fields()).contains(["label"])

## `data/waves/` n'est pas vide, et rien d'autre ne le dirait : aucun système du domaine ne
## lit encore ce catalogue. Sans ce cas, le dossier pourrait disparaître entier sans qu'une
## seule suite ne bronche.
func test_data_carries_at_least_one_wave() -> void:
	assert_array(GameDatabase.list_wave_ids()) \
		.override_failure_message("data/waves/ ne contient aucune vague") \
		.is_not_empty()

## Et ce qu'il contient est exploitable. C'est le même contrôle que `GameDatabase` fait au
## boot, refait ici parce qu'un `assert()` de boot ne survit pas à un export release.
func test_no_wave_of_data_is_left_unset() -> void:
	for id in GameDatabase.list_wave_ids():
		var missing := GameDatabase.get_wave(id).missing_fields()
		assert_array(missing) \
			.override_failure_message("champs vides dans data/waves/%s.tres : %s"
				% [id, ", ".join(missing)]) \
			.is_empty()

func _wave() -> WaveDef:
	var wave := WaveDef.new()
	wave.id = &"test_wave"
	wave.label = "Vague d'essai"
	wave.power = 12
	return wave
