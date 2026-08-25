class_name CardShuffle
extends RefCounted
## Le mélange, et le seul endroit du projet où il s'écrit.
##
## `Array.shuffle()` est **interdit ici**, et c'est toute la raison d'être du fichier :
## il tire sur le RNG global de Godot et non sur celui du run. Un deck mélangé par lui
## rendrait un même seed non rejouable — ce que la section Déterminisme de CLAUDE.md
## interdit, au même titre que `randf()` hors de `RunState.rng` — et il le ferait sans
## rien signaler. C'est exactement le profil du piège de `sort()` sur des StringName :
## le code a l'air juste, la sortie a l'air plausible, et elle change d'une session à
## l'autre.
##
## Un fichier pour une fonction, ce qui ne se justifie pas souvent. Ici si : il fallait
## éviter le piège à deux endroits — la pioche du Deck et l'offre d'un DraftPool — et
## une règle qu'on recopie est une règle qu'on oublie à la troisième occurrence.
##
## Fisher-Yates, du dernier vers le premier, sur une copie. La suite des tirages ne
## dépend donc que du rng et de la taille du tableau : deux mélanges de même longueur
## consomment exactement le même nombre de valeurs, ce qui rend la consommation du flux
## prévisible pour tout ce qui tire après.

## Ces cartes dans un ordre tiré sur ce rng. Le tableau d'entrée n'est pas modifié.
static func shuffled(cards: Array[StringName],
		rng: RandomNumberGenerator) -> Array[StringName]:
	assert(rng != null, "mélange demandé sans générateur")
	var mixed := cards.duplicate()
	for index in range(mixed.size() - 1, 0, -1):
		var pick := rng.randi_range(0, index)
		var held: StringName = mixed[index]
		mixed[index] = mixed[pick]
		mixed[pick] = held
	return mixed
