extends Node
## Harnais de dev du Cycle de tour — jalon I3 : le jeu se relance. Jalon N2 : on le voit.
##
## C'est le harnais que `R0` avait supprimé, refait autour d'**un seul geste**. Celui d'avant
## faisait 2 178 lignes et pilotait une main de cartes, un roster, un plateau d'actions, une
## machine à phases et une bataille en attente ; celui-ci pose des chantiers et passe le
## tour. L'écart est le rescope, pas une régression de confort.
##
## Il ne décide rien. Il traduit un clic en appel de `RunManager` et une réponse de domaine
## en texte ou en couleur — et la règle vaut ici comme ailleurs : si un « if » sur la
## réserve, sur les bras ou sur la file apparaissait dans ce fichier, ce serait un bug
## d'architecture. Le domaine répond `not_enough_workers`, l'écran l'affiche.
##
## Clic gauche fonde puis bâtit, clic droit démolit, Entrée passe le tour, 1 à 8 choisissent
## le bâtiment, Tab pivote. La caméra garde Q et E, la molette, WASD et R.
##
## **Le rapport est imprimé sur la sortie standard autant que dessiné**, ce que le README
## demande à tous les harnais qui ne dessinent pas : un rapport qu'on ne voit qu'en lançant
## le jeu finit par ne plus être lu. `--chronicle` en fait un tableau.
##
## ---
##
## **`N2` sort trois choses du texte** et les met dans la colonne de droite : la fiche du
## bâtiment qu'on s'apprête à poser, le village, et la réserve qui y était déjà. Ce qui reste
## à gauche est ce qu'aucune vue ne dessine — l'état du run, les chantiers ouverts, ce que le
## dernier tour a rendu, le verdict du survol, et les touches.
##
## Le partage n'est pas cosmétique : `DESIGN.md` 3.4 fait du coût en bras **un argument de
## design**, « lisible avant de poser, exactement comme son coût en bois », et une table de
## catalogue ne peut pas dire ce que la réserve ne couvre pas. La fiche le demande au domaine
## et l'affiche ; le catalogue n'est plus qu'une liste de raccourcis.

## Seed du run. Fixe : deux lancements doivent se comparer.
const SEED := 1234

## Marge du rapport, en pixels.
const REPORT_MARGIN := 16.0

## Taille de la police du rapport, en pixels.
const REPORT_FONT_SIZE := 13

## Épaisseur du contour du texte. Sans lui le rapport devient illisible dès qu'il passe
## au-dessus d'une zone claire du terrain.
const REPORT_OUTLINE_SIZE := 4

## Chantiers et bâtiments endormis énumérés avant qu'une ligne ne compte le reste.
##
## `CLAUDE.md` : une liste qui suit la partie se borne. Un HUD a une hauteur fixe, un village
## peut porter un nombre quelconque de chantiers. Ce harnais n'a qu'un bloc de texte et pas
## de budget de hauteur à distribuer, donc un plafond nommé suffit — mais il est nommé, et
## non recopié dans trois boucles.
const LISTED := 6

## Colonnes de la table des raccourcis de bâtiment.
##
## Trois et non quatre, et c'est une contrainte de **largeur** plutôt qu'un goût : le rapport
## et la colonne de droite ne doivent jamais se croiser, et la seule séparation qui tienne
## quoi qu'il arrive est horizontale — la hauteur du rapport, elle, suit la partie. Une
## quatrième colonne portait sa ligne la plus large à 98 caractères, soit au-delà du bord
## gauche des panneaux.
const CATALOGUE_COLUMNS := 3

## Largeur d'une entrée de cette table, en caractères. Fixe, pour que les crochets de la
## sélection ne décalent pas ses voisines à chaque touche.
const CATALOGUE_WIDTH := 24

## Écart entre les trois panneaux de la colonne de droite, en pixels.
const PANEL_GAP := 8

## Rappel des touches, en pied du rapport.
##
## Quatre lignes courtes et non deux longues, pour la raison qui a ramené le catalogue à
## trois colonnes : ce bloc est le **plus large** du rapport et il en est aussi le **plus
## bas**, donc c'est lui qui allait chercher les panneaux de droite. `N2` l'a trouvé en
## sondant la mise en page, pas en regardant l'image — la ligne y passait sous une fiche qui
## la coupait, ce qui se lit comme une phrase qui s'arrête plutôt que comme un défaut.
const CONTROLS := "Clic gauche : fonder puis bâtir.   Clic droit : démolir.\nEntrée : passer le tour.   1-8 : bâtiment.   Tab : pivoter.\nQ/E : tourner la caméra.   Molette : zoom.   R : recadrer.\nWASD ou clic milieu : déplacer."

## Ce que le harnais tente d'ouvrir à chaque tour en mode chronique, dans cet ordre.
##
## Une politique **bête et écrite** : elle essaie chaque bâtiment de cette liste **une fois
## par tour**, dans cet ordre, et garde ce que le domaine accepte. Elle ne raisonne pas —
## elle n'a pas à être bonne, elle a à être la même d'un lancement à l'autre pour que deux
## équilibrages se comparent.
##
## **Un par tour et non autant que possible**, et le premier essai a montré pourquoi. À
## vider la file avec le premier bâtiment acceptable, la chronique enchaînait les cabanes,
## n'ouvrait jamais une ferme, et rendait un run mort de faim au dixième tour — un tableau
## parfaitement aligné dont **toutes les colonnes bougeaient**, et qui ne montrait pourtant
## rien de la boucle qu'il prétend montrer : la moitié nourriture n'était jamais jouée, et
## la même table serait sortie d'un jeu où les fermes n'existent pas. C'est très exactement
## le défaut que `CLAUDE.md` nomme depuis `F1`.
##
## La ferme est en tête pour la même raison : c'est la nourriture qui commande la population,
## donc les bras, donc tout le reste.
const CHRONICLE_POLICY: Array[StringName] = [&"farm", &"lumberjack_hut", &"house",
	&"warehouse", &"quarry"]

var _metrics: TerrainMetrics
var _world: DevWorld
var _grid: HeightGrid
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _label: Label
var _column: VBoxContainer
var _card: BuildingCard
var _people: PopulationBar
var _bar: ResourceBar
var _palette: CommodityPalette
var _catalogue: Array[BuildingData] = []
var _selected := 0
var _turns := 0
var _preview: PlacementResult
var _last_action := "—"

## Ce que la réserve a gagné ou perdu au dernier tour, ressource par ressource.
##
## Mesuré **avant/après** plutôt que déduit du rapport de production, et c'est délibéré : ce
## que la réserve a vraiment changé est la somme de la récolte, de l'écrêtage et du repas,
## et recomposer cette somme à partir de trois champs serait une seconde arithmétique à
## tenir d'accord avec la première. `CLAUDE.md` nomme ce raccourci depuis `F1` — une mesure
## qui emprunte un chemin plus court mesure le chemin plus court.
var _delta: Dictionary[StringName, int] = {}

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	var params := balance.terrain_gen
	_grid = TerrainGen.generate(SEED, params.map_size, params)
	_world = DevWorld.create(_grid, _metrics, balance)
	add_child(_world)
	RunManager.open(SEED, _grid)
	_catalogue = _known_buildings()
	_renderer = BuildingRenderer.create(_state().city(), _metrics)
	add_child(_renderer)
	_ghost = PlacementGhost.create(_metrics)
	add_child(_ghost)
	_palette = CommodityPalette.from_database()
	_label = _make_label()
	add_child(_corner(_label, Control.SIZE_SHRINK_BEGIN, Control.SIZE_SHRINK_BEGIN))
	add_child(_corner(_make_column(), Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_END))
	EventBus.turn_resolved.connect(_on_turn_resolved)
	_world.settle_at(DevWorld.REST)
	if DevShot.has_flag(DevShot.CHRONICLE_FLAG):
		_write_chronicle()
		return
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne — donc le
## fantôme, le rapport et la barre se refont à chaque image. Les vues se mettent à jour **sur
## place** et ne se reconstruisent pas, ce qui rend l'appel gratuit et surtout dispense
## d'énumérer les gestes qui touchent leur sujet : un oubli dans cette liste se lirait comme
## un compteur qui ne bouge pas.
func _process(_delta_seconds: float) -> void:
	_refresh_preview()
	_label.text = _report()
	# Un seul relevé de la ville par image, partagé par les deux vues qui l'interrogent :
	# le plan d'occupation et le manque de bras se posent à la même ville, et la projeter
	# deux fois ouvrirait la porte à ce qu'ils répondent sur deux instants différents.
	var city := _state().city().to_snapshot()
	_bar.show_ledger(_state().ledger(), _delta)
	_people.show_people(_state().people(),
		Staffing.resolve(city, _state().people().headcount()))
	_show_card(city)

## Aucun geste pendant qu'une transition joue.
##
## Le refus est **ici et non dans les fonctions de geste**, et la distinction compte : c'est
## un verrou d'**entrée**, pas une règle. Une résolution scriptée — la chronique, une
## capture — emprunte les mêmes fonctions de geste et n'a aucune raison d'attendre une
## animation qu'elle ne regarde pas. Le poser plus bas bloquerait les deux.
##
## Il ne mange que ce qui lui est destiné : la caméra vit sous `DevWorld` et voit l'entrée
## avant ce nœud, donc on peut continuer de tourner et de zoomer pendant qu'un jour passe.
## C'est voulu — la transition interdit d'**agir**, pas de regarder.
func _unhandled_input(event: InputEvent) -> void:
	if _world.is_in_transition():
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_place_here()
		MOUSE_BUTTON_RIGHT:
			_demolish_here()
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		_turns = posmod(_turns + 1, BuildingData.QUARTER_TURNS)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_pass_turn()
		get_viewport().set_input_as_handled()
		return
	var index := event.keycode - KEY_1
	if index < 0 or index >= _catalogue.size():
		return
	_selected = index
	get_viewport().set_input_as_handled()

# --- les gestes, et eux seuls -----------------------------------------------

## Fonde si le Cœur n'est pas posé, ouvre un chantier sinon.
##
## **Un seul bouton pour les deux**, parce que le joueur ne fait qu'un geste — désigner une
## cellule — et que ce qui s'y passe est une asymétrie du domaine, pas de l'intention. C'est
## le run lui-même qui dit laquelle des deux portes pousser, et ce fichier ne juge rien : il
## lit `awaits_its_heart()`, qui est une question d'état, comme une vue demande « la réserve
## est-elle pleine ? ».
func _place_here() -> void:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		_last_action = "Rien sous le curseur."
		return
	if _state().awaits_its_heart():
		_report_gesture("Fondation", RunManager.found(hovered.cell(), _turns))
		return
	var data := _selected_building()
	if data == null:
		_last_action = "Aucun bâtiment sélectionné."
		return
	_report_gesture("Chantier %s" % data.label,
		RunManager.build(data.id, hovered.cell(), _turns))

func _demolish_here() -> void:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		_last_action = "Rien sous le curseur."
		return
	_report_gesture("Démolition", RunManager.demolish(hovered.cell()))

## Passe le tour et retient ce que la réserve y a gagné ou perdu.
##
## Le relevé d'avant est pris **ici** et non dans l'auditeur du signal : quand
## `turn_resolved` arrive, la réserve a déjà changé. C'est la même précaution que `I2` a
## apprise sur les morts d'un rapport — le relevé se prend avant le geste qui le rend faux.
func _pass_turn() -> void:
	if _state().is_over():
		_last_action = "Le run est terminé."
		return
	if _state().awaits_its_heart():
		_last_action = "Poser le Cœur avant de passer le tour."
		return
	var before := _state().ledger().amounts()
	var report := RunManager.end_turn()
	_delta = _difference(before, _state().ledger().amounts())
	_last_action = "Tour %d résolu." % report.turn()

## Ce qu'un tour résolu change à l'écran : le bâti, et un jour qui passe.
##
## **Le soleil fait une révolution entière**, puis revient se poser à midi. C'est la seule
## chose de cet écran qui dise le temps en le montrant plutôt qu'en l'écrivant, et elle ne
## dit pas *quel* jour on est : la lumière au repos est la même au premier tour et au
## vingtième. Le run fini est la seule exception, et il tombe dans la nuit.
##
## Il passe par le bus plutôt que par le retour de `end_turn()`, ce qui est le partage que
## `CLAUDE.md` veut — un adapter entend ce que le domaine a fait, il ne va pas le chercher.
## Et c'est ce qui garantit qu'une résolution scriptée redessine autant qu'un clic : le
## défaut que `P1a` a trouvé venait précisément d'un chemin qui court-circuitait ça.
func _on_turn_resolved(_report: TurnReport) -> void:
	_redraw_city()
	if _state().is_over():
		_world.fall_to_night()
		return
	_world.pass_a_day()

## Rapporte ce que le domaine a répondu, sans le juger, et redessine si ça a bougé.
func _report_gesture(what: String, result: PlayResult) -> void:
	if not result.is_ok():
		_last_action = "%s refusée : %s" % [what, result.reason()]
		return
	_redraw_city()
	var extra := ""
	if result.workers() > 0:
		extra = ", %d bras" % result.workers()
	if result.homeless() > 0:
		extra += ", %d habitant(s) à la rue" % result.homeless()
	if result.spilled() > 0:
		extra += ", %d unité(s) renversée(s)" % result.spilled()
	_last_action = "%s en %s%s." % [what, result.anchor(), extra]

# --- ce que le fantôme montre ------------------------------------------------

## Réévalue ce que donnerait une pose sous le curseur, et le montre.
##
## Il n'interroge que le **placement**, donc la carte, et pas les trois coûts. Ce n'est pas
## un oubli : le fantôme dit où la forme tient, la ligne de survol dit ce que le domaine
## répondrait pour de bon. Les deux passent par la même porte quand on clique, et c'est
## `RunOrchestrator` qui les ordonne — la carte d'abord, précisément pour que la couleur du
## fantôme ne soit jamais contredite par la réponse.
func _refresh_preview() -> void:
	var hovered := _world.cursor().hovered()
	var data := _ghost_building()
	if not hovered.is_hit() or data == null:
		_preview = null
		_ghost.clear()
		return
	_preview = PlacementValidator.validate(_state().city(), _state().terrain(), data,
		hovered.cell(), _turns)
	# La hauteur vient du survol et non du résultat : un refus n'en a pas, et c'est
	# justement sur un refus qu'il faut voir le fantôme.
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), _preview)

## Le bâtiment que le fantôme dessine : le Cœur tant qu'il n'est pas posé, la sélection
## ensuite. Le fantôme montre donc toujours ce que le clic gauche ferait.
func _ghost_building() -> BuildingData:
	if _state().awaits_its_heart():
		return _state().building(_state().balance().run.starting_building)
	return _selected_building()

# --- ce que la fiche montre --------------------------------------------------

## Décrit ce que le clic gauche poserait, et ce que le village n'a pas pour le payer.
##
## **La fiche décrit le même bâtiment que le fantôme**, par le même appel : la carte colorée
## et le panneau ne peuvent donc pas parler de deux choses différentes, ce qui serait le plus
## silencieux des défauts d'écran.
##
## Les deux manques viennent du domaine et ne sont **pas** recalculés ici. Celui des bras
## surtout : il se pose à la demande totale du village et non aux bras que le plan laisse
## libres, si bien qu'une soustraction faite dans ce fichier serait plus permissive que la
## règle, et inviterait à un geste que `open_site()` refuserait.
##
## Un run fini n'a pas de fiche : `RunOrchestrator` refuse tout dessus, et une vue qui invite
## à un geste doit demander si le geste est possible.
func _show_card(city: CitySnapshot) -> void:
	if _state().is_over():
		_card.show_nothing("Run terminé")
		return
	var data := _ghost_building()
	if data == null:
		_card.show_nothing("Aucun bâtiment choisi")
		return
	_card.show_building(data, _turns, _state().ledger().shortfall(data.cost),
		Staffing.hands_short(city, _state().people().headcount(), data.workers),
		_neighbourhood_of(data))

## Ce que le voisinage de la case survolée rapporterait à ce bâtiment.
##
## C'est le **même appel** que celui du résolveur de production — `Adjacency` ne sait pas si le
## bâtiment qu'on lui décrit est posé —, donc la fiche ne peut pas promettre autre chose que ce
## que le tour versera. `DESIGN.md` 3.2 réclame ce delta en temps réel, et un second calcul
## écrit ici aurait été le doublon que le domaine a justement été taillé pour éviter.
##
## Rien de survolé rend un rapport **vide** et non un rapport à zéro : la fiche annonce alors
## la promesse de la règle plutôt que de fausses nouvelles. La distinction est celle
## qu'`AdjacencyReport.is_empty()` porte.
func _neighbourhood_of(data: BuildingData) -> AdjacencyReport:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return AdjacencyReport.none()
	return Adjacency.inspect(data, hovered.cell(), _turns, _state().terrain())

## Redessine le bâti, endormis compris.
##
## **Un seul chemin pour les trois gestes qui changent la ville**, et c'est ce qui garantit
## que le sommeil se remontre : ouvrir un chantier peut endormir le bâtiment d'à côté aussi
## sûrement qu'une famine, et trois appels séparés auraient été trois occasions d'oublier la
## liste. Un oubli se lirait comme une couleur qui ne change pas, ce que rien ne signale.
func _redraw_city() -> void:
	_renderer.rebuild(_state().city(), [], _state().staffing().asleep())

# --- le rapport --------------------------------------------------------------

func _report() -> String:
	var lines := PackedStringArray()
	lines.append(_header_line())
	lines.append("")
	lines.append(_sites_block())
	lines.append("")
	lines.append(_catalogue_block())
	lines.append("")
	lines.append(_turn_block())
	lines.append("")
	lines.append(_hover_line())
	lines.append(_last_action)
	lines.append("")
	lines.append(CONTROLS)
	return "\n".join(lines)

func _header_line() -> String:
	var state := _state()
	var size := _grid.size()
	if state.is_over():
		# Le verdict passe à la ligne : d'un seul tenant il porterait le rapport à cent
		# vingt caractères, donc jusque sous les panneaux de droite.
		return "Run — seed %d, %d x %d\n%s\n%s" % [SEED, size.x, size.y, _verdict_head(),
			_verdict_terms()]
	# Une vue qui invite à un geste doit demander si le geste est possible : pendant une
	# transition il ne l'est pas, et l'écran doit le dire plutôt que d'avaler les clics en
	# silence. C'est la règle que `I2b` a payée sur une main affichée à pleine encre dans
	# une phase qui n'autorisait rien.
	var stage := "à fonder" if state.awaits_its_heart() else "en cours"
	if _world.is_in_transition():
		stage = "le jour passe…"
	return "Run — seed %d, %d x %d   tour %d/%d, %s" % [
		SEED, size.x, size.y, state.turn(), state.balance().run.turns, stage]

## Le verdict et sa somme.
func _verdict_head() -> String:
	var outcome := _state().outcome()
	var issue := "VICTOIRE" if outcome.is_victory() else "DÉFAITE (%s)" % outcome.cause()
	return "%s au tour %d — %d points" % [issue, outcome.turn(), outcome.score()]

## Les quatre termes du score.
##
## Ils sont affichés à côté du total et non à sa place : un écran de fin qui n'annoncerait
## qu'un nombre ne dirait pas ce qui l'a fait.
func _verdict_terms() -> String:
	var outcome := _state().outcome()
	return "  [%d ressources, %d bâtiment(s), %d habitant(s), %d PV de Cœur]" % [
		outcome.resources(), outcome.buildings(), outcome.inhabitants(),
		outcome.heart_hit_points()]

## Le verdict entier sur une ligne, pour la chronique — qui écrit sur la sortie standard,
## où aucune largeur ne contraint.
func _verdict_line() -> String:
	return "%s %s" % [_verdict_head(), _verdict_terms()]

func _sites_block() -> String:
	var state := _state()
	var lines := PackedStringArray()
	lines.append("Chantiers %d ouvert(s)" % state.open_sites())
	var listed := 0
	var hidden := 0
	for building in state.city().buildings():
		if building.is_complete():
			continue
		if listed >= LISTED:
			hidden += 1
			continue
		listed += 1
		lines.append("    %-18s %s   %d/%d tour(s)" % [building.data().label,
			building.anchor(), building.progress(), building.data().site_turns])
	if hidden > 0:
		lines.append("    … et %d autre(s)" % hidden)
	lines.append(_sleep_line())
	return "\n".join(lines)

## Ce qui dort, par **nature** de bâtiment.
##
## Il est ici et non dans `PopulationBar` parce que ce n'est pas de la même nature que ce
## qu'elle montre : elle tient un compteur — tant de bras pris, tant de libres, tant de places
## —, alors qu'une liste d'endormis nomme des choses posées sur la carte. C'est aussi
## pourquoi le vrai « lesquels ? » est sur le plateau, qui les éteint en couleur : une ligne de
## texte peut dire *combien* et *de quel genre*, elle ne peut pas désigner une case.
##
## Par nature et non par ancre, et c'est la règle que `I2` a laissée au projet : un joueur
## corrige « cette ferme dort, il me manque un toit », pas « (17, 12) dort ». Les endormis
## sont debout, donc les chercher dans la ville est sûr — l'inverse du piège de `I2`, qui
## portait sur des morts qu'un rapport retire avant de le rendre.
##
## L'ordre est celui de pose, donc celui dans lequel le village s'est éteint : la première
## nature nommée est la plus ancienne à avoir cédé, ce qui est l'information la plus lourde de
## la ligne. Un tri alphabétique l'aurait perdue.
func _sleep_line() -> String:
	var asleep := _state().staffing().asleep()
	if asleep.is_empty():
		return "Aucun bâtiment en sommeil."
	var counts: Dictionary[String, int] = {}
	for anchor in asleep:
		var building := _state().city().building_at(anchor)
		# Une ancre que la ville ne porte plus : impossible sur un plan fraîchement résolu,
		# et pas une raison de faire tomber un rapport si ça arrivait un jour.
		var kind := "?" if building == null else building.data().label
		counts[kind] = counts.get(kind, 0) + 1
	var parts := PackedStringArray()
	var hidden := 0
	for kind in counts:
		if parts.size() >= LISTED:
			hidden += counts[kind]
			continue
		parts.append("%d %s" % [counts[kind], kind])
	var text := "En sommeil : %s" % ", ".join(parts)
	if hidden > 0:
		text += " (+%d)" % hidden
	return text

## Le raccourci clavier de chaque bâtiment, et **rien d'autre**.
##
## `N2` lui retire ses trois colonnes de chiffres — coût, bras, chantier —, qui sont
## désormais la fiche du bâtiment sélectionné. Les laisser ici en aurait fait un doublon, et
## un doublon qui ment la moitié du temps : la fiche sait ce que la réserve ne couvre pas,
## une table de catalogue ne le sait pas. `DESIGN.md` 3.4 demandait d'ailleurs une **fiche**,
## et cette table était ce qui la remplaçait en attendant.
##
## Les entrées sont de largeur fixe : les crochets de la sélection ne doivent pas décaler
## leurs voisines à chaque touche.
func _catalogue_block() -> String:
	var lines := PackedStringArray()
	lines.append("Bâtiments")
	var row := PackedStringArray()
	for index in _catalogue.size():
		var entry := "%d %s" % [index + 1, _catalogue[index].label]
		var marked := "[%s]" % entry if index == _selected else " %s" % entry
		row.append(marked.rpad(CATALOGUE_WIDTH))
		if row.size() == CATALOGUE_COLUMNS:
			lines.append("  %s" % "".join(row))
			row = PackedStringArray()
	if not row.is_empty():
		lines.append("  %s" % "".join(row))
	return "\n".join(lines)

## Ce que le dernier tour a fait. Six lignes au plus, et chacune est un **fait du tour** —
## rien de ce qui s'y trouve n'est relisible sur l'état une fois le tour clos.
func _turn_block() -> String:
	var report := _state().last_report()
	if report == null:
		return "Dernier tour : aucun — le run n'a pas encore été joué."
	var lines := PackedStringArray()
	lines.append("Tour %d" % report.turn())
	var production := report.production()
	var yielded := _palette.bundle_text(production.produced())
	var lost := "" if production.overflow() == 0 \
		else "   (%d perdue(s) au plafond)" % production.overflow()
	lines.append("    récolte    %s%s" % [yielded, lost])
	if production.has_dormant():
		lines.append("    en sommeil %s" % _cells(production.dormant()))
	var upkeep := report.upkeep()
	var meal := "%d/%d" % [upkeep.paid(), upkeep.due()]
	if upkeep.is_starving():
		meal += "   FAMINE, %d sans manger" % upkeep.unfed()
	if upkeep.arrived() > 0:
		meal += "   +%d habitant(s)" % upkeep.arrived()
	if upkeep.lost() > 0:
		meal += "   -%d habitant(s)" % upkeep.lost()
	lines.append("    repas      %s" % meal)
	if not report.advanced().is_empty():
		lines.append("    chantiers  %s avancé(s)%s" % [_cells(report.advanced()),
			"" if report.completed().is_empty()
				else ", %s achevé(s)" % _cells(report.completed())])
	if not report.stalled().is_empty():
		lines.append("    à l'arrêt  %s — faute de bras" % _cells(report.stalled()))
	return "\n".join(lines)

## Ce que le curseur désigne, et le verdict du domaine sur une pose à cet endroit.
## C'est la légende du fantôme : la couleur dit oui ou non, cette ligne dit pourquoi.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit() or _preview == null:
		return "Survol : —"
	var cell := hovered.cell()
	var verdict := "posable" if _preview.is_ok() else String(_preview.reason())
	return "Survol : (%d, %d)   h = %d   %s   %s   -> %s%s" % [
		cell.x, cell.y, hovered.height(), _grid.terrain_at(cell).id,
		_orientation(_turns), verdict, _hovered_site()]

func _hovered_site() -> String:
	var building := _state().city().building_at(_world.cursor().hovered().cell())
	if building == null:
		return ""
	var stage := "achevé" if building.is_complete() \
		else "chantier %d/%d" % [building.progress(), building.data().site_turns]
	return "   |   %s : %s" % [building.data().label, stage]

# --- la chronique ------------------------------------------------------------

## Rejoue le run entier sans écran et imprime ce qu'il donne, tour par tour.
##
## **Ce que cette table doit montrer** : que la boucle de `DESIGN.md` 2 tourne — qu'un
## village fondé sur les chiffres de `data/balance/` produit, mange, grandit et bâtit
## jusqu'au verdict —, et où elle se casse quand elle se casse. C'est l'instrument que `B1`
## réclamera, et c'est aussi le seul contrôle qui emprunte le chemin de résolution complet :
## ni le parsing ni les tests ne jouent vingt tours d'affilée sur la data réelle.
##
## **Ce qu'elle ne montre pas, et ne montrera jamais** : si le jeu est bon. La politique
## ci-dessous est bête — elle ouvre le premier bâtiment que le domaine accepte —, donc les
## chiffres sont un **plancher** et non une partie bien jouée. Une ligne qui s'effondre est
## un vrai problème d'équilibrage ; une ligne qui monte lentement ne prouve rien.
##
## Elle passe par `_place_at()` et `_pass_turn()`, c'est-à-dire par les fonctions de geste du
## harnais et non par le domaine en direct. C'est la règle que `P1a` a payée : un scripteur
## qui court-circuite les gestes finit par mesurer autre chose que ce que le joueur fait.
func _write_chronicle() -> void:
	print("[run_harness] chronique — seed %d, %d tours"
		% [SEED, _state().balance().run.turns])
	print("[run_harness] politique : %s, au premier emplacement accepté" % ", ".join(
		Array(CHRONICLE_POLICY).map(func(id: StringName) -> String: return String(id))))
	_place_at(_state().suggested_heart_anchor())
	print("  Habitants, bras libres et endormis sont relevés APRÈS la résolution ; les")
	print("  chantiers ouverts le sont AVANT, au moment où le tour va les faire avancer.")
	print("  tour | hab. | libres | dort | ouverts | finis | récolte                | repas | réserve")
	while not _state().is_over():
		_open_what_we_can()
		var turn := _state().turn()
		# Relevé avant la résolution, et c'est le correctif d'un premier tableau qui
		# comptait les chantiers **après** : un chantier d'un tour s'ouvre et s'achève dans
		# la même ligne, donc la colonne affichait 0 pendant que le village bâtissait une
		# cabane par tour. Le chiffre était exact et répondait à une autre question que la
		# sienne — le défaut que `CLAUDE.md` nomme depuis `F2b`.
		var sites := _state().open_sites()
		_pass_turn()
		var report := _state().last_report()
		print("  %4d | %4d | %6d | %4d | %7d | %5d | %-22s | %5s | %d/%d" % [
			turn, _state().people().headcount(), _state().staffing().available(),
			_state().staffing().asleep().size(), sites, report.completed().size(),
			_palette.bundle_text(report.production().produced()),
			"%d/%d" % [report.upkeep().paid(), report.upkeep().due()],
			_state().ledger().total(), _state().ledger().capacity()])
	print("[run_harness] %s" % _verdict_line())
	print("[run_harness] la table dit que la boucle tourne et où elle casse ; elle ne dit")
	print("[run_harness] pas si le jeu est bon — la politique est bête, donc c'est un plancher.")
	get_tree().quit(OK)

## Essaie chaque bâtiment de la politique une fois, dans l'ordre.
##
## Aucune règle n'est évaluée ici : on **essaie**, et c'est le refus du domaine qui arrête.
## C'est ce qui garantit que la chronique ne puisse pas diverger des règles qu'elle mesure —
## une politique qui testerait les bras, la file ou la bourse elle-même mesurerait sa propre
## copie de ces règles plutôt que les vraies.
func _open_what_we_can() -> void:
	for id in CHRONICLE_POLICY:
		_place_first_accepted(id)

## Pose ce bâtiment sur la première ancre que le domaine accepte. Faux si aucune ne convient.
func _place_first_accepted(id: StringName) -> bool:
	var data := _state().building(id)
	if data == null:
		return false
	var size := _state().terrain().size()
	for y in size.y:
		for x in size.x:
			if RunManager.build(id, Vector2i(x, y)).is_ok():
				_redraw_city()
				return true
	return false

## Choisit le n-ième bâtiment du catalogue, numéroté comme au clavier. 0 ne touche à rien.
##
## Un rang hors catalogue est ignoré plutôt que refusé : une capture doit montrer quelque
## chose plutôt qu'échouer sur un chiffre, comme `--shot-hover` se replie sur le centre de la
## carte devant une virgule mal placée.
func _select(rank: int) -> void:
	if rank <= 0 or rank > _catalogue.size():
		return
	_selected = rank - 1

## Fonde sur cette cellule, en passant par la porte que le clic emprunte.
func _place_at(cell: Vector2i) -> void:
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(cell)
	_place_here()

# --- capture -----------------------------------------------------------------

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-passes 6] [--shot-hover x,y]
##
## `src/adapters/` n'est pas testé et les trois commandes de vérification ne regardent pas
## l'écran : cette capture est donc le contrôle principal du jalon, et non un supplément.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	# La souris est à (0, 0) dans une session pilotée en ligne de commande : sans ça le
	# survol tomberait hors carte et la capture ne montrerait aucun fantôme.
	# La fondation prend la case que le run propose lui-même : `--shot-hover` désigne la
	# cellule que le CURSEUR montrera, et lui faire aussi choisir le Cœur donnerait deux
	# sens au même drapeau. `--shot-unfounded` la saute, ce qui est le seul moyen de
	# photographier l'écran de fondation depuis que `N2` lui donne une fiche à lui.
	if not DevShot.has_flag(DevShot.SHOT_UNFOUNDED_FLAG):
		_place_at(_state().suggested_heart_anchor())
	for _turn in DevShot.argument(DevShot.SHOT_PASSES_FLAG).to_int():
		if _state().is_over() or _state().awaits_its_heart():
			break
		_open_what_we_can()
		_pass_turn()
	# Le curseur cesse de piocher sous la souris **ici** et non dans `_place_at()` : celle-ci
	# ne passe pas quand on capture l'écran de fondation, et le survol retombait alors sur la
	# position réelle de la souris — (0, 0), donc hors carte, donc pas de fantôme du tout.
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_grid.size() / 2))
	_select(DevShot.argument(DevShot.SHOT_SELECT_FLAG).to_int())
	_turns = DevShot.argument(DevShot.SHOT_ROTATE_FLAG).to_int()
	var turns := DevShot.argument(DevShot.SHOT_TURNS_FLAG).to_int()
	if turns != 0:
		_world.rig().rotate_steps(turns)
		var seconds: float = GameDatabase.get_balance().camera.rotation_seconds
		await get_tree().create_timer(seconds).timeout
	# Le soleil ne parcourt pas sa course en trois images de chauffe : sans ce pas forcé,
	# une capture scriptée photographierait une lumière arrêtée n'importe où. Elle se pose
	# donc là où le jeu la laisse entre deux tours — à midi, ou dans la nuit si le run est
	# fini —, ce qui est aussi ce qui rend deux captures comparables. La sonde ci-dessous
	# a bougé le soleil, donc ce réglage vient forcément après elle.
	_world.settle_at(DevShot.sun_moment(
		DevWorld.MIDNIGHT if _state().is_over() else DevWorld.REST))
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	var camera := _world.rig().get_camera()
	print("[run_harness] cadrage : camera.size = %.3f, viewport = %s"
		% [camera.size, get_viewport().get_visible_rect().size])
	print("[run_harness] %s" % _probe_the_sun())
	print("[run_harness] %s" % _probe_the_light())
	print("[run_harness] %s" % _probe_the_layout())
	print("[run_harness] %s" % _hover_line())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[run_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

# --- plomberie ---------------------------------------------------------------

func _state() -> RunState:
	return RunManager.state()

## Tous les bâtiments de data/, triés par identifiant, **moins le Cœur**.
##
## Il en sort à `N2`, et c'est la règle de `I2b` appliquée à une liste : une vue qui invite à
## un geste doit demander si le geste est possible. `open_site()` refuse le bâtiment
## d'ouverture par principe — le Cœur se **fonde**, il ne se bâtit ni ne se démolit *(cf.
## `DESIGN.md` 4.2)* —, donc une touche numérotée pour lui ne pouvait mener qu'à un refus.
## `I3` avait corrigé le domaine, qui acceptait d'en ouvrir un second ; ce jalon corrige
## l'écran, qui le proposait encore.
##
## Sa fiche reste atteignable, et au seul moment où elle veut dire quelque chose : tant que
## le run attend son Cœur, c'est lui que le fantôme dessine et lui que la fiche décrit.
func _known_buildings() -> Array[BuildingData]:
	var opener := _state().balance().run.starting_building
	var buildings: Array[BuildingData] = []
	for id in GameDatabase.list_building_ids():
		if id == opener:
			continue
		buildings.append(GameDatabase.get_building(id))
	return buildings

func _selected_building() -> BuildingData:
	if _selected < 0 or _selected >= _catalogue.size():
		return null
	return _catalogue[_selected]

## Ce que la réserve a gagné, ressource par ressource. Les ressources disparues comptent
## comme des pertes, sans quoi une famine qui vide la nourriture n'annoterait rien.
func _difference(before: Dictionary[StringName, int],
		after: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var delta: Dictionary[StringName, int] = {}
	for id in _palette.ordered():
		var change: int = after.get(id, 0) - before.get(id, 0)
		if change != 0:
			delta[id] = change
	return delta

## Une liste de cellules en clair, bornée. Une liste qui suit la partie se borne.
func _cells(cells: Array[Vector2i]) -> String:
	var parts := PackedStringArray()
	for index in mini(cells.size(), LISTED):
		parts.append("%s" % cells[index])
	var text := ", ".join(parts)
	if cells.size() > LISTED:
		text += " (+%d)" % (cells.size() - LISTED)
	return text

## L'orientation en clair. Les crans seuls ne disent rien à la lecture d'une capture.
func _orientation(turns: int) -> String:
	return "%d/4" % posmod(turns, BuildingData.QUARTER_TURNS)

## Place cette vue dans un coin, par un conteneur et **jamais** par des ancres calculées.
##
## `E2` a essayé les ancres et a payé deux pièges d'un coup, tous deux invisibles au parsing
## comme aux tests : `set_anchors_preset()` prend un booléen là où l'on croit passer un mode,
## et `get_combined_minimum_size()` lu juste après avoir ajouté des enfants rend encore la
## valeur d'avant. Un `MarginContainer` plein écran dont l'enfant porte `SIZE_SHRINK_BEGIN`
## ou `SIZE_SHRINK_END` ne se trompe sur aucun des deux, ni à la dixième mise à jour.
##
## Le rapport et la colonne sont dans des coins **opposés** et non empilés : `W2` demande que
## deux vues qui grandissent l'une vers l'autre vivent dans le même conteneur, et c'est
## justement pourquoi celles-ci n'y sont pas — le rapport grandit vers le bas depuis le
## haut-gauche, la colonne vers le haut depuis le bas-droite, et rien ne les fait se
## rencontrer. La sonde de mise en page le vérifie en pixels plutôt qu'on ne l'espère.
func _corner(view: Control, horizontal: Control.SizeFlags,
		vertical: Control.SizeFlags) -> MarginContainer:
	var slot := MarginContainer.new()
	slot.name = "%sSlot" % view.name
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		slot.add_theme_constant_override("margin_%s" % side, int(REPORT_MARGIN))
	view.size_flags_horizontal = horizontal
	view.size_flags_vertical = vertical
	slot.add_child(view)
	return slot

## Les trois panneaux de droite, empilés du plus variable au plus stable.
##
## **Ils sont dans le même conteneur**, ce que `W2` exige de deux vues qui grandissent l'une
## vers l'autre : posées dans des coins voisins elles tiennent tant que rien n'est chargé, et
## se recouvrent à la première partie qui l'est. Empilées, elles se poussent.
##
## **L'ordre et l'ancre vont ensemble**, et c'est la règle de `P1a` : dans une pile, l'ancre
## se met du côté de la vue la plus stable, et le mouvement se paie par la plus variable. La
## réserve est de hauteur fixe, donc elle est en bas et la colonne y est ancrée ; la fiche
## change de taille avec le bâtiment choisi, donc elle est en haut et c'est elle qui bouge.
## L'inverse aurait fait sauter la barre de réserve à chaque touche du clavier.
func _make_column() -> VBoxContainer:
	_column = HudStyle.column(PANEL_GAP)
	_column.name = "RightColumn"
	_card = BuildingCard.create(_palette)
	_people = PopulationBar.create()
	_bar = ResourceBar.create(_palette)
	_column.add_child(_card)
	_column.add_child(_people)
	_column.add_child(_bar)
	return _column

## Sonde du cycle solaire : le soleil repart-il **à chaque** tour ?
##
## **Ce que cette ligne doit montrer**, et c'est la seule chose qu'aucune image ne peut dire :
## qu'une seconde journée bouge autant que la première. La première version de la course
## visait un moment absolu, si bien qu'elle se jouait au premier jour et à aucun autre —
## rien ne plantait, rien ne compilait de travers, et les quatre captures du cycle étaient
## toutes justes, puisqu'une image fixe ne dit rien d'un mouvement **absent**.
##
## Elle joue donc deux journées de suite, en pas forcés d'un quart de course, et imprime où
## le soleil s'arrête à chaque quart. Deux séries identiques et non triviales — `0.50, 0.75,
## 0.00, 0.25` — disent que la course tourne et se rejoue ; une seconde série figée sur
## `0.25` serait le bug, à la lecture.
##
## Elle dit aussi le **verrou de transition** aux deux bouts de chaque journée, et la seconde
## moitié compte plus que la première : un verrou qui se poserait sans se lever bloquerait la
## partie pour de bon, sans rien signaler et sans qu'aucune image ne le montre. Un verrou qui
## ne se lève jamais et une course qui ne part pas se ressemblent d'ailleurs parfaitement de
## l'extérieur — c'est la même question sous deux angles.
##
## Elle passe par `pass_a_day()`, la fonction que le tour appelle vraiment. Un scripteur qui
## emprunte un autre chemin mesure cet autre chemin : `P1a` a payé trois jalons pour cette
## phrase.
func _probe_the_sun() -> String:
	var days := PackedStringArray()
	for _day in 2:
		var quarters := PackedStringArray()
		_world.pass_a_day()
		quarters.append("verrou %s" % ("posé" if _world.is_in_transition() else "ABSENT"))
		for _quarter in 4:
			_world.step_the_course(DevWorld.DAY_SECONDS / 4.0)
			quarters.append("%.2f" % _world.moment())
		quarters.append("verrou %s" % ("levé" if not _world.is_in_transition() else "COINCÉ"))
		days.append("[%s]" % ", ".join(quarters))
	return "soleil : deux journées jouées d'affilée, %s" % " puis ".join(days)

## Sonde de mise en page : les deux blocs du HUD tiennent-ils sans se marcher dessus ?
##
## **Ce que cette ligne doit montrer**, et c'est ce qu'aucun coup d'œil sur une capture ne
## tranche : que le rapport de gauche et la colonne de droite ne se recouvrent pas, et
## qu'aucun des deux ne sort de l'écran. Les deux défauts se manifestent **le plus tard
## possible** — au village le plus chargé, à la fiche la plus longue, au run le plus long —,
## donc justement pas sur l'image qu'on regarde en écrivant le jalon.
##
## Elle a payé son écriture le jour même : au **premier** tour, la dernière ligne des touches
## passait sous la fiche, qui la coupait net. Un texte tronqué se lit comme une phrase qui
## s'arrête, pas comme un défaut, et les captures du jalon étaient prises plus tard dans le
## run — où le rapport, plus court, ne touchait rien.
##
## La séparation qu'elle contrôle est **horizontale** et c'est délibéré : la hauteur du
## rapport suit la partie, sa largeur non. Compter sur l'écart vertical revenait à parier que
## le village ne porterait jamais six chantiers.
##
## Elle rend un chiffre là où `P1b` avait passé une heure à en chercher un dans un PNG :
## `project.godot` est en `stretch/mode = "canvas_items"`, donc la mise en page raisonne dans
## un viewport logique pendant que l'image sort à la taille de la fenêtre. Un recouvrement
## sondé sur des pixels d'image est dans le mauvais repère ; demandé aux `Control`, il est
## dans le bon.
func _probe_the_layout() -> String:
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var report := Rect2(_label.global_position, _label.size)
	var column := Rect2(_column.global_position, _column.size)
	var overlap := report.intersection(column)
	return "mise en page : viewport %.0fx%.0f, rapport %s%s, colonne %s%s, recouvrement %s" % [
		view.size.x, view.size.y,
		_box(report), "" if view.encloses(report) else " HORS ÉCRAN",
		_box(column), "" if view.encloses(column) else " HORS ÉCRAN",
		"%.0f x %.0f px" % [overlap.size.x, overlap.size.y] if overlap.has_area()
			else "aucun"]

## Un rectangle de mise en page, coin haut-gauche vers coin bas-droit.
func _box(rect: Rect2) -> String:
	return "(%.0f,%.0f)→(%.0f,%.0f)" % [rect.position.x, rect.position.y,
		rect.end.x, rect.end.y]

## Pas d'échantillonnage de la course, pour la sonde de régularité.
const LIGHT_SAMPLES := 72

## Sonde de régularité : la lumière tourne-t-elle d'un pas **égal** tout au long de la course ?
##
## **Ce que cette ligne doit montrer**, et c'est la seconde chose qu'aucune image fixe ne dit :
## que le passage à la nuit ne se fait pas d'un coup. La bascule du soleil à la lune n'est pas
## qu'une baisse d'intensité — la lumière **change de direction** de plus de cent trente
## degrés —, et l'étaler sur un dixième de la course la fait lurcher là où tous les autres
## dixièmes sont doux. Chaque point du cycle était pourtant juste pris isolément : c'est le
## chemin entre eux qui ne l'était pas.
##
## Elle échantillonne la course en pas réguliers et imprime le **pire** écart angulaire à côté
## du pas moyen. Deux nombres du même ordre disent une rotation régulière ; un pire écart
## plusieurs fois le moyen serait l'à-coup, en chiffres.
##
## Elle repose le soleil en sortant, parce qu'elle l'a promené pour mesurer.
func _probe_the_light() -> String:
	var worst := 0.0
	var previous := Vector3.ZERO
	for sample in LIGHT_SAMPLES + 1:
		_world.settle_at(DevWorld.REST + float(sample) / float(LIGHT_SAMPLES))
		var here := _world.sun_direction()
		if sample > 0:
			worst = maxf(worst, rad_to_deg(previous.angle_to(here)))
		previous = here
	return "lumière : pas moyen %.1f°, pire pas %.1f° sur %d échantillons" % [
		360.0 / float(LIGHT_SAMPLES), worst, LIGHT_SAMPLES]

func _make_label() -> Label:
	var label := Label.new()
	label.name = "RunReport"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# AUTOWRAP_OFF : un Label qui s'enroule déclare une largeur minimale minuscule, et un
	# conteneur qui distribue la lui donne — « Main vide » s'est dessiné à la verticale
	# pendant trois jalons pour cette raison, et un « 20 » coupé en « 2 » sur « 0 » est
	# lisible et faux. Rien ici n'a de largeur bornée par autre chose.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", REPORT_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
