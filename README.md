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
faut le regarder. Le harnais Terrain accepte donc une capture en ligne de commande,
qui rend une image puis quitte.

```bash
"$GODOT_BIN" --path . --resolution 1280x720 -- --shot rendu.png --shot-turns 1
```

Les arguments après `--` sont ceux du jeu et non du moteur. `--shot-turns` est
optionnel : c'est le nombre de quarts de tour appliqués à la caméra avant la capture.

C'est aussi ce qui rend une passe d'équilibrage visuelle tenable — comparer deux
valeurs de `step_height` revient à éditer un `.tres` et relancer deux fois.
