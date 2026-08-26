class_name WorkerCard
extends PanelContainer
## La fiche d'un ouvrier : son nom, ce qu'il a vécu, ce qu'il sait faire, et ce qu'il
## fait à l'instant.
##
## C'est la moitié de `W2` que `DESIGN.md` 3.4 réclame depuis `W1` : « on choisit *qui*
## on place. Les ouvriers n'ayant pas les mêmes pistes, envoyer le bon sur la bonne
## action est la décision de fond de chaque phase. » Une décision qu'on ne peut pas voir
## n'est pas une décision — jusqu'ici le roster tenait sur une ligne de texte qui
## comptait des têtes.
##
## Elle montre les **deux axes** de 3.4 côte à côte, et c'est ce qui les rend lisibles
## comme deux choses distinctes : le **niveau d'ouvrier** en tête, qui dit ce qu'il a
## vécu et ne donne aucun multiplicateur, et une ligne par **piste** entamée, qui dit ce
## qu'il sait faire et porte le chiffre que la production consomme. Un ouvrier n'a pas
## trois pistes vierges : il en a autant qu'il a exercé de métiers, et la fiche se lit
## donc comme son parcours.
##
## Vue pure. On lui donne un `Worker`, elle dessine. Elle ne juge aucune affectation —
## « cet ouvrier peut-il aller là ? » se demande à `RunOrchestrator.staffing_refusal()`,
## et c'est l'appelant qui traduit. Elle ne sélectionne rien non plus : elle **signale**
## qu'on l'a cliquée, comme `HandView` signale un rang de carte, et c'est le harnais qui
## tient ce qu'il tient.
##
## **Elle voit un `Worker`, et ce n'est pas une entorse.** `Roster` en est le seul
## propriétaire et « rien hors de `domain/workforce/` n'en voit un » — la phrase vise les
## **systèmes du domaine**, ceux à qui l'on ne montre que des projections. Un adapter,
## lui, lit le domaine : c'est le précédent de `ResourceBar` avec un `Ledger`, de
## `HandView` avec une `Hand` et de `BuildingRenderer` avec un `CityState`. Passer par la
## `LaborForce` aurait coûté le niveau, l'XP et la présence, qui n'y traversent pas
## justement parce que l'Économie n'a pas à les connaître.
##
## Construite en code, sans `.tscn`. Les chiffres sont des constantes nommées et non de
## l'équilibrage : une largeur de fiche est de la mise en forme.

## La fiche vient d'être cliquée.
##
## Un signal et non un appel, pour la raison que `HandView` a écrite avant elle : une vue
## qui déciderait de la sélection serait la même faute d'architecture qu'une vue qui
## jugerait la jouabilité.
signal picked()

const CARD_WIDTH := 176

## Écarts internes.
const ROW_GAP := 2
const COLUMN_GAP := 10
const BLOCK_GAP := 3

const PANEL_COLOR := Color(0.13, 0.14, 0.17, 0.94)
const PANEL_RADIUS := 4
const PANEL_MARGIN := 6

## Fond d'une fiche tenue, et son liseré. Le même or que la carte tenue de `HandView` :
## deux sélections différentes dans le même écran doivent se lire pareil.
const HELD_COLOR := Color(0.20, 0.19, 0.14, 0.96)
const HELD_BORDER := 2
const SELECTED_COLOR := Color(1.0, 0.85, 0.35)

const NAME_COLOR := Color(0.94, 0.94, 0.92)
const LEVEL_COLOR := Color(0.60, 0.68, 0.85)
const KEY_COLOR := Color(0.62, 0.66, 0.72)
const VALUE_COLOR := Color(0.90, 0.91, 0.93)

## Ce qu'il fait ce soir : un poste tenu, ou rien.
const BUSY_COLOR := Color(0.55, 0.82, 0.50)
const FREE_COLOR := Color(0.72, 0.66, 0.40)

## Un absent, et un palier qui vient d'être franchi.
const ABSENT_COLOR := Color(0.60, 0.45, 0.45)
const NOTE_COLOR := Color(1.0, 0.85, 0.35)

## Opacité d'une fiche dont l'ouvrier n'est pas là.
const ABSENT_ALPHA := 0.55

const NAME_FONT_SIZE := 13
const ROW_FONT_SIZE := 11

## Ce qu'un ouvrier libre affiche à la place d'un poste.
const FREE_TEXT := "libre"

## Un absent — parti en expédition à `X1`. Rien ne rend personne absent aujourd'hui, mais
## la fiche sait déjà le dire : `DESIGN.md` 3.9 exige que rien ne suppose le roster
## entier disponible, et un écran qui l'oublierait serait le dernier endroit où on s'en
## apercevrait.
const ABSENT_TEXT := "absent"

## Une piste au plafond. Elle continue de recevoir de l'XP pour le niveau, mais son
## multiplicateur ne monte plus — c'est exactement la situation que `X5` rendra
## intéressante, et elle mérite de se voir avant.
const CAPPED_MARK := " · max"

## XP totale, montrée quand aucun palier n'est à annoncer.
const XP_TEXT := "%d XP"

## Préfixe du niveau d'ouvrier. Court exprès : c'est un repère, pas une phrase.
const LEVEL_PREFIX := "N"

var _name: Label
var _level: Label
var _tracks: GridContainer
var _job: Label
var _note: Label

## Équilibrage des Effectifs, gardé à la construction. Il ne change pas en cours de run,
## et le tenir ici évite de le repasser à chaque image.
var _balance: WorkforceBalance

## Les libellés de piste, par paires clé/valeur, dans l'ordre où les familles sont
## entrées. Le tableau grandit quand l'ouvrier entame un métier de plus, et il ne se
## reconstruit jamais.
var _track_keys: Array[Label] = []
var _track_values: Array[Label] = []

## Fiche prête à être ajoutée à l'arbre, vide.
static func create(balance: WorkforceBalance) -> WorkerCard:
	assert(balance != null, "fiche d'unité sans équilibrage")
	var card := WorkerCard.new()
	card.name = "WorkerCard"
	card._balance = balance
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _make_style(false))
	# Elle **arrête** les clics, à l'inverse des vues de E2 : c'est la seule du projet
	# qu'on désigne pour agir dessus, et un clic qui la traverserait irait piocher une
	# cellule derrière le panneau.
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", COLUMN_GAP)
	card._name = _make_text("", NAME_FONT_SIZE, NAME_COLOR)
	card._name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(card._name)
	card._level = _make_text("", ROW_FONT_SIZE, LEVEL_COLOR)
	header.add_child(card._level)
	column.add_child(header)

	card._tracks = GridContainer.new()
	card._tracks.columns = 2
	card._tracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card._tracks.add_theme_constant_override("v_separation", ROW_GAP)
	card._tracks.add_theme_constant_override("h_separation", COLUMN_GAP)
	column.add_child(card._tracks)

	card._job = _make_text("", ROW_FONT_SIZE, FREE_COLOR)
	column.add_child(card._job)
	card._note = _make_text("", ROW_FONT_SIZE, NOTE_COLOR)
	column.add_child(card._note)

	card.add_child(column)
	return card

## Redessine la fiche. `job` est ce qu'il tient — vide s'il est libre —, `note` une
## annonce de palier, et `held` dit s'il est le sélectionné.
##
## Les nœuds sont **mis à jour sur place** et non reconstruits, ce qui la rend appelable
## à chaque image sans churn d'allocation. C'est la leçon que `E2` a écrite dans
## `CLAUDE.md` : rafraîchir sur événement demanderait d'énumérer tous les gestes qui
## touchent un ouvrier — l'affecter, le rappeler, résoudre, et demain le blesser — et un
## oubli dans cette liste se lirait comme une fiche qui ne bouge plus.
func show_worker(worker: Worker, job: String, note: String, held: bool) -> void:
	assert(worker != null, "fiche d'unité sans ouvrier")
	var absent := not worker.is_present()
	_name.text = worker.given_name()
	_level.text = "%s%d%s" % [LEVEL_PREFIX, worker.level(_balance),
		CAPPED_MARK if worker.is_capped(_balance) else ""]
	_fill_tracks(worker)
	_job.text = ABSENT_TEXT if absent else (job if not job.is_empty() else FREE_TEXT)
	_job.add_theme_color_override("font_color", _job_color(absent, job))
	_show_note(worker, note)
	add_theme_stylebox_override("panel", _make_style(held))
	modulate.a = ABSENT_ALPHA if absent else 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()
			accept_event()

# --- Les pistes ---------------------------------------------------------------------------

## Une ligne par famille entamée, dans l'ordre où l'ouvrier les a entamées.
##
## Le libellé d'une famille est son identifiant capitalisé, et c'est assumé : aucune
## famille ne porte de libellé dans `data/`, parce qu'aucune famille n'y est déclarée —
## `DESIGN.md` 3.4 pose que « la liste n'est pas close », qu'elle vit dans
## `data/balance/` et qu'aucun code ne l'énumère. Écrire ici une table
## identifiant -> libellé français rouvrirait exactement l'énumération que la Construction
## a pu rejoindre sans une ligne de GDScript à `I1`. Le jour où un nom d'affichage
## comptera, ce sera un champ de `.tres`, pas un dictionnaire dans une vue.
func _fill_tracks(worker: Worker) -> void:
	var families := worker.families()
	while _track_keys.size() < families.size():
		var key := _make_text("", ROW_FONT_SIZE, KEY_COLOR)
		var value := _make_text("", ROW_FONT_SIZE, VALUE_COLOR)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_track_keys.append(key)
		_track_values.append(value)
		_tracks.add_child(key)
		_tracks.add_child(value)
	for index in _track_keys.size():
		var shown := index < families.size()
		_track_keys[index].visible = shown
		_track_values[index].visible = shown
		if not shown:
			continue
		var family := families[index]
		_track_keys[index].text = "%s %d%s" % [String(family).capitalize(),
			worker.skill_level(family, _balance),
			CAPPED_MARK if worker.is_skill_capped(family, _balance) else ""]
		_track_values[index].text = "×%.2f" % worker.efficiency(family, _balance)

## La dernière ligne : un palier qu'on vient de franchir, ou l'XP totale à défaut.
##
## Elle est **toujours là**, et c'est une décision de mise en page avant d'être une
## d'information. Une ligne qui n'apparaît qu'au palier ferait grandir la fiche au moment
## exact où le compte rendu de phase est le plus long — donc où la colonne de droite a le
## moins de place —, et la grille entière sauterait sous l'œil. C'est la raison qui garde
## les quatre colonnes de `ResourceBar` en place même à zéro.
##
## Ce qu'elle montre le reste du temps n'est donc pas du remplissage : l'XP totale est
## l'axe du **niveau d'ouvrier**, celui que les pistes n'expliquent pas, et c'est aussi ce
## qui rend lisible un ouvrier qui monte sans que rien ne bouge dans ses pistes — la
## situation même que `X5` rendra intéressante.
func _show_note(worker: Worker, note: String) -> void:
	if note.is_empty():
		_note.text = XP_TEXT % worker.xp()
		_note.add_theme_color_override("font_color", KEY_COLOR)
		return
	_note.text = note
	_note.add_theme_color_override("font_color", NOTE_COLOR)

func _job_color(absent: bool, job: String) -> Color:
	if absent:
		return ABSENT_COLOR
	return FREE_COLOR if job.is_empty() else BUSY_COLOR

static func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_style(held: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HELD_COLOR if held else PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	if held:
		style.set_border_width_all(HELD_BORDER)
		style.border_color = SELECTED_COLOR
	return style
