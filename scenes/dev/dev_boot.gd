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
const HARNESS := &"city"

## Identifiant de harnais -> script à instancier.
const HARNESS_SCRIPTS: Dictionary[StringName, String] = {
	&"terrain": "res://scenes/dev/terrain_harness.gd",
	&"city": "res://scenes/dev/city_harness.gd",
	&"economy": "res://scenes/dev/economy_harness.gd",
	&"workforce": "res://scenes/dev/workforce_harness.gd",
}

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
