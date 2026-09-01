class_name RunBalance
extends Resource
## Réglages du run : combien de tours il dure, par quoi il commence, combien de chantiers
## tiennent de front, et ce qu'il vaut à la fin.
##
## Cinquième bloc de BalanceData, et le seul qui décide d'un **tempo**. Le bloc du même nom
## existait avant R0 et portait la forme d'une journée en phases ; celui-ci n'en garde rien,
## parce que DESIGN.md 2 a ramené la journée à un tour : « Il n'y a qu'une sorte de tour, et
## c'est le principal gain du rescope. »
##
## Ce qu'il **ne porte pas**, et il faut le dire parce que l'ancien le portait : aucun nom de
## moment, aucune liste de phases, aucun calendrier de vagues. Les deux premiers n'ont plus
## d'objet ; le troisième est daté de V4, qui écrira la vague qui tombe à sa date. Un champ
## ajouté d'avance oblige à deviner sa forme.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Tours qu'un run dure avant son verdict.
##
## DESIGN.md 2 garde la durée d'un run sous un OUVERT — run fini ou mode sans fin —, et
## data/balance/ est précisément l'endroit où l'on itère sur une question encore ouverte.
## Les deux réponses sont ce champ rempli différemment.
@export_range(1, 200, 1) var turns: int

## Bâtiment posé à l'ouverture d'un run, sur la cellule que le joueur désigne.
##
## Il est ici plutôt qu'écrit en dur dans src/domain/run/ pour la raison la plus simple :
## &"heart" dans un .gd serait un identifiant de contenu dans du code, ce que les
## conventions refusent partout ailleurs.
##
## **Vide est une réponse et non un oubli** — c'est le run d'un harnais qui veut une carte
## nue et pas de fondation. Le champ n'est donc pas réclamé par missing_fields(), à
## l'inverse de tous les autres ; que le bâtiment nommé existe l'est en revanche, à
## l'ouverture du run.
@export var starting_building: StringName

## Chantiers qui peuvent être ouverts **en même temps**.
##
## La file de chantiers de DESIGN.md 3.2, et c'est l'un des deux régulateurs qui remplacent
## la main de cartes et le pool d'ouvriers supprimés. Les deux ne se doublent pas, parce
## qu'ils ne répondent pas à la même question : les travailleurs disent ce que le village
## peut **posséder**, la file ce qu'il peut **faire à la fois**.
##
## Elle mord surtout au lendemain d'une vague, quand il faut choisir entre réparer et
## grandir — c'est la seule raison de la garder à côté des travailleurs. À I3 seul *Bâtir*
## s'y dispute une place ; C5 y met le terrassement et C6 la réparation, sans qu'une ligne
## d'ici ne change.
##
## Un emplacement est pris de l'ouverture du chantier à son achèvement, jamais au tour près.
@export_range(1, 10, 1) var build_slots: int

## Points de score par unité restée en réserve.
##
## Les quatre champs qui suivent sont les quatre termes que DESIGN.md 5 énumère —
## « ressources, bâtiments intacts, population, points de vie restants du Cœur ». Ils
## échappent à la doctrine du zéro : un poids nul est un choix d'équilibrage lisible — « la
## thésaurisation ne vaut pas de points » — et le réclamer interdirait de l'essayer sans
## toucher au GDScript.
##
## Le filet est posé un cran plus haut : **au moins un des quatre doit compter**. Un poids
## effacé reste invisible, la disparition du barème entier ne l'est pas.
@export_range(0, 100, 1) var score_per_resource: int

## Points de score par bâtiment **achevé** encore debout à la fin du run.
##
## Achevé et non posé, par la règle qui vaut depuis C4 : un chantier n'est pas un bâtiment,
## et CitySnapshot.completed() répond déjà exactement cette question à ses autres
## consommateurs. Un chantier laissé en plan au dernier tour n'est pas un bâtiment intact.
@export_range(0, 100, 1) var score_per_building: int

## Points de score par habitant vivant à la fin du run.
##
## Il remplace les deux termes de roster de DESIGN.md 5 d'avant le rescope — les ouvriers
## vivants et la somme de leurs niveaux —, et il en remplace deux par un parce que la
## population est un **entier** : il n'y a plus de niveau à sommer, donc plus de second
## terme à pondérer.
@export_range(0, 100, 1) var score_per_inhabitant: int

## Points de score par point de vie restant au Cœur.
##
## DESIGN.md 5 le nomme, et il est écrit dès I3 bien que **rien ne l'abîme avant V4** : il
## vaudra ses PV pleins à chaque run jusque-là. Ce n'est pas le champ ajouté d'avance que le
## projet refuse depuis E1b — celui-là n'est lu par personne, celui-ci l'est par RunOutcome
## dès le premier run joué. Ce qui lui manque est de la variété, pas un lecteur.
##
## Il est aussi ce qui rend une mauvaise vague **coûteuse sans être fatale**, quand elles
## existeront : DESIGN.md 3.5 veut que « ce n'est pas tout ou rien, une vague à moitié
## arrêtée coûte la moitié », et un run qui se termine sur un Cœur entamé doit le dire
## quelque part.
@export_range(0, 100, 1) var score_per_heart_hit_point: int

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## Le seul contrôle qui ne soit pas une simple présence est celui du barème, et il est écrit
## d'un cran au-dessus des quatre poids pour la raison qui vaut à tous les filets de ce
## genre : quatre poids nuls sont un run qui vaut zéro quoi qu'on y fasse, c'est-à-dire la
## disparition d'un format et non un réglage.
##
## Ce que ce fichier ne peut **pas** contrôler, et c'est la question que CLAUDE.md fait poser
## avant tout missing_fields() : que `starting_building` nomme un bâtiment qui existe. Une
## RunBalance ne lit jamais l'index, donc la règle monte d'un cran — ici jusqu'à l'ouverture
## du run, qui tient le catalogue.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if turns <= 0:
		missing.append("turns")
	if build_slots <= 0:
		missing.append("build_slots")
	if score_per_resource <= 0 and score_per_building <= 0 \
			and score_per_inhabitant <= 0 and score_per_heart_hit_point <= 0:
		missing.append("score.none_counts")
	return missing
