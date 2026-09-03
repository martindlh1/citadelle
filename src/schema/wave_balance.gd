class_name WaveBalance
extends Resource
## Ce qu'une vague paie pour avancer : marcher, monter, et casser.
##
## Trois coûts et une hauteur d'enjambée, et c'est tout ce dont le chemin de `V1` a besoin. Ce
## que la vague *est* — combien elle a de corps, ce qu'elle encaisse, ce qu'elle frappe —
## appartient à `V2`, et n'entrera ici qu'avec le système qui le lit.
##
## ---
##
## **Les trois coûts sont dans la même unité, et c'est ce qui les rend comparables.** Un pas
## vaut `step_cost`, un cran de montée vaut `climb_cost`, traverser un bâtiment vaut
## `breach_cost` — donc « casser plutôt que contourner » n'est pas une règle écrite quelque
## part, c'est **le résultat de la comparaison**. Une vague casse un mur quand le détour lui
## coûterait plus cher que le mur, et pas avant.
##
## C'est la forme que `DESIGN.md` 3.5 réclame en toutes lettres : « boucher cesse d'être une
## astuce pour devenir un troc ». Un seuil écrit à part — « casse si le détour dépasse N » —
## aurait été un second mécanisme à tenir d'accord avec le chemin, et il se serait trompé
## exactement là où deux détours se valent.
##
## Aucun @export ne porte de défaut, pour la raison exposée dans terrain_balance.gd.

## Ce que coûte un pas d'une case à sa voisine, à plat.
##
## Non nul, et pas seulement pour éviter une division : à zéro, tous les chemins qui ne montent
## ni ne cassent auraient le même prix, et la vague choisirait le premier venu dans l'ordre de
## balayage plutôt que le plus court. La distance **est** la première moitié de ce que
## `DESIGN.md` 3.5 fait mesurer au terrain.
@export_range(1, 100, 1) var step_cost: int

## Ce que coûte **chaque cran** gravi, en plus du pas.
##
## La montée coûte, la descente est gratuite : c'est la lecture de 3.5 — « Coûtent : la
## distance, la montée » — et elle a une conséquence de jeu qu'on veut. Une vague préfère
## contourner une butte que la gravir, donc un village haut perché est **naturellement** plus
## loin qu'il n'en a l'air, sans qu'aucune règle ne le dise.
##
## 0 serait légitime — un relief qui ne coûterait rien à monter —, mais il rendrait le relief
## muet pour les vagues alors qu'il est la moitié du sujet. On le réclame donc, et c'est un des
## rares champs où la doctrine du zéro sert un argument de design plutôt qu'un oubli.
@export_range(1, 100, 1) var climb_cost: int

## Ce que coûte de traverser **une case** de bâtiment.
##
## C'est la « patience » de `DESIGN.md` 3.5, exprimée dans la seule unité qui permette de la
## comparer à un détour. À `breach_cost = 10 × step_cost`, une vague accepte dix cases de
## détour plutôt que de casser, et casse au onzième.
##
## **Par case et non par bâtiment**, ce qui fait qu'un mur épais coûte plus cher à percer qu'un
## mur mince. C'est la lecture qu'on veut d'une palissade, et c'est aussi la seule qui garde la
## recherche de chemin en une simple pondération : compter par bâtiment demanderait de savoir,
## au milieu du parcours, si l'on a déjà payé celui-ci — donc un état par chemin, donc plus un
## Dijkstra.
@export_range(1, 1000, 1) var breach_cost: int

## Crans qu'un corps enjambe d'un pas. Au-delà, la marche barre.
##
## **La vague a la sienne, distincte de celle de la génération.** `TerrainGenBalance.max_climb`
## annonçait ce partage depuis `T4` : la génération compte ses accès avec sa propre enjambée, et
## le jour où les deux devraient être le même chiffre, l'un des deux champs déménage. Ce jour
## n'est pas venu — une carte peut vouloir des cols plus larges que ce qu'une vague franchit,
## et c'est même un levier d'équilibrage.
@export_range(1, 32, 1) var max_climb: int

## Champs non renseignés. Vide = bloc exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if step_cost < 1:
		missing.append("step_cost")
	if climb_cost < 1:
		missing.append("climb_cost")
	if breach_cost < 1:
		missing.append("breach_cost")
	if max_climb < 1:
		missing.append("max_climb")
	return missing

## Combien de cases de détour une vague accepte plutôt que de percer une case de bâtiment.
##
## Une lecture et non un réglage : le chiffre ne vit nulle part, il se déduit des deux coûts.
## Elle existe pour que le harnais et le journal puissent dire la patience en cases — l'unité
## dans laquelle on la ressent — sans que personne ne recopie la division.
func patience_in_steps() -> int:
	assert(step_cost > 0, "pas gratuit : la patience n'a pas de sens")
	return breach_cost / step_cost
