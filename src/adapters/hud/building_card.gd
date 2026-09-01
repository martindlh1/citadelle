class_name BuildingCard
extends PanelContainer
## La fiche du bâtiment qu'on s'apprête à poser : ce qu'il coûte, ce qu'il rend, et ce
## qu'il manque pour l'ouvrir.
##
## Vue pure. On lui donne une `BuildingData`, une orientation, et ce que le domaine a
## répondu à deux questions ; elle dessine. Elle ne juge rien, et surtout pas les deux
## chiffres qui font tout son intérêt : « ai-je les dix bois ? » se demande à
## `Ledger.shortfall()`, « ai-je les quatre bras ? » à `Staffing.hands_short()`. Un adapter
## qui comparerait lui-même la réserve au coût tiendrait une seconde copie de la règle, et
## celle des bras serait **fausse** — elle se pose à la demande totale du village, jamais
## aux bras que le plan laisse libres.
##
## ---
##
## **C'est la moitié de `N2` qui vient de `DESIGN.md` 3.4**, et c'en est un argument de
## design plutôt qu'un confort : « le coût en main-d'œuvre d'un bâtiment devient une ligne
## de sa fiche, **lisible avant de le poser**, exactement comme son coût en bois ». Les
## travailleurs sont le seul régulateur du jeu depuis le rescope ; un régulateur qu'on ne
## découvre qu'au refus n'en est pas un.
##
## Le coût en bras porte donc la teinte des bras au travail, la même que la part chaude de
## `PopulationBar` : ce que la fiche réclame est exactement ce qui passera de « libres » à
## « au travail » sur la jauge du village. C'est la lecture que `DESIGN.md` 3.4 résume par
## « une baliste coûte deux bûcherons ».
##
## **Elle décrit ce que le clic gauche poserait, pas ce que le catalogue contient** : c'est
## le Cœur tant qu'il n'est pas fondé, la sélection ensuite. Le harnais lui passe la même
## `BuildingData` qu'au fantôme, et les deux ne peuvent donc pas se contredire.
##
## **Ce qu'elle ne dit pas, et ne dira jamais : si la case convient.** Elle ne connaît pas
## de cellule. Le fantôme colore la carte et la ligne de survol dit pourquoi ; cette fiche
## répond à l'autre moitié — ce que le village peut payer. Les deux se rejoignent dans
## `RunOrchestrator.open_site()`, qui pose la question du terrain avant celle des coûts.
##
## Les nœuds sont construits une fois et **mis à jour sur place**, visibilité comprise : une
## ligne de coût qui n'existe pas est cachée, jamais retirée. Appelable à chaque image.

## Ce que la ligne de manque dit quand le village peut payer.
##
## Elle parle des **coûts** et de rien d'autre : la case, elle, se juge au fantôme. Annoncer
## « posable » ici serait la seule chose que cette vue n'a pas le droit de dire.
const AFFORDABLE := "Coût couvert."

## Préfixe de la ligne de manque.
const MISSING := "Il manque "

## Ce qui s'affiche à la place d'une fiche quand il n'y a rien à poser.
const NO_COST := "—"

var _palette: CommodityPalette
var _title: Label
var _orientation: Label
var _costs: Dictionary[StringName, HBoxContainer] = {}
var _amounts: Dictionary[StringName, Label] = {}
var _workers: HBoxContainer
var _workers_amount: Label
var _site: Label
var _gives: Label
var _verdict: Label

## Fiche prête à être ajoutée à l'arbre, une colonne de coût par ressource du catalogue.
##
## Toutes les colonnes existent dès la construction et se **cachent** au lieu de naître :
## c'est ce qui rend `show_building()` gratuite à chaque image, et ce qui évite qu'une fiche
## reconstruite sous l'œil clignote entre deux sélections.
static func create(palette: CommodityPalette) -> BuildingCard:
	assert(palette != null, "fiche de bâtiment sans palette")
	var card := BuildingCard.new()
	card.name = "BuildingCard"
	card._palette = palette
	card.add_theme_stylebox_override("panel", HudStyle.panel())
	card.custom_minimum_size.x = HudStyle.PANEL_WIDTH
	# Vue de lecture : les clics traversent jusqu'au harnais, qui pose le bâtiment que
	# cette fiche décrit. Une fiche qui les avalerait annulerait le geste qu'elle annonce.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := HudStyle.column()
	column.add_child(card._make_title())
	column.add_child(card._make_costs())
	card._gives = HudStyle.text("", HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR)
	column.add_child(card._gives)
	card._verdict = HudStyle.text(AFFORDABLE, HudStyle.LABEL_FONT_SIZE, HudStyle.GAIN_COLOR)
	column.add_child(card._verdict)
	card.add_child(column)
	card.show_nothing(NO_COST)
	return card

## Montre ce bâtiment, dans cette orientation, avec ce que le domaine dit qu'il manque.
##
## `missing` et `hands` sont les **réponses** de `Ledger.shortfall()` et de
## `Staffing.hands_short()`, pas des questions à reposer ici. Les passer plutôt que de les
## calculer est ce qui garantit que la fiche et le refus disent la même chose : le jour où
## le seuil des bras bouge, il bouge une fois.
func show_building(data: BuildingData, turns: int,
		missing: Dictionary[StringName, int], hands: int) -> void:
	assert(data != null, "fiche sans bâtiment — passer par show_nothing()")
	_title.text = data.label
	_title.add_theme_color_override("font_color", HudStyle.AMOUNT_COLOR)
	_orientation.text = "%d/4" % posmod(turns, BuildingData.QUARTER_TURNS)
	_show_costs(data, missing)
	_show_workers(data, hands)
	_site.text = "%d tour(s) de chantier" % data.site_turns
	_site.visible = data.site_turns > 0
	_gives.text = _gives_text(data)
	_gives.visible = true
	_verdict.visible = true
	_show_verdict(missing, hands)

## Montre qu'il n'y a rien à poser, et pourquoi.
##
## Une fiche **réduite à son titre** plutôt qu'un panneau qui disparaît : la colonne est
## ancrée en bas, donc ce qui rétrécit ici ne déplace rien d'autre — c'est la vue la plus
## variable qui paie le mouvement, et c'est pour ça qu'elle est en haut de la pile *(règle de
## `P1a`)*. Les lignes vides sont **cachées** et non vidées : un `Label` sans texte occupe
## quand même sa hauteur de ligne, et trois d'entre elles font un panneau creux qui se lit
## comme une vue qui aurait cessé de se mettre à jour.
func show_nothing(why: String) -> void:
	_title.text = why
	_title.add_theme_color_override("font_color", HudStyle.EMPTY_COLOR)
	_orientation.text = ""
	for id in _costs:
		_costs[id].visible = false
	_workers.visible = false
	_site.visible = false
	_gives.visible = false
	_verdict.visible = false

# --- La mise à jour ---------------------------------------------------------------------

## Une colonne par ressource du coût, teintée de ce qui manque.
func _show_costs(data: BuildingData, missing: Dictionary[StringName, int]) -> void:
	for id in _costs:
		var due: int = data.cost.get(id, 0)
		_costs[id].visible = due > 0
		if due <= 0:
			continue
		_amounts[id].text = "%d" % due
		_amounts[id].add_theme_color_override("font_color",
			HudStyle.LOSS_COLOR if missing.has(id) else HudStyle.AMOUNT_COLOR)

## Le coût en bras, caché quand il est nul.
##
## Caché et non affiché à zéro, à l'inverse des quatre colonnes de `ResourceBar` : là-bas un
## zéro se grise parce que les colonnes ne doivent jamais bouger sous l'œil, ici « 0 bras »
## est une **information**, celle de la soupape de `DESIGN.md` 3.4 — et elle se lit mieux
## par une ligne absente que par un zéro qu'il faut remarquer. L'habitation et la palissade
## sont les seules à ne rien coûter, et c'est ce qui les rend toujours ouvrables.
func _show_workers(data: BuildingData, hands: int) -> void:
	_workers.visible = data.workers > 0
	if data.workers <= 0:
		return
	_workers_amount.text = "%d" % data.workers
	_workers_amount.add_theme_color_override("font_color",
		HudStyle.LOSS_COLOR if hands > 0 else HudStyle.AMOUNT_COLOR)

## Ce que ce bâtiment rend au village, en une ligne. Ses points de vie ferment la liste,
## parce qu'ils sont le seul terme que tous portent.
func _gives_text(data: BuildingData) -> String:
	var parts := PackedStringArray()
	if data.produces():
		parts.append("%s par tour"
			% _palette.bundle_text(data.production.yield_per_turn))
	if data.housing > 0:
		parts.append("loge %d" % data.housing)
	if data.storage_bonus > 0:
		parts.append("réserve +%d" % data.storage_bonus)
	parts.append("%d PV" % data.hit_points)
	return " · ".join(parts)

## Ce qui manque pour l'ouvrir — les deux coûts ensemble, dans l'ordre où le domaine les
## demande.
func _show_verdict(missing: Dictionary[StringName, int], hands: int) -> void:
	if missing.is_empty() and hands <= 0:
		_verdict.text = AFFORDABLE
		_verdict.add_theme_color_override("font_color", HudStyle.GAIN_COLOR)
		return
	var parts := PackedStringArray()
	if not missing.is_empty():
		parts.append(_palette.bundle_text(missing))
	if hands > 0:
		parts.append("%d bras" % hands)
	_verdict.text = MISSING + ", ".join(parts)
	_verdict.add_theme_color_override("font_color", HudStyle.LOSS_COLOR)

# --- La construction --------------------------------------------------------------------

func _make_title() -> HBoxContainer:
	var row := HudStyle.row()
	_title = HudStyle.text("", HudStyle.TITLE_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_orientation = HudStyle.text("", HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR)
	row.add_child(_orientation)
	return row

func _make_costs() -> HBoxContainer:
	var row := HudStyle.row(HudStyle.COLUMN_GAP)
	for id in _palette.ordered():
		var chip := HudStyle.row()
		chip.add_child(HudStyle.swatch(_palette.color_of(id)))
		var amount := HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
		chip.add_child(amount)
		chip.add_child(HudStyle.text(_palette.label_of(id), HudStyle.LABEL_FONT_SIZE,
			HudStyle.LABEL_COLOR))
		_costs[id] = chip
		_amounts[id] = amount
		row.add_child(chip)

	_workers = HudStyle.row()
	_workers.add_child(HudStyle.swatch(HudStyle.WORKERS_COLOR))
	_workers_amount = HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	_workers.add_child(_workers_amount)
	_workers.add_child(HudStyle.text("bras", HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR))
	row.add_child(_workers)

	_site = HudStyle.text("", HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR)
	row.add_child(_site)
	return row
