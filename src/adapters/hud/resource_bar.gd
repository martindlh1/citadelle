class_name ResourceBar
extends PanelContainer
## La réserve à l'écran : ce qu'on possède, et la place qu'il reste.
##
## Vue pure. On lui donne un `Ledger`, elle dessine. Elle ne juge rien, ne convertit
## rien, n'écrête rien : « la réserve est-elle pleine ? » se demande au domaine, et cette
## classe affiche la réponse. Un adapter qui appellerait `set_capacity()` serait la faute
## d'architecture que `CLAUDE.md` refuse en premier — c'est l'orchestrateur qui la pose.
##
## **La jauge est unique et segmentée, et c'est le sujet.** `DESIGN.md` 3.3 : les cent
## unités sont partagées entre toutes les ressources, « remplir sa réserve de bois, c'est
## renoncer à stocker de la pierre ». Quatre jauges côte à côte auraient dessiné quatre
## plafonds indépendants, c'est-à-dire exactement la lecture que `E1` a écartée. Une seule
## barre où le bois qui monte pousse la place de la pierre est la décision de `E1` rendue
## regardable — et 3.3 dit qu'« un joueur qui ne la voit pas ne comprend pas pourquoi son
## entrepôt manque ».
##
## **Les quatre colonnes ne bougent jamais**, même à zéro. Une ressource qui
## apparaîtrait le jour où on en gagne la première unité ferait glisser ses voisines sous
## l'œil, et il faudrait relire la barre entière pour retrouver la nourriture. Un zéro se
## grise ; il ne disparaît pas.
##
## Les nœuds sont construits une fois et **mis à jour sur place** : `show_ledger()` ne
## reconstruit rien, ce qui la rend appelable à chaque image sans churn d'allocation. Le
## jeu de ressources ne change pas en cours de run — il vient du catalogue, pas de la
## partie.
##
## Construite en code, sans `.tscn`. Elle déménagera sous `scenes/ui/` le jour où `M1` fera
## un vrai écran, et elle déménagera avec sa mise en forme : elle n'a pas de règles à
## emporter.
##
## ---
##
## **`I3` lui retire `delta_of()`**, et l'annotation qu'elle composait se mesure maintenant
## avant/après chez l'appelant. La fonction était un résidu que `R0` avait laissé passer :
## elle prenait un `PhaseReport`, classe supprimée avec la journée en phases, si bien que ce
## fichier **ne compilait plus** — sans que rien ne le dise, puisque le boot ne le chargeait
## plus et que le contrôle de parsing ne balaie que `src/domain/`.
##
## Elle ne revient pas sous une autre forme, et c'est un gain plutôt qu'une perte : elle
## recomposait ce que la réserve avait changé à partir de deux champs d'un rapport, quand la
## réserve elle-même pouvait être lue deux fois. `CLAUDE.md` nomme ce raccourci depuis `F1` —
## **une mesure qui emprunte un chemin plus court mesure le chemin plus court** —, et le cas
## était réel : une somme « entré moins mangé » ignore l'écrêtage d'un entrepôt démoli, donc
## affiche un delta qui ne recolle pas au chiffre juste à côté de lui.
##
## **`N2` lui retire sa jauge et ses teintes**, qui partent l'une dans `SegmentedGauge` et
## les autres dans `HudStyle`. Ce fichier ne perd aucune règle au passage : la seule qu'il
## tenait — le reste de la division va à la place libre — est justement celle que la
## `PopulationBar` devait avoir aussi, et elle est désormais écrite une fois.

var _palette: CommodityPalette

var _names: Dictionary[StringName, Label] = {}
var _amounts: Dictionary[StringName, Label] = {}
var _deltas: Dictionary[StringName, Label] = {}
var _swatches: Dictionary[StringName, ColorRect] = {}
var _gauge: SegmentedGauge

## Barre prête à être ajoutée à l'arbre, une colonne par ressource du catalogue.
static func create(palette: CommodityPalette) -> ResourceBar:
	assert(palette != null, "barre de ressources sans palette")
	var bar := ResourceBar.new()
	bar.name = "ResourceBar"
	bar._palette = palette
	bar.add_theme_stylebox_override("panel", HudStyle.panel())
	bar.custom_minimum_size.x = HudStyle.PANEL_WIDTH
	# Les clics traversent : le curseur de cellule pioche sous la souris à chaque image,
	# et une barre qui les avalerait rendrait injouable la bande de carte qu'elle couvre.
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := HudStyle.column()
	column.add_child(bar._make_chips())
	bar._gauge = SegmentedGauge.create(bar._gauge_colors())
	column.add_child(bar._gauge)
	bar.add_child(column)
	return bar

## Montre cette réserve, annotée de ce que la dernière résolution y a changé.
##
## Les quantités viennent **toujours** du `Ledger` et jamais du delta : celui-ci n'est
## qu'une annotation de lecture, et une barre qui cumulerait des deltas finirait par
## diverger de la réserve qu'elle prétend montrer. Un delta vide n'annote rien.
##
## Sans reconstruction : appelable à chaque image.
func show_ledger(ledger: Ledger, delta: Dictionary[StringName, int] = {}) -> void:
	assert(ledger != null, "barre de ressources sans réserve")
	for id in _palette.ordered():
		var held := ledger.amount(id)
		_amounts[id].text = "%d" % held
		_amounts[id].add_theme_color_override("font_color",
			HudStyle.AMOUNT_COLOR if held > 0 else HudStyle.EMPTY_COLOR)
		_names[id].add_theme_color_override("font_color",
			HudStyle.LABEL_COLOR if held > 0 else HudStyle.EMPTY_COLOR)
		var swatch := _palette.color_of(id)
		swatch.a = 1.0 if held > 0 else HudStyle.EMPTY_SWATCH_ALPHA
		_swatches[id].color = swatch
		_show_delta(id, delta.get(id, 0))
	_gauge.show_amounts(ledger.amounts(), ledger.total(), ledger.capacity(),
		ledger.is_full())

# --- La mise à jour ---------------------------------------------------------------------

func _show_delta(id: StringName, moved: int) -> void:
	var label := _deltas[id]
	if moved == 0:
		label.text = ""
		return
	label.text = "%+d" % moved
	label.add_theme_color_override("font_color",
		HudStyle.GAIN_COLOR if moved > 0 else HudStyle.LOSS_COLOR)

# --- La construction --------------------------------------------------------------------

## Les parts de la jauge, dans l'ordre du HUD et à la couleur du catalogue.
func _gauge_colors() -> Dictionary[StringName, Color]:
	var colors: Dictionary[StringName, Color] = {}
	for id in _palette.ordered():
		colors[id] = _palette.color_of(id)
	return colors

func _make_chips() -> HBoxContainer:
	var row := HudStyle.row(HudStyle.COLUMN_GAP)
	for id in _palette.ordered():
		row.add_child(_make_chip(id))
	return row

func _make_chip(id: StringName) -> HBoxContainer:
	var chip := HudStyle.row()

	var swatch := HudStyle.swatch(_palette.color_of(id))
	_swatches[id] = swatch
	chip.add_child(swatch)

	var name_label := HudStyle.text(_palette.label_of(id), HudStyle.LABEL_FONT_SIZE,
		HudStyle.LABEL_COLOR)
	_names[id] = name_label
	chip.add_child(name_label)

	var amount := HudStyle.text("0", HudStyle.AMOUNT_FONT_SIZE, HudStyle.AMOUNT_COLOR)
	_amounts[id] = amount
	chip.add_child(amount)

	var delta := HudStyle.text("", HudStyle.LABEL_FONT_SIZE, HudStyle.GAIN_COLOR)
	_deltas[id] = delta
	chip.add_child(delta)
	return chip
