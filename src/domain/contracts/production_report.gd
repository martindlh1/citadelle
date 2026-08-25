class_name ProductionReport
extends RefCounted
## Ce qu'un soir a produit, stocké, perdu et mangé.
##
## Produit par l'Économie ; consommé par les Effectifs pour l'XP — via work() — et par
## les adapters pour l'affichage. Immuable.
##
## **Il rapporte, il ne punit pas.** La famine y est un compte d'ouvriers non nourris
## et rien d'autre : ce qu'il leur arrive appartient aux Effectifs, qui possèdent les
## unités, et DESIGN.md 3.3 garde la question ouverte. Un rapport qui trancherait ici
## fermerait ce choix sans que personne ne le décide.

var _produced: Dictionary[StringName, int] = {}
var _stored: Dictionary[StringName, int] = {}
var _work: Array[WorkLine] = []
var _idle: Array[StringName] = []
var _upkeep: int
var _consumed: int
var _unfed: int

## Rapport d'un soir. Appelé une seule fois, en fin de résolution.
##
## `produced` est la récolte brute et `stored` ce qui a franchi le plafond : les deux
## y figurent plutôt qu'un seul, parce que la différence est justement ce que la
## réserve commune fait perdre, et qu'un joueur qui ne la voit pas ne comprend pas
## pourquoi son entrepôt manque.
static func create(produced: Dictionary[StringName, int],
		stored: Dictionary[StringName, int], work: Array[WorkLine],
		idle: Array[StringName], upkeep: int, consumed: int,
		unfed: int) -> ProductionReport:
	assert(upkeep >= 0, "upkeep négatif : %d" % upkeep)
	assert(consumed >= 0, "consommation négative : %d" % consumed)
	assert(unfed >= 0, "compte de non-nourris négatif : %d" % unfed)
	var report := ProductionReport.new()
	report._produced = produced.duplicate()
	report._stored = stored.duplicate()
	report._work = work.duplicate()
	report._idle = idle.duplicate()
	report._upkeep = upkeep
	report._consumed = consumed
	report._unfed = unfed
	return report

## Récolte brute du soir, avant le plafond. Copie.
func produced() -> Dictionary[StringName, int]:
	return _produced.duplicate()

## Ce qui est réellement entré en réserve. Copie.
func stored() -> Dictionary[StringName, int]:
	return _stored.duplicate()

## Ce que le plafond a fait perdre, par ressource. Dérivé : produit moins stocké.
##
## Une ressource qui n'a rien perdu n'y figure pas, plutôt que d'y figurer à zéro : le
## dictionnaire se lit alors comme la liste de ce qui a débordé.
func wasted() -> Dictionary[StringName, int]:
	var lost: Dictionary[StringName, int] = {}
	for resource in _produced:
		var over: int = _produced[resource] - _stored.get(resource, 0)
		if over > 0:
			lost[resource] = over
	return lost

## Total perdu au plafond, toutes ressources confondues.
##
## En réserve commune, c'est ce chiffre-là qui se lit d'un coup d'œil : peu importe
## laquelle a débordé, c'est la réserve entière qui était pleine.
func total_wasted() -> int:
	var lost := wasted()
	var total := 0
	for resource in lost:
		total += lost[resource]
	return total

## Journal de travail : qui a tenu quel slot, dans quelle famille. Copie.
func work() -> Array[WorkLine]:
	return _work.duplicate()

## Ouvriers qui n'ont rien produit — non affectés, affectés à une ancre vide, ou
## arrivés quand les slots de leur bâtiment étaient déjà pris. Copie.
##
## La raison n'est pas distinguée : « trois oisifs » suffit à l'affichage, et les
## séparer supposerait de savoir laquelle intéresse le joueur, ce que E2 tranchera
## devant une vraie maquette.
func idle() -> Array[StringName]:
	return _idle.duplicate()

## Nourriture due ce soir : le roster entier, oisifs compris.
func upkeep() -> int:
	return _upkeep

## Nourriture réellement consommée. Inférieure à upkeep() quand la réserve manque.
func consumed() -> int:
	return _consumed

## Ouvriers que la réserve n'a pas pu nourrir.
func unfed() -> int:
	return _unfed

## La réserve a-t-elle manqué ?
func is_famine() -> bool:
	return _unfed > 0
