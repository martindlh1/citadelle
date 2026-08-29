class_name CombatIntent
extends RefCounted
## Ce qu'un assaillant annonce pour son tour : une case, ou rien de plus qu'une direction.
##
## **La question que `DESIGN.md` 3.6 gardait ouverte depuis `F2a`**, et la réponse tient en
## une ligne : *un corps annonce une case exactement quand il peut frapper sans bouger.*
## L'annonce est alors **engageante** — il frappe cette case quoi qu'il arrive. Sinon il
## n'annonce que sa nature, et son tour se résout contre le plateau réel.
##
## Ce que cette ligne achète, et pourquoi les deux autres sorties ont été écartées :
##
## - **Annoncer un trajet** ne tient pas. Le joueur agit après l'annonce, donc un trajet est
##   ou bien conditionnel — et l'information cesse d'être complète, ce que 3.6 refuse en
##   toutes lettres — ou bien rigide, et un ennemi enfermé cogne l'air. C'est ce que `F2a` a
##   fait remonter, et c'est pour ça que ce jalon a été coupé là.
## - **N'annoncer jamais de case** aurait été le plus court, et aurait tué une règle entière :
##   « une intention frappe la case, pas la cible. Esquiver l'annule — c'est ce qui fait du
##   déplacement la décision centrale. » On n'esquive pas ce qui n'est pas annoncé. La règle
##   aurait continué de fonctionner à la résolution sans que le joueur puisse jamais s'en
##   servir.
##
## La question littérale de 3.6 était « une attaque **à distance** annonce-t-elle sa case ? »,
## et la réponse y est *oui* — un tireur posté n'a pas besoin de bouger. Mais elle n'est pas
## une règle sur les tireurs : un corps-à-corps déjà collé à un ouvrier annonce sa case lui
## aussi, et c'est précisément le moment où reculer d'un pas est une décision. Ce qui varie
## n'est donc pas le **type** — l'objection du « vocabulaire à géométrie variable » — mais la
## **situation**, que le joueur lit sur le plateau.
##
## Le troc de 3.6 tient par-dessus : esquiver coûte à l'assaillant son tour entier, et le
## tour suivant il annonce la palissade, qui n'esquive pas. « On garde ses gens, ils mangent
## les murs. »
##
## **Deux entrées, et c'est tout ce que `F2b` invente.** Le renfort et les états que 3.6
## annonce pour plus tard sont `X5` et `X6` ; ils entreront dans cet `enum` sans que rien
## d'autre ait à bouger, ce qui est la seule chose qu'on lui demande aujourd'hui.
##
## Il vit dans `domain/combat/` et non dans `contracts/` : aucun second système du domaine
## ne le franchit — seul un écran le lit, et lire le domaine est le métier d'un adapter.
## C'est le critère de `PickResult` et de `ProgressReport`.
##
## Immuable.

## Ce qu'un corps s'apprête à faire.
enum Kind {
	## Il se rapproche, et frappera ce qu'il pourra en arrivant.
	ADVANCE,
	## Il frappe la case annoncée, sans bouger et quoi qu'il y ait dessus.
	STRIKE,
}

## Aucune case annoncée.
##
## Même valeur et même rôle que `StrikeResult.NO_ANCHOR` et `WorkLine.NO_CELL`, recopiée
## plutôt qu'importée pour ne pas faire dépendre ce fichier d'un contrat dont il n'a rien
## d'autre à tirer.
const NO_CELL := Vector2i(-1, -1)

var _kind: CombatIntent.Kind
var _cell: Vector2i = NO_CELL

## Il vient. Ni trajet, ni case : les deux se décideront à l'exécution, contre le plateau
## tel qu'il sera après que le joueur aura joué.
static func advance() -> CombatIntent:
	var intent := CombatIntent.new()
	intent._kind = Kind.ADVANCE
	return intent

## Il frappera cette case, et il ne bougera pas.
##
## L'annonce **engage** : c'est ce qui rend l'esquive possible, et c'est aussi ce qui rend
## l'esquive payante — un coup annoncé qui part dans le vide est un tour d'assaillant perdu.
static func strike(cell: Vector2i) -> CombatIntent:
	var intent := CombatIntent.new()
	intent._kind = Kind.STRIKE
	intent._cell = cell
	return intent

## Ce qu'il annonce.
func kind() -> CombatIntent.Kind:
	return _kind

## La case annoncée, ou `NO_CELL`.
func cell() -> Vector2i:
	return _cell

## L'annonce désigne-t-elle une case ?
##
## Une question plutôt qu'un `kind() == Kind.STRIKE` recopié partout : c'est elle que l'écran
## pose pour savoir s'il a une case à allumer, et c'est elle que l'exécution pose pour savoir
## si elle a un engagement à honorer. Le jour où un troisième verbe annoncera une case — une
## capacité de `X5` —, elle se redéfinira ici et nulle part ailleurs.
func is_bound() -> bool:
	return _kind == Kind.STRIKE
