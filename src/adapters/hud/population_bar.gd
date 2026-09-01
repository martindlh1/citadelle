class_name PopulationBar
extends PanelContainer
## Le village à l'écran : combien de gens, combien de bras pris, et qui dort.
##
## Vue pure. On lui donne une `Population`, un `StaffingPlan` et la ville, elle dessine.
## Elle ne juge rien : « le logement est-il plein ? » se demande à `Population.is_full()`,
## « qui dort » se demande à `Staffing`, et cette classe affiche les réponses. Elle ne
## compte pas non plus les bras elle-même — le plan les a comptés, et un adapter qui
## referait cette somme finirait par en donner une autre.
##
## ---
##
## **C'est le jumeau de `ResourceBar`, et le jumelage est le sujet.** `N1` a écrit que
## `Population` est bâtie sur le modèle de `Ledger` : une quantité, une capacité que des
## bâtiments relèvent, un écrêtage quand cette capacité baisse. Les deux vues partagent donc
## la même `SegmentedGauge`, et ce qu'elle dit d'une réserve elle le dit d'un village —
## remplir un plateau d'ouvriers immobilisés, c'est renoncer à en avoir de libres, et un
## logement plein arrête la prochaine naissance comme une réserve pleine renverse la
## prochaine récolte.
##
## Les trois parts sont **exhaustives et disjointes** par construction : `immobilisés` plus
## `disponibles` font l'effectif, et le reste des places est libre. C'est l'invariant de
## `DESIGN.md` 3.4 dessiné plutôt qu'écrit — `disponibles = population − immobilisés`,
## `population ≤ places` —, et il se lit sans savoir qu'il existe : la barre est pleine
## quand le village l'est.
##
## **La population est un compteur, jamais une liste**, et cette vue est le premier endroit
## du jeu où l'on serait tenté d'en faire une : un panneau qui montrerait *lequel* des douze
## habitants fait quoi est le jeu que `R0` vient de couper *(cf. `DESIGN.md` 3.4)*. Ce
## qu'elle nomme, ce sont des **bâtiments** — « deux fermes dorment » —, jamais des gens.
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

## Natures de bâtiment énumérées avant qu'un compte ne ramasse le reste.
##
## `CLAUDE.md` : une liste qui suit la partie se borne. Le regroupement par nature la borne
## déjà au catalogue, mais un catalogue grossit — et la ligne est ici la dernière du
## panneau, donc celle qui déborderait.
const LISTED_KINDS := 3

## Ce que la ligne du sommeil dit quand personne ne dort.
##
## Une phrase et non une ligne vide : un panneau dont la dernière ligne apparaît et
## disparaît fait sauter tout ce qui est au-dessus, et le vide ne se distingue pas d'une vue
## qui aurait cessé de se mettre à jour.
const NOBODY_ASLEEP := "Tous les bâtiments tournent."

var _headcount: Label
var _parts: Dictionary[StringName, Label] = {}
var _gauge: SegmentedGauge
var _sleepers: Label

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
	bar._sleepers = HudStyle.text(NOBODY_ASLEEP, HudStyle.LABEL_FONT_SIZE,
		HudStyle.LABEL_COLOR)
	column.add_child(bar._sleepers)
	bar.add_child(column)
	return bar

## Montre ce village, ce plan d'occupation, et ce que ses bâtiments endormis sont.
##
## La ville n'arrive que pour **nommer** ce que le plan désigne par des ancres : un joueur
## corrige « cette ferme dort, il me manque un toit », pas « (17, 12) dort ». Les endormis
## sont debout, donc les chercher dans la ville est sûr — c'est l'inverse du piège que `I2`
## a payé sur des morts, qu'un rapport retire avant de le rendre.
##
## Sans reconstruction : appelable à chaque image.
func show_people(people: Population, plan: StaffingPlan, city: CityState) -> void:
	assert(people != null, "barre de population sans village")
	assert(plan != null, "barre de population sans plan d'occupation")
	_headcount.text = "%d" % people.headcount()
	_show_part(COMMITTED, plan.committed())
	_show_part(AVAILABLE, plan.available())
	_gauge.show_amounts({
		COMMITTED: plan.committed(),
		AVAILABLE: plan.available(),
	} as Dictionary[StringName, int], people.headcount(), people.places(), people.is_full())
	_show_sleepers(plan, city)

# --- La mise à jour ---------------------------------------------------------------------

## Une part, grisée à zéro comme une ressource qu'on ne possède pas.
##
## Zéro bras libre n'est pourtant **pas** une ressource à zéro : c'est l'état où plus rien ne
## se bâtit, donc celui qui explique un refus. Il se marque de la teinte des plafonds
## atteints, la même que celle d'une réserve pleine, parce que c'en est un.
func _show_part(part: StringName, quantity: int) -> void:
	var label := _parts[part]
	label.text = "%d" % quantity
	if quantity > 0:
		label.add_theme_color_override("font_color", HudStyle.AMOUNT_COLOR)
		return
	label.add_theme_color_override("font_color",
		HudStyle.FULL_COLOR if part == AVAILABLE else HudStyle.EMPTY_COLOR)

## Ce qui dort, par nature de bâtiment et non par ancre.
func _show_sleepers(plan: StaffingPlan, city: CityState) -> void:
	var asleep := plan.asleep()
	if asleep.is_empty():
		_sleepers.text = NOBODY_ASLEEP
		_sleepers.add_theme_color_override("font_color", HudStyle.LABEL_COLOR)
		return
	_sleepers.text = "En sommeil : %s" % _kinds_of(asleep, city)
	_sleepers.add_theme_color_override("font_color", HudStyle.FULL_COLOR)

## « 2 Ferme, 1 Carrière », borné, dans l'ordre de pose.
##
## L'ordre de pose est celui que `StaffingPlan` rend, donc celui dans lequel le village
## s'est éteint : la première nature nommée est la plus ancienne à avoir cédé, ce qui est
## l'information la plus lourde de la ligne. Un tri alphabétique l'aurait perdue.
func _kinds_of(anchors: Array[Vector2i], city: CityState) -> String:
	var counts: Dictionary[String, int] = {}
	for anchor in anchors:
		var building := city.building_at(anchor)
		# Une ancre que la ville ne porte plus : impossible sur un plan fraîchement
		# résolu, et pas une raison de faire tomber un HUD si ça arrivait un jour.
		var kind := "?" if building == null else building.data().label
		counts[kind] = counts.get(kind, 0) + 1
	var parts := PackedStringArray()
	var hidden := 0
	for kind in counts:
		if parts.size() >= LISTED_KINDS:
			hidden += counts[kind]
			continue
		parts.append("%d %s" % [counts[kind], kind])
	var text := ", ".join(parts)
	if hidden > 0:
		text += " (+%d)" % hidden
	return text

# --- La construction --------------------------------------------------------------------

func _make_chips() -> HBoxContainer:
	var row := HudStyle.row(HudStyle.COLUMN_GAP)

	var people := HudStyle.row()
	people.add_child(HudStyle.text("Habitants", HudStyle.LABEL_FONT_SIZE,
		HudStyle.LABEL_COLOR))
	_headcount = HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	people.add_child(_headcount)
	row.add_child(people)

	row.add_child(_make_chip(COMMITTED, "Au travail", COMMITTED_COLOR))
	row.add_child(_make_chip(AVAILABLE, "Libres", AVAILABLE_COLOR))
	return row

func _make_chip(part: StringName, label: String, color: Color) -> HBoxContainer:
	var chip := HudStyle.row()
	chip.add_child(HudStyle.swatch(color))
	chip.add_child(HudStyle.text(label, HudStyle.LABEL_FONT_SIZE, HudStyle.LABEL_COLOR))
	var amount := HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	_parts[part] = amount
	chip.add_child(amount)
	return chip
