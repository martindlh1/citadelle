class_name StrikeResult
extends RefCounted
## Ce qu'un coup a trouvé sur la case visée, ou pourquoi il n'a pas été porté.
##
## **Un coup vise une case, jamais une cible.** `DESIGN.md` 3.6 : « Une intention frappe la
## case, pas la cible. Esquiver l'annule — l'attaque s'exécute dans le vide. » Ce fichier est
## l'endroit où cette phrase devient une structure : `NOTHING` n'est pas un échec, c'est une
## fin de coup à part entière, et `is_ok()` est vrai dessus.
##
## La conséquence que 3.6 garde ouverte est portée par la même forme : si un **autre** corps
## se trouve là au moment de l'exécution, c'est lui qui prend — ennemi compris. Le résultat
## nomme ce qu'il a touché, jamais ce qu'on avait voulu toucher.
##
## `{ ok, reason }` comme MoveResult, et dans `domain/combat/` par le même critère.
##
## Immuable.

## Ce qu'un coup a rencontré.
const UNKNOWN_BODY := &"unknown_body"
const IS_DOWN := &"is_down"
const WRONG_SIDE := &"wrong_side"
const ALREADY_STRUCK := &"already_struck"

## La case est hors de la portée de ce corps.
const OUT_OF_RANGE := &"out_of_range"

## La case n'est pas sur la carte.
const OFF_MAP := &"off_map"

## Nature de ce que le coup a touché.
enum Hit { NOTHING, BODY, BUILDING }

## Aucune ancre : le coup n'a pas touché de bâtiment.
##
## Même valeur et même rôle que `WorkLine.NO_CELL`, recopiée plutôt qu'importée pour ne pas
## faire dépendre le Combat d'un contrat dont il n'a rien d'autre à tirer.
const NO_ANCHOR := Vector2i(-1, -1)

var _ok: bool
var _reason: StringName
var _cell: Vector2i
var _damage: int
var _hit: Hit
var _body: StringName
var _anchor: Vector2i = NO_ANCHOR
var _felled: bool

## Le coup est parti et n'a rien trouvé.
##
## Le cas que l'esquive produit, et il est **réussi** : le corps a dépensé son coup, la case
## était vide, et c'est exactement ce que le joueur avait manœuvré pour obtenir.
static func into_the_void(cell: Vector2i) -> StrikeResult:
	var result := StrikeResult.new()
	result._ok = true
	result._cell = cell
	result._hit = Hit.NOTHING
	return result

## Le coup a trouvé un corps.
static func on_body(cell: Vector2i, damage: int, body: StringName,
		felled: bool) -> StrikeResult:
	assert(damage >= 0, "coup de %d point(s) sur %s" % [damage, body])
	assert(not body.is_empty(), "coup sur un corps sans identifiant")
	var result := StrikeResult.new()
	result._ok = true
	result._cell = cell
	result._damage = damage
	result._hit = Hit.BODY
	result._body = body
	result._felled = felled
	return result

## Le coup a trouvé un bâtiment, désigné par son ancre.
##
## L'ancre et non la case frappée : c'est par elle que la ville identifie un bâtiment, et
## une empreinte de quatre cases n'a qu'un jeu de points de vie. `DamageReport` emploie la
## même clé, ce qui évite une traduction au moment d'appliquer.
static func on_building(cell: Vector2i, damage: int, anchor: Vector2i,
		felled: bool) -> StrikeResult:
	assert(damage >= 0, "coup de %d point(s) en %s" % [damage, anchor])
	var result := StrikeResult.new()
	result._ok = true
	result._cell = cell
	result._damage = damage
	result._hit = Hit.BUILDING
	result._anchor = anchor
	result._felled = felled
	return result

## Le coup n'a pas été porté, pour cette raison.
static func refused(reason: StringName) -> StrikeResult:
	assert(not reason.is_empty(), "refus de coup sans raison")
	var result := StrikeResult.new()
	result._ok = false
	result._reason = reason
	result._hit = Hit.NOTHING
	return result

## Le coup a-t-il été porté ? Vrai même quand il n'a rien trouvé.
func is_ok() -> bool:
	return _ok

## Pourquoi le refus, ou vide si le coup est parti.
func reason() -> StringName:
	return _reason

## Case visée.
func cell() -> Vector2i:
	return _cell

## Points infligés. Zéro sur un coup dans le vide comme sur un refus.
func damage() -> int:
	return _damage

## Ce que le coup a touché.
func hit() -> Hit:
	return _hit

## Identifiant du corps touché, ou vide.
func body() -> StringName:
	return _body

## Ancre du bâtiment touché, ou `NO_ANCHOR`.
func anchor() -> Vector2i:
	return _anchor

## La cible est-elle tombée sous ce coup ?
##
## Vrai pour un corps comme pour un bâtiment : les deux tombent à zéro, et c'est ce qui
## permet à l'écran de dire « il s'écroule » sans savoir de quoi il parle.
func felled() -> bool:
	return _felled
