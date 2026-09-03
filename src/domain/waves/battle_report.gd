class_name BattleReport
extends RefCounted
## Ce qu'une bataille a fait : combien de ticks, combien de morts, ce que le Cœur a pris, et ce
## que le village a perdu.
##
## Immuable. Rendu par CombatBoard.report().
##
## ---
##
## **Il vit dans domain/waves/ et non dans contracts/, et c'est un choix contre une prédiction.**
## `CLAUDE.md` annonçait qu'un rapport de bataille serait le premier DTO à entrer dans
## `contracts/` à `V2`. Le critère, lui, n'est pas rempli : ce rapport va des Vagues à
## `domain/run/`, et `domain/run/` a le droit de tout lire — ce n'est pas un second système. Les
## adapters le liront aussi, et lire le domaine est leur métier.
##
## C'est exactement le sort que `ProductionReport` a connu deux fois : annoncé pour `N1`, puis
## pour `I3`, refusé par les deux. Le fichier note lui-même que c'est la discipline — « aucun
## n'entre avant que **deux systèmes du domaine** le franchisse vraiment » — et une prédiction
## ne vaut pas un critère. Le coût d'une promotion le jour où elle se justifie est un
## déplacement de fichier ; celui d'une frontière inventée trop tôt est une forme figée avant
## qu'on la connaisse.
##
## ---
##
## **Il constate, il ne décide pas.** « Trois corps sur dix ont atteint le Cœur, qui a pris 24 »
## est un fait ; « la défense était mal placée » est un jugement, et personne ici ne le porte.
## C'est ce qui permet à `V4` d'appliquer ces chiffres et à un harnais d'en imprimer une table
## sans qu'ils arrivent déjà interprétés.
##
## **Ce qu'il ne dit pas : ce que la ville devient.** Il nomme les ancres percées ; retirer un
## bâtiment, rendre ses travailleurs au pool et faire partir ceux qu'un toit logeait sont trois
## gestes de trois autres systèmes, et c'est l'orchestrateur qui les enchaîne à `V4`. Un rapport
## qui muterait la ville serait la faute d'architecture que ce projet refuse en premier.

## Ticks qu'il a fallu pour que tout soit joué.
var _ticks: int = 0

## Corps tombés.
var _killed: int = 0

## Tirs lâchés, touchés ou perdus.
##
## **Il est là parce qu'une table sans lui invite à la mauvaise conclusion**, et c'est le harnais
## de `V2` qui l'a montré : une tour posée sur le chemin ne tuait personne, et la ligne « zéro
## mort » se lisait comme « la défense ne marche pas ». Elle avait tiré une fois. Le défaut
## n'était ni dans le plateau ni dans le ciblage — c'était une cadence plus longue que la fenêtre
## pendant laquelle un corps reste à portée, donc un chiffre à régler.
##
## Un rapport qui dit ce qu'il a **tenté** en même temps que ce qu'il a **obtenu** distingue « la
## mécanique ne répond pas » de « les chiffres sont mauvais ». Les deux se corrigent ailleurs.
var _shots: int = 0

## Corps qui ont atteint le Cœur.
var _arrived: int = 0

## Ce que le Cœur a encaissé.
var _heart_damage: int = 0

## Ancre -> dégâts pris, pour chaque bâtiment que la vague a percé.
var _damaged: Dictionary[Vector2i, int] = {}

## Rapport brut. Réservé à CombatBoard, qui est le seul à savoir le composer.
static func create(ticks: int, killed: int, arrived: int, heart_damage: int,
		damaged: Dictionary[Vector2i, int], shots: int) -> BattleReport:
	assert(ticks >= 0, "bataille de durée négative : %d" % ticks)
	assert(killed >= 0 and arrived >= 0, "compte de corps négatif")
	assert(heart_damage >= 0, "dégâts négatifs au Cœur : %d" % heart_damage)
	assert(shots >= 0, "compte de tirs négatif : %d" % shots)
	var report := BattleReport.new()
	report._ticks = ticks
	report._shots = shots
	report._killed = killed
	report._arrived = arrived
	report._heart_damage = heart_damage
	report._damaged = damaged.duplicate()
	return report

## Ticks écoulés.
func ticks() -> int:
	return _ticks

## Corps tombés.
func killed() -> int:
	return _killed

## Tirs lâchés, touchés ou perdus.
func shots() -> int:
	return _shots

## Tirs qui n'ont rien tué, faute d'avoir suffi ou parce que leur cible est morte en vol.
##
## Une lecture et non un compteur : elle se déduit des deux autres. Elle existe parce que c'est
## sous cette forme qu'on la regarde — « la tour a tiré quatre fois pour un mort » dit à la fois
## que la mécanique répond et que la cadence est trop lente.
func wasted() -> int:
	return maxi(0, _shots - _killed)

## Corps qui ont atteint le Cœur.
func arrived() -> int:
	return _arrived

## Corps engagés, morts et arrivés confondus.
func fielded() -> int:
	return _killed + _arrived

## Ce que le Cœur a encaissé.
##
## **Ce n'est pas tout ou rien**, et c'est ce que `DESIGN.md` 3.5 veut : « une vague à moitié
## arrêtée coûte la moitié ». C'est ce qui donne au run une jauge de santé lisible d'un bout à
## l'autre, et ce qui rend une mauvaise vague survivable mais coûteuse.
func heart_damage() -> int:
	return _heart_damage

## Le village a-t-il tenu, c'est-à-dire le Cœur n'a-t-il rien pris ?
func held() -> bool:
	return _heart_damage == 0

## Ancre -> dégâts pris. Copie.
func damaged() -> Dictionary[Vector2i, int]:
	return _damaged.duplicate()

## Les ancres percées, dans l'ordre où la ville les a posées. Copie.
func breached() -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	anchors.assign(_damaged.keys())
	return anchors
