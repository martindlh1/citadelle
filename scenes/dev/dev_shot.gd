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
##
## **Un drapeau n'existe que tant qu'un harnais le lit.** `R0` a supprimé sept harnais sur
## neuf et retiré du README les dix drapeaux qui les servaient — `--shot-evenings`,
## `--shot-phases`, `--shot-fold`, `--shot-piles`, `--shot-view`, `--shot-restart`,
## `--shot-select`, `--shot-foes`, `--shot-rounds` et `--chronicle` — mais les avait laissés
## ici. Le code et la documentation se sont donc contredits pendant deux jalons, et rien ne
## pouvait le dire : ce fichier n'a ni test ni écran. `I3` les retire, et rend ceux dont son
## tour a besoin.
##
## La phrase qui les fait naître, elle, ne bouge pas : **un état qu'aucune capture ne peut
## atteindre est un état que personne ne regardera.**

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

## Tours à résoudre avant de capturer. Lu par les harnais qui savent résoudre ; les autres
## l'ignorent, comme ils ignorent déjà les drapeaux qui ne les concernent pas.
##
## Il rend à `I3` ce que `--shot-evenings` faisait pour la journée en phases, et il existe
## pour la même raison : un rapport de fin de tour est du texte fabriqué à la main, donc
## exactement le genre de code que ni le parsing ni les tests ne regardent. Sans lui, le
## chemin de résolution du harnais Run ne serait emprunté par aucun contrôle, et toute
## capture montrerait un village qu'on vient de fonder.
const SHOT_PASSES_FLAG := "--shot-passes"

## Rejoue le run entier sans écran et imprime ce que ça donne, tour par tour. Drapeau **nu**.
##
## Le seul drapeau de ce fichier qui ne capture pas une image, et il est ici quand même :
## `DevShot` est l'unique endroit du projet qui lise la ligne de commande, et un second
## lecteur serait un second endroit où l'on écrit `OS.get_cmdline_user_args()`.
##
## Il vient du jeu d'avant, où il arbitrait deux modèles de journée, et `I3` le rend pour la
## même raison exactement : c'est le seul contrôle qui joue la boucle entière sur la data
## réelle, là où le parsing et les tests n'en jouent jamais vingt tours d'affilée. Il
## n'arbitre rien, et le rapport le dit en toutes lettres — la politique qu'il joue est
## bête, donc ses chiffres sont un plancher et non une partie bien jouée.
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
