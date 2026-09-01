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
##
## `R0` a appliqué cette règle à l'envers, et c'était la première fois : sept signaux sont
## sortis d'ici parce que les systèmes qui les émettaient n'existaient plus. `I3` en repose
## **un seul**, et le compte mérite d'être expliqué, parce que le jeu d'avant en avait huit
## pour moins de choses.
##
## Un tour se résout d'un bloc, et le rapport qu'il rend dit tout ce qui s'est passé
## dedans — ce qui a été produit, ce que le plafond a mangé, quels chantiers ont bougé, ce
## que le repas a coûté, et comment le run s'est terminé s'il s'est terminé. Là où l'ancien
## jeu avait besoin d'annoncer une phase franchie, une journée refermée, une bataille armée
## et un run fini, il n'y a plus qu'un moment à annoncer.
##
## **`run_ended` n'est donc pas là**, et son absence est la règle appliquée honnêtement :
## `TurnReport.outcome()` porte déjà l'issue, et aucun auditeur ne poserait la question
## ailleurs. Le jour où un écran de fin vivra hors du tour — `M1` —, il l'aura.

## GameDatabase a fini d'indexer data/. Émis une fois au boot, en différé pour
## que la scène principale, prête après les autoloads, puisse encore l'entendre.
signal database_ready()

## Un tour vient de se résoudre. Le rapport dit tout ce qu'il a fait, l'issue comprise.
##
## Émis par RunManager après RunOrchestrator.end_turn(), et par lui seul. La charge est un
## TurnReport, immuable comme le veut la règle : ce que le bus transporte ne peut pas être
## muté par celui qui l'écoute.
signal turn_resolved(report: TurnReport)
