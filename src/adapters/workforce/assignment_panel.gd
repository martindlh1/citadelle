class_name AssignmentPanel
extends PanelContainer
## Le panneau d'affectation : ce qui est posé, qui est là, et le bouton qui remplit le
## reste.
##
## C'est le morceau de `W2` que deux jalons ont annoncé sans l'écrire. `I1` : « le choix
## de *qui* l'on envoie — le harnais prend toujours le premier ouvrier libre. 3.4 dit que
## c'est la décision de fond d'une phase ; la présenter est `W2` ». `E2` : « ce qui reste
## en texte […] le plateau et le roster iront à `W2` ». Les deux tiennent ici, et les deux
## lignes de texte qu'ils décrivent disparaissent du harnais plutôt que de le doubler —
## un chiffre affiché à deux endroits est un chiffre qui finira par différer de lui-même.
##
## **Il montre les deux moitiés du geste ensemble**, et c'est tout le sujet. `D2` a fait
## de « jouer une carte » et « y envoyer des ouvriers » deux gestes distincts : les
## actions posées d'un côté, les fiches de l'autre, et l'on relie les deux d'un clic. Une
## liste d'ouvriers sans les postes, ou l'inverse, laisserait la décision se prendre de
## mémoire.
##
## Vue pure, et la règle vaut jusqu'au bout : elle ne **décide** d'aucune affectation.
## Elle signale un clic, le harnais appelle `RunManager.staff()`, et le domaine dit oui ou
## non — c'est `RunOrchestrator.staffing_refusal()` qui reste le seul juge des cinq refus.
## Le seul verdict qu'elle lit elle-même est celui de la phase courante, pour éteindre son
## bouton : `I1` a payé pour savoir qu'« un refus qui ne se nomme pas est indiscernable
## d'une panne », et un bouton éteint est la façon la moins chère de nommer celui-là.
##
## **Elle reçoit un `RunState`**, ce qu'aucune vue n'avait fait avant elle, et il faut
## dire pourquoi. Une affectation a besoin de trois choses à la fois — le plateau, le
## roster, et le brouillon qui les relie —, plus le relief et la ville pour savoir quelle
## piste chaque action créditera. `RunState` est le seul objet du projet qui les tienne
## ensemble, et c'est `DESIGN.md` 3.8 qui l'autorise à exister pour cette raison même. Les
## passer un par un aurait fait six arguments dont l'appelant devrait calculer le sixième.
## Le risque est connu et il est le même que celui de `ResourceBar` devant son `Ledger` :
## rien n'empêche techniquement une vue de muter ce qu'on lui montre, et rien ici ne le
## fait.
##
## Construite en code, sans `.tscn`, comme les trois vues de `E2`. Elle déménagera sous
## `scenes/ui/` quand `I2` fera un vrai écran, et elle déménagera avec sa mise en forme :
## elle n'a pas de règles à emporter.

## Une fiche vient d'être cliquée.
signal worker_picked(worker: StringName)

## On veut rappeler cet ouvrier de là où il est, sans toucher à l'action.
##
## Le geste symétrique de `worker_picked`, et il manquait : jusqu'ici rappeler quelqu'un
## demandait de viser son action sur la carte et de rappeler **tout le monde** avec Retour
## arrière. Retirer un seul ouvrier d'un poste à deux places était donc impossible sans
## défaire les deux.
signal worker_released(worker: StringName)

## Une action posée vient d'être cliquée.
signal action_picked(action: int)

## Le bouton d'auto-affectation vient d'être pressé.
signal auto_requested()

## Fiches par rangée. Trois tient dans la largeur qui reste à droite de la carte, et
## garde le panneau assez court pour ne pas monter dans le compte rendu de phase.
const CARD_COLUMNS := 3

## Lignes d'action affichées au plus, le reste étant compté sur une ligne.
##
## Une borne et non une place « qui devrait suffire ». La première capture de `W2` a
## montré ce qu'un panneau sans borne fait dans un HUD de taille fixe : il grandit avec le
## plateau jusqu'à recouvrir son voisin, et le défaut n'apparaît qu'à la phase la plus
## chargée — donc le plus tard possible.
##
## **Trois à `W2`, cinq après `I2`**, et le desserrage n'est pas arbitraire : le panneau de
## bataille a quitté cette colonne, ce qui y a rendu de la place, et cinq est ce qu'une main
## peut poser en une phase — `hand_size` vaut cinq cartes d'action. Le plafond couvre donc
## le cas courant au lieu de tronquer dès la quatrième pose, ce qu'une partie jouée à la
## main a signalé comme gênant.
##
## Ça reste une borne de **harnais**, et le chiffre se mesure en capture plutôt qu'il ne se
## devine : c'est un HUD posé sur un viewport déjà occupé par une barre, un compte rendu et
## une main. L'écran du jeu aura à traiter la question pour de bon — une liste qui défile,
## ou une place à elle — et c'est `P1`.
const MAX_ROWS := 5

## Ce que la ligne de reste annonce.
const MORE_TEXT := "… et %d autre(s), sur la carte."

const PANEL_COLOR := Color(0.10, 0.11, 0.14, 0.94)
const PANEL_RADIUS := 5
const PANEL_MARGIN := 10

## Épaisseur du liseré qui dit la phase, sur le bord haut du panneau.
##
## **C'est le « signe qui bascule » que `DESIGN.md` 8 réclame**, et il est ici plutôt
## qu'ailleurs pour une raison qui tient : la phase décide de ce qu'on a le droit de faire,
## et ce panneau est l'endroit où on le fait — son bouton **Auto** s'éteint déjà quand la
## phase n'autorise pas d'affecter. Le liseré et le bouton disent donc la même chose, l'un
## en couleur et l'autre en gris.
##
## Sur le bord **haut** seulement : un cadre complet entourerait des fiches d'ouvrier qui
## portent déjà leurs propres couleurs, et ferait un second cadre là où la fiche tenue en a
## un. Une barre au-dessus du titre ne recouvre rien et se voit du coin de l'œil.
const PHASE_RULE := 3

## Couleur du liseré hors phase — avant le premier jour, et une fois le run fini.
##
## Un gris franc et non la teinte de la dernière phase jouée : « il n'y a plus de phase »
## est un état, et le peindre aux couleurs de celle qui vient de finir dirait le contraire.
const NO_PHASE_COLOR := Color(0.32, 0.34, 0.40)

const ROW_GAP := 3
const CARD_GAP := 5
const BLOCK_GAP := 6

const TITLE_COLOR := Color(0.94, 0.94, 0.92)
const COUNT_COLOR := Color(0.62, 0.66, 0.72)

## Une action dont tous les postes sont pris. Le même vert que le poste tenu d'une fiche :
## c'est le même fait, vu de l'autre côté.
const FULL_COLOR := Color(0.55, 0.82, 0.50)

## Une action à qui il manque du monde.
##
## Neutre et non orange depuis `I2`. L'orange veut dire *danger* sur les trois autres
## panneaux — famine, écrêtage au plafond, pertes d'une vague — et ici il voulait dire
## « pas encore rempli », c'est-à-dire l'état normal d'une action qu'on vient de poser. Une
## phase qui commence s'affichait donc tout en alarme, et le contresens a été signalé par
## la première personne à jouer une partie entière.
const WAITING_COLOR := Color(0.84, 0.86, 0.90)

const TITLE_FONT_SIZE := 14
const ROW_FONT_SIZE := 11

const TITLE := "Affectation"
const EMPTY_BOARD := "Aucune action posée — prendre une carte et cliquer une cible."
const AUTO_TEXT := "Auto"

## Le bouton qui replie le panneau, et celui qui le rouvre.
##
## Le chevron pointe vers **ce que le geste va faire** et non vers l'état courant : vers le
## bas quand le contenu est là et va disparaître, vers le haut quand il est plié et va
## remonter. C'est le sens que tous les replis d'interface emploient, et l'inverse se lit
## comme une flèche qui ment.
const FOLD_TEXT := "▾"
const UNFOLD_TEXT := "▸"
const NO_ONE := "—"

## Marque d'un palier franchi, sur la fiche de celui qui l'a franchi.
const PROMOTED_MARK := "↑ "

var _catalogue: CardCatalogue

## Le fond du panneau, retenu pour que le liseré de phase se **repeigne sur place**.
##
## Une `StyleBoxFlat` neuve à chaque image serait une allocation par image pour une couleur
## qui change deux fois par jour, et c'est exactement ce que `CLAUDE.md` refuse d'une vue
## rafraîchie en continu.
var _style: StyleBoxFlat

var _counts: Label
var _rows: VBoxContainer
var _more: Label
var _empty: Label
var _grid: GridContainer
var _auto: Button
var _fold: Button

## Le panneau est-il replié sur sa seule barre de tête ?
##
## État d'**affichage** et rien d'autre, donc il vit ici plutôt que dans le harnais — à
## l'inverse de la sélection d'un ouvrier, qui est un état de jeu et que la vue se contente
## de signaler. Le partage est celui que `HandView` a posé à `D2` : une vue ne décide pas
## de ce que le joueur tient, mais elle décide de sa propre taille.
var _folded := false

## Rang de ligne -> action qu'elle porte. C'est par lui que le clic retrouve son numéro,
## les boutons de ligne étant recyclés d'une image à l'autre.
var _row_actions: Array[int] = []

## Les lignes d'action, réutilisées et non reconstruites.
var _row_buttons: Array[Button] = []

## Ouvrier -> sa fiche. Le roster ne rétrécit pas en cours de run, et rien ne le remplit
## non plus — le recrutement est l'`OUVERT` de `DESIGN.md` 3.4 —, mais la table grandit
## sans qu'on ait à le savoir.
var _cards: Dictionary[StringName, WorkerCard] = {}

## Ouvrier -> ce que la dernière résolution lui a fait franchir.
##
## Il vit jusqu'à la résolution **suivante**, qui le remplace — y compris par rien. C'est
## le même cycle que le delta de `ResourceBar`, et il s'entretient tout seul : aucune
## liste de gestes à énumérer, donc aucun geste à oublier.
var _notes: Dictionary[StringName, String] = {}

## Panneau prêt à être ajouté à l'arbre, vide.
static func create(catalogue: CardCatalogue) -> AssignmentPanel:
	assert(catalogue != null, "panneau d'affectation sans catalogue")
	var panel := AssignmentPanel.new()
	panel.name = "AssignmentPanel"
	panel._catalogue = catalogue
	panel._style = _make_panel_style()
	panel.add_theme_stylebox_override("panel", panel._style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", BLOCK_GAP)

	column.add_child(panel._make_header())

	panel._rows = VBoxContainer.new()
	panel._rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._rows.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(panel._rows)

	panel._more = _make_text("", ROW_FONT_SIZE, COUNT_COLOR)
	panel._more.visible = false
	column.add_child(panel._more)

	panel._empty = _make_text(EMPTY_BOARD, ROW_FONT_SIZE, COUNT_COLOR)
	column.add_child(panel._empty)

	panel._grid = GridContainer.new()
	panel._grid.columns = CARD_COLUMNS
	panel._grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._grid.add_theme_constant_override("v_separation", CARD_GAP)
	panel._grid.add_theme_constant_override("h_separation", CARD_GAP)
	column.add_child(panel._grid)

	panel.add_child(column)
	return panel

## Redessine le panneau. `held` est l'ouvrier sélectionné, ou &"" si aucun ; `phase` est la
## phase courante, ou null hors run.
##
## Mise à jour sur place, appelable à chaque image : la règle que `E2` a écrite dans
## `CLAUDE.md`. Les lignes d'action sont recyclées et masquées plutôt que détruites, et
## les fiches ne naissent qu'une fois par ouvrier.
##
## La phase arrive en **argument** plutôt que d'être tirée du `RunState`, alors que tout le
## reste en vient. La raison est le hors-run : « quelle phase ? » n'a de réponse qu'avant la
## dernière journée, et `RunManager.phase()` porte déjà ce garde-fou. Le lui redemander ici
## en ferait un second exemplaire, donc un endroit de plus où la fin d'un run pourrait se
## lire autrement.
func show_state(state: RunState, held: StringName, phase: PhaseDef) -> void:
	assert(state != null, "panneau d'affectation sans run")
	# Aucun nom de phase n'entre ici, et c'est tout l'objet : la vue lit une couleur en
	# data, comme le renderer de terrain lit celle d'un `TerrainData`. Une table
	# `&"morning" -> bleu` écrite dans cet adapter serait le nom en dur que `DESIGN.md` 2
	# interdit, et elle rendrait fausse la promesse d'échanger la journée par un `.tres`.
	_style.border_color = NO_PHASE_COLOR if phase == null else phase.color
	var roster := state.roster()
	var assign := state.to_assignment()
	var places := Roster.capacity_for(state.city().to_snapshot(),
		state.balance().workforce)
	var free := state.free_workers().size()
	_counts.text = "%d au travail · %d libre(s) · %d/%d place(s)" % [
		assign.size(), free, roster.size(), places]

	# Replié, les lignes et les fiches sont invisibles : les remplir serait un balayage du
	# plateau et du roster par image pour des nœuds que personne ne regarde. La barre de
	# tête, elle, continue de dire l'essentiel — c'est ce qui rend le repli tenable.
	if not _folded:
		_fill_rows(state, assign)
		_fill_cards(state, assign, held)
	_auto.disabled = not state.cycle().permits(PhaseDef.ACTION_ASSIGN)
	_auto.text = AUTO_TEXT if _auto.disabled else "%s (%d)" % [AUTO_TEXT, free]

## Replie le panneau sur sa barre de tête, ou le rouvre. Rend le nouvel état, ce qui évite
## au harnais un accesseur de lecture qu'il serait le seul à appeler, et juste après.
##
## **Le panneau est la vue la plus haute du HUD**, et de loin : quatre lignes d'action plus
## six fiches d'ouvrier à trois pistes chacune. C'est lui qui fait déborder la colonne de
## droite depuis `W2`, et c'est lui qui recouvre le haut de la main aux journées chargées.
## Le replier est donc le geste qui rend la carte au joueur — et il la rend *entière*, ce
## que ni `H` ni `F1` ne font : `H` ne touche qu'au pavé de texte, et `F1` emporte la main
## avec le reste, donc empêche de jouer.
##
## Ce qui reste visible est délibéré. La barre de tête garde le compte — « 6 au travail · 0
## libre(s) » —, le bouton **Auto**, et le liseré de phase. Autrement dit : de quoi savoir
## s'il faut rouvrir, et de quoi ne pas avoir à le faire. Un repli qui n'aurait laissé qu'un
## titre aurait forcé un aller-retour à chaque phase.
## Le geste est **asymétrique**, et c'est voulu : replier masque les quatre blocs, rouvrir
## n'en remontre qu'un. Les trois autres — les lignes, le « aucune action posée » et le
## « et N autre(s) » — s'excluent entre eux selon ce que le plateau porte, et c'est
## `_fill_rows()` qui tranche, à l'image suivante. Les rallumer ici en montrerait deux à la
## fois le temps d'une image, et surtout recopierait sa règle à un second endroit.
func toggle_folded() -> bool:
	_folded = not _folded
	_fold.text = UNFOLD_TEXT if _folded else FOLD_TEXT
	_grid.visible = not _folded
	if _folded:
		_rows.visible = false
		_empty.visible = false
		_more.visible = false
	return _folded

## Retient qui vient de franchir un palier, pour l'annoncer sur sa fiche.
##
## `E2` a laissé cette dépendance ici en toutes lettres : `ProductionPanel` « ne nomme pas
## qui a franchi un palier » parce que le faire lui demanderait le `Roster`, « c'est-à-dire
## exactement la dépendance que `W2` existe pour porter ». Elle est portée — et elle l'est
## sur la **fiche de l'intéressé** plutôt que dans le compte rendu de récolte. Un palier
## appartient à la personne ; l'annoncer aux deux endroits rejouerait le doublon que `E2`
## a précisément défait.
func show_progress(report: ProgressReport) -> void:
	assert(report != null, "progression annoncée sans rapport")
	_notes.clear()
	for gain in report.gains():
		var parts := PackedStringArray()
		if gain.is_skill_level_up():
			parts.append("%s %d" % [String(gain.family()).capitalize(),
				gain.skill_level_after()])
		if gain.is_worker_level_up():
			parts.append("%s%d" % [WorkerCard.LEVEL_PREFIX, gain.worker_level_after()])
		if parts.is_empty():
			continue
		_notes[gain.worker()] = PROMOTED_MARK + " · ".join(parts)

# --- Les lignes d'action --------------------------------------------------------------

## Une ligne par action posée, dans l'ordre de pose — qui est aussi l'ordre dans lequel le
## bouton les sert. Ce que la ligne montre n'est donc pas décoratif : c'est la priorité que
## le joueur a exprimée en posant ses cartes.
##
## La **famille** y figure à côté du verbe, et c'est elle qui rend le classement lisible :
## sans elle, « pourquoi le bouton a-t-il envoyé Bo ici ? » n'a pas de réponse à l'écran.
## Elle est demandée au domaine, jamais devinée du nom de la carte.
func _fill_rows(state: RunState, assign: Assignment) -> void:
	var posted := state.board().to_plan().actions()
	var shown_count := mini(posted.size(), MAX_ROWS)
	_empty.visible = posted.is_empty()
	_rows.visible = not posted.is_empty()
	_row_actions.resize(shown_count)
	while _row_buttons.size() < shown_count:
		var button := _make_row(_row_buttons.size())
		_row_buttons.append(button)
		_rows.add_child(button)
	for index in _row_buttons.size():
		var shown := index < shown_count
		_row_buttons[index].visible = shown
		if not shown:
			continue
		var action := posted[index]
		_row_actions[index] = action.id()
		_row_buttons[index].text = _row_text(state, action, assign)
		_row_buttons[index].add_theme_color_override("font_color",
			_row_color(action, assign))
	_more.visible = posted.size() > shown_count
	if _more.visible:
		_more.text = MORE_TEXT % (posted.size() - shown_count)

func _row_text(state: RunState, action: PlayedAction, assign: Assignment) -> String:
	var held := assign.workers_on(action.id())
	var names := PackedStringArray()
	for worker in held:
		names.append(_name_of(state, worker))
	var family := StaffingAdvisor.family_of(action, state.terrain(),
		state.city().to_snapshot(), state.balance().actions)
	return "%s · %s · %s%d/%d · %s" % [_label_of(action.card()),
		String(family).capitalize() if not family.is_empty() else NO_ONE,
		action.target(), held.size(), action.capacity(),
		", ".join(names) if not names.is_empty() else NO_ONE]

## Vert quand les postes sont tenus, neutre tant qu'il en manque. C'est la seule chose que
## le panneau juge, et ce n'est pas une règle : c'est une soustraction.
##
## **L'orange en est sorti après `I2`**, et c'était un vrai contresens de lecture. Il veut
## dire *danger* sur les trois autres panneaux — famine, écrêtage au plafond, pertes d'une
## vague —, et ici il voulait dire « pas encore rempli », c'est-à-dire l'état normal d'une
## action qu'on vient de poser. Une phase qui commence s'affichait donc tout en alarme.
##
## Le vert reste, parce qu'il dit quelque chose que la fraction ne dit pas d'un coup d'œil :
## cette ligne-là est finie, on peut passer à la suivante. Et la fraction `1/2` porte déjà
## le compte, donc la couleur n'a jamais eu à le répéter.
func _row_color(action: PlayedAction, assign: Assignment) -> Color:
	if StaffingAdvisor.room_on(action, assign) > 0:
		return WAITING_COLOR
	return FULL_COLOR

# --- Les fiches ---------------------------------------------------------------------------

## Les fiches dans l'ordre du roster, absents compris.
##
## Un absent reste affiché, grisé, et c'est délibéré : `DESIGN.md` 3.9 veut qu'on sache
## qu'il existe et qu'il reviendra. Le retirer de l'écran le confondrait avec un mort.
func _fill_cards(state: RunState, assign: Assignment, held: StringName) -> void:
	for worker in state.roster().workers():
		var id := worker.id()
		if not _cards.has(id):
			var card := WorkerCard.create(state.balance().workforce)
			card.picked.connect(_on_card_picked.bind(id))
			card.released.connect(_on_card_released.bind(id))
			_cards[id] = card
			_grid.add_child(card)
		var note: String = _notes.get(id, "")
		_cards[id].show_worker(worker, _job_of(state, assign, id), note, id == held)

## Ce que cet ouvrier tient, en clair. Vide s'il ne tient rien.
func _job_of(state: RunState, assign: Assignment, worker: StringName) -> String:
	if not assign.is_assigned(worker):
		return ""
	var action := state.board().at(assign.action_of(worker))
	if action == null:
		return ""
	return "%s %s" % [_label_of(action.card()), action.target()]

func _name_of(state: RunState, worker: StringName) -> String:
	if not state.roster().has(worker):
		return String(worker)
	return state.roster().worker(worker).given_name()

func _label_of(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label

# --- Les clics ------------------------------------------------------------------------------

func _on_card_picked(worker: StringName) -> void:
	worker_picked.emit(worker)

func _on_card_released(worker: StringName) -> void:
	worker_released.emit(worker)

func _on_row_pressed(index: int) -> void:
	if index >= _row_actions.size():
		return
	action_picked.emit(_row_actions[index])

# --- La mise en place -------------------------------------------------------------------------

func _make_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", BLOCK_GAP)
	header.add_child(_make_text(TITLE, TITLE_FONT_SIZE, TITLE_COLOR))
	_counts = _make_text("", ROW_FONT_SIZE, COUNT_COLOR)
	_counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_counts)
	_auto = Button.new()
	_auto.text = AUTO_TEXT
	_auto.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	_auto.pressed.connect(_on_auto_pressed)
	header.add_child(_auto)
	_fold = Button.new()
	_fold.text = FOLD_TEXT
	_fold.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	_fold.pressed.connect(toggle_folded)
	header.add_child(_fold)
	return header

func _on_auto_pressed() -> void:
	auto_requested.emit()

## Une ligne d'action est un bouton plat : il porte le survol et le clic sans qu'on ait à
## les écrire, et un bouton plat ne se distingue d'un libellé que quand la souris passe
## dessus — ce qui est exactement l'indication qu'on veut donner.
func _make_row(index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.pressed.connect(_on_row_pressed.bind(index))
	return button

static func _make_text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(PANEL_MARGIN)
	style.border_width_top = PHASE_RULE
	style.border_color = NO_PHASE_COLOR
	return style
