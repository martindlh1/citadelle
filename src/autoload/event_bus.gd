extends Node
## Signaux typés globaux. Aucune logique, aucun état.
##
## Couche adapter uniquement : src/domain/ ne connaît pas ce fichier et ne doit
## jamais le référencer. Le domaine retourne un résultat, c'est RunManager qui
## le publie ici.
##
## Règle d'ajout : un signal n'entre dans ce fichier que le jour où un système
## réel l'émet et où un auditeur réel peut l'entendre. Les charges utiles sont
## des DTO immuables ou des primitives — jamais une référence mutable sur un
## état du domaine.

## GameDatabase a fini d'indexer data/. Émis une fois au boot, en différé pour
## que la scène principale, prête après les autoloads, puisse encore l'entendre.
signal database_ready()

## Un run vient de s'ouvrir sur ce seed.
signal run_started(run_seed: int)

## Le run courant s'est terminé sur ce score.
signal run_ended(score: int)

## La phase courante a changé. Le jour, et l'identifiant de la phase entrante.
##
## L'identifiant et non la PhaseDef : un auditeur n'a besoin que de savoir que ça a
## bougé, et faire voyager la Resource d'équilibrage sur le bus donnerait à n'importe
## quel adapter une référence mutable sur de la data partagée. Le libellé se lit sur la
## phase que RunManager expose.
signal phase_changed(day: int, phase: StringName)

## Une phase vient de se résoudre. La charge est le rapport, immuable.
##
## Un seul signal pour les deux sortes de résolution : le rapport porte la journée fermée
## quand il y en a une, et `closes_the_day()` le dit. Un second signal serait une frontière
## que personne ne franchit — aucun auditeur ne veut l'une sans l'autre.
signal phase_resolved(report: PhaseReport)

## Le run a franchi sa dernière phase. Ce qu'il advient ensuite — score, écran de
## récompense — appartient à I2 ; ce signal existe pour que le harnais cesse de jouer.
signal run_finished(day: int)
