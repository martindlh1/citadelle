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
