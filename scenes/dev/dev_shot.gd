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

## Harnais à lancer, par-dessus la constante `HARNESS` de `dev_boot.gd`.
##
## Il entre à `T4` pour une raison qui vaudra pour tous les jalons suivants : la revue de
## deux cents seeds vit chez le harnais Terrain, alors que le harnais par défaut est celui du
## Run — donc la mesure du jalon n'était atteignable qu'en éditant une constante et en
## relançant, ce qui revient à dire que personne ne la lancerait. C'est la phrase de ce
## fichier appliquée un cran plus haut : **un état qu'aucune ligne de commande ne peut
## atteindre est un état que personne ne regardera**, et un harnais est un état comme un
## autre.
const HARNESS_FLAG := "--harness"

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

## Moment du cycle solaire à photographier, en fraction de révolution : 0 à l'aube, 0,25 à
## midi, 0,5 au crépuscule, 0,75 au cœur de la nuit. Lu par les harnais qui éclairent.
##
## Une capture se pose sinon là où le jeu laisse le soleil entre deux tours, c'est-à-dire
## **toujours à midi** : la course entière serait un état qu'aucune image ne peut atteindre,
## donc que personne ne regarderait. C'est la phrase que `P1a` a laissée au projet, et le
## corollaire qu'elle traîne — quand une vue se met à commuter sur un état, vérifier d'abord
## qu'un drapeau atteint **chacune** de ses valeurs.
##
## Il ne sert qu'à regarder. Aucun geste du jeu ne le produit, et c'est bien pour ça qu'il
## faut un drapeau.
const SHOT_SUN_FLAG := "--shot-sun"

## Bâtiment à sélectionner avant de capturer, numéroté comme au clavier — 1 pour le premier.
##
## Il existe pour la même raison que le suivant, et la fiche de `N2` en a besoin de façon plus
## pressante encore : elle commute sur **quatre** états — coût couvert, réserve courte, bras
## courts, les deux —, et « réserve courte » ne s'obtient qu'en désignant un bâtiment qu'on
## ne peut pas payer. Sans ce drapeau, une capture ne montrerait jamais que le premier
## bâtiment du catalogue, donc jamais ce que la moitié d'une fiche sert à dire.
##
## Zéro et absent valent « ne touche à rien », c'est-à-dire le premier du catalogue.
const SHOT_SELECT_FLAG := "--shot-select"

## Ne fonde pas le Cœur avant de capturer. Drapeau **nu**.
##
## Une capture pose sinon le Cœur d'office, sans quoi toute image montrerait une carte nue.
## Cet état-là — le run qui **attend** sa fondation — est donc devenu inatteignable le jour
## où le harnais a su le photographier, et il l'est resté tant que rien n'y changeait de
## couleur.
##
## `N2` l'y a fait changer : la fiche décrit ce que le clic gauche poserait, donc le **Cœur**
## tant qu'il n'est pas fondé, et la sélection ensuite. C'est le corollaire de `P1a`, à la
## lettre — quand une vue se met à commuter sur un état, vérifier d'abord qu'un drapeau
## atteint chacune de ses valeurs.
const SHOT_UNFOUNDED_FLAG := "--shot-unfounded"

## Génère un grand nombre de cartes sans écran et imprime leur distribution, puis quitte.
## Drapeau **nu**.
##
## C'est ce que `DESIGN.md` 3.1 demande à `T4` en toutes lettres — « un harnais génère deux
## cents seeds et imprime la distribution des accès, de la surface plate et de la distance
## lisière → Cœur » —, et c'est le pendant de `--chronicle` pour le Terrain : le seul contrôle
## qui regarde la génération sur autre chose qu'une carte. Un seed bien choisi ne dit rien
## d'un générateur ; deux cents disent s'il tient ses promesses et à quel prix.
const SURVEY_FLAG := "--survey"

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

## Moment du cycle solaire demandé, ou `fallback` si le drapeau est absent.
##
## `to_float()` rend 0.0 sur une chaîne vide, ce qui est **l'aube** et non « pas de
## demande » : les deux se distinguent donc en regardant la présence du drapeau, jamais sa
## valeur. Sans ça, toute capture sans drapeau se prendrait au lever du jour.
static func sun_moment(fallback: float) -> float:
	if not has_flag(SHOT_SUN_FLAG):
		return fallback
	return argument(SHOT_SUN_FLAG).to_float()

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
