class_name Staffing
extends RefCounted
## La règle qui décide, quand les bras manquent, quels bâtiments s'arrêtent.
##
## DESIGN.md 3.4 : « Quand l'effectif doit baisser et qu'aucun travailleur n'est
## disponible, le bâtiment bâti le plus récemment passe en sommeil et rend ses
## travailleurs. On répète tant qu'il le faut. »
##
## ---
##
## **Le sommeil n'est pas un état, c'est un calcul.** C'est la décision qui porte ce
## fichier, et elle vaut d'être écrite parce que l'alternative était tentante : mémoriser
## sur chaque bâtiment s'il dort, et le mettre à jour à chaque famine, chaque destruction,
## chaque démolition. Deux états à garder d'accord finissent toujours par diverger, et
## celui-ci aurait divergé en silence — un bâtiment endormi par erreur ne plante pas, il
## ne produit simplement plus.
##
## Ici, rien n'est stocké : le plan se **redérive** de l'effectif et de l'ordre de pose, à
## chaque fois qu'on le demande. Une population qui remonte repeuple donc toute seule, ce
## que DESIGN.md 3.4 réclame en toutes lettres, et sans qu'aucun geste ait à l'ordonner.
##
## **Extinguer du plus récent revient à garder le plus long préfixe qui tient**, les deux
## formulations sont équivalentes puisque les sommes cumulées ne décroissent jamais. On
## écrit la seconde, qui se lit en une passe.
##
## ---
##
## **Un bâtiment qui ne coûte aucun travailleur ne dort jamais**, et cette ligne n'était pas
## dans la spécification : elle a été trouvée en écrivant la boucle, en vérifiant que
## l'interdit de blocage de DESIGN.md 3.4 tenait vraiment.
##
## Il ne tenait pas. La soupape est l'habitation gratuite en bras : village bloqué, on bâtit
## une habitation, le plafond monte, la population repart. Mais une habitation neuve est le
## bâtiment **le plus récent**, donc le premier qu'un préfixe strict endort — et un chantier
## endormi n'avance pas. La soupape existait dans la data et ne s'ouvrait jamais.
##
## Le correctif est d'une ligne et il se justifie tout seul : dormir veut dire « il manque
## des bras », et un bâtiment qui n'en demande aucun ne peut pas en manquer. Une palissade
## se bâtit pendant une famine.
##
## C'est la règle que le cas de test du jalon garde, et elle vaut d'être relue avant de
## toucher à cette boucle — la modifier sans y penser rend une partie mortellement bloquée
## sans qu'aucun test de population ne le voie.
##
## Il reçoit un CitySnapshot — un contrat — et jamais le CityState : l'Économie ne voit pas
## les internes de la Construction.

## Qui tourne et qui dort, pour cette ville et cet effectif.
##
## L'ordre de pose est la priorité que le joueur a déjà exprimée : on sert du plus ancien
## au plus récent, et ce qui déborde s'arrête. C'est le même argument que W2 employait pour
## le bouton d'auto-affectation du jeu d'avant, et il survit à sa disparition.
##
## Les **chantiers comptent comme les bâtiments finis**, et c'est voulu : leurs travailleurs
## ont été payés à leur ouverture (DESIGN.md 3.4), donc ils immobilisent déjà. Un chantier
## endormi n'avance pas — ce qui est la même phrase que « un bâtiment endormi ne produit
## pas », dite pour l'autre moitié de la ville.
static func resolve(city: CitySnapshot, headcount: int) -> StaffingPlan:
	assert(headcount >= 0, "effectif négatif")
	var active: Array[Vector2i] = []
	var asleep: Array[Vector2i] = []
	var committed := 0
	var short_handed := false
	for building in city.buildings():
		var needed := building.data().workers
		if needed <= 0:
			active.append(building.anchor())
			continue
		if short_handed or committed + needed > headcount:
			short_handed = true
			asleep.append(building.anchor())
			continue
		committed += needed
		active.append(building.anchor())
	return StaffingPlan.create(active, asleep, committed, headcount)

## Ce que cette ville immobiliserait si tout tournait.
##
## Sert à répondre « puis-je ouvrir ce chantier ? » sans passer par un plan : c'est la
## demande totale, pas ce que l'effectif honore. Un village qui dort en réclame plus qu'il
## n'en a.
static func demand(city: CitySnapshot) -> int:
	var total := 0
	for building in city.buildings():
		total += maxi(0, building.data().workers)
	return total
