class_name RunBalance
extends Resource
## Réglages du run : la forme d'une journée, combien il y en a, quand on se bat, et ce
## qu'un run vaut à la fin.
##
## Huitième bloc de `BalanceData`, et le seul qui décide d'un **moment**. `D1` avait
## laissé cette question dehors en toutes lettres : « Le Deck offre les gestes, la journée
## choisit quand les faire — donc I1. » La voici, et elle est en data pour que les deux
## modèles de `DESIGN.md` 2 restent deux `.tres` et non deux versions du code.
##
## `I2` lui donne les deux bouts qui manquaient à un run pour en être un. Le **calendrier**
## des vagues, que `DESIGN.md` 8 lui destinait nommément — il est ici et non dans
## `CombatBalance`, qui s'en défausse en toutes lettres, parce que le seul contrôle qui
## compte le croise avec `days` : un jour au-delà de la durée du run est une vague que
## personne ne verra tomber, et seul le bloc qui tient cette durée peut le dire. Et les
## quatre poids du **score** de `DESIGN.md` 5, pour la raison la plus simple : ce sont des
## chiffres, et aucun chiffre ne s'écrit dans un `.gd`.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Les phases d'une journée, dans l'ordre où elles se jouent.
##
## Le fichier de data fait foi sur l'ordre comme sur le nombre : deux phases symétriques,
## deux asymétriques, ou trois, sans qu'une ligne de GDScript ne bouge. `I2b` tranchera
## l'`OUVERT` de 2 en échangeant ce tableau.
@export var phases: Array[PhaseDef]

## Journées d'un run avant la vague finale.
##
## `DESIGN.md` 2 garde la durée d'un run sous un `OUVERT`, et `data/balance/` est
## précisément l'endroit où l'on itère sur une question encore ouverte.
@export_range(1, 100, 1) var days: int

## Bâtiment posé au centre de la carte à l'ouverture d'un run.
##
## `DESIGN.md` 2 en fait une étape à part entière — « génération de carte → pose du Cœur →
## suite de journées ». Il est ici plutôt qu'écrit en dur dans `src/domain/run/` pour la
## raison la plus simple : `&"heart"` dans un `.gd` serait un identifiant de contenu dans
## du code, ce que les conventions refusent partout ailleurs.
##
## Vide est une réponse et non un oubli — c'est le run d'un harnais qui veut une carte
## nue. Le champ n'est donc pas contrôlé par `missing_fields()`, à l'inverse de tous les
## autres ; l'existence du bâtiment nommé l'est en revanche à l'ouverture du run.
@export var starting_building: StringName

## Les vagues du run, et le jour où chacune tombe.
##
## L'`OUVERT` de `DESIGN.md` 2 sur la **fréquence des vagues** vit ici, donc se tourne en
## éditant un `.tres` — ce qui est tout ce qu'on lui demande jusqu'à `I3`.
##
## **Vide est une réponse et non un oubli**, comme pour `starting_building` : c'est le run
## paisible d'un harnais qui veut mesurer une économie sans qu'on lui casse ses murs. Un
## calendrier n'est donc pas réclamé ; c'est sa cohérence qui l'est.
@export var waves: Array[WaveSlot]

## Points de score par unité restée en réserve.
##
## Les quatre champs qui suivent sont les quatre termes que `DESIGN.md` 5 énumère —
## « ressources, bâtiments intacts, ouvriers vivants et leur niveau ». Ils échappent à la
## doctrine du zéro pour la même raison que `plunder_per_breach` : un poids nul est un
## choix d'équilibrage lisible — « la thésaurisation ne vaut pas de points » — et le
## réclamer interdirait de l'essayer sans toucher au GDScript.
##
## Le filet est posé un cran plus haut, comme pour `resolves` : **au moins un des quatre
## doit compter**. Un poids effacé reste invisible, la disparition du barème entier ne
## l'est pas.
@export_range(0, 100, 1) var score_per_resource: int

## Points de score par bâtiment **achevé** encore debout à la fin du run.
##
## Achevé et non posé, par la règle qui vaut depuis `C4` : un chantier n'est pas un
## bâtiment, et `CitySnapshot.completed()` répond déjà exactement cette question à trois
## autres consommateurs. Un chantier laissé en plan à la dernière journée n'est pas un
## bâtiment intact.
@export_range(0, 100, 1) var score_per_building: int

## Points de score par ouvrier encore vivant.
@export_range(0, 100, 1) var score_per_worker: int

## Points de score par niveau d'ouvrier cumulé sur tout le roster.
##
## Le **niveau** de `DESIGN.md` 3.4 — « ce qu'il a vécu » —, et non les pistes : c'est le
## compteur qui agrège toute l'XP quelle qu'en soit la source, donc le seul qui dise d'un
## roster ce qu'il a traversé sans qu'on ait à additionner quatre métiers.
@export_range(0, 100, 1) var score_per_worker_level: int

## Phases qui résolvent, dans l'ordre.
func resolving_phases() -> Array[PhaseDef]:
	var resolving: Array[PhaseDef] = []
	for phase in phases:
		if phase != null and phase.resolves:
			resolving.append(phase)
	return resolving

## La vague qui tombe ce jour-là, ou null si la journée est paisible.
##
## Un jour porte **au plus une** vague, et `missing_fields()` le tient : deux créneaux le
## même jour rendraient la seconde vague inatteignable, puisqu'une seule peut attendre à la
## fois. Le premier créneau trouvé fait donc foi, et le second est signalé en data plutôt
## que silencieusement perdu ici.
func wave_on(day: int) -> WaveDef:
	for slot in waves:
		if slot != null and slot.day == day:
			return slot.wave
	return null

## Le prochain créneau à partir de ce jour, celui-ci compris, ou null si plus rien ne vient.
##
## Il existe pour une raison de design et non de confort. `DESIGN.md` 3.6 veut qu'on
## « pense à la bataille en posant un bâtiment », et en tire que la direction d'une vague
## s'annonce à l'avance : « une direction révélée le soir même transformerait cette
## prévoyance en loterie ». **La date se tient par le même argument** — un joueur qui
## ignore qu'un siège tombe dans deux journées ne peut pas bâtir en le prévoyant, et la
## prévoyance que 3.2 réclame n'existe pas.
##
## Le balayage prend le plus petit jour plutôt que le premier trouvé : le tableau est une
## liste d'édition, et rien dans `data/` n'oblige à l'écrire dans l'ordre. Exiger un tri
## serait un contrôle de plus dans `missing_fields()` pour une contrainte que personne
## n'a de raison de subir.
func next_slot_from(day: int) -> WaveSlot:
	var soonest: WaveSlot = null
	for slot in waves:
		if slot == null or slot.day < day:
			continue
		if soonest == null or slot.day < soonest.day:
			soonest = slot
	return soonest

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## Le contrôle qui compte est celui de la phase résolvante. Un `resolves` est un booléen,
## donc le seul champ que la doctrine du zéro ne protège pas : effacé, il vaut faux sans
## que rien ne le dise. Exiger qu'au moins une phase de la journée résolve rattrape la
## disparition du format entier, ce qu'un contrôle champ par champ ne pourrait pas faire.
## Une journée qui ne résout jamais produirait un run entier sans une seule récolte.
##
## Le barème de score est tenu par le même geste, et `I2` l'a écrit en le recopiant
## sciemment : quatre poids nuls sont un run qui vaut zéro quoi qu'on y fasse, ce qui est
## la disparition d'un format et non un réglage.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if days <= 0:
		missing.append("days")
	missing.append_array(_phase_fields())
	missing.append_array(_wave_fields())
	if score_per_resource <= 0 and score_per_building <= 0 and score_per_worker <= 0 \
			and score_per_worker_level <= 0:
		missing.append("score.none_counts")
	return missing

## Incohérences de la liste des phases.
func _phase_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if phases.is_empty():
		missing.append("phases")
		return missing
	var seen: Dictionary[StringName, bool] = {}
	for index in phases.size():
		var phase := phases[index]
		if phase == null:
			missing.append("phases.%d" % index)
			continue
		for field in phase.missing_fields():
			missing.append("phases.%d.%s" % [index, field])
		if seen.has(phase.id):
			missing.append("phases.%d.id.duplicate" % index)
		seen[phase.id] = true
	if resolving_phases().is_empty():
		missing.append("phases.none_resolves")
	return missing

## Incohérences du calendrier des vagues.
##
## Un calendrier vide n'en est pas une — voir `waves`. Ce qui l'est : un créneau nul, une
## vague absente ou mal remplie, un jour au-delà de la dernière journée du run, et deux
## créneaux le même jour.
##
## Les deux derniers contrôles n'existent que parce que ce bloc voit à la fois le
## calendrier et la durée, ce qu'aucun `WaveSlot` ne peut faire seul — le même partage
## qu'entre `PhaseDef` et l'unicité de son identifiant.
func _wave_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	var seen: Dictionary[int, bool] = {}
	for index in waves.size():
		var slot := waves[index]
		if slot == null:
			missing.append("waves.%d" % index)
			continue
		for field in slot.missing_fields():
			missing.append("waves.%d.%s" % [index, field])
		if slot.day > days:
			missing.append("waves.%d.day.beyond_the_run" % index)
		if seen.has(slot.day):
			missing.append("waves.%d.day.duplicate" % index)
		seen[slot.day] = true
	return missing
