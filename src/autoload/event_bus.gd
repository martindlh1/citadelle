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

## Le run courant a été refermé et RunManager ne tient plus rien.
##
## Distinct de `run_finished`, et les deux ne disent pas la même chose : l'un annonce
## qu'une partie est **jouée**, l'autre qu'elle est **rangée**. Un écran de fin vit entre
## les deux.
signal run_ended(outcome: RunOutcome)

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

## Le run est fini, et voici comment.
##
## Il portait le jour jusqu'à I2, avec cette note : « ce qu'il advient ensuite — score,
## écran de récompense — appartient à I2 ». C'est fait, et la charge a changé pour la
## raison la plus simple : **un signal qui annonce une fin sans dire laquelle oblige son
## auditeur à la redemander.** Un `RunOutcome` porte la cause, le jour et le score, il est
## immuable, et il ne référence aucun état du domaine.
##
## Il ne se déclenche plus seulement au bout des journées : `DESIGN.md` 5 donne deux
## défaites qui n'attendent pas la dernière. C'est le domaine qui décide laquelle des trois
## fins c'est ; ce fichier ne fait que la transporter.
signal run_finished(outcome: RunOutcome)

## Une vague attend d'être menée, et voici laquelle. L'identifiant, jamais la WaveDef.
##
## L'identifiant pour la même raison que `phase_changed` porte celui de la phase : faire
## voyager la Resource d'équilibrage sur le bus donnerait à n'importe quel adapter une
## référence mutable sur de la data partagée. Le libellé se lit sur la vague que
## RunManager expose.
##
## Il existe parce que `DESIGN.md` 3.8 fait de l'attente un état du run et non un instant :
## le cycle refuse d'avancer d'ici là, donc un écran a de quoi montrer entre les deux.
signal battle_pending(wave: StringName)

## Une vague vient d'être menée. La charge est le rapport, immuable.
signal battle_resolved(report: BattleReport)
