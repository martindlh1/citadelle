class_name EnemyData
extends Resource
## Un assaillant : ce qu'il encaisse, ce qu'il porte, et comment il se déplace.
##
## Les .tres vivent dans data/enemies/, un par type. Le domaine le reçoit dans la vague
## qu'on lui donne et ne lit jamais GameDatabase, comme pour BuildingData et TerrainData.
##
## **Une Resource et non un DTO de contracts/**, par la règle que F1 a tirée en sortant
## WaveDef de contracts/ : c'est du contenu qu'on édite dans un .tres, et contracts/ est
## l'endroit où deux systèmes **du code** se rencontrent. Ce qui traverse la frontière est
## le CombatStats qu'il rend, pas ce fichier.
##
## Ce que ce fichier ne décide pas, et c'est la règle de DESIGN.md 3.3 appliquée à l'autre
## camp : ce qu'un assaillant **fait** est du code de domain/combat/, jamais de la data.
## Ajouter un *type* d'ennemi doit rester une édition de data/ ; ajouter une *nature* — un
## qui soigne, un qui pousse — est légitimement une modification du domaine. Une Resource
## qui porterait une méthode de résolution serait du domaine déguisé.
##
## La **couleur** est entrée à F3a et le **butin** à F2b, et ce docstring les annonçait tous
## deux mot pour mot : chacun est arrivé avec le code qui le lit, jamais avant. Rien ne
## reste dehors — ce fichier décrit désormais un assaillant en entier.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Couleur qu'on lit comme « non renseignée ».
##
## Même sentinelle et même raison que `TerrainData.UNSET_COLOR` et `PhaseDef.UNSET_COLOR` :
## le noir opaque est le défaut d'un `Color` en GDScript, donc exactement ce que Godot omet
## d'un `.tres`, et un champ oublié y est indiscernable d'un noir délibéré. On tranche pour
## « oublié ». Un assaillant qui voudrait vraiment du noir écrit `Color(0.02, 0.02, 0.02)`.
const UNSET_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## Identifiant stable. Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Libellé affiché. C'est le seul mot que l'écran dira de lui.
##
## Réclamé comme celui d'une PhaseDef et d'une WaveDef, et pour la même raison : un
## assaillant sans nom s'annoncerait par son identifiant interne, en anglais, au milieu
## d'un rapport français.
@export var label: String

## Ce qu'il encaisse avant de tomber.
@export_range(0, 200, 1) var hit_points: int

## Plancher des dégâts d'un de ses coups.
##
## Zéro est légitime et n'est pas un oubli : une fourchette qui commence à zéro est un
## assaillant qui rate parfois, ce qui est un modèle jouable. C'est le plafond qui porte le
## contrôle, voir missing_fields().
@export_range(0, 100, 1) var damage_min: int

## Plafond des dégâts d'un de ses coups.
@export_range(0, 100, 1) var damage_max: int

## Jusqu'où il frappe, en cases, distance de Manhattan.
##
## CombatStats.CONTACT pour un corps-à-corps. C'est ce seul chiffre qui décide de sa nature
## d'attaque, et non un champ à part : F2b lira « au-delà du contact » pour savoir qu'un
## assaillant se poste au lieu de charger. Un booléen `ranged` à côté aurait pu dire le
## contraire de la portée qui le porte, ce qui est le défaut que DESIGN.md 2 refuse pour la
## fin de journée.
@export_range(1, 20, 1) var reach: int

## Points de déplacement par tour.
##
## Zéro est légitime : une pièce de siège qui ne bouge pas est un assaillant que le terrain
## rend redoutable ou inoffensif selon où il entre. Voir missing_fields().
@export_range(0, 20, 1) var move: int

## Plus haute marche qu'il franchit d'un seul pas, en crans de relief.
##
## DESIGN.md 3.6 : « monter coûte, une marche trop haute bloque ». Il est **par type** et
## non global, ce qui est la seule chose de ce fichier qui rende le relief intéressant :
## un assaillant qui escalade là où les autres contournent transforme un plateau défendu en
## piège, sans qu'une ligne du plateau ait à connaître son nom.
##
## Zéro est légitime : il ne se déplace qu'à plat.
@export_range(0, 20, 1) var climb: int

## Unités de réserve qu'il emporte par manche passée dans l'enceinte.
##
## Le pillage de DESIGN.md 3.6, tranché à F2b : « seulement une facture — ce qu'ils ont
## cassé et **emporté entre-temps** ». Il s'accumule donc pendant la bataille et non à son
## départ, et c'est ce qui fait payer les deux bonnes façons de jouer : les abattre vite, ou
## les tenir dehors. Une vague bloquée à la lisière repart les mains vides sans qu'une règle
## ait à le dire.
##
## L'enceinte est le rectangle du bâti, celui-là même dont la vague longe la lisière pour
## entrer. Un rectangle et non les seules cases bâties : ce qu'on défend est un village, pas
## une collection de murs, et les trous entre les maisons en font partie.
##
## Zéro est légitime et n'est pas un oubli : une pièce de siège qui casse sans rien emporter
## est un assaillant qu'on redoute autrement. Même exemption que `move` et `climb`, et que
## `plunder_per_breach` avant eux.
@export_range(0, 100, 1) var plunder: int

## Couleur de son pion au rendu, en attendant de vrais assets.
##
## Elle vit ici et non dans le renderer pour la raison qui vaut depuis `TerrainData` :
## celui-ci ne doit **jamais** commuter sur un identifiant, sans quoi ajouter un assaillant
## cesserait d'être une édition de `data/`. Le camp des ouvriers, lui, n'a pas de couleur en
## data — il n'a pas de types à distinguer, donc c'est une constante de décor du renderer,
## comme celle de `CellHighlight`.
@export var color: Color

## Son profil, tel que le plateau le consomme.
##
## Le seul point de passage entre ce fichier et le domaine, et il rend **la même forme**
## qu'un ouvrier engagé. C'est ce qui permet au déplacement, à la portée et aux dégâts de
## s'écrire une fois pour les deux camps.
func to_stats() -> CombatStats:
	return CombatStats.create(hit_points, damage_min, damage_max, reach, move, climb)

## Champs non renseignés ou incohérents. Vide = assaillant exploitable.
## Vérifié au boot par GameDatabase, comme les terrains, les bâtiments, les cartes et les
## vagues.
##
## Deux champs échappent à la doctrine du zéro, et chacun pour une raison de contenu qui se
## tient : `move` à zéro est une pièce immobile, `climb` à zéro un corps qui ne grimpe pas.
## Les réclamer interdirait d'essayer ces deux assaillants sans toucher au GDScript, ce qui
## est exactement l'argument qui a laissé passer `plunder_per_breach` à F1.
##
## `damage_min` n'est pas réclamé non plus — une fourchette qui part de zéro est jouable —,
## mais son **inversion** l'est : une fourchette 5..2 ne se distingue pas d'un champ oublié
## et ne veut rien dire. C'est le même geste que WaveSlot, qui contrôle la cohérence de deux
## champs plutôt que la présence de chacun.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if hit_points <= 0:
		missing.append("hit_points")
	if damage_max <= 0:
		missing.append("damage_max")
	if damage_min > damage_max:
		missing.append("damage_min")
	if reach < CombatStats.CONTACT:
		missing.append("reach")
	if color == UNSET_COLOR:
		missing.append("color")
	return missing
