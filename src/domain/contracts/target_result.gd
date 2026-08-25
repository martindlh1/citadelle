class_name TargetResult
extends RefCounted
## Réponse à « puis-je jouer cette carte ici ? » : oui avec ce que ça poserait, ou non
## avec la raison.
##
## C'est la forme { ok, reason } que les conventions réservent aux erreurs récupérables,
## et le jumeau exact de `PlacementResult` — même profil, même raison d'être. Un ciblage
## refusé est le résultat normal d'un curseur promené sur la carte une carte en main, pas
## un incident à remonter par `push_error` : la surbrillance des cibles interroge cette
## fonction à chaque image, et la plupart des réponses sont des refus.
##
## C'est ici qu'atterrit la **jouabilité** que D1 avait explicitement refusé de juger.
## `DESIGN.md` 3.5 pose qu'un jeu de carte est une *intention* que le système concerné
## accepte ou refuse ; le `Deck` ne connaît ni la grille ni la ville, donc il ne pouvait
## pas répondre. `ActionTargeting` le peut, parce qu'on lui passe les deux.
##
## Une acceptation porte trois choses que la validation a calculées de toute façon, et
## que l'action posée gardera figées : **où** l'action se joue — à cru ou dans un
## bâtiment —, **sur quelle cellule** exactement, et **combien** d'ouvriers elle accepte.
## Les faire recalculer plus tard ouvrirait la porte à ce que l'écran promette trois
## postes et que le soir n'en serve que deux.
##
## La cellule rendue n'est pas toujours celle qu'on a demandée : sur un bâtiment, c'est
## son **ancre**, que le ciblage a retrouvée depuis une cellule quelconque de l'empreinte.
## C'est le chemin d'un clic — on désigne un coin de la ferme, on vise la ferme — et le
## faire ici plutôt que dans l'adapter évite que deux clics sur la même ferme posent deux
## actions qui se croient différentes.

## Le ciblage est accepté, il n'y a pas de raison à donner.
const REASON_NONE := &""

## La cible tombe hors de la carte.
const REASON_OUT_OF_BOUNDS := &"out_of_bounds"

## Cette carte n'a pas de règle de ciblage — une carte de bâtiment, qui se pose et ne
## s'affecte pas, ou une action que le MVP n'a pas encore écrite.
const REASON_UNKNOWN_CARD := &"unknown_card"

## Rien n'est bâti sur la cible, alors que le verbe exige un bâtiment.
const REASON_NO_BUILDING := &"no_building"

## La cible porte un bâtiment achevé, alors que le verbe exige un chantier.
const REASON_ALREADY_BUILT := &"already_built"

## La cible porte un chantier inachevé, qui n'offre encore aucun poste.
const REASON_UNFINISHED := &"unfinished"

## Le bâtiment visé n'a pas de bloc de production : il n'a pas « zéro slot », il n'a pas
## de poste du tout. C'est l'entrepôt, l'habitation, la palissade.
const REASON_NO_PRODUCTION := &"no_production"

## La cible porte un bâtiment, alors que le verbe ne se joue qu'à cru.
const REASON_OCCUPIED := &"occupied"

## Aucun tag de la cible n'autorise ce verbe à cru. `DESIGN.md` 3.1 : ce sont les tags
## qui décident où une action à cru peut se jouer.
const REASON_WRONG_TAG := &"wrong_tag"

## Cette carte est **déjà posée** sur cette cible.
##
## Une carte ouvre les postes de sa cible une fois. Une seconde du même nom au même
## endroit les rouvrirait, et trois ouvriers produiraient dans une cabane qui n'a que
## deux postes — la carte cesserait d'être une permission pour devenir un multiplicateur.
##
## Deux cartes **différentes** sur une même cellule restent parfaitement acceptées :
## *Récolter* et *Chasser* sur une même forêt sont deux métiers sur une même terre, et
## c'est précisément ce que D2 a rendu représentable en donnant une identité aux actions.
const REASON_ALREADY_POSTED := &"already_posted"

var _ok: bool
var _reason: StringName = REASON_NONE
var _kind: PlayedAction.Kind = PlayedAction.Kind.BARE
var _target: Vector2i
var _capacity: int

## Ciblage accepté : l'action se poserait de cette façon, sur cette cellule, et
## accepterait tant d'ouvriers.
##
## Une capacité nulle est refusée ici plutôt que tolérée. Une action qu'aucun ouvrier ne
## peut tenir est indiscernable d'un refus pour le joueur, et la laisser passer
## produirait une action posée que rien ne peut jamais servir — le genre d'état qui ne
## casse pas mais qui ment.
static func accepted(kind: PlayedAction.Kind, target: Vector2i,
		capacity: int) -> TargetResult:
	assert(capacity > 0, "ciblage accepté sans aucun poste : %d" % capacity)
	var result := TargetResult.new()
	result._ok = true
	result._kind = kind
	result._target = target
	result._capacity = capacity
	return result

## Ciblage refusé pour cette raison, qui est l'une des constantes ci-dessus.
static func refused(reason: StringName) -> TargetResult:
	assert(not reason.is_empty(), "refus sans raison")
	var result := TargetResult.new()
	result._reason = reason
	return result

## Le ciblage est-il accepté ?
func is_ok() -> bool:
	return _ok

## Raison du refus. Vide quand le ciblage est accepté.
func reason() -> StringName:
	return _reason

## À cru ou dans un bâtiment. Précondition : is_ok().
func kind() -> PlayedAction.Kind:
	assert(_ok, "nature demandée à un ciblage refusé")
	return _kind

## Cellule que l'action viserait — l'ancre du bâtiment quand elle s'y joue, et non la
## cellule d'empreinte qu'on a désignée. Précondition : is_ok().
func target() -> Vector2i:
	assert(_ok, "cible demandée à un ciblage refusé")
	return _target

## Ouvriers que l'action accepterait. Précondition : is_ok().
func capacity() -> int:
	assert(_ok, "capacité demandée à un ciblage refusé")
	return _capacity
