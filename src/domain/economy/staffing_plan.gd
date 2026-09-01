class_name StaffingPlan
extends RefCounted
## Qui tourne et qui dort, pour un effectif donné et une ville donnée.
##
## Résultat de Staffing.resolve(). Immuable une fois construit.
##
## Il vit dans domain/economy/ et non dans contracts/, par le critère habituel : aucun
## second **système du domaine** ne le franchit. L'Économie le produit et le consomme,
## domain/run/ a le droit de tout lire, et les adapters lisent le domaine — c'est leur
## métier. Le jour où les Vagues voudront savoir ce qui dort, il déménagera, et ce sera un
## déplacement de fichier.

## Ancres des bâtiments qui tournent, dans l'ordre de pose.
var _active: Array[Vector2i] = []

## Ancres des bâtiments endormis, dans l'ordre de pose.
var _asleep: Array[Vector2i] = []

## Travailleurs retenus par les bâtiments actifs.
var _committed: int = 0

## Habitants sur lesquels le plan a été calculé.
var _headcount: int = 0

## Plan brut. Réservé à Staffing, qui est le seul à savoir le composer.
static func create(active: Array[Vector2i], asleep: Array[Vector2i],
		committed: int, headcount: int) -> StaffingPlan:
	assert(committed >= 0, "travailleurs immobilisés négatifs")
	assert(committed <= headcount, "plus de travailleurs immobilisés que d'habitants")
	var plan := StaffingPlan.new()
	plan._active = active.duplicate()
	plan._asleep = asleep.duplicate()
	plan._committed = committed
	plan._headcount = headcount
	return plan

## Ancres qui tournent, dans l'ordre de pose. Copie.
func active() -> Array[Vector2i]:
	return _active.duplicate()

## Ancres endormies, dans l'ordre de pose. Copie.
func asleep() -> Array[Vector2i]:
	return _asleep.duplicate()

## Travailleurs immobilisés par ce que le village fait tourner.
func committed() -> int:
	return _committed

## Bras libres. C'est ce qu'un chantier neuf peut dépenser.
func available() -> int:
	return _headcount - _committed

## Ce bâtiment tourne-t-il ?
##
## Une ancre inconnue rend `false` plutôt qu'une erreur : demander pour une cellule vide
## est le cas normal d'un curseur promené sur la carte, pas un incident.
func is_active(anchor: Vector2i) -> bool:
	return _active.has(anchor)

## Le village a-t-il des bâtiments à l'arrêt faute de bras ?
func has_sleepers() -> bool:
	return not _asleep.is_empty()
