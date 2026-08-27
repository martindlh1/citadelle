class_name PhaseDef
extends Resource
## Une phase de la journée : ce qu'on y a le droit de faire, et si elle résout en
## partant.
##
## `DESIGN.md` 2 garde sous un `OUVERT` la structure de la journée — deux phases
## symétriques à la *Dead in Vinland*, ou deux phases asymétriques construction puis
## résolution — et en tire une conséquence directe sur l'implémentation : « Le `DayCycle`
## ne code ni matin ni soir en dur. Une journée est une liste ordonnée de `PhaseDef`
## définies en data. Les deux modèles ci-dessus deviennent deux fichiers `.tres`, et on
## peut en tester un troisième sans toucher au code. »
##
## Ce fichier est cette phrase. **Aucun nom de phase n'apparaît nulle part dans le code**,
## ni dans le domaine ni dans les adapters : l'UI lit le libellé et les gestes permis
## depuis la phase courante, et le cycle avance sans jamais savoir où il est. C'est ce qui
## permettra à `I2b` de trancher l'`OUVERT` en échangeant un `.tres`.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Poser une carte : une action sur une cible, ou un chantier sur la carte.
const ACTION_PLAY := &"play"

## Envoyer un ouvrier sur une action posée, ou l'en rappeler.
const ACTION_ASSIGN := &"assign"

## Les gestes qu'une phase peut autoriser.
##
## `CLAUDE.md` en cite quatre — bâtir, affecter, échanger, piocher. Il n'y en a que deux
## ici, et l'écart est délibéré : *échanger* attend le marché, et *piocher* est
## aujourd'hui une conséquence de la fin de phase et non un geste que le joueur pose.
## Les écrire d'avance ferait deux frontières que personne ne franchit, ce que `W1` a
## refusé pour `CombatForce` et `D1` pour la colonne **Débloque**. Elles entreront avec
## le système qui les traverse.
const ACTIONS: Array[StringName] = [ACTION_PLAY, ACTION_ASSIGN]

## Couleur qu'on lit comme « non renseignée ».
##
## Même sentinelle et même raison que `TerrainData.UNSET_COLOR` : le noir opaque est le
## défaut d'un `Color` en GDScript, donc exactement ce que Godot omet d'un `.tres`, et un
## champ oublié y est indiscernable d'un noir délibéré. On tranche pour « oublié ». Une
## phase qui voudrait vraiment du noir écrit `Color(0.02, 0.02, 0.02)`.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Identifiant de la phase. Unique dans la journée.
##
## Il ne sert qu'à se nommer dans un rapport et dans un signal — rien ne commute dessus,
## et c'est tout l'intérêt.
@export var id: StringName

## Libellé affiché.
##
## Il a été « la seule chose que l'écran dit de la phase » jusqu'à `P1a`, où la couleur
## ci-dessous l'a rejoint. Les deux disent la même chose de deux façons, et c'est le
## point : une partie jouée à la main a montré qu'on ne **lit** pas un bandeau quinze
## journées durant, on le survole.
@export var label: String

## Teinte de la phase, dont l'écran se sert pour qu'on la reconnaisse sans la lire.
##
## Elle vit ici et non dans une vue pour la raison exacte qui met la couleur d'un terrain
## dans `TerrainData` : le renderer ne commute jamais sur un identifiant, et `DESIGN.md` 2
## interdit qu'un nom de phase entre dans le code. Une table `&"morning" -> bleu` écrite
## dans un adapter serait ce nom en dur, déguisé en mise en forme — et elle rendrait faux
## le « on peut tester un troisième modèle sans toucher au code » que ce fichier promet.
##
## Ce qu'elle teinte appartient à l'écran ; qu'il y ait quelque chose à teindre appartient
## à la data. C'est le même partage que `label`, qui ne dit pas non plus où il s'affiche.
@export var color: Color

## Gestes autorisés, parmi ACTIONS.
##
## Une phase qui n'autorise rien est légitime dès lors qu'elle résout : c'est le soir du
## modèle asymétrique, où l'on regarde la journée se dérouler. Une phase qui n'autorise
## rien **et** ne résout pas ne serait qu'un tour perdu.
@export var allows: Array[StringName]

## Une résolution se déclenche-t-elle à la fin de cette phase ?
##
## C'est le seul champ de tout `data/balance/` que la doctrine du zéro ne peut pas
## protéger : un booléen faux est la valeur par défaut de Godot, donc un `resolves` effacé
## d'un `.tres` est indiscernable d'un `resolves` volontairement faux. Le filet est posé
## un cran plus haut, sur `RunBalance`, qui exige qu'**au moins une** phase de la journée
## résolve — c'est le même geste que `C4` sur `build_actions`, où un cas de test exige
## qu'au moins un bâtiment de `data/` en déclare un. La disparition d'un champ isolé
## resterait invisible ; celle du format entier ne l'est pas.
@export var resolves: bool

## Ce geste est-il l'un de ceux qu'une phase peut déclarer ?
static func is_known_action(kind: StringName) -> bool:
	return ACTIONS.has(kind)

## Cette phase autorise-t-elle ce geste ?
func permits(kind: StringName) -> bool:
	return allows.has(kind)

## Champs non renseignés ou incohérents. Vide = phase exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if color == UNSET_COLOR:
		missing.append("color")
	for kind in allows:
		if not is_known_action(kind):
			missing.append("allows.%s.unknown" % kind)
	if allows.is_empty() and not resolves:
		missing.append("allows")
	return missing
