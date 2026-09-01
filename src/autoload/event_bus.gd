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
## `R0` a appliqué cette règle à l'envers, et c'est la première fois : sept signaux sont
## sortis d'ici parce que les systèmes qui les émettaient n'existent plus. Ils décrivaient
## une journée en phases, une bataille en attente et une fin de run que le rescope refait
## — `I3` et `V4` reposeront ceux dont ils auront besoin, avec les charges que leurs
## rapports porteront vraiment. Il ne reste que celui qui n'a jamais dépendu d'un système.

## GameDatabase a fini d'indexer data/. Émis une fois au boot, en différé pour
## que la scène principale, prête après les autoloads, puisse encore l'entendre.
signal database_ready()
