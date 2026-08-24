# Citadelle *(titre de travail)*

City-builder roguelite en 3D isométrique sur grille en relief.

| Document | Contenu |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Design, systèmes, jalons, questions ouvertes |
| [`CLAUDE.md`](CLAUDE.md) | Contexte permanent pour Claude Code : architecture, conventions, vérification |
| [`JOURNAL.md`](JOURNAL.md) | Décisions prises en cours de route, datées |

## Version de Godot — épinglée

**Godot 4.7.2-stable** (`ed1daf0bf`), renderer Forward+, GDScript uniquement — pas de
C#, pas de GDExtension.

Cette version est figée pour la durée du projet. Une montée de version est une tâche à
part entière, jamais un effet de bord : branche dédiée, et les trois commandes de
vérification passées avant fusion.

Seule dépendance : **gdUnit4 6.2.0**, dans `addons/`.

## Mise en route

Le binaire Godot n'est pas forcément dans le `PATH`. Les commandes de vérification
lisent `GODOT_BIN` :

```bash
export GODOT_BIN="/chemin/vers/Godot_v4.7.2-stable_win64_console.exe"
```

Sur Windows, préférer le binaire `_console` : c'est le seul qui écrit sur la sortie
standard, donc le seul exploitable en ligne de commande.

## Vérification

Les trois commandes qui doivent passer avant de considérer une tâche terminée sont
décrites dans [`CLAUDE.md`](CLAUDE.md#vérification-avant-de-conclure), avec les pièges
de la 4.7.2 qui expliquent pourquoi il en faut trois et pas une.

## Lancer une scène de dev

`scenes/dev/dev_boot.tscn` est la scène principale et le seul fichier de scène du
dossier. Le harnais à lancer se choisit dans la constante `HARNESS` de
`scenes/dev/dev_boot.gd`. Vide, on obtient le rapport de boot.

## Capturer un rendu depuis un terminal

Un harnais qui affiche quelque chose ne se vérifie ni au parsing ni aux tests : il
faut le regarder. Les harnais graphiques acceptent donc une capture en ligne de
commande, qui rend une image puis quitte.

C'est le harnais désigné par `HARNESS` qui répond. Les drapeaux sont les mêmes pour
tous — ils vivent dans `scenes/dev/dev_shot.gd`, en un seul endroit, pour que la même
commande marche partout.

```bash
"$GODOT_BIN" --path . --resolution 1280x720 -- --shot /tmp/rendu.png --shot-turns 1 --shot-hover 16,16
```

Les arguments après `--` sont ceux du jeu et non du moteur. Seul `--shot` est
obligatoire ; les autres sont optionnels :

| Drapeau | Effet |
|---|---|
| `--shot chemin.png` | rend une image puis quitte |
| `--shot-hover x,y` | cellule à désigner. À défaut, le centre de la carte |
| `--shot-turns n` | quarts de tour appliqués à la **caméra** |
| `--shot-rotate n` | quarts de tour appliqués au **bâtiment** à poser *(harnais Construction)* |

`--shot-hover` a une valeur par défaut plutôt que rien, parce qu'une capture qui ne
montre pas la surbrillance ne prouve rien à son sujet, et que souris à `(0, 0)` le
survol réel tomberait hors carte. `--shot-rotate` existe pour la même raison : sans
lui, aucune capture ne montrerait jamais un bâtiment pivoté.

**Écrire l'image hors du projet.** Une capture déposée dans l'arborescence est
importée par le prochain scan de l'éditeur, qui lui colle un `.png.import` à ranger
ensuite. Un chemin absolu hors de `res://` évite le ménage.

La capture du harnais Terrain imprime aussi une sonde : elle reprojette la cellule
désignée vers l'écran, retire un rayon depuis cette position comme le ferait la souris,
et dit si les deux tombent sur la même cellule. C'est le seul contrôle du raccord entre
la caméra orthogonale et le `CellPicker` — les tests unitaires tirent des rayons
fabriqués à la main, et les trois commandes de vérification ne regardent pas l'écran.

Celle du harnais Construction imprime à la place la ligne de survol : la cellule visée,
son terrain, et le verdict du domaine sur une pose à cet endroit. C'est la légende de
l'image — le fantôme y est vert ou rouge, cette ligne dit pourquoi.

**Les coordonnées de la sonde ne sont pas des pixels de l'image.** `project.godot` est
en `stretch/mode="canvas_items"` : le viewport garde la résolution de base du projet
pendant que la fenêtre, elle, suit `--resolution`. La capture sort donc à la taille de
la fenêtre, et tout ce que `unproject_position` ou `project_ray_*` manipule est en
coordonnées de viewport — plus petites d'un facteur constant. Comparer les deux sans
convertir fait apparaître des décalages qui n'existent pas.

C'est aussi ce qui rend une passe d'équilibrage visuelle tenable — comparer deux
valeurs de `step_height` revient à éditer un `.tres` et relancer deux fois.

**Deux captures ne se comparent que si leur ligne `cadrage` est identique.** Elle
donne le `camera.size` et la taille du viewport, et c'est le viewport qui décide de
tout : il garde la largeur de base du projet mais sa **hauteur suit le rapport de la
fenêtre**, donc `--resolution 1024x600` ne cadre pas comme `1280x720`. Le premier
lancement après un démarrage à froid n'obtient d'ailleurs pas toujours la fenêtre
qu'il a demandée. Une capture qui paraît « plus zoomée » qu'une autre est presque
toujours ça, et non le rendu qui a changé — au moindre doute, `cmp` sur les deux
`.png` tranche là où l'oeil se trompe.
