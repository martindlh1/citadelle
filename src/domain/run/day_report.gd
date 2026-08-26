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
## Il ne porte qu'un membre aujourd'hui, et c'est voulu : les trois autres arrivent avec
## leurs systèmes. L'**événement** de 3.7 et le **combat** de `F1` entreront ici, chacun par
## un champ, sans que la forme de la journée ait à bouger. C'est la place que la séquence
## leur garde depuis le premier jour.
##
## Immuable.

## Jour qui vient de se fermer.
var _day: int

## Ce que le roster a coûté à nourrir.
var _upkeep: UpkeepReport

## Rapport d'une journée. Appelé une seule fois, à la fin de sa dernière phase.
static func create(day: int, upkeep: UpkeepReport) -> DayReport:
	assert(day > 0, "rapport de journée sans jour : %d" % day)
	assert(upkeep != null, "rapport de journée sans upkeep")
	var report := DayReport.new()
	report._day = day
	report._upkeep = upkeep
	return report

## Jour qui s'est fermé.
func day() -> int:
	return _day

## Ce que le roster a coûté à nourrir.
func upkeep() -> UpkeepReport:
	return _upkeep
