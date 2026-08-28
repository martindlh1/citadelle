class_name DevShot
extends RefCounted
## Le vocabulaire de capture des harnais de dev, en un seul endroit.
##
## Ces drapeaux sont documentés dans le README comme une fonctionnalité du projet et
## non d'un harnais : deux harnais qui les redéfiniraient chacun de leur côté
## finiraient par ne plus accepter la même ligne de commande, et la faute ne se verrait
## qu'en tapant la commande de l'un sur l'autre.
##
## Le déroulé d'une capture, lui, reste chez chaque harnais : ce qu'il faut mettre en
## place avant de déclencher diffère trop — une rotation et une sonde ici, un fantôme
## et une ville là.
##
## Les arguments qui suivent -- sont ceux du jeu et non du moteur, d'où
## get_cmdline_user_args().

## Déclenche une capture vers ce chemin, puis quitte.
const SHOT_FLAG := "--shot"

## Nombre de quarts de tour appliqués à la caméra avant de capturer.
const SHOT_TURNS_FLAG := "--shot-turns"

## Cellule à désigner avant de capturer, en « x,y ».
const SHOT_HOVER_FLAG := "--shot-hover"

## Quarts de tour appliqués à ce qu'on s'apprête à POSER, à ne pas confondre avec
## --shot-turns qui fait pivoter la caméra. Lu par les harnais qui posent quelque
## chose ; les autres l'ignorent, comme ils ignorent déjà les drapeaux qui ne les
## concernent pas.
const SHOT_ROTATE_FLAG := "--shot-rotate"

## Soirs à résoudre avant de capturer. Lu par les harnais qui savent résoudre ; les
## autres l'ignorent, comme ils ignorent déjà les drapeaux qui ne les concernent pas.
##
## Il existe parce qu'un rapport de fin de soirée est du texte fabriqué à la main, donc
## exactement le genre de code que ni le parsing ni les tests ne regardent : sans lui, le
## chemin de résolution d'un harnais ne serait jamais emprunté par un contrôle.
const SHOT_EVENINGS_FLAG := "--shot-evenings"

## Phases à franchir **en plus** des journées, avant de capturer. Lu par les harnais qui
## connaissent une journée en phases.
##
## Il vient de `P1a`, et il vient de la phrase ci-dessous appliquée à elle-même : une
## journée compte plusieurs phases, mais `--shot-evenings` en résout des journées entières,
## donc une capture s'arrête toujours sur le **premier** créneau. Toutes les autres phases
## étaient des écrans qu'aucune capture ne pouvait atteindre — ce qui n'a gêné personne
## tant qu'une phase ressemblait à une autre, et qui est devenu un trou le jour où la phase
## a eu une couleur à montrer.
const SHOT_PHASES_FLAG := "--shot-phases"

## Replier le panneau d'affectation avant de capturer. Drapeau **nu**, sans valeur.
##
## Même raison que les deux ci-dessus, et le repli est un cas encore plus net : c'est un
## état qu'aucune suite de journées ne produit, puisqu'il ne s'obtient que par un geste du
## joueur. Sans ce drapeau, la seule façon de regarder un HUD replié serait de modifier du
## code pour le regarder — ce qui revient à ne jamais le regarder.
const SHOT_FOLD_FLAG := "--shot-fold"

## Ouvrir la vue des piles avant de capturer. Drapeau **nu**, sans valeur.
##
## Troisième drapeau ouvert par la même porte que `--shot-view`, `--shot-phases` et
## `--shot-fold`, et le cas est aussi net que celui du repli : la vue des piles est une
## modale qu'aucune suite de journées ne fait apparaître, puisqu'elle ne s'obtient que par
## une touche. Sans ce drapeau, la seule façon de la regarder serait de modifier du code
## pour la regarder — c'est-à-dire de ne jamais la regarder.
const SHOT_PILES_FLAG := "--shot-piles"

## Cran d'affichage du HUD au moment de capturer. Lu par les harnais qui en ont un.
##
## Il existe pour la raison qui a valu son drapeau à `--shot-evenings`, et que `I2` a
## reformulée en une phrase : **un écran qu'aucune capture ne peut atteindre est celui que
## personne ne regardera**. Replier un rapport et masquer un HUD sont deux gestes qui ne
## changent que l'image, donc les deux seuls dont ni le parsing ni les tests ne diront
## jamais rien.
const SHOT_VIEW_FLAG := "--shot-view"

## Relance un run neuf après la suite de journées demandée, avant de capturer.
##
## Cinquième drapeau nu, et la même porte que les quatre autres : **un état qu'aucune
## capture ne peut atteindre est celui que personne ne regardera.** Relancer ne s'obtient
## que par un clic sur un écran de fin, donc aucune suite de journées ne le produit — et
## `_restart()` serait du code que ni le parsing, ni les tests, ni une image n'empruntent
## jamais, sur le seul chemin du harnais qui reconstruise un run entier.
##
## Il se cumule avec `--shot-evenings` : `--shot-evenings 16 --shot-restart` joue le run
## jusqu'au verdict, le relance, et capture la fondation du suivant.
const SHOT_RESTART_FLAG := "--shot-restart"

## Corps à sélectionner sur le champ de bataille avant de capturer, par son rang d'entrée.
##
## Sixième passage par la même porte, et le cas est aussi net que le repli de `P1a` : les
## deux voiles d'un combat — où l'on peut aller, ce qu'on peut frapper — ne s'allument
## qu'après un clic sur une fiche. Sans ce drapeau, **la seule image qu'une capture pourrait
## prendre d'une bataille serait celle où rien n'est sélectionné**, c'est-à-dire celle qui
## ne montre aucune des deux choses que `F3a` ajoute.
##
## Un rang et non un identifiant : les corps d'une vague se nomment `raider_0`, ce qui est
## une nomenclature de harnais et n'a aucune raison de fuir sur une ligne de commande.
const SHOT_SELECT_FLAG := "--shot-select"

## Passe la main au camp d'en face avant de capturer. Drapeau **nu**.
##
## Même porte encore : le tour de la vague change la couleur du bandeau, l'encre des fiches
## et qui répond aux clics. Aucune suite de gestes automatique ne l'atteint, puisque `F2a`
## n'a pas d'IA — c'est un état qui ne s'obtient que par un geste, comme le repli.
const SHOT_FOES_FLAG := "--shot-foes"

## Rejoue le run entier sous chaque variante d'équilibrage et imprime ce que ça donne.
##
## Le seul drapeau de ce fichier qui ne capture pas une image, et il est ici quand même :
## `DevShot` est l'unique endroit du projet qui lise la ligne de commande, et un second
## lecteur serait un second endroit où l'on écrit `OS.get_cmdline_user_args()`.
##
## Il vient de `I2b`, qui demande d'arbitrer deux `.tres` en jouant quinze journées. Ce
## qu'une partie jouée ne dit pas et qu'une table dit tout de suite : **si la comparaison
## est honnête**. Un modèle de journée qui résout moitié moins produit moitié moins à coût
## constant, et sans le chiffre on prendrait cet écart pour un ressenti.
##
## Il n'arbitre rien, et le rapport le dit en toutes lettres : « est-ce une corvée » n'est
## pas mesurable. C'est un instrument de dégrossissage, pas un juge.
const CHRONICLE_FLAG := "--chronicle"

## Images laissées passer avant de capturer. La première ne porte encore ni le tampon
## d'instances téléversé ni la lumière, et rendrait un cadre vide.
const WARMUP_FRAMES := 3

## Chemin de capture demandé, ou "" si aucune capture n'est demandée.
static func path() -> String:
	return argument(SHOT_FLAG)

## Ce drapeau est-il présent, quelle que soit sa suite ?
##
## Pour les drapeaux qui n'ont pas de valeur — on les pose ou on ne les pose pas.
## `argument()` ne sait pas les lire : il rend la chaîne **suivante**, donc un drapeau nu
## en fin de ligne rendrait "" comme s'il était absent, et un drapeau nu suivi d'un autre
## rendrait le nom de l'autre.
static func has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)

## Valeur qui suit ce drapeau sur la ligne de commande, ou "" s'il est absent.
static func argument(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index < 0 or index + 1 >= args.size():
		return ""
	return args[index + 1]

## Cellule à désigner, lue en « x,y ». `fallback` à défaut, et aussi sur un argument
## mal formé : une capture doit montrer quelque chose plutôt qu'échouer sur une virgule.
static func hover_cell(fallback: Vector2i) -> Vector2i:
	var raw := argument(SHOT_HOVER_FLAG)
	if raw.is_empty():
		return fallback
	var parts := raw.split(",")
	if parts.size() != 2:
		return fallback
	return Vector2i(parts[0].to_int(), parts[1].to_int())
