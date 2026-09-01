class_name PopulationBar
extends PanelContainer
## Le village à l'écran : combien de bras sont pris, combien sont libres, et sur combien de
## places de logement.
##
## Vue pure. On lui donne une `Population` et un `StaffingPlan`, elle dessine. Elle ne juge
## rien : « le logement est-il plein ? » se demande à `Population.is_full()`, et cette classe
## affiche la réponse. Elle ne compte pas non plus les bras elle-même — le plan les a
## comptés, et un adapter qui referait cette somme finirait par en donner une autre.
##
## ---
##
## **C'est le jumeau de `ResourceBar`, et le jumelage est le sujet.** `N1` a écrit que
## `Population` est bâtie sur le modèle de `Ledger` : une quantité, une capacité que des
## bâtiments relèvent, un écrêtage quand cette capacité baisse. Les deux vues ont donc la
## **même forme** — une rangée de pastilles, une jauge segmentée, un total sur une capacité —
## et partagent la même `SegmentedGauge`. Ce qu'elle dit d'une réserve elle le dit d'un
## village : remplir un plateau d'ouvriers immobilisés, c'est renoncer à en avoir de libres,
## et un logement plein arrête la prochaine naissance comme une réserve pleine renverse la
## prochaine récolte.
##
## **Les deux parts sont exhaustives et disjointes** par construction : `au travail` plus
## `libres` font l'effectif, et le reste des places est libre. C'est l'invariant de
## `DESIGN.md` 3.4 dessiné plutôt qu'écrit — `disponibles = population − immobilisés`,
## `population ≤ places` —, et il se lit sans savoir qu'il existe : la barre est pleine quand
## le village l'est.
##
## **L'effectif n'a pas de pastille à lui**, et c'est le même argument : la jauge écrit déjà
## « 12 / 18 » à droite, exactement comme la barre de réserve écrit « 26 / 100 ». Un troisième
## chiffre qui serait la somme des deux autres n'apprendrait rien et donnerait à cette vue une
## forme que sa jumelle n'a pas.
##
## **Ce qui dort n'est pas ici**, et c'est délibéré : cette vue montre un **compteur**, et la
## liste des bâtiments à l'arrêt est d'une autre nature — elle nomme des choses posées sur la
## carte. Le plateau les éteint en couleur *(cf. `BuildingRenderer`)*, ce qui est la seule
## réponse honnête à « lesquels ? », et le rapport du harnais les compte par nature.
##
## **La population est un compteur, jamais une liste**, et cette vue est le premier endroit du
## jeu où l'on serait tenté d'en faire une : un panneau qui montrerait *lequel* des douze
## habitants fait quoi est le jeu que `R0` vient de couper *(cf. `DESIGN.md` 3.4)*.
##
## Les nœuds sont construits une fois et mis à jour **sur place** : appelable à chaque image.

## Bras retenus par ce que le village fait tourner.
const COMMITTED := &"committed"

## Bras libres, ceux qu'un chantier neuf peut dépenser.
const AVAILABLE := &"available"

## Teintes des deux parts. Elles vivent dans `HudStyle` parce que la fiche d'un bâtiment les
## lit aussi : les bras qu'elle réclame sont ceux qui passeront d'une part à l'autre.
const COMMITTED_COLOR := HudStyle.WORKERS_COLOR
const AVAILABLE_COLOR := HudStyle.IDLE_COLOR

var _labels: Dictionary[StringName, Label] = {}
var _amounts: Dictionary[StringName, Label] = {}
var _swatches: Dictionary[StringName, ColorRect] = {}
var _gauge: SegmentedGauge

## Barre prête à être ajoutée à l'arbre.
static func create() -> PopulationBar:
	var bar := PopulationBar.new()
	bar.name = "PopulationBar"
	bar.add_theme_stylebox_override("panel", HudStyle.panel())
	bar.custom_minimum_size.x = HudStyle.PANEL_WIDTH
	# Vue de lecture : les clics traversent, pour que le curseur de cellule continue de
	# piocher la carte sous elle.
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := HudStyle.column()
	column.add_child(bar._make_chips())
	bar._gauge = SegmentedGauge.create({
		COMMITTED: COMMITTED_COLOR,
		AVAILABLE: AVAILABLE_COLOR,
	} as Dictionary[StringName, Color])
	column.add_child(bar._gauge)
	bar.add_child(column)
	return bar

## Montre ce village et ce plan d'occupation.
##
## Sans reconstruction : appelable à chaque image.
func show_people(people: Population, plan: StaffingPlan) -> void:
	assert(people != null, "barre de population sans village")
	assert(plan != null, "barre de population sans plan d'occupation")
	_show_part(COMMITTED, plan.committed())
	_show_part(AVAILABLE, plan.available())
	_gauge.show_amounts({
		COMMITTED: plan.committed(),
		AVAILABLE: plan.available(),
	} as Dictionary[StringName, int], people.headcount(), people.places(), people.is_full())

# --- La mise à jour ---------------------------------------------------------------------

## Une part, grisée à zéro comme une ressource qu'on ne possède pas.
##
## Zéro bras libre n'est pourtant **pas** une ressource à zéro : c'est l'état où plus rien ne
## se bâtit, donc celui qui explique un refus. Il se marque de la teinte des plafonds
## atteints, la même que celle d'une réserve pleine, parce que c'en est un.
func _show_part(part: StringName, quantity: int) -> void:
	var warn := part == AVAILABLE and quantity <= 0
	var ink := HudStyle.AMOUNT_COLOR
	if quantity <= 0:
		ink = HudStyle.FULL_COLOR if warn else HudStyle.EMPTY_COLOR
	_amounts[part].text = "%d" % quantity
	_amounts[part].add_theme_color_override("font_color", ink)
	_labels[part].add_theme_color_override("font_color",
		HudStyle.LABEL_COLOR if quantity > 0 else HudStyle.EMPTY_COLOR)
	var swatch: Color = COMMITTED_COLOR if part == COMMITTED else AVAILABLE_COLOR
	swatch.a = 1.0 if quantity > 0 else HudStyle.EMPTY_SWATCH_ALPHA
	_swatches[part].color = swatch

# --- La construction --------------------------------------------------------------------

func _make_chips() -> HBoxContainer:
	var row := HudStyle.row(HudStyle.COLUMN_GAP)
	row.add_child(_make_chip(COMMITTED, "Au travail", COMMITTED_COLOR))
	row.add_child(_make_chip(AVAILABLE, "Libres", AVAILABLE_COLOR))
	return row

func _make_chip(part: StringName, label: String, color: Color) -> HBoxContainer:
	var chip := HudStyle.row()

	var swatch := HudStyle.swatch(color)
	_swatches[part] = swatch
	chip.add_child(swatch)

	var name_label := HudStyle.text(label, HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR)
	_labels[part] = name_label
	chip.add_child(name_label)

	var amount := HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	_amounts[part] = amount
	chip.add_child(amount)
	return chip
