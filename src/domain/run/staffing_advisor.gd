class_name StaffingAdvisor
extends RefCounted
## Qui envoyer où : le classement des ouvriers sur les actions posées, et le plan que le
## bouton d'auto-affectation applique.
##
## `DESIGN.md` 3.4 pose le risque que ce fichier existe pour réduire : « des effectifs à
## quinze, sur deux phases, pendant quinze jours, c'est plusieurs centaines de décisions
## par run dont la plupart sont évidentes ». Le bouton retire les évidentes ; il ne
## retire pas la décision de fond, qui est *qui* l'on envoie et que le joueur garde
## entière en surchargeant à la main.
##
## **Il est dans le domaine, et 3.4 disait le contraire.** La phrase « c'est du travail
## d'adapter, pas de domaine » vaut pour les deux autres mitigations qu'elle liste — des
## effectifs réduits et une affectation persistante sont bien de la présentation. Classer
## des ouvriers, non : il faut la famille que chaque action posée créditera, les
## multiplicateurs de la `LaborForce`, et la capacité figée à la pose. L'écrire dans une
## vue obligerait à y recopier `ProductionResolver.family_of()`, que ce fichier-là
## documente comme « posée ici et nulle part ailleurs ». Et `CLAUDE.md` promet qu'un seed
## plus une suite de gestes rejoue un run à l'identique : un geste dont le résultat n'est
## pas testable ne peut pas tenir cette promesse, et `src/adapters/` n'est pas testé.
## *(Tranché à `W2`, 3.4 corrigé dans le même commit.)*
##
## **Il est dans `domain/run/`** parce qu'il interroge deux systèmes — l'Économie pour la
## famille d'un poste de production, les chantiers pour celle de *Construire* et de
## *Terraformer*. C'est exactement ce que `DESIGN.md` 3.8 autorise pour ce dossier et
## nulle part ailleurs.
##
## **Il ordonne, il ne mute rien.** Même partage que `SiteResolver` et `RunOrchestrator` :
## `plan()` rend qui irait où, l'orchestrateur applique en repassant par `staff()`. Le
## bénéfice est le même qu'à `I1` — un plan est rejouable, et il se teste sans run.
##
## Statique et sans état, comme tous les résolveurs.

## Famille de compétence que cette action créditera, ou &"" si elle ne crédite personne.
##
## La seule question que l'écran et le bouton ont besoin de poser, et elle n'a pas de
## réponse unique : les deux résolveurs d'un soir créditent chacun la leur. La production
## lit le bloc du bâtiment ou `bare_skill_family` selon la lecture de `DESIGN.md` 3.5 ;
## les chantiers lisent `site_skill_family`, la quatrième famille que `I1` a ouverte.
##
## L'ordre des deux questions n'est pas indifférent, et un cas de test le tient :
## `ProductionResolver` d'abord, parce que c'est lui qui refuse *Construire* posé sur un
## bâtiment qui produit. Inverser laisserait un chantier crédité en Récolte.
##
## Aucun nom de carte n'est écrit ici. Les deux fichiers interrogés en portent, et c'est
## leur affaire : `DESIGN.md` 4.2 garantit depuis `I1` que **tout verbe que le ciblage
## accepte est soit productif selon `data/balance/`, soit exécuté par le résolveur de
## chantiers**. Cette fonction est donc totale sur les verbes réels, et le &"" ne sert
## qu'aux actions devenues creuses — un poste dont le bâtiment a disparu, ce que le
## `DamageReport` de `F1` rendra possible.
static func family_of(action: PlayedAction, terrain: TerrainQuery, city: CitySnapshot,
		balance: ActionBalance) -> StringName:
	assert(action != null, "famille demandée sans action")
	assert(balance != null, "famille demandée sans équilibrage")
	var produced := ProductionResolver.family_of(action, terrain, city, balance)
	if not produced.is_empty():
		return produced
	if SiteResolver.handles(action.card()):
		return balance.site_skill_family
	return &""

## Postes que cette action a encore à offrir.
##
## Le compte est **brut**, exactement celui que `RunOrchestrator.staffing_refusal()`
## oppose : `assign.workers_on().size()` contre la capacité, sans écarter un ouvrier que
## la main-d'œuvre ne connaîtrait plus. C'est ce qui garantit qu'aucune paire proposée
## par `plan()` ne peut se faire refuser à l'application — et cette garantie vaut mieux
## qu'un compte plus fin, parce qu'un plan à moitié appliqué serait invisible à l'écran.
static func room_on(action: PlayedAction, assign: Assignment) -> int:
	assert(action != null, "postes demandés sans action")
	assert(assign != null, "postes demandés sans affectation")
	return maxi(action.capacity() - assign.workers_on(action.id()).size(), 0)

## Ces ouvriers, classés du meilleur au moins bon pour cette famille. Copie.
##
## C'est le classement que la fiche montre et que le bouton suit. À efficacité égale,
## c'est **l'ordre reçu** qui départage, et l'appelant le donne dans l'ordre du roster :
## deux bleus sont interchangeables, mais deux runs partis du même seed doivent envoyer
## le même. Un tri qui laisserait le départage au hasard casserait le déterminisme sans
## qu'aucun test de production ne s'en aperçoive.
##
## Le rang reçu entre dans le comparateur plutôt que d'être laissé au tri : l'ordre est
## donc **total**, et le résultat ne dépend pas de la stabilité de `sort_custom`, que
## Godot ne garantit nulle part.
static func ranked_for(candidates: Array[StringName], labor: LaborForce,
		family: StringName) -> Array[StringName]:
	assert(labor != null, "classement sans main-d'œuvre")
	var rank: Dictionary[StringName, int] = {}
	for index in candidates.size():
		rank[candidates[index]] = index
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(first: StringName, second: StringName) -> bool:
		var left := labor.efficiency(first, family)
		var right := labor.efficiency(second, family)
		if not is_equal_approx(left, right):
			return left > right
		var ahead := labor.track_xp(first, family)
		var behind := labor.track_xp(second, family)
		if ahead != behind:
			return ahead > behind
		return rank[first] < rank[second])
	return sorted

## Qui envoyer où : ouvrier -> action posée, dans l'ordre de remplissage.
##
## La règle, et c'est du gameplay plutôt que de la technique *(tranchée à `W2`)* :
##
##   - on parcourt les actions **dans l'ordre de pose**, et on remplit les postes qui
##     restent avec le meilleur ouvrier libre pour la famille de cette action ;
##   - une action que rien ne crédite est **sautée** — y envoyer quelqu'un est exactement
##     l'erreur évidente que le bouton doit éviter, pas commettre ;
##   - un ouvrier **déjà affecté n'est jamais déplacé**. C'est ça, la « surcharge
##     manuelle » de 3.4 : on place à la main ceux dont on se soucie, le bouton fait le
##     reste.
##
## Ce que la règle refuse de faire, et il faut le dire parce que c'est le choix le plus
## discutable : elle **ne pondère pas par le rendement**. Une récolte à 3 bois et une
## case nue à 1 se valent devant elle. Pondérer demanderait de lire `_yield_of()`, et
## surtout rendrait un cran de chantier comparable à une récolte — ce qui est un
## arbitrage d'équilibrage, donc `I3`. Le bouton ne choisit donc jamais quelle action
## mérite un ouvrier : **l'ordre de pose est la priorité que le joueur a déjà exprimée**,
## et le bouton s'y tient. Il ne choisit que *qui*.
##
## La main-d'œuvre ne porte que les présents *(cf. `Roster.to_labor()`)*, donc un absent
## ne peut pas être planifié : la contrainte de 3.9 se paie une seule fois, en amont, et
## ce fichier n'a pas à la connaître.
static func plan(terrain: TerrainQuery, city: CitySnapshot, posted: ActionPlan,
		assign: Assignment, labor: LaborForce,
		balance: ActionBalance) -> Dictionary[StringName, int]:
	assert(posted != null, "plan d'affectation sans actions posées")
	assert(assign != null, "plan d'affectation sans affectation")
	assert(labor != null, "plan d'affectation sans main-d'œuvre")
	assert(balance != null, "plan d'affectation sans équilibrage")

	var free := _free(assign, labor)
	var orders: Dictionary[StringName, int] = {}
	if free.is_empty():
		return orders

	for action in posted.actions():
		var room := room_on(action, assign)
		if room <= 0:
			continue
		var family := family_of(action, terrain, city, balance)
		if family.is_empty():
			continue
		for worker in ranked_for(free, labor, family):
			if room <= 0:
				break
			orders[worker] = action.id()
			free.erase(worker)
			room -= 1
	return orders

## Les présents que rien n'occupe, dans l'ordre de la main-d'œuvre.
##
## Miroir de `RunState.free_workers()`, qui part du roster là où celui-ci part de la
## projection. Les deux rendent le même monde — `to_labor()` conserve l'ordre du roster —
## et c'est la projection qu'on lit ici, pour que ce fichier reste sur les contrats et
## n'ait jamais à voir un `Worker`.
static func _free(assign: Assignment, labor: LaborForce) -> Array[StringName]:
	var free: Array[StringName] = []
	for worker in labor.workers():
		if not assign.is_assigned(worker):
			free.append(worker)
	return free
