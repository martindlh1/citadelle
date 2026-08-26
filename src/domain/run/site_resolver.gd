class_name SiteResolver
extends RefCounted
## Ce que les verbes de chantier ordonnent : les crans posés, la terre déplacée.
##
## Le jumeau de `ProductionResolver` pour l'autre moitié des actions jouées. `D2` a posé
## et affecté *Construire* et *Terraformer* sans les exécuter, et son journal disait
## pourquoi : leur effet mute le `CityState` et la `HeightGrid`, donc l'état de deux autres
## systèmes. Un résolveur d'Économie qui les muterait violerait la règle de dépendance.
##
## Ce fichier est la réponse annoncée : **il ordonne, il ne mute rien.** `RunOrchestrator`
## applique. Il est donc aussi pur que son jumeau — tout lui est fourni, il ne lit ni
## `GameDatabase` ni le moindre `Node` —, et il n'a même pas besoin du terrain : un
## terrassement rend un **delta**, et c'est l'orchestrateur qui sait sur quelle hauteur
## l'ajouter.
##
## **Il écrit deux noms de carte, et c'est un changement de doctrine qu'il faut dire.**
## `DESIGN.md` 4.2 affirmait depuis `D2` qu'`ActionTargeting` était « le seul endroit du
## projet où un identifiant de carte est écrit en dur ». La phrase protégeait quelque
## chose de précis — que le résolveur d'Économie ne nomme personne —, et cela tient
## toujours. Mais **où** un verbe se pose et **ce qu'il fait** sont deux questions, et la
## seconde ne se lit pas dans `data/` : 4.2 pose elle-même qu'« une *nature* d'action est
## du code de `src/domain/` ». La garantie « un seul fichier » est donc remplacée par une
## plus forte et vérifiée par un cas de test : **tout verbe que le ciblage accepte est soit
## productif selon `ActionBalance`, soit exécuté ici**. Aucun ne peut tomber dans le vide.
##
## Ce qu'il ne fait pas : re-valider. Le sens d'un terrassement et la capacité d'un
## chantier ont été figés à la pose, et les relire ici rouvrirait la porte à ce que l'écran
## promette un cran que le soir ne pose pas.

## *Construire* : avance un chantier.
const CARD_BUILD := &"build"

## *Terraformer* : déplace une case d'un cran, dans le sens choisi à la pose.
const CARD_TERRAFORM := &"terraform"

## Les verbes que ce fichier exécute.
##
## Fermé comme `ActionTargeting.CARDS`, et confronté à lui par un cas de test. Un
## cinquième verbe qui ne serait ni productif ni listé ici se poserait, s'affecterait, et
## ne ferait rien — exactement la panne silencieuse que `D2` a rencontrée en laissant ces
## deux-là sans exécution.
const CARDS: Array[StringName] = [CARD_BUILD, CARD_TERRAFORM]

## Ce fichier exécute-t-il ce verbe ?
static func handles(card: StringName) -> bool:
	return CARDS.has(card)

## Résout les chantiers d'un soir : qui a bâti quoi, et de combien.
##
## Les postes se remplissent dans l'ordre de l'affectation et jusqu'à la capacité de
## l'action, exactement comme un poste de production — c'est la même règle, écrite deux
## fois faute d'un endroit qui appartienne aux deux systèmes.
static func resolve(city: CitySnapshot, plan: ActionPlan, assign: Assignment,
		labor: LaborForce, actions: ActionBalance) -> SiteReport:
	assert(city != null, "résolution de chantier sans ville")
	assert(plan != null, "résolution de chantier sans plan d'actions")
	assert(assign != null, "résolution de chantier sans affectation")
	assert(labor != null, "résolution de chantier sans main-d'œuvre")
	assert(actions != null, "résolution de chantier sans équilibrage")
	assert(not actions.site_skill_family.is_empty(),
		"piste des chantiers non renseignée dans data/balance/")

	var advances: Dictionary[Vector2i, int] = {}
	var shifts: Dictionary[Vector2i, int] = {}
	var work: Array[WorkLine] = []
	for action in plan.actions():
		if not handles(action.card()):
			continue
		var manned := _manned(action, assign, labor)
		if manned.is_empty():
			continue
		for worker in manned:
			work.append(WorkLine.create(worker, action.target(),
				actions.site_skill_family))
		var steps := _steps(action, manned, labor, actions)
		if steps <= 0:
			continue
		if action.card() == CARD_TERRAFORM:
			shifts[action.target()] = steps * action.direction()
		else:
			advances[action.target()] = steps
	return SiteReport.create(advances, shifts, work)

## Crans que cette équipe pose ce soir.
##
## Même arithmétique que la production, et c'est le point : on somme les multiplicateurs
## des ouvriers, on tronque vers le bas, on plafonne à ce que l'action accepte. Deux
## ouvriers chevronnés posent trois crans là où deux bleus en posent deux, ce qui est la
## seule chose qui fasse de la piste Construction un métier plutôt qu'un compteur.
##
## Le plafond est celui que l'action porte, figé à la pose — pour un chantier, ce qu'il
## lui restait à bâtir. Un chantier ne peut donc jamais dépasser son dernier cran, quel
## que soit le talent envoyé dessus.
##
## *Terraformer* traverse la même formule et n'en sort qu'un cran, sa capacité valant 1
## dans `data/balance/`. Ce n'est pas un cas particulier écrit ici : le jour où une case
## nue acceptera deux ouvriers, elle se creusera de deux crans sans qu'une ligne bouge.
##
## Un total tronqué à zéro laisse quand même ses lignes de travail : l'ouvrier a tenu le
## poste et mérite son XP, il a juste mal travaillé. C'est la règle du résolveur de
## production, mot pour mot.
static func _steps(action: PlayedAction, manned: Array[StringName], labor: LaborForce,
		actions: ActionBalance) -> int:
	var power := 0.0
	for worker in manned:
		power += labor.efficiency(worker, actions.site_skill_family)
	return mini(floori(power), action.capacity())

## Les ouvriers qui tiennent effectivement un poste de cette action, dans l'ordre
## d'affectation et jusqu'à sa capacité.
##
## Jumeau exact de `ProductionResolver._manned()`, recopié plutôt que partagé. Le mettre
## en commun demanderait un endroit qui appartienne à l'Économie et au Cycle de jour à la
## fois : `contracts/` porte des DTO et non de la logique, et `Assignment` déclare en
## toutes lettres ne rien savoir des actions posées. Huit lignes recopiées coûtent moins
## qu'une dépendance inventée entre deux systèmes — même arbitrage que les cinq boucles de
## complétude de `GameDatabase`.
static func _manned(action: PlayedAction, assign: Assignment,
		labor: LaborForce) -> Array[StringName]:
	var held: Array[StringName] = []
	for worker in assign.workers_on(action.id()):
		if held.size() >= action.capacity():
			break
		if not labor.has(worker):
			continue
		held.append(worker)
	return held
