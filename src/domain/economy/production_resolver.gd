class_name ProductionResolver
extends RefCounted
## Ce que les bâtiments rendent au village, une fois par tour.
##
## Fonction pure au sens du domaine : tout lui est fourni, elle ne lit ni GameDatabase ni le
## moindre Node. Elle mute le Ledger, ce qui n'est pas une entorse — la réserve est l'état
## **interne** de l'Économie, comme CityState l'est de Construction, et UpkeepResolver a déjà
## exactement ce profil depuis N1 : muter ce qui est à soi, puis rendre le récit.
##
## ---
##
## **La production est passive, et c'est le renversement du rescope.** DESIGN.md 2 : « Un
## bâtiment fini qui a ses habitants produit, tous les tours, sans qu'on lui demande rien.
## C'est un renversement explicite de la règle qui portait l'ancien document — un bâtiment
## dont aucun slot n'a reçu d'action ne rend rien —, et il est nécessaire : cette règle
## n'existait que pour donner un emploi aux cartes. » Le résolveur d'avant partait des
## actions posées ; celui-ci part de la ville, et il est plus court d'un tiers pour ça.
##
## **Trois conditions, et pas une de plus.** Achevé, actif, et porteur de **quelque chose à
## verser** — un bloc de production, des règles d'adjacence, ou les deux. La troisième s'est
## élargie à `C3` : rien n'oblige un bâtiment qui se bonifie au voisinage à produire par
## ailleurs, et la refuser aurait été une règle de contenu écrite dans un résolveur.
##
## **Tout ou rien, jamais au prorata.** Un bâtiment à moitié servi qui produirait à moitié
## serait un chiffre mou et une explication à donner ; « cette ferme dort, il me manque un
## toit » est une phrase qu'un joueur comprend et corrige. C'est un anti-pattern nommé dans
## CLAUDE.md, et il est tenu ici par construction : `is_active()` rend un booléen.
##
## ---
##
## **Le TerrainQuery est entré à C3, et pas avant.** I3 le lui avait retiré : le contrat de
## DESIGN.md 3.3 le portait à cause de la seconde lecture du jeu d'avant — une carte jouée **à
## cru** sur une case rendait ce que le tag de cette case dictait —, et ce geste avait disparu
## avec les cartes. Le garder aurait été le champ ajouté d'avance que ce projet refuse depuis
## E1b, avec en prime une signature qui ment sur ce qu'elle lit.
##
## Il revient donc **avec ce qui le lit**, comme les PV sont entrés avec F1, et ce qui le lit
## est `Adjacency`. Deux jalons se sont écoulés entre le retrait et le retour, et le fichier
## n'a rien eu à défaire : c'est ce que le pari valait.
##
## **Le bonus est calculé ici, pas stocké sur le bâtiment.** Un rendement figé à la pose se
## périmerait au premier terrassement de `C5` — et il aurait fallu se souvenir de le
## recalculer, ce qui est la forme d'oubli la plus silencieuse qui soit : le chiffre reste
## juste jusqu'au jour où il ne l'est plus, sans que rien ne bouge.
##
## Ce qu'il ne fait pas non plus : l'upkeep, qui est chez UpkeepResolver depuis N1 parce que
## manger ne dépend pas de la ville ; et les plafonds, que CityLimits calcule et que
## l'orchestrateur applique — les appliquer ici en appliquerait un sur deux, et laisserait le
## logement à quelqu'un d'autre.

## Résout la production d'un tour : dépose la récolte sous le plafond, rend le rapport.
##
## Le plafond de la réserve est celui que le Ledger porte **déjà** : l'appelant l'a posé
## avant d'entrer ici, et il l'a posé en même temps que le plafond de logement. Le
## recalculer serait la seconde arithmétique à tenir d'accord avec la première.
##
## `plan` doit avoir été résolu sur **cette** ville et sur l'effectif du moment. Rien ici ne
## peut le vérifier — un plan ne se souvient pas de la ville qui l'a produit —, et c'est
## pourquoi l'orchestrateur les fabrique dans la même fonction, à deux lignes d'écart.
static func resolve(city: CitySnapshot, plan: StaffingPlan, terrain: TerrainQuery,
		ledger: Ledger, balance: EconomyBalance) -> ProductionReport:
	assert(city != null, "production sans ville")
	assert(plan != null, "production sans plan d'occupation")
	assert(terrain != null, "production sans terrain")
	assert(ledger != null, "production sans réserve")
	assert(balance != null, "production sans équilibrage")

	var produced: Dictionary[StringName, int] = {}
	var producers: Array[Vector2i] = []
	var dormant: Array[Vector2i] = []
	for building in city.completed():
		var data := building.data()
		if not data.produces() and data.adjacency.is_empty():
			continue
		if not plan.is_active(building.anchor()):
			dormant.append(building.anchor())
			continue
		producers.append(building.anchor())
		if data.produces():
			for resource in data.production.yield_per_turn:
				produced[resource] = produced.get(resource, 0) \
					+ data.production.yield_per_turn[resource]
		var bonus := Adjacency.bonus(data, building.anchor(), building.turns(), terrain)
		for resource in bonus:
			produced[resource] = produced.get(resource, 0) + bonus[resource]

	var stored := ledger.deposit(produced)
	return ProductionReport.create(produced, stored, producers, dormant)
