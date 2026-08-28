class_name WaveDef
extends Resource
## Une vague : ce qui vient, et avec quelle force.
##
## Les .tres vivent dans data/waves/, un par vague. Le domaine la reçoit en argument et ne
## lit jamais GameDatabase, comme pour BuildingData et TerrainData.
##
## **Une Resource et non un DTO de contracts/**, alors que CLAUDE.md la rangeait là depuis
## I0. La correction est faite en même temps que le fichier, et elle suit ce que le projet
## fait déjà partout : une PhaseDef décrit la forme d'une journée et vit dans src/schema/ ;
## une BuildingData traverse tous les systèmes dans un BuildingSnapshot ; ProductionResolver
## et SiteResolver reçoivent leurs blocs d'équilibrage en argument. Un contenu que l'on
## édite dans un .tres n'a rien à faire dans contracts/, qui est l'endroit où deux systèmes
## **du code** se rencontrent.
##
## **Elle a attendu F2b pour dire qui vient, et c'était le bon moment.** À F1 elle ne
## portait qu'une puissance et un nom, sur l'argument que l'enrichir d'avance reviendrait à
## deviner la forme du combat. Cette forme existe depuis F2a : des corps sur une grille,
## chacun décrit par un EnemyData. Une vague est donc une **liste de corps** et un nombre de
## manches à tenir, et rien de plus — la direction dont elle vient reste dehors, parce que
## personne ne la lit encore et que F3b la datera avec le reste du calendrier.
##
## Deux époques cohabitent le temps que le bouchon meure, exactement comme CombatBalance en
## porte trois depuis F2a : `power` est le seul chiffre de F1, il ne sert qu'à
## InstantCombatResolver, et il part avec lui à F3b.
##
## Elle ne dit pas non plus **quand** elle tombe. La fréquence des vagues est un OUVERT de
## DESIGN.md 2, et un run qui ne se bat pas encore n'a personne pour lire un calendrier :
## l'écrire ici serait une frontière que personne ne franchit. C'est I2 qui la datera, en
## même temps qu'il branchera le combat sur la fin de journée.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Identifiant stable. Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Libellé affiché. C'est la seule chose que l'écran dit de la vague.
##
## Réclamé comme celui d'une PhaseDef, et pour la même raison : une vague sans nom
## s'annoncerait par son identifiant interne, en anglais, au milieu d'un rapport français.
@export var label: String

## Ce qu'elle jette contre le village. **Le champ du bouchon de F1, et lui seul.**
##
## Confrontée à la défense de la ville et des engagés ; la différence est la brèche, et
## tout le reste en découlait. DESIGN.md 3.6 l'annonçait jetable dès F1 ; il l'est resté à
## F2b parce que InstantCombatResolver fait encore tourner le jeu, et il partira avec lui
## quand F3b branchera le plateau sur le run. Le vrai combat ne le lit jamais : une vague y
## est ce que `roster` dit, pas un chiffre.
@export_range(0, 500, 1) var power: int

## Les assaillants qui viennent, un identifiant d'EnemyData par corps.
##
## Les répétitions sont écrites : trois pillards s'écrivent trois fois. C'est plus verbeux
## qu'un couple (type, nombre) et c'est voulu — l'ordre est celui des cases d'entrée, que
## BattleGround rend **du centre vers les bords**, donc c'est lui qui décide qui arrive au
## milieu et qui arrive sur l'aile. Un compte aurait laissé cette décision au code.
##
## **Réclamé non vide**, comme CombatBalance.impassable_tags et pour la même raison : Godot
## n'écrit pas un tableau vide dans un .tres, donc « oublié » et « délibérément vide » y
## sont indiscernables. Une vague sans personne n'est pas une vague facile, c'est un fichier
## vide qui se lit comme une vague — ce que `power` refuse déjà pour l'autre époque.
##
## Que ces identifiants existent vraiment est vérifié par GameDatabase au boot : une
## WaveDef ne lit pas l'index, et c'est très bien ainsi. Même partage que les cartes qui
## posent un bâtiment.
@export var roster: Array[StringName]

## Manches à tenir pour qu'elle reparte.
##
## DESIGN.md 3.6 : « Une vague est une razzia, pas un duel. Tenir N tours suffit à ce
## qu'elle reparte ; battre tous les ennemis donne un bonus par-dessus. » C'est ce N, et il
## est **par vague** plutôt que dans CombatBalance : un siège s'installe là où une
## escarmouche passe, et la durée d'une razzia est du contenu au même titre que sa
## composition. Les deux se règlent dans le même .tres, ce qui est la seule façon de les
## garder d'accord.
##
## Il ne désigne aucun vainqueur — il n'y a ni victoire ni défaite au combat, seulement une
## facture. Il dit combien de temps la facture court.
@export_range(1, 50, 1) var rounds: int

## Champs non renseignés ou incohérents. Vide = vague exploitable.
## Vérifiée au boot par GameDatabase, comme les terrains, les bâtiments et les cartes.
##
## `power` est réclamé strictement positif : une vague à zéro se contient toute seule, ne
## casse rien et ne se distingue en rien d'une journée sans combat. Elle n'est pas une
## vague facile, c'est un fichier vide qui se lit comme une vague. `roster` est réclamé pour
## la même raison, sur l'autre époque ; `rounds` parce qu'une razzia qui repart au bout de
## zéro manche n'entre jamais.
##
## Ce que ce contrôle ne peut **pas** faire : dire que `roster` nomme des assaillants qui
## existent. Une Resource ne lit pas l'index, et c'est la règle qui a mis les mêmes
## contrôles chez GameDatabase pour les coûts et les cartes.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if power <= 0:
		missing.append("power")
	if roster.is_empty():
		missing.append("roster")
	if rounds <= 0:
		missing.append("rounds")
	return missing
