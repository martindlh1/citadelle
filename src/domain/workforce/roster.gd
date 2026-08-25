class_name Roster
extends RefCounted
## Le vivier : tous les ouvriers du run, présents ou non.
##
## État interne des Effectifs, comme CityState l'est de Construction et le Ledger de
## l'Économie. Il est le **seul propriétaire** des Worker, et c'est ce qui fait tenir le
## vivier unique de DESIGN.md 3.4 : rien hors de domain/workforce/ ne voit un ouvrier,
## seulement des projections. La LaborForce en est une ; la CombatForce en sera une
## seconde à F1, tirée de la même liste sans que le Combat puisse le deviner.
##
## Il ne connaît pas la ville. Le plafond de places en dépend — les habitations le
## relèvent —, d'où capacity_for(), statique et pure, qui prend la ville en argument.
## Le roster, lui, ne refuse jamais personne : c'est la couche qui orchestre la journée
## qui pose les deux questions à la suite, exactement comme elle enchaîne « payable » et
## « posable » pour un bâtiment. Voir DESIGN.md 3.2.

## Ouvriers, dans l'ordre où ils sont entrés au roster.
var _workers: Array[Worker] = []

## Identifiant -> ouvrier.
var _by_id: Dictionary[StringName, Worker] = {}

## Vivier composé de ces ouvriers, dans cet ordre.
static func create(workers: Array[Worker]) -> Roster:
	var roster := Roster.new()
	for worker in workers:
		roster.add(worker)
	return roster

## Vivier vide. Un run qui perd son dernier ouvrier est une défaite — DESIGN.md 5.
static func empty() -> Roster:
	var none: Array[Worker] = []
	return Roster.create(none)

## Places disponibles pour cette ville : la base, plus ce que les habitations ajoutent.
##
## Miroir exact de ProductionResolver.capacity_for(), et publique pour la même raison :
## la fiche de W2 doit afficher « 10 / 12 » sans rien résoudre.
##
## Ce qui **remplit** ces places n'existe pas — DESIGN.md 3.4 garde le recrutement sous
## un OUVERT. Le plafond, lui, est réel dès aujourd'hui : il dit si le vivier peut
## grandir, ce qui est la question à laquelle une carte de recrutement viendra répondre.
static func capacity_for(city: CitySnapshot, balance: WorkforceBalance) -> int:
	assert(city != null, "capacité de roster demandée sans ville")
	assert(balance != null, "capacité de roster demandée sans équilibrage")
	var places := balance.base_roster_places
	for building in city.buildings():
		places += building.data().roster_places
	return places

## Effectif total, absents compris. Ce n'est **pas** ce que l'upkeep multiplie : la
## LaborForce ne porte que les présents, et c'est elle qui mange.
func size() -> int:
	return _workers.size()

## Effectif disponible ce soir.
func present_count() -> int:
	var here := 0
	for worker in _workers:
		if worker.is_present():
			here += 1
	return here

## Cet ouvrier est-il au roster ?
func has(id: StringName) -> bool:
	return _by_id.has(id)

## Ouvrier nommé. Précondition : has(id).
func worker(id: StringName) -> Worker:
	assert(has(id), "ouvrier inconnu du roster : %s" % id)
	return _by_id[id]

## Tous les ouvriers, dans l'ordre d'entrée. Copie du tableau : les Worker eux-mêmes
## sortent tels quels, puisque c'est ce système qui les fait vivre.
func workers() -> Array[Worker]:
	return _workers.duplicate()

## Les seuls ouvriers disponibles, dans l'ordre d'entrée.
func present() -> Array[Worker]:
	var here: Array[Worker] = []
	for worker in _workers:
		if worker.is_present():
			here.append(worker)
	return here

## Fait entrer un ouvrier. Le plafond de places n'est pas consulté ici : voir le
## docstring de la classe.
func add(worker: Worker) -> void:
	assert(worker != null, "ouvrier nul au roster")
	assert(not _by_id.has(worker.id()), "deux ouvriers nommés %s" % worker.id())
	_workers.append(worker)
	_by_id[worker.id()] = worker

## Retire un ouvrier — un mort, un départ. Rend faux s'il n'y était pas.
##
## Une affectation qui le nommait lui survit : c'est un état normal que le résolveur de
## production tranche déjà en l'ignorant sans un mot, et que celui d'XP tranche de la
## même façon. Rien n'a à parcourir les affectations pour en purger un disparu.
func remove(id: StringName) -> bool:
	if not _by_id.has(id):
		return false
	_workers.erase(_by_id[id])
	_by_id.erase(id)
	return true

## La main-d'œuvre que l'Économie consomme : **les présents seulement**.
##
## C'est ici que la contrainte de DESIGN.md 3.9 se paie, et c'est la seule ligne qui la
## porte. Conséquence assumée et tranchée à W1 : un absent ne compte pas dans
## LaborForce.size(), donc **il ne mange pas**. L'inverser demanderait de distinguer sur
## ce contrat « qui peut travailler » de « qui mange », ce qui est un champ de plus sur
## une frontière inter-systèmes.
func to_labor(balance: WorkforceBalance) -> LaborForce:
	assert(balance != null, "projection sans équilibrage")
	var units: Array[LaborUnit] = []
	for worker in present():
		units.append(worker.to_labor_unit(balance))
	return LaborForce.create(units)
