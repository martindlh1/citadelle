class_name StepButton
extends Button
## Le pas suivant du run, nommé : fonder, finir la phase, fermer la journée, tenir la
## ligne, ou relancer.
##
## `DESIGN.md` 8 le demande à `P2a` après plusieurs runs entiers joués à la main, et la
## raison n'est pas qu'il manquait un bouton — `Entrée` fait déjà les cinq. C'est qu'elle
## les fait **sans le dire** : la seule chose de l'écran qui annonçait lequel des cinq
## allait tomber était une ligne du pavé de texte, à côté de l'aide au clavier.
##
## Ce bouton n'est donc pas un geste de plus, c'est la **dispatch rendue visible**. Le
## harnais la calculait déjà pour router `Entrée` ; elle est ici, et elle se lit.
##
## **Aucun nom de phase n'y entre**, ce qui est la contrainte que `DESIGN.md` 2 pose depuis
## `I1`. Les cinq libellés viennent de cinq questions posées au domaine — `is_over()`,
## `awaits_its_heart()`, `awaits_a_battle()`, `closes_the_day()` — et jamais d'un
## identifiant lu sur la `PhaseDef` courante. Échanger la journée par un `.tres` ne change
## donc rien ici, et une journée à une seule phase dirait « fermer la journée » du premier
## coup, ce qui est exact.
##
## Vue pure, comme les quatre autres du HUD : on lui donne un `RunState`, elle lit et elle
## dessine. Elle ne décide de rien — c'est le harnais qui reçoit `step_requested` et
## appelle `RunManager`, exactement comme pour le bouton **Auto** depuis `W2`.
##
## **Elle double délibérément le bouton de `BattlePanel`.** Ce n'est pas le doublon que ce
## projet refuse : celui-là porte sur un *chiffre* affiché deux fois, qui finit par différer
## de lui-même. Ici il n'y a qu'un geste, offert à deux endroits — la même chose que le
## chevron de repli et `F2`, ou qu'Espace et le clic sur une fiche. Le panneau de bataille
## garde le sien parce qu'il montre ce qu'on affronte, et c'est là qu'on regarde ; celui-ci
## existe parce que le pas suivant se trouve **toujours au même endroit**, quel qu'il soit.

## Le joueur veut faire le pas que le bouton annonce.
##
## Un signal et non un appel, comme `auto_requested` et `battle_requested` : la vue apprend
## un geste au harnais, elle ne le fait pas à sa place.
signal step_requested()

## Les cinq pas, dans l'ordre où `show_state()` les départage.
const LABEL_RESTART := "Relancer"
const LABEL_FOUND := "Fonder le village"
const LABEL_FIGHT := "Tenir la ligne"
const LABEL_CLOSE_DAY := "Finir la journée"
const LABEL_END_PHASE := "Finir la phase"

## Ce que l'infobulle ajoute. Le libellé dit **quoi**, l'infobulle dit ce que ça déclenche —
## le partage que `P1a` a posé pour le coût d'une carte, et `I2b` pour une phase qui ne pose
## rien.
const HINT_RESTART := "Ouvrir un run neuf, sur le seed suivant."
const HINT_FOUND := "Poser le Cœur sur la case suggérée."
const HINT_FIGHT := "Faire tomber la vague qui attend."
const HINT_CLOSE_DAY := "Résoudre, prélever l'upkeep, et passer au lendemain."
const HINT_END_PHASE := "Résoudre la phase et passer à la suivante."

const FONT_SIZE := 15
const PADDING_X := 18
const PADDING_Y := 10
const RADIUS := 5

## Le pas ordinaire. Sobre : c'est le geste le plus fréquent du jeu, et un bouton qui crie
## quinze journées durant cesse d'être lu.
const CALM_COLOR := Color(0.18, 0.24, 0.32, 0.96)

## Le pas qui ouvre ou referme un run. Assez distinct pour qu'on voie que ce n'est pas le
## geste d'une phase.
const OPEN_COLOR := Color(0.20, 0.30, 0.26, 0.96)

## La bataille. **L'orange de danger** des quatre autres panneaux — famine, écrêtage,
## pertes d'une vague —, et c'est le seul état du bouton qui le mérite : ce pas-là coûte
## des hommes.
const ALARM_COLOR := Color(0.42, 0.24, 0.14, 0.96)

const BORDER := 1
const BORDER_LIGHTEN := 0.22
const TEXT_COLOR := Color(0.94, 0.94, 0.92)

## Bouton prêt à être ajouté à l'arbre. Le harnais le place ; il ne s'ancre pas lui-même.
static func create() -> StepButton:
	var button := StepButton.new()
	button.name = "StepButton"
	button.text = LABEL_END_PHASE
	# **Pas de focus clavier.** `Entrée` et `Espace` appartiennent au harnais depuis `I1`,
	# et un `Button` focalisé réagit à `ui_accept` : ce bouton-ci est justement celui
	# qu'`Entrée` déclenche, donc un focus le ferait tirer deux fois. La règle a été écrite
	# sur le bouton **Auto** à `W2` ; elle n'a jamais compté autant qu'ici.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.pressed.connect(button._on_pressed)
	button._wear(LABEL_END_PHASE, HINT_END_PHASE, CALM_COLOR)
	return button

## Relit le run et affiche le pas qui vient.
##
## L'ordre des cinq cas n'est pas indifférent. **Un run terminé passe en premier** : c'est
## le seul état où les autres questions n'ont plus de sens, et `DayCycle` les ferme toutes
## en rendant faux — demander « cette phase ferme-t-elle la journée ? » à un run fini
## rendrait « finir la phase » sur une partie qui n'en a plus.
##
## Viennent ensuite les deux **attentes** de `DESIGN.md` 3.8, qui suspendent la journée sans
## la finir, et le pas ordinaire en dernier.
func show_state(state: RunState) -> void:
	assert(state != null, "bouton de pas sans run")
	if state.cycle().is_over():
		_wear(LABEL_RESTART, HINT_RESTART, OPEN_COLOR)
		return
	if state.awaits_its_heart():
		_wear(LABEL_FOUND, HINT_FOUND, OPEN_COLOR)
		return
	if state.awaits_a_battle():
		_wear(LABEL_FIGHT, HINT_FIGHT, ALARM_COLOR)
		return
	if state.cycle().closes_the_day():
		_wear(LABEL_CLOSE_DAY, HINT_CLOSE_DAY, CALM_COLOR)
		return
	_wear(LABEL_END_PHASE, HINT_END_PHASE, CALM_COLOR)

## Le libellé, l'infobulle et la teinte, posés d'un seul geste.
##
## Les trois ensemble et jamais séparément : un libellé qui changerait sans sa teinte
## laisserait l'orange de la bataille sur le pas suivant, et c'est exactement le genre
## d'écran qui reste vrai une image de trop.
##
## Elle sort tôt si rien n'a changé. Le bouton est relu à **chaque image** — sa réponse
## dépend de l'état du run, donc tout geste qui l'avance doit s'y voir —, et repeindre un
## `StyleBoxFlat` soixante fois par seconde pour la même valeur serait le churn que
## `CLAUDE.md` demande d'éviter aux vues rafraîchies en continu.
func _wear(label: String, hint: String, tint: Color) -> void:
	if text == label:
		return
	text = label
	tooltip_text = "%s\n%s" % [label, hint]
	for slot in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(slot, _make_style(tint, slot == "hover"))

static func _make_style(tint: Color, lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint.lightened(BORDER_LIGHTEN) if lit else tint
	style.border_color = tint.lightened(BORDER_LIGHTEN * 2.0)
	style.set_border_width_all(BORDER)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = PADDING_X
	style.content_margin_right = PADDING_X
	style.content_margin_top = PADDING_Y
	style.content_margin_bottom = PADDING_Y
	return style

func _on_pressed() -> void:
	step_requested.emit()
