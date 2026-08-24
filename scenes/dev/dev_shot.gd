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

## Images laissées passer avant de capturer. La première ne porte encore ni le tampon
## d'instances téléversé ni la lumière, et rendrait un cadre vide.
const WARMUP_FRAMES := 3

## Chemin de capture demandé, ou "" si aucune capture n'est demandée.
static func path() -> String:
	return argument(SHOT_FLAG)

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
