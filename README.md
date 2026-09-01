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

Les **quatre** commandes qui doivent passer avant de considérer une tâche terminée sont
décrites dans [`CLAUDE.md`](CLAUDE.md#vérification-avant-de-conclure), avec les pièges
de la 4.7.2 qui expliquent pourquoi il en faut plusieurs et pas une.

La quatrième est entrée à `I3`, et elle a une histoire courte : deux fichiers hors
`src/domain/` ne compilaient plus depuis `R0` — un harnais orphelin et une fonction de HUD
qui prenait une classe supprimée — sans qu'aucune des trois autres ne puisse le dire. Le
boot ne charge que ce qu'un harnais actif référence, et la passe de parsing ne balaie que le
domaine. Il restait un angle mort de la taille de `src/adapters/`.

## Lancer une scène de dev

`scenes/dev/dev_boot.tscn` est la scène principale et le seul fichier de scène du
dossier. Le harnais à lancer se choisit dans la constante `HARNESS` de
`scenes/dev/dev_boot.gd`. Vide, on obtient le rapport de boot.

**`F11` bascule en plein écran**, quel que soit le harnais : la touche vit sur le pivot
et non dans un harnais, parce que c'est une propriété de la fenêtre et non de ce qu'on y
montre. C'est le mode *fullscreen* sans bordure, donc à la résolution du bureau.

Le décor sombre qu'on voit à gauche et à droite de la carte n'est **pas** du letterboxing :
`project.godot` est en `stretch/aspect = "expand"`, qui n'ajoute jamais de bandes. C'est le
cadrage — `CameraRig.frame()` cale la **diagonale de la carte sur la hauteur** de l'écran,
et la `size` d'une caméra orthogonale Godot est verticale. Sur un écran large il reste donc
du monde vide sur les côtés, à toute résolution : la molette zoome, `R` recadre.

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
| `--shot-rotate n` | quarts de tour appliqués au **bâtiment** à poser *(harnais Construction et Run)* |
| `--shot-passes n` | tours à résoudre avant de capturer *(harnais Run)* |
| `--chronicle` | rejoue le run entier sans écran et imprime la table, puis quitte *(harnais Run)* |

`--shot-hover` a une valeur par défaut plutôt que rien, parce qu'une capture qui ne
montre pas la surbrillance ne prouve rien à son sujet, et que souris à `(0, 0)` le
survol réel tomberait hors carte. `--shot-rotate` existe pour la même raison : sans
lui, aucune capture ne montrerait jamais un bâtiment pivoté.

**Les drapeaux ont fondu avec les harnais, à `R0`**, et `I3` en rend deux. Il en restait
quatorze avant le rescope, il en reste six. Les dix qui étaient partis servaient des harnais
supprimés ; `--shot-passes` remplace `--shot-evenings` pour un tour au lieu d'une journée en
phases, et `--chronicle` revient tel quel parce que la question qu'il pose n'a pas changé.

*Attention, ils n'étaient partis que du README.* `R0` les avait retirés du tableau ci-dessus
sans les retirer de `scenes/dev/dev_shot.gd`, si bien que le code et cette page se sont
contredits pendant deux jalons. Rien ne pouvait le dire : ce fichier n'a ni test ni écran.
Voir la quatrième commande de vérification.

La phrase qui les a fait naître, elle, ne bouge pas, et elle vaut pour ceux qui viendront :
**un écran qu'aucune capture ne peut atteindre est celui que personne ne regardera.** Le cas
le plus net était le repli d'un panneau — un état qu'aucune suite de journées ne produit,
puisqu'il ne s'obtient que par un geste. Corollaire appris à `P1a` : quand une vue se met à
commuter sur un état, vérifier **d'abord** qu'un drapeau atteint chacune de ses valeurs.

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

## Les harnais, après `R0` et `I3`

Il y en a **trois** : **Terrain**, **Construction** et **Run**. `R0` en avait supprimé sept
sur neuf, tous ceux qui exerçaient l'Économie d'avant, les Effectifs, les Cartes, le Combat,
la Bataille et le HUD. `I3` rend le Run, et il redevient le harnais **par défaut** pour la
raison qui l'a fait venir tôt dans l'ordre des jalons : un projet qui ne se lance pas est un
projet dont on ne mesure plus rien.

Le harnais Run tient le seul geste du jeu — fonder, bâtir, démolir, passer le tour — et il
imprime deux choses qu'aucun autre contrôle ne regarde. Sa **capture** montre l'écran après
`n` tours résolus ; sa **chronique** rejoue le run entier sans écran et rend un tableau,
tour par tour, jusqu'au verdict :

```bash
"$GODOT_BIN" --headless --path . -- --chronicle
```

C'est le seul contrôle du projet qui joue la boucle complète sur la data réelle — ni le
parsing ni les tests n'enchaînent vingt tours. Il n'arbitre rien et le dit en toutes lettres :
la politique qu'il joue est bête, donc ses chiffres sont un **plancher** et non une partie
bien jouée.

**Ce qui revient encore, et quand.** La génération mesurée sur deux cents seeds à `T4`, la
Bataille à `V2`. Le harnais de l'Économie ne revient pas : ce qu'il montrait — le repas, la
famine, la réserve qui se remplit — se montre dans un tour, ce qui est le seul endroit où ces
chiffres veulent dire quelque chose. Ajouter un harnais reste un `.gd` et une ligne de
`HARNESS_SCRIPTS` — jamais une scène, jamais une intervention dans l'éditeur.

Trois leçons de la famille survivent aux harnais qui les ont produites, et elles valent
d'autant plus pour ceux qu'on écrira à neuf :

**Un harnais qui mesure doit être lu, pas seulement lancé.** Un tableau de chiffres compile,
s'aligne, ne lève aucune erreur, et peut être **faux sur ce qu'il prétend montrer** — ce qui
est pire qu'une panne, parce qu'on lui fait confiance. D'où la discipline : chaque table
annonce en toutes lettres ce qu'elle doit montrer, et le verdict de fin dit ce qu'elle ne
montrera jamais.

**Une table choisit son moment, et l'écrit dans son titre.** Deux colonnes issues du même
compteur ne prouvent rien en se ressemblant ; une mesure qui emprunte un raccourci mesure le
raccourci ; une mesure prise au mauvais instant répond à une autre question que la sienne. Le
test qui les attrape toutes est le même — *cette table pourrait-elle rendre ce chiffre-là
sans que la règle qu'elle prétend montrer existe ?*

**Un rapport qu'on ne voit qu'en lançant le jeu finit par ne plus être lu.** Les harnais qui
ne dessinent pas impriment sur la **sortie standard** en plus de l'écran, de sorte que

```bash
"$GODOT_BIN" --headless --quit --path .
```

suffise à les lire — la même commande que la première vérification, ce qui est voulu.

**Et un chemin de capture emprunte les fonctions de geste du harnais**, ou il refait leur
rafraîchissement à la main. Une capture scriptée qui appelle le domaine en direct ne redessine
rien : c'est ainsi que toutes les captures du projet ont montré pendant trois jalons une main
d'avant leurs propres poses.
