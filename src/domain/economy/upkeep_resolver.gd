class_name UpkeepResolver
extends RefCounted
## Le repas d'un tour : ce que le village mange, et qui arrive ou s'en va ensuite.
##
## DESIGN.md 3.4 — « tout le monde mange, une nourriture par tête, immobilisés compris ;
## la population croît d'un cran s'il reste de la nourriture après le repas *et* qu'il reste
## une place de logement ; elle décroît d'un cran si la réserve n'a pas couvert le repas ».
##
## ---
##
## **Il mute et il rapporte**, ce qui le distingue d'une fonction pure et mérite d'être dit :
## il prélève sur le Ledger et déplace le compteur de Population, puis rend le récit de ce
## qu'il vient de faire. C'est légitime parce que les deux états qu'il touche appartiennent
## au **même système** — l'Économie possède la réserve et la population. Un résolveur qui
## voudrait toucher la ville devrait, lui, se contenter d'ordonner.
##
## **L'ordre des trois temps est imposé, et il n'est pas commutatif.** On mange d'abord, on
## constate ensuite. Faire venir quelqu'un avant le repas le ferait manger le tour de son
## arrivée ; le faire partir avant lui ferait rendre une ration qu'il a déjà consommée.
##
## **Un tour ne fait jamais venir et partir à la fois.** Ce n'est pas une garde défensive
## mais une conséquence : la croissance demande un reliquat de nourriture, la décroissance
## demande un manque, et les deux ne peuvent pas être vrais du même repas. L'assertion de
## UpkeepReport.create() le tient par écrit, de sorte qu'un changement de règle qui casserait
## cette exclusivité se signale au lieu de produire un rapport contradictoire.

## Fait manger le village, puis en tire la conséquence sur l'effectif.
##
## `upkeep_resource`, `upkeep_per_inhabitant` et le reste viennent de l'équilibrage : aucun
## identifiant de ressource ni aucun chiffre n'est écrit ici, ce que les conventions
## interdisent dans src/domain/.
##
## **La croissance ne demande qu'un reliquat**, si petit soit-il. C'est la règle la plus
## simple qui satisfait DESIGN.md 3.4, et c'est délibérément ici que se posera le premier
## bouton d'équilibrage de la population — un seuil de reliquat, ou un coût par naissance —
## le jour où un run entier montrera que le village grossit trop vite. Le frein voulu est
## spatial, donc on ne lui en ajoute pas un second avant d'avoir vu le premier travailler.
static func resolve(people: Population, ledger: Ledger,
		balance: EconomyBalance) -> UpkeepReport:
	assert(people != null, "repas sans population")
	assert(ledger != null, "repas sans réserve")
	assert(balance != null, "repas sans équilibrage")

	var due := people.headcount() * balance.upkeep_per_inhabitant
	var paid := ledger.take(balance.upkeep_resource, due)
	var unfed := _unfed(due - paid, balance.upkeep_per_inhabitant)

	var arrived := 0
	var lost := 0
	if paid < due:
		lost = people.shrink()
	elif ledger.amount(balance.upkeep_resource) > 0:
		arrived = people.grow()

	return UpkeepReport.create(due, paid, unfed, arrived, lost)

## Combien d'habitants ce manque laisse sur leur faim.
##
## Le manque est en **nourriture** et le compte en **personnes** : il faut donc arrondir au
## supérieur, sans quoi un manque plus petit qu'une ration se lirait comme « tout le monde a
## mangé » alors que quelqu'un n'a rien eu.
##
## Une ration nulle est impossible — GameDatabase refuse un upkeep_per_inhabitant à zéro —,
## mais la division est gardée quand même : ce fichier ne doit pas dépendre d'un contrôle
## qui vit ailleurs pour ne pas diviser par zéro.
static func _unfed(shortfall: int, per_head: int) -> int:
	if shortfall <= 0 or per_head <= 0:
		return 0
	return ceili(float(shortfall) / float(per_head))
