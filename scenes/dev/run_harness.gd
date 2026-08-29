extends Node
## Harnais de dev du système Run — la boucle minimale de `I1`, le HUD de `E2`.
##
## C'est le premier harnais qui ne montre pas un système mais **une journée**. Le harnais
## Cartes de `D2` composait déjà trois systèmes du domaine ; celui-ci les compose tous, et
## surtout il ne les appelle plus lui-même : tout passe par `RunManager`, qui est le pont
## que `I0` avait annoncé et laissé vide.
##
## Ce que `I1` met sous les yeux, et qu'aucun harnais précédent ne pouvait montrer :
##
##   - **la journée en phases.** Le bandeau dit où l'on en est, et les gestes s'allument
##     ou s'éteignent selon ce que la phase courante autorise. Aucun nom de phase n'est
##     écrit ici : le libellé vient de la `PhaseDef`, et les touches se gardent en
##     demandant au domaine ce qui est permis.
##   - **la bourse au moment de bâtir.** Une carte de bâtiment affiche son coût sous le
##     curseur et se fait refuser quand la réserve ne suit pas. `D2` la posait
##     gratuitement et le disait en toutes lettres.
##   - **les deux verbes exécutés.** Un chantier monte vraiment d'un cran, et le relief se
##     creuse vraiment sous un terrassement. Le rapport de phase les nomme.
##
## Ce que `E2` y a ajouté, et surtout ce qu'il en a **retiré** : la réserve et le compte
## rendu de résolution ne sont plus deux morceaux du pavé de texte, ce sont deux vues —
## `ResourceBar` en haut à gauche, `ProductionPanel` en haut à droite. Le harnais ne
## fabrique plus une seule ligne de leur mise en forme ; il leur passe un `Ledger` et un
## `PhaseReport`. Les deux endroits où le même chiffre se lisait ont disparu avec, ce qui
## est le vrai bénéfice : un chiffre affiché à deux endroits est un chiffre qui finira par
## différer de lui-même.
##
## Il ne décide rien. Il traduit un clic en appel de `RunManager` et une réponse en
## couleur, comme les harnais Construction et Cartes avant lui. Aucun « if » sur le
## terrain, la ville, la bourse ou la phase n'apparaît ici — la question se pose au
## domaine, l'écran affiche la réponse.
##
## Ce que `W2` y ajoute, et ce qu'il en retire à son tour : le plateau et le roster ne
## sont plus deux lignes de texte, c'est un `AssignmentPanel`. On y choisit **qui** l'on
## envoie — une fiche, puis une action — au lieu de subir le premier ouvrier libre, et un
## bouton remplit le reste. Le harnais ne classe personne : il demande, `StaffingAdvisor`
## répond.
##
## Ce que `I2` en fait enfin un jeu qu'on ouvre et qu'on finit. Le run **commence** par la
## pose du Cœur — un clic sur la carte, ou Entrée pour la case que le domaine suggère — au
## lieu de le trouver déjà posé au centre. Les vagues **tombent à leur date**, et la journée
## s'arrête sur elles : le bandeau annonce l'assaut, le `BattlePanel` dit ce qu'on lui
## oppose, et rien n'avance tant qu'on n'a pas tenu la ligne. Et le run **se termine** — la
## dernière journée franchie, le Cœur tombé ou le village vidé —, sur un bandeau qui dit
## laquelle des trois et ce que la partie valait.
##
## Ce qui reste en texte est ce dont aucune vue n'a la charge : les piles, le survol, et le
## bandeau de tête.
##
## Ce que `P1a` y change tient en un mot : **la souris suffit**. `DESIGN.md` 8 le demande en
## premier de sa liste de confort, et l'ancien geste le méritait — on cliquait une fiche,
## puis on appuyait sur Espace en visant à la souris. Une intention, deux vocabulaires.
## Une fiche tenue s'envoie désormais d'un clic sur son action, sur la carte comme dans la
## liste ; le clavier reste en raccourci, il ne commande plus rien seul.
##
## Les commandes : une carte se prend au clavier — 1 à 9 — ou au clic dessus ; un clic
## gauche sur le sol y envoie l'ouvrier tenu s'il y en a un, sinon il y joue la carte
## tenue ; un clic droit retire l'action posée là, Espace y envoie un ouvrier, Retour
## arrière les rappelle tous, Tab pivote un bâtiment ou retourne un terrassement, **Entrée
## termine la phase**. La caméra garde Q/E, la molette, WASD et R. Dans le panneau : un
## clic sur une fiche la sélectionne, un clic sur une ligne d'action y envoie le
## sélectionné, et **Auto** remplit le reste.

## Seed du run. Fixe : deux lancements doivent se comparer.
const SEED := 20260825

## Ouvriers du roster d'ouverture.
##
## Ils sont fabriqués ici et non par le domaine, et c'est voulu : `DESIGN.md` 3.4 garde le
## recrutement sous un `OUVERT`, `RunState.open()` reçoit son roster, et un harnais est
## exactement le genre d'appelant qui a le droit d'en inventer un.
const GIVEN_NAMES: Array[String] = ["Ana", "Bo", "Cy", "Dov", "Ema", "Fen"]

## Rendu quand aucune cellule ne convient.
const NO_CELL := Vector2i(-1, -1)

## Cartes que les touches 1 à 9 atteignent. Au-delà, il faut cliquer.
const SLOT_KEYS := 9

## Rang qui ne désigne aucune carte.
const NO_SLOT := -1

## Valeurs de `--shot-view`, dans l'ordre des crans, plus celle qui éteint tout.
##
## Des noms et non des chiffres : `--shot-view 2` n'aurait dit à personne ce qu'il capture,
## et c'est une ligne de commande qu'on relit six mois plus tard dans un journal.
const VIEW_NAMES: Array[String] = ["complet", "essentiel", "masque"]
const VIEW_NONE := "aucun"

## Crans du rapport texte, du plus bavard au plus discret.
##
## Trois et non deux, parce qu'un simple on/off répond mal à ce qui gêne. Ce qui couvre la
## carte est en grande partie l'aide et les piles, qu'on cesse de lire au bout de deux
## minutes ; le bandeau et la dernière action, eux, sont ce qui dit où l'on en est et ce
## que le dernier geste a fait — les masquer pour dégager la vue reviendrait à jouer en
## aveugle. Le cran du milieu garde exactement ces deux-là.
enum Report { FULL, ESSENTIAL, HIDDEN }

## Nom de chaque cran, pour que la touche dise ce qu'elle vient de faire.
const REPORT_NAMES: Array[String] = ["complet", "l'essentiel", "masqué"]

const HOVER_BACKGROUND := Color(0.10, 0.11, 0.14, 0.88)
const HOVER_RADIUS := 5
const HOVER_PADDING := 8

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13
const REPORT_OUTLINE_SIZE := 4

const CONTROLS := """La main    1-9 ou clic sur une carte : la prendre. Tab : pivoter, ou retourner un terrassement.
La carte   clic gauche : jouer sur la case survolée. Clic droit : retirer.
Le travail clic sur une fiche, puis sur son action — sur la carte ou dans la liste. Ou Auto.
           Clic droit sur une fiche : la rappeler. Retour arrière : rappeler toute une action.
           Espace reste le raccourci : envoyer sur la case survolée sans rien tenir.
Entrée     le pas que le bouton en bas à droite annonce : fonder, finir, tenir la ligne, relancer.
La caméra  Q/E : pivoter. Molette : zoomer. WASD : déplacer. R : recadrer.
La vue     H : replier ce rapport. F2 : replier l'affectation. F1 : masquer tout le HUD.
           P : voir les piles. B : le bilan de la journée. F11 : plein écran."""


## Ce que `--shot-evenings` doit valoir pour capturer l'écran de **fondation**.
##
## Zéro journée, littéralement : le run n'a pas commencé. C'est le seul état de `I2` qu'une
## capture ne pouvait sinon jamais atteindre, puisque toute journée jouée commence par
## poser le Cœur — donc le seul écran neuf du jalon que personne n'aurait regardé. La
## valeur est comparée en **texte** et non convertie, pour distinguer un « 0 » écrit
## exprès d'un drapeau absent, que `to_int()` rend tous les deux à zéro.
const SHOT_FOUNDING := "0"

## Les blocs d'équilibrage de rechange que `I2b` laisse dans `data/balance/`, et le nom qui
## veut dire « celui que `balance.tres` désigne ».
##
## Deux identifiants de contenu écrits dans un `.gd`, ce que les conventions évitent
## partout ailleurs — et c'est ici inévitable : le travail de la chronique est justement de
## **nommer** les variantes qu'elle compare, et une variante anonyme ne se compare à rien.
## Ils passent par l'index de `GameDatabase` et non par un chemin, donc un fichier déplacé
## rend un null que l'assertion de `_chronicle_balance()` nomme, plutôt qu'un `load()` muet.
const SPARE_NONE := &""
const SPARE_TWO_PHASES := &"run_balance_two_phases"
const SPARE_PERSISTENT_DECK := &"deck_balance_persistent"

var _metrics: TerrainMetrics
var _world: DevWorld
var _renderer: BuildingRenderer
var _ghost: PlacementGhost
var _targets: TargetHighlight
var _piles: PileView
var _marker: ActionMarker
var _hand_view: HandView
var _palette: CommodityPalette
var _bar: ResourceBar
var _panel: ProductionPanel
var _battle: BattlePanel
var _crew: AssignmentPanel
var _label: Label

## La ligne de survol, sortie du rapport pliable et posée sous la barre de réserve.
##
## Elle en sort parce qu'elle est la seule ligne du texte qu'on lit **en visant** : ce qu'il
## y a sous le curseur, sa hauteur, son terrain, et ce que la carte tenue y ferait. Toutes
## les autres se lisent entre deux gestes. La laisser dans le rapport revenait à choisir
## entre la voir et voir la carte — c'est-à-dire à perdre, en repliant le pavé avec H, la
## seule ligne dont on a besoin pendant qu'on vise.
##
## **Elle a été posée deux fois en haut au centre, et deux captures l'ont refusée.** Cette
## rangée-là est prise en étau : la barre de réserve la borne à gauche, le compte rendu de
## phase à droite, et une bande centrée grandit des deux côtés — « Survol : » se dessinait
## par-dessus « Minerai 0 ». Ce n'est pas une marge à régler, c'est la leçon de `W2` sur une
## rangée plutôt que sur une colonne : deux vues qui grandissent l'une vers l'autre doivent
## vivre dans le **même conteneur**, sans quoi elles se croisent au pire moment.
##
## Elle vit donc dans la colonne de gauche, juste sous la barre, où elle pousse au lieu de
## recouvrir. Elle y gagne d'ailleurs un voisinage juste : ce qu'on survole et ce qu'on
## possède se lisent d'un même regard, et le coût d'une carte tenue s'affiche à un
## centimètre de la réserve qui doit le payer.
##
## Elle n'est **pas** dans le pavé pliable : H la laisse en place, F1 l'emporte avec le
## reste du HUD. C'est exactement ce qu'on lui demande — toujours là, sauf quand on veut
## regarder la carte nue.
var _hover: Label

## Le libellé de la vague qu'on est en train de mener, et le jour où elle tombe.
##
## Retenus **avant** d'appeler `RunManager.fight()`, exactement pour la raison qui vaut
## depuis `I1` sur le libellé de phase : quand `battle_resolved` arrive, la vague est
## consommée et le cycle a avancé. Le rapport de bataille ne porte ni l'une ni l'autre —
## il dit ce que la vague a coûté, pas comment elle s'appelait.
var _battle_label := ""
var _battle_day := 0

## Identifiant -> prénom, relevé juste avant que la vague tombe.
##
## **Trouvé en capture, et c'est le défaut que `F1` avait nommé d'avance** : une table peut
## être fausse sur ce qu'elle prétend montrer. Le panneau annonçait « Pertes : bo, cy » —
## les identifiants internes — parce que `_name_of()` interroge le roster, et qu'au moment
## où `battle_resolved` arrive **les morts n'y sont plus** : `RunOrchestrator.fight()` les a
## retirés avant de rendre son rapport, ce qui est précisément l'ordre qui fait qu'un mort
## ne gagne pas d'XP. Rien ne plantait, rien ne compilait de travers, et la seule ligne du
## jeu qui raconte quelque chose disait des matricules.
var _battle_names: Dictionary[StringName, String] = {}

## Cran courant du rapport texte.
var _report_level := Report.FULL

## Les deux colonnes du HUD, gardées pour pouvoir les masquer d'un coup.
##
## Retenues plutôt que retrouvées par `get_children()` : un harnais qui irait chercher ses
## propres nœuds par leur rang dans l'arbre serait le `get_node("../../UI/HUD")` que
## `CLAUDE.md` refuse en premier, écrit à l'envers.
var _left_slot: MarginContainer
var _right_slot: MarginContainer

## Le bouton de pas et l'écran de fin, ajoutés à `P2a`.
##
## Le bouton vit dans un troisième créneau, **dans la bande de la main** et non dans la
## colonne de droite : celle-ci a débordé trois fois — `W2`, `I2`, `P1a` —, et on ne lui
## confie pas le geste le plus fréquent du jeu.
var _step_slot: MarginContainer
var _step: StepButton
var _end_screen: RunEndScreen

## Le bilan de la journée, ouvert au soir. Voir `_show_summary()`.
var _summary: DaySummaryView

## Le seed du run **courant**, qui n'est plus `SEED` dès qu'on relance.
##
## `SEED` reste la valeur d'ouverture, donc ce qu'une capture et la chronique montrent ;
## celui-ci est ce que l'écran affiche et ce qu'un relancement fait avancer. Les deux
## seraient le même tant que rien ne relance, et c'est précisément pour ça qu'il fallait
## les séparer avant : un `SEED` lu à l'écran après un relancement aurait annoncé le seed
## d'un run qu'on ne joue plus.
var _run_seed := SEED

## Ouvrier sélectionné dans le panneau, ou &"" si aucun.
##
## Il vit ici et non dans la vue, exactement comme le rang de la carte tenue : `HandView`
## a posé à `D2` qu'une vue signale et ne sélectionne pas, et une seconde vue qui
## déciderait de sa propre sélection serait la même faute écrite deux fois.
var _held_worker := &""

## Rang de la carte tenue dans Hand.cards(), ou NO_SLOT. Un **rang** et non un
## identifiant : une main tient couramment deux exemplaires du même nom, et `D2` a payé
## cette leçon au clavier.
var _held_slot := NO_SLOT

## Quarts de tour appliqués au bâtiment qu'on s'apprête à poser.
var _turns := 0

## Sens du terrassement. Il démarre à « monter » plutôt qu'à « aucun » : une carte tenue
## sans sens choisi n'allumerait aucune cible, ce qui se lirait comme une panne.
var _direction := PlayedAction.DIRECTION_UP

var _last_action := "Prendre une carte : 1 à 9, ou un clic dessus."

## Le libellé de la phase qu'on est en train de finir.
##
## Retenu **avant** d'appeler `RunManager.end_phase()`, parce que le cycle a déjà avancé
## quand `phase_resolved` arrive : à ce moment-là `RunManager.phase()` désigne la
## suivante, et le rapport ne porte que l'identifiant de celle qui vient de finir. C'est
## la seule chose que le harnais sache et que le panneau ne puisse pas retrouver.
var _ending_label := ""

## Ce que la dernière résolution a changé à la réserve, annoté sur la barre jusqu'à la
## prochaine. Il se vide dès qu'on repose une carte : un « +5 » qui survivrait à une
## dépense annoterait le mauvais chiffre.
var _last_delta: Dictionary[StringName, int] = {}

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_metrics = TerrainMetrics.from_balance(balance.terrain)
	var grid := TerrainGen.generate(SEED, balance.terrain_gen.map_size,
		balance.terrain_gen)

	RunManager.open(RunState.open(SEED, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance))

	_world = DevWorld.create(grid, _metrics, balance)
	add_child(_world)
	_renderer = BuildingRenderer.create(_state().city(), _metrics)
	add_child(_renderer)
	_ghost = PlacementGhost.create(_metrics)
	add_child(_ghost)
	_targets = TargetHighlight.create(_metrics)
	add_child(_targets)
	_marker = ActionMarker.create(_metrics)
	add_child(_marker)
	# La palette précède la main depuis `P1a` : une carte de bâtiment y affiche son coût,
	# donc elle a besoin des couleurs de ressource avant d'exister.
	_palette = CommodityPalette.from_database()
	_hand_view = HandView.create(_state().catalogue(), _palette, _make_buildings())
	_hand_view.card_picked.connect(_hold)
	add_child(_hand_view)
	_bar = ResourceBar.create(_palette)
	_panel = ProductionPanel.create(_palette)
	_battle = BattlePanel.create()
	_battle.battle_requested.connect(_fight)
	_crew = AssignmentPanel.create(_state().catalogue())
	_crew.worker_picked.connect(_on_worker_picked)
	_crew.worker_released.connect(_on_worker_released)
	_crew.action_picked.connect(_on_action_picked)
	_crew.auto_requested.connect(_on_auto_requested)
	_label = _make_label()
	_hover = _make_hover()
	_left_slot = _hud_slot(_make_left_column(), Control.SIZE_SHRINK_BEGIN,
		Control.SIZE_SHRINK_BEGIN)
	add_child(_left_slot)
	# La marge basse **se demande à la main** plutôt que d'être recopiée. Un `88.0` était
	# écrit ici, et il valait la bande d'à peu près — à trois pixels près, ce qui suffisait
	# à faire mordre le panneau sur le haut des cartes aux journées chargées. Un chiffre
	# recopié est un chiffre qui dérive : même doublon que celui qu'`E2` a retiré de la
	# réserve, et la bande sait seule ce qu'elle occupe.
	#
	# La bande **entière** et rien de plus : `CARD_GAP` y est déjà compris deux fois, donc
	# l'écart au-dessus des cartes est dedans. Lui ajouter la marge du HUD volerait seize
	# pixels de plus à une colonne de droite qui n'en a aucun à donner.
	# La colonne s'accroche **en haut** et non en bas depuis que le panneau d'affectation se
	# replie. Accrochée en bas, elle gardait le panneau contre la main et faisait dériver le
	# compte rendu de phase avec sa hauteur — replier faisait chuter le rapport de trois
	# cent cinquante pixels, alors que `W2` ne lui demande qu'une chose : rester au même
	# endroit d'une résolution à l'autre. En haut, le rapport ne bouge jamais et c'est le
	# panneau, qui vient de changer de taille exprès, qui se déplace.
	_right_slot = _hud_slot(_make_right_column(), Control.SIZE_SHRINK_END,
		Control.SIZE_SHRINK_BEGIN, HandView.band_height())
	add_child(_right_slot)
	# En dernier, donc au-dessus de tout le reste : c'est une modale, et une modale qui
	# passerait sous la main laisserait cliquer ce qu'elle est censée couvrir.
	_piles = PileView.create(_state().catalogue())
	_piles.dismissed.connect(_show_piles)
	add_child(_piles)

	# Le bouton de pas, **dans la bande de la main** et calé sur le bas des cartes. La marge
	# se demande à la main plutôt que d'être recopiée, comme celle de la colonne de droite
	# depuis `P1b` : la bande seule sait où elle commence et où elle finit.
	_step = StepButton.create()
	_step.step_requested.connect(_press_on)
	_step_slot = _hud_slot(_step, Control.SIZE_SHRINK_END, Control.SIZE_SHRINK_END,
		HandView.band_bottom())
	add_child(_step_slot)

	# En dernier, donc au-dessus de la vue des piles elle-même : un run fini l'est pendant
	# qu'une modale est ouverte comme pendant qu'elle ne l'est pas, et le verdict passe
	# devant tout le reste.
	# Le bilan de la journée, sous l'écran de fin et au-dessus du reste : les deux sont des
	# modales, et une partie finie passe devant une journée à lire.
	_summary = DaySummaryView.create(_palette)
	_summary.close_requested.connect(_press_on)
	_summary.dismissed.connect(_summary.dismiss)
	add_child(_summary)

	_end_screen = RunEndScreen.create()
	_end_screen.restart_requested.connect(_restart)
	_end_screen.dismissed.connect(_end_screen.dismiss)
	add_child(_end_screen)

	EventBus.phase_resolved.connect(_on_phase_resolved)
	EventBus.battle_pending.connect(_on_battle_pending)
	EventBus.battle_resolved.connect(_on_battle_resolved)
	# `run_finished` et non `run_ended` : `EventBus` distingue la partie **jouée** de la
	# partie **rangée**, et son commentaire dit depuis `I2` qu'« un écran de fin vit entre
	# les deux ». Écouter la seconde ferait apparaître le verdict au moment où le run
	# disparaît, donc trop tard pour en lire quoi que ce soit.
	EventBus.run_finished.connect(_on_run_finished)
	# Le bilan s'ouvre à l'entrée d'une phase qui ne fait que fermer la journée, et c'est
	# `phase_changed` qui le dit — jamais un nom de phase, que `DESIGN.md` 2 interdit.
	EventBus.phase_changed.connect(_on_phase_changed)
	# La première ligne du jeu doit parler du premier geste. « Prendre une carte » était
	# vrai tant qu'un run s'ouvrait Cœur posé et main tirée ; depuis `I2` il n'y a ni
	# l'un ni l'autre, et l'écran conseillerait un geste que le domaine refuse.
	if _state().awaits_its_heart():
		_last_action = "Poser le Cœur : un clic sur la carte, ou Entrée pour la case suggérée."
	_refresh_targets()
	# Avant la capture, et exclusive d'elle : la chronique rouvre le run quatre fois, donc
	# une image prise après elle montrerait la dernière variante et non celle de `data/`.
	# Elle quitte d'elle-même, ce qui rend l'ordre suffisant sans qu'un garde s'y ajoute.
	_chronicle_if_asked()
	_capture_if_asked()

## Le survol change sans que rien ne soit joué — la souris bouge, la caméra tourne — donc
## le fantôme et le rapport se refont à chaque image. Les cibles, elles, ne bougent qu'à un
## changement de carte, de sens, de pose ou de phase.
##
## La barre de ressources y est aussi, et c'est délibéré : elle met ses nœuds à jour sur
## place plutôt que de se reconstruire, donc elle ne coûte rien par image. La rafraîchir
## sur événement aurait demandé de lister tous les gestes qui touchent la bourse — poser
## un bâtiment, résoudre, et demain piller —, et un oubli dans cette liste se serait vu
## comme une réserve qui ne bouge pas.
func _process(_delta: float) -> void:
	_refresh_ghost()
	_refresh_light()
	_bar.show_ledger(_state().ledger(), _last_delta)
	_crew.set_height_budget(_crew_budget())
	_crew.show_state(_state(), _held_worker, RunManager.phase())
	# Le bouton de pas est relu à chaque image, comme le panneau d'affectation et pour la
	# même raison : sa réponse dépend de l'état du run, donc de six gestes différents.
	# Le rafraîchir sur événement aurait demandé de les énumérer, et un oubli dans cette
	# liste se lirait comme un bouton qui propose le pas d'avant. Il ne redessine rien tant
	# que le libellé ne change pas.
	_step.show_state(_state())
	_label.text = _report()
	_hover.text = _hover_line()

## Où en est le soleil, selon où en est la journée.
##
## La fraction est `phase_index / (phase_count - 1)` : la **position** de la phase dans sa
## journée, jamais son nom, ce que `DESIGN.md` 2 interdit depuis `I1`. Deux phases donnent
## donc un matin et un soir ; une journée à trois phases gagnerait un midi sans qu'une
## ligne bouge ici, et une journée à une seule phase se joue à midi — le seul moment qui
## ait un sens quand il n'y a pas de « plus tard ».
##
## La nuit tombe sur les deux états où la journée ne se joue plus : une **bataille armée**,
## qui est le soir d'une journée refermée depuis `I2`, et un **run fini**. Les deux se lisent
## déjà sur le run ; aucun drapeau n'a été ajouté pour éclairer quoi que ce soit.
##
## Appelé à chaque image et non sur événement, par la règle que `CLAUDE.md` pose pour les
## vues : énumérer les gestes qui changent le moment — franchir une phase, armer une vague,
## la résoudre, finir le run, fonder — c'est se donner cinq occasions d'en oublier un, et
## l'oubli se lirait comme un soleil bloqué. Le plateau ne glisse que si le moment a bien
## changé, donc l'appel ne coûte rien.
func _refresh_light() -> void:
	var cycle := _state().cycle()
	if cycle.is_over() or _state().awaits_a_battle():
		_world.light_night()
		return
	_world.light_day(_day_progress(cycle))

## La position de la phase courante dans sa journée, de 0 à 1.
##
## Une journée d'une seule phase rend 0.5 et non 0 : la division serait par zéro, et
## « la seule phase de la journée » n'est pas plus un lever qu'un coucher.
static func _day_progress(cycle: DayCycle) -> float:
	if cycle.phase_count() <= 1:
		return 0.5
	return float(cycle.phase_index()) / float(cycle.phase_count() - 1)

## Ce qui reste au panneau d'affectation une fois la colonne servie.
##
## C'est le harnais qui répond, et pas le panneau, parce que c'est lui qui a bâti la
## colonne : la marge du HUD, la bande de la main et la hauteur du compte rendu de phase
## sont trois choses qu'il a posées lui-même. Les faire mesurer par le panneau lui aurait
## demandé de connaître ses voisins, ce qu'aucune vue de ce projet ne fait.
##
## Le plafond de la colonne est **demandé à la main**, qui sait où elle commence, et non
## déduit de la taille du conteneur qui porte la colonne. La première version faisait
## l'inverse et laissait passer 28 px : un `MarginContainer` prend le **plus grand** de son
## ancrage et de la taille minimale de son contenu, donc le vôtre grandit avec le panneau
## à mesure que le panneau grandit. Un budget tiré de là se desserre exactement quand il
## devrait serrer — il borne une hauteur à partir d'elle-même.
##
## Les trois termes, dans l'ordre : le haut de la bande de la main, la marge haute du HUD,
## puis le compte rendu et l'écart qui l'en sépare. Aucun n'est un chiffre recopié — la
## main dit où elle est, `_panel.size.y` est ce que le rapport mesure cette image-ci, et
## `REPORT_MARGIN` est la constante que la colonne emploie déjà pour les deux.
##
## Recalculé à chaque image exprès : la fenêtre se redimensionne, et le compte rendu de
## phase change de longueur d'une résolution à l'autre.
func _crew_budget() -> float:
	var column := _hand_view.global_position.y - REPORT_MARGIN
	return column - _panel.size.y - REPORT_MARGIN

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_left_click_here()
		MOUSE_BUTTON_RIGHT:
			_withdraw_here()
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	# La vue des piles est **modale** : tant qu'elle couvre l'écran, les seules touches qui
	# répondent sont celles qui la referment. C'est la contrepartie de son voile — laisser
	# jouer une carte derrière un panneau qui cache la carte serait exactement le geste
	# qu'aucune image ne permet de vérifier.
	if _piles.visible:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			_show_piles()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_TAB:
			_turn_the_held_card()
		KEY_SPACE:
			_staff_here()
		KEY_BACKSPACE:
			_unstaff_here()
		KEY_ENTER, KEY_KP_ENTER:
			_press_on()
		KEY_B:
			_show_summary()
		KEY_H:
			_cycle_report()
		KEY_F1:
			_toggle_hud()
		KEY_F2:
			_fold_crew()
		KEY_P:
			_show_piles()
		_:
			var slot := event.keycode - KEY_1
			if slot < 0 or slot >= SLOT_KEYS:
				return
			_hold(slot)
	get_viewport().set_input_as_handled()

# --- Les gestes -----------------------------------------------------------------------

## Fait passer le rapport texte au cran suivant : complet, l'essentiel, masqué.
##
## Le premier confort demandé, et le plus mérité : le pavé couvre la moitié gauche de la
## carte en permanence, alors que la moitié de ses lignes ne change jamais.
func _cycle_report() -> void:
	_report_level = (_report_level + 1) % REPORT_NAMES.size()
	_label.visible = _report_level != Report.HIDDEN
	_last_action = "Rapport : %s. H pour changer." % REPORT_NAMES[_report_level]

## Masque ou remontre tout le HUD, main comprise.
##
## Un cran plus loin que le précédent, et pour un autre usage : celui-ci ne sert pas à
## jouer mais à **regarder** — le village entier, le relief, ce qu'une vague a cassé. C'est
## aussi ce qui rend une capture propre possible sans toucher au code.
##
## Il masque la main, donc il empêche de jouer, et c'est assumé : un mode où l'on ne voit
## rien mais où l'on peut tout faire serait un piège plus désagréable que le pavé qu'on
## vient d'enlever.
func _toggle_hud() -> void:
	var shown := not _left_slot.visible
	_left_slot.visible = shown
	_right_slot.visible = shown
	_hand_view.visible = shown
	_step_slot.visible = shown
	if shown:
		_last_action = "HUD rendu. F1 pour le remasquer."

## Ouvre la liste des piles, ou la referme.
##
## Elle remplace les trois lignes de compteurs que le pavé de texte portait depuis `I1`, et
## elle les remplace au lieu de les doubler : `DESIGN.md` 8 demande « une pioche et une
## défausse consultables, plutôt que trois compteurs », et garder les deux aurait laissé le
## même chiffre lisible à deux endroits — le doublon qu'`E2` puis `W2` ont chacun retiré
## en prenant un morceau de ce pavé.
##
## Le contenu se relit à l'ouverture et pas à chaque image : une pile ne bouge qu'à la
## pioche ou à la défausse, et rien de tout ça ne peut arriver pendant qu'une modale
## bloque les gestes.
func _show_piles() -> void:
	var shown := _piles.toggle(_state().deck())
	_last_action = "Les piles. P, Échap, ou un clic pour refermer." if shown 		else "Piles refermées. P pour les revoir."

## Replie le panneau d'affectation sur sa barre de tête, ou le rouvre.
##
## Le troisième cran de dégagement du HUD, et il complète les deux autres au lieu de les
## doubler. `H` ne touche qu'au pavé de texte à gauche ; `F1` emporte tout, main comprise,
## donc empêche de jouer. Celui-ci rend la moitié droite de la carte **sans rien perdre de
## jouable** : la barre de tête garde le compte des ouvriers, le bouton **Auto** et le
## liseré de phase, et les cartes redeviennent entièrement visibles.
##
## Le geste existe aussi au clic, sur le chevron du panneau, et c'est le chemin principal —
## cette touche n'est que le raccourci. C'est l'inverse du partage d'avant `P1a`, où le
## clavier commandait et où la souris ne suivait pas.
##
## Le panneau garde son propre état plié : c'est de l'affichage, pas du jeu. Le harnais ne
## fait que dire ce qui vient d'arriver, comme pour les deux autres crans.
func _fold_crew() -> void:
	_last_action = "Affectation repliée. F2 pour la rouvrir." if _crew.toggle_folded() \
		else "Affectation rouverte."

## Prend en main la carte de ce rang, ou la repose si elle y était déjà.
func _hold(slot: int) -> void:
	if slot < 0 or slot >= _state().deck().hand().size():
		_last_action = "Aucune carte au rang %d." % (slot + 1)
		return
	_held_slot = NO_SLOT if slot == _held_slot else slot
	var held := _held_card()
	_last_action = "Reposé." if held.is_empty() else "En main : %s." % _label_of(held)
	_refresh_targets()

## Tab agit sur ce que la carte tenue **ferait** : elle pivote un bâtiment, elle retourne
## un terrassement. Une seule touche pour une seule idée, plutôt qu'une par verbe.
func _turn_the_held_card() -> void:
	var held := _held_card()
	if held == SiteResolver.CARD_TERRAFORM:
		_direction = -_direction
		_last_action = "Terrassement : %s." % _sense()
		_refresh_targets()
		return
	_turns = posmod(_turns + 1, BuildingData.QUARTER_TURNS)
	_last_action = "Orientation : %s." % _orientation()

## Ce que le clic gauche fait du sol : il envoie l'ouvrier tenu, ou il joue la carte tenue.
##
## **Le premier confort que `DESIGN.md` 8 réclame**, et sa formulation dit tout : « un
## glisser-déposer, ou un clic sur la fiche puis un clic sur la case, mais pas les deux
## moitiés dans deux langues ». Jusqu'ici on cliquait une fiche — geste de souris — puis
## on appuyait sur **Espace** — geste de clavier — en visant la case avec la souris. Une
## intention, deux vocabulaires, et le second ne s'apprend qu'en lisant l'aide.
##
## L'ordre des trois questions n'est pas indifférent, et chacune a sa raison :
##
##   - **fonder passe avant tout**, parce qu'aucun des deux autres gestes n'a de sens sur
##     une carte nue — il n'y a ni main tirée ni action posée avant le Cœur.
##   - **l'ouvrier passe avant la carte**, et le cas où les deux sont tenus le montre : une
##     case qui porte déjà une action refuse d'en recevoir une seconde depuis `I2`, donc
##     jouer y serait de toute façon refusé. Envoyer est la seule lecture qui reste.
##   - **la carte ferme la marche**, ce qui laisse `_play_here()` exactement tel qu'il
##     était. Ce fichier n'a pas gagné une règle, il a gagné un aiguillage.
##
## C'est le clic **sur le sol** et non sur le panneau : les fiches et les lignes d'action
## portent `MOUSE_FILTER_STOP` et se servent d'abord, ce qui est le partage que `CLAUDE.md`
## décrit. Cliquer une ligne d'action reste donc le chemin du panneau, et il ne change pas.
func _left_click_here() -> void:
	if _state().awaits_its_heart():
		_play_here()
		return
	if not _held_worker.is_empty():
		var action := _action_here()
		if action != null:
			_staff_on(action)
			return
	_play_here()

## Joue la carte tenue sur la cellule survolée.
##
## Un seul chemin pour les deux natures de carte, à l'inverse du harnais Cartes qui en
## avait deux : `RunOrchestrator.play()` est la porte unique, et c'est lui qui sait
## laquelle des deux il a sous la main.
func _play_here() -> void:
	var hovered := _world.cursor().hovered()
	if _state().awaits_its_heart():
		if not hovered.is_hit():
			_last_action = "Rien sous le curseur — le Cœur se pose sur la carte."
			return
		_found_at(hovered.cell())
		return
	var held := _held_card()
	if held.is_empty():
		# Tenir un ouvrier et cliquer une case nue est un geste juste qui vise à côté, pas
		# une erreur de main : lui répondre « aucune carte » enverrait chercher la
		# mauvaise moitié de l'intention.
		_last_action = "Aucune carte en main — 1 à 9, ou un clic sur une carte." \
			if _held_worker.is_empty() \
			else "%s en main — cliquer une action posée pour l'y envoyer." \
				% _name_of(_held_worker)
		return
	if not hovered.is_hit():
		_last_action = "Rien sous le curseur."
		return
	var result := RunManager.play(held, hovered.cell(), _turns, _direction)
	if not result.is_ok():
		_last_action = "Refusé : %s en %s — %s" % [_label_of(held), hovered.cell(),
			result.reason()]
		return
	if result.posts_an_action():
		_last_action = "Posé : %s en %s, %d poste(s), 0 ouvrier." % [
			_label_of(held), result.anchor(), result.action().capacity()]
	else:
		_renderer.rebuild(_state().city())
		# La bourse vient d'être débitée : le delta de la dernière résolution n'annote
		# plus le chiffre qu'il commentait, et un « +5 » à côté d'une réserve qui vient
		# de baisser de 20 se lirait à l'envers.
		_last_delta = {}
		_last_action = "Chantier ouvert : %s en %s, %s — payé %s." % [
			_label_of(held), result.anchor(), _orientation(),
			_cost_text(result.paid())]
	_release()

func _withdraw_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	if not RunManager.withdraw(action.id()):
		_last_action = "Retrait refusé — %s ne le permet pas." % _phase_label()
		return
	_last_action = "Retiré : %s en %s — la carte revient en main." % [
		_label_of(action.card()), action.target()]
	# La main vient de changer, donc un **rang** dans la main ne désigne plus la même
	# carte : la carte rendue s'insère dans son pool et décale tout ce qui suit. C'est le
	# même piège que `D2` a payé au clavier, et la même réponse que `_play_here()` — tout
	# geste qui touche la main repose ce qu'on tenait.
	_release()

## Envoie un ouvrier sur l'action sous le curseur : le sélectionné, ou le meilleur.
##
## Le premier ouvrier libre a tenu de `D2` à `E2`, et son commentaire renvoyait déjà ici :
## `DESIGN.md` 3.4 dit que **qui** l'on place est la décision de fond d'une phase. Elle se
## prend maintenant dans le panneau ; cette touche en est le raccourci, et c'est la même
## règle qui la sert — `StaffingAdvisor` classe, on prend le premier du classement. Le
## bouton n'est donc pas un chemin à part : c'est ce geste-ci répété.
func _staff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	_staff_on(action)

## Envoie l'ouvrier tenu — ou le meilleur de son métier — sur cette action.
func _staff_on(action: PlayedAction) -> void:
	var worker := _held_worker if not _held_worker.is_empty() else _best_for(action)
	if worker.is_empty():
		_last_action = "Plus aucun ouvrier libre — tout le monde est déjà au travail."
		return
	if not RunManager.staff(worker, action.id()):
		_last_action = "%s en %s : %s" % [_label_of(action.card()), action.target(),
			_staffing_refusal(worker, action)]
		return
	_held_worker = &""
	_last_action = "%s -> %s en %s (%d/%d)." % [
		_name_of(worker), _label_of(action.card()), action.target(),
		_state().staffed_on(action.id()).size(), action.capacity()]
	_refresh_markers()

## Le meilleur ouvrier libre pour cette action, ou &"" s'il n'y en a aucun.
##
## Le classement vient du domaine et n'est pas refait ici : c'est celui-là même que le
## bouton suit, donc la touche et le bouton ne peuvent pas envoyer deux personnes
## différentes. Deux classements auraient dérivé, exactement comme deux tables de ciblage
## l'auraient fait à `D2`.
func _best_for(action: PlayedAction) -> StringName:
	var family := StaffingAdvisor.family_of(action, _state().terrain(),
		_state().city().to_snapshot(), _state().balance().actions)
	var ranked := StaffingAdvisor.ranked_for(_state().free_workers(), _state().labor(),
		family)
	return &"" if ranked.is_empty() else ranked[0]

## Le refus d'affectation, en clair et avec le geste qui le lève.
##
## La raison vient du domaine et n'est pas redevinée ici : l'écran ne fait que traduire.
## Sans cette traduction, la touche paraissait morte — le premier essai au clavier a
## donné un « refusé » sans cause, alors que la phase courante l'expliquait entièrement.
func _staffing_refusal(worker: StringName, action: PlayedAction) -> String:
	var reason := RunOrchestrator.staffing_refusal(_state(), worker, action.id())
	match reason:
		PlayResult.REASON_WRONG_PHASE:
			return "affecter n'est pas permis en phase « %s ». Entrée pour la finir." \
				% _phase_label()
		RunOrchestrator.REASON_NO_ROOM:
			return "ses %d poste(s) sont pris. Retour arrière pour les rappeler." \
				% action.capacity()
		RunOrchestrator.REASON_ALREADY_STAFFED:
			return "%s tient déjà une autre action." % _name_of(worker)
		RunOrchestrator.REASON_ABSENT_WORKER:
			return "%s est absent." % _name_of(worker)
		RunOrchestrator.REASON_NO_ACTION:
			return "cette action n'est plus posée."
	return "refusé (%s)." % reason

## Prend une fiche en main, ou la repose si elle y était déjà. Même geste que pour une
## carte, et volontairement : ce sont les deux moitiés d'une même intention.
func _on_worker_picked(worker: StringName) -> void:
	_held_worker = &"" if worker == _held_worker else worker
	if _held_worker.is_empty():
		_last_action = "Reposé."
		return
	_last_action = "%s en main — cliquer son action, sur la carte ou dans la liste." \
		% _name_of(worker)

## Rappelle cet ouvrier de là où il est, sans toucher à l'action.
##
## Le geste symétrique de la prise en main, et il manquait : rappeler quelqu'un demandait
## jusqu'ici de viser son action sur la carte et de rappeler **tout le monde** avec Retour
## arrière. Retirer un seul ouvrier d'un poste à deux places était donc impossible sans
## défaire les deux.
##
## `RunState.release_worker()` répond, et il n'y a pas de porte d'orchestrateur pour ça :
## rappeler un ouvrier ne pose aucune des cinq questions que `staffing_refusal()` juge —
## il était placé, il ne l'est plus. La phase, elle, est bien gardée : le brouillon ne
## survit pas à une résolution, et une phase qui n'affecte pas n'a personne à rappeler.
func _on_worker_released(worker: StringName) -> void:
	if not _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		_last_action = "Rappeler n'est pas permis en phase « %s »." % _phase_label()
		return
	if not _state().release_worker(worker):
		_last_action = "%s ne tenait aucun poste." % _name_of(worker)
		return
	if _held_worker == worker:
		_held_worker = &""
	_last_action = "%s rappelé." % _name_of(worker)
	_refresh_markers()

func _on_action_picked(action: int) -> void:
	var posted := _state().board().at(action)
	if posted == null:
		_last_action = "Cette action n'est plus posée."
		return
	_staff_on(posted)

## Le bouton d'auto-affectation. Il ne calcule rien ici : le domaine plane, l'orchestrateur
## applique, et l'écran ne fait que compter ce qui est parti.
func _on_auto_requested() -> void:
	var placed := RunManager.auto_staff()
	if placed.is_empty():
		_last_action = "Auto : rien à remplir — %s." % _why_auto_did_nothing()
		return
	var names := PackedStringArray()
	for worker in placed:
		names.append(_name_of(worker))
	_held_worker = &""
	_last_action = "Auto : %d ouvrier(s) placé(s) — %s." % [placed.size(),
		", ".join(names)]
	_refresh_markers()

## Pourquoi le bouton n'a rien fait. Trois causes, et aucune n'est une panne — c'est la
## leçon de `I1` sur le refus muet, appliquée au seul geste de `W2` qui puisse ne rien
## produire sans que rien ne soit cassé.
func _why_auto_did_nothing() -> String:
	if not _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		return "affecter n'est pas permis en phase « %s »" % _phase_label()
	if _state().free_workers().is_empty():
		return "tout le monde est déjà au travail"
	return "aucun poste libre sur ce qui est posé"

func _unstaff_here() -> void:
	var action := _action_here()
	if action == null:
		_last_action = "Aucune action posée sous le curseur."
		return
	var recalled := RunManager.unstaff(action.id())
	_last_action = "%d ouvrier(s) rappelé(s) de %s." % [
		recalled.size(), _label_of(action.card())]
	_refresh_markers()

## Entrée fait avancer le run, quoi qu'il attende : elle fonde, elle mène la bataille, ou
## elle finit la phase.
##
## Une seule touche pour une seule idée — « je suis prêt » —, comme Tab agit sur ce que la
## carte tenue **ferait**. Les trois attentes sont exclusives et le domaine les distingue
## déjà ; une touche par cas aurait demandé au joueur de savoir laquelle avant d'appuyer.
##
## Fonder par Entrée pose le Cœur sur la case que le domaine suggère. C'est le « bouton par
## défaut » que `F1` annonçait pour le déploiement automatique, et c'est le même geste :
## la règle automatique de `I1` survit comme raccourci, le clic reste le choix.
func _press_on() -> void:
	# Un run fini passe en premier, et c'est la seule question qui vaille alors : les trois
	# autres portent sur une journée qui n'existe plus. C'est aussi ce qui fait que le
	# bouton de pas n'a jamais d'état mort — `StepButton.show_state()` départage dans le
	# même ordre, et les deux chemins doivent dire la même chose.
	if _state().cycle().is_over():
		_restart()
		return
	if _state().awaits_its_heart():
		_found_at(_state().suggested_heart_anchor())
		return
	if _state().awaits_a_battle():
		_fight()
		return
	_end_phase()

## Referme le run courant et en ouvre un neuf, sur le seed suivant.
##
## **Le seed suivant et non un tirage libre.** Un seed au hasard rendrait le harnais
## différent à chaque lancement, donc les captures incomparables d'une session à l'autre —
## ce que ce projet refuse depuis `I0`, et ce que la chronique de `I2b` exige pour que
## quatre variantes se comparent. `+ 1` est frais pour le joueur et reproductible pour nous,
## et l'écran l'affiche pour qu'on puisse revenir à un run précis quand on le veut.
##
## Le relief est **régénéré** : c'est un run neuf, pas une reprise. Le monde le reçoit par
## `show_grid()` plutôt que d'être reconstruit — `DevWorld` sait repointer ses trois
## renderers et son curseur, et refaire l'arbre perdrait la caméra là où le joueur l'avait
## laissée.
##
## Tout ce que le harnais tenait du run précédent est remis à zéro ici, et il faut que la
## liste soit exhaustive : un `_battle_names` oublié ferait nommer les morts d'hier dans la
## bataille de demain — exactement le défaut que `I2` a trouvé en capture, retourné.
func _restart() -> void:
	var balance := GameDatabase.get_balance()
	_run_seed += 1
	if RunManager.is_running():
		RunManager.close()
	var grid := TerrainGen.generate(_run_seed, balance.terrain_gen.map_size,
		balance.terrain_gen)
	RunManager.open(RunState.open(_run_seed, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance))
	_world.show_grid(grid)
	_renderer.rebuild(_state().city())
	_held_slot = NO_SLOT
	_held_worker = &""
	_turns = 0
	_direction = PlayedAction.DIRECTION_UP
	_battle_label = ""
	_battle_day = 0
	_battle_names = {}
	_ending_label = ""
	_last_delta = {}
	_panel.clear()
	_battle.clear()
	_summary.dismiss()
	_end_screen.dismiss()
	_last_action = "Poser le Cœur : un clic sur la carte, ou Entrée pour la case suggérée."
	_refresh_targets()

## Le run vient de se terminer : on montre comment.
##
## Le seed lui est **passé** plutôt que lu sur le run : l'écran vit entre `run_finished` et
## `run_ended`, donc entre le moment où la partie est jouée et celui où `RunManager` la
## range, et lui faire redemander un état qui peut déjà avoir disparu serait une
## dépendance de plus pour rien.
func _on_run_finished(outcome: RunOutcome) -> void:
	# Le bilan de la dernière journée s'efface : deux modales empilées feraient lire un
	# récapitulatif de journée derrière un verdict de run, et la partie est finie.
	_summary.dismiss()
	_end_screen.show_outcome(outcome, _run_seed)

## Une phase vient de commencer. Le bilan de la journée s'ouvre si c'est le moment de lire.
##
## **Le moment se demande au domaine et jamais à un nom de phase** : c'est une phase qui
## ferme la journée et n'autorise aucun geste, donc une phase où il n'y a rien d'autre à
## faire que lire. `DESIGN.md` 2 en fait la seconde moitié du soir, et cette condition-là
## est ce qui garde la promesse d'échanger la journée par un `.tres` — un modèle dont la
## dernière phase se joue encore n'ouvre pas de modale par-dessus les cartes.
func _on_phase_changed(_day: int, _phase: StringName) -> void:
	if _is_a_reading_phase():
		_show_summary()

## La phase courante est-elle une phase où l'on ne fait que lire ?
func _is_a_reading_phase() -> bool:
	var cycle := _state().cycle()
	if cycle.is_over() or not cycle.closes_the_day():
		return false
	return not cycle.permits(PhaseDef.ACTION_PLAY) \
		and not cycle.permits(PhaseDef.ACTION_ASSIGN)

## Ouvre le bilan de la journée, ou le referme s'il est déjà là.
##
## La vague est **nommée** à la vue plutôt que devinée par elle : ce qui tombe cette nuit
## se lit sur le calendrier de `data/balance/`, et un panneau qui irait le chercher
## connaîtrait l'équilibrage. Même partage que les prénoms des morts sur `BattlePanel`.
func _show_summary() -> void:
	if _summary.visible:
		_summary.dismiss()
		return
	var summary := RunManager.day_summary()
	if summary == null:
		return
	var slot := _state().balance().run.wave_on(_state().cycle().day())
	_summary.show_summary(summary, _state().ledger(),
		_state().balance().economy.upkeep_resource,
		"" if slot == null else slot.label)

## Termine la phase. C'est `RunManager` qui décide si ça résout — le harnais ne connaît
## pas la journée, il la traverse.
##
## Trois suites depuis `I2` et non plus deux : la phase suivante, la fin du run, ou une
## **bataille qui attend**. La troisième se lit à ce que le cycle n'a pas bougé, et il
## fallait la nommer : annoncer « au tour de Matin » alors qu'on est toujours au Matin qui
## vient de finir serait un écran qui ment sur ce qu'il attend.
## Elle **rend** le rapport depuis `I2b`, et c'est ce qui permet à la chronique de mesurer
## une partie sans court-circuiter le geste. `P1a` a payé une fois le raccourci inverse —
## un scripteur qui appelait `RunManager` en direct capturait un écran d'avant ses propres
## poses. Un appelant qui veut lire ce qu'une phase a rendu passe donc par ici comme le
## clavier, et rien ne se dédouble.
func _end_phase() -> PhaseReport:
	if _state().cycle().is_over():
		_last_action = "Run terminé."
		return null
	var finished := _phase_label()
	_ending_label = finished
	# La phase qu'on quitte était peut-être celle qu'on lisait, donc le bilan se referme —
	# **avant** l'appel et non après. `RunManager.end_phase()` publie `phase_changed`, donc
	# la phase suivante peut rouvrir le bilan dans cette ligne même : refermer ensuite le
	# rouvrait puis le fermait aussitôt, et le soir s'affichait sans son bilan.
	_summary.dismiss()
	var report := RunManager.end_phase()
	_held_slot = NO_SLOT
	_refresh_targets()
	if _state().awaits_a_battle():
		_last_action = "%s terminée — %s en approche. Entrée pour tenir la ligne." % [
			finished, _state().pending_wave().label]
		return report
	if _state().cycle().is_over():
		_last_action = "%s terminée — %s." % [finished, _outcome_word(_state().outcome())]
		return report
	_last_action = "%s terminée. Au tour de %s." % [finished, _phase_label()]
	return report

## Pose le Cœur sur cette cellule, et ouvre la première journée.
##
## Le refus vient du domaine et n'est pas redeviné ici — `PlacementValidator` répond, comme
## pour n'importe quelle carte de bâtiment. C'est le tout premier geste d'un run, donc
## l'endroit où un refus muet coûterait le plus cher.
func _found_at(cell: Vector2i) -> void:
	if cell == NO_CELL:
		_last_action = "Aucune place pour le Cœur sur ce relief."
		return
	var result := RunManager.found(cell, _turns)
	if not result.is_ok():
		_last_action = "Cœur refusé en %s — %s" % [cell, result.reason()]
		return
	_renderer.rebuild(_state().city())
	_last_action = "Cœur posé en %s. La première journée commence." % cell
	_refresh_targets()

## Fait tomber la vague en attente.
##
## Le libellé et le jour sont retenus **avant** l'appel : la vague est consommée et le
## cycle a avancé quand le signal arrive.
func _fight() -> BattleReport:
	if not _state().awaits_a_battle():
		_last_action = "Aucune vague en approche."
		return null
	_battle_label = _state().pending_wave().label
	_battle_day = _state().cycle().day()
	_battle_names = {}
	for worker in _state().roster().workers():
		_battle_names[worker.id()] = worker.given_name()
	var report := RunManager.fight()
	_held_slot = NO_SLOT
	_refresh_targets()
	# Les murs sont tombés et le relief n'a pas bougé : seul le rendu de la ville est à
	# refaire. C'est aussi le seul endroit du harnais où un bâtiment disparaît sans qu'un
	# geste du joueur l'ait visé.
	_renderer.rebuild(_state().city())
	if _state().cycle().is_over():
		_last_action = "%s : %s." % [_battle_label, _outcome_word(_state().outcome())]
		return report
	_last_action = "%s repoussée." % _battle_label if report.is_held() 		else "%s a frappé. Au tour de %s." % [_battle_label, _phase_label()]
	return report

## Le seul endroit du harnais qui réagit à un signal plutôt qu'à une touche, et c'est ce
## que `I0` avait dessiné : le domaine retourne, `RunManager` publie, l'écran écoute.
##
## `E2` a sorti d'ici le pavé de texte que `I1` fabriquait à la main : c'est le panneau
## qui met en forme le rapport, et le harnais ne fait plus que le lui passer. Il ne
## calcule qu'une chose, le delta de la réserve, et par une fonction de la vue.
func _on_phase_resolved(report: PhaseReport) -> void:
	_panel.show_report(report, _ending_label)
	_crew.show_progress(report.progress())
	# La résolution a vidé le brouillon d'affectation : garder une fiche en main
	# encadrerait un choix que plus rien ne porte.
	_held_worker = &""
	_last_delta = ResourceBar.delta_of(report,
		_state().balance().economy.upkeep_resource)
	# Le relief a pu bouger sous un terrassement, et la ville sous un chantier. Refaire
	# les deux plutôt que de deviner lequel : deux résolutions par jour, le coût est nul.
	_world.show_grid(_state().grid())
	_renderer.rebuild(_state().city())

## La vague est armée et n'est pas encore tombée : le seul moment que `DESIGN.md` 3.8 fait
## exister, et le seul où l'on peut encore regarder ce qu'on lui oppose.
##
## Les deux chiffres viennent du Combat et ne sont pas refaits ici. Un écran qui
## additionnerait des points de défense serait une seconde règle de combat, et celle qui
## s'afficherait ne serait pas celle qui frappe — le même piège que deux tables de ciblage
## à `D2`.
func _on_battle_pending(_wave: StringName) -> void:
	var balance := _state().balance()
	var city := _state().city().to_snapshot()
	var force := _state().roster().to_combat(balance.combat.combat_skill_family,
		balance.workforce, balance.combat)
	var slots := InstantCombatResolver.slots_for(city, balance.combat)
	_battle.show_pending(_state().pending_wave(), _state().cycle().day(),
		InstantCombatResolver.defense_of(city, force, balance.combat),
		InstantCombatResolver.deploy(force, slots).size())

## Ce que la vague a coûté. Les prénoms sont traduits ici : le panneau ne connaît pas le
## roster, et c'est ce que `E2` a posé pour `ProductionPanel`.
##
## Ils viennent du relevé pris **avant** la bataille et non du roster, qui ne connaît plus
## les morts — voir `_battle_names`.
func _on_battle_resolved(report: BattleReport) -> void:
	var names := PackedStringArray()
	for fallen in report.damage().lost():
		names.append(_battle_names.get(fallen, String(fallen)))
	_battle.show_report(report, _battle_label, _battle_day, names)
	_crew.show_progress(report.progress())

# --- Les rafraîchissements -------------------------------------------------------------

func _release() -> void:
	_held_slot = NO_SLOT
	_refresh_targets()

func _refresh_markers() -> void:
	_marker.rebuild(_state().board().to_plan(), _state().to_assignment(),
		_state().terrain())

## Recalcule le jeu de cibles de la carte tenue. Un balayage complet de la carte, et il
## n'a lieu qu'ici : à une prise de carte, un retournement, une pose, un retrait, une
## fondation, une bataille ou une fin de phase.
##
## **Cette liste a cessé d'être une commodité à `P1a` et est devenue une obligation.** La
## main y est redessinée, et depuis que ses cartes de bâtiment pâlissent quand la réserve
## ne les paie pas, elle affiche une réponse qui dépend du `Ledger` — donc tout geste qui
## déplace la réserve doit passer par ici, sinon une carte reste pâle après la récolte qui
## vient de la rendre payable. Les cinq qui la déplacent y passent : bâtir la débite,
## fonder ouvre le run, la fin de phase produit et prélève, la bataille pille.
##
## L'appeler depuis `_process` serait le remède évident et ce serait le mauvais :
## `show_hand()` reconstruit tous ses nœuds, donc la main perdrait son survol soixante
## fois par seconde. C'est le cas que `CLAUDE.md` distingue — une vue qu'on rafraîchit à
## chaque image met ses nœuds à jour **sur place**, et celle-ci ne le fait pas.
func _refresh_targets() -> void:
	_refresh_markers()
	_hand_view.show_hand(_state().deck().hand(), _held_slot, _state().ledger(),
		_state().cycle())
	var held := _held_card()
	if held.is_empty() or not ActionTargeting.handles(held):
		_targets.clear()
		return
	var cells: Array[Vector2i] = []
	var heights := PackedInt32Array()
	var extent := _state().terrain().size()
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			if not _validate(held, cell).is_ok():
				continue
			cells.append(cell)
			heights.append(_state().terrain().height_at(cell))
	_targets.show_targets(cells, heights)

## Montre ce que poserait une carte de bâtiment sous le curseur.
##
## Le fantôme ne dit **que** le placement, et c'est assumé : la bourse est la seconde
## question, elle se lit sur la ligne de survol. Un fantôme qui virerait au rouge faute de
## bois mélangerait deux refus que `DESIGN.md` 3.2 sépare exprès.
func _refresh_ghost() -> void:
	var hovered := _world.cursor().hovered()
	var data := _founding_data() if _state().awaits_its_heart() 		else _building_of(_held_card())
	if not hovered.is_hit() or data == null:
		_ghost.clear()
		return
	var result := PlacementValidator.validate(_state().city(), _state().terrain(), data,
		hovered.cell(), _turns)
	_ghost.show_at(data, hovered.cell(), _turns, hovered.height(), result)

# --- Le rapport ------------------------------------------------------------------------

## Ce qui reste du rapport texte de `I1` après que `E2` puis `W2` en ont pris des morceaux.
##
## La réserve est partie sur la barre, la résolution sur le panneau de production, le
## plateau et le roster sur le panneau d'affectation. Ce qui demeure est ce qu'aucun des
## trois jalons d'écran n'a de vue pour : les piles et le survol, qui attendront `I2`.
##
## Chaque fois, le morceau est **retiré** plutôt que doublé. Garder les deux laisserait le
## même chiffre lisible à deux endroits, et un chiffre affiché deux fois est un chiffre
## qui finira par différer de lui-même — la capture n'en vérifie qu'une des deux mises en
## forme, et l'autre dérive en silence.
func _report() -> String:
	var lines := PackedStringArray()
	lines.append(_banner())
	var forecast := _forecast_line()
	if not forecast.is_empty():
		lines.append(forecast)
	lines.append("")
	if _report_level == Report.ESSENTIAL:
		lines.append(_last_action)
		return "\n".join(lines)
	lines.append(_last_action)
	lines.append("")
	lines.append(CONTROLS)
	return "\n".join(lines)

## Quand tombe la prochaine vague, et laquelle.
##
## **Ce n'est pas du confort**, à l'inverse des deux touches ci-dessus. `DESIGN.md` 3.6 pose
## que la direction d'une vague s'annonce à l'avance parce que 3.2 « veut qu'on pense à la
## bataille en posant un bâtiment », et qu'« une direction révélée le soir même
## transformerait cette prévoyance en loterie ». La **date** se tient par le même argument,
## et elle n'était visible nulle part : jusqu'ici une vague apparaissait le soir où elle
## tombait, donc la palissade se bâtissait après coup ou par superstition.
##
## Elle se lit à tous les crans du rapport, y compris le plus discret, pour cette raison
## exactement : c'est une information de décision, pas un compte rendu.
func _forecast_line() -> String:
	var cycle := _state().cycle()
	if cycle.is_over() or _state().awaits_a_battle():
		return ""
	var slot := _state().balance().run.next_slot_from(cycle.day())
	if slot == null:
		return "Plus aucune vague au calendrier."
	var wait := slot.day - cycle.day()
	if wait <= 0:
		return "%s ce soir." % slot.wave.label
	return "%s au jour %d — dans %d journée(s)." % [slot.wave.label, slot.day, wait]

## Le bandeau de phase. Le libellé et les gestes viennent de la `PhaseDef`, jamais d'un
## nom écrit ici : c'est ce qui fera de l'arbitrage de `I2b` un échange de `.tres`.
##
## La réserve en est sortie à `E2`. Elle y était parce qu'il n'y avait nulle part
## ailleurs où la mettre ; la garder en double aurait donné deux endroits où lire le même
## chiffre, donc un endroit où le lire faux le jour où l'un des deux dériverait.
func _banner() -> String:
	var cycle := _state().cycle()
	if _state().awaits_its_heart():
		return "Fondation   |   poser le Cœur : clic sur la carte, ou Entrée pour la case suggérée   |   seed %d" 			% _run_seed
	if cycle.is_over():
		return "Run terminé   |   %s" % _verdict()
	if _state().awaits_a_battle():
		return "Jour %d/%d   |   %s en approche   |   tenir la ligne" % [
			cycle.day(), cycle.days(), _state().pending_wave().label]
	return "Jour %d/%d   |   %s   |   %s" % [
		cycle.day(), cycle.days(), _phase_label(), _permissions()]

## Comment le run s'est terminé, en une demi-ligne.
##
## La cause est traduite ici et non portée par le domaine : un `RunOutcome` rend une
## constante, l'écran en fait une phrase — le même partage que `_staffing_refusal()` depuis
## `I1`.
##
## Court, et il l'est en deux fois. La première capture de `I2` mettait la phrase entière
## dans le bandeau, qui passait sous les panneaux de droite : la seule chose qu'il devait
## annoncer se lisait « Victoire — la dernière journée est passée au jour 15. Score 431 —
## 71 en ré ». La raccourcir une fois ne suffisait pas — la moitié gauche de l'écran est
## large de sept cents pixels, et un bandeau ne se replie pas. Ce qui tient est donc **un
## mot**, et la cause comme le détail sont des lignes du rapport, où le texte peut aller à
## la ligne.
func _verdict() -> String:
	var ending := _state().outcome()
	if ending == null:
		return "%d jour(s) joués, seed %d" % [_state().cycle().days(), _run_seed]
	return "%s   |   jour %d, score %d" % [_outcome_word(ending), ending.day(),
		ending.score()]

func _outcome_word(ending: RunOutcome) -> String:
	return "Victoire" if ending.is_victory() else "Défaite"

## Le détail d'une fin a quitté ce pavé à `P2a`, pour `RunEndScreen`.
##
## Il y était depuis `I2` — la cause en clair, puis le score et ses quatre termes —, à côté
## de l'aide au clavier, c'est-à-dire dans la seule zone de l'écran qu'on cesse de lire au
## bout de deux minutes. Une partie de quinze journées s'achevait donc sur une phrase qu'on
## pouvait manquer. L'écran de fin les **remplace** au lieu de les doubler, quatrième fois
## après `E2`, `W2` et `P1b` : un chiffre affiché à deux endroits est un chiffre qui finira
## par différer de lui-même. Ce que le bandeau garde est un mot et un total, ce qu'un
## bandeau sait porter.


## Ce que la phase courante autorise, en clair. L'écran ne suppose rien : il pose les
## deux questions au domaine et affiche les réponses.
func _permissions() -> String:
	var allowed := PackedStringArray()
	if _state().cycle().permits(PhaseDef.ACTION_PLAY):
		allowed.append("poser")
	if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		allowed.append("affecter")
	if _state().cycle().resolves():
		allowed.append("résout en partant")
	return "—" if allowed.is_empty() else ", ".join(allowed)

## Ce que le curseur désigne, et ce que la carte tenue y ferait — sur **deux** lignes.
##
## Une seule jusqu'à ce qu'elle sorte du rapport pour aller en haut au centre, où la
## première capture l'a montrée passant **sous la barre de ressources** : centrée, elle
## grandit des deux côtés, et la version longue — cellule, hauteur, terrain, bâtiment, plus
## le coût d'une carte tenue et son refus — fait deux fois la place disponible entre la
## barre et le bord. « Survol : » se dessinait par-dessus « Minerai 0 ».
##
## Deux lignes courtes tiennent là où une longue ne tient pas, et elles se lisent mieux :
## **ce qu'il y a**, puis **ce que ça ferait**. La seconde n'existe que si l'on tient
## quelque chose, donc la bande ne prend deux lignes que lorsqu'elle a deux choses à dire.
##
## Le préfixe « Survol : » est parti avec le déménagement : une bande qui ne dit que ça n'a
## pas à s'annoncer.
func _hover_line() -> String:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return "—"
	var cell := hovered.cell()
	var line := "(%d, %d)   h = %d   %s" % [cell.x, cell.y, hovered.height(),
		_state().terrain().terrain_at(cell).id]
	if _state().awaits_its_heart():
		var verdict := _founding_placement(cell)
		return "%s\n%s, %s%s" % [line, _founding_label(), _orientation(),
			"" if verdict.is_ok() else "   <- %s" % verdict.reason()]
	var building := _state().city().building_at(cell)
	if building != null:
		line += "   |   %s : %s" % [building.data().id, _site_state(building)]
	var held := _held_card()
	if held.is_empty():
		return line
	return "%s\n%s" % [line, _held_card_line(held, cell)]

## Ce que la carte tenue ferait sur cette cellule : son coût si elle bâtit, son verdict de
## ciblage sinon.
func _held_card_line(held: StringName, cell: Vector2i) -> String:
	var data := _building_of(held)
	if data != null:
		return "%s, %s, coût %s%s" % [_label_of(held), _orientation(),
			_cost_text(data.cost),
			"" if _state().ledger().can_afford(data.cost) else "   <- réserve insuffisante"]
	var verdict := _validate(held, cell)
	return "%s : %s" % [_label_of(held),
		"accepté, %d poste(s)" % verdict.capacity() if verdict.is_ok()
			else String(verdict.reason())]

# --- Les petites lectures ---------------------------------------------------------------

func _state() -> RunState:
	return RunManager.state()

func _validate(card: StringName, cell: Vector2i) -> TargetResult:
	return ActionTargeting.validate(card, cell, _state().terrain(),
		_state().city().to_snapshot(), _state().board().to_plan(),
		_state().balance().actions, _direction)

## La carte tenue, ou &"" si l'on ne tient rien. Relue depuis la main à chaque appel : une
## main qui rétrécit invalide le rang, et le rendre vide d'office évite de le remettre à
## zéro partout où la main bouge.
func _held_card() -> StringName:
	var cards := _state().deck().hand().cards()
	if _held_slot < 0 or _held_slot >= cards.size():
		return &""
	return cards[_held_slot]

## Dernière action posée sur la cellule survolée, ou null.
func _action_here() -> PlayedAction:
	var hovered := _world.cursor().hovered()
	if not hovered.is_hit():
		return null
	var here := _state().board().at_cell(hovered.cell())
	if here.is_empty():
		return null
	return here[here.size() - 1]

func _phase_label() -> String:
	var phase := RunManager.phase()
	return "—" if phase == null else phase.label

func _sense() -> String:
	return _sense_of(_direction)

func _sense_of(direction: int) -> String:
	return "monter" if direction == PlayedAction.DIRECTION_UP else "descendre"

func _orientation() -> String:
	return "%d/4" % posmod(_turns, BuildingData.QUARTER_TURNS)

func _site_state(building: PlacedBuilding) -> String:
	if building.is_complete():
		return "achevé"
	return "chantier %d/%d" % [building.progress(), building.data().build_actions]

func _label_of(card: StringName) -> String:
	var catalogue := _state().catalogue()
	if not catalogue.has(card):
		return String(card)
	return catalogue.card(card).label

func _name_of(worker: StringName) -> String:
	if not _state().roster().has(worker):
		return String(worker)
	return _state().roster().worker(worker).given_name()

## Le bâtiment d'ouverture, ou null si `data/balance/` n'en nomme aucun.
##
## Il est lu sur l'équilibrage et jamais écrit ici : `&"heart"` dans un `.gd` serait
## l'identifiant de contenu que les conventions refusent partout ailleurs.
func _founding_data() -> BuildingData:
	return _state().building(_state().balance().run.starting_building)

## Le nom du bâtiment d'ouverture, tel que `data/` le porte.
func _founding_label() -> String:
	var data := _founding_data()
	return "—" if data == null else String(data.id)

## Ce que le validateur dit de la case survolée pendant la fondation.
##
## La même question que le fantôme pose, posée au même endroit : c'est
## `PlacementValidator` qui répond, et l'écran ne fait que traduire. Un survol qui
## afficherait « accepté » là où le fantôme est rouge serait deux règles de placement.
func _founding_placement(cell: Vector2i) -> PlacementResult:
	return PlacementValidator.validate(_state().city(), _state().terrain(),
		_founding_data(), cell, _turns)

## Le bâtiment que cette carte pose, ou null si ce n'en est pas une.
func _building_of(card: StringName) -> BuildingData:
	if card.is_empty() or not _state().catalogue().has(card):
		return null
	var data := _state().catalogue().card(card)
	if not data.places_a_building():
		return null
	return _state().building(data.building)

## Un coût en clair. La palette met un lot en forme et rend « — » pour un lot vide ; un
## coût vide, lui, se dit « gratuit ». C'est la phrase du harnais et non celle de la
## palette : la même absence ne se raconte pas pareil selon qu'on paie ou qu'on reçoit.
func _cost_text(cost: Dictionary[StringName, int]) -> String:
	if cost.is_empty():
		return "gratuit"
	return _palette.bundle_text(cost)

# --- La mise en place ---------------------------------------------------------------------

func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	for id in GameDatabase.list_building_ids():
		table[id] = GameDatabase.get_building(id)
	return table

## Colle une vue de HUD dans un coin de l'écran, à la marge du rapport.
##
## Une bande plein écran à marges, dont l'enfant se rétracte vers le coin voulu — et non
## des ancres et des décalages calculés à la main. `E2` a essayé de les calculer, et la
## capture a montré les deux pièges l'un après l'autre.
##
## Le premier est que `set_anchors_preset()` prend un **booléen** en second argument, là
## où `set_anchors_and_offsets_preset()` prend un mode de redimensionnement : lui passer
## `PRESET_MODE_MINSIZE` revient à lui dire « garde tes décalages », donc à laisser la vue
## à zéro. Un `PanelContainer` de taille nulle ne dessine pas son fond, et ses libellés
## débordent par-dessus la carte.
##
## Le second survit à la correction du premier : une taille minimale lue juste après avoir
## ajouté des enfants est encore celle d'avant, Godot la recalculant à la passe suivante.
## Le panneau se plaçait donc toujours sur la taille du rapport **précédent**.
##
## Un conteneur ne se trompe sur aucun des deux, et il ne se trompe pas non plus à la
## dixième résolution : c'est lui qui refait la mise en page quand le contenu change.
## `bottom` s'écarte de la marge commune pour une seule raison, et c'est la main : elle
## est ancrée au bas de l'écran, donc une vue qui se rétracte vers le bas lui monterait
## dessus. Une marge plus grande est la façon de le dire dans le vocabulaire du
## conteneur ; une hauteur recopiée serait exactement ce que `E2` a payé pour ne plus
## écrire.
func _hud_slot(view: Control, horizontal: int, vertical: int,
		bottom := REPORT_MARGIN) -> MarginContainer:
	var slot := MarginContainer.new()
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right"]:
		slot.add_theme_constant_override("margin_%s" % side, int(REPORT_MARGIN))
	slot.add_theme_constant_override("margin_bottom", int(bottom))
	view.size_flags_horizontal = horizontal
	view.size_flags_vertical = vertical
	slot.add_child(view)
	return slot

## La barre, puis le rapport texte dessous.
##
## Empilés dans un `VBoxContainer` plutôt que posés à des hauteurs écrites à la main : le
## texte démarre sous la barre parce qu'il la suit, et non parce qu'un chiffre recopié se
## trouve valoir la bonne hauteur. Régler la barre ne peut donc pas faire repasser le
## texte dessous.
##
## La barre se rétracte à sa largeur ; sans ça, la colonne l'étirerait sur la largeur du
## bloc de texte, qui est bien plus large. Le panneau de bataille fait de même.
##
## Il s'intercale entre les deux, et il est masqué tant qu'aucune vague n'est en jeu — voir
## `_make_right_column()`, qui dit pourquoi il n'y est pas. Entre la barre et le texte
## plutôt qu'en dessous : ce qu'une vague pille est ce que la barre au-dessus affiche, et
## tant qu'elle est en approche c'est la seule chose de l'écran qui demande une décision.
func _make_left_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(REPORT_MARGIN))
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)
	_hover.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_hover)
	_battle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_battle)
	column.add_child(_label)
	return column

## Le compte rendu de phase, puis le panneau d'affectation dessous.
##
## Empilés pour la raison que la première capture de `W2` a montrée : posés séparément,
## l'un en haut à droite et l'autre en bas à droite, ils se **recouvrent** dès que le
## plateau porte cinq actions — le panneau grandit vers le haut et vient manger les lignes
## « Chantiers » et « Upkeep » du rapport. Ce n'est pas une marge à régler : c'est deux
## vues qui grandissent l'une vers l'autre, donc un chevauchement qui n'attend qu'une
## phase chargée. Une colonne les fait se pousser au lieu de se croiser.
##
## Le prix est que le compte rendu descend du haut de l'écran, où `E2` l'avait mis. Il n'y
## était pas par principe mais parce que rien d'autre n'occupait ce coin, et il reste au
## même endroit d'une résolution à l'autre — ce qui est la seule chose qu'on lui demande.
##
## Les deux se rétractent à leur largeur ; sans ça, la colonne étirerait le plus étroit
## sur la largeur du plus large.
##
## **Le panneau de bataille n'est pas ici, et la capture de `I2` explique pourquoi.** Il y a
## d'abord été mis, en tête — un assaut en approche se lit avant un compte rendu de récolte
## —, et le jour de la dernière vague la colonne débordait par le bas : trois panneaux
## empilés plus la marge que la main réclame ne tiennent pas dans huit cents pixels, et la
## dernière fiche d'ouvrier sortait de l'écran. C'est le défaut qu'`W2` avait déjà payé, un
## cran plus loin — la colonne ne se recouvre pas, elle **déborde**, et augmenter une marge
## basse aggraverait la chose au lieu de la corriger.
##
## Il vit donc dans la colonne de gauche, où la place est. Ce n'est pas un pis-aller : `W2`
## notait déjà du compte rendu de phase qu'« il n'y était pas par principe mais parce que
## rien d'autre n'occupait ce coin ». Et la lecture y gagne — la vague est voisine de la
## réserve qu'elle va piller.
func _make_right_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(REPORT_MARGIN))
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_panel)
	_crew.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_crew)
	return column

## La bande de survol. Même fonte et même contour que le rapport, pour qu'on la lise comme
## la même voix ; un fond discret parce qu'elle passe sur la carte et non sur le ciel.
func _make_hover() -> Label:
	var label := _make_label()
	label.name = "RunHover"
	var style := StyleBoxFlat.new()
	style.bg_color = HOVER_BACKGROUND
	style.set_corner_radius_all(HOVER_RADIUS)
	style.set_content_margin_all(HOVER_PADDING)
	label.add_theme_stylebox_override("normal", style)
	return label

## Le rapport texte. Il n'a plus ni ancre ni décalage depuis `E2` : il est empilé sous la
## barre de ressources par la colonne de gauche, qui les place l'un après l'autre.
func _make_label() -> Label:
	var label := Label.new()
	label.name = "RunReport"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_constant_override("outline_size", REPORT_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

# --- La chronique ---------------------------------------------------------------------------

## Rejoue le run entier sous chacune des quatre variantes de `I2b`, et imprime ce que ça
## donne. Rien n'est dessiné : c'est une mesure, pas une image.
##
## **Ce qu'elle sert, et ce qu'elle refuse de servir.** `DESIGN.md` 8 confie à `I2b`
## l'arbitrage de deux `.tres` — la structure de la journée en 2, le sort de la main non
## jouée en 3.5 — et ces deux questions se tranchent en jouant, pas en comptant. « Deux
## phases identiques deviennent-elles une corvée ? » n'a aucune colonne dans ce rapport et
## n'en aura jamais.
##
## Ce qu'une partie jouée ne dit pas et qu'une table dit tout de suite, en revanche : **si
## la comparaison est honnête**. L'upkeep suit la journée et la production suit la phase
## qui résout — c'est la séparation que 2. a voulue pour que changer la forme d'une journée
## ne force pas à rééquilibrer la nourriture. Elle a un revers que personne n'avait chiffré :
## un modèle qui résout moitié moins produit moitié moins **à coût constant**. Sans le
## nombre, on prendrait cet écart pour un ressenti et l'on arbitrerait la faim en croyant
## arbitrer le rythme.
##
## **Chaque table annonce ce qu'elle doit montrer**, en toutes lettres, et le verdict de fin
## dit ce qui la démentirait. C'est la discipline que `F1` a écrite après s'être fait avoir
## par une ligne parfaitement alignée et fausse sur son propre sujet : une table dont on ne
## sait pas dire ce qu'elle prouverait ne prouve rien.
##
## Elle emprunte les **gestes du harnais** — `_scripted_found()`, `_scripted_plays()`,
## `_scripted_staffing()`, `_end_phase()`, `_fight()` — et non `RunManager` en direct.
## C'est la règle que `P1a` a payée : un scripteur qui court-circuite le geste finit par
## mesurer autre chose que ce que le joueur fait. Les quatre runs se jouent donc exactement
## comme la capture joue le sien, à la carte près.
func _chronicle_if_asked() -> void:
	if not DevShot.has_flag(DevShot.CHRONICLE_FLAG):
		return
	print("[chronique] seed %d — quatre variantes, le même relief, les mêmes gestes." % SEED)
	var tallies: Array[Dictionary] = []
	for variant in _chronicle_variants():
		tallies.append(_chronicle_one(variant))
	_print_chronicle_tables(tallies)
	get_tree().quit()

## Les quatre croisements que `I2b` doit départager.
##
## Les deux blocs de rechange sont nommés par leur identifiant d'index et non par leur
## chemin : `GameDatabase` les a déjà chargés, et un fichier déplacé se signale ici par un
## null plutôt que par un `load()` silencieux.
func _chronicle_variants() -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	for day in [SPARE_NONE, SPARE_TWO_PHASES]:
		for hand in [SPARE_NONE, SPARE_PERSISTENT_DECK]:
			variants.append({
				&"label": "%s · %s" % [
					"2 phases" if day == SPARE_TWO_PHASES else "3 phases",
					"main reportée" if hand == SPARE_PERSISTENT_DECK else "main défaussée"],
				&"run": day,
				&"deck": hand,
			})
	return variants

## Joue un run entier sous cette variante et rend ce qu'il a coûté et rapporté.
##
## Le relief est **régénéré** à chaque variante plutôt que réutilisé : un terrassement le
## creuse, et comparer quatre runs sur quatre cartes différentes ne comparerait rien.
func _chronicle_one(variant: Dictionary) -> Dictionary:
	var balance := _chronicle_balance(variant)
	var grid := TerrainGen.generate(SEED, balance.terrain_gen.map_size, balance.terrain_gen)
	# `RunManager` ne tient qu'un run et refuse d'en ouvrir un second — ce qui est juste, et
	# ce qui oblige la chronique à refermer avant de repartir. Le premier tour referme celui
	# que `_ready()` vient d'ouvrir : la variante 0 se joue sur le même équilibrage, mais
	# repartir d'un run neuf est ce qui garantit que les quatre lignes se comparent.
	if RunManager.is_running():
		RunManager.close()
	RunManager.open(RunState.open(SEED, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance))
	_renderer.rebuild(_state().city())
	var tally := _blank_tally(variant, balance)
	_scripted_found()
	print("")
	print("[chronique] %s" % variant[&"label"])
	print("[chronique]   jour  résol.  jouées  servies  perdues  récolte      "
		+ "upkeep   stock  vague")
	while not _state().cycle().is_over():
		var closing := _chronicle_phase(tally)
		if closing != null:
			_print_chronicle_day(tally, closing)
	_close_tally(tally)
	return tally

## Joue une phase de bout en bout et note ce qu'elle a fait passer.
##
## Les deux comptes de cartes se prennent **de part et d'autre** des deux gestes, et pas
## autrement : « jouées » est ce que la main perd en posant, « servies » est ce qu'elle
## gagne à la frontière de phase, une fois retiré ce que le report lui a laissé. Sans le
## retrait, une main qui reporte tout paraîtrait ne rien recevoir, alors qu'elle reçoit
## exactement ce qu'elle a dépensé — ce qui est tout le sujet.
func _chronicle_phase(tally: Dictionary) -> PhaseReport:
	var cycle := _state().cycle()
	var closes := cycle.closes_the_day()
	var held := _state().deck().hand().size()
	if cycle.permits(PhaseDef.ACTION_PLAY):
		_scripted_plays()
	if cycle.permits(PhaseDef.ACTION_ASSIGN):
		_scripted_staffing()
	var kept := _hand_by_pool()
	tally[&"played"] += held - _state().deck().hand().size()
	if cycle.resolves():
		tally[&"resolutions"] += 1
	var resolves := cycle.resolves()
	var report := _end_phase()
	# La bataille est le **dernier cran** de la fermeture d'une journée, et c'est elle qui
	# ouvre la phase suivante quand une vague attend — donc elle qui sert la main. Compter
	# les cartes avant elle datait la pioche du lendemain : le modèle à deux phases
	# annonçait sept cartes servies le jour d'une vague et quatorze les autres, ce qui
	# n'était pas une différence de jeu mais un défaut de mesure. Elle est aussi ici pour
	# que le pillage entre dans le stock de ce soir plutôt que dans celui de demain.
	if _state().awaits_a_battle():
		_chronicle_battle(tally)
	if resolves:
		_chronicle_cards(tally, kept)
	if report != null:
		_chronicle_report(tally, report)
	return report if closes else null

## Ce que la frontière de phase a fait des cartes : combien sont parties sans avoir été
## jouées, combien la pioche a servi pour les remplacer.
##
## **Appelée aux seules frontières qui résolvent**, et le premier jet ne l'était pas : une
## phase qui ne résout pas laisse la main intacte, si bien que la formule ci-dessous y
## comptait une défausse entière **et** une pioche entière, dont aucune n'avait eu lieu.
## Vingt et une cartes servies par journée pour une main de sept sur deux résolutions — un
## chiffre parfaitement aligné, et faux d'une moitié. C'est exactement ce dont `F1` dit de
## se méfier, trouvé cette fois en relisant la table plutôt qu'en la croyant.
##
## Le report est lu sur `carry_over`, donc sur la même table que le domaine applique. Un
## report partiel — que `DeckBalance` refuse — compterait ici comme « tout gardé », ce qui
## est la dégradation qu'`RunOrchestrator` fait déjà de son côté : les deux se trompent
## ensemble ou pas du tout.
func _chronicle_cards(tally: Dictionary, kept: Dictionary) -> void:
	var carry := _state().balance().deck.carry_over
	var hand := _state().deck().hand()
	for pool in CardData.POOLS:
		var before: int = kept[pool]
		var survivors := before if int(carry.get(pool, 0)) > 0 else 0
		tally[&"dropped"] += before - survivors
		tally[&"dealt"] += maxi(hand.count_in(pool) - survivors, 0)

## Ce qu'une phase résolue a rapporté, et ce qu'une journée fermée a coûté.
func _chronicle_report(tally: Dictionary, report: PhaseReport) -> void:
	var food: StringName = _state().balance().economy.upkeep_resource
	var produced := report.production().produced()
	for id in produced:
		tally[&"harvest"] += int(produced[id])
	tally[&"grown"] += int(produced.get(food, 0))
	if not report.closes_the_day():
		return
	var upkeep := report.day_report().upkeep()
	tally[&"upkeeps"] += 1
	tally[&"due"] += upkeep.due()
	tally[&"eaten"] += upkeep.consumed()
	tally[&"unfed"] += upkeep.unfed()
	if upkeep.is_famine() and tally[&"famine"] == 0:
		tally[&"famine"] = report.day_report().day()

## Tient la ligne, et note ce qu'elle a coûté en hommes.
##
## Le compte se prend sur le roster de part et d'autre plutôt que dans le rapport : c'est
## la seule lecture qui reste juste le jour où quelqu'un d'autre que la vague fera tomber
## un ouvrier.
func _chronicle_battle(tally: Dictionary) -> void:
	var standing := _state().roster().size()
	var wave := _state().pending_wave().label
	var report := _fight()
	tally[&"fallen"] += standing - _state().roster().size()
	tally[&"plundered"] += report.total_plundered() if report != null else 0
	tally[&"wave"] = wave

## Une ligne par journée fermée. Ce qui y bouge d'une variante à l'autre est ce que la
## variante change ; le reste est le même run.
func _print_chronicle_day(tally: Dictionary, report: PhaseReport) -> void:
	var closing: DayReport = report.day_report() if report != null else null
	var upkeep := closing.upkeep() if closing != null else null
	print("[chronique]  %4d  %6d  %6d  %7d  %7d  %5d (%d nour.)  %d/%d  %5d  %s" % [
		closing.day() if closing != null else 0,
		tally[&"resolutions"] - tally[&"printed_resolutions"],
		tally[&"played"] - tally[&"printed_played"],
		tally[&"dealt"] - tally[&"printed_dealt"],
		tally[&"dropped"] - tally[&"printed_dropped"],
		tally[&"harvest"] - tally[&"printed_harvest"],
		tally[&"grown"] - tally[&"printed_grown"],
		upkeep.consumed() if upkeep != null else 0,
		upkeep.due() if upkeep != null else 0,
		_state().ledger().total(),
		tally[&"wave"],
	])
	tally[&"wave"] = ""
	for field in [&"resolutions", &"played", &"dealt", &"dropped", &"harvest", &"grown"]:
		tally[StringName("printed_%s" % field)] = tally[field]

## La main, pool par pool, à l'instant. Sert de repère avant une frontière de phase.
func _hand_by_pool() -> Dictionary:
	var counts: Dictionary[StringName, int] = {}
	var hand := _state().deck().hand()
	for pool in CardData.POOLS:
		counts[pool] = hand.count_in(pool)
	return counts

## Un équilibrage où l'on a remplacé les blocs que la variante nomme.
##
## Les blocs sont **remplacés** et jamais mutés : `duplicate()` est superficiel, donc
## toucher au contenu d'un sous-bloc toucherait celui que `GameDatabase` sert à tout le
## monde, et la variante suivante partirait d'un équilibrage déjà déformé.
func _chronicle_balance(variant: Dictionary) -> BalanceData:
	var balance := GameDatabase.get_balance().duplicate() as BalanceData
	var run: StringName = variant[&"run"]
	if run != SPARE_NONE:
		balance.run = GameDatabase.get_resource(GameDatabase.CATEGORY_BALANCE, run) as RunBalance
	var deck: StringName = variant[&"deck"]
	if deck != SPARE_NONE:
		balance.deck = GameDatabase.get_resource(GameDatabase.CATEGORY_BALANCE, deck) as DeckBalance
	assert(balance.missing_fields().is_empty(),
		"variante de chronique inexploitable : %s" % ", ".join(balance.missing_fields()))
	return balance

func _blank_tally(variant: Dictionary, balance: BalanceData) -> Dictionary:
	var tally: Dictionary = {
		&"label": variant[&"label"],
		&"phases": balance.run.phases.size(),
		&"resolving": balance.run.resolving_phases().size(),
		&"wave": "",
	}
	for field in [&"upkeeps", &"resolutions", &"played", &"dealt", &"dropped", &"harvest",
			&"grown", &"due", &"eaten", &"unfed", &"famine", &"fallen", &"plundered",
			&"printed_resolutions", &"printed_played", &"printed_dealt",
			&"printed_dropped", &"printed_harvest", &"printed_grown"]:
		tally[field] = 0
	return tally

func _close_tally(tally: Dictionary) -> void:
	var ending := _state().outcome()
	tally[&"outcome"] = _outcome_word(ending) if ending != null else "inachevé"
	tally[&"last_day"] = ending.day() if ending != null else 0
	tally[&"score"] = ending.score() if ending != null else 0
	tally[&"stock"] = _state().ledger().total()
	tally[&"buildings"] = _state().city().to_snapshot().completed().size()
	tally[&"workers"] = _state().roster().size()

# --- Les quatre tables ----------------------------------------------------------------------

func _print_chronicle_tables(tallies: Array[Dictionary]) -> void:
	print("")
	print("=".repeat(92))
	_print_day_table(tallies)
	_print_food_table(tallies)
	_print_card_table(tallies)
	_print_run_table(tallies)
	_print_chronicle_verdict()

## Ce que la forme de la journée fait, et ce qu'elle ne fait pas.
func _print_day_table(tallies: Array[Dictionary]) -> void:
	print("")
	print("A — LA JOURNÉE")
	print("   Doit montrer : un upkeep par journée, quel que soit le nombre de phases,")
	print("   et autant de résolutions que la data en déclare. Si ces deux colonnes")
	print("   cessent de se suivre, changer la forme d'une journée a changé ce qu'elle coûte.")
	print("   %-28s %7s %7s %7s %9s %11s" % ["variante", "phases", "résol.",
		"jours", "upkeeps", "résol./jour"])
	for tally in tallies:
		# Les deux colonnes viennent de **deux compteurs** : « jours » du cycle, par
		# l'issue du run, « upkeeps » du nombre de `DayReport` reçus. Elles disaient toutes
		# deux le second dans le premier jet, donc leur égalité ne prouvait rien — une
		# colonne qui recopie sa voisine est le défaut que `F1` a nommé.
		print("   %-28s %7d %7d %7d %9d %11.2f" % [tally[&"label"], tally[&"phases"],
			tally[&"resolutions"], tally[&"last_day"], tally[&"upkeeps"],
			float(tally[&"resolutions"]) / maxf(float(tally[&"last_day"]), 1.0)])

## Le chiffre qui dit si la comparaison est honnête.
func _print_food_table(tallies: Array[Dictionary]) -> void:
	print("")
	print("B — LA NOURRITURE")
	print("   Doit montrer : si les quatre variantes se comparent entre elles, et à quel prix.")
	print("   L'upkeep suit la journée, la récolte suit la phase qui résout : une variante qui")
	print("   résoudrait moins produirait moins À COÛT CONSTANT, et sa « 1re famine » avancerait")
	print("   sans que le modèle y soit pour rien. Les quatre résolvent deux fois par jour —")
	print("   voir A —, donc ce qui les sépare ici ne vient que du report de main. La phase")
	print("   du soir ne coûte rien, et c'est cette table qui le montre.")
	print("   %-28s %8s %7s %7s %8s %11s" % ["variante", "récoltée", "due",
		"mangée", "affamés", "1re famine"])
	for tally in tallies:
		print("   %-28s %8d %7d %7d %8d %11s" % [tally[&"label"], tally[&"grown"],
			tally[&"due"], tally[&"eaten"], tally[&"unfed"],
			"—" if tally[&"famine"] == 0 else "jour %d" % tally[&"famine"]])

## Ce que le report fait, et ce qu'il coûte.
func _print_card_table(tallies: Array[Dictionary]) -> void:
	print("")
	print("C — LES CARTES")
	print("   Doit montrer : ce que le report de main change, et son prix. « Perdues » est")
	print("   la question de DESIGN.md 3.5 — les cartes parties sans avoir été jouées — et")
	print("   elle doit tomber à zéro dès qu'un pool reporte. « Servies » doit baisser")
	print("   d'autant : une carte gardée est une carte non piochée, sinon le report est")
	print("   gratuit et la main cesse d'être une contrainte.")
	print("   %-28s %8s %8s %8s %11s" % ["variante", "servies", "jouées",
		"perdues", "jouées/jour"])
	for tally in tallies:
		print("   %-28s %8d %8d %8d %11.2f" % [tally[&"label"], tally[&"dealt"],
			tally[&"played"], tally[&"dropped"],
			float(tally[&"played"]) / maxf(float(tally[&"last_day"]), 1.0)])

## Ce que la variante vaut au bout.
func _print_run_table(tallies: Array[Dictionary]) -> void:
	print("")
	print("D — LE RUN")
	print("   Doit montrer : que chaque variante se joue jusqu'au bout, et ce qu'elle vaut.")
	print("   Un « inachevé » dans la première colonne est un défaut de la chronique et non")
	print("   du modèle : c'est un run qui n'a ni gagné, ni perdu, ni épuisé ses journées.")
	print("   %-28s %10s %6s %7s %7s %7s %7s %7s" % ["variante", "issue", "jour",
		"score", "réserve", "bât.", "ouvr.", "pillé"])
	for tally in tallies:
		print("   %-28s %10s %6d %7d %7d %7d %7d %7d" % [tally[&"label"],
			tally[&"outcome"], tally[&"last_day"], tally[&"score"], tally[&"stock"],
			tally[&"buildings"], tally[&"workers"], tally[&"plundered"]])

## Ce que la chronique **ne** dit pas, et il faut que ce soit écrit sous les tables plutôt
## que dans un commentaire : c'est là qu'on le lit.
func _print_chronicle_verdict() -> void:
	print("")
	print("VERDICT")
	print("   Ces quatre tables ne tranchent aucune des deux questions de I2b. Elles disent")
	print("   ce qu'une variante fait aux chiffres ; ce que I2b demande est ce qu'elle fait")
	print("   à la partie — si une phase de plus se joue ou s'endure, si une main qu'on garde")
	print("   rend le tour plus riche ou plus mou. Aucune colonne ne répond à ça.")
	print("   Ce qu'elles servent : savoir, avant d'y passer quinze journées, laquelle des")
	print("   quatre part avec un handicap d'équilibrage plutôt qu'une différence de rythme.")
	print("   Le scripteur joue une carte de chaque nature sur la première cible venue et")
	print("   remplit au bouton Auto : il ne joue pas bien, il joue **pareil** quatre fois.")
	print("=".repeat(92))

# --- La capture --------------------------------------------------------------------------

## Capture d'écran pilotée par la ligne de commande, puis sortie :
##
##     godot --path . -- --shot chemin.png [--shot-hover x,y] [--shot-evenings n]
##
## `src/adapters/` n'est pas testé et les trois commandes de vérification ne regardent pas
## l'écran : cette capture est le contrôle principal du jalon. Elle joue donc une journée
## entière plutôt qu'un geste — un chantier ouvert, payé, avancé, et un terrassement
## exécuté —, sans quoi elle ne montrerait rien de ce que `I1` ajoute.
##
## **Elle joue le run entier et non plus une journée**, ce qui est le sujet de `I2` : un
## `--shot-evenings 16` fonde, traverse quinze journées, encaisse les trois vagues du
## calendrier et s'arrête sur le bandeau de fin. Une vague reste **en approche** quand elle
## tombe sur la dernière journée demandée, de sorte que les deux moitiés de la coupure de
## `DESIGN.md` 3.8 soient chacune atteignables en une commande. Et `--shot-evenings 0`
## capture la fondation, voir `SHOT_FOUNDING`.
##
## Elle n'imprime plus le compte rendu de la dernière phase : il est devenu un panneau, et
## un panneau se regarde. Le réécrire en texte à côté aurait donné deux mises en forme du
## même rapport, dont une seule serait vérifiée par la capture — donc l'autre dériverait.
## Ce qui reste imprimé est ce qu'aucune image ne rend lisible d'un coup d'œil : la réserve
## chiffrée, qui dit si la bourse a bien été débitée.
##
## **`W2` lui retire la table des actions posées**, pour la même raison et à contrecœur :
## c'est elle qui avait attrapé le seul vrai bug de `D2`. Elle est désormais dessinée par
## le panneau d'affectation, avec les ouvriers qui la tiennent, et la garder en texte
## aurait laissé la version imprimée dire vrai pendant qu'une mise en page fautive cachait
## l'autre — c'est exactement le piège que `E2` a rencontré deux fois de suite.
##
## Ce que la journée scriptée traverse a changé en revanche : elle remplit les postes par
## le **bouton**, donc par `StaffingAdvisor`. Le chemin neuf du jalon est emprunté par le
## seul contrôle qui regarde l'écran.
##
## Et elle s'arrête désormais **au milieu** d'une phase, sur une dernière manche posée et
## affectée qu'on ne finit pas. Une capture prise juste après une résolution montrait un
## plateau vide et six fiches oisives, c'est-à-dire tout `W2` sauf ce qu'il fait : la
## seule image qui prouve quelque chose est celle où des ouvriers tiennent des postes.
func _capture_if_asked() -> void:
	var path := DevShot.path()
	if path.is_empty():
		return
	_world.cursor().input_enabled = false
	_world.cursor().hover_cell(DevShot.hover_cell(_state().grid().size() / 2))
	var asked := DevShot.argument(DevShot.SHOT_EVENINGS_FLAG)
	if asked != SHOT_FOUNDING:
		_scripted_found()
		var days := maxi(asked.to_int(), 1)
		for index in days:
			_scripted_day()
			if _state().awaits_a_battle() and index < days - 1:
				_fight()
		_scripted_skip_phases(DevShot.argument(DevShot.SHOT_PHASES_FLAG).to_int())
		if not _state().awaits_a_battle() and not _state().cycle().is_over():
			_scripted_open_phase()
	# Après la suite de journées et avant tout le reste : relancer refait le run entier —
	# relief compris —, donc appliquer un cran de HUD ou poser le soleil avant lui les
	# poserait sur une partie qu'on jette. C'est aussi le seul passage automatique qui
	# emprunte `_restart()`.
	if DevShot.has_flag(DevShot.SHOT_RESTART_FLAG):
		_restart()
	_apply_shot_view()
	# Le soleil se pose **d'un coup** pour une capture. Trois images de chauffe ne couvrent
	# pas un glissement de neuf dixièmes de seconde : sans ça, toute capture montrerait un
	# soleil à mi-course entre le moment précédent et le bon, ce qui est exactement le genre
	# d'image à laquelle `F1` dit de ne pas faire confiance — vraisemblable, et fausse.
	var cycle := _state().cycle()
	_world.settle_light(DevWorld.NIGHT if cycle.is_over() or _state().awaits_a_battle() \
		else _day_progress(cycle))
	if DevShot.has_flag(DevShot.SHOT_PILES_FLAG):
		_show_piles()
	for _frame in DevShot.WARMUP_FRAMES:
		await get_tree().process_frame
	print("[run_harness] %s" % _banner())
	print("[run_harness] %s" % _armies_line())
	print("[run_harness] réserve %s — %d/%d" % [
		_palette.bundle_text(_state().ledger().amounts()),
		_state().ledger().total(), _state().ledger().capacity()])
	print("[run_harness] %s" % _hover_line())
	print("[run_harness] %s" % _fit_line())
	print("[run_harness] %s" % _step_fit_line())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[run_harness] capture vers %s : %s" % [path, error_string(error)])
	get_tree().quit(OK if error == OK else FAILED)

## Ce que la colonne de droite fait de la place qu'elle a, en pixels de mise en page.
##
## Elle existe parce que le défaut que `P1b` répare a mis **trois jalons** à se faire
## voir : le panneau d'affectation descendait sur la main, et personne ne pouvait le dire
## autrement qu'à l'œil ou en sondant une capture pixel par pixel — ce qui est long, et
## ce qui donne un chiffre en pixels de **fenêtre** alors que la mise en page raisonne en
## pixels **logiques**, le projet étant en `stretch/mode = canvas_items`. Les deux ne se
## comparent pas, et les confondre est la façon la plus sûre de mesurer le mauvais
## chiffre.
##
## C'est la discipline que `F1` a écrite pour les tables du harnais, appliquée à une
## image : **elle annonce ce qu'elle doit montrer**. Un recouvrement positif est un
## défaut, et il se lit sur la sortie standard de n'importe quelle capture au lieu de se
## redécouvrir.
##
## Les deux bords sont **demandés aux vues** et jamais recalculés : `_crew` dit où il finit,
## `_hand_view` dit où elle commence, et les deux répondent en `global_position`, donc dans
## le même repère. Déduire le haut de la bande d'une soustraction sur le viewport aurait
## marché ici et cassé le jour où la main change d'ancrage.
##
## Elle mesure contre la **bande** que la main réserve, et non contre le haut visible d'une
## carte, qui est plus bas. C'est volontaire et c'est plus sévère : la bande comprend
## `HOVER_LIFT`, la course qu'une carte survolée a au-dessus d'elle, donc un panneau qui
## s'arrête pile au bord ne recouvrira pas non plus la carte qu'on désigne. « 0 px de
## dégagement » est l'état visé et non un frôlement.
func _fit_line() -> String:
	var band := _hand_view.global_position.y
	var bottom := _crew.global_position.y + _crew.size.y
	var verdict := "recouvrement %d px" % (bottom - band) if bottom > band \
		else "%d px de dégagement" % (band - bottom)
	return "colonne droite : bas du panneau y=%d, haut de la main y=%d, %s" % [
		bottom, band, verdict]

## La même mesure, couchée : le bouton de pas vit **dans** la bande de la main, à droite,
## et la main est centrée — donc elle grandit vers lui à chaque carte de plus.
##
## Elle existe pour la raison que `P1b` a payée d'une heure passée à sonder des PNG : un
## recouvrement se mesure en pixels de **mise en page**, que seules les vues connaissent,
## et pas en pixels d'image, qui valent 1,667 fois moins en 1920×1080. La faire dire au
## harnais coûte cinq lignes et la rend lisible sur toutes les captures suivantes.
##
## Le bord droit est demandé à la main et non déduit de sa taille : la vue est ancrée sur
## toute la largeur de l'écran, donc son propre bord droit ne dit rien de ses cartes.
func _step_fit_line() -> String:
	var cards := _hand_view.right_edge()
	var button := _step.global_position.x
	var verdict := "recouvrement %d px" % (cards - button) if cards > button 		else "%d px de dégagement" % (button - cards)
	return "bande basse : droite des cartes x=%d, gauche du bouton x=%d, %s" % [
		cards, button, verdict]

## Applique le cran de HUD demandé par `--shot-view`, s'il l'est.
##
## Sans drapeau, la capture montre le rapport complet — ce que toutes les captures du projet
## montrent depuis `T2`, et ce qu'un lecteur de journal attend par défaut.
func _apply_shot_view() -> void:
	# Le repli est un **axe à part** du cran de rapport, et il s'applique avant lui : les
	# deux se cumulent, et l'ordre ne change rien puisqu'ils portent sur deux vues qui ne
	# se connaissent pas. `--shot-view aucun` emporte le HUD entier, donc le repli devient
	# invisible — ce n'est pas une contradiction, c'est ce que « aucun » veut dire.
	if DevShot.has_flag(DevShot.SHOT_FOLD_FLAG):
		_fold_crew()
	var asked := DevShot.argument(DevShot.SHOT_VIEW_FLAG)
	if asked.is_empty():
		return
	if asked == VIEW_NONE:
		_toggle_hud()
		return
	var level := VIEW_NAMES.find(asked)
	if level < 0:
		return
	while _report_level != level:
		_cycle_report()

## Fonde le village là où le domaine le suggère.
##
## Elle doit passer avant tout : depuis `I2`, un run attend son Cœur et refuse tout autre
## geste d'ici là. Sans elle, la journée scriptée poserait zéro carte et la capture
## montrerait une carte nue — ce qui compilerait, ne lèverait aucune erreur, et serait faux
## sur ce qu'elle prétend montrer.
func _scripted_found() -> void:
	if not _state().awaits_its_heart():
		return
	_found_at(_state().suggested_heart_anchor())

## Ce que la ligne oppose à la vague en approche, ou ce que la dernière a coûté.
##
## Imprimé à côté de la réserve, et pour la même raison qu'elle : c'est ce qu'une image ne
## rend pas lisible d'un coup d'œil. Un `BattlePanel` masqué et un `BattlePanel` qui annonce
## zéro brèche se ressemblent beaucoup en capture, et ne disent pas du tout la même chose.
func _armies_line() -> String:
	if _state().awaits_a_battle():
		return "vague en approche : %s, puissance %d" % [
			_state().pending_wave().label, _state().pending_wave().power]
	if _battle_label.is_empty():
		return "aucune vague n'est encore tombée"
	return "dernière vague : %s au jour %d — %d bâtiment(s), %d ouvrier(s) restants" % [
		_battle_label, _battle_day, _state().city().count(), _state().roster().size()]

## Une journée jouée comme une main humaine la jouerait : on pose ce qu'on peut, on
## envoie les ouvriers, on finit la journée.
##
## Elle s'arrête sur la **fin de journée** et non sur un compte écrit ici : une journée de
## trois phases se joue sans qu'une ligne bouge.
##
## Elle s'est d'abord arrêtée sur `resolves()`, ce qui revenait au même tant qu'une seule
## phase par jour résolvait. Depuis que les deux le font, ça n'en jouait plus qu'une —
## défaut que seule la capture pouvait montrer, puisqu'elle est le seul contrôle qui
## compte les jours.
func _scripted_day() -> void:
	while not _state().cycle().is_over():
		if _state().cycle().permits(PhaseDef.ACTION_PLAY):
			_scripted_plays()
		if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
			_scripted_staffing()
		var closed := _state().cycle().closes_the_day()
		_end_phase()
		if closed:
			return

## Franchit `count` phases de plus, pour que la capture s'arrête ailleurs qu'au premier
## créneau d'une journée.
##
## `--shot-evenings` résout des **journées entières**, donc toute capture retombait sur la
## même phase — la première. Les autres étaient des écrans inatteignables, ce qui est resté
## sans conséquence tant qu'une phase ressemblait à sa voisine, et qui est devenu un trou à
## `P1a` : le liseré de couleur du panneau d'affectation n'aurait jamais pu se regarder
## qu'en une seule de ses teintes.
##
## Elle s'arrête d'elle-même sur un run fini ou une bataille en attente, plutôt que de
## forcer : demander plus de phases qu'il n'en reste est une ligne de commande maladroite,
## pas une erreur, et la capture doit rendre l'écran qu'elle a atteint.
func _scripted_skip_phases(count: int) -> void:
	for _index in count:
		if _state().cycle().is_over() or _state().awaits_a_battle():
			return
		if _state().cycle().permits(PhaseDef.ACTION_PLAY):
			_scripted_plays()
		if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
			_scripted_staffing()
		_end_phase()

## Pose et affecte sans finir la phase : l'état sur lequel la capture s'arrête.
##
## C'est le seul moment où le panneau d'affectation a quelque chose à montrer — des postes
## ouverts et des ouvriers dessus. Une phase résolue les efface tous les deux, et l'image
## ne dirait plus rien de ce que `W2` ajoute.
##
## **Elle refermait sur `_refresh_markers()`, et l'image mentait.** `_play_scripted()`
## appelle `RunManager.play()` en direct, sans passer par `_play_here()` : rien ne reposait
## donc la carte ni ne redessinait la main, si bien que la capture montrait la main
## **d'avant** ces poses — cartes déjà jouées comprises. Le défaut a traversé `D2`, `W2` et
## `I2` sans se voir, parce que rien sur une carte ne dépendait d'un état mutable : la
## liste était fausse, mais fausse d'une façon qu'aucun œil ne rattrapait. Le coût de
## `P1a` l'a rendue visible d'un coup — une Habitation payée 20 s'affichait à pleine encre
## sur une réserve qui ne la payait plus.
##
## C'est exactement ce que `F1` a nommé : un harnais qui montre peut être **faux sur ce
## qu'il prétend montrer**, ce qui est pire qu'une panne parce qu'on lui fait confiance.
## `_refresh_targets()` est un sur-ensemble de `_refresh_markers()`, donc le remplacer ne
## retire rien.
func _scripted_open_phase() -> void:
	if _state().cycle().is_over():
		return
	if _state().cycle().permits(PhaseDef.ACTION_PLAY):
		_scripted_plays()
	if _state().cycle().permits(PhaseDef.ACTION_ASSIGN):
		_scripted_staffing()
	_refresh_targets()

## Pose une carte de chaque nature qui trouve une cible : un bâtiment payable, puis les
## verbes. L'ordre compte — le chantier doit exister avant que *Construire* le vise.
func _scripted_plays() -> void:
	for card in _state().deck().hand().cards_in(CardData.POOL_BUILDING):
		if _play_scripted(card):
			break
	for card in _state().deck().hand().cards_in(CardData.POOL_ACTION):
		_play_scripted(card)

## Joue cette carte sur la première cible venue, du centre vers les bords. Vrai si elle
## est partie.
func _play_scripted(card: StringName) -> bool:
	for cell in _cells_from_the_middle():
		if RunManager.play(card, cell, _turns, _direction).is_ok():
			return true
	return false

## Remplit les actions posées, par le bouton lui-même.
##
## Elle recopiait la boucle « premier libre » jusqu'à `W2`. Passer par
## `RunManager.auto_staff()` la raccourcit à une ligne, et surtout fait entrer le chemin
## neuf du jalon dans le seul contrôle qui regarde l'écran — sans quoi ni le parsing, ni
## les tests, ni la capture n'auraient jamais emprunté le bouton.
func _scripted_staffing() -> void:
	RunManager.auto_staff()
	_refresh_markers()

## Les cellules de la carte, balayées **du centre vers les bords**.
##
## Le coin de la carte est exactement l'endroit que le rapport texte recouvre : une
## première capture de `D2` n'y montrait ni les bâtiments ni le jalon posé dessus.
## L'ordre reste totalement déterministe — à distance égale, le balayage en y puis en x
## départage.
func _cells_from_the_middle() -> Array[Vector2i]:
	var extent := _state().terrain().size()
	var middle := extent / 2
	var cells: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var near := (first - middle).length_squared()
		var far := (second - middle).length_squared()
		if near != far:
			return near < far
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x)
	return cells
