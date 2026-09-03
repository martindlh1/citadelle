class_name WaveBalance
extends Resource
## L'échelle dans laquelle une marche se paie : le prix d'un pas, et celui d'un cran gravi.
##
## **Deux chiffres, et ils n'appartiennent à personne.** Ce que coûte de percer un mur et ce
## qu'on enjambe sont des traits de l'**assaillant** — `EnemyDef` les porte —, mais il faut bien
## une unité commune dans laquelle les comparer, et c'est celle-ci.
##
## *`V1` avait mis les quatre ici*, ce qui marchait tant qu'il n'existait qu'une sorte
## d'assaillant. `DESIGN.md` 3.5 en fait pourtant deux chiffres de la créature, et la différence
## porte : un bélier traverse un mur là où une meute le contourne, et c'est cette asymétrie qui
## fait qu'une palissade a un sens contre l'un et pas contre l'autre. Deux champs sont donc
## partis chez `EnemyDef` à `V2`, et ce qui reste est exactement ce qui n'a pas de propriétaire.
##
## ---
##
## **Tout est dans la même unité, et c'est ce qui rend le troc du mur possible.** Un pas vaut
## `step_cost`, un cran de montée vaut `climb_cost`, percer une case vaut la patience de celui
## qui perce — donc « casser plutôt que contourner » n'est pas une règle écrite quelque part,
## c'est **le résultat de la comparaison**.
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

## Champs non renseignés. Vide = bloc exploitable.
func missing_fields() -> PackedStringArray:
	var missing := PackedStringArray()
	if step_cost < 1:
		missing.append("step_cost")
	if climb_cost < 1:
		missing.append("climb_cost")
	return missing

## Combien de cases de détour cet assaillant accepte plutôt que de percer une case de bâtiment.
##
## Une lecture et non un réglage : le chiffre ne vit nulle part, il se déduit de la patience et
## du prix d'un pas. Elle existe pour que le harnais et le journal puissent dire la patience en
## cases — l'unité dans laquelle on la ressent — sans que personne ne recopie la division.
func patience_in_steps(enemy: EnemyDef) -> int:
	assert(step_cost > 0, "pas gratuit : la patience n'a pas de sens")
	assert(enemy != null, "patience sans assaillant")
	return enemy.patience / step_cost
