class_name WaveDefTest
extends GdUnitTestSuite
## Une vague, et le filet qui refuse un fichier vide.
##
## Elle ne portait que trois champs jusqu'à `F2b`, et c'était délibéré : `DESIGN.md` 3.6
## gardait la forme du combat sous un `OUVERT`. Cette forme existe, donc une vague dit
## désormais **qui vient** et **combien de temps ça dure**, et cette suite grandit d'autant.
##
## Elle vérifie aussi ce que `data/waves/` contient vraiment, y compris que les assaillants
## qu'une composition nomme existent. Ce dernier contrôle double celui que `GameDatabase`
## fait au boot, pour la raison habituelle : un `assert()` de boot ne survit pas à un export
## release.

func test_a_blank_wave_reports_all_its_fields() -> void:
	assert_array(WaveDef.new().missing_fields()) \
		.contains(["id", "label", "power", "roster", "rounds"])

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

## Godot n'écrit pas un tableau vide dans un `.tres`, donc « oubliée » et « délibérément
## sans personne » y seraient indiscernables. Une vague qui n'envoie personne n'est pas une
## vague facile, c'est un fichier qu'on a oublié de remplir. Même geste que sur
## `CombatBalance.impassable_tags`.
func test_a_wave_without_a_roster_is_reported() -> void:
	var wave := _wave()
	wave.roster = []
	assert_array(wave.missing_fields()).contains(["roster"])

## Une razzia qui repart au bout de zéro manche n'entre jamais. Le zéro est ici le défaut
## d'un `int` que Godot omet, donc le cas à refuser.
func test_a_wave_that_lasts_no_round_is_reported() -> void:
	var wave := _wave()
	wave.rounds = 0
	assert_array(wave.missing_fields()).contains(["rounds"])

## Un même type peut venir plusieurs fois, et c'est la forme retenue plutôt qu'un couple
## (type, nombre) : l'ordre décide qui entre au milieu et qui entre sur l'aile.
func test_a_wave_may_send_the_same_attacker_twice() -> void:
	var wave := _wave()
	wave.roster = [&"raider", &"raider"]
	assert_array(wave.missing_fields()).is_empty()
	assert_int(wave.roster.size()).is_equal(2)

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

## Une composition ne nomme que des assaillants qui existent.
##
## `WaveDef.missing_fields()` ne peut pas le dire — une `Resource` ne lit pas l'index —,
## donc c'est le seul cas qui l'attrape hors du boot. Sans lui, un `&"raidre"` ferait
## entrer une vague avec un corps de moins, en silence.
func test_every_wave_of_data_calls_known_attackers() -> void:
	var known := GameDatabase.list_enemy_ids()
	for id in GameDatabase.list_wave_ids():
		for enemy in GameDatabase.get_wave(id).roster:
			assert_bool(known.has(enemy)) \
				.override_failure_message(
					"data/waves/%s.tres appelle un assaillant inconnu : %s" % [id, enemy]) \
				.is_true()

func _wave() -> WaveDef:
	var wave := WaveDef.new()
	wave.id = &"test_wave"
	wave.label = "Vague d'essai"
	wave.power = 12
	wave.roster = [&"test_enemy"]
	wave.rounds = 5
	return wave
