class_name RunBalance
extends Resource
## Réglages du run : la forme d'une journée, et combien il y en a.
##
## Huitième bloc de `BalanceData`, et le seul qui décide d'un **moment**. `D1` avait
## laissé cette question dehors en toutes lettres : « Le Deck offre les gestes, la journée
## choisit quand les faire — donc I1. » La voici, et elle est en data pour que les deux
## modèles de `DESIGN.md` 2 restent deux `.tres` et non deux versions du code.
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

## Phases qui résolvent, dans l'ordre.
func resolving_phases() -> Array[PhaseDef]:
	var resolving: Array[PhaseDef] = []
	for phase in phases:
		if phase != null and phase.resolves:
			resolving.append(phase)
	return resolving

## Champs non renseignés ou incohérents. Vide = bloc exploitable.
##
## Le contrôle qui compte est celui de la phase résolvante. Un `resolves` est un booléen,
## donc le seul champ que la doctrine du zéro ne protège pas : effacé, il vaut faux sans
## que rien ne le dise. Exiger qu'au moins une phase de la journée résolve rattrape la
## disparition du format entier, ce qu'un contrôle champ par champ ne pourrait pas faire.
## Une journée qui ne résout jamais produirait un run entier sans une seule récolte.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if days <= 0:
		missing.append("days")
	missing.append_array(_phase_fields())
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
