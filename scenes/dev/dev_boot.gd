extends Node
## Point d'entrée unique des scènes de dev.
##
## Godot ne sait lancer qu'une scène, jamais un script : dev_boot.tscn est donc la
## seule .tscn de scenes/dev/, et la scène principale du projet. Tous les harnais
## restent des .gd purs, instanciés ici.
##
## Pour changer de harnais : ajouter son script à HARNESS_SCRIPTS, mettre son
## identifiant dans HARNESS, relancer (F5). Un harnais hérite de Node et construit
## son arbre dans _ready().

## Marge du rapport de boot, en pixels.
const REPORT_MARGIN := 16.0

## Harnais à lancer. Vide = aucun, on affiche le rapport de boot.
const HARNESS := &"run"

## Identifiant de harnais -> script à instancier.
const HARNESS_SCRIPTS: Dictionary[StringName, String] = {
	&"terrain": "res://scenes/dev/terrain_harness.gd",
	&"city": "res://scenes/dev/city_harness.gd",
	&"economy": "res://scenes/dev/economy_harness.gd",
	&"workforce": "res://scenes/dev/workforce_harness.gd",
	&"deck": "res://scenes/dev/deck_harness.gd",
	&"run": "res://scenes/dev/run_harness.gd",
	&"hud": "res://scenes/dev/hud_harness.gd",
	&"combat": "res://scenes/dev/combat_harness.gd",
}

## Bascule plein écran / fenêtré, pour **tous** les harnais à la fois.
##
## Elle est ici et non dans un harnais parce qu'elle n'appartient à aucun : c'est une
## propriété de la fenêtre, pas de ce qu'on y montre. Le pivot est le seul nœud que tous
## les harnais ont au-dessus d'eux, donc le seul endroit où l'écrire une fois.
##
## `_unhandled_input` la place **après** les harnais dans la chaîne : un harnais qui
## voudrait F11 pour autre chose garderait la priorité. Aucun ne le fait aujourd'hui, mais
## c'est le bon sens de lecture — le pivot rattrape ce que personne n'a pris.
##
## `WINDOWED` et non `MAXIMIZED` au retour : on revient à la fenêtre qu'on avait, ce qui est
## ce qu'une bascule promet.
const FULLSCREEN_KEY := KEY_F11

func _ready() -> void:
	EventBus.database_ready.connect(_on_database_ready)
	if HARNESS.is_empty():
		add_child(_make_report_label())
		return
	var script_path: String = HARNESS_SCRIPTS.get(HARNESS, "")
	assert(not script_path.is_empty(), "harnais inconnu : %s" % HARNESS)
	var harness_script: GDScript = load(script_path)
	var harness: Node = harness_script.new()
	harness.name = String(HARNESS).to_pascal_case()
	add_child(harness)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != FULLSCREEN_KEY:
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()

func _on_database_ready() -> void:
	print("[dev_boot] GameDatabase prêt, %d catégorie(s) indexée(s)."
		% GameDatabase.list_categories().size())

func _make_report_label() -> Label:
	var label := Label.new()
	label.name = "BootReport"
	label.text = _report()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	return label

func _report() -> String:
	var lines := PackedStringArray()
	lines.append("Citadelle — dev boot")
	lines.append("Godot %s" % str(Engine.get_version_info().get("string", "?")))
	lines.append("")
	lines.append("GameDatabase")
	for category in GameDatabase.list_categories():
		var ids := PackedStringArray()
		for id in GameDatabase.list_ids(category):
			ids.append(String(id))
		lines.append("  %s : %s" % [category, ", ".join(ids)])
	var terrain := GameDatabase.get_balance().terrain
	lines.append("  terrain.tile_size = %s" % terrain.tile_size)
	lines.append("  terrain.step_height = %s" % terrain.step_height)
	lines.append("")
	lines.append("RunManager.is_running() = %s" % RunManager.is_running())
	lines.append("")
	lines.append("Aucun harnais actif — renseigner HARNESS dans scenes/dev/dev_boot.gd.")
	return "\n".join(lines)
