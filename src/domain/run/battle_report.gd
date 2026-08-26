class_name BattleReport
extends RefCounted
## Le compte rendu d'une vague : ce qu'elle a ordonné, et ce que l'appliquer a **vraiment**
## coûté.
##
## Même rôle que `PhaseReport` pour une phase, et il existe pour la même raison : il agrège
## sans recopier, chaque système restant le seul auteur de ce qu'il dit. Le `DamageReport`
## est le verdict du Combat ; le reste est ce que les autres systèmes en ont fait.
##
## Deux choses n'existent en effet qu'à l'application, et aucune ne se déduit du verdict.
## Le **pillage** est un ordre — « emporte sept unités » — et une réserve à moitié vide en
## donnera moins : ce qui a réellement disparu est ce que le `Ledger` rend, avec sa règle de
## prorata que le Combat n'a pas le droit de connaître. La **progression** vient des
## Effectifs, sur le journal de la ligne, et elle sait qui a franchi un palier en défendant.
##
## Il vit dans `domain/run/` et non dans `contracts/`, comme `SiteReport` et `PhaseReport` :
## aucun second système du domaine ne le franchit — il va du Cycle de jour aux adapters —,
## et 3.8 pose que ce système-ci est justement celui qui a le droit de connaître tous les
## autres. Le `DamageReport` qu'il porte, lui, est bien un contrat : trois systèmes le
## lisent.
##
## `DayReport` ne le porte pas encore. La place lui est gardée depuis `I1` — « l'événement
## de 3.7 et le combat de `F1` entreront ici, chacun par un champ » —, mais rien ne fait
## encore tomber une vague à la fin d'une journée : la fréquence des vagues est l'`OUVERT`
## de 2, et c'est `I2` qui la datera. Un champ que personne ne remplit serait la frontière
## que ce projet refuse depuis `E1`.
##
## Immuable.

## Ce que la vague a ordonné.
var _damage: DamageReport

## Ce que la réserve a réellement perdu, par ressource.
var _plundered: Dictionary[StringName, int] = {}

## Ce que la ligne a valu à ceux qui l'ont tenue.
var _progress: ProgressReport

## Rapport d'une vague. Appelé une seule fois, en fin d'application.
static func create(damage: DamageReport, plundered: Dictionary[StringName, int],
		progress: ProgressReport) -> BattleReport:
	assert(damage != null, "rapport de bataille sans dégâts")
	assert(progress != null, "rapport de bataille sans progression")
	var report := BattleReport.new()
	report._damage = damage
	report._plundered = plundered.duplicate()
	report._progress = progress
	return report

## Ce que la vague a ordonné.
func damage() -> DamageReport:
	return _damage

## Ce que la réserve a réellement perdu. Copie.
##
## Inférieur à `damage().plunder()` quand la réserve était trop maigre pour payer. C'est le
## seul endroit qui connaisse l'écart, et il vaut d'être lisible : « ils ont tout pris » et
## « ils sont repartis les mains vides » sont deux fins de vague différentes.
func plundered() -> Dictionary[StringName, int]:
	return _plundered.duplicate()

## Total réellement pillé, toutes ressources confondues.
func total_plundered() -> int:
	var stolen := 0
	for resource in _plundered:
		stolen += _plundered[resource]
	return stolen

## Ce que les Effectifs ont distribué à ceux qui ont tenu la ligne.
##
## Elle ne nomme pas les morts : l'XP est créditée **après** que le roster les a perdus, et
## `SkillResolver` saute un ouvrier qu'il ne connaît plus — « un mort ne progresse pas »,
## dit son docstring depuis `W1`. C'est une phrase déjà écrite qui se trouve vraie, pas une
## règle ajoutée ici.
func progress() -> ProgressReport:
	return _progress

## La vague a-t-elle été contenue sans rien coûter ?
func is_held() -> bool:
	return _damage.is_held()
