class_name PlayedAction
extends RefCounted
## Une carte d'action posée sur une cible : le geste que le joueur vient de faire, avant
## qu'aucun ouvrier n'y soit affecté.
##
## C'est l'objet que D1 avait diagnostiqué manquant. `DESIGN.md` 8 annonçait que jouer
## une carte produirait directement un `Assignment` — ouvrier -> (action, cible) —, donc
## un geste atomique où une carte vaut un ouvrier. Ce raccourci ferait **doubler** les
## deux contraintes : chaque action consommant une carte et un ouvrier, la contrainte
## réelle deviendrait `min(cartes, ouvriers)`, ce que `DESIGN.md` 3.4 refuse
## explicitement — « deux contraintes qui se croisent, et non deux ressources qui se
## doublent ».
##
## Le flux réel compte donc deux gestes, et cette classe est la charnière : on joue la
## carte **sur une cible**, ce qui pose une action ; puis on y affecte **des** ouvriers.
## La carte dit ce qu'on peut faire, les ouvriers disent combien on peut en faire.
##
## Ce qu'elle **ne** porte pas, et ce n'est pas un oubli : ce que l'action rapporte. Une
## action posée est une intention, et `DESIGN.md` 4.2 pose que ce qu'un verbe fait est du
## code de `src/domain/` et non un champ de contenu. Le résolveur relit le terrain et la
## ville au moment de résoudre.
##
## Immuable. L'`ActionBoard` en fabrique à la pose et les jette au vidage de la phase.

## Où l'action se joue.
##
## Un `enum` et non un `StringName`, à l'inverse de `CardData.pool` : c'est un état en
## mémoire décidé par le ciblage, jamais un identifiant écrit dans `data/`. La convention
## générale du projet s'applique donc telle quelle.
##
## Les deux membres sont les deux lectures de `DESIGN.md` 3.5 — « Une action se joue à
## cru ou dans un bâtiment ». Une action à cru rend peu ; la même jouée dans un bâtiment
## rend davantage et applique le multiplicateur de la famille du bâtiment.
enum Kind {
	## Sur une case nue, dont le tag autorise le verbe.
	BARE,
	## Sur un bâtiment posé — un poste de production, ou un chantier à avancer.
	BUILDING,
}

## Le verbe ne va nulle part : c'est le cas de tous sauf un.
const DIRECTION_NONE := 0

## *Terraformer* monte la case d'un cran.
const DIRECTION_UP := 1

## *Terraformer* la descend d'un cran.
const DIRECTION_DOWN := -1

## Identifiant qu'aucune action posée ne partage. C'est la clé sous laquelle
## `Assignment` lui attache des ouvriers.
var _id: int

## Carte jouée. C'est d'elle que le résolveur déduit la nature du verbe.
var _card: StringName

## Cellule visée. Sur un bâtiment, c'est son **ancre** et non une cellule quelconque de
## l'empreinte : le ciblage l'a résolue à la pose, pour que le résolveur n'ait pas à
## refaire ce chemin.
var _target: Vector2i

## À cru ou dans un bâtiment.
var _kind: Kind

## Ouvriers que l'action accepte.
var _capacity: int

## Sens du terrassement, ou DIRECTION_NONE.
##
## Un `int` et non un `enum`, à l'inverse de `Kind`, et le choix est délibéré : il entre
## dans une arithmétique de hauteur — le résolveur écrit `h + direction` —, alors qu'un
## `enum` obligerait à le traduire en chiffre à chaque usage. Les trois valeurs sont
## nommées juste au-dessus, ce que la convention réclame vraiment.
var _direction := DIRECTION_NONE

## Action posée sous cet identifiant, par cette carte, sur cette cible.
##
## `capacity` est **figée à la pose**, comme l'avancement de chantier que
## `BuildingSnapshot` transporte figé. Elle est calculée par le ciblage, qui est le seul
## endroit où la question se pose : la recalculer à la résolution ouvrirait la porte à ce
## que l'écran promette trois postes et que le soir n'en serve que deux.
##
## `direction` est du même bois, et c'est ce que I1 ajoute. `DESIGN.md` 4.2 donne à
## *Terraformer* deux sens et `data/cards/` n'en porte qu'une carte : le sens est donc un
## choix **fait à la pose**, au même titre que l'orientation d'un bâtiment appartient au
## placement et non à la `BuildingData`. Un défaut la rend invisible aux trois verbes qui
## ne vont nulle part.
static func create(id: int, card: StringName, target: Vector2i, kind: Kind,
		capacity: int, direction := DIRECTION_NONE) -> PlayedAction:
	assert(id > 0, "action posée sans identifiant : %d" % id)
	assert(not card.is_empty(), "action posée sans carte")
	assert(capacity >= 0, "action posée à capacité négative : %d" % capacity)
	assert(is_known_direction(direction), "sens de terrassement inconnu : %d" % direction)
	var action := PlayedAction.new()
	action._id = id
	action._card = card
	action._target = target
	action._kind = kind
	action._capacity = capacity
	action._direction = direction
	return action

## Ce chiffre est-il l'un des trois sens ?
##
## Publique parce que le ciblage pose la même question avant d'accepter une pose, et que
## recopier la comparaison là-bas ferait deux listes à tenir d'accord.
static func is_known_direction(direction: int) -> bool:
	return direction == DIRECTION_NONE or direction == DIRECTION_UP \
		or direction == DIRECTION_DOWN

## Identifiant stable pour la durée de la phase. C'est ce que l'`Assignment` nomme.
func id() -> int:
	return _id

## Carte jouée.
func card() -> StringName:
	return _card

## Cellule visée — l'ancre du bâtiment quand l'action s'y joue.
func target() -> Vector2i:
	return _target

## À cru ou dans un bâtiment.
func kind() -> Kind:
	return _kind

## Se joue-t-elle sur une case nue ?
func is_bare() -> bool:
	return _kind == Kind.BARE

## Se joue-t-elle sur un bâtiment ?
func is_on_building() -> bool:
	return _kind == Kind.BUILDING

## Ouvriers que l'action accepte. Au-delà, les suivants chôment.
##
## Ce n'est pas le nombre d'ouvriers affectés : l'affectation vit dans `Assignment`, et
## une action peut parfaitement rester vide. C'est le plafond que le ciblage a promis.
func capacity() -> int:
	return _capacity

## Sens du terrassement : DIRECTION_UP, DIRECTION_DOWN, ou DIRECTION_NONE pour tout
## verbe qui ne déplace pas de terre.
##
## Il s'ajoute à la hauteur de la cellule tel quel, ce qui est la raison d'être des trois
## valeurs choisies.
func direction() -> int:
	return _direction

## L'action déplace-t-elle de la terre ?
func moves_ground() -> bool:
	return _direction != DIRECTION_NONE
