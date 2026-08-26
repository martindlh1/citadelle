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
| `--shot-evenings n` | soirs résolus avant de capturer *(harnais Cartes)*, journées jouées *(harnais Run)*, scène à montrer *(harnais HUD)* |
| `--shot-view v` | cran d'affichage du HUD : `complet`, `essentiel`, `masque`, ou `aucun` *(harnais Run)* |

`--shot-view` existe pour la raison qui a valu son drapeau à `--shot-evenings`, et que
`I2` a reformulée en une phrase : **un écran qu'aucune capture ne peut atteindre est celui
que personne ne regardera.** Replier le rapport et masquer le HUD sont deux gestes qui ne
changent que l'image, donc les deux seuls dont ni le parsing ni les tests ne diront jamais
rien. `aucun` rend la carte entière sans rien dessus, ce qui est aussi la façon de
regarder un village de quinze journées.

Sur le harnais **Run**, `--shot-evenings 0` est un cas à part : il capture l'écran de
**fondation**, avant que le run n'ait commencé. C'est le seul état que les autres valeurs
ne peuvent pas atteindre, puisque toute journée jouée commence par poser le Cœur. La
valeur est comparée en texte et non convertie, pour distinguer un zéro écrit exprès d'un
drapeau absent.

`--shot-hover` a une valeur par défaut plutôt que rien, parce qu'une capture qui ne
montre pas la surbrillance ne prouve rien à son sujet, et que souris à `(0, 0)` le
survol réel tomberait hors carte. `--shot-rotate` existe pour la même raison : sans
lui, aucune capture ne montrerait jamais un bâtiment pivoté. Et `--shot-evenings` pour
une raison voisine mais plus forte : un rapport de fin de soirée est du texte fabriqué à
la main, donc exactement le genre de code que ni le parsing ni les tests n'atteignent —
sans ce drapeau, le chemin de résolution d'un harnais ne serait jamais emprunté par un
contrôle.

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

Celle du harnais Cartes imprime la ligne de survol **et** la table des actions posées :
quelle carte, sur quelle cible, combien de postes, et qui les tient. C'est ce qui a
attrapé le seul vrai bug de `D2` — deux *Récolter* sur une même cabane à deux postes, et
trois ouvriers dedans. Il ne se voyait ni au parsing, ni aux tests, ni à l'œil sur
l'image : il se lisait dans cette table.

Celle du harnais **Run** imprime le bandeau de phase, la **réserve chiffrée** et la ligne
de survol. Elle joue une journée entière par `--shot-evenings` plutôt qu'un geste : ouvrir
un chantier, le payer, y envoyer des ouvriers, le voir monter d'un cran et le relief se
creuser à côté. Une capture qui ne montrerait qu'une carte posée ne dirait rien de ce que
`I1` ajoute, et la réserve imprimée est la seule preuve que la bourse a bien été débitée.

Elle s'arrête **au milieu** d'une phase depuis `W2`, sur une dernière manche posée et
affectée qu'elle ne finit pas. Prise juste après une résolution, elle montrait un plateau
vide et six fiches oisives — c'est-à-dire tout sauf ce que le panneau d'affectation fait.
Elle remplit ces postes par le **bouton**, ce qui fait passer le chemin neuf du jalon sous
le seul contrôle qui regarde l'écran.

Depuis `I2`, elle joue le **run entier** et non plus une journée : `--shot-evenings 16`
fonde le village, traverse quinze journées, encaisse les trois vagues du calendrier et
s'arrête sur le bandeau de fin. Une vague qui tombe sur la dernière journée demandée reste
**en approche**, de sorte que les deux moitiés de la fin de journée — l'attente et la
facture — soient chacune atteignables en une commande. Elle imprime aussi une ligne
d'armées, pour la raison qui vaut déjà pour la réserve : un panneau de bataille masqué et
un panneau qui annonce zéro brèche se ressemblent beaucoup en capture, et ne disent pas du
tout la même chose.

Elle **n'imprime plus** le rapport du dernier soir : depuis `E2` c'est un panneau, et un
panneau se regarde. Le réécrire en texte à côté aurait donné deux mises en forme du même
rapport, dont une seule serait vérifiée par la capture — donc l'autre dériverait. `W2` lui
retire la **table des actions posées** pour la même raison, et à contrecœur : c'est elle
qui avait attrapé le seul vrai bug de `D2`. Elle est désormais dessinée par le panneau,
avec les ouvriers qui la tiennent, et la garder en texte aurait laissé la version imprimée
dire vrai pendant qu'une mise en page fautive cachait l'autre.

Le harnais **HUD** est le seul dont `--shot-evenings` ne désigne pas un temps mais un
**cas** : il ne joue rien, il fabrique des états — réserve pleine qui gaspille, famine,
phase du milieu de journée — qu'un vrai run met une dizaine de journées à atteindre. Il
réutilise le drapeau plutôt que d'en inventer un neuvième, ce que `dev_shot.gd` prévoit
en posant que chaque harnais ignore ceux qui ne le concernent pas.

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

## Les harnais qui n'affichent rien

Tous les harnais ne dessinent pas. Les harnais **Économie** et **Effectifs** sont des
rapports texte : ils impriment leurs tableaux sur la **sortie standard** en plus de
l'écran, donc

```bash
"$GODOT_BIN" --headless --quit --path .
```

suffit à le lire, sans capture ni fenêtre. C'est la même commande que la première
vérification, ce qui est voulu — un rapport qu'on ne voit qu'en lançant le jeu finit
par ne plus être lu du tout.

Ce rapport se termine sur un verdict d'équilibrage que les tests ne peuvent pas
donner, puisqu'ils travaillent sur des chiffres choisis : avec les valeurs de
`data/balance/`, qui casse en premier — la famine ou la réserve pleine.

Il tient aussi une **file de construction** depuis `E1b` : ce que la bourse refuse à
l'ouverture y reste, et le harnais en retente la tête un soir à la fois. La colonne de
droite dit donc aussi le soir où chaque bâtiment différé devient enfin payable.

Le harnais **Effectifs**, arrivé à `W1`, est le premier à composer **deux systèmes du
domaine** : chaque soir, l'Économie résout la production, les Effectifs distribuent
l'XP, et la main-d'œuvre est reprojetée avant le soir suivant — ce que
`RunOrchestrator` fera à `I1`. Sa table montre la récolte à côté du multiplicateur qui
vient de la produire, et son verdict répond à trois questions que les tests ne peuvent
pas poser : au bout de combien de soirs un ouvrier devient bon, ce que la spécialisation
rapporte une fois la troncature passée, et ce qu'une absence coûte.

Le harnais **Cartes** en faisait partie à `D1`, où il mesurait sur deux cents seeds ce
qu'un draft coûte en dilution. **`D2` l'a rendu graphique** : ce qu'il tabulait se lit
maintenant en jouant, exactement comme le rapport de `C1` a cédé la place à la scène de
`C2`. Son verdict statistique avait fait son travail et n'avait pas à être rejoué à
chaque lancement ; les chiffres restent dans l'entrée `D1` du journal.

Il a été le premier harnais où une **phase entière** se jouait : prendre une carte, la
poser sur une cible, y envoyer des ouvriers, résoudre le soir. Il compose trois systèmes
du domaine — Cartes, Économie, Effectifs — là où celui des Effectifs en composait deux.

Le harnais **Run**, arrivé à `I1`, est le seul qui ne montre pas un système mais **une
journée**, et le seul à ne plus appeler le domaine du tout : tout passe par
`RunManager`. Il lit son bandeau de phase et les gestes qu'il allume sur la `PhaseDef`
courante, jamais sur un nom écrit à l'écran — c'est ce qui fera de l'arbitrage de `I2b`
un échange de `.tres`. Une carte de bâtiment y affiche son coût et se voit refuser quand
la réserve ne suit pas, un chantier monte vraiment d'un cran, et le relief se creuse
vraiment. Il remplace le harnais Cartes comme scène de travail par défaut ; les autres
restent utiles pour isoler un système.

`Tab` y fait une seule chose, exprimée deux fois : elle agit sur ce que la carte tenue
**ferait**. Elle pivote un bâtiment, elle retourne un terrassement.

Son rapport distingue les **deux sortes de résolution** de la journée : chaque phase
imprime ce qu'elle a produit, et seule celle qui ferme la journée porte la ligne
d'upkeep, marquée « fin de journée ». Une ligne d'upkeep à zéro sur les autres phases se
lirait comme un soir où personne n'a mangé.
