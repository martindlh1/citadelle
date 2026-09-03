class_name EnemyDef
extends Resource
## Un assaillant : ce qu'il encaisse, à quelle vitesse il marche, ce qu'il casse, et sa patience.
##
## **Quatre chiffres, et `DESIGN.md` 3.5 les nomme un par un.** Les `.tres` vivent dans
## `data/enemies/`, un par sorte d'assaillant, et le domaine les reçoit en argument sans jamais
## lire `GameDatabase` — comme les bâtiments et les terrains.
##
## ---
##
## **La patience est ici et non dans l'équilibrage des vagues**, et c'est une correction de
## `V2`. `V1` l'avait mise dans `WaveBalance` avec les prix du pas et de la montée, ce qui
## marchait tant qu'il n'existait qu'une sorte d'assaillant ; 3.5 en fait pourtant un chiffre
## **de la créature**, au même titre que ses points de vie. La différence porte : un bélier
## traverse un mur là où une meute le contourne, et c'est cette asymétrie qui fait qu'une
## palissade a un sens contre l'un et pas contre l'autre.
##
## Ce qui reste dans `WaveBalance` est ce qui n'appartient à personne : le prix d'un pas et
## celui d'un cran gravi, c'est-à-dire l'**échelle** dans laquelle les trois se comparent.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Identifiant stable. Par convention il reprend le nom du fichier .tres.
@export var id: StringName

## Nom affichable, celui qu'un rapport de bataille montre.
##
## Réclamé comme celui d'un bâtiment ou d'une ressource, et pour la même raison qu'à `E2` : un
## identifiant sert le code, un libellé sert l'écran. Sans lui, une chronique de bataille
## raconterait la mort de `raider_a`.
@export var label: String

## Ce qu'il encaisse avant de tomber.
@export_range(1, 1000, 1) var hit_points: int

## Ticks qu'il met à franchir une case.
##
## Une **lenteur** et non une vitesse, et l'inversion est délibérée : ce qui doit rester entier
## est le nombre de ticks, jamais une fraction de case par tick. `DESIGN.md` 3.5 : aucun
## flottant dans le domaine — un corps est sur la case X avec un compteur de progression vers la
## suivante, et la fraction n'est qu'une indication de rendu.
##
## Plus le chiffre est grand, plus l'assaillant est lent. À 1, il avance d'une case par tick.
@export_range(1, 100, 1) var ticks_per_cell: int

## Dégâts qu'il infligerait au Cœur s'il l'atteignait, et à chaque bâtiment qu'il perce.
##
## Un seul chiffre pour les deux, parce que rien dans 3.5 ne les distingue et qu'en inventer un
## second demanderait une explication à donner. Ce qu'une vague coûte est « un retard de
## reconstruction plutôt qu'une dette définitive », et ce chiffre-là en est la mesure.
@export_range(1, 500, 1) var damage: int

## Ce que lui coûte de percer **une case** de bâtiment, dans l'unité des pas de `WaveBalance`.
##
## C'est le « seuil de patience » de 3.5, exprimé dans la seule unité qui permette de le
## comparer à un détour : à `patience = 12 × step_cost`, il accepte douze cases de détour plutôt
## que de casser, et casse à la treizième. Le seuil n'existe donc nulle part comme règle — **il
## est le prix**, et c'est le chemin qui tranche.
##
## Par case et non par bâtiment, ce qui fait qu'un mur épais coûte plus cher à percer qu'un mur
## mince. C'est la lecture qu'on veut d'une palissade, et la seule qui garde la recherche de
## chemin en une simple pondération.
@export_range(1, 10000, 1) var patience: int

## Crans qu'il enjambe d'un pas. Au-delà, la marche barre.
##
## **Le sien, distinct de celui de la génération.** `TerrainGenBalance.max_climb` annonçait ce
## partage depuis `T4` : la carte compte ses accès avec sa propre enjambée, et le jour où les
## deux devraient être le même chiffre, l'un des deux déménage. Ce jour n'est pas venu — une
## carte peut vouloir des cols plus larges que ce qu'un assaillant franchit, et c'est même un
## levier d'équilibrage.
@export_range(1, 32, 1) var climb: int

## Champs non renseignés. Vide = assaillant exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if id.is_empty():
		missing.append("id")
	if label.is_empty():
		missing.append("label")
	if hit_points < 1:
		missing.append("hit_points")
	if ticks_per_cell < 1:
		missing.append("ticks_per_cell")
	if damage < 1:
		missing.append("damage")
	if patience < 1:
		missing.append("patience")
	if climb < 1:
		missing.append("climb")
	return missing
