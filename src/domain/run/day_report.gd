class_name DayReport
extends RefCounted
## Ce qu'une journée entière a coûté, une fois sa dernière phase passée.
##
## Une journée compte **deux sortes de résolution**, et c'est le sujet de ce fichier. Une
## **phase** produit : ce que les actions posées rapportent, ce que les chantiers avancent,
## l'XP que ça vaut. Une **journée** coûte : on mange une fois par jour, quel que soit le
## nombre de fois qu'on a récolté.
##
## Sans cette séparation, jouer deux phases par jour ferait manger deux fois — et rendrait
## la structure de la journée inséparable de son équilibrage, alors que `DESIGN.md` 2 veut
## précisément pouvoir échanger l'une sans toucher à l'autre. La séquence de 2 les listait
## d'ailleurs déjà comme des étapes distinctes : « actions jouées → **événement** →
## **upkeep** → **combat** → gain d'XP → rapport ».
##
## Il portait un seul membre jusqu'à `I2`, la place étant gardée « pour l'événement de 3.7
## et le combat de `F1` ». Le combat l'a prise, et sous la forme que 3.8 avait écrite
## d'avance : **la vague en attente**, jamais un rapport de bataille. Un combat tactique
## attend le joueur pendant des dizaines de tours, donc ce qu'il aura coûté ne peut pas
## revenir dans le rapport qui l'annonce — « ce que la bataille a coûté revient par la
## seconde porte », et cette porte est `RunOrchestrator.fight()`.
##
## Reste l'**événement** de 3.7, qui entrera par un champ de plus sans que rien ne bouge.
##
## Immuable.

## Jour qui vient de se fermer.
var _day: int

## Ce que le roster a coûté à nourrir.
var _upkeep: UpkeepReport

## La vague que le calendrier fait tomber ce soir, ou null si la journée est paisible.
var _wave: WaveDef = null

## Rapport d'une journée. Appelé une seule fois, à la fin de sa dernière phase.
static func create(day: int, upkeep: UpkeepReport, wave: WaveDef = null) -> DayReport:
	assert(day > 0, "rapport de journée sans jour : %d" % day)
	assert(upkeep != null, "rapport de journée sans upkeep")
	var report := DayReport.new()
	report._day = day
	report._upkeep = upkeep
	report._wave = wave
	return report

## Jour qui s'est fermé.
func day() -> int:
	return _day

## Ce que le roster a coûté à nourrir.
func upkeep() -> UpkeepReport:
	return _upkeep

## La vague qui attend, ou null si la journée s'est fermée sans combat.
##
## Elle est **en attente** et non résolue : la journée ne s'achève pas tant qu'elle n'est
## pas tombée, et le cycle refuse d'avancer d'ici là. C'est ce que `DESIGN.md` 3.8 réclame
## depuis la discussion qui a suivi `F1`, écrit avant d'en avoir besoin.
func wave() -> WaveDef:
	return _wave

## La journée attend-elle une bataille ?
##
## Une question plutôt qu'un `wave() != null` recopié partout, même geste que
## `DamageReport.is_held()` : c'est la phrase que l'écran dira, et le jour où une journée
## pourra attendre autre chose qu'une vague, elle se redéfinira ici.
func awaits_a_battle() -> bool:
	return _wave != null
