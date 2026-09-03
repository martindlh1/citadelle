class_name WaveDef
extends Resource
## Une vague : qui vient, en combien d'exemplaires, et par où.
##
## Trois choses, et `DESIGN.md` 3.5 n'en demande pas davantage. Les `.tres` vivent dans
## `data/waves/`, un par vague du calendrier.
##
## ---
##
## **La direction est dans la data et non tirée au sort**, et c'est un argument de design plutôt
## qu'une commodité : 3.5 veut qu'elle soit « annoncée à l'avance », parce qu'« on pose un
## bâtiment en pensant à la bataille, et une direction révélée au dernier moment transformerait
## cette prévoyance en loterie ». Un champ se lit et s'annonce ; un tirage ne s'annonce qu'en le
## faisant d'avance, ce qui revient à un champ avec une étape de plus.
##
## **La date n'est pas ici.** C'est le calendrier de `DESIGN.md` 2 qui dit quand une vague
## tombe, et il appartient au Cycle de tour : une vague ne sait pas quel jour on est. `V4`
## branchera les deux, et ce jour-là c'est `RunBalance` qui portera la liste.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Le bord de carte par lequel la vague entre. UNSET vaut 0 pour rester détectable.
##
## Un bord et non une case : la vague entre « à la lisière », et c'est le chemin qui choisit
## **laquelle** des cases de ce bord lui coûte le moins. Nommer la case aurait été décider à sa
## place, et l'aurait fait entrer dans un rocher le jour où le relief change.
enum Side {
	UNSET = 0,
	NORTH = 1,
	SOUTH = 2,
	WEST = 3,
	EAST = 4,
}

## Identifiant stable. Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## L'assaillant qui compose la vague.
##
## Un seul type par vague, et c'est une décision de `V2` : 3.5 dit « qui vient, en combien
## d'exemplaires » au singulier, et une vague mixte demanderait une liste de couples, donc une
## `Resource` de plus pour un contenu qu'aucun chiffre du document ne réclame. Le jour où une
## vague veut deux sortes de corps, c'est ce champ qui devient un tableau — et rien d'autre ne
## bouge, puisque le plateau reçoit déjà ses corps un par un.
@export var enemy: EnemyDef

## Combien d'exemplaires.
@export_range(1, 200, 1) var count: int

## Par où elle entre. Voir Side.
##
## Le type est écrit `WaveDef.Side` **jusque dans le fichier qui le déclare**, et c'est le piège
## que `CLAUDE.md` note depuis `F2a` : GDScript traite le `Side` interne et le `WaveDef.Side` du
## dehors comme deux types distincts. Écrit `Side`, ce champ refuse ce qu'un appelant lui passe.
@export var side: WaveDef.Side

## Ticks entre deux arrivées de corps.
##
## Une vague n'entre pas d'un bloc : ses corps se suivent, et c'est ce qui rend une cadence de
## tir utile — une défense qui tire toutes les vingt ticks ne sert à rien contre dix corps posés
## sur la même case au même instant.
##
## 0 serait légitime — tout le monde arrive ensemble — mais rendrait la cadence muette alors
## qu'elle est la moitié du sujet. On le réclame, comme `climb_cost` chez `WaveBalance`, et pour
## la même raison : un des rares champs où la doctrine du zéro sert un argument de design.
@export_range(1, 200, 1) var spacing: int

## Champs non renseignés. Vide = vague exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if enemy == null:
		missing.append("enemy")
	else:
		for field in enemy.missing_fields():
			missing.append("enemy.%s" % field)
	if count < 1:
		missing.append("count")
	if side == WaveDef.Side.UNSET:
		missing.append("side")
	if spacing < 1:
		missing.append("spacing")
	return missing

## Les cases du bord par lequel cette vague entre, sur une carte de cette taille.
##
## Tout le bord, et c'est le chemin qui départage : `WavePathfinder` est multi-sources
## précisément pour ça, et il rend en un seul parcours la meilleure façon d'entrer. Choisir la
## case ici aurait été décider avant de savoir ce que le relief coûte.
##
## L'ordre est celui du balayage, donc identique d'un lancement à l'autre.
func entry_cells(extent: Vector2i) -> Array[Vector2i]:
	assert(extent.x > 0 and extent.y > 0, "carte de taille non positive : %s" % extent)
	var cells: Array[Vector2i] = []
	match side:
		WaveDef.Side.NORTH:
			for x in extent.x:
				cells.append(Vector2i(x, 0))
		WaveDef.Side.SOUTH:
			for x in extent.x:
				cells.append(Vector2i(x, extent.y - 1))
		WaveDef.Side.WEST:
			for y in extent.y:
				cells.append(Vector2i(0, y))
		WaveDef.Side.EAST:
			for y in extent.y:
				cells.append(Vector2i(extent.x - 1, y))
	# UNSET n'arrive jamais jusqu'ici : GameDatabase refuse de démarrer dessus.
	assert(not cells.is_empty(), "vague sans bord d'entrée : %s" % id)
	return cells
