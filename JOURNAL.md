# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

---

## 2026-09-02 — `T4` (suite) : la mesa jetée, et un village qui descend du centre

**État : terminé.** Branche `feat/t4-terrain-gen`, tirée de `feat/n2-population-view` — `N2`
n'était pas encore fusionnée, et les deux le sont ensemble, dans cet ordre. Les quatre
commandes passent et **433 tests sont verts**. Le relief est resté sur `ridges` : `peak` ouvre
trop d'accès, `crest` assèche la carte.

### La mesa est jetée, et le motif ne se mesure pas

Le verdict est tombé en une phrase : *« le terrain fait complètement artificiel, on perd tout
le charme de la map »*. La mesa tenait pourtant toutes ses promesses **par construction**,
c'était son argument, et la revue de deux cents seeds le disait en chiffres.

C'est très exactement ce qui rend le cas intéressant. **Aucune table du projet ne sait rendre
ce critère-là**, et l'entrée d'hier le disait déjà sans en tirer la conséquence : « la table
dit qu'une carte est jouable, ce qui est le plancher et non l'objectif ». Un plancher tenu ne
rachète pas un résultat qu'on n'a pas envie de regarder. La leçon est montée dans `CLAUDE.md`,
parce qu'elle ne concerne pas que le terrain.

Ce qui la remplace est le bruit d'avant, **penché** : un centre un peu plus haut, des crêtes
qui barrent parce qu'elles sont hautes et non parce qu'on les a taillées. Trois techniques
empilées dans un `enum` exclusif sont devenues **deux axes qui se composent** — la nature du
bruit, la colline —, parce que l'`enum` interdisait justement la combinaison qu'on cherchait :
des crêtes *et* une colline au milieu.

### L'ordre des opérations, raté deux fois de suite

Pencher le bruit **puis** l'étaler donne une **île** : la colline pousse le centre bien
au-dessus de l'amplitude, l'étalement ramène tout le monde dedans, et le pourtour se retrouve
poussé sous la nappe. Pencher **puis borner** donne un sommet **plat de cent cases**,
c'est-à-dire la mesa qu'on venait de retirer, revenue par la porte de derrière.

Étaler d'abord règle les deux, et la colline prend ensuite une **part** de l'amplitude au lieu
de s'y ajouter. Le corollaire s'est payé plus tard : une colline forte et **étroite** ne laisse
presque rien au bruit au-delà de sa portée, donc noie le pourtour — c'est la même île sous un
autre nom, et il a fallu une revue rendant le **même chiffre pour trois enjambées différentes**
pour cesser d'accuser la marche et regarder l'eau.

### La décision du jalon : le village descend du centre

L'audit ne reçoit plus son plateau, il le **cherche**. Un relief bruité n'a aucune raison de
laisser une place à bâtir sur une case nommée d'avance : sur des crêtes, le centre géométrique
est le plus souvent un **pic**, donc un replat d'une seule case — la revue disait « plateau
1 case » sur les plus belles cartes du lot. Auditer là revenait à noter une carte sur un pixel.

La règle est donc celle qu'un joueur devinerait tout seul : **on fonde où le terrain le permet,
au plus près du centre.** `min_plateau_cells` cesse d'être un seuil et devient une **consigne de
recherche** ; le seuil qui juge est la **dérive**, la distance entre le village et le milieu.
Sur deux cents brouillons, le replat de seize cases se trouve à deux cases du centre en médiane.

Trois choses en sont tombées d'elles-mêmes :

- **La clairière centrale ne sert plus à rien**, et c'est mieux ainsi. Un replat trouvé en
  marchant est plat *parce qu'il a été trouvé plat* ; la clairière, elle, rabotait au passage
  les gisements sur lesquels le village démarre — médiane 0 avec, 3 sans.
- **Deux noms de variante sont devenus identiques à `data/`** le jour où la clairière est
  passée à zéro. Une table qui annonce une différence qu'elle ne montre plus est le défaut que
  ce projet traque depuis `F1` ; les deux sont supprimés.
- **La capture désigne le site trouvé** au lieu du milieu de la carte. C'est la règle
  d'`R0` — un état qu'aucune capture n'atteint est un état que personne ne regardera — et ici
  elle a un bonus : le rapport imprime la même case, donc l'image et le chiffre se contredisent
  si l'un des deux ment.

### Les promesses mordent enfin

Elles ne refusaient rien : 0 rejet sur 200. Trois sont maintenant serrées sur ce que
`DESIGN.md` 3.1 dit depuis toujours — **jamais un seul accès, jamais douze** — et la revue rend
109 rejets pour **2,15 essais** par carte, neuf au pire, les deux cents seeds rendant tous une
carte. La quatrième, la surface bâtissable, reste un plancher pour une molette tournée demain,
et c'est un **cas de test** qui le fait refuser plutôt qu'une revue serrée à la main puis
desserrée : le contrôle reste, là où le serrage manuel s'oublie.

### Un test qui prouvait une propriété qu'on venait de retirer

`test_the_forest_ceiling_does_not_shift_the_scatter_stream` a échoué trente-deux fois. Il avait
raison : la dispersion en **bandes** posait chaque famille sur un tirage par cellule, donc un
plafond de forêt ne consommait rien et les gisements ne bougeaient pas. La dispersion **par
zones** prend une part exacte au classement — d'où des bosquets et des éboulis plutôt qu'un
semis —, et le classement de la forêt change ce que la passe suivante trouve libre.

Le réflexe à ne pas avoir était de le rafistoler. Il a été remplacé par ce que le nouveau modèle
garantit **et** que l'ancien ne garantissait pas : une famille prend une part **exacte** de la
terre ferme, et deux familles ne réclament jamais la même case. C'est le piège du seuil qui
avait déjà coûté une passe sur l'eau, où « douze pour cent » avait rendu zéro case.

### La force de la colline, tranchée en capture

Trois variantes posaient la question, et les deux qui poussaient la colline coûtaient chacune
quelque chose de **mesurable**, ce qui a rendu l'arbitrage court : `peak` — colline forte et
large — ouvre plus d'accès, donc moins de goulots ; `crest` — amplitude 0..15 — **assèche la
carte**, un toit plus haut relevant tout le monde au-dessus de la nappe, et la ligne `water`
disparaît du tableau. `ridges` garde ses 7,9 % d'eau et son découpage. C'est lui qui reste.

`--gen` survit au choix, avec ses cinq noms : la question « jusqu'où pencher » se reposera à
`B1`, et un drapeau qui la rejoue coûte moins que de la réoutiller.

**Aucun chiffre n'est équilibré pour autant.** Densités, portée de la colline, taille minimale
d'un lac : des points de départ choisis pour que la carte se lise.

---

## 2026-09-01 — `T4` : la mesa, et deux défauts qu'aucune image ne montrait

> **Renversée le lendemain.** La mesa décrite ci-dessous a été retirée entière : elle tenait
> ses promesses et ne ressemblait à rien. Ce qui suit reste tel quel — un journal enregistre ce
> qui a été décidé, pas ce qu'on aurait voulu décider —, et deux choses lui survivent :
> `MapAudit`, qui n'a pas eu à bouger d'une ligne, et la doctrine des tables. Voir l'entrée
> au-dessus.

**État : terminé.** Branche `feat/t4-terrain-gen`, tirée de **`feat/n2-population-view`** et
non de `master` — `N2` n'est pas encore fusionnée, et travailler sur un arbre sans le HUD du
jalon précédent aurait fait mentir toutes les captures. Les quatre commandes passent : boot
sans erreur ni warning, tout `src/domain/` parse, tout `src/adapters/` et `scenes/dev/` aussi,
et **431 tests verts contre 400**. Deux captures, une revue de deux cents seeds, et une sonde
ASCII jetable sans laquelle rien de ce qui suit n'aurait été trouvé.

`TerrainGen` cesse d'espérer. C'est ce que `DESIGN.md` 3.1 lui demande depuis le rescope, et
la phrase qui porte le jalon est de lui : « bruiter puis espérer est ce qui ne peut pas donner
de garantie ».

### La forme retenue : une mesa

Le document laissait le choix ouvert — il demandait un plateau central, des accès bornés, une
surface plate, et ne disait pas **par quoi** le plateau est isolé. La réponse retenue est la
plus littérale : un plateau surélevé, une plaine plus basse tout autour, et des **rampes**
taillées en marches franchissables pour seules montées.

Elle a une propriété qu'aucune autre n'avait, et c'est elle qui a décidé. La plaine est
bruitée dans une amplitude **bornée sous le seuil d'enjambée** ; il devient alors impossible
qu'un bruit ouvre un accès que personne n'a voulu. La garantie des accès n'est pas vérifiée
après coup, elle est **structurelle** — et c'est `TerrainGenBalance.missing_fields()` qui la
tient, en refusant au boot un réglage où la plaine toucherait le plateau.

C'est le geste du bloc `production` nullable de `E1b`, transposé : rendre une cohérence
**structurelle** au lieu de vérifiée. Le jour où l'on voudra une plaine qui touche le plateau,
c'est le contrôle qui se desserre, pas la génération qui se met à espérer.

### Le vérificateur ne sait rien du générateur, et c'est tout son intérêt

`MapAudit` retrouve le plateau par un parcours, compte les accès en marchant depuis la
lisière, et mesure la place à bâtir en essayant d'y poser une empreinte 2x2. Il ne reçoit que
la carte et une cellule de repère.

C'est la règle des tables appliquée à un contrôle. Un audit à qui la génération dirait « j'ai
creusé trois rampes » rendrait trois accès sur une carte dont deux rampes se sont rejointes,
ou dont une est bouchée par un rocher — il répéterait au lieu de vérifier. Et le rejet du seed
n'a de sens que si le juge est indépendant de l'accusé.

**Il sert deux fois, et c'est ce qui en fait une classe** plutôt que trois fonctions privées :
la génération l'appelle pour rejeter, le harnais pour imprimer une distribution. Les deux
lisent le même rapport, ce qui est la seule façon d'être sûr que la table décrit les cartes
qu'on joue.

### Deux défauts que seule une carte imprimée en chiffres montrait

Ils sont de la même famille et méritent d'être notés ensemble, parce que cette famille est
neuve : **une capture d'un relief ne dit pas si l'on peut y marcher.**

**L'eau demandée en part se comportait en seuil.** `water_share` valait 0,12 et la génération
comparait le bruit à ce chiffre — ce qui paraît la même chose et ne l'est pas : un bruit
simplex se serre autour de sa moyenne, si bien que « douze pour cent » rendait **zéro** case
d'eau sur mille. Le champ portait un nom de proportion et faisait autre chose. On classe
maintenant les cases de plaine par leur bruit et l'on noie les plus basses, ce qui rend au
champ le sens qu'il annonce.

**Et une rampe en diagonale s'écrasait elle-même.** Une rampe passe par des cases d'angle, ses
voies se chevauchent d'un cran à l'autre, et « le dernier qui écrit gagne » veut alors dire
que le cran **bas** efface le cran haut. L'escalier perdait une marche, donc devenait une
marche de deux crans, donc infranchissable. La rampe était parfaitement dessinée à l'écran,
elle ne se montait pas, et l'audit rendait « un accès de moins » sans que rien ne dise
pourquoi. Deux des cinq crans disparaissaient ainsi.

Le correctif est de **planifier toutes les rampes avant de les poser et de garder le plus
haut**, ce qui rend l'escalier monotone par construction : il n'y a plus à vérifier qu'une
rampe se monte. Une rampe est devenue au passage un **remblai** et jamais une tranchée — elle
ne descend rien de ce qui était là, donc elle n'entame pas le plateau et comble l'étang
qu'elle traverse.

Aucun des deux ne se voyait sur une capture, et les deux se lisaient d'un coup sur une carte
imprimée en chiffres. **Une sonde ASCII jetable, trente lignes, lancée sous `-s` : c'est
l'instrument du jalon**, au même titre que la revue de seeds. Le relief se regarde en image ;
ce qui s'y marche se lit en nombres.

*Un troisième défaut de la même veine, trouvé en même temps : une rampe large de deux n'en
faisait qu'une. Les voies étaient étalées sur la perpendiculaire réelle, et sur une diagonale
un décalage d'un demi-pas arrondit sur la même cellule. Elle se dessinait, elle se montait,
elle était simplement deux fois plus fragile qu'annoncé.*

### La franchissabilité entre en data

`TerrainData` gagne un `walk`, réclamé comme son `build`. C'est la colonne **Franchissable**
du tableau de `DESIGN.md` 3.1, qui existait dans le document et nulle part ailleurs.

**Deux champs et non une déduction**, alors que les cinq terrains de `data/` répondent la même
chose aux deux questions. C'est précisément pourquoi il en fallait deux : une franchissabilité
déduite de la constructibilité aurait passé la suite entière et se serait trompée en silence
le jour d'un marécage — qu'on traverse et sur quoi l'on ne bâtit pas. Un cas de test tient
cette distinction en fabriquant le marécage.

`TerrainQuery` gagne `is_walkable()` pour ce que la case est, et `can_step()` pour ce que le
marcheur peut enjamber. La hauteur d'enjambée arrive **en argument** : ce n'est pas le terrain
qui grimpe. Elle vit dans `TerrainGenBalance` en attendant `V1`, parce que la génération en est
aujourd'hui le seul lecteur.

### Ce que la revue de deux cents seeds a rendu

`--survey` tire deux cents brouillons et imprime leur distribution. Sur les réglages du jour :

```
  accès      0:1  1:13  2:77  3:75  4:34
  plateau    min  133  méd  148  max  165 cases bâtissables
  assises    min  403  méd  463  max  529 emplacements 2x2
  gisements  min    3  méd    9  max   16 sur le plateau
  lisière    min   -1  méd   10  max   15 pas jusqu'au plateau
  rejets     14/200 brouillons — accesses_too_few 14
  retenues   200/200 seeds, 1.08 essai(s) en moyenne, 3 au pire
```

**Elle mesure les brouillons et le dit**, parce qu'une distribution prise après rejet serait
bonne par construction, donc muette. Les deux dernières lignes disent séparément ce que le jeu
reçoit — et elles viennent de `TerrainGen.accepted_attempt()`, c'est-à-dire de la boucle que
`generate()` emprunte, jamais d'une copie écrite dans le harnais. Une boucle recopiée aurait
mesuré la copie, sous la forme la plus perfide du raccourci que `CLAUDE.md` nomme depuis
`F1` : les deux auraient été justes le jour où on les a écrites.

C'est cette table qui a **placé les seuils**, et l'ordre compte — les promesses ont été
laissées lâches pendant l'écriture, mesurées, puis serrées. Trois d'entre elles sont des
**planchers** — taille du plateau, surface bâtissable, gisements — et elles ne mordent pas sur
les réglages du jour : c'est leur métier, elles protègent d'une molette tournée demain. La
quatrième, la fourchette d'accès, est le vrai filtre, et c'est elle qui rejette les quatorze.

**Un plancher qui ne refuse jamais se vérifie en le faisant refuser**, et c'est `N1` qui a
laissé cette règle au projet. Les trois ont donc été serrés une fois exprès : la revue est
passée de 14 rejets sur 200 à **185**, et 28 seeds n'ont plus rien trouvé en 24 essais. Ils
refusent, et la table nomme lesquels.

*Un piège de mesure évité de justesse : `min_accesses` et `max_accesses` sont **à la fois**
l'intervalle dans lequel la génération tire son nombre de rampes et celui que l'audit exige.
Laissés lâches « pour mesurer d'abord », ils ont fait creuser jusqu'à trente-deux rampes. Un
champ de promesse qui est aussi une entrée ne se desserre pas impunément.*

### Le relief ne se voyait pas, et c'est un défaut de jalon

La première mesa était juste en chiffres et **invisible en image** : trois crans à 0,25 de
haut sur une carte de trente-deux cases, sous une forêt qui couvrait aussi le plateau. Pour un
jalon dont toute la thèse est que le relief *est* la carte de tower-defense, une carte qui se
lit comme une plaine est un échec, quoi qu'en dise l'audit.

Trois chiffres de `data/balance/` l'ont réglé, et c'est le bon endroit : le plateau monte à 6
au lieu de 4, le cran passe de 0,25 à 0,35 — le premier réglage de `T2` qui bouge depuis
`T2` —, et la forêt s'arrête un cran sous le plateau. Le dernier fait le plus gros du travail :
un plateau **dégagé** se lit comme une table, et il dit du même coup où l'on bâtit.

### `--harness`, et pourquoi il fallait l'ajouter maintenant

La revue vit chez le harnais Terrain alors que le harnais par défaut est le Run. La mesure du
jalon n'était donc atteignable qu'en éditant une constante et en relançant — c'est-à-dire, en
pratique, jamais.

C'est la phrase que `P1a` a laissée au projet, appliquée un cran plus haut : **un état
qu'aucune ligne de commande ne peut atteindre est un état que personne ne regardera**, et un
harnais est un état comme un autre. Six lignes dans le pivot de boot, et `HARNESS` reste ce
qu'il était pour le travail à la souris.

### Ce que je n'ai pas fait

**Pas de `ore`.** `DESIGN.md` 3.1 décrit un Filon à côté du Gisement ; il n'existe pas en data,
et il n'a toujours aucun lecteur — la production est plate depuis `I3`, et c'est l'adjacence de
`C3` qui lira un tag de terrain pour la première fois. `MapAudit.DEPOSIT_TAGS` l'attend en un
mot.

**Aucun contrat n'entre dans `contracts/`**, et la table y reste à quatre lignes pour le
quatrième jalon d'affilée. `MapReport` vit dans `domain/terrain/` : la génération le produit et
le consomme, le harnais le lit, et aucun **second système du domaine** ne le franchit. Le jour
où les Vagues voudront connaître les cols avant de choisir par où entrer, il déménagera.

**Pas de marquage des cols à l'écran.** Le harnais les imprime en clair et la surbrillance en
désigne un ; les peindre tous demanderait une passe de rendu, et rien dans ce jalon ne
l'exige.

**Et la politique de la chronique n'a pas appris le plateau**, ce qui se voit en capture : elle
pose ses bâtiments dans le coin de la carte, en pleine plaine, parce qu'elle balaie depuis
(0, 0). Ce n'est pas encore un mensonge — la chronique mesure la boucle économique, et
l'Économie ne voit pas le relief —, et c'est d'ailleurs pourquoi elle rend **exactement les
mêmes 265 points** qu'avant `T4` sur une carte entièrement refaite : la meilleure confirmation
possible de ce que `I3` avait écrit. Ça le deviendra à `V4`, le jour où bâtir hors du plateau
voudra dire se faire manger. C'est la règle que `CLAUDE.md` tient depuis `I3` — une table dont
le pilote ne joue jamais la règle ne montre pas cette règle —, et elle attend son jalon.

**Aucun chiffre n'est vraiment équilibré.** Le rayon du plateau, la densité des étangs, la
part de forêt et la hauteur de la mesa sont des points de départ, choisis pour que la carte se
lise. C'est `B1`, et `--survey` est l'instrument qu'il réclamera.

### Prochain jalon

**`V1`** — le chemin. `DESIGN.md` 8 le place juste après `T4`, et la raison est maintenant
visible en capture : les cols existent, donc un chemin veut dire quelque chose. Il héritera de
`is_walkable()` et de `can_step()`, qui ont été écrits pour lui autant que pour l'audit — et
la hauteur d'enjambée déménagera le jour où une vague aura la sienne.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut toujours `&"run"`**, et `--harness terrain` suffit désormais pour la revue.
- **Deux drapeaux neufs** : `--harness <id>` choisit le harnais, `--survey` tire deux cents
  cartes et imprime leur distribution.
- **Les cinq `.tres` de terrain gagnent un `walk`.**
- **`data/balance/terrain_gen_balance.tres` est refait** : `min_height` et `max_height`
  disparaissent — l'amplitude du relief est devenue une conséquence de la structure — et
  onze champs entrent, dont les quatre promesses.
- **`data/balance/terrain_balance.tres` change son `step_height`**, de 0,25 à 0,35. C'est le
  premier réglage de `T2` qui bouge depuis `T2`, et il bouge parce que `T4` fait du relief un
  élément de jeu et non plus un décor.
- **La branche est tirée de `feat/n2-population-view`** et non de `master` : `N2` n'est pas
  fusionnée. Les fusionner dans l'ordre, `N2` puis `T4`.
- **La branche n'est pas fusionnée** : `feat/t4-terrain-gen`, six commits.

---

## 2026-09-01 — `N2` : la fiche avant le clic, et un recouvrement que seule une sonde voyait

**État : terminé.** Branche `feat/n2-population-view`, tirée de `master` après la fusion de
`I3`. Les quatre commandes passent — boot sans erreur ni warning, tout `src/domain/` parse,
tout `src/adapters/` et `scenes/dev/` aussi, et **400 tests verts contre 390**. Six captures,
et une sonde de plus.

Le jalon est un jalon d'écran, donc son vrai livrable est ce qu'on regarde : quatre fichiers
neufs dans `src/adapters/hud/`, deux fonctions de plus dans le domaine, un champ dans
`data/`, et le harnais Run réorganisé autour d'une colonne de panneaux.

### Ce que `DESIGN.md` demandait, et ce qui a suivi

Le jalon tient en une phrase de 3.4 : « le coût en main-d'œuvre d'un bâtiment devient une
ligne de sa fiche, **lisible avant de le poser**, exactement comme son coût en bois ». Ce
n'est pas du confort — les travailleurs sont le **seul** régulateur du jeu depuis le rescope,
et un régulateur qu'on ne découvre qu'au refus n'en est pas un.

D'où la `BuildingCard` : elle décrit ce que le clic gauche poserait, avec ses trois coûts,
ce qu'il rend, et ce qui manque pour l'ouvrir. Elle a poussé le reste devant elle — la
`PopulationBar` pour que « il manque 2 bras » ait un compteur à côté de lui, et le catalogue
texte hors du rapport, parce qu'une table de chiffres à côté d'une fiche de chiffres est un
doublon qui ment la moitié du temps.

### « Combien manque-t-il ? » est une question du domaine

C'est la décision qui porte le jalon, et elle a élargi une règle du projet plutôt que de
l'appliquer. `CLAUDE.md` disait déjà qu'« est-ce plein ? » se demande au domaine ; il ne
disait rien des **écarts**, si bien qu'une vue qui voulait annoncer « il te manque 5 bois »
n'avait d'autre choix que de soustraire elle-même.

`Ledger.shortfall()` et `Staffing.hands_short()` entrent donc dans le domaine, et leurs
formes en oui/non — `can_afford()`, `has_the_hands()` — sont **réécrites avec eux** : deux
boucles qui comparent la même chose sont deux occasions de diverger, et celle qui décide
n'est pas forcément celle qu'on lit. Un cas de test épingle l'égalité des deux réponses,
précisément pour qu'on ne puisse pas réécrire l'une sans l'autre.

**Le cas des bras rend la chose obligatoire plutôt que jolie.** La question se pose à la
**demande totale** de la ville et non aux bras que le plan laisse libres — c'est
`DESIGN.md` 3.2, « ce que le village peut posséder » —, et l'écart entre les deux n'est pas
nul : une ville qui a déjà un endormi rend `available() == 1` alors qu'ouvrir un chantier
d'un bras y creuserait le manque. Une fiche qui aurait comparé son coût à `available()`,
c'est-à-dire au chiffre affiché juste en dessous d'elle, aurait donc été **plus permissive
que la règle** et invité à un geste que `open_site()` refuse.

C'est la leçon générale : un seuil recopié dans un adapter ne se contente pas de doubler, il
se trompe dans le sens qui se voit le plus tard. La fonction était privée chez
`RunOrchestrator` ; elle est publique chez `Staffing`, et l'orchestrateur l'appelle comme
tout le monde.

### Les deux barres ont la même forme, et c'est `N1` rendu visible

`N1` avait écrit que `Population` est le jumeau de `Ledger` — une quantité, une capacité que
des bâtiments relèvent, un écrêtage quand elle baisse. Tant que la population n'était qu'une
ligne de texte, c'était une affirmation de docstring.

Les deux vues partagent maintenant la même `SegmentedGauge`, extraite de `ResourceBar`, et
la règle qu'elle portait seule depuis `E2` — **le reste de la division va à la place libre,
jamais à une part** — est justement celle que la seconde devait avoir aussi. Un plafond
atteint n'a donc jamais de place libre à l'écran, ni pour du bois ni pour des habitants.

*Corrigé après une première version, sur retour de l'humain.* La `PopulationBar` portait en
plus une pastille « Habitants » et la liste de ce qui dort ; les deux sont parties. La
première était la **somme des deux autres**, que la jauge écrit déjà à droite — un troisième
chiffre qui n'apprend rien et qui donne à cette vue une forme que sa jumelle n'a pas. La
seconde n'est pas de la même nature que le reste du panneau : un compteur montre des
nombres, une liste d'endormis **nomme des choses posées sur la carte**. Elle est allée dans
le rapport texte, à côté des chantiers ouverts.

### Ce qui dort se dit deux fois, et la bonne des deux est le plateau

`DESIGN.md` 3.3 veut qu'un joueur puisse se dire « cette ferme dort, il me manque un toit ».
Le mot qui compte est **cette** : il désigne une case, et aucune ligne de texte ne désigne
une case. Une liste de coordonnées dans un HUD demande de chercher sur la carte ce que la
carte peut montrer elle-même.

`BuildingRenderer` éteint donc les endormis en couleur — une teinte **froide**, là où celle
d'un chantier est chaude. Les deux états se ressemblent, ni l'un ni l'autre ne produit, et
ils se distinguent quand même parce que ce qu'ils demandent au joueur n'est pas la même
chose : un chantier veut qu'on attende, un endormi veut un toit. Le sommeil s'applique
**après** le gris de chantier et non à sa place, sans quoi un chantier endormi — qui est les
deux à la fois — n'en montrerait qu'un.

Le renderer n'apprend rien de tout ça : on lui donne des ancres, il les éteint, exactement
comme `hidden` depuis `F3a` ignore qu'une bataille existe.

### Le défaut du jalon : un recouvrement qu'aucune capture ne montrait

C'est le résultat le plus utile, et il a été trouvé par une sonde écrite le matin même.

Le rapport texte est en haut à gauche, la colonne de panneaux en bas à droite. Les deux ne se
touchaient pas — trente-trois pixels d'écart vertical — **sauf au premier tour**, où le
rapport porte deux chantiers de plus : la dernière ligne des touches passait alors sous la
fiche, qui la coupait net. Une phrase tronquée se lit comme une phrase qui s'arrête, pas
comme un défaut, et les captures du jalon étaient prises plus tard dans le run, où le rapport
plus court ne touchait rien.

La règle qui en sort : **deux blocs de HUD se séparent par la largeur, jamais par la
hauteur.** Dans un HUD, une dimension suit la partie et l'autre non — la hauteur d'un rapport
suit les chantiers ouverts, les lignes du tour, les endormis, alors que sa largeur ne dépend
que de ce qu'on écrit dedans. Compter sur l'écart vertical, c'est parier sur le village le
plus chargé qu'on verra un jour, et c'est le pari que `W2` et `P1b` ont tous les deux perdu.
Le catalogue est donc passé à trois colonnes et les touches à quatre lignes courtes, et la
largeur du rapport ne bouge plus.

Et la sonde est `P1b` dit une troisième fois : deux `Rect2` pris en `global_position`, leur
`intersection()`, un `encloses()` contre le viewport. Cinq lignes, un chiffre dans le repère
de la mise en page plutôt que dans les pixels de l'image, et il s'imprime désormais sur
**toutes** les captures suivantes au lieu d'être redécouvert.

### Deux états que rien ne pouvait photographier

Corollaire de `P1a`, appliqué avant d'en avoir besoin cette fois : quand une vue se met à
commuter sur un état, vérifier **d'abord** qu'un drapeau atteint chacune de ses valeurs.

La fiche commute sur quatre états — coût couvert, réserve courte, bras courts, les deux. Or
« réserve courte » ne s'obtient qu'en désignant un bâtiment qu'on ne peut pas payer, et rien
ne permettait de choisir un bâtiment depuis la ligne de commande : d'où `--shot-select`. Et
elle décrit le **Cœur** tant que le run n'est pas fondé, alors que toute capture fondait
d'office pour ne pas photographier une carte nue : d'où `--shot-unfounded`. Les deux états
existaient dès la première version ; aucun n'était joignable.

Le second a d'ailleurs révélé un défaut de plus : le curseur de cellule cessait de piocher
sous la souris à l'intérieur de `_place_at()`, donc uniquement sur le chemin qui fonde. Sans
fondation, le survol retombait sur la position réelle de la souris — `(0, 0)`, hors carte —
et la capture ne montrait aucun fantôme.

### Le Cœur sort du catalogue numéroté

`open_site()` le refuse par principe depuis `I3` : le Cœur se **fonde**, il ne se bâtit ni ne
se démolit *(`DESIGN.md` 4.2)*. Il occupait pourtant une touche du catalogue, donc une touche
qui ne pouvait mener qu'à un refus — la règle de `I2b` appliquée à une liste, une vue qui
invite à un geste doit demander si le geste est possible. `I3` avait corrigé le domaine, qui
acceptait d'en ouvrir un second ; ce jalon corrige l'écran, qui le proposait encore.

Sa fiche reste atteignable, au seul moment où elle veut dire quelque chose : tant que le run
attend son Cœur, c'est lui que le fantôme dessine et lui que la fiche décrit. Les deux
passent d'ailleurs par le **même** appel, ce qui est ce qui les empêche de parler de deux
choses différentes.

### Un champ dans `data/`, et pourquoi il n'invente rien

`BuildingData` gagne un `label`, réclamé comme celui d'une `CommodityData`. Sans lui la fiche
s'intitulait `lumberjack_hut`, c'est-à-dire un identifiant interne montré à qui regarde le
jeu.

Il **ne nomme rien de neuf** : les neuf noms sont ceux que `DESIGN.md` 4.1 a fixés, recopiés
dans la data au lieu de rester dans un tableau de document. C'est la seule fois du projet où
le contenu d'une table de ce document est entré dans un `.tres`, et 4.1 le dit maintenant.
Même partage qu'à `E2` pour les ressources : un identifiant sert le code, un libellé sert
l'écran, et le second n'a aucune raison d'être le premier traduit à la volée par un adapter.

### Recopié trois fois, c'est un fichier qui manque

`ResourceBar` tenait seule un style de panneau, une fabrique de `Label` et sept teintes ; les
deux vues du jalon en voulaient les mêmes. Trois copies de `FULL_COLOR` finissent par ne plus
être la même couleur, et le jour où ça arrive personne ne sait laquelle est la bonne. D'où
`HudStyle`, qui ne porte que de la **mise en forme** — et c'est pourquoi ses nombres ne sont
pas dans `data/balance/`, réservé aux questions encore ouvertes de `DESIGN.md`.

C'est la deuxième fois que ce raisonnement se tient : `E2` l'avait fait pour
`CommodityPalette`, sur un `_bundle_text()` écrit deux fois qu'un troisième appelant allait
tripler.

### Ce que je n'ai pas fait

**Aucun contrat n'entre dans `contracts/`**, et la table y reste à quatre lignes pour le
troisième jalon d'affilée. Rien de ce jalon ne franchit une frontière entre deux systèmes du
domaine : `shortfall()` et `hands_short()` rendent des types nus, et tout le reste est de
l'adapter.

**Aucun test d'adapter.** `CLAUDE.md` : `src/adapters/` n'est pas testé. Le contrôle du jalon
est la capture, et la sonde de mise en page est là pour ce qu'une capture ne dit pas.

**Aucun chiffre n'est équilibré.** La chronique rend exactement les mêmes vingt lignes
qu'après `I3` — 265 points —, ce qui est le contrôle qu'aucune règle n'a bougé.

**Pas de survol de fiche à la souris**, pas d'infobulle sur un refus, pas de repli de
panneau. Ce sont des jalons de confort de la famille `P`, et il n'y en a pas au programme :
`DESIGN.md` 8 enchaîne sur `T4`.

### Prochain jalon

**`T4`** — la génération garantie. `DESIGN.md` 8 la place avant `V1` et donne la raison : on
ne teste pas un pathing sur des cartes qui n'ont pas de cols. Les six captures de ce jalon la
redisent — le relief du seed 1234 est du bruit uniforme, sans plateau central ni goulot, et
la politique de la chronique pose ses bâtiments dans un coin parce que rien sur cette carte
ne suggère où les mettre.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut toujours `&"run"`.**
- **Deux drapeaux de capture neufs** : `--shot-select n` choisit un bâtiment comme au
  clavier, `--shot-unfounded` saute la fondation pour photographier l'écran qui l'attend.
- **Les neuf `.tres` de bâtiment gagnent un `label`**, celui de `DESIGN.md` 4.1.
- **Le catalogue numéroté passe de neuf à huit entrées** — le Cœur en sort, donc les touches
  `1` à `8` ne désignent plus les mêmes bâtiments qu'avant.
- **Une passe `--headless --editor --quit` a été nécessaire** après la création des quatre
  `class_name` de `src/adapters/hud/` : le cache de classes globales n'est écrit que par le
  scan de l'éditeur, et la commande 4 échouait sur `HudStyle` avant elle. Le piège est déjà
  dans `CLAUDE.md` ; il s'est simplement présenté.
- **La branche n'est pas fusionnée** : `feat/n2-population-view`, six commits.

---

## 2026-09-01 — `I3` : le tour, et deux fichiers qui ne compilaient plus depuis `R0`

**État : terminé.** Branche `feat/i3-turn`, tirée de `master` après la fusion de `N1`. Les
**quatre** commandes passent — la quatrième est née dans ce jalon, voir plus bas : boot sans
erreur ni warning, tout `src/domain/` parse, tout `src/adapters/` et `scenes/dev/` aussi, et
**390 tests verts contre 296**. Des captures, deux sondes, et une chronique de run.

*Deux décisions de l'humain sont arrivées en cours de jalon et sont intégrées ici plutôt que
dans une entrée à part : la **file de chantiers est supprimée**, et le **cycle du jour**
change de forme. Les deux sont racontées plus bas.*

Le jeu se relance. C'est ce que `DESIGN.md` 8 demande à ce jalon, et rien d'autre : « un
projet qui ne se lance pas est un projet dont on ne mesure plus rien ».

### Ce que le jalon livre

Cinq fichiers dans `domain/run/` — 948 lignes contre les 2 361 que `R0` avait retirées —,
trois dans `domain/economy/`, un bloc d'équilibrage, un autoload rerempli et un harnais.

`RunOrchestrator` **a rétréci de moitié**, et c'est la mesure du rescope plus que celle du
jalon : 691 lignes avant `R0`, la moitié aujourd'hui. Il orchestrait cinq systèmes, il en
orchestre trois ; il connaissait deux sortes de résolution — une phase qui produit, une
journée qui coûte —, il n'en connaît qu'une.

**Ce qu'il n'a plus à faire du tout est le vrai gain du modèle de `N1`.** Il n'y a *rien à
réaffecter*. Les bras d'un bâtiment sont payés à l'ouverture de son chantier et y restent, le
sommeil est un calcul que `Staffing` refait à la demande — si bien qu'un bâtiment démoli rend
ses bras **sans qu'une ligne du code ne le dise**, et qu'un village qui repeuple le fait sans
qu'on l'ordonne. Les deux se lisent à ce que le fichier ne contient pas.

### Trois décisions de forme, et pourquoi

**Aucun DTO n'entre dans `contracts/`**, et la table y reste à quatre lignes pour le
deuxième jalon d'affilée. `CLAUDE.md` annonçait `ProductionReport` pour `N1` puis pour `I3` ;
les deux l'ont refusé par le même critère — il va de l'Économie à `domain/run/`, et
`domain/run/` a le droit de tout lire. Cinq DTO sont nés en deux jalons, aucun n'a franchi
de frontière. Le document a été corrigé plutôt que la règle.

**Le résolveur de production ne reçoit pas de `TerrainQuery`**, contre ce que `DESIGN.md` 3.3
écrivait. Le relief était dans ce contrat parce que le jeu d'avant laissait jouer une carte
**à cru** sur une case, auquel cas le tag décidait du rendement ; ce geste est parti avec les
cartes. Le passer aujourd'hui serait un champ ajouté d'avance avec, en prime, une signature
qui ment sur ce qu'elle lit. Il reviendra à `C3` avec l'adjacence, qui le lira. *(Tranché
avec l'humain avant d'écrire ; `DESIGN.md` 3.3 est corrigé dans le même commit.)*

**`CityLimits` est un fichier pour deux fonctions de quatre lignes**, et c'est leur raison
commune qui le justifie plutôt que leur longueur. `N1` avait écrit que `Ledger` et
`Population` sont deux plafonds bâtis sur le même modèle ; ce fichier est l'endroit où cette
symétrie est visible, et les séparer la rendrait invisible. Aucun des deux ne pouvait vivre
chez celui qu'il plafonne — `Population` ne connaît pas les bâtiments, et c'est une frontière
que son propre docstring défend.

### Deux fichiers qui ne compilaient plus depuis `R0`

C'est le résultat le plus utile du jalon, et il n'était pas au programme.

`scenes/dev/economy_harness.gd` n'était dans aucune table de harnais et référençait six
classes supprimées. `ResourceBar.delta_of()` prenait un `PhaseReport`, classe partie avec la
journée en phases. **Aucune des trois commandes de vérification ne pouvait le dire** : le
boot ne charge que ce qu'un harnais *actif* référence, et la passe de parsing ne balaie que
`src/domain/`. Il restait un angle mort de la taille de `src/adapters/`, et il a duré deux
jalons.

D'où une **quatrième commande**, qui balaie `src/adapters/`, `src/schema/` et `scenes/dev/`
en filtrant les trois autoloads que `--check-only` ne sait pas résoudre. Elle sort propre
depuis. La leçon générale vaut au-delà de ces deux fichiers : **un contrôle de parsing qui ne
balaie qu'un dossier laisse un angle mort de la taille des autres.** `R0` avait raison de
dire que GDScript dénonce toute référence pendante — encore faut-il le lui demander.

Un troisième résidu était du même bois sans être une panne : `dev_shot.gd` déclarait encore
les dix drapeaux de capture que `R0` avait retirés du README. Le code et la documentation se
contredisaient, et rien ne pouvait le signaler — ce fichier n'a ni test ni écran.

### Le garde-fou de `N1` avait un trou, et il fallait un tour pour le voir

`GameDatabase` refuse au boot un catalogue où aucun bâtiment ne loge sans coûter de bras.
C'est l'interdit de blocage de `DESIGN.md` 3.4, et il comptait le **Cœur** parmi les
soupapes : housing 4, workers 0, il satisfaisait le contrôle à lui seul.

Or le Cœur est posé **une fois**, à la fondation, et aucun geste du jeu n'en bâtit un second.
La soupape qu'il semblait offrir ne s'ouvre jamais. Le contrôle aurait donc laissé passer un
catalogue où l'habitation coûte des bras, c'est-à-dire exactement la partie mortellement
bloquée qu'il existe pour interdire.

C'est **la règle qu'il protège, appliquée à lui-même** : `N1` a écrit qu'une soupape se joue
et ne se déclare pas, et le contrôle y était soumis sans qu'on le voie — il vérifiait qu'un
bâtiment gratuit *existe*, pas qu'on puisse le *bâtir*. Il a fallu un tour jouable pour que
la différence se voie. Corrigé au boot et dans la suite, et **vérifié en le faisant échouer**
plutôt qu'en le regardant passer.

### La file de chantiers est supprimée

*(Décidé par l'humain après avoir vu le jalon tourner.)* Le rescope avait posé **deux**
régulateurs — les travailleurs disent ce que le village peut posséder, la file ce qu'il peut
faire à la fois. Le second est retiré, et l'argument est celui qui a fait couper le reste :
il **doublait** le premier au lieu de le croiser. Ce qu'un village mène de front est déjà ce
que ses bras autorisent, puisqu'un chantier les immobilise à son ouverture ; un plafond de
plus posait la même question deux fois, et devenait la contrainte réelle dès qu'il mordait.

**La chronique l'a dit sans qu'on le lui demande.** La même politique bête qui mourait de
faim au douzième tour survit maintenant les vingt et gagne : le village monte à treize
habitants, redescend à huit, et s'y tient. La file était bien ce qui mordait.

Ce que ça change et qui est écrit dans `DESIGN.md` 2 : un bâtiment gratuit en bras —
l'habitation, la palissade — n'est plus borné que par la ressource et la place au sol. On
peut en ouvrir dix d'un coup avec le bois et les cases. C'est cohérent avec un pitch dont la
contrainte est spatiale, et c'est un chiffre de `B1` si c'est trop permissif.

Une découverte du jalon part avec elle. Le blocage avait une **seconde forme** — des
chantiers endormis gardant leurs emplacements pour toujours, y compris contre l'habitation
qui aurait tout débloqué — et elle n'existe plus faute d'emplacements. Ce qui survit est la
moitié qui ne lui devait rien : l'habitation est gratuite en bras mais **pas en bois**, donc
la démolition reste la seconde soupape, et un cas de test la garde.

### Ce que la capture a trouvé

Le catalogue du harnais liste tous les bâtiments de `data/`, Cœur compris — et le domaine
**acceptait** d'en ouvrir un second. Gratuit, sans chantier, quarante points de vie et quatre
places de logement : le meilleur bâtiment du jeu, à répétition, et le refus d'une seconde
fondation devenait décoratif. `open_site()` le refuse maintenant, avec la même raison que la
démolition — le Cœur se **fonde**, il ne se bâtit ni ne se démolit.

### La chronique, et ses deux tables fausses avant la bonne

`--chronicle` revient et rejoue le run entier sans écran. C'est le seul contrôle du projet
qui joue la boucle complète sur la data réelle : ni le parsing ni les tests n'enchaînent
vingt tours.

**Deux versions de sa table étaient fausses**, chacune d'une famille que `CLAUDE.md` nomme
déjà — et aucune des deux n'aurait été trouvée sans la relire contre ce qu'elle prétend
montrer.

La première venait du **pilote**, ce qui est une nuance neuve. La politique vidait la file
avec le premier bâtiment acceptable, donc enchaînait les cabanes de bûcheron et n'ouvrait
jamais une ferme. Le tableau était aligné, toutes ses colonnes bougeaient, il finissait sur
une défaite plausible par famine — et **la moitié nourriture de la boucle n'y était jamais
jouée**. La même table serait sortie d'un jeu où les fermes n'existent pas. Corrigée en
rendant la politique plus bête : un bâtiment de la liste par tour.

La seconde était un défaut de **moment**, la famille de `F2b`. La colonne des chantiers était
relevée après la résolution, si bien qu'un chantier d'un tour s'ouvrait et s'achevait dans la
même ligne : elle affichait 0 pendant que le village bâtissait une cabane par tour. Elle est
maintenant relevée avant, et la table le dit dans son en-tête.

Ce qu'elle a donné d'abord, du temps de la file : le village montait à huit habitants au
quatrième tour, la famine commençait au cinquième, et le run était perdu au douzième. C'est
ce chiffre qui a motivé la suppression de la file — et une fois celle-ci partie, la même
politique survit les vingt tours et gagne avec 265 points. **La chronique dit où la boucle
casse ; elle ne dit pas si le jeu est bon**, et la politique reste bête, donc ces chiffres
sont un plancher.

### Le soleil fait un tour à chaque tour, et deux défauts qu'aucune capture ne voyait

*(Second retour de l'humain.)* La lumière suivait l'avancement du run — aube au premier tour,
nuit au vingtième —, si bien qu'elle **dérivait** sans qu'aucune règle du jeu ne le demande :
le tour 12 se lisait autrement que le tour 3, et la carte devenait moins lisible à mesure
qu'on jouait. Elle se repose maintenant **toujours à midi**, l'orientation calibrée à `T2`,
et c'est un tour de soleil complet à chaque tour passé qui dit qu'un jour est passé.

Les deux défauts de la première version méritent d'être notés ensemble, parce qu'ils sont de
la même famille et que cette famille est neuve pour le projet : **une capture ne dit rien
d'un mouvement.**

**La course ne se jouait qu'au premier jour.** Elle visait un moment absolu, et le compteur
n'était pas replié : le premier tour menait le soleil à 1,25, les suivants lui demandaient
d'aller là où il était déjà. Rien ne plantait, rien ne compilait de travers, et les quatre
captures du cycle étaient **chacune juste** — une image fixe ne dit rien d'un mouvement
absent.

**Et la nuit tombait d'un coup.** Passer du soleil à la lune n'est pas qu'une baisse
d'intensité : la lumière **vire de plus de cent trente degrés**, et l'étaler sur un dixième
de la course se voit comme un à-coup quand tous les autres dixièmes sont doux. Élargir le
fondu n'y faisait presque rien — un virage de 135° doit bien se faire quelque part. Le
correctif est d'arrêter de virer : le lacet fait un **tour complet à vitesse constante**, et
la lune est le même luminaire arrivé de l'autre côté.

La calibration de `T2` en sort intacte, par une coïncidence qui vaut d'être écrite : −125
vaut 10 modulo 45, et ajouter des quarts de tour ne change pas ce reste. Les quatre moments
cardinaux tombent donc tous à dix degrés d'un angle qui aplatirait le relief — exactement la
propriété que le réglage d'origine cherchait. Et minuit tombe pile sur le lacet que la lune
portait en constante : elle était déjà « de l'autre côté », à un demi-tour du soleil de midi.

**Le repos est le matin et non midi**, sur demande de l'humain, et c'est mieux que le
réglage que ça remplace : un tour commence le matin, donc une journée qui se joue va du matin
au matin. Midi rendait la course symétrique autour de son propre début — joli, et sans
signification. La calibration de `T2` y survit, et il fallait le vérifier avant d'y toucher :
un huitième de tour vaut 45°, donc ne change pas le reste modulo 45, et le lacet du matin
tombe à dix degrés d'un angle qui aplatirait le relief. L'inclinaison descend de −52° à −46°,
donc des ombres un peu plus longues — le matin se **dit** au lieu de s'écrire.

**Deux sondes sont écrites, et elles impriment sur chaque capture.** La première joue deux
journées d'affilée et donne où le soleil s'arrête à chaque quart — deux séries identiques et
non triviales disent que la course se rejoue. La seconde échantillonne la course et donne le
pire écart angulaire à côté du pas moyen : **48,8° contre 5,0° avant, 4,7° après**.

Et vérifier la première en refaisant le bug a corrigé le **diagnostic** autant que le
contrôle : la cible absolue était inoffensive à elle seule, c'est le repli manquant qui était
la cause. J'avais écrit l'explication à l'envers avant de la vérifier.

### La transition devient le verrou, et il n'y en aura qu'un

*(Troisième retour de l'humain, et le plus structurant.)* On pouvait poser un bâtiment pendant
que la course jouait. « Purement décorative » ne veut pas dire sans conséquence : un geste
posé pendant une transition arrive dans un état que le joueur **ne regarde pas encore** — il
pose sur une ville qu'il n'a pas vue, et découvre les deux ensemble.

Une transition est donc **le moment où le plateau parle et où le joueur se tait**, et
l'humain a demandé qu'on l'instaure maintenant pour tout ce qui viendra. Trois décisions
tiennent dedans :

**Le verrou est un adapter, jamais un état du domaine.** `DESIGN.md` 3.5 vient de refermer la
coupure d'attente que l'ancien jeu avait dû écrire — « la fin de tour reste atomique » — et
la rouvrir parce qu'une animation dure trois secondes serait la rouvrir pour une raison
encore plus faible. Le domaine ignore qu'un écran existe.

**Il est unique**, porté par `DevWorld`, et `V3` y déclarera sa bataille plutôt que d'inventer
le sien. Deux verrous à tenir d'accord divergent, et celui qu'on oublie laisse passer les
gestes en silence.

**Il vit dans `_unhandled_input` et non dans les fonctions de geste**, parce que c'est un
verrou d'**entrée** : la chronique et les captures empruntent les mêmes gestes et n'ont
aucune raison d'attendre une animation qu'elles ne regardent pas. Et il n'interdit que
d'agir — la caméra continue de tourner, puisque regarder est ce qu'on demande.

La sonde dit les deux bouts, et le second compte plus : `verrou posé … verrou levé`, deux
fois. **Un verrou qui se poserait sans se lever bloquerait la partie pour de bon**, sans rien
signaler et sans qu'aucune image ne le montre.

### Trois résidus nettoyés au passage

`build_actions` devient **`site_turns`** : le champ comptait les actions *Construire* d'un
deck supprimé, c'est-à-dire « autant de cartes qu'il faudra piocher ». Même geste que
`upkeep_per_worker` → `upkeep_per_inhabitant` à `N1` — le chiffre est le même, ce qu'il
compte a changé de nature.

`BuildingData.defense` est supprimé. `DESIGN.md` 4.1 le retire de la palissade depuis le
rescope, et aucun système ne le lisait. Ce qui le remplace — portée, dégâts, cadence — arrive
à `V2`, avec le système qui le lit.

Et le harnais de l'Économie ne revient pas. Ce qu'il montrait — le repas, la famine, la
réserve qui se remplit — se montre dans un tour, ce qui est le seul endroit où ces chiffres
veulent dire quelque chose.

### Ce que je n'ai pas fait

**Pas de vague, pas de calendrier.** `DESIGN.md` 8 date la vague de `V1` à `V4`, et l'étape
`e` de la séquence est laissée en commentaire à l'endroit où elle s'insérera. Un champ de
calendrier écrit aujourd'hui obligerait à deviner sa forme.

**Pas de vue de population.** C'est `N2` : effectif, immobilisés, disponibles, places, et
lesquels dorment. `I3` les imprime en texte dans son rapport, `N2` les dessinera.

**Pas d'écran de fin.** Il est parti avec le harnais Run à `R0`. Le verdict et ses quatre
termes s'affichent en texte ; un vrai écran appartient à `M1`, qui est une `.tscn`.

**Aucun chiffre n'est équilibré.** `turns = 20`, `build_slots = 3` et les quatre poids du
score sont des points de départ, et la chronique dit déjà que la nourriture ne suit pas.
C'est `B1`.

### Prochain jalon

**`N2`** — ce qu'on voit de la population. Le tour existe, donc les chiffres ont enfin un
endroit où vouloir dire quelque chose : effectif, immobilisés, disponibles, places restantes,
et lesquels des bâtiments dorment. La `ResourceBar` et la `CommodityPalette` servent telles
quelles, et le coût en bras s'affiche sur la fiche d'un bâtiment avant qu'on le pose — le
rapport texte du harnais le porte déjà, il faut le dessiner.

Puis **`T4`**, la génération garantie, qui doit venir avant `V1` : on ne teste pas un pathing
sur des cartes qui n'ont pas de cols. La capture de ce jalon le redit — le relief du seed
1234 est du bruit uniforme, sans plateau ni goulot.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut désormais `&"run"`**, et le harnais Run est le défaut. `&"terrain"` et
  `&"city"` restent dans la table.
- **Trois drapeaux de capture neufs** : `--shot-passes n` résout des tours avant l'image,
  `--shot-sun f` pose le soleil où l'on veut dans son cycle, et `--chronicle` rejoue le run
  entier sans écran et imprime la table. Dix autres, morts depuis `R0`, sont retirés de
  `dev_shot.gd` — ils l'étaient déjà du README.
- **`data/balance/run_balance.tres` n'a plus de `build_slots`.**
- **Neuf `.tres` de bâtiment ont changé** : `build_actions` s'appelle `site_turns`, et la
  palissade perd sa `defense`.
- **`data/balance/run_balance.tres` est neuf**, et `balance.tres` gagne sa cinquième ligne.
- **La branche n'est pas fusionnée** : `feat/i3-turn`, onze commits.

---

## 2026-09-01 — `N1` : la population, et la règle que la spécification n'avait pas

**État : terminé.** Branche `feat/n1-population`, tirée de `master` après la fusion de `R0`.
Les trois commandes passent : boot sans erreur ni warning, tout `src/domain/` parse,
**296 tests verts contre 262**.

### Ce que le jalon livre

Quatre fichiers dans `domain/economy/`, aucun `Node`, aucun contrat créé.

`Population` est le **jumeau de `Ledger`**, et le parallèle est délibéré plutôt que
joli : ce sont deux plafonds bâtis sur le même modèle — une quantité, une capacité qu'un
bâtiment relève, et un écrêtage quand cette capacité baisse. `Ledger.set_capacity()` rend ce
qu'un entrepôt détruit fait perdre en ressources ; `Population.set_places()` rend ce qu'une
habitation détruite fait perdre en habitants. Même signature, même raison.

`Staffing` décide qui tourne et qui dort. `UpkeepResolver` fait manger le village et en tire
la conséquence. `UpkeepReport` raconte ce qui s'est passé sans décider de ce qu'il faut en
faire — la règle que `DESIGN.md` 9 garde du jeu supprimé.

**Aucun DTO de `contracts/` n'entre**, et c'est la discipline que `R0` venait de réaffirmer :
`StaffingPlan` et `UpkeepReport` restent dans `domain/economy/` tant qu'aucun **second
système du domaine** ne les franchit. `domain/run/` aura le droit de tout lire, les adapters
lisent le domaine — ni l'un ni l'autre n'est un critère.

### Le sommeil n'est pas un état, c'est un calcul

C'est la décision qui porte le jalon, et l'alternative était tentante : mémoriser sur chaque
bâtiment s'il dort, et le mettre à jour à chaque famine, chaque destruction, chaque
démolition. Deux états à garder d'accord finissent par diverger, et celui-ci aurait divergé
**en silence** — un bâtiment endormi par erreur ne plante pas, il cesse simplement de
produire.

Rien n'est donc stocké : le plan se redérive de l'effectif et de l'ordre de pose à chaque
demande. Le repeuplement automatique que `DESIGN.md` 3.4 réclame en toutes lettres devient
gratuit, parce qu'il n'y a rien à repeupler — il n'y avait rien d'éteint.

Et « éteindre du plus récent » revient à « garder le plus long préfixe qui tient », les deux
formulations étant équivalentes puisque les sommes cumulées ne décroissent jamais. On écrit
la seconde, qui se lit en une passe.

### La règle que la spécification n'avait pas, et qui la sauve

**Un bâtiment qui ne coûte aucun travailleur ne dort jamais.** Cette ligne n'était pas dans
`DESIGN.md` 3.4 ; elle a été trouvée en écrivant la boucle, en vérifiant que l'interdit de
blocage tenait vraiment.

Il ne tenait pas. La soupape annoncée est l'habitation gratuite en bras : village bloqué, on
bâtit une habitation, le plafond monte, la population repart. Mais une habitation neuve est
le bâtiment **le plus récent**, donc le premier qu'un préfixe strict endort — et un chantier
endormi n'avance pas. **La soupape existait dans la data et ne s'ouvrait jamais.**

Le correctif tient en une ligne et se justifie tout seul : dormir veut dire « il manque des
bras », et un bâtiment qui n'en demande aucun ne peut pas en manquer. Une palissade se bâtit
pendant une famine.

Ce que ça apprend vaut au-delà du cas : **une soupape se joue, elle ne se déclare pas.** La
spécification avait raison sur le mécanisme — l'habitation gratuite — et n'avait pas vérifié
qu'il était atteignable. C'est la même famille que les défauts de mesure que `F1` et `F2b`
ont nommés, transposée d'une table à une règle : *cette règle pourrait-elle produire son
effet si l'on jouait vraiment la situation qu'elle prétend débloquer ?*

### L'interdit de blocage est gardé deux fois, et ce n'est pas un doublon

`GameDatabase` refuse au boot un catalogue où aucun bâtiment ne loge sans coûter de bras. Il
est là et non dans `BuildingData.missing_fields()` par la question que `CLAUDE.md` fait poser
avant tout `missing_fields()` — *cette `Resource` a-t-elle sous les yeux tout ce que la règle
regarde ?* Une `BuildingData` ne voit qu'elle-même et ne peut pas savoir qu'un *autre*
bâtiment offre la sortie. Même partage que la règle du tour perdu, montée de `PhaseDef` à
`RunBalance` dans le jeu d'avant.

Un cas de test le double au niveau de `data/`, et la raison est mécanique : **un `assert()`
est retiré d'un export**, alors qu'une suite de tests tourne toujours en débogage. Une règle
dont la violation rend une partie définitivement injouable — sans rien casser ni rien
signaler — est trop coûteuse à perdre pour ne reposer que sur la première des deux.

**Et le contrôle a été vérifié en le faisant échouer**, plutôt qu'en le regardant passer :
en donnant un bras à l'habitation et au Cœur, le boot s'arrête sur son message. Un contrôle
qui n'a jamais refusé quoi que ce soit ne prouve pas qu'il refuserait.

### Un résidu que `R0` avait laissé passer

`ProductionBlock` portait encore `slots` et `skill_family` — des postes qu'une carte venait
tenir, et une piste de compétence que le travail créditait. Deux champs de systèmes
supprimés, et un `skill_family = &"harvest"` dans neuf `.tres` : exactement le genre de reste
dont `R0` s'était promis de ne pas laisser traîner.

Il n'en reste qu'un champ, `yield_per_turn`, et le bloc garde sa raison d'être : nullable, il
rend la doctrine du zéro applicable — un bloc qui existe produit, donc son contenu se réclame
sans condition.

`upkeep_per_worker` devient `upkeep_per_inhabitant` et `roster_places` devient `housing`. Ces
renommages n'étaient pas cosmétiques et ils avaient été **volontairement repoussés** de
`R0`, qui s'interdisait tout ajout : un ouvrier était une fiche qu'on affectait, un habitant
est une unité d'un compteur.

### Un test qui mesurait autre chose que ce qu'il annonçait

`BuildingSnapshot.create()` prend un `turns` qui est une **orientation**, et j'ai cru y
passer la longueur d'un chantier. Le cas titré « un chantier immobilise comme un bâtiment
fini » fabriquait donc un bâtiment **fini**, et il a échoué sur la seule assertion qui
regardait son propre montage — `completed()` n'était pas vide.

C'est la famille de défauts que ce projet nomme depuis `F1`, rencontrée pour la première fois
dans un *fixture* plutôt que dans une table : le cas passait, il aurait simplement prouvé
autre chose. L'assertion qui l'a attrapé est celle qui vérifiait la prémisse au lieu de la
supposer, et c'est un argument pour en écrire plus souvent.

### Ce que je n'ai pas fait

**Pas de résolveur de production.** `DESIGN.md` 8 ne le liste pas dans `N1`, et il n'a rien à
résoudre tant qu'aucun tour ne l'appelle — c'est `I3`. Un commentaire de `CLAUDE.md` disait
« et le résolveur à `N1` » ; c'est la liste de jalons qui fait foi, et le commentaire a été
corrigé.

**Pas de baliste.** `DESIGN.md` 4.1 la porte, et ses trois champs qui comptent — portée,
dégâts, cadence — n'existent pas avant `V2`. L'écrire aujourd'hui donnerait un bâtiment à
moitié décrit, ce que la doctrine du projet refuse depuis `E1b` : un champ arrive avec le
système qui le lit.

**Aucun chiffre n'est équilibré.** `base_housing = 6`, `starting_population = 4`, et les
coûts en bras de la table de 4.1 sont des points de départ. C'est `B1`.

### Prochain jalon

**`I3`** — le tour. `RunState` et `RunOrchestrator` réécrits sans phases, sans deck, sans
roster ; le harnais Run refait autour d'un seul geste. C'est lui qui rend le jeu jouable à
nouveau, et rien ne se regarde avant lui.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut toujours `&"city"`.** `N1` n'a pas d'écran : la population ne se voit
  qu'à `N2`, et `N2` attend `I3` pour avoir un tour à afficher.
- **Neuf `.tres` de bâtiment ont changé** : un `workers`, un `housing` là où il y avait
  `roster_places`, des PV alignés sur la table de `DESIGN.md` 4.1, et un bloc de production
  réduit à son rendement.
- **La branche n'est pas fusionnée** : `feat/n1-population`, quatre commits.
- **Les quatre commits ont d'abord atterri sur `master`**, et il a fallu les déplacer :
  `R0` avait été fusionnée entre les deux sessions, si bien que la branche de travail
  n'existait plus et que je n'ai pas rebranché avant d'écrire. Rien n'est perdu — `master`
  est revenu sur la fusion de `R0` — mais la règle vaut d'être relue : **vérifier sur quelle
  branche on est au début d'un jalon, pas à son commit.**

---

## 2026-09-01 — le rescope, et `R0` : la moitié du code s'en va

**État : terminé.** Branche `refactor/r0-demolition`, tirée de `master`. Les trois commandes
passent : boot sans erreur ni warning, tout `src/domain/` parse, **262 tests verts contre
962**. Une capture.

C'est le premier jalon du projet qui ne construit rien. Il en retire.

### Ce que la discussion a décidé, et l'ordre dans lequel

La séance a commencé par une lecture des trois documents, et par un constat que le projet
faisait déjà sans le dire : quatre genres empilés — city-builder, roguelite, deckbuilding,
combat tactique — dont **trois contraintes de tempo qui se doublaient** au lieu de se
croiser. `DESIGN.md` 3.5 avait vu la moitié du problème dès `D2` et l'avait contournée en
dédoublant le geste ; l'autre moitié n'avait jamais été posée.

L'humain a tranché le périmètre : garder le city-builder de placement sur le relief, garder
les vagues comme jalon de progression, **supprimer le combat tactique, les effectifs et le
deckbuilding**.

Trois questions ont occupé le reste, et deux ont changé la proposition d'origine.

**La population, corrigée par l'humain.** Je l'avais écrite comme un pool réattribué à chaque
tour — chaque bâtiment « réclame » son personnel. Elle est en réalité une **ressource de
construction** : une ferme coûte 10 bois *et* 4 travailleurs, payés à l'ouverture du chantier
et gardés à vie. C'est plus simple et c'est meilleur : il n'y a **plus rien à réattribuer**,
le coût en main-d'œuvre tient sur la fiche du bâtiment comme son coût en bois, et un seul
champ suffit puisque ceux qui l'ont bâti sont ceux qui y vivent.

Ce que ça préserve mérite d'être noté, parce que c'était le cœur du pitch d'origine :
« envoyer son meilleur récoltant en milice coûte deux fois » devient **« une baliste coûte
deux bûcherons »**. La tension produire/défendre survit à la suppression des effectifs, en
pure arithmétique, sans un seul clic d'affectation.

**Le tower-defense, où ma première proposition était creuse.** J'avais proposé une vague que
rien ne blesse — les bâtiments la ralentissent et l'usent en tombant. L'humain a demandé ce
qui l'arrête, et il n'y avait pas de réponse : la vague mâchait jusqu'à ce que son compteur
tombe. La version retenue a des bâtiments qui **tirent**, avec quatre chiffres et pas un de
plus : portée, dégâts, cadence, points de vie.

**Le pas de simulation, où « N tours » était le mauvais mot.** L'humain a objecté qu'une
vague a besoin de continuité pour se regarder. La réponse est que « tour par tour » et
« continu à l'écran » ne s'opposent pas : ce qui les sépare est la **finesse du pas**. Une
journée est un pas grossier, une bataille un pas fin — quelques dizaines de ticks par
seconde, une fonction pure à chaque tick, et l'écran qui interpole entre deux états. Le
patron est celui de tous les jeux déterministes qui bougent, et il ne coûte rien ici parce
que le domaine est déjà pur.

Il rend une chose au passage : **la fin de tour redevient atomique.** Une bataille n'attend
jamais une entrée du joueur, donc plus d'état « en attente », plus de seconde porte. C'était
la seule raison d'être de la coupure que `DESIGN.md` 3.8 avait écrite d'avance à `F1` et que
`I2` avait payée.

### Couper depuis `master` plutôt que repartir de `E1b`

L'humain a posé la question avant d'autoriser quoi que ce soit, et elle méritait une mesure
plutôt qu'une opinion. `E1b` est à 66 commits, `master` à 192. Ce que `E1b` n'a **pas**, et
qui n'a rien à voir avec les trois systèmes coupés : tout `domain/run/`, tout le HUD —
`ResourceBar`, `CommodityPalette`, l'écran de fin, le bouton de pas —, `dev_shot.gd` à 57
lignes contre 166, `dev_world.gd` à 133 contre 298, et 16 fichiers de test contre 51.

L'argument décisif n'est pourtant aucun de ceux-là : **`domain/run/` et le résolveur de
production doivent être réécrits dans les deux cas.** Revenir à `E1b`, c'est les réécrire
depuis rien plutôt que depuis une référence qui marche.

La peur du code zombie, qui est le seul bon argument d'en face, se règle par la **méthode**
et non par le point de départ : on supprime des **dossiers entiers**, jamais des lignes. Et
GDScript est particulièrement bon pour ça — le boot, le parsing et les tests dénoncent
immédiatement toute référence pendante, ce que la suite de ce jalon a vérifié trois fois.

### Ce que `R0` a retiré

| | domaine | adapters | tests |
|---|---|---|---|
| Combat | 1 847 | 385 | 1 823 |
| Effectifs | 671 | 877 | 720 |
| Cartes | 878 | 1 007 | 1 290 |

Plus tout `domain/run/` (2 361 lignes), le `ProductionResolver` et l'`UpkeepReport`, huit
contrats, dix `Resource` de `src/schema/`, 29 `.tres`, sept harnais sur neuf, et onze suites
de test. **Le harnais Run seul faisait 2 178 lignes.**

Quatre bâtiments partent avec les systèmes qui les justifiaient — caserne, marché, atelier,
camp d'exploration —, tous les quatre présents pour débloquer une carte ou ouvrir des places
de déploiement.

### Ce que la coupe a vérifié, et c'était l'argument du jalon

**Les quatre contrats qui restent n'ont pas eu à bouger d'un mot.** `TerrainQuery`,
`CitySnapshot`, `BuildingSnapshot` et `PlacementResult` sont sortis intacts d'une amputation
qui a emporté la moitié du dépôt. Terrain et Construction ne connaissaient rien des systèmes
qui les entouraient, donc il n'y avait rien à défaire — c'est ce que la règle de dépendance
promettait depuis `I0` sans qu'on l'ait jamais éprouvée à ce point.

Même constat sur les survivants : `Ledger`, `CityState`, `PlacementValidator`, `HeightGrid`,
`CellPicker`, `TerrainGen` et tout le rendu n'ont reçu **aucune modification de code**. Trois
d'entre eux portaient une mention d'un système coupé, et c'était dans un commentaire.

### Les trois autoloads restent, même vidés

`EventBus` passe de huit signaux à un, `RunManager` de quinze fonctions à trois. Ni l'un ni
l'autre n'est supprimé, et la raison est mécanique plutôt que de design : `project.godot` les
déclare, ce fichier appartient à l'humain, et un autoload dont le script manque casse le
boot. C'est le seul endroit du projet où la **propriété d'un fichier décide de la forme du
code**, et ça valait d'être écrit dans `CLAUDE.md`.

Les sept signaux d'`EventBus` sont sortis par la règle qui gouverne leur entrée, appliquée à
l'envers pour la première fois : un signal n'existe que si un système réel l'émet. `I3` et
`V4` reposeront ceux dont ils auront besoin, avec les charges que leurs rapports porteront
vraiment.

### Ce qu'une capture a dit sans qu'on le lui demande

Le harnais Construction, devenu le harnais par défaut, rend bien ses neuf bâtiments. Et
l'image montre autre chose : **ce relief n'a ni plateau ni col.** C'est du bruit de Perlin
uniforme sur 32×32, avec des flaques d'eau éparses — exactement ce que `DESIGN.md` 3.1
décrit maintenant comme inutilisable, puisque le placement défensif y devient l'essence du
jeu. `T4` n'était pas une intuition ; il se voit.

### Un piège d'outil, et un piège que je me suis fabriqué

**Le cache des classes globales était en retard**, et le tout premier boot du jalon a échoué
sur des `Parse Error` dans un projet parfaitement sain. C'est le piège documenté dans
`CLAUDE.md` : une passe `--headless --editor --quit` reconstruit le cache. Il a fallu la
relancer après la coupe aussi, ce qui est logique — dix `class_name` avaient disparu.

**Et deux patchs Python ont échoué sur des marqueurs de texte.** Le premier sur l'encodage
d'une chaîne accentuée passée par un heredoc — la mémoire du projet le disait déjà, il faut
passer par un fichier de script. Le second est plus instructif : j'ai découpé `README.md`
entre deux marqueurs dont **le premier apparaissait deux fois**, si bien que `str.index()` a
pris la mauvaise occurrence et que le fichier a gagné un bloc dupliqué au lieu d'en perdre
un. La parade est celle qui vaut pour toutes les mesures de ce projet : **découper par
indices trouvés dans l'ordre, jamais par un marqueur supposé unique** — et relire le
résultat, ce qu'un `grep` sur la structure a fait tout de suite.

### Ce que je n'ai pas fait

Aucun ajout. `R0` est fini quand le boot est propre, que tout `src/domain/` parse et que la
suite restante est verte — c'est tout ce que `DESIGN.md` 8 lui demande, et il n'a rien fait
d'autre. La population n'existe pas, le tour n'existe pas, la génération est celle d'avant,
et rien ne se joue.

`data/balance/economy_balance.tres` garde `upkeep_per_worker` sous ce nom : il devient l'upkeep
par habitant à `N1`, et le renommer ici aurait été un ajout déguisé.

### Prochain jalon

**`N1`** — le compteur de population et sa boucle, dans `domain/economy/`, sans un `Node`. Le
cas de test qui porte le jalon est l'**interdit de blocage** : une partie où tout le monde est
immobilisé et le logement plein doit rester jouable, parce que l'habitation ne coûte personne.

Puis **`I3`**, le tour, qui rend le jeu jouable à nouveau — et il doit venir tôt, parce qu'un
projet qui ne se lance pas est un projet dont on ne mesure plus rien.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché — ce qui est la raison pour laquelle les
trois autoloads ont été vidés plutôt que supprimés.

- **`HARNESS` vaut `&"city"`.** C'est le seul harnais qui montre encore quelque chose avec
  `&"terrain"`. Les sept autres sont supprimés.
- **`DESIGN.md` est entièrement réécrit.** L'ancien reste lisible dans l'historique, dernière
  version sur `master` au commit `144689b`. Sa section **9** dit ce qui est parti et pourquoi.
- **`CLAUDE.md` a perdu la table des contrats d'avant** — douze lignes, il en reste quatre —
  et gagné trois anti-patterns nés du rescope, dont le premier compte : la population est un
  **entier**, jamais une liste de gens.
- **La branche n'est pas fusionnée** : `refactor/r0-demolition`.

---

## 2026-08-28 — `F2b` : la vague décide, et une annonce engage

**État : terminé**, et `F2` est fini. Sept commits sur `feat/f2b-wave-ai`, tirée de
`feat/f3a-battle-view` — la branche porte donc trois jalons. Les trois commandes passent :
boot sans erreur ni warning, tout `src/domain/` parse, **962 tests verts contre 925**.
Les neuf harnais bootés un par un. Six captures.

### La question qui ouvrait le jalon, et la ligne qui la referme

`DESIGN.md` 3.6 gardait le grain du vocabulaire d'intentions ouvert depuis `F2a`, et le
jalon commençait par là plutôt que par du code. La réponse retenue tient en une ligne :

> **Un corps annonce une case exactement quand il peut frapper sans bouger**, et cette
> annonce engage.

Ce qu'elle répare est la contradiction qui avait rouvert le paragraphe. Un **trajet** ne
s'annonce pas — le joueur agit après, donc le plan est conditionnel ou rigide. Une **case**
si, mais seulement quand rien de ce que le joueur fera ne peut l'invalider, c'est-à-dire
quand le corps n'a pas à se déplacer pour la tenir.

Elle répond **oui** à la question littérale que tu posais — un tireur posté annonce sa case
—, et c'est ce qui compte : **ce n'est pas une règle sur les tireurs.** Un corps-à-corps
déjà collé à un ouvrier annonce la sienne aussi. Ce qui varie est la **situation**, que le
joueur lit sur le plateau, pas la fiche de l'assaillant — et l'objection du « vocabulaire à
géométrie variable » tombe avec ça.

La troisième sortie, ne jamais annoncer de case, était la plus courte à écrire et elle
tuait une règle entière. On n'esquive pas ce qui n'est pas annoncé : « une intention frappe
la case, pas la cible » aurait continué de fonctionner à la résolution sans que le joueur
puisse jamais s'en servir.

### Ce que le pillage a demandé de trancher

`DESIGN.md` 3.6 dit « ce qu'ils ont cassé et emporté **entre-temps** », et c'est ce mot qui
a décidé : le butin court **par manche passée dans l'enceinte**, pas au départ de la vague.
Trois conséquences, et c'est pour elles que la lecture a été préférée à « chaque survivant
emporte sa part » : les deux bonnes façons de jouer paient — les abattre vite, ou les tenir
dehors —, une vague bloquée à la lisière repart les mains vides sans qu'une règle ait à le
dire, et la borne de tours cesse d'être une durée pour devenir un montant.

L'enceinte est **figée à l'ouverture**. La recalculer ferait rapporter *moins* à une vague
qui casse *plus*, ce qui est l'inverse de ce qu'on veut.

### Ce que la data porte maintenant

`WaveDef` dit enfin **qui vient** — un identifiant d'`EnemyData` par corps, répétitions
écrites, dans l'ordre où ils prennent les cases d'entrée — et **combien de manches il faut
tenir**. La borne est par vague et non dans `CombatBalance` : un siège s'installe là où une
escarmouche passe, et la durée d'une razzia est du contenu au même titre que sa composition.
Les deux dans le même `.tres`, ce qui est la seule façon de les garder d'accord.

`power` reste, seul champ de l'époque du bouchon, et il partira avec lui à `F3b`. Deux
époques cohabitent, exactement comme `CombatBalance` en porte trois depuis `F2a`.

`EnemyData` gagne son butin, et son docstring l'annonçait mot pour mot depuis `F2a` : « il
ne reste dehors que le **butin** ». Rien ne reste dehors désormais.

`GameDatabase` gagne un troisième contrôle croisé, après les ressources et les cartes : une
composition qui nommerait un assaillant inexistant ferait entrer une vague avec un corps de
moins, en silence.

### Le contrat, et ce qu'il cesse de publier

`assault`, `defense` et `breach()` ont quitté le `DamageReport`, `swept()` y est entré, et
`is_empty()` a fondu dans `is_held()`. Les trois premiers décrivaient une **soustraction**,
pas un fait du combat : une vague qui est une poignée de corps sur une grille n'a plus de
« puissance » à publier. Ce que le rapport dit désormais, ce sont des faits — ce qui est
tombé, qui est mort, ce qui est parti.

Et la promesse de `F1` se vérifie enfin : **`RunOrchestrator.fight()` applique ce rapport
sans une ligne à changer.** C'est ce que `DESIGN.md` 3.6 annonçait en corrigeant la phrase
sur « l'échange en une ligne » — l'applicateur ne bouge pas, c'est le producteur qui change
de nature.

Ce qui n'est **pas** entré, et c'est la discipline habituelle : le nombre de manches tenues.
Le plateau le connaît, personne hors du Combat ne le lit, et un champ que personne ne
franchit est la frontière que ce projet refuse depuis `E1`. Il entrera avec l'écran qui
voudra dire « tenue cinq manches ».

### Le partage entre qui décide et qui se souvient

`WaveAI` décide, `CombatBoard` se souvient, l'écran lit. Le plateau porte les intentions, la
borne, le butin et `to_report()` — mais il ne décide de rien, et ce n'est pas seulement de la
doctrine : le harnais joue les deux camps à la main depuis `F3a`, et un plateau qui
réannoncerait tout seul le lui interdirait. La touche `A` rend donc la vague au joueur, et
**le même plateau se rejoue des deux façons**, ce qui était l'argument qui avait fait passer
`F3a` devant ce jalon.

`WaveAI.take_turn()` est la seule porte, et l'ordre qu'elle tient compte : la manche se ferme
**entre** l'exécution et l'annonce suivante, parce que c'est à cette fermeture que le butin
se compte et que la borne avance. Annoncer avant décrirait un plateau d'une manche en retard.

### Les deux défauts, et aucun n'a été trouvé par un test

**En capture.** La borne franchie, l'écran gardait affichées les quatre cases annoncées à la
dernière manche : une vague repartie promettait des coups qui ne tomberaient jamais. La
réparation est dans le **domaine** et pas dans la vue — une vague repartie n'annonce rien, et
la réponse est la même pour tous les écrans. Le compteur de voiles du harnais l'a confirmée
sans qu'on ait à sonder un PNG : « 4 annoncée(s) » est devenu « 0 annoncée(s) ».

**Dans une table.** Celui-là est le plus instructif du jalon, et il est d'une famille neuve.
La table qui mesure ce qu'esquiver retire à la vague la prenait à la **première** manche —
celle où la vague entre à trois cases de la lisière et n'a encore personne à portée. Le
chiffre était exact, la colonne alignée, le verdict formellement satisfait, et la table
mesurait **l'approche**. Prise à la manche où la vague est le plus engagée, elle est passée
de « 13 contre 11 » à **« 12 contre 3 »**, pour le même nombre de coups portés, la
différence entièrement en coups tombés dans le vide.

C'est entré dans `CLAUDE.md` : les deux règles qui y étaient portaient sur *ce qu'on compte*,
celle-ci porte sur **quand** on le compte. Une table choisit son moment et l'écrit dans son
titre.

### Ce que le harnais dit, et qui n'est pas rassurant

La chronique manche par manche est lisible et le verdict est dur : à ces chiffres-là, la
Razzia tue les **trois** défenseurs avant la quatrième manche, rase trois bâtiments sur
quatre, emporte douze de réserve et repart sans une égratignure. C'est le même constat que
`F2a`, mesuré autrement, et c'est `I3`.

La chronique dit aussi ce qu'elle devait dire du reste : le vocabulaire est **exercé** — la
colonne « annoncent » va de 0 à 4 selon les manches, donc les deux entrées existent
vraiment —, et le pillage reste à zéro tant qu'ils sont dehors puis monte dès qu'ils entrent,
ce que la colonne « dans murs » corrobore depuis un autre compteur.

### Un piège d'outil, et une leçon de portée de tests

**Un `&&` avale une vérification.** J'ai chaîné `python patch.py && godot --headless --quit`
suivi d'un `echo` séparé par `;`. Le patch a échoué, le boot n'a jamais tourné, et le `echo`
a imprimé « boot fini ». Une vérification ne se chaîne pas derrière ce qui peut échouer.

**Et j'ai élargi la suite de tests un cran trop tard.** Le commit de schéma a cassé
`run_orchestrator_test`, qui fabrique ses propres `WaveDef` et que `RunState.open()` refuse
désormais sans composition. Les suites ciblées ne l'ont pas vu parce que j'avais lancé
`tests/domain/run` avant ce commit et `tests/schema` après. La règle existait — élargir quand
un changement traverse — et il fallait la lire d'un cran plus large : **un champ de
`src/schema/` qu'agrège `RunBalance` voyage aussi loin qu'un champ de `data/balance/`.**

### Ce que je n'ai pas fait

Aucun branchement sur le run : la bataille ne se déclenche toujours pas à la fermeture d'une
journée, et le `DamageReport` que le plateau sait rendre n'est appliqué par personne. C'est
`F3b`, et il n'attend plus que lui-même.

Aucun équilibrage. Le bonus d'un balayage complet est **constaté** par le rapport et payé par
personne, ce que `DESIGN.md` 3.6 réserve à `I3`.

Aucune capacité (`X5`), aucun état (`X6`), aucune coordination entre assaillants : trois
corps qui appliquent la même règle chacun de leur côté produisent déjà de l'encerclement et
du blocage de porte.

`InstantCombatResolver` est **intact** et fait encore tourner le jeu. Il expose une
`breach_of()` publique de plus, pour son seul lecteur restant — le harnais qui le calibre —,
et il partira avec elle à `F3b`.

### Une tension d'écran laissée à `F3b`

Quand la vague repart, le panneau dit « La vague repart » pendant que les pions des
assaillants sont toujours sur la carte, debout au milieu des ruines. Ce n'est pas un bug —
la carte montre l'état, le panneau raconte, et c'est le partage que `F3a` a posé — mais les
deux se contredisent à la lecture. Le despawn effacerait où la bataille s'est terminée, et
rendrait un balayage indiscernable d'un départ. La vraie réponse est ce qui **ferme** un
écran de bataille, et c'est `F3b` qui l'écrira.

### Prochain jalon

**`F3b`** — l'intégration : le producteur branché dans `RunOrchestrator`, la fin de journée
qui cesse d'être atomique, `EventBus`, et l'écran qui s'ouvre et se ferme. Tout ce qu'il
attendait existe.

Puis **`M1`**, le menu, toujours le premier jalon qui demande une `.tscn`. Puis **`I3`**, qui
a maintenant trois fronts : la nourriture, la dureté des vagues, et les deux chiffres neufs —
la borne de tours et le butin par manche.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut `&"battle"`.** L'IA tient la vague : `Entrée` finit ton tour, elle joue le
  sien, tu reprends la main. **`A`** te la rend si tu veux rejouer le même plateau à la main.
- **Le voile ambre** est ce que la vague a annoncé. Une case ambre est un coup qui tombera
  là quoi qu'il arrive — en partir le fait tomber dans le vide, et coûte son tour à celui qui
  l'avait annoncé.
- **Les fiches d'en face** disent « frappe » ou « avance » pendant ton tour, et leurs gestes
  restants pendant le leur.
- **`H`** montre deux tables neuves : ce qu'esquiver retire à la vague, et ce qu'une vague
  fait seule manche par manche.
- **Deux drapeaux de capture** : `--shot-rounds n` laisse l'IA jouer n manches,
  `--shot-foes` te rend la main. Documentés au README.
- **La branche n'est pas fusionnée** : `feat/f2b-wave-ai`, sept commits, par-dessus les huit
  de `F2a` et `F3a`.

---

## 2026-08-28 — `F3a` : la bataille se regarde, et quatre défauts que seule l'image montre

**État : terminé.** Trois commits sur `feat/f3a-battle-view`, tirée de `feat/f2a-battle-board`
— la branche porte donc les deux jalons, comme `feat/i2b-knobs` en portait trois. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **925 tests verts
contre 918**. Les neuf harnais bootés un par un. Cinq captures.

### Pourquoi un bout de `F3` est passé devant `F2b`

C'est venu de toi, et l'argument tenait en une phrase : *« le rendu texte ne m'est pas aussi
facile à lire »*. Le calendrier d'origine faisait écrire l'IA contre un damier ASCII, puis la
vue après — c'est-à-dire décider du format en le lisant dans un terminal.

Ce que la conversation a fait apparaître en plus, et qui rend l'ordre meilleur qu'il n'y
paraissait : **sans IA, une vue laisse jouer les deux camps.** On sent donc le format en
entier — déplacement, relief, blocage, la règle « on frappe la case » — sans qu'aucune ligne
d'IA existe. Et `F2b` remplacera ton contrôle du camp d'en face par une IA, donc le **même
plateau se rejouera des deux façons**. C'est le meilleur banc d'essai possible pour la
question d'intentions qui reste ouverte.

C'est la seconde fois qu'un ordre de jalons change en cours de route, après `E1b` passé avant
`W1`, et la raison est de la même famille : **on ne fait pas de contenu dans un instrument
qu'on ne sait pas lire.**

### Ce qu'il a fallu écrire, et c'est peu

`DevWorld` donnait déjà le ciel, le soleil, la caméra, le relief et le survol.
`TargetHighlight` posait déjà un voile sur un jeu de cellules — il lui manquait une teinte en
argument, une ligne. `BuildingRenderer` dessinait déjà la ville — il lui manquait une liste
d'ancres à sauter, six lignes. `CellCursor` désignait déjà une case.

Deux vues sont neuves : les pions, et un panneau. Le panneau est **la sœur d'`AssignmentPanel`
jusque dans le geste** — on clique une fiche, puis on clique la carte —, ce que `P1a` a posé
comme le vocabulaire du jeu et qu'il n'y avait aucune raison de rompre parce qu'on se bat.

Trois choses ont débordé d'`adapters/`, et toutes les trois étaient prévues au plan sauf la
troisième.

**`CombatBoard.strikeable()`**, parce qu'une vue ne juge rien. Allumer les cases à portée
*est* la question « jusqu'où puis-je frapper », et un écran qui recopierait `can_reach()`
finirait par allumer autre chose que ce que `strike()` accepte. Elle rend **toutes** les cases
à portée, vides comprises : filtrer sur ce qui s'y trouve ferait d'une case qui s'éteint une
information que le joueur n'a pas à recevoir avant d'avoir frappé.

**Deux refus qu'un écran rend nécessaires**, et ils sont le meilleur de la couche domaine.
On ne frappe pas sa propre case — la portée inclut la distance zéro, donc un clic mal placé
blesserait le sien. Et on ne dépense pas son pas pour rester où l'on est — `reachable()` rend
toujours la case de départ à zéro, parce que c'est une vérité sur les distances, mais le geste
brûlerait le déplacement du tour pour rien.

Les deux sont dans le **domaine** et non dans la vue, par la règle qu'`E2` et `W2` n'arrêtent
pas de prouver : une règle que deux écrans doivent se rappeler est une règle qu'un troisième
oubliera. Et ni l'un ni l'autre n'aurait été cherché par un test : ce sont des pièges que
l'existence d'un curseur crée, pas des règles qu'un domaine viole.

**La couleur d'un `EnemyData`** est entrée, et son docstring l'annonçait mot pour mot : « elle
arrivera avec le renderer qui la lit ». Il ne reste dehors que le butin, qui attend `F2b`.

### Les quatre défauts que la capture a trouvés

Aucun n'était cherché, aucun n'aurait été vu autrement. `src/adapters/` n'est pas testé et les
trois commandes ne regardent pas l'écran : la capture **est** le contrôle du jalon.

**La caméra cadrait les 32×32.** `DevWorld` cadre la grille entière, ce qui est juste pour les
harnais qui la regardent toute — et illisible ici : une bataille tient dans une dizaine de
cases, donc les pions faisaient trois pixels. Elle cadre le bâti plus la marge d'entrée, de
sorte que la vague soit dans l'image dès la première frame.

**Le rapport couvrait les deux tiers du champ.** Un jalon d'écran qui cache ce qu'il vient de
rendre visible est un contresens. Seules les commandes restent affichées ; les tables partent
sur la sortie standard et reviennent sous `H`.

**Les assaillants étaient des cônes, et `TerrainDecorRenderer` dessine les forêts en cônes
sombres.** Un pillard ne différait donc d'un arbre que par sa teinte — exactement ce que le
docstring du renderer refuse trois paragraphes plus haut. Les rochers étant des dômes, les
deux primitives libres de `T3` étaient prises ; un **tronc de cône** se glisse entre les deux
et garde ses flancs courbes.

**Et le voile rouge disparaissait pour un corps-à-corps.** Celui-là est le plus instructif,
parce qu'il a failli me faire chercher au mauvais endroit. Le compteur ajouté à la capture a
répondu « 13 cases atteignables, 4 frappables » — donc le domaine et le câblage étaient
justes, et le défaut était une **opacité**. À 0,34 le voile tenait pour un archer, dont la
portée couvre vingt-quatre cases, et s'effaçait pour les quatre d'un corps-à-corps : il
disparaissait précisément dans le cas le plus fréquent.

C'est la leçon de `P1b` telle quelle : **sonder un PNG rend un doute, faire dire le chiffre au
harnais rend un nombre.** Les deux compteurs sortent désormais sur toutes les captures.

Un cinquième défaut a été corrigé sans jamais être vu, parce qu'il se déduisait : les deux
voiles étaient coplanaires, donc se disputaient le même Y sur toutes les cases à la fois
atteignables et frappables — c'est-à-dire les voisines, donc les seules qui comptent.

### Ce que je n'ai pas fait

Aucune intention affichée : `F2b` n'a pas décidé de leur forme. Aucune IA. Aucun branchement
sur le run — la bataille ne se déclenche pas à la fermeture d'une journée et ne rend aucun
`DamageReport`, c'est `F3b`. Aucun cadrage sur le côté attaqué au-delà du recadrage sur le
bâti. Et **aucun test d'adapter**, `CLAUDE.md` posant que `src/adapters/` n'est pas testé —
les sept cas de plus couvrent les trois ajouts au domaine.

`DamageReport` n'a toujours pas bougé, pour la raison écrite à `F2a` : il perdra `assault`,
`defense` et `breach()` quand il y aura un producteur pour le remplir.

### Un piège d'outil qui m'a coûté trois allers-retours

Les backslashes d'un heredoc `<<'PY'` perdent un niveau d'échappement avant d'arriver à
Python, y compris avec un délimiteur cité. Une continuation de ligne GDScript et un `"\n"`
littéral n'ont donc jamais pu être trouvés dans un fichier où ils étaient pourtant. La
parade est d'écrire le script de patch dans un fichier plutôt que de le passer en heredoc.

### Prochain jalon

**`F2b`** — les intentions, l'IA, la borne de tours, le pillage, le `DamageReport`. Il commence
par ta question et non par du code : le grain du vocabulaire d'intentions, et notamment si une
attaque à distance annonce sa case.

Puis **`F3b`**, l'intégration, qui n'attend que ce rapport. Puis **`M1`**, puis **`I3`**.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn` ni `project.godot` touché — les vues se bâtissent en code.

- **`HARNESS` vaut `&"battle"`.** Clic gauche : prendre un corps, ou l'emmener sur une case
  bleue. Clic droit : frapper une case rouge. `Entrée` finit le tour, `N` relance une bataille
  neuve, `H` montre les chiffres. La caméra garde ses touches : `Q`/`E` pivotent, `R` recadre.
- **Tu joues les deux camps**, exprès. Finis le tour et la vague devient jouable.
- **Deux drapeaux de capture neufs** : `--shot-select n` prend le corps de ce rang,
  `--shot-foes` passe la main à la vague. Documentés au README.
- **Les chiffres sont des placeholders** et le harnais le dit : quatre assaillants balaient
  trois défenseurs. C'est `I3`.
- **La branche n'est pas fusionnée** : `feat/f3a-battle-view`, huit commits en tout — cinq
  pour `F2a`, trois pour `F3a`.

---

## 2026-08-28 — `F2a` : le plateau existe, le relief joue, et les deux camps se ressemblent enfin

**État : terminé**, et `F2` est découpé en deux — `F2b` reste entier. Quatre commits sur
`feat/f2a-battle-board`, tirée de `master`. Les trois commandes passent : boot sans erreur
ni warning, tout `src/domain/` parse, **918 tests verts contre 826**, 50 suites contre 46.
Les neuf harnais ont été bootés un par un — un contrat a bougé.

### Pourquoi le jalon a été coupé en deux

Compté honnêtement, `F2` faisait vingt-cinq fichiers, une catégorie de `data/` de plus et
une centaine de cas — plus gros que `I1` et que `F1`. La découpe suit ce que chaque moitié
**touche**, comme `P1a`/`P1b` : `F2a` ne sort pas de `domain/combat/`, `src/schema/` et
`data/`, à un contrat près ; `F2b` porte tout ce qui **décide**.

Elle s'est trouvée justifiée pour une raison qu'on n'avait pas prévue : tu as rouvert le
système d'intentions en cours de session. Écrire un plateau ne l'attend pas ; écrire une IA
ne peut pas s'en passer. La coupure est tombée exactement sur cette ligne.

### Les deux corrections qui viennent de toi

**Les attaquants n'ont pas à être des généralités, et les défenseurs non plus.** Le plan
proposait `fighter_hit_points`, `fighter_attack` et consorts dans `CombatBalance` — c'est-à-dire
*un* soldat décliné en N exemplaires, pendant qu'`EnemyData` allait décrire des assaillants
tous différents. Un camp spécifique contre un camp générique n'est pas un combat tactique,
c'est une multiplication.

`CombatStats` est né de là, et c'est le premier DTO de `contracts/` créé depuis `F1` : **la
même forme pour les deux camps**. Un assaillant tient la sienne de son `EnemyData`, un
ouvrier de la projection des Effectifs, et le plateau ne sait pas laquelle il lit. C'est ce
qui permet au déplacement, à la portée et aux dégâts de s'écrire **une fois** — sans lui, les
deux camps auraient eu deux chemins de code et deux occasions de diverger sur ce que
« grimper » veut dire.

`CombatUnit` cesse donc d'être un multiplicateur. Son docstring gardait la place depuis `F1`
en toutes lettres — « ni PV, ni équipement, ni blessure… ce contrat lui laisse la place
d'ajouter ce dont il aura besoin » — et `F1` avait raison d'attendre : il aurait deviné.

Ce que ça a demandé de trancher, et ce n'était pas dans le plan : **ce qu'un palier de piste
Combat achète.** La réponse retenue est *les dégâts, et rien d'autre*. Un entraînement fait
frapper plus fort ; encaisser relève de l'équipement et de la constitution, donc de `X5` et
de `X6`. Lui faire multiplier les deux rendrait un vétéran deux fois meilleur sur deux axes à
la fois, ce qui est une courbe qu'on ne peut plus régler.

Tous les ouvriers ont donc les mêmes points de vie aujourd'hui — et ce n'est **pas** une
généralité de contrat, ce qui est toute la différence. Le chiffre voyage par unité, si bien
que la piste que tu gardes ouverte — des paliers qui donnent des stats, des PV tirés à la
création — ne changera que `Worker.to_combat_unit()`, un fichier, et le plateau ne s'en
apercevra pas.

**Il y a de l'aléatoire, et il est borné.** Chaque corps porte une fourchette de dégâts
plutôt qu'un chiffre : un combat entièrement calculable se calcule au lieu de se jouer. Le
tirage passe par le `RandomNumberGenerator` du run, jamais `randf()` — donc un seed plus une
suite de gestes rejoue une bataille à l'identique, et le déterminisme promis depuis `I0`
n'est pas entamé. Un cas de test le porte.

Les **pourcentages** que tu mentionnais en plus — infliger un effet — appartiennent à `X6`, et
`F2` n'en invente aucun : 3.6 est explicite, « il en inventerait quatre ». Le tirage aura sa
place au moment de frapper ; rien ne l'occupe.

### Les intentions, rouvertes, et ce que la session en retient

Tu as mis le doigt sur la vraie difficulté, et elle est structurelle : sur une grille où les
corps bloquent, le joueur agit **après** l'annonce, donc un trajet annoncé est soit
conditionnel — et l'information cesse d'être complète, ce que 3.6 refuse en toutes lettres —
soit rigide, et un ennemi enfermé cogne l'air.

Trois sorties ont été pesées, dont « un pion fait une chose par tour », que tu as écartée
parce qu'elle ralentit les combats. La direction retenue est plus vague, à la *Slay the
Spire* : on sait de quelle **nature** sera le tour d'un ennemi, sans son trajet ni sa case.

Ce que la conversation a fait apparaître et qui vaut d'être noté : **la difficulté ne venait
pas du « bouger *et* frapper », elle venait du trajet annoncé.** En ne déclarant que la
nature, l'IA se résout à l'exécution contre le plateau réel, et le blocage cesse d'être un
cas à traiter — sans rien coûter au rythme. Le plateau a donc été écrit pour qu'un corps
puisse se déplacer et frapper dans le même tour, ce qui est la lettre de 3.6.

Reste à trancher, et c'est la première chose de `F2b` : si une attaque **à distance** annonce
sa case. L'argument pour est qu'un tireur qui ne bouge pas a une visée que rien ne peut
invalider sauf l'esquive, donc que c'est exactement là que la règle de 3.6 a un sens.

### Ce que le relief fait, et l'asymétrie qui se discute

Trois précisions que l'écriture a demandées. Le déplacement est **orthogonal** et la portée
en **Manhattan** : mélanger deux métriques sur la même grille produit des distances qu'on ne
peut pas lire à l'œil, et une case atteignable en deux pas qui serait « au contact » ferait
mentir toute case allumée à l'écran. Un mur, un chantier et un corps **barrent de la même
façon** — c'est la seule tactique que `F2a` livre.

Et **descendre ne coûte que le pas**, quelle que soit la chute. Celle-là se discute, donc
elle est dans `DESIGN.md` : elle fait d'une hauteur une position qu'on *tient* — longue à
gagner, facile à quitter — plutôt qu'un mur qui enferme aussi celui qui est dessus. Un
défenseur peut sauter d'un plateau pour rompre le contact, et l'assaillant devra remonter.

La marche franchissable est **par corps** et non globale, ce qui laisse la place à un
assaillant qui escalade là où les autres contournent — le Colosse de `data/enemies/` en
franchit deux là où tout le monde en franchit un.

### Ce que les tags de terrain ont évité

`impassable_tags` vit dans `data/balance/` et non dans le code, parce que le domaine aurait
sinon écrit `&"water"`. C'est le même geste que `combat_skill_family` à `F1`.

Il est le seul champ neuf **réclamé non vide**, et la raison mérite d'être notée : Godot
n'écrit pas un tableau vide dans un `.tres`, donc « oublié » et « délibérément vide » y sont
indiscernables — c'est exactement le piège de `resolves`. L'issue de `PhaseDef`, faire monter
la règle d'un cran, ne s'applique pas ici : aucun bloc au-dessus ne voit cette liste. Un
combat où l'on marche sur l'eau n'est pas un modèle qu'on essaie, c'est un champ perdu.

### Ce que le harnais a trouvé tout seul, et c'est le meilleur du jalon

Deux défauts, tous deux au premier lancement, et **aucun n'était cherché**.

**Le village se bâtissait contre le bord haut de la carte.** `_raise()` posait chaque
bâtiment sur la première ancre acceptée en balayant depuis l'origine — le harnais Combat fait
pareil et ne s'en aperçoit pas, parce qu'aucune de ses tables n'est géométrique. La lisière du
bâti touchait donc le bord, et une vague qui arrive du nord n'avait **aucune** case où entrer.

La table l'a dit en toutes lettres — « entrée de la vague : aucune » — sous un damier
parfaitement aligné. C'est la variante *utile* du défaut que `F1` a décrit : elle n'a pas
menti, elle a annoncé qu'elle n'avait rien à montrer. Et c'est le verdict en fin de fichier
qui l'a rendue lisible, ce qui est précisément ce à quoi il sert.

**Et à ces chiffres-là, une vague de quatre balaie trois défenseurs en deux manches sans
perdre personne.** Le verdict demande à l'échange « d'entamer quelque chose sans tout finir » ;
il finit tout, du mauvais côté. Le harnais **dit lui-même** le constat sous la table plutôt
que de laisser un critère que sa propre table contredit — un verdict faux serait exactement
le tableau aligné, plausible et faux que `CLAUDE.md` refuse depuis `F1`. C'est un chiffre pour
`I3` et pas une règle.

La table du blocage a gagné une seconde colonne prise sur le **voisinage** et non sur le
parcours, par la règle de `I2b` : deux colonnes tirées du même compteur ne prouvent rien en
se ressemblant. Elle lit treize cases contre une, et une sortie contre zéro — ce qui dit
qu'on tient une porte, pas qu'un calcul a raté.

### Deux pièges de test, tous deux silencieux

**Un coup dans le vide réussit et rend zéro.** C'est la règle d'esquive qui fonctionne — et
c'est ce qui a fait qu'un cas censé mesurer une fourchette de dégâts ne mesurait rien du tout,
faute de cible sur la case visée. Le cas échouait, ce qui est la chance ; il aurait pu passer.

**Et « un village à l'étroit rend moins de cases » a d'abord été écrit avec une carte
étroite**, ce qui était faux : une bande de deux cases de large offre autant d'entrées qu'on
veut dès qu'on s'éloigne. Ce qui manque à un village acculé est la **profondeur**, jamais la
largeur. Le cas serait passé au vert pour la mauvaise raison.

### Le piège GDScript, entré dans `CLAUDE.md`

Un `enum` déclaré dans une classe doit être **qualifié** dans les signatures de cette classe :
`static func create(side: Side)` compile, puis refuse ce que tout appelant lui passe, parce
que GDScript traite le `Side` interne et le `Combatant.Side` du dehors comme deux types
distincts. Attrapé par le parsing, invisible à la lecture.

### Ce qui ne bouge pas

`InstantCombatResolver` est **intact** : il fait encore tourner le jeu, et `F3` l'échangera.
Le harnais `combat` de `F1` reste à côté du nouveau pour la même raison — il calibre le
bouchon. Aucune ligne de `RunOrchestrator.fight()`, d'`EventBus` ou de `src/adapters/`.

`DamageReport` n'a **pas** bougé non plus, alors que tu as validé qu'il le fasse : il perdra
`assault`, `defense` et `breach()` et gagnera `swept()` à `F2b`, quand il y aura un rapport à
produire. Un contrat qu'on casse avant d'avoir son nouveau producteur est un contrat cassé
deux fois.

### Prochain jalon

**`F2b`**, et il commence par une question de design plutôt que par du code : le grain du
vocabulaire d'intentions, et notamment si une attaque à distance annonce sa case.

Puis **`M1`**, le menu, inchangé — c'est toujours l'écran de fin de `P2a` qui le rend
nécessaire, et toujours le premier jalon qui demande une `.tscn` et la scène principale.

Puis **`I3`**, qui a maintenant deux fronts au lieu d'un : la nourriture — vingt-sept
récoltées pour quatre-vingt-cinq dues — et le combat, dont le harnais dit déjà que la vague
est trop dure de beaucoup.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **`HARNESS` vaut `&"battle"`** — le nouveau harnais, un rapport texte avec un damier.
  `&"combat"` rend les tables du bouchon, `&"run"` rend le jeu.
- **Le damier se lit ainsi** : un chiffre est la hauteur du relief, `#` un bâtiment, `+` un
  chantier, `~` de l'eau, `^` du rocher ; une majuscule est un ouvrier engagé, une minuscule
  un assaillant. La seconde carte remplace le décor par le **coût** pour aller sur chaque case.
- **`data/enemies/` est neuf** — trois assaillants, un au contact, un lourd qui grimpe, un à
  distance. Leurs chiffres sont des placeholders assumés.
- **La branche n'est pas fusionnée** : `feat/f2a-battle-board`, quatre commits.

---

## 2026-08-27 — `P2b` : la journée se souvient d'elle-même, et le soir a quelque chose à lire

**État : terminé**, et `P2` avec lui. Trois commits sur `feat/i2b-knobs`. Les trois commandes
passent : boot sans erreur ni warning, tout `src/domain/` parse, **826 tests verts contre
810**. Quatre captures.

C'est le seul point de la famille `P2` qui touche le domaine, et il a fallu commencer par
là : **rien ne se souvenait d'une journée.**

### Le manque, et où il était

Chaque `PhaseReport` était émis puis oublié, et `DayReport` ne porte que l'upkeep et la
vague. Une journée n'existait donc nulle part entre ses phases : le joueur qui voulait
savoir ce qu'elle avait rapporté n'avait qu'un compte rendu de phase, dont la moitié était
déjà remplacée par la suivante.

`RunState` retient désormais les rapports des phases **qui ont résolu**, une journée neuve
les efface, et `RunOrchestrator.day_summary()` en compose un `DaySummary` avec ce que le
village doit à manger. L'accumulation est dans le domaine et non dans une vue, par
l'argument que `DESIGN.md` 2 donne depuis l'écriture du jalon : l'événement de 3.7 et les
états d'ouvrier de `X6` voudront tous deux poser une ligne dans ce bilan, et un accumulateur
d'adapter devrait réapprendre chaque nouvelle source.

Trois précisions que l'écriture a demandées, et aucune n'était dans la ligne de `DESIGN.md`.

**Seules les phases qui résolvent entrent.** Une phase qui ne résout pas n'a rien produit,
donc rien à additionner — et la compter parmi les résolutions ferait mentir la seule colonne
du bilan qui dise combien de fois la journée a travaillé. Le modèle retenu à `I2b` en a
justement une par jour.

**L'effacement se lit sur `advance()`.** Le cycle dit lui-même qu'un jour vient de s'ouvrir,
ce qui évite à `RunState` de porter un souvenir de plus — comparer un numéro de jour d'avant
à un numéro d'après aurait été exactement le genre d'état que `I2` a refusé pour la vague en
attente.

**La coupure de bataille tient.** Quand une vague attend, le cycle ne bouge pas, donc le
bilan est encore là : on lit sa journée, on se bat, et c'est la bataille qui ouvre le
lendemain — donc qui efface. Un cas de test l'épingle, parce que ça se lit mal.

### Le refus qui porte le jalon

**Le bilan ne compte aucun oisif**, et il n'a pas d'accesseur pour ça.

Un oisif est un état de **phase**. Quelqu'un qui chôme le matin et travaille l'après-midi
n'est pas un demi-oisif, et additionner deux ensembles de personnes rend un nombre qui ne
désigne personne. Les postes tenus, eux, s'additionnent sans mentir : ce sont des
**affectations** et non des gens, donc « la journée a fait travailler douze fois quelqu'un »
veut dire quelque chose.

C'est la même distinction que `I2b` avait tirée un cran plus bas — une phase qui ne résout
pas ne compte aucun oisif, parce qu'un oisif est un reproche et qu'un reproche suppose qu'on
pouvait faire autrement. Ici la raison change : ce n'est plus « on ne pouvait pas », c'est
« ce n'est pas une quantité ».

Un cas de test le vérifie, et c'est le seul du fichier qui vérifie une **absence** : tous les
autres contrôlent une addition, ce qui se relit d'un coup d'œil, alors qu'un refus ne se
relit nulle part. Sans lui, le premier écran qui réclamerait « et les oisifs ? » les
obtiendrait.

### Le chiffre qui doit être le même des deux côtés

`ProductionResolver.upkeep_due()` devient publique, troisième fois après `staffing_refusal()`
à `I1` et `family_of()` à `W2`, et toujours pour le même motif : une seconde question se pose
sur la même règle. Le bilan se lit **avant** la fermeture, donc avant qu'on ait rien prélevé,
et il doit pourtant annoncer ce qu'on doit.

Les deux appelants passent par la même multiplication plutôt que de la recopier, et le cas de
test qui compte croise les deux : **ce que le bilan annonce comme dû est exactement ce que la
fermeture prend**. Le jour où ce qu'on doit dépendra d'autre chose que du nombre de présents
— un blessé qui mange double, un absent d'expédition qui ne mange pas —, l'annonce et le
prélèvement bougeront ensemble ou pas du tout.

### Ce que la vue demande, et ce qu'elle ne calcule pas

Elle n'additionne rien : le bilan arrive fait. Elle pose **deux questions** au domaine et
dessine les réponses — la seconde étant celle qui compte le plus du soir. « La réserve
paiera-t-elle l'upkeep ? » va au `Ledger`, et la ligne vire à l'orange quand non. Savoir
qu'on va manquer **avant** de fermer est la seule chose de ce panneau sur laquelle on puisse
encore agir ; après, c'est une famine constatée.

Elle s'ouvre sur une **question au domaine** et jamais sur un nom de phase : *cette phase
ferme-t-elle la journée sans rien autoriser ?* C'est ce qui garde la promesse d'échanger la
journée par un `.tres` — le modèle à deux phases, dont la dernière se joue encore, n'ouvre
pas de modale par-dessus les cartes. La touche `B` l'ouvre à tout moment, ce qui lui rend son
accès dans ce modèle-là.

### Les deux horloges, réparées par les deux bouts

Le compte rendu de phase annonçait « Jour 3 · Soir » pendant que le bandeau annonçait
« Jour 4 · Matin ». Son bandeau ne disait quelque chose qu'à la fin d'une journée — « fin de
journée » — et restait **vide** le reste du temps, si bien que le titre se lisait comme
l'état courant alors qu'il nomme la phase qui vient de finir.

Le bilan prend en charge « où en est-on », et le panneau annonce désormais son propre temps —
**passé** — à toutes les résolutions. Une ligne de code, et le malentendu tombe.

### Le défaut trouvé en capture, et il est instructif

Le bilan **s'ouvrait et se refermait dans la même fonction**. Le harnais le fermait après
`RunManager.end_phase()`, ce qui semblait l'ordre naturel : on finit la phase, puis on range
ce qu'on lisait. Or cette porte publie `phase_changed` **avant de rendre la main**, donc la
phase suivante rouvrait le bilan à l'intérieur de cette ligne — et la ligne d'après le
refermait aussitôt.

Le symptôme est muet : rien ne plante, rien ne compile de travers, le soir s'affiche
simplement sans son bilan. Seule une capture le montre. La règle en sort et vaut plus que le
cas : **ce qu'on range avant un appel appartient à ce qui précède ; ce qu'on ouvre après
appartient à ce qui suit.** Un bus de signaux rend l'ordre des lignes trompeur, parce qu'une
partie de la suite s'exécute au milieu de l'appel.

### Ce qui ne bouge pas

**Aucun DTO de `contracts/` n'a été créé ni modifié**, le septième jalon d'affilée après
`E2`, `W2`, `P1a`, `P1b`, `I2b` et `P2a`. `DaySummary` vit dans `domain/run/` par le critère
habituel : aucun second système du domaine ne le franchit — il va du Cycle de jour aux
adapters, et `DESIGN.md` 3.8 pose que ce système-ci est justement celui qui a le droit de
connaître tous les autres.

### Prochain jalon

**`M1`**, le menu. C'est l'écran de fin de `P2a` qui le rend nécessaire : proposer de
relancer désigne un endroit d'où l'on lance, et il n'y en a pas. C'est aussi le **premier
jalon du projet qui demande une `.tscn` et la scène principale de `project.godot`**, donc le
premier que je ne peux pas livrer seul — je décrirai l'arbre, tu le câbleras.

Puis **`I3`**, avec la nourriture en tête et son premier chiffre : vingt-sept récoltées pour
quatre-vingt-cinq dues sur quinze journées.

`M2` — la persistance — attend toujours une mesure et non du temps : **combien de temps te
prend un run joué à la main.**

Et **l'arbitrage de `I2b` reste ouvert**. Il ne se referme qu'en jouant, et `P2` vient de
rendre ces quinze journées nettement moins pénibles à mener — ce qui était tout son objet.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché. `M1` sera le premier à en
demander.

- **Le soir ouvre un bilan.** Ce que la journée a récolté, les paliers, les chantiers, ce
  qu'il y a à nourrir ce soir — et la vague, quand il y en a une. Le bouton **Finir la
  journée** referme le bilan et ferme la journée : c'est le même geste, pas deux.
- **`B` ouvre le bilan à tout moment**, et le referme. Un clic à côté le referme aussi, pour
  regarder le village avant de décider.
- **La ligne « À nourrir ce soir » vire à l'orange** quand la réserve ne suivra pas. C'est la
  seule chose du soir qu'on puisse encore corriger.
- **Le compte rendu de phase dit « résolu »** à chaque résolution. Il parlait au présent
  d'une phase passée, ce qui le mettait en contradiction avec le bandeau juste à gauche.
- **La branche n'est pas fusionnée** : `feat/i2b-knobs`, onze commits — six pour `I2b`, un
  pour `DESIGN.md`, deux pour `P2a`, trois pour `P2b`.

---


## 2026-08-27 — `P2a` : le pas se nomme, la fin se regarde, et trois défauts plus vieux que le jalon

**État : terminé.** Deux commits sur `feat/i2b-knobs`, à la suite de `I2b`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **810 tests
verts** — inchangés, le jalon ne touche pas au domaine. Cinq captures.

Il vient de plusieurs runs complets joués à la main, comme `P1` avant lui, et il en livre
les deux points qui ne demandent rien au domaine. `DESIGN.md` a été écrit d'abord, dans son
propre commit : deux de ces points ouvrent des jalons, et le quatrième **rouvre une ligne
du hors-périmètre**.

### Ce que le bouton corrige, et ce que ce n'est pas

`Entrée` faisait déjà cinq choses selon l'état du run — fonder, finir la phase, fermer la
journée, tenir la ligne, et depuis ce jalon relancer. Le manque n'était donc pas un geste :
c'est qu'elle les faisait **sans le dire**. La seule chose de l'écran qui annonçait lequel
des cinq allait tomber était une ligne du pavé de texte, au milieu de l'aide au clavier,
c'est-à-dire dans la zone qu'on cesse de lire au bout de deux minutes.

Le bouton n'ajoute rien : il rend visible une dispatch que le harnais calculait déjà pour
router `Entrée`. Les deux chemins la refont **dans le même ordre**, et il fallait le noter
en toutes lettres — `StepButton.show_state()` et `_press_on()` doivent départager les cinq
cas identiquement, sans quoi le bouton proposerait un pas que la touche ne ferait pas.

**Aucun nom de phase n'y entre**, ce qui est la contrainte de `DESIGN.md` 2 depuis `I1` :
les cinq libellés viennent de quatre questions au domaine. Une journée à une seule phase
dirait « Finir la journée » du premier coup, ce qui est exact.

Il vit **dans la bande de la main** et non dans la colonne de droite. Ce n'est pas une
préférence : cette colonne a débordé trois fois — `W2`, `I2`, `P1a` —, et on ne lui confie
pas le geste le plus fréquent du jeu. La marge se demande à `HandView`, qui a gagné un
troisième accesseur de mesure après `band_height()` et `band_bottom()` ; et la capture
imprime désormais une seconde ligne de mise en page, couchée cette fois — où finissent les
cartes, où commence le bouton, lequel mord sur l'autre.

**Il double le bouton de `BattlePanel`, et c'est délibéré.** Le doublon que ce projet
refuse porte sur un *chiffre* affiché deux fois, qui finit par différer de lui-même ; ici
il n'y a qu'un geste, offert à deux endroits — comme le chevron de repli et `F2`, ou Espace
et le clic sur une fiche. Le panneau garde le sien parce qu'il montre ce qu'on affronte.

### L'écran de fin, dont la place était gardée sans qu'on l'ait dit

`EventBus` porte deux signaux distincts depuis `I2`, et le commentaire qui les sépare
écrivait déjà la phrase : « l'un annonce qu'une partie est **jouée**, l'autre qu'elle est
**rangée**. Un écran de fin vit entre les deux. » Il n'y avait qu'une vue à écrire, et elle
écoute `run_finished` — écouter `run_ended` aurait fait apparaître le verdict au moment où
le run disparaît.

Le pavé de texte **perd** la cause et le détail du score au lieu de les doubler, quatrième
fois après `E2`, `W2` et `P1b`. Ce que le bandeau garde est un mot et un total, ce qu'un
bandeau sait porter.

**Relancer prend le seed suivant.** Un tirage libre rendrait le harnais différent à chaque
lancement, donc les captures incomparables d'une session à l'autre — et la chronique de
`I2b` a précisément besoin que quatre runs partent du même endroit. `+ 1` est frais pour le
joueur et reproductible pour nous ; l'écran l'affiche.

`--shot-restart` naît de la porte habituelle, cinquième drapeau nu : relancer ne s'obtient
que par un clic sur un écran de fin, donc aucune suite de journées ne le produit.
`_restart()` reconstruit un run entier — relief compris — et aurait été le seul chemin de
cette taille qu'aucune passe automatique n'emprunte jamais.

### Trois défauts trouvés en regardant, et deux sont plus vieux que le jalon

**Le pavé d'aide était double-interligné, et c'est moi qui l'avais cassé.** Mes scripts
d'édition écrivaient les fichiers sans forcer `LF`, donc les convertissaient en **CRLF** —
et Godot lit un `\r` isolé comme un saut de ligne de plus. Toute chaîne multi-ligne d'un
script se dessinait donc avec une ligne vide entre chaque ligne.

Ce qui rend le cas instructif est **où il n'apparaissait pas** : ni au boot, ni au parsing,
ni aux 810 tests, et pas non plus dans le dépôt, que git normalise en `LF` au commit. Le
défaut n'existait que dans la copie de travail, c'est-à-dire exactement dans ce qu'une
capture montre. Les warnings `CRLF will be replaced by LF` de `git add` étaient le signal,
et je les ai pris pour du bruit préexistant pendant tout `I2b`.

**« Main vide » se dessinait une lettre par ligne**, à la verticale, sur l'écran de
fondation — **depuis `I2`**. Un `Label` en autowrap déclare une largeur minimale minuscule ;
seul enfant d'un conteneur qui distribue, il reçoit cette largeur-là et se coupe par
caractère. C'est la règle que `P1a` avait tirée à moitié : elle disait « tout libellé qui
porte un nombre passe en `AUTOWRAP_OFF` », alors que la cause n'a rien à voir avec les
nombres. Et l'ironie est nette — c'était le seul texte de la seule image que
`--shot-evenings 0` existe pour montrer.

Le même libellé **mentait une fois sur deux** : il annonçait « Entrée termine la phase » sur
un écran où Entrée pose le Cœur. Une main est vide dans deux situations, et la phrase
n'était juste que dans la seconde. Elle ne nomme plus rien du tout : le bouton s'en charge,
et il ne se trompe dans aucune des deux.

**Le panneau d'affectation annonçait « cette phase ferme la journée » à un run terminé**,
qui n'en a plus aucune. Même famille que ce que `I2b` venait de corriger sur la même vue, un
cran plus loin, et trouvée de la même façon — en regardant l'écran d'un état que le jalon
venait de rendre atteignable.

### Ce que `DESIGN.md` a gagné avant le code

Quatre points écrits, dont deux ne sont pas de ce jalon.

- **2** gagne la seconde moitié du soir : on y **lit sa journée** avant de la fermer. Il
  tombe à l'entrée du soir et non après, ce qui échange une nuance — l'upkeep est annoncé
  comme *dû* et non comme mangé — contre deux choses qui valent mieux : aucun geste de plus,
  puisque le bouton qui referme le bilan est celui qui ferme la journée, et un soir qui a
  quelque chose à montrer. C'est `P2b`, et **quelqu'un devra se souvenir de la journée**, ce
  que rien ne fait aujourd'hui.
- **5** gagne l'écran de fin, fait ici.
- **6** devient « autour du run » et gagne le **menu** — une `.tscn` et la scène principale
  de `project.godot`, donc l'humain — et un `OUVERT` sur la **persistance**.
- **7** perd sa ligne « pas de sauvegarde en cours de run », qui devient une question.

Sur la persistance, l'apport du jour est un rappel plutôt qu'une réponse : **l'architecture
paie déjà une sauvegarde bien moins chère qu'un instantané.** Un seed plus une liste de
gestes rejoue un run à l'identique — promis depuis `I0`, vérifié par un cas de test depuis
`I1`. Un journal de gestes coûte un fichier et zéro format par système ; sérialiser
`RunState` demande à sept états d'en avoir un, plus une migration. Le défaut du rejeu est
net et il est écrit : **toute sauvegarde meurt au prochain changement d'équilibrage**. Ce
qui tranche est une mesure que personne n'a prise — combien de temps prend un run joué à la
main —, et c'est `M2`.

### Prochain jalon

**`P2b`**, le bilan de journée, seul point de `P2` qui reste et le seul qui touche le
domaine. Puis **`M1`**, le menu, que l'écran de fin rend nécessaire en proposant de
relancer.

Et **l'arbitrage de `I2b` reste ouvert** : il ne se referme qu'en jouant.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché — `M1` sera le premier
jalon à en demander.

- **Un bouton en bas à droite** dit le pas qui vient et le fait au clic. `Entrée` reste le
  raccourci et fait exactement la même chose.
- **Un run fini ouvre un écran**, avec le score et ses quatre termes. **Relancer** ouvre un
  run neuf sur le seed suivant, affiché. Un clic à côté referme l'écran pour regarder le
  village ; le bouton en bas à droite dit toujours « Relancer ».
- **Le pavé de texte a maigri** : la cause et le détail du score sont dans l'écran de fin.
- **Un drapeau de plus** : `--shot-restart`, nu, relance avant de capturer.
- **La branche n'est pas fusionnée** : `feat/i2b-knobs`, huit commits — six pour `I2b`, deux
  pour `P2a`.

---


## 2026-08-27 — `I2b` : les deux boutons posés, la journée gagne un soir, et ce qui reste est de jouer

**État : partiel, et c'est sa forme normale.** Cinq commits sur `feat/i2b-knobs`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **810 tests verts
contre 786**. Quatre captures et une chronique.

Partiel parce que `I2b` est un **playtest**. Ce qu'un jalon peut livrer, ce sont les boutons
et de quoi les comparer ; l'arbitrage des deux `OUVERT` se joue au clavier, quinze journées
à la fois, et personne d'autre que toi ne peut le faire.

### La promesse de `DESIGN.md` 8, vraie à moitié

Le jalon était annoncé ainsi : « les deux se testent en échangeant un `.tres` », et « c'est
la première fois du projet qu'un jalon ne demande pas d'écrire une ligne de GDScript ».

**La structure de la journée l'était.** `PhaseDef` et `RunBalance` ont tenu leur promesse
mot pour mot depuis `I1` : le cycle ne connaît aucun nom, `end_phase()` lit `resolves()` et
`closes_the_day()`, et l'on peut écrire un troisième modèle sans toucher au code.

**Le sort de la main ne l'était pas.** `RunOrchestrator.end_phase()` appelait
`state.deck().discard_hand()` **sans condition**, et aucun champ de `DeckBalance` ne le
réglait. Le domaine avait pourtant été écrit pour accueillir la réponse — `discard_hand()`
se dit « une capacité, pas une politique », et `Deck.discard()` désigne l'endroit en toutes
lettres — mais personne n'avait posé le bouton.

C'est la quatrième correction de `DESIGN.md` par un jalon après `D2`, `W2` et `F1`, et ce
qu'elle apprend n'est pas « on s'était trompé » mais **où** : la promesse portait sur deux
questions, une seule avait sa prise, et rien ne les distinguait tant qu'on ne cherchait pas
à tourner le bouton. Un jalon annoncé « sans code » mérite qu'on vérifie, **avant de le
planifier**, que chacune de ses questions a vraiment la sienne.

### Le troisième modèle de journée, et ce qu'il coûte

Il vient de toi, en cours de session, et ce n'est aucun des deux que 2. mettait sur la
table : deux phases symétriques qui posent, affectent et résolvent, puis **un soir** qui
n'autorise rien, ne résout rien, et se contente de fermer la journée.

Le domaine le supportait déjà, mot pour mot — `resolve()` porte depuis `I1` la phrase « une
phase qui ne résout pas mais ferme la journée ne produit rien et prélève quand même », et
`_scripted_day()` du harnais annonce « une journée de trois phases se joue sans qu'une ligne
bouge ». **Une seule chose le refusait**, et au boot : `PhaseDef` rejetait une phase qui
n'autorise rien et ne résout pas, au motif qu'elle n'est qu'un tour perdu.

Le motif était bon et la conclusion fausse. Fermer une journée prélève l'upkeep et fait
tomber la vague, ce qui n'est ni autoriser ni résoudre — et une `PhaseDef` ne sait pas
qu'elle est la dernière. La règle est montée d'un cran, dans `RunBalance`, qui voit la
liste : même partage que l'unicité de `id` et que `phases.none_resolves`. Le test à faire
avant d'écrire un `missing_fields()` tient donc en une question — *cette `Resource` a-t-elle
sous les yeux tout ce que la règle regarde ?*

**Ce que le soir gagne** : ce que la journée coûte cesse d'être noyé dans une récolte, et la
vague tombe dans un moment qui n'est que le sien. **Ce qu'il coûte** : un `Entrée` de plus
par jour, et rien d'autre — la chronique le chiffre plus bas.

Deux conséquences à connaître pour le lire, aucune n'était évidente d'avance. La main est
tirée à la fin de la dernière phase qui **produit**, donc elle traverse le soir intacte : on
regarde l'upkeep tomber en tenant déjà celle de demain matin. Et le soleil s'en accommode
sans une ligne — `dev_world` prend la position de la phase dans sa journée en fraction,
donc trois phases gagnent un midi là où deux ne montraient que les deux bords.

### Le bouton de report, et pourquoi son milieu est refusé

`DeckBalance.carry_over` dit **par pool** combien de cartes non jouées survivent à une phase
qui résout, et `RunState.draw_phase()` **complète** la main au lieu d'en servir une neuve.

C'est ce complément qui donne son prix au report : **une carte gardée est une carte de moins
piochée**. Sans lui, garder sa main serait gratuit — cinq actions reportées *plus* cinq
fraîches — et le pool cesserait d'être la contrainte que 3.5 en fait. Il rend du même coup
inutile la « limite de jeu par tour » que ce document adjoignait à la main persistante : le
plafond est la taille de la main elle-même.

**Deux valeurs, et le milieu est refusé.** Garder deux cartes sur cinq demande de dire
*lesquelles*, et la seule règle qui ne choisisse pas à la place du joueur est qu'il
choisisse — donc une modale de fin de phase, donc un écran qui n'existe pas. Le résoudre par
une règle d'ancienneté aurait **répondu à l'`OUVERT` par un arbitraire enfoui dans un
résolveur**, ce que `P1b` a refusé au recensement des piles pour la même raison. Le refus
vit dans `missing_fields()` : la cohérence devient structurelle au lieu d'être vérifiée,
même geste que le bloc `production` nullable de `E1b`. Le jour où le geste existe, c'est ce
contrôle-là qui se desserre et rien d'autre.

Un entier plutôt qu'un booléen, alors que deux valeurs légales font un booléen : `hand_size`
diffère d'un pool à l'autre — cinq actions, deux bâtiments —, donc « tout garder » n'est pas
le même nombre partout, et l'écrire permet au contrôle de **croiser les deux champs**. Un
booléen n'aurait rien eu à croiser.

La quatrième piste de 3.5, « défausser contre une petite ressource », n'entre pas et ne
pouvait pas : c'est une conversion qui touche la réserve **plus** un geste pour désigner
quoi vendre. Ce n'est pas un bouton, c'est une mécanique.

### Ce que la chronique a mesuré

`--chronicle` rejoue le run entier sous les quatre croisements — deux modèles de journée ×
deux sorts de la main —, sur le même relief et les mêmes gestes, et rend quatre tables.
Chacune annonce ce qu'elle doit montrer ; le verdict dit ce qu'elle ne montrera jamais.

**Le soir ne coûte rien.** Les tables A, B et D sont **identiques** entre deux et trois
phases : trente résolutions, quinze upkeeps, même score, même réserve, même date de famine.
C'était l'inquiétude d'entrée du jalon — l'upkeep suit la journée, la récolte suit la phase
qui résout, donc un modèle qui résout moins produit moins à coût constant — et elle ne
s'applique pas à ce modèle-ci, précisément parce que le soir ne résout pas. Le seul écart est
de sept cartes servies sur tout un run, et il vient du dernier jour : à deux phases la vague
s'arme sur la dernière phase qui produit, donc la pioche qu'elle diffère n'a jamais lieu.

**Le report n'est pas gratuit, et le chiffre le dit.** Un run qui défausse voit **210 cartes**
et en joue 167 ; un run qui garde en voit **153** et en joue 153. La pioche ne sert plus que
ce qu'on a dépensé, exactement comme annoncé. Les quarante-trois cartes « perdues » — parties
sans avoir été jouées — tombent à zéro, ce qui est la question de 3.5 réduite à une colonne.

**La famine est un chiffre d'équilibrage, pas un modèle.** Elle tombe au **sixième jour dans
les quatre variantes**, et l'ampleur est plus grande qu'« un peu juste » : vingt-sept
nourritures récoltées pour quatre-vingt-cinq dues sur quinze journées. Le village mange un
jour sur trois. C'est `I3`, et la chronique vient de lui donner son premier chiffre.

**Ce que la chronique ne dit pas, et il faut le répéter.** Le run reporté finit mieux — 350
contre 307, vingt-cinq bâtiments contre dix-neuf, trois survivants contre deux — et **ce n'est
pas une preuve**. Le scripteur joue une carte de chaque nature sur la première cible venue
et remplit au bouton Auto : il ne joue pas bien, il joue *pareil* quatre fois. Une main qu'on
garde avantage mécaniquement un joueur qui ne choisit pas, puisqu'elle lui rend jouable ce
qu'il aurait défaussé. Ce que ça vaut pour quelqu'un qui choisit est exactement la question
qu'il faut jouer.

### Les trois défauts trouvés en regardant, et aucun cherché par un test

Le jalon en a trouvé un par capture et deux par relecture de table, ce qui est la répartition
habituelle depuis `E2` — sauf que cette fois les deux derniers étaient dans l'instrument
lui-même.

**L'écran promettait un geste que le domaine refuse.** Dans le soir, la main s'affichait à
pleine encre, numérotée, curseur de main compris, et le panneau d'affectation conseillait de
« prendre une carte et cliquer une cible » — pendant que `play()` répondait `wrong_phase` à
chaque clic. Ce n'est pas la faute d'architecture habituelle : la vue ne **jugeait** rien,
elle ne **demandait** rien non plus. `HandView` interroge donc `DayCycle.permits()` comme
elle interroge `Ledger.can_afford()`, et affaiblit la même encre — les deux disent « pas
maintenant », et ce qui les sépare est une raison, donc une infobulle.

**Le soir annonçait six oisifs** à qui venait de faire travailler ses six ouvriers tout
l'après-midi. Vrai au mot près, faux à la lecture. Un oisif est un **reproche**, et un
reproche suppose qu'on pouvait faire autrement ; dans une phase où personne ne peut être
affecté, tout le roster est trivialement oisif. La réparation est du domaine et non de la
vue : une phase qui ne résout pas n'en compte aucun.

**Et la chronique s'est trompée deux fois avant d'avoir raison**, des deux façons que `F1` a
nommées. Elle comptait une défausse et une pioche entières sur une phase qui ne résout pas et
ne touche donc à rien — vingt et une cartes par journée pour une main de sept sur deux
résolutions, parfaitement alignées et fausses de moitié. Et elle comptait les cartes **avant**
la bataille, alors que c'est elle qui ouvre la phase suivante quand une vague attend : le
modèle à deux phases annonçait sept cartes servies le jour d'une vague et quatorze les
autres, ce qui n'était pas une différence de jeu mais un défaut de mesure. Une troisième du
même sang : la table A imprimait le même accumulateur sous « jours » et sous « upkeeps »,
donc leur égalité — qui est *l'énoncé le plus important du tableau* — était une tautologie.
**Une colonne qui doit en corroborer une autre se prend ailleurs.**

### Ce qui ne bouge pas

**Aucun DTO de `contracts/` n'a été créé ni modifié**, le cinquième jalon d'affilée après
`E2`, `W2`, `P1a` et `P1b`. Le sort de la main ne sort jamais du couple Deck+Run, et le soir
ne franchit aucune frontière : `PhaseReport` le portait déjà.

Le domaine gagne trois choses et pas une règle de jeu inventée : `Deck.discard_pool()`, dont
`discard_hand()` devient la boucle — deux façons de vider une pile finiraient par différer,
et celle des deux que le jeu n'emprunte plus est celle qui dérive ; une pioche qui complète ;
et une porte qui lit `carry_over`.

### Prochain jalon

**Jouer.** C'est la moitié de `I2b` qu'aucun commit ne peut faire, et elle attend deux
réponses : est-ce que le soir se joue ou s'endure, et est-ce qu'une main qu'on garde rend le
tour plus riche ou plus mou. Les quatre variantes se montent en repointant une ligne de
`balance.tres`.

Puis **`I3`**, la nourriture en tête, avec son premier chiffre : vingt-sept récoltées pour
quatre-vingt-cinq dues.

De la famille `P` il ne reste que **`P1c`**, qui attend toujours une question de design et
non du temps : comment désigner l'une des deux actions d'une même case.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **La journée fait trois phases** : Matin, Après-midi, puis **Soir**. Le soir n'autorise
  rien — `Entrée` le passe, et c'est là que l'upkeep tombe et que la vague arrive.
- **Pour revenir au modèle à deux phases** : dans `data/balance/balance.tres`, faire pointer
  `run` sur `run_balance_two_phases.tres` au lieu de `run_balance.tres`.
- **Pour essayer la main persistante** : même fichier, faire pointer `deck` sur
  `deck_balance_persistent.tres` au lieu de `deck_balance.tres`. La main survit alors d'une
  phase à l'autre et la pioche complète — garder une carte, c'est en piocher une de moins.
- **Un drapeau de plus, et le premier qui ne capture rien** : `--chronicle`, sans `--shot`,
  rejoue le run sous les quatre variantes et imprime les tables. Il quitte tout seul.
  ```
  "$GODOT_BIN" --headless --path . -- --chronicle
  ```
- **Dans une phase qui ne pose rien**, la main est en encre faible et l'infobulle dit
  pourquoi. Ce n'est pas la même pâleur que « réserve insuffisante », c'est la même encre
  avec une autre raison.
- **La branche n'est pas fusionnée** : `feat/i2b-knobs`, cinq commits.

---


## 2026-08-27 — `P1b` : la colonne tient, les piles se lisent, la fiche raccourcit

**État : terminé.** Quatre commits sur `feat/p1b-lists`. Les trois commandes passent : boot
sans erreur ni warning, tout `src/domain/` parse, **786 tests verts contre 779**. Huit
captures, à trois résolutions.

Le jalon livre **quatre** points et non trois. Le quatrième — la fiche d'ouvrier compacte —
vient de l'humain à l'ouverture, exactement comme le repli du panneau était venu en cours
de `P1a`. Il a aussi décidé du partage à l'intérieur du panneau : **les fiches sont
prioritaires, c'est la liste des actions qui défile.**

### Ce que valait le défaut, en chiffres

`P1a` l'avait renvoyé ici en le mesurant à dix-huit pixels au sixième jour. La mesure était
juste et optimiste : au **douzième** jour, où une cinquième ligne d'action s'ajoute, le
panneau descendait vingt-huit pixels sous la bande de la main.

C'est la cinquième ligne qui fait tout. À quatre lignes le panneau s'arrêtait seize pixels
**au-dessus** des cartes ; à cinq il passait vingt-huit **dessous**. `MAX_ROWS` valait trois
à `W2`, cinq depuis `I2`, sur l'argument parfaitement raisonnable que cinq est ce qu'une
main d'actions peut poser en une phase — `hand_size` le dit. Le plafond avait donc été
calibré, et il était faux d'exactement une ligne.

C'est l'argument du jalon, et il vaut mieux que « ça débordait » : **un plafond calibré sur
une hauteur qu'il ne mesure pas se trompe dès qu'autre chose bouge**, et autre chose bouge
toujours. Le remplaçant n'est pas un chiffre mieux choisi, c'est un budget en pixels que le
harnais calcule et passe au panneau.

### Le piège qui a coûté vingt-huit pixels

Le budget se lisait d'abord sur `_right_slot.size.y`, le `MarginContainer` qui porte la
colonne de droite. C'était faux, et faux d'une façon qui ne se voit pas : **un conteneur
prend le plus grand de son ancrage et de la taille minimale de son contenu.** Le slot
mesurait donc 676 là où le viewport en fait 648 — la différence étant, très exactement, le
débordement du panneau qu'on voulait borner.

Un plafond tiré de là se desserre au moment précis où il devrait serrer. Il **borne une
hauteur à partir d'elle-même**, et la boucle est silencieuse : tout compile, la ligne de
budget a l'air d'une soustraction honnête, et il reste vingt-huit pixels de recouvrement.

La réparation est une ligne : on **demande à la main où elle commence**. C'est le même
geste que `HandView.band_height()` à `P1a`, un cran plus loin — on demandait déjà ce que la
bande occupe, on demande maintenant où elle est.

### Une heure perdue à sonder des PNG, et la ligne qui l'évite désormais

Pour mesurer le recouvrement j'ai écrit un lecteur PNG et sondé des colonnes de pixels. Ça
a marché, ça a pris une heure, et **ça rend un chiffre dans le mauvais repère** : le projet
est en `stretch/mode = "canvas_items"`, donc l'image sort à la taille de la fenêtre pendant
que la mise en page raisonne dans un viewport logique de 1152×648. En 1920×1080 le facteur
vaut 1,667 — mes « vingt-huit pixels » sondés en valaient dix-sept, et ne se comparaient à
rien de ce que dit le code.

Le harnais Run imprime donc désormais, à chaque capture, **où finit la colonne, où commence
la main, et lequel mord sur l'autre**. Cinq lignes, les deux bords demandés aux vues en
`global_position`, donc dans le même repère. C'est la discipline que `F1` a écrite pour les
tables du harnais — une table annonce ce qu'elle doit montrer — appliquée à une image, et
c'est elle qui a fini par montrer que le budget était trop généreux.

Elle mesure contre la **bande** que la main réserve et non contre le haut visible d'une
carte, qui est plus bas. C'est volontaire et plus sévère : la bande comprend `HOVER_LIFT`,
la course qu'une carte survolée a au-dessus d'elle, donc un panneau qui s'arrête pile au
bord ne recouvrira pas non plus la carte qu'on désigne.

### La fiche d'ouvrier, de six lignes à quatre

Elle portait une ligne par famille avec son multiplicateur, plus le poste et l'XP : six
lignes à trois familles, sept quand `X2` ouvrira l'Artisanat. Six ouvriers en font deux
rangées de grille, et c'est cette hauteur-là qui poussait le panneau sur la main — la
compacter a rendu quatre-vingt-neuf pixels, soit trois fois le débordement.

Ce qui reste est ce qui **décide** : les pistes qui ont franchi un palier, sur une ligne.
Ce qui part est ce qui s'en déduit — un multiplicateur vient d'un palier, donc l'écrire à
côté répète le même fait en chiffres à virgule — et ce qui ne sert qu'à comparer de près :
les pistes entamées sans palier, et l'XP totale. Le tout est à un survol, dans l'infobulle,
qui est le précédent que `P1a` a posé pour le coût d'une carte.

Deux choses valent d'être notées. Les deux formes sont remplies par **une seule passe** :
séparées, c'est l'infobulle — qu'aucune capture ne montre — qui aurait dérivé en silence.
Et les noms de famille restent écrits en entier, alors qu'abréger tiendrait mieux sur la
ligne : « Con » pour Construction et « Com » pour Combat seraient la table
identifiant → français que `W1` interdit, à trois lettres près.

Un ouvrier sans aucun palier affiche « sans palier » plutôt que rien, pour la raison que
`_show_note()` porte depuis `W2` : une ligne qui n'apparaîtrait qu'au premier palier ferait
grandir la fiche au moment où la colonne a le moins de place.

### Les piles, et l'ordre qu'elles ne diront pas

`Deck` savait dire combien, jamais quoi. Il répond maintenant par un **recensement** —
carte vers nombre d'exemplaires — et c'est là qu'est la seule décision de design du jalon.

Une pioche est ordonnée : l'index 0 est le sommet. En rendre le contenu dans l'ordre
dirait au joueur non seulement ce qu'il reste mais *quand ça vient*, ce qui **répondrait
par accident à l'`OUVERT` de 3.5** sur la main non jouée — « que fait-on d'une main qu'on ne
peut pas jouer » cesse d'être un pari dès qu'on lit les trois prochaines cartes. C'est
l'inverse de ce que `P1b` cherche : `DESIGN.md` 8 veut cette vue pour rendre l'arbitrage de
`I2b` **jouable**, pas pour le trancher.

Le refus vit dans le domaine et pas dans la vue. Rendre l'ordre puis demander à l'adapter
de ne pas le montrer aurait laissé la règle dans un commentaire, à un appel de distance de
la fuite. Un recensement n'a pas d'ordre à trahir — même geste que le bloc `production`
nullable de `E1b` : la cohérence devient structurelle au lieu d'être vérifiée. Un cas de
test le prouve plutôt que de le supposer : **deux decks mélangés sur deux seeds différents
recensent à l'identique**, alors qu'un autre cas épingle qu'ils ne piochent pas pareil.

La vue le **dit** quand même, en une ligne sous les colonnes. L'absence d'une information
ne se voit pas : quatre noms rangés se lisent comme un ordre si rien ne dit le contraire,
et ce serait le même défaut de forme que le « 2 » au-dessus du « 0 » de `P1a` — lisible, et
faux.

`P` l'ouvre dans le harnais Run **et** dans le harnais Cartes. Le second n'est pas du luxe :
c'est la scène où le `Deck` vit seul, donc la seule où l'on peut vider une pioche à la main
et regarder le remélange. La capture le montre — pioche des bâtiments à zéro, défausse à
quatre —, état qu'aucune journée du harnais Run n'atteint.

Les trois lignes de compteurs quittent le pavé de texte du harnais Run **au lieu d'être
doublées**. Troisième fois après `E2` et `W2` : un chiffre affiché à deux endroits est un
chiffre qui finira par différer de lui-même.

### `--shot-piles`, par la porte habituelle

Quatrième drapeau né de la phrase que ce projet se répète depuis `I2` : un écran qu'aucune
capture ne peut atteindre est celui que personne ne regardera. La vue des piles est une
modale qui ne s'obtient que par une touche — aucune suite de journées ne la produit —, donc
sans drapeau la seule façon de la regarder aurait été de modifier du code pour la regarder.

### Ce qui ne bouge pas

**Aucun DTO de `contracts/` n'a été créé ni modifié**, le quatrième jalon d'affilée après
`E2`, `W2` et `P1a`. Le domaine gagne deux accesseurs sur `Deck` et rien d'autre ; aucune
règle de jeu n'a changé.

### Prochain jalon

**`I2b`**, sans réserve cette fois. `P1a` a rendu une phase agréable à mener, `P1b` a rendu
à l'écran ce que la colonne cachait et donné à lire ce qu'il reste dans les piles : les deux
choses qu'il fallait pour demander à quelqu'un de jouer quinze journées et d'arbitrer un
`.tres`.

De la famille `P` il ne reste que **`P1c`**, qui attend une question de design et non du
temps : comment désigner l'une des deux actions d'une même case — un cycle au clic, un
menu, une pile visible sur la case. Elle se pose avant le code, et elle se pose à toi.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **`P` ouvre les piles**, dans le harnais Run comme dans le harnais Cartes. Échap ou un clic
  n'importe où referme. C'est une modale : tant qu'elle est ouverte, aucune autre touche ne
  répond.
- **Les trois lignes « Piles » ont quitté le pavé de texte.** Ce qu'elles disaient est dans
  la vue, en mieux : quelles cartes, et pas seulement combien.
- **La pioche ne montre jamais son ordre**, et c'est une décision de design, pas une limite
  d'affichage. Le domaine ne le rend pas.
- **Le panneau d'affectation ne déborde plus**, à aucune résolution. La liste des actions
  défile quand la place manque ; les fiches passent d'abord et restent entières.
- **La fiche d'ouvrier fait quatre lignes.** Le détail — multiplicateurs, pistes sans palier,
  XP totale — est dans l'infobulle, au survol.
- **Chaque capture du harnais Run imprime une ligne de mise en page** : « bas du panneau
  y=…, haut de la main y=…, N px de dégagement ». Un recouvrement positif y est un défaut.
- **Un drapeau de plus** : `--shot-piles`, nu, ouvre la vue avant de capturer.
- **La branche n'est pas fusionnée** : `feat/p1b-lists`, quatre commits.

---

## 2026-08-27 — `P1a` : la souris suffit, la main affiche ses prix, la phase a une couleur

**État : terminé.** Six commits sur `feat/p1a-comfort`. Les trois commandes passent : boot
sans erreur ni warning, tout `src/domain/` parse, **779 tests verts contre 777**. Onze
captures, dont quatre qui ont renvoyé le travail à l'établi.

`P1` s'est découpé en trois à l'ouverture, et la découpe suit ce que chaque point
**touche** plutôt que sa taille : quatre ne sortent pas de `src/adapters/`, deux réclament
une vue ou une place neuve, le septième rouvre une règle du domaine et une ligne de
`DESIGN.md`. `P1a` prend les gestes ; `P1b` les listes ; `P1c` la désignation.

Le jalon a livré **quatre** points et non trois : le repli du panneau d'affectation s'y est
ajouté en cours de route, demandé par l'humain après lecture des captures.

**Le sens du terrassement n'est dans aucun des trois jalons.** Il était au périmètre de
`P1a`, l'humain l'en a retiré, puis l'a retiré de `P1b` aussi : il dira quand le remettre.
Le verbe, son ciblage et sa résolution restent écrits et exercés ; la promesse de 4.2 — la
carte revient au deck le jour où l'écran montre où va la terre — tient, elle n'a simplement
pas de date.

### Ce que le jalon livre

**Affecter à la souris de bout en bout.** On cliquait une fiche, puis on appuyait sur
Espace en visant à la souris : une intention, deux vocabulaires. Le clic gauche sur le sol
route désormais trois questions dans un ordre qui a chacun sa raison — fonder d'abord,
parce qu'aucun autre geste n'a de sens sur une carte nue ; l'ouvrier avant la carte, et
c'est gratuit puisqu'une case qui porte déjà une action en refuse une seconde depuis `I2`,
si bien que jouer y serait de toute façon refusé ; la carte en dernier, ce qui laisse
`_play_here()` intact. Le fichier n'a pas gagné une règle, il a gagné un aiguillage.

**Le coût sur la carte.** Un chiffre par ressource, de la couleur que la jauge de réserve
emploie déjà, et l'encre s'affaiblit quand `Ledger.can_afford()` dit non. Ce n'est pas une
entorse au « la vue ne juge aucune jouabilité » de `HandView` : la vue pose la question au
domaine et dessine la réponse, ce que `CLAUDE.md` écrit noir sur blanc. La faute serait
`if ledger.wood >= data.cost`, pas l'appel.

L'affaiblissement plutôt qu'une couleur d'alarme, et c'est la leçon de la passe jouée à la
main appliquée d'avance : l'orange veut dire *danger* sur les quatre autres panneaux. Une
main de sept cartes dont trois sont trop chères s'afficherait entièrement en alarme le
premier jour, où rien ne va mal. « Pas maintenant » et « attention » sont deux messages.

Une carte d'**action** ne porte pas de coût. Ce qu'elle dépense, ce sont des ouvriers, et
combien dépend de la cible — les postes d'un bâtiment, les crans d'un chantier, un chiffre
d'équilibrage sur une case nue. Ce prix-là n'existe qu'en visant ; lui inventer un nombre
fixe sur la carte serait mentir sur la seule chose qu'on voudrait comparer.

**La phase a une couleur.** Un liseré de trois pixels sur le bord haut du panneau
d'affectation. `PhaseDef` porte une `color` sur le patron exact de `TerrainData` — pas de
défaut, une sentinelle `UNSET_COLOR`, un contrôle dans `missing_fields()` — et **aucun nom
de phase n'est entré dans le code**, ce qui était la condition posée par `DESIGN.md` 8. La
vue lit une couleur en data, comme le renderer de terrain.

Le liseré est sur ce panneau-là et pas ailleurs parce que la phase décide de ce qu'on a le
droit de faire et que ce panneau est l'endroit où on le fait : son bouton **Auto** s'éteint
déjà quand la phase interdit d'affecter. Le liseré et le bouton disent la même chose, l'un
en couleur, l'autre en gris.

La phase arrive en **argument** et non par le `RunState`, alors que tout le reste de cette
vue en vient. « Quelle phase ? » n'a de réponse qu'avant la dernière journée, et
`RunManager.phase()` porte déjà ce garde-fou ; le redemander au cycle ici en aurait fait un
second exemplaire, donc un endroit de plus où la fin d'un run pourrait se lire autrement.

### Les trois défauts trouvés en regardant

Aucun n'était cherché par un test, et deux ne pouvaient pas l'être.

**Un coût de vingt s'affichait « 2 » au-dessus de « 0 ».** `AUTOWRAP_WORD_SMART` ne se
contente pas de replier sur les espaces : il coupe aussi ce qui n'en a pas dès qu'un
`HBoxContainer` serre. Le résultat était **lisible et faux**, ce qui est pire
qu'illisible — un prix de vingt lu comme deux chiffres empilés.

**Toutes les captures du projet depuis `D2` montraient une main d'avant leurs propres
poses.** `_play_scripted()` appelle `RunManager.play()` en direct, sans passer par le geste
que la souris déclenche, donc sans rien redessiner. L'image affichait sept cartes pendant
que la ligne « Piles » en annonçait deux, deux panneaux plus loin, sur la même image. Le
défaut a traversé `D2`, `W2` et `I2` sans se voir parce que rien sur une carte ne dépendait
d'un état mutable : la liste était fausse d'une façon qu'aucun œil ne rattrapait. Le coût
l'a rendue visible d'un coup — une Habitation à pleine encre sur une réserve qui ne la
payait plus.

C'est le piège que `F1` avait nommé, appliqué à une image au lieu d'une table : un harnais
peut être **faux sur ce qu'il prétend montrer**, ce qui est pire qu'une panne parce qu'on
lui fait confiance.

**Le panneau d'affectation déborde de sa colonne et couvre le haut des cartes.** Dix-huit
pixels de bande au sixième jour du run de test, c'est-à-dire exactement la ligne du rang au
clavier — déjà illisible là **avant** ce jalon. C'est la troisième fois qu'une colonne de
droite ne tient pas, après `W2` et `I2`, et la première où elle **cache** une information
au lieu d'en tronquer une.

Ce défaut n'est pas réparé, et c'est délibéré : sa réponse est le point « la liste des
actions posées, pour de bon » que `DESIGN.md` 8 garde, donc `P1b`. Il a en revanche décidé
d'un choix de ce jalon-ci, et c'est ce qui mérite d'être écrit.

### Le coût a changé de ligne deux fois, et la deuxième était la bonne

Il a d'abord été posé sur une **troisième ligne**, ce qui portait la carte de 74 à 86
pixels. La bande a grandi d'autant, son bord haut est monté de douze pixels, et le
chevauchement du panneau est passé de trois à trente.

Le réflexe a été de tout ramener à 74 en rangeant le coût sur la ligne du rang, qui
semblait à moitié vide. **La capture a refusé.** Cette ligne-là est précisément celle que
le panneau recouvre : le prix devenait invisible aux journées chargées, et un prix qu'on ne
voit que certains jours est pire qu'un prix absent.

Le coût est donc revenu sous le libellé, dans le tiers **bas** de la carte, celui que rien
ne couvre. La carte plus haute élargit ce que le panneau cache — mais ce qu'il cache reste
le rang, qui est un rappel de touche et non une information de décision.

La leçon est notée dans `CLAUDE.md` : **agrandir une vue qui en touche une autre déplace un
défaut, il n'en crée pas.** Mesurer ce qui recouvre quoi, en pixels, sur une capture, avant
de rogner la marge qu'on vient d'ajouter.

### `--shot-phases`, et la phrase que ce projet se répète

`--shot-evenings` résout des **journées entières**, donc toute capture s'arrêtait sur le
premier créneau : les autres phases n'étaient joignables par aucun drapeau. Sans
conséquence tant qu'une phase ressemblait à sa voisine, et un trou dès qu'une phase a eu
une couleur à montrer — le liseré n'aurait jamais pu se regarder qu'en une seule teinte.

C'est mot pour mot la raison qui a valu son drapeau à `--shot-view` : **un écran qu'aucune
capture ne peut atteindre est celui que personne ne regardera.** Les deux teintes sont
maintenant vérifiées à l'image et au pixel — `115,168,224` le matin, `237,168,79`
l'après-midi, exactement ce que `run_balance.tres` porte.

### Le repli du panneau, demandé en cours de jalon

Il n'était pas dans la liste de `DESIGN.md` 8 : il vient de l'humain, après lecture des
captures. Le panneau d'affectation se replie sur sa barre de tête, d'un clic sur son
chevron ou par `F2`.

C'est le **troisième cran de dégagement** du HUD, et il complète les deux autres au lieu de
les doubler. `H` ne touche qu'au pavé de texte à gauche ; `F1` emporte tout, main comprise,
donc empêche de jouer. Celui-ci rend la moitié droite de la carte **sans rien perdre de
jouable**.

Ce qui reste visible est le vrai sujet. La barre garde le compte — « 6 au travail · 0
libre(s) · 6/14 place(s) » —, le bouton **Auto**, et le liseré de phase. Autrement dit : de
quoi savoir s'il faut rouvrir, et de quoi ne pas avoir à le faire. Un repli qui n'aurait
laissé qu'un titre aurait forcé un aller-retour à chaque phase.

Le geste est **asymétrique** dans le code, et c'est délibéré : replier masque les quatre
blocs, rouvrir n'en remontre qu'un. Les trois autres — les lignes, le « aucune action
posée » et le « et N autre(s) » — s'excluent entre eux selon ce que le plateau porte, et
c'est `_fill_rows()` qui tranche, à l'image suivante. Les rallumer à la main en aurait
montré deux à la fois le temps d'une image, et recopié sa règle à un second endroit.

Le panneau garde son propre état plié, et ça vaut d'être noté parce que la même vue fait
les deux choses : elle **signale** qu'on a cliqué une fiche — qui l'on tient est un état de
jeu, le harnais le garde — et elle **décide** seule d'être repliée, parce que sa propre
taille ne regarde personne d'autre.

### Une ancre déplacée, et ce qu'elle apprend

Le repli a déplacé un défaut d'un cran, comme la carte plus haute l'avait fait avant lui.
La colonne de droite était ancrée **en bas**, ce qui gardait le panneau contre la main ;
sa hauteur devenant variable, le compte rendu de phase empilé au-dessus **chutait de trois
cent cinquante pixels** à chaque repli. Or `W2` ne lui demande qu'une chose : rester au
même endroit d'une résolution à l'autre.

Ancrée **en haut**, la colonne fait l'inverse : le rapport ne bouge jamais, et c'est le
panneau — qui vient de changer de taille exprès — qui se déplace. La règle est notée dans
`CLAUDE.md` : dans une pile, **l'ancre va du côté de la vue la plus stable**, et le
mouvement se paie par la plus variable.

### Sur le débordement, une mesure et pas une impression

Le panneau ouvert **déborde toujours** sur le haut des cartes, et je le mesure encore en
1920×1080 : la carte de bâtiment y perd sa ligne de rang. Le repli est une échappatoire —
un clic rend les cartes entières — et non une réparation. C'est `P1b` qui devra loger ce
panneau, et le point « la liste des actions posées, pour de bon » est exactement l'endroit
où ça se traitera.

`--shot-fold` est né avec le repli, par la porte qui a déjà donné `--shot-view` et
`--shot-phases` : le repli est un état qu'**aucune suite de journées ne produit**, puisqu'il
ne s'obtient que par un geste. Sans drapeau, la seule façon de regarder un HUD replié
aurait été de modifier du code pour le regarder.

### Un doublon retiré au passage

La marge basse du HUD était un `88.0` écrit à la main dans le harnais, censé valoir la
hauteur de la main. Il ne la valait déjà pas — trois pixels d'écart, assez pour faire mordre
le panneau sur le haut des cartes. `HandView.band_height()` la calcule à un seul endroit.
Même doublon que celui qu'`E2` a retiré de la réserve, et il avait déjà dérivé.

### Ce qui ne bouge pas

**Aucun DTO de `contracts/` n'a été créé ni modifié**, comme à `E2` et `W2` : une vue n'est
pas un second système du domaine. Aucune règle de domaine n'a changé non plus — les trois
points sont des questions auxquelles le domaine répondait déjà et que l'écran n'affichait
pas, ou affichait mal.

`PhaseDef` a gagné un champ, ce qui a forcé cinq fixtures de test à le renseigner :
`RunState.open()` asserte que l'équilibrage est complet, donc resserrer le schéma les casse
par construction. Elles sont dans le **même commit** que le schéma — les séparer aurait
laissé un commit rouge derrière.

### Prochain jalon

**`P1b`** ou **`I2b`**. Les trois gestes qui rendaient une phase pénible à mener sont faits,
donc `I2b` peut se jouer sans attendre. Mais `P1b` porte maintenant un défaut qui **cache**
une information, et ça pèse plus lourd qu'un confort qui manque. `P1b` doit régler le
débordement de la colonne **avant** ses deux points, qui s'y heurteraient tous les deux.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **Le clic gauche sur le sol a un sens de plus** : fiche en main + action sous le curseur =
  l'ouvrier y va. Espace reste, en raccourci.
- **Les cartes de bâtiment affichent leur coût**, en couleur de ressource, et pâlissent
  quand la réserve ne suit pas. L'infobulle porte le texte entier.
- **`data/balance/run_balance.tres` a deux lignes de plus** : une `color` par phase — bleu
  le matin, ambre l'après-midi. C'est de la data, donc réglable sans toucher au GDScript ;
  une phase sans couleur fait **refuser le boot**.
- **`F11` bascule en plein écran**, dans tous les harnais. La touche vit sur `dev_boot.gd`
  et non dans un harnais : c'est une propriété de la fenêtre, pas de ce qu'on y montre.
  Elle n'existait nulle part, d'où l'impossibilité de passer en plein écran.
- **Les bandes sombres sur les côtés ne sont pas du letterboxing.** `project.godot` est déjà
  en `stretch/aspect = "expand"`, qui n'en ajoute jamais, et la mesure le confirme — le
  terrain couvre 35 % de la largeur en 1440×810 et 36 % en 1920×1080, donc l'image ne fait
  que grandir. C'est le cadrage : `CameraRig.frame()` cale la diagonale de la carte sur la
  **hauteur**, et la `size` d'une caméra orthogonale Godot est verticale. Sur un écran large
  il reste du monde vide à gauche et à droite, à toute résolution. La molette zoome,
  `R` recadre, et `frame_margin` dans `data/balance/camera_balance.tres` serre le cadrage
  si on le veut plus près.
- **`F2` replie le panneau d'affectation**, et le chevron de sa barre de tête fait la même
  chose à la souris. Replié, il garde le compte, **Auto** et son liseré de phase.
- **Le compte rendu de phase ne bouge plus** : la colonne de droite s'accroche désormais en
  haut. C'est le panneau qui se déplace quand il se replie, plus le rapport.
- **Deux nouveaux drapeaux de capture** : `--shot-phases n` franchit n phases après les
  journées — `--shot-evenings 3 --shot-phases 1` donne l'après-midi du quatrième jour — et
  `--shot-fold`, drapeau nu, replie le panneau avant de capturer.
- **Le panneau ouvert déborde toujours sur le haut des cartes**, y compris en 1920×1080.
  C'est un défaut antérieur à ce jalon et il est renvoyé à `P1b` ; `F2` le contourne.
- **La branche n'est pas fusionnée** : `feat/p1a-comfort`, six commits.

---

## 2026-08-27 — la première partie jouée à la main, et ce qu'elle a rapporté

**État : terminé.** Cinq commits sur `feat/i2-qol`, à la suite des trois QOL de la veille.
Les trois commandes passent : boot sans erreur ni warning, tout `src/domain/` parse,
**777 tests verts contre 771**. Quatre captures.

C'est la première fois du projet qu'un jalon vient **entièrement** d'une passe humaine.
`E2`, `W2` et `I2` avaient chacun trouvé leurs défauts en capture, ce qui est déjà autre
chose qu'un test ; là, rien de ce qui suit n'aurait été trouvé sans quinze journées jouées
au clavier.

### Les deux bugs, et pourquoi le second était invisible

**Deux actions sur une même case.** Le symptôme signalé — « ça bugue, on ne peut pas
attribuer deux fois » — était plus large que ça : `_action_here()` ne rend que la
**dernière** action posée sur une cellule, donc la touche qui affecte, le clic droit qui
retire et la ligne de survol ne peuvent en atteindre qu'une. L'autre n'existait plus que
dans une liste de panneau bornée à trois lignes.

La correction demandée — interdire deux actions par case — **renverse une ligne écrite de
`DESIGN.md` 3.5**, et c'est le cas même pour lequel `D2` avait donné une identité aux
actions : *Récolter* et *Chasser* sur une même forêt, « deux métiers sur une même terre ».
Elle est renversée quand même, et le journal doit dire l'argument exact : le domaine
autorisait un geste que **rien à l'écran ne pouvait viser**. Une règle que le joueur ne
peut ni voir ni employer n'est pas une règle, c'est une intention.

Le retour en arrière est écrit comme provisoire dans les trois endroits qui comptent — le
code, le cas de test, et 3.5 —, avec la condition qui le lèvera : un écran qui sait
désigner l'une des deux.

**L'auto-affectation classait par ordre du roster.** Le diagnostic tient en une phrase :
un multiplicateur vient d'un **palier**, donc six ouvriers frais valent tous 1.00, et
`ranked_for()` n'avait plus rien à comparer. Le départage par l'ordre du roster, écrit à
`W2` comme dernier recours, était devenu le **seul** recours — pendant précisément les
journées où le bouton sert le plus.

Ce défaut ne pouvait pas se voir autrement. Les tests de `W2` comparaient des ouvriers aux
multiplicateurs distincts, ce qui est le cas intéressant et le cas rare ; le cas fréquent,
celui de six bleus, ne prouvait rien et n'était donc pas écrit. C'est un trou de couverture
que seule une partie révèle.

### Le contrat qui bouge, et le seul depuis `F1`

`LaborUnit` porte l'XP de piste. Son docstring disait « ni les traits, ni l'XP, ni les
blessures », et le refus était juste tant que rien ne posait la question — c'est la règle
qui a fait attendre `CombatForce` jusqu'à `F1`. Le bouton d'auto-affectation la pose.

Ce qui entre est l'**XP** et non le niveau, et la distinction porte tout : un niveau est un
palier de plus, donc la même égalité un cran plus haut. Ce qui manquait est *où l'on en est
à l'intérieur d'un palier*, et il n'y a que l'XP pour le dire. Elle ne donne aucun
rendement et n'en donnera jamais : elle **ordonne**, elle ne calcule pas.

Le choix a un effet de design qu'il faut assumer : préférer celui qui est le plus près du
palier suivant **concentre** l'XP au lieu de l'étaler, donc le bouton fabrique des
spécialistes. C'est ce que 3.4 réclame — « spécialiser rend excellent à un poste et
médiocre ailleurs » — mais c'est une décision et non une correction.

### Ce qu'un écran disait de travers

**L'orange voulait dire deux choses.** Sur le panneau d'affectation, une action à qui il
manque du monde s'affichait en orange — la couleur qui veut dire *danger* sur les trois
autres panneaux : famine, écrêtage au plafond, pertes d'une vague. Une phase qui commence
s'affichait donc entièrement en alarme. Le vert reste, parce que « cette ligne est finie »
mérite un coup d'œil ; la fraction `1/2` portait déjà le compte, donc la couleur n'a jamais
eu à le répéter.

**Le sens d'un terrassement n'est visible nulle part.** La touche le retourne bien, mais
seulement carte en main, et ni la ligne de survol ni les cibles allumées ne disent lequel
des deux on fait. Une carte qu'on oriente à l'aveugle est pire qu'une carte qu'on subit,
ce qui est exactement l'inverse de ce que `I1` cherchait en faisant du sens un choix de
pose. La carte sort du deck de départ ; le verbe reste écrit et revient avec `P1`.

### La bande de survol, posée trois fois

Elle devait aller « en haut au milieu ». Elle y a été mise, et **deux captures l'ont
refusée** : cette rangée est prise en étau entre la barre de réserve à gauche et le compte
rendu de phase à droite, et une bande centrée grandit des deux côtés — « Survol : » se
dessinait par-dessus « Minerai 0 ». La couper en deux lignes plus courtes n'a pas suffi.

Ce n'est pas une marge à régler : c'est la leçon de `W2` appliquée à une **rangée** plutôt
qu'à une colonne. Deux vues qui grandissent l'une vers l'autre doivent vivre dans le même
conteneur. Elle est donc dans la colonne de gauche, sous la barre, où elle pousse au lieu
de recouvrir — et elle y gagne un voisinage juste, le coût d'une carte tenue se lisant à un
centimètre de la réserve qui doit le payer.

Elle reste visible quand `H` replie le rapport, ce qui était tout l'objet de la demande :
c'est la seule ligne qu'on lit **en visant**.

### La règle de travail que j'ai dû me faire rappeler

J'ai lancé la suite complète — deux minutes quarante-cinq — cinq ou six fois pour des
changements qui touchaient deux fichiers. `-a` se répète et une suite isolée revient en
treize secondes.

La règle est notée : **suites concernées pendant l'itération, suite complète une fois par
couche, avant le commit.** Le coût n'était pas le mien.

### Le jalon `P1`, et pourquoi c'en est un

La liste de confort ne va pas dans un coin de `JOURNAL.md` : elle devient une famille de
jalons, `P`, avec une raison qui tient. Les jalons d'écran ont chacun livré la vue **dont
leur système avait besoin** ; aucun n'avait pour charge ce qui rend une partie agréable à
mener bout en bout. C'est une question qu'on ne peut poser qu'après avoir joué, donc après
`I2` — et **avant** `I2b`, qui va demander à quelqu'un de jouer quinze journées d'affilée
pour arbitrer un `.tres`.

`P1` porte sept points, dont deux sont déjà faits parce qu'ils coûtaient une heure : le
clic droit sur une fiche pour rappeler un seul ouvrier, et la ligne de survol qui survit au
repli du rapport. Les cinq autres sont écrits en 8.

### Quatre `OUVERT` de plus, tous sur les cartes

Ils viennent de la même passe et se tiennent, ce qui est la raison de les écrire ensemble
plutôt que de les trancher séparément :

- **Une carte de bâtiment est-elle à usage unique ?** Les actions tournent ; un bâtiment
  posé ne se rebâtit pas au même endroit. S'il est détruit à l'usage, le pool devient fini
  et précieux — et il faut aussitôt un moyen d'en gagner : un choix parmi trois après une
  vague, ou dans un événement de 3.7. Les deux se tranchent ensemble ou pas du tout.
- **Conserver une carte, redessiner sa main, ce qu'un gouverneur de départ offre.** Trois
  variantes d'une même question, et c'est l'`OUVERT` que 3.5 garde depuis `D1` : que fait-on
  d'une main qu'on ne peut pas jouer.
- **Un bâtiment large peut-il recevoir plusieurs fois la même action ?** Une empreinte de
  quatre cellules est aujourd'hui **une** cible, donc elle accepte autant de travail qu'une
  cabane 1×1. La taille devrait-elle acheter du débit, ou seulement des points de vie et de
  la place ? La réponse décide de ce que valent les grands bâtiments dans le tableau de 4.1.

### Prochain jalon

**`I2b`** ou **`P1`**, dans l'ordre qu'on veut. `P1` est le seul jalon du projet dont le
contenu vient d'une partie jouée plutôt que d'une déduction, donc le seul qui se périme si
on attend — et il rend `I2b` nettement moins pénible à mener.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **Les commandes ont deux ajouts** : **clic droit sur une fiche** rappelle cet ouvrier-là
  sans défaire l'action, et **H** replie le rapport en gardant la ligne de survol, qui a
  quitté le pavé pour se poser sous la barre de réserve.
- **`data/balance/deck_balance.tres` a perdu une ligne** : *Terraformer* n'est plus dans le
  deck de départ. La carte, le verbe et sa résolution sont intacts — c'est une ligne de data
  à remettre quand `P1` aura montré le sens.
- **Le panneau d'affectation montre cinq lignes d'action** au lieu de trois, et une action
  incomplète n'est plus orange.
- **Les deux branches ne sont pas fusionnées** : `feat/i2-full-loop` (5 commits) puis
  `feat/i2-qol` (9), la seconde tirée de la première.

---

## 2026-08-26 — `I2` : le run se fonde, se bat et se termine

**État : terminé.** Cinq commits sur `feat/i2-full-loop`, tirée de `master`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **768 tests
verts contre 715** à l'ouverture, 44 suites contre 42. Les huit harnais ont été bootés un
par un. Quatre captures — la fondation, une vague en approche, la même après coup, et la
fin d'un run entier.

Le jeu se joue du premier geste au dernier. C'est ce que le titre du jalon promettait
depuis `I0`.

### Ce qui a été livré

- **Schéma et data** — `WaveSlot`, le calendrier et les quatre poids du score dans
  `RunBalance`, `run_balance.tres` réécrit.
- **Domaine** — `RunOutcome`, `DayCycle.end()`, `RunOrchestrator.found()`,
  `close_the_day()` qui arme, `end_phase()` coupée en deux, `fight()` qui consomme une
  vague en attente, `Roster.total_level()`, `DayReport.wave()`, trois refus nommés de plus
  sur `PlayResult`.
- **Adapters** — `BattlePanel` sous `src/adapters/hud/`, `RunManager.found()` et
  `fight()`, `EventBus` qui gagne `battle_pending` et `battle_resolved` et dont
  `run_finished` porte l'issue.
- **Cinquante-trois cas de plus**, dont une suite neuve sur `RunOutcome`.
- `DESIGN.md` 2, 3.6, 3.8, 5 et 8 ; `CLAUDE.md` ; `README.md`.

### Ce que le jalon n'a pas eu à faire, et c'est le plus important

**Aucun DTO de `contracts/` n'a bougé.** `DESIGN.md` 8 le promettait — « aucun contrat ne
bougera plus, ce qui était la raison de passer `F1` avant » — et c'était une promesse
vérifiable, pas une intention. Tout ce que `I2` crée vit dans `domain/run/` ou dans
`src/schema/`, par le critère habituel : aucun second système du domaine ne le franchit.

Un jalon d'intégration qui aurait fait bouger un contrat aurait été un jalon qui découvre
trop tard ce qu'il branche. L'ordre `F1` puis `I2` a coûté un jalon de plus et il valait
exactement son prix.

### La coupure écrite à l'avance, et ce qu'elle a coûté

`DESIGN.md` 3.8 a été écrit après `F1`, avant qu'on en ait besoin : « le cycle devra
refuser d'avancer tant qu'une bataille est en attente », et le rapport de journée
« n'accueillera pas un rapport de bataille mais **la vague en attente** ». Le prix annoncé
était d'une demi-heure contre un écran à moitié câblé à défaire ensuite.

L'estimation était juste, et la forme aussi. Ce qui est différé n'est pas la résolution —
elle a bien lieu, le plateau se vide, la main part à la défausse — mais l'**ouverture de
la phase suivante**, que `fight()` fait à sa place. Les deux portes passent par la même
fonction privée, ce qui garantit qu'une journée fermée par un combat s'ouvre sur la
suivante dans le même état qu'une journée paisible.

**Et le run n'a coûté qu'un champ.** L'idée était de porter la vague *et* de se souvenir
que la phase interrompue résolvait, pour savoir s'il faudrait repiocher. C'est inutile :
quand une bataille attend, **le cycle pointe encore sur la phase qui vient de finir**,
donc `resolves()` dit encore ce que cette phase faisait. Un état qu'on peut relire n'a pas
besoin d'être retenu.

### Le calendrier : une liste, et pas une période

La question était réelle et j'ai demandé avant d'écrire. Une période — « une vague tous
les N jours » — rendrait l'`OUVERT` de 2 plus facile à tourner, puisqu'un seul entier
bouge.

C'est la liste, pour deux raisons dont la seconde tranche. Une liste **dit** une période
en l'écrivant, alors qu'une période ne sait exprimer ni un creux ni deux vagues
rapprochées. Et surtout la **vague finale** de 2 tombe sur le dernier jour parce qu'on l'y
a mise ; avec une période elle n'y tomberait que par coïncidence arithmétique, et changer
`days` la déplacerait sans qu'on le veuille.

Elle vit dans `RunBalance` et non dans `CombatBalance`, qui s'en défausse en toutes
lettres depuis `F1`. L'argument qui décide n'est pas thématique : le seul contrôle qui
compte croise le calendrier avec `days`, et seul le bloc qui tient la durée du run peut
dire qu'une vague datée au jour vingt ne tombera jamais.

### Ce que la fin de run a demandé de plus que sa ligne de design

`DESIGN.md` 5 tient en trois puces depuis le premier jour. L'écrire en a demandé trois
précisions qu'aucune des trois ne portait :

- **Une défaite ne s'attend pas.** Elle tombe au jour sept, donc « le run est fini » doit
  pouvoir devenir vrai au milieu. Une seule vérité pour ça — le cycle des jours —, et la
  cause à côté ; deux drapeaux qui peuvent se contredire auraient été pires que le cas
  qu'ils couvrent. Le bénéfice se lit en une ligne : tous les gardes déjà écrits se
  ferment sur une défaite sans qu'un seul ait bougé.
- **Le Cœur se reconnaît à son ancre**, retenue à la fondation, et non à son identifiant.
  C'est ce qui garde `heart` dans `data/balance/` et hors de tout `.gd`.
- **« Victoire » se lit « dernière journée franchie »** plutôt que « dernière vague
  survécue ». Les deux disent la même chose tant que le calendrier pose sa dernière vague
  sur le dernier jour, et la première n'a pas à inventer une règle pour un calendrier qui
  s'arrêterait avant.

**Il n'y a pas de `RunScorer`**, et c'est la seule chose du plan que j'ai retirée en
écrivant. Un score est une somme pondérée de quatre nombres ; ce qui méritait un fichier
n'était pas la somme mais le fait d'aller chercher les quatre au bon endroit — or c'est
exactement le métier de l'orchestrateur, qui « n'ajoute que ce qu'aucun résolveur ne peut
faire seul ». Un fichier de plus n'aurait fait que retransporter quatre entiers.
`Roster.total_level()` répond pour le roster comme `Ledger.total()` répond pour la
réserve : aucun contenu d'état ne traverse, ce qui est la ligne que `F1` a tracée sur le
pillage.

### Trois défauts, tous trouvés en capture

`E2` et `W2` ont appris qu'un écran trouve ce qu'aucun test ne cherche, et `F1` que le
pire est un affichage **faux sur ce qu'il prétend montrer**. `I2` en donne le meilleur
exemple du projet.

**Le panneau de bataille annonçait « Pertes : bo, cy »** — les identifiants internes. La
traduction interroge le roster, et au moment où le signal arrive **les morts n'y sont
plus** : `fight()` les retire avant de rendre son rapport, ce qui est précisément l'ordre
qui fait qu'un mort ne gagne pas d'XP. Rien ne plantait, tout compilait, les 768 tests
passaient, et la seule ligne du jeu qui raconte quelque chose disait des matricules. Le
relevé se prend maintenant avant que la vague tombe.

**Trois panneaux ne tiennent pas dans une colonne qui en portait deux.** `W2` avait appris
que deux vues qui grandissent l'une vers l'autre doivent vivre dans le même conteneur ; le
cran suivant est que ce conteneur a lui aussi une hauteur. Le jour de la dernière vague,
la dernière fiche d'ouvrier sortait de l'écran par le bas — et rétrécir une marge
aggraverait la chose. Le panneau de bataille est parti dans la colonne de gauche, où la
place est, et la lecture y gagne : la vague est voisine de la réserve qu'elle va piller.

**Le bandeau de fin passait sous les panneaux de droite**, si bien que la seule chose
qu'il devait annoncer se lisait « Victoire — la dernière journée est passée au jour 15.
Score 431 — 71 en ré ». Le raccourcir une fois n'a pas suffi : la moitié gauche de l'écran
fait sept cents pixels et un bandeau ne se replie pas. Ce qui tient est **un mot** ; la
cause et les quatre termes du score sont des lignes du rapport, où le texte va à la ligne.

**Et un quatrième qui n'en était pas un, mais qui aurait été le pire.** L'écran de
fondation n'était atteignable par aucune capture, puisque toute journée jouée commence par
poser le Cœur — donc le seul écran neuf du jalon aurait été le seul que personne n'aurait
regardé. `--shot-evenings 0` le capture désormais. Le contrôle a d'ailleurs servi tout de
suite : la première ligne du jeu conseillait encore « prendre une carte », geste que le
domaine refuse tant que le Cœur n'est pas posé.

### Ce qu'un run entier dit de l'équilibrage

Une partie complète, seed 20260825, quinze journées, trois vagues, victoire à 431 points :
71 en réserve, 23 bâtiments debout, 4 ouvriers sur 6, 10 niveaux cumulés.

- **La famine s'installe et ne repart pas.** Elle tombe à la cinquième journée et tient
  jusqu'au bout — « 6 dû, 2 mangé, 4 à jeun » au quinzième jour. C'est le déséquilibre le
  plus visible du run, et il est cohérent avec ce que `I1` avait noté sans pouvoir le
  mesurer : deux récoltes par jour pour un seul upkeep, mais une main qui pioche
  rarement une ferme. Elle ne punit encore rien — `X6` —, ce qui est la seule raison pour
  laquelle le run se gagne quand même.
- **Le village grossit beaucoup.** Vingt-cinq bâtiments à la fin, dont vingt-trois
  achevés. Le bois ne manque jamais ; la nourriture, toujours.
- **Le siège final mord.** Quarante contre vingt-sept de défense, treize de brèche, trois
  bâtiments détruits, deux morts et treize unités pillées. C'est la seule vague dont on se
  souvienne, ce qui est le bon dosage pour une dernière — mais les deux premières sont
  peut-être trop douces.
- **Le score est dominé par les ouvriers**, ce qui sert le pitch : quatre survivants
  valent quatre-vingts points là où soixante-et-onze unités de réserve en valent
  soixante-et-onze. Un chiffre de départ, pas une cible.

### Ce qui reste

Rien pour `I2`. Ce qui est resté dehors était annoncé dehors :

- **Le vrai combat** — `F2` et `F3`. La vague se résout encore instantanément ; ce que ce
  jalon livre est le **moment** où elle tombe et l'attente autour.
- **L'événement quotidien** *(3.7)* — la dernière case vide de la séquence de 2.
- **Les états d'ouvrier** — `X6`. La famine se constate toujours sans punir.
- **Le poste occupé de la tour de guet**, la colonne **Débloque**, les bonus d'adjacence
  de `C3` : inchangés, et chacun attend son jalon.

La mise en commun des `_make_label()` est passée de neuf à **dix** exemplaires. Elle
n'appartient toujours à aucun jalon.

### Prochain jalon

**`I2b`** — le playtest. La boucle est jouable de bout en bout, donc la question n'est plus
« qu'est-ce qui manque » mais « est-ce que ça se joue ». Les deux arbitrages — la structure
de la journée en 2, le sort de la main non jouée en 3.5 — se testent en échangeant un
`.tres`, et c'est le premier jalon du projet qui ne demande pas d'écrire une ligne de
GDScript.

`I3` suit avec les chiffres, et il en a désormais une liste précise plutôt qu'une
intention : la nourriture d'abord, puis le calendrier des vagues, le barème du score, et le
`breach_per_casualty` que `F1` avait déjà signalé comme le plus fragile de ses cinq.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'`InputMap`
ajoutée.

- `F5` lance le **harnais Run** : `HARNESS` vaut de nouveau `&"run"`.
- **Les commandes ont un ajout** : **Entrée** fait avancer le run quoi qu'il attende — elle
  fonde le village, elle mène la bataille, ou elle finit la phase. Le reste est inchangé.
  Le Cœur se pose au **clic gauche** sur la carte ; Entrée le met sur la case suggérée.
- **`data/balance/run_balance.tres` a changé de forme** : il porte trois sous-ressources
  `WaveSlot` de plus, qui **référencent** les `.tres` de `data/waves/`, et quatre poids de
  score. C'est le premier `.tres` du projet dont une sous-ressource pointe sur un fichier
  externe — l'éditeur devrait le réenregistrer sans broncher, mais c'est le diff à
  surveiller.
- **Les chiffres à relire** : trois vagues aux jours 5, 10 et 15 — escarmouche, razzia,
  siège — et un score à 1 par unité de réserve, 10 par bâtiment achevé, 20 par ouvrier
  vivant, 5 par niveau.
- **Les captures** : `--shot-evenings 0` montre la fondation, `10` une vague en approche,
  `16` la fin d'un run entier.
- **L'équilibrage de la nourriture est le premier chantier ouvert**, et il l'est maintenant
  avec une mesure plutôt qu'un soupçon : famine du jour 5 au jour 15.
- Les caches de classes et d'uid ont été reconstruits pendant la session, et les `.gd.uid`
  des trois scripts neufs sont commités.
- **La branche n'est pas fusionnée** : `feat/i2-full-loop`, cinq commits.

---

## 2026-08-26 — le format de combat, tranché en discussion juste après `F1`

**État : décidé, rien d'écrit.** Un commit sur `feat/f1-combat-stub`. Aucune ligne de `F2`
n'existe ; ce qui change est `DESIGN.md`, plus **une correction de data** que la
conversation a fait tomber. Les trois commandes passent, 715 tests toujours verts.

C'est le plus gros `OUVERT` du document qui se referme — 3.6 gardait sept questions
depuis `I0`. Il en reste trois, et ce sont des chiffres.

### Le format

**Tactique au tour par tour, sur la grille du village.** Un tour joueur où l'on déplace
les déployés et où chacun agit ; un tour ennemi. Référence assumée : *The Last Spell*,
avec beaucoup moins d'unités.

Les trois pistes que 3.6 listait avaient le même contrat — c'était l'intérêt de les
laisser ouvertes —, et c'est la troisième. Elle est aussi la plus testable des trois :
tout y est discret, un plateau et des entiers, donc du domaine pur.

### Ce que le projet avait déjà pour ça

Beaucoup, et c'est ce qui a rendu la décision facile. `HeightGrid`, `CellPicker` en DDA,
`CellHighlight`, `TargetHighlight`, la caméra orthographique qui pivote par quarts de
tour, `BuildingRenderer` : un combat sur la grille du village n'en réécrit **rien**.

Et la **borne de déploiement**, ajoutée à `F1` il y a une heure, devient littéralement la
phase de déploiement d'un jeu tactique. Elle était une rareté stratégique ; elle est aussi,
maintenant, le régulateur du rythme tactique — trois places, trois pions à jouer. Une
propriété qu'on n'avait pas cherchée et qu'il faut connaître : **desserrer la borne ne
rend pas le combat plus riche, ça le rend plus long.**

### La collision entre deux bonnes réponses

Prises séparément, « garder la carte entière » et « tenir N tours » sont justes. Ensemble,
elles donnaient la stratégie dominante la plus bête possible : **courir en rond dans les
vingt-huit colonnes vides** jusqu'au compteur. Zéro perte, zéro décision.

La réponse n'a pas été de recadrer la carte, mais de fixer **ce que les ennemis veulent** :
les ouvriers à portée, les bâtiments sinon. Fuir devient un troc — on garde ses gens, ils
mangent les murs — et le rapport de sortie sait déjà dire exactement ça, depuis `F1`.

Ce qui a en retour transformé la condition de victoire : **une vague est une razzia, pas un
duel.** Tenir N tours suffit à ce qu'elle reparte, nettoyer donne un bonus. Il n'y a plus
de défaite au combat, seulement une facture. La défaite d'un run reste celle de 5.

Second effet de garder le 32×32 : **la vague entre à la lisière du bâti**, pas au bord de
la carte. Le Cœur est au centre, donc seize cases de marche — quatre tours où personne ne
décide rien.

### La phrase de `DESIGN.md` qui est tombée

3.6 promettait depuis toujours : « Le jour où il est prêt, on échange l'implémentation dans
l'orchestrateur : **une ligne**. » C'est faux pour un format au tour par tour, et ça
n'aurait aucune importance si on l'avait découvert ailleurs qu'à `I2`, l'écran à moitié
câblé.

Un résolveur rend un rapport ; un combat tactique **attend le joueur**, et le domaine n'a
pas le droit d'`await`. Le producteur cesse donc d'être une fonction pour devenir un
**état** — un plateau mutable dans `domain/combat/`, des fonctions pures qui appliquent un
geste à la fois, un `DamageReport` au bout.

Ce qui est vrai en revanche, et `F1` l'a livré sans le chercher : `fight()` sépare déjà
**produire** — une ligne — et **appliquer** aux trois systèmes — tout le reste.
L'applicateur ne bouge pas d'un pouce. La promesse était bonne, elle portait juste sur la
mauvaise moitié.

### La conséquence qui touche du code déjà écrit

Le combat clôt la journée, après l'upkeep, à la place que la séquence de 2 lui garde. Mais
`end_phase()` est aujourd'hui **indivisible** — résoudre, vider, avancer — et la rupture
interactive tombe au milieu.

Le cycle devra refuser d'avancer tant qu'une bataille est en attente. C'est une demi-heure
aujourd'hui contre un écran à défaire plus tard, et c'est entré dans 3.8 **avant** d'en
avoir besoin, ce qui est la première fois que ce document écrit une contrainte
d'implémentation en avance. Corollaire : `DayReport` n'accueillera pas un rapport de
bataille mais **la vague en attente**.

### Deux `OUVERT` qui se referment par ricochet

**Le relief joue enfin autrement** *(3.1)*. Monter coûte, une marche trop haute bloque.
L'« avantage défensif en hauteur » qu'on imaginait est remplacé par mieux : une contrainte
de déplacement, donc quelque chose qui **se joue** au lieu de se subir. Le terrassement
devient un geste militaire autant qu'économique.

**`X5` a une forme.** « Ce qu'un palier de niveau offre » était en blanc depuis `W1` : une
**capacité de combat**. C'est ce qui a permis de ne donner que deux verbes à `F2` — se
déplacer, attaquer — sans condamner le combat à rester plat, et ça enracine les capacités
dans le roster nominatif au lieu d'un catalogue hors-sol. Un système de capacités
générique dans `F2` aurait été un jeu entier, et il aurait tué le jalon avant qu'on sache
si le format tient.

### Ce que `X6` devient

Un ouvrier à zéro point de vie **meurt**. C'est le choix qui sert le pitch, et il a un
revers qu'il valait mieux nommer tout de suite : **sans blessure, un combat n'a que deux
issues, rien ou définitif.** Le joueur qui a bien joué ne sent rien du tout, et la courbe de
difficulté est une falaise.

Les points de vie sont donc la ressource d'une **manche** ; ce qu'un survivant en emporte
est un effet progressif **selon la part de vie perdue**. `X6`, écrit ce matin comme un
rangement, devient structurant — et c'est le premier état dont on connaisse à la fois la
source et la graduation.

### Ce que la conversation a corrigé dans `data/`

**La caserne valait +2 places de déploiement, elle vaut +1.** Sur une base de trois, un
seul bâtiment ajoutait deux tiers de la ligne d'un coup. Une place se gagne très
progressivement — c'est un pion de plus à jouer chaque tour.

Le chiffre datait de `F1`, écrit ce matin, et c'est le harnais Combat qui rend la
correction lisible : la table « ce que la borne retient » montre maintenant trois, quatre
et quatre engagés au lieu de trois, cinq et cinq.

### Ce qui reste ouvert en 3.6

Trois choses, toutes des chiffres ou du contenu : **la nature des vagues** — qui vient,
combien, avec quelles portées —, **la borne de tours** d'une manche, et **le bonus** que
vaut un nettoyage complet. Aucune ne remet en cause le format.

L'éclaireur de 3.7 a changé de métier au passage : la direction d'une vague est désormais
une information de base, annoncée par une flèche, parce que 3.2 veut qu'on pense à la
bataille en posant un bâtiment et qu'une direction révélée le soir même transformerait
cette prévoyance en loterie. Ce qu'un éclaireur révélerait est donc ce qui vient **en
plus** — composition, portée, nombre —, ce qui en fait un meilleur événement.

### Prochain jalon

**`I2`** — inchangé. Cette discussion ne l'avance ni ne le retarde ; elle lui dit quelle
place réserver, ce qui est exactement ce qu'on lui demandait. Le seul travail qu'elle lui
ajoute est la coupure de `end_phase()`, et il vaut mieux la faire là que dans `F3`.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn`, aucun `project.godot`, aucun champ neuf.

- `data/buildings/barracks.tres` a changé d'un chiffre. Rien d'autre dans `data/`.
- `HARNESS` vaut toujours `&"combat"` ; `&"run"` rend le jeu.

---

## 2026-08-26 — `F1` : le bouchon de combat, et la borne qui lui donne un enjeu

**État : terminé.** Six commits sur `feat/f1-combat-stub`, tirée de `master`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **715 tests
verts contre 625** à l'ouverture, 42 suites contre 39. Les sept autres harnais ont été
bootés un par un — trois champs neufs sur `BuildingData` traversent tout le projet.

### Ce qui a été livré

- **Contrats** — `CombatUnit`, `CombatForce`, `DamageReport`. `WorkLine` gagne `NO_CELL`.
- **Schéma et data** — `WaveDef`, `CombatBalance`, les colonnes **Déf.**, **PV** et
  **Dépl.** de 4.1 dans treize `.tres`, `data/waves/` et son indexation par
  `GameDatabase`.
- **Domaine** — `InstantCombatResolver` sous `domain/combat/`, `BattleReport` sous
  `domain/run/`, `RunOrchestrator.fight()`, `Roster.to_combat()`,
  `Worker.to_combat_unit()`, `CityState.damage()`, `PlacedBuilding.take()`,
  `Ledger.take_share()`.
- **Harnais** — `scenes/dev/combat_harness.gd`, quatre tables et une chronique.
- **Quatre-vingt-dix cas de plus**, dont trente-huit sur le résolveur.
- `DESIGN.md` 3.3, 3.4, 3.6, 4.1 et 8 ; `CLAUDE.md`.

### Le déploiement capé, qui vient de l'humain et change le jalon

Le plan proposait que **tout le monde** se batte, en assumant le prix : à `F1` la vague
n'aurait concurrencé la production en rien, donc la tension centrale du pitch n'aurait pas
été exercée. C'était honnête pour un bouchon et ça restait un trou.

La réponse — *« un nombre de slot serait pas mal, la phase de combat commence par une phase
de déploiement capé qui pourra augmenter plus tard, peut-être avec la construction d'une
caserne »* — est meilleure, et pour une raison qui se dit en une ligne : **sans borne, un
ouvrier de plus est un défenseur de plus, donc « envoyer son meilleur récoltant en milice »
ne coûte rien puisqu'on les envoie tous.** La borne rend une place rare, et une place rare
rend le choix réel.

Elle a aussi un effet qu'on n'attendait pas de ce jalon : **elle sort la caserne de sa
coquille**, et avant l'action qu'elle débloquera à `X3`. On la bâtissait pour *S'entraîner*,
qui n'existe pas ; on la bâtira d'abord pour tenir la ligne. C'est un renversement du
tableau de 4.1, et il est délibéré — un bâtiment dont le seul intérêt est de débloquer une
carte absente n'a rien à faire dans un MVP.

Le design est donc passé **en premier**, dans le commit d'ouverture, comme le second axe de
progression à `W1` et la rotation à `C2`. Il a coûté une colonne à 4.1, un champ plat de
plus sur `BuildingData`, et zéro ligne au reste : `slots_for()` est le miroir exact de
`ProductionResolver.capacity_for()` et de `Roster.capacity_for()`, filtre `completed()`
compris.

### Ce que `CombatForce` n'est pas, et pourquoi `W1` avait raison d'attendre

`W1` refusait de l'écrire : « ou bien un clone strict de `LaborForce` qui ne prouve rien,
ou bien une devinette sur des PV et de l'équipement ». Le refus était juste, et l'écart
tient en un mot — **un** multiplicateur, pas un par famille. Un ouvrier récolte
différemment au camp de bûcheron et à l'atelier, donc `LaborUnit` répond par métier ; il ne
se bat que d'une seule façon. Ce qui en aurait fait un clone est précisément ce qui a
disparu.

Elle porte **tout le roster présent**, pas les engagés, et c'est le miroir strict de
`LaborForce`, qui porte tout le monde et non les affectés. Le filtre appartient au
consommateur : l'Économie n'emploie que ce que l'`Assignment` place, le Combat n'engage que
ce que la borne tient. Projeter les seuls déployés aurait donné aux Effectifs à connaître un
plafond qui vient de la ville.

Et le vivier unique cesse d'être une phrase : `to_labor()` et `to_combat()` sont deux
fonctions jumelles qui partent du même `present()`.

### La ligne de dépendance que le pillage a révélée

La règle de `CLAUDE.md` interdit de dépendre des **internes** d'un autre système. Le
corollaire s'est découvert ici : **recevoir le contenu d'un état voisin, même en copie,
revient au même.**

Le plan prévoyait que le résolveur reçoive le stock et rende un pillage réparti par
ressource. C'est faux : répartir demande de lire le `Ledger`, qui est un interne de
l'Économie. Le `DamageReport` dit donc **combien**, jamais quoi, et `Ledger.take_share()`
répond avec la règle de prorata de l'Économie — la même que l'écrêtage d'une récolte, écrite
une seule fois et déjà testée. Le Combat ignore jusqu'à ce que le village stocke.

Le test qui dit de quel côté on est : **la question posée appartient-elle au système qui
répond ?** « Combien la vague emporte » est une question du Combat ; « ce que la réserve
perd quand on lui prend N » est une question de la réserve. `take_share()` est nommée pour
aucun combat en particulier, et un événement de 3.7 lui posera la même question.

Conséquence en cascade : `BattleReport` est né de là. Le `DamageReport` est un ordre, et
deux choses n'existent qu'à l'application — ce que la réserve a **vraiment** perdu, et ce
que la ligne a valu. « Ils ont tout pris » et « ils sont repartis les mains vides » sont
deux fins de vague différentes, et seul ce rapport connaît l'écart.

### La règle de dégâts, écrite dans `DESIGN.md` parce qu'elle se discute

**Une brèche casse d'abord ce qui la retenait, puis ce qui cède le plus vite.** Deux vertus,
et une propriété qui n'était pas cherchée.

La palissade sert vraiment à quelque chose, ce qui n'allait pas de soi pour un bâtiment
entré « par la pratique et non par le design » à `C2`. Et le **Cœur se retrouve en dernier
sans qu'une ligne de code n'écrive son nom**, puisqu'il est le plus solide du tableau de
4.1 : c'est un identifiant de contenu en moins dans du GDScript, obtenu par accident et
gardé exprès.

L'ordre ignore la pose, et c'est le cas de test qui porte le jalon —
`test_the_pose_order_decides_nothing`. Deux villes aux mêmes bâtiments posés dans deux
ordres différents perdent exactement la même chose. Le risque est celui que `E1` avait déjà
nommé pour l'écrêtage : silencieux, invisible à l'œil, et il ne se manifeste que sur deux
parties qu'on compare.

Tu as dit « on modifiera peut-être plus tard », et c'est écrit tel quel : 3.6 la range
explicitement parmi ce que `F2` jettera en premier.

### La blessure déménage, et la famine avec

3.6 réclamait « pertes **et blessures** » depuis le premier jour. La blessure n'entre pas,
et ce n'est pas un renoncement : **elle n'a nulle part où atterrir.** Un `Worker` porte une
présence et de l'XP, rien qui dure et qui pèse. L'inventer dans le rapport d'un système neuf
aurait décidé pour les Effectifs de ce qu'un état fait.

Ta réponse a transformé un report en jalon. `X6` — **états d'ouvrier** — accueille la faim,
la blessure, et ce qui viendra des événements de 3.7. Trois systèmes avaient buté sur le même
manque et l'avaient chacun contourné : `E1` en laissant la famine « se constater sans se
punir », l'`OUVERT` de 3.3 en listant quatre issues dont trois décrivent le même objet, et
`F1` en sortant la blessure.

Il est dans les différés, après `I2`, et pour une raison de méthode : **un système d'états se
conçoit devant la liste de ceux qui existent vraiment**, et cette liste n'est complète
qu'une fois la boucle jouable. Ce qu'il contraint en attendant tient en une ligne, et elle
est dans `DESIGN.md` : **aucun rapport n'invente sa propre conséquence.** Un système qui
rencontre un état le compte ; il ne décide pas de ce qu'il fait.

C'est la troisième fois qu'un jalon **corrige** `DESIGN.md` au lieu de l'appliquer, après
`D2` sur le geste atomique et `W2` sur le micro-management.

### `WaveDef` sort de `contracts/`, et c'est une ligne de `CLAUDE.md` en moins

Elle y figurait depuis `I0`. C'est une `Resource` de `src/schema/`, éditée dans
`data/waves/`, exactement comme `PhaseDef` décrit la forme d'une journée. `contracts/` est
l'endroit où deux systèmes **du code** se rencontrent ; un contenu qu'on règle dans un
`.tres` voyage déjà partout — le domaine reçoit ses blocs d'équilibrage en argument depuis
`E1`, et une `BuildingData` traverse tous les systèmes dans un `BuildingSnapshot`.

Le Combat reçoit donc sa vague comme le résolveur de chantiers reçoit son `ActionBalance`.

### Trois défauts que seule l'exécution a montrés — tous dans le harnais

`E2` et `W2` ont appris qu'un écran trouve ce qu'aucun test ne cherche. `F1` ajoute une
variante plus désagréable : **un tableau de chiffres peut être faux sur ce qu'il prétend
montrer**, ce qui est pire qu'une panne parce qu'on lui fait confiance.

**Un `Array[StringName]` ne s'additionne pas à un tableau littéral non typé**, et le
`as Array[T]` ne rattrape rien. Ça compile, ça casse à l'exécution. Dans un harnais, donc
hors de toute suite de tests.

**La table des murs mesurait sur le plus petit roster**, si bien que la caserne ouvrait des
places que personne ne venait occuper et que sa ligne était identique à la précédente. La
table faisait passer pour inutile le seul bâtiment que ce jalon ajoute.

**La chronique annonçait une vague tombant sur un village déjà entamé** en jouant les trois
vagues par puissance croissante — que le village tenait deux fois sur trois. Elle rejoue
maintenant la plus dure, et la quatrième ligne est le seul endroit du harnais qui montre ce
qu'aucune table ne peut dire : les dégâts restent sur les murs, et les morts ne reviennent
pas.

D'où la discipline entrée dans `CLAUDE.md` : **chaque table annonce ce qu'elle doit
montrer**, en toutes lettres, dans le rapport lui-même. Une table dont on ne sait pas dire
ce qu'elle prouverait ne prouve rien.

### Ce que le harnais dit de l'équilibrage

Sur les chiffres de départ, et à prendre comme un premier relevé et non comme un verdict :

- **La palissade est rentable et la tour l'est davantage.** Cinq bois pour trois de défense,
  vingt-cinq pour huit — la progression est saine, la tour n'écrase pas.
- **La piste Combat ne rattrape pas la pierre**, et c'est voulu. Du palier 0 au plafond, un
  trio passe de 6 à 10 de défense ; une seule tour en donne 8. Bâtir reste le levier, monter
  la piste est un complément. Si l'inverse s'était produit, la caserne n'aurait rien acheté.
- **La borne mord franchement.** Trois, cinq ou huit ouvriers donnent la même défense sans
  caserne, et cinq avec. C'est la démonstration en trois lignes de ce que 3.6 affirme.
- **Un second siège est dévastateur.** Le village passe de six bâtiments à un et de huit
  ouvriers à trois. C'est exactement la spirale qu'un roguelite veut, et c'est aussi le
  chiffre le plus suspect du lot : `breach_per_casualty` est le réglage le plus fragile des
  cinq, et `I3` le verra de près.

### Ce qui n'a pas été fait, et qui était au plan

**Rien du plan n'a été retiré.** Deux choses en ont été ajoutées en cours de route —
`BattleReport` et `Ledger.take_share()` —, toutes deux conséquences de la ligne de
dépendance ci-dessus.

Ce qui est resté dehors était annoncé dehors :

- **Rien ne déclenche une vague.** `RunOrchestrator.fight()` existe, le harnais l'appelle,
  et personne d'autre. La fréquence est l'`OUVERT` de 2, et un calendrier que personne ne
  lit serait la frontière que ce projet refuse depuis `E1`.
- **La fin de run** — 5. veut un score et des conditions de défaite. `I2`.
- **Le poste occupé de la tour de guet** — « +8 déf. si occupée ». `F1` était le jalon
  nommé, et il n'entre pas : **aucun verbe de 4.2 ne tient un poste de défense.** Il en
  faudrait un huitième, hors du tableau. Même refus que `E1b` a opposé à cinq `slots = 1`.
- **La blessure** — `X6`.
- **Le rendu d'un bâtiment endommagé** — `BuildingRenderer` ne montre rien des PV. Les
  dégâts traversent `BuildingSnapshot`, la vue les lira quand il y aura un écran de combat.

### Prochain jalon

**`I2`** — la boucle complète. Tous les systèmes du MVP existent et tiennent debout seuls, et
**aucun contrat ne bougera plus** : c'était la raison de passer `F1` d'abord, et elle est
tenue. Il reste trois fils à brancher, chacun sur une prise déjà posée — la vague dans
`close_the_day()`, où `DayReport` l'accueillera par un champ ; le calendrier des vagues, qui
sera un bloc de `data/balance/` ; et la défaite, qui lit ce que la ville et le roster disent
déjà.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'`InputMap`
ajoutée.

- `F5` lance le **harnais Combat** — `HARNESS` vaut `&"combat"`. `&"run"` rend le jeu.
- **Une catégorie neuve dans `data/`** : `data/waves/`, trois vagues. Le rapport de boot
  annonce désormais six catégories.
- **Trois `.tres` neufs sans `uid://`** — les trois vagues, plus `combat_balance.tres`.
  L'éditeur leur en ajoutera un au premier réenregistrement : c'est un diff à attendre, pas
  un problème.
- **Treize `.tres` de bâtiments rouverts.** Seules les valeurs non nulles y sont écrites,
  puisque Godot n'écrit jamais un champ égal à son défaut — un `defense = 0` disparaîtrait
  au premier réenregistrement de toute façon.
- **Les chiffres du bloc `combat` sont à relire** : trois places de déploiement, deux de
  défense par homme, un mort tous les six points de brèche, une unité pillée par point. Le
  harnais mesure les quatre.
- **L'équilibrage des ressources reste le premier chantier ouvert**, inchangé depuis `I1` :
  deux récoltes par jour pour un seul upkeep. `F1` n'y a pas touché, et vient d'ajouter une
  seconde source de pertes.
- Les caches de classes et d'uid ont été reconstruits pendant la session, et les `.gd.uid`
  des sept scripts neufs sont commités.
- **La branche n'est pas fusionnée** : `feat/f1-combat-stub`, six commits.

---

## 2026-08-26 — `W2` : choisir qui, et une phrase de design qu'il a fallu corriger

**État : terminé.** Sept commits sur `feat/w2-assignment` — dont trois qui corrigent le
jalon après coup, sur un défaut trouvé au clavier. Les trois commandes passent : boot sans
erreur ni warning, tout `src/domain/` parse, **625 tests verts contre 589** à l'ouverture.

`StaffingAdvisor` dans `domain/run/` ; `ProductionResolver.family_of()` devient publique ;
`RunOrchestrator.auto_staff()` ; `WorkerCard` et `AssignmentPanel` sous
`src/adapters/workforce/`, le dossier que l'arborescence réservait depuis `I0` et que rien
n'habitait ; `Deck.take_back()`. Une suite neuve et 36 cas de plus, dont dix sur
l'orchestrateur. **Aucun DTO de `contracts/` créé ni modifié**, pour la deuxième fois
d'affilée. `DESIGN.md` 3.4, 3.5 et 8.

### La phrase de `DESIGN.md` qu'il a fallu corriger, et pourquoi je ne l'ai pas contournée

3.4 listait trois mitigations du micro-management et concluait : « C'est du travail
d'adapter, pas de domaine. » C'est vrai des deux qui encadrent la troisième — un effectif
réduit est un chiffre d'équilibrage, une affectation persistante est une politique
d'écran. **Ce n'est pas vrai du bouton.**

Classer des ouvriers exige la famille que chaque action posée créditera, les
multiplicateurs de la `LaborForce`, et la capacité figée à la pose. La famille n'est
calculable qu'à un seul endroit : `ProductionResolver.family_of()`, dont le docstring dit
qu'elle est « posée ici et nulle part ailleurs ». L'écrire dans une vue aurait donc demandé
de l'y recopier, et une vue qui classerait sur une famille que le soir ne crédite pas est
un défaut qui ne se voit qu'au bout de dix journées, sur une courbe d'XP.

L'argument décisif est ailleurs : **le bouton est un geste.** `CLAUDE.md` promet depuis
`I0` qu'un seed plus une suite de gestes rejoue un run à l'identique. Un geste dont le
résultat n'est pas reproductible casse cette promesse, et `src/adapters/` n'est pas testé.
La question a été posée avant d'écrire une ligne, et la réponse est entrée dans
`DESIGN.md` dans le même commit que le domaine — le journal seul n'aurait pas suffi : la
prochaine session lit le design.

### La règle du bouton, qui est du gameplay et non de la technique

Écrite en 3.4 parce qu'elle se discute :

> Parcourir les actions **dans l'ordre de pose**, remplir les postes qui restent avec
> l'ouvrier libre le plus efficace dans la famille de cette action, départager à égalité
> par l'ordre du roster. Sauter une action que rien ne crédite. Ne jamais déplacer un
> ouvrier placé à la main.

Le choix le plus discutable est ce qu'elle **refuse** de faire : elle ne pondère pas par le
rendement. Une récolte à 3 bois et une case nue à 1 se valent devant elle. Pondérer aurait
demandé de lire `_yield_of()`, et surtout rendu un cran de chantier comparable à une
récolte — un arbitrage d'équilibrage, donc `I3`.

Ce que ça achète en échange vaut mieux que l'optimalité : **l'ordre de pose est la priorité
que le joueur a déjà exprimée**, et le bouton s'y tient. Il ne décide jamais quelle action
mérite un ouvrier, seulement *qui* y va — la moitié évidente de la décision, celle que 3.4
veut retirer. Un bouton plus malin serait un bouton qu'on ne pourrait pas prédire, donc
contre lequel la surcharge manuelle serait un combat.

### Le cas de test qui porte le jalon

`test_the_announced_family_is_the_one_the_evening_credits` résout un vrai soir avec les
deux résolveurs, puis confronte **chaque ligne de travail** à ce que l'advisor annonçait
pour l'action dont elle vient. C'est le seul vrai risque du jalon, et il est silencieux :
un classement sur la mauvaise piste produit des affectations plausibles, un soir qui résout
normalement, et une courbe d'XP qui dérive sans que rien ne tombe.

Deux égalités sont épinglées exprès. À efficacité égale c'est l'ordre reçu qui départage,
et une famille que personne n'a entamée laisse l'ordre du roster intact. Sans les deux,
deux runs partis du même seed enverraient deux ouvriers différents sur le même poste, et ni
la bourse ni le relief ne le montreraient. Le cas de rejeu de `I1` a gagné un jumeau qui
passe par le bouton.

### Ce que le domaine n'a pas eu à inventer

`family_of()` devient publique plutôt que d'être recopiée — même geste que
`staffing_refusal()` à `I1` : une seconde question se pose sur la même règle, donc la règle
sort, elle ne se duplique pas. `auto_staff()` applique le plan **à travers** `staff()`,
jamais autour — une porte d'affectation qui court-circuiterait les cinq refus serait une
seconde liste de règles.

`StaffingAdvisor.plan()` **ordonne et ne mute rien**, comme `SiteResolver` depuis `I1` : il
se teste sans run, et l'écran pourrait l'appeler pour prévisualiser sans rien engager. Il
compte les postes exactement comme `staffing_refusal()`, ce qui garantit qu'aucune paire
proposée ne peut se faire refuser — un plan à moitié appliqué serait invisible à l'écran.

### Ce qu'un `Worker` fait dans une vue

`W1` a écrit que « rien hors de `domain/workforce/` n'en voit un », et la fiche en reçoit
un. Ce n'est pas une entorse : la phrase vise les **systèmes du domaine**, ceux à qui l'on
ne montre que des projections. Un adapter lit le domaine — `ResourceBar` prend un `Ledger`,
`HandView` une `Hand`, `BuildingRenderer` un `CityState`. Passer par la `LaborForce` aurait
coûté le niveau, l'XP et la présence, qui n'y traversent pas justement parce que l'Économie
n'a pas à les connaître.

Le panneau, lui, reçoit un **`RunState`**, ce qu'aucune vue n'avait fait. Une affectation a
besoin du plateau, du roster et du brouillon qui les relie, plus le relief et la ville pour
la famille de chaque action : `RunState` est le seul objet qui les tienne ensemble, et 3.8
l'autorise à exister pour cette raison même.

### Le legs de `E2` repris, et déplacé

`ProductionPanel` « ne nomme pas qui a franchi un palier » parce que ça lui demanderait le
`Roster`, « c'est-à-dire exactement la dépendance que `W2` existe pour porter ». Elle est
portée — mais **sur la fiche de l'intéressé**, pas dans le compte rendu de récolte. Un
palier appartient à la personne, et l'annoncer aux deux endroits aurait rejoué le doublon
que `E2` avait précisément défait en retirant la réserve du pavé de texte.

### Trois défauts de mise en page, tous trouvés en capture

Cette fois sur des défauts **structurels** plutôt que sur des pièges d'API.

**Deux panneaux qui grandissent l'un vers l'autre finissent par se recouvrir.** Le compte
rendu de phase en haut à droite et le panneau d'affectation en bas à droite tiennent tant
que le plateau est vide, et se chevauchent dès cinq actions posées. Ce n'est pas une marge
à régler : c'est un chevauchement qui n'attend que la phase la plus chargée, donc qui se
manifeste le plus tard possible. Une colonne les fait se pousser au lieu de se croiser.

**Une liste qui suit la partie sort de n'importe quel HUD de taille fixe.** Elle est bornée
et le reste est compté. Corollaire contre-intuitif appris en chemin : augmenter la marge
basse **aggrave** le débordement, parce qu'un conteneur trop petit pour son contenu le
laisse déborder par le bas au lieu de le remonter.

**Une ligne qui n'apparaît qu'au palier fait sauter toute la grille**, et elle le fait au
moment exact où le compte rendu de phase est le plus long. La ligne est désormais toujours
là, et montre l'XP totale à défaut de palier : pas du remplissage, l'axe du niveau
d'ouvrier, celui que les pistes n'expliquent pas. Même raison que les quatre colonnes de
`ResourceBar` qui ne bougent pas à zéro.

Les trois sont dans `CLAUDE.md` : la prochaine vue n'a pas à les réapprendre.

### Ce que la capture a dû changer pour prouver quelque chose

Elle s'arrêtait après une résolution, donc sur un plateau vide et six fiches oisives —
c'est-à-dire sur tout `W2` sauf ce qu'il fait. Elle joue maintenant une manche de plus
qu'elle **ne finit pas** : la seule image qui prouve quelque chose est celle où des
ouvriers tiennent des postes. Elle remplit ces postes par le **bouton**, ce qui fait passer
le chemin neuf du jalon sous le seul contrôle qui regarde l'écran. Et elle perd la table
des actions posées, à contrecœur : c'est elle qui avait attrapé le seul vrai bug de `D2`,
mais la garder aurait laissé la version imprimée dire vrai pendant qu'une mise en page
fautive cachait l'autre.

### Une heure perdue sur un `cd`

À noter parce que ça se reproduira. Un `cd src/adapters/workforce &&` dans une commande a
laissé le shell dans ce dossier, et les commandes suivantes ont lancé Godot avec `--path .`
sur un dossier sans projet. Symptômes : le boot cesse d'imprimer sa ligne, une capture ne
rend jamais la main, le renderer bascule en OpenGL, `.godot/` « a disparu ». Rien n'était
cassé. **Toujours des chemins absolus**, et vérifier `pwd` avant de conclure qu'un projet
est en vrac.

### Ce qui n'a pas été fait, et qui était au plan

**La bande de fiches dans le harnais Effectifs.** Retirée plutôt que forcée : ce harnais
est un rapport texte plein écran sur dix ouvriers et trente soirs, et six fiches graphiques
n'y ont ni la place ni l'idiome. La fiche se regarde dans le harnais Run, qui est aussi
l'endroit où elle sert. Le seul manque réel est de la voir aux paliers 3 et 4, que quinze
journées n'atteignent pas.

### Le défaut que le clavier a trouvé, deux jalons de suite

*(Trouvé par l'humain juste après le jalon, corrigé dans la foulée.)* Retirer une action ne
rendait pas sa carte.

Le comportement était **documenté comme volontaire** dans `RunOrchestrator.withdraw()` —
« elle est à la défausse depuis qu'on l'a jouée, c'est l'état par défaut et non une
réponse » — et renvoyé à l'`OUVERT` de 3.5. Le docstring avait tort, et sur un point
précis : **il confondait deux gestes.** Cet `OUVERT` porte sur les cartes *non jouées en
fin de phase* ; un retrait reprend une carte *jouée*, dans la phase même, avant que quoi
que ce soit n'ait été consommé. Deux moments, deux questions, et `I2b` garde la sienne
entière.

Le prix de l'ancienne lecture ne se voyait qu'au clavier : le clic droit n'était pas une
annulation mais un sacrifice, et il punissait une cible mal visée plutôt qu'une décision.
Le scumming qu'on aurait pu craindre en retour — poser pour lire la capacité, retirer,
reposer ailleurs — n'existe pas, la ligne de survol annonçant déjà « accepté, N poste(s) »
avant le jeu.

**Aucun test ne figeait l'ancien comportement**, et c'est la différence avec le cas que
`E2` avait dû réécrire : les trois cas de retrait ne vérifiaient que le plateau et les
ouvriers. Rien n'avait été prouvé, seulement supposé.

`Deck.take_back()` est l'inverse exact de `discard()`, et reprend le **dernier exemplaire
tombé** — sans conséquence observable, deux exemplaires étant interchangeables, mais ça
fixe l'ordre et garde deux runs du même seed identiques jusque dans les piles. Le cas qui
compte est que la carte rendue **se rejoue** ; son revers aussi — un retrait que la phase
refuse ne rend rien, sans quoi un clic droit dans la mauvaise phase serait une source de
cartes gratuites.

**Et un second défaut est tombé avec, que personne n'avait signalé.** Le harnais garde un
**rang** dans la main, jamais un identifiant — la leçon de `D2`. Une carte rendue s'insère
dans son pool et décale tout ce qui suit : tenir une carte de bâtiment et retirer une
action changeait donc silencieusement ce qu'on tenait. `_play_here()` reposait déjà la
sélection pour cette raison exacte ; `_withdraw_here()` le fait maintenant aussi.

### Ce qui reste

- **l'affectation persistante d'une phase à l'autre** — la troisième mitigation de 3.4.
  Elle touche au vidage du board et au sort de la main non jouée, qui est l'`OUVERT` de
  3.5 : c'est `I2b`, sur un `.tres`.
- **le recrutement** — `OUVERT` de 3.4. Le panneau affiche « 6/12 places » ; ce qui les
  remplit n'existe toujours pas.
- **`X5`** — le niveau se gagne et se lit sur la fiche, il n'ouvre rien.
- **le libellé français d'une famille.** La fiche affiche « Harvest » et « Construction »,
  parce qu'aucune famille n'est déclarée nulle part : 3.4 pose que la liste n'est pas close
  et qu'aucun code ne l'énumère. Écrire une table identifiant → libellé dans une vue
  rouvrirait l'énumération que la Construction a pu rejoindre sans une ligne de GDScript à
  `I1`. Le jour où ça comptera, ce sera un champ de `.tres`.
- **la sortie sous `scenes/ui/`** — `I2`, comme les trois vues de `E2`. C'est là aussi que
  la borne de trois lignes du panneau devra être traitée pour de bon.

**Repères d'équilibrage** : la capture au jour 8 montre une famine à 5 ouvriers à jeun et
une réserve à 29 — deux récoltes par jour pour un seul upkeep n'ont pas suffi. Et les
paliers sont lents à voir : quatre XP par poste, vingt-cinq par palier, donc sept soirs de
travail dans la même famille pour le premier cran.

---

## 2026-08-26 — `E2` : la réserve regardable, et le mensonge qu'un écran a trouvé

**État : terminé.** Six commits sur `master`, **589 tests verts contre 585**. Premier jalon
d'écran du projet. `CommodityPalette`, `ResourceBar`, `ProductionPanel` sous
`src/adapters/hud/` ; `CommodityData` gagne un `order` ; `RunOrchestrator` relève la
réserve dès qu'un chantier d'entrepôt est achevé. `hud_harness` neuf, `run_harness` allégé.
**Aucun DTO de `contracts/` créé ni modifié** — c'est la première chose à dire du jalon.

### Ce qu'un jalon d'écran n'a pas à écrire

Le plan tenait en une ligne qui a décidé de tout le reste : **aucun DTO de `contracts/` ne
bouge**. Deux vues qui lisent un `Ledger` et un `PhaseReport` ne franchissent aucune
frontière neuve — `CLAUDE.md` pose depuis `I1` que le critère d'entrée est un second
**système du domaine**, pas un adapter. Un `LedgerSnapshot` aurait été le geste réflexe, et
il aurait figé une forme que personne ne traverse.

Corollaire assumé : **peu de tests**. `src/adapters/` n'est pas testé, et un jalon dont le
contenu est trois `Control` n'a pas à inventer du domaine pour se donner de quoi tester.

### La jauge est unique, et c'est tout le sujet

`E1` a tranché pour une **réserve commune** : cent unités partagées. Depuis, c'était une
règle de résolution que rien ne montrait. Quatre jauges côte à côte auraient dessiné quatre
plafonds indépendants, c'est-à-dire exactement la lecture que `E1` a écartée — et la phrase
de 3.3, « un joueur qui ne la voit pas ne comprend pas pourquoi son entrepôt manque »,
serait restée une intention. Une seule barre segmentée où le bois qui monte pousse la place
de la pierre est la décision de `E1` rendue regardable.

Deux détails d'affichage qui sont des décisions, pas de la mise en forme. **Les quatre
colonnes ne bougent jamais**, même à zéro : une ressource qui apparaîtrait le jour où l'on
en gagne la première unité ferait glisser ses voisines sous l'œil. Et **le reste de la
division va à la place libre**, jamais à une ressource : lui donner un pixel de plus ferait
mentir la seule barre qui compte, celle qui dit s'il reste de la place. Une réserve pleine
n'a donc aucune place libre à l'écran, pas même d'un pixel.

### Le mensonge d'une phase, que seul un écran pouvait trouver

**C'est le vrai apport du jalon, et il n'était pas au plan.**

`ProductionResolver.resolve()` pose la capacité de la réserve, puis `_apply()` achève les
chantiers. Un entrepôt fini ce soir ne relevait donc la réserve qu'**au soir suivant** :
entre les deux, un bâtiment visiblement terminé sur la carte cohabitait une phase entière
avec une jauge annonçant l'ancien plafond.

Personne ne l'avait vu, et pour une raison qui vaut d'être écrite : **aucun écran
n'affichait la capacité en continu**, et la résolution suivante la reposait de toute façon.
**Un mensonge qui se corrige tout seul reste un mensonge le temps qu'il dure.** Le harnais
Économie contournait d'ailleurs la même chose depuis `E1`, en reposant la capacité à la
main, et son commentaire renvoyait la question « là où le HUD de `E2` le fera aussi ».

Elle n'a pas été faite là. Un adapter qui appellerait `Ledger.set_capacity()` serait la
faute d'architecture que `CLAUDE.md` refuse en premier. C'est `RunOrchestrator` qui relève
la réserve, juste après avoir appliqué les chantiers, parce qu'il est le seul à tenir la
ville et la bourse. **La règle d'ordre de `I1` ne bouge pas d'un pouce** : la production
est déjà calculée quand le plafond monte, donc un entrepôt achevé ce soir ne sauve toujours
pas la récolte de ce soir. Ce qui change n'est pas la résolution, c'est ce que l'écran
raconte entre deux.

### Le test de `I1` qu'il a fallu réécrire, et pourquoi ce n'est pas un recul

`test_a_warehouse_finished_tonight_only_raises_the_cap_tomorrow` affirmait exactement ce
que la correction change. Son docstring justifiait la **règle** — la récolte du soir n'est
pas sauvée — mais son assertion portait sur un **effet de bord** : que le compteur vaille
encore 100 à la fin de la phase. Les deux ne sont pas la même affirmation, et `I1` les a
confondues parce que la seconde était la seule chose observable à l'époque.

Le cas remplit désormais la réserve à ras bord avant de résoudre : la récolte du soir n'a
nulle part où entrer, et elle est visiblement perdue alors même que l'entrepôt s'achève.
C'est **plus fort** que ce que `I1` pouvait épingler.

Réécrire un test qu'un jalon précédent a délibérément écrit, docstring argumentée à
l'appui, mérite d'être signalé plutôt que fait en passant. La question à se poser était :
**est-ce que je casse la règle, ou est-ce que je casse l'observation qu'on en faisait ?**
La réponse était la seconde.

### L'ordre des ressources, ou le troisième `_bundle_text()` évité

`run_harness._bundle()` et `economy_harness._bundle_text()` étaient la même fonction écrite
deux fois, et un panneau de production en voulait une troisième. C'est exactement le
problème que `I1` note à propos du `_make_label()` à neuf exemplaires : « elle n'appartient
à aucun jalon, ce qui est précisément pourquoi elle ne se fait jamais ». Celle-ci
appartenait à celui-ci — afficher un lot de ressources *est* le sujet.

`CommodityPalette` les remplace, et donne au passage un foyer à une question que personne
n'avait posée : **dans quel ordre affiche-t-on les ressources ?** Les deux copies triaient
par identifiant, donc en anglais interne, ce qui rangeait la nourriture — celle qui tue —
entre le minerai et la pierre. Le rang vit désormais sur la `CommodityData`, parce que la
seule alternative était une liste d'identifiants dans un `.gd` : le nombre magique que les
conventions refusent, et que 3.3 refuse nommément en sortant l'ensemble des ressources de
l'énumération du code.

Il commence à **1** et non à 0 : un champ non renseigné vaut 0, et un rang 0 légitime
aurait rendu l'oubli indétectable. Un cas de test tient le seul vrai piège du champ — deux
ressources ne partagent pas un rang, sans quoi leur ordre retomberait sur une comparaison
de `StringName`, stable le temps d'une session et différente à la suivante.

### L'`OUVERT` refermé : les oisifs restent un compte

`production_report.gd` portait la question depuis `E1`, renvoyée à « ce que E2 tranchera
devant une vraie maquette ». Trois raisons se cachaient derrière un seul chiffre : non
affecté, affecté à une ancre vide, arrivé quand les slots étaient pris.

Devant la maquette, la réponse est **non**. Au niveau de la phase les trois s'effondrent de
toute façon en « n'a tenu aucun poste », qui est la seule lecture juste depuis `I1`. Et les
séparer aurait demandé au résolveur de tracer une information que le joueur voit **déjà**
sur le plateau avant de résoudre, donc au moment où il peut encore agir. **Un chiffre qu'on
ne peut plus corriger n'a pas besoin de trois colonnes.**

### Ce que le panneau lit, et ce qu'il refuse de lire

Il prend un **`PhaseReport`** et non un `ProductionReport`, alors que le jalon s'appelle
Économie. `I1` a trouvé que le rapport de production compte comme oisif un ouvrier parti
bâtir, et que seul le rapport de phase voit les deux journaux de travail. Un panneau qui
lirait le second réintroduirait le mensonge que `I1` a diagnostiqué, et il le
réintroduirait en grand, à l'écran.

Il **ne nomme pas** qui a franchi un palier : le faire demanderait le `Roster`, la
dépendance que `W2` existe pour porter.

Le libellé de la phase lui est **fourni** plutôt que lu. Un `PhaseReport` porte
l'identifiant de sa phase et non son libellé, et au moment où `phase_resolved` arrive le
cycle a déjà avancé. Le harnais, lui, connaît celle qu'il finit — il la retient avant
d'appeler `end_phase()`. Aucun nom de phase n'est écrit nulle part, ce que `DESIGN.md` 2
exige jusque dans les adapters.

### Les deux pièges de mise en page, trouvés en capture l'un après l'autre

**Premier piège.** `set_anchors_preset()` prend un **booléen** en second argument, là où
`set_anchors_and_offsets_preset()` prend un `LayoutPresetMode`. Lui passer
`PRESET_MODE_MINSIZE` revient à lui dire « garde tes décalages », donc à laisser la vue à
la taille qu'elle avait — zéro, la mise en page n'ayant pas encore tourné. Un
`PanelContainer` de taille nulle **ne dessine pas son fond** pendant que ses libellés
débordent par-dessus la carte.

**Second piège**, qui survit à la correction du premier : `get_combined_minimum_size()` lu
juste après avoir ajouté des enfants rend encore la valeur d'**avant**, Godot la
recalculant à la passe suivante. Le panneau se plaçait donc sur la taille du rapport
précédent, ce qui n'aurait été visible qu'au deuxième rapport d'une session.

La correction n'est pas un calcul plus fin, c'est **l'abandon du calcul** : un
`MarginContainer` plein écran dont l'enfant porte `SIZE_SHRINK_BEGIN` ou `SIZE_SHRINK_END`
ne se trompe sur aucun des deux, et ne se trompe pas davantage à la dixième mise à jour du
contenu. C'est écrit dans `CLAUDE.md`.

### Ce que le harnais Run perd, et pourquoi c'est le vrai livrable

Le jalon aurait pu ajouter deux vues et laisser le pavé de texte tranquille. Il en a retiré
deux morceaux à la place : la réserve sort du bandeau, le compte rendu de résolution
disparaît entièrement.

Garder les deux aurait laissé **le même chiffre lisible à deux endroits**, et un chiffre
affiché deux fois est un chiffre qui finira par différer de lui-même. La capture ne vérifie
qu'une seule des deux mises en forme ; l'autre dérive en silence. Pour la même raison, la
capture du harnais Run n'imprime plus le rapport du soir — elle imprime la réserve
chiffrée, qui est ce qu'aucune image ne rend lisible d'un coup d'œil et la seule preuve que
la bourse a été débitée.

### Le harnais qui fabrique ses cas

Le harnais Run montre les deux vues **en situation**. Ce qu'il ne peut pas montrer, c'est à
quoi elles ressemblent quand ça va mal : une réserve pleine qui gaspille, une famine, une
journée qui ne se ferme pas. Un run met une dizaine de journées à y arriver, et une capture
ne sait pas attendre.

`hud_harness.gd` **fabrique** donc ses cinq scènes au lieu de les jouer, sur le même
principe que le harnais Économie cherche le soir où l'économie casse. Il n'y a **pas de run
ouvert** derrière — ce qui est aussi le contrôle que les deux vues ne lisent rien d'autre
que ce qu'on leur donne. Il réutilise `--shot-evenings` pour désigner la scène plutôt que
d'inventer un neuvième drapeau : seul harnais où ce drapeau ne compte pas un temps mais un
cas, ce que `dev_shot.gd` permet en posant que chaque harnais ignore ceux qui ne le
concernent pas.

### Ce qui reste

- **la prévisualisation de ce qu'une action posée rapporterait.** C'est `C3` : le calcul de
  delta au survol vient avec l'adjacence, et l'écrire ici demanderait au résolveur une
  porte « à blanc » qu'aucun jalon n'a réclamée.
- **la sortie sous `scenes/ui/`.** Les trois vues restent construites en code, comme
  `HandView` depuis `D2`. Elles déménageront quand `I2` fera un vrai écran, et elles
  déménageront avec leur mise en forme : elles n'ont pas de règles à emporter.
---

## 2026-08-25 — `I1` : la journée, la bourse, et les deux verbes enfin exécutés

**État : terminé.** Dix commits sur `feat/d1-deck`, à la suite de `D2` — dont deux qui
corrigent le jalon lui-même, l'un venu d'une partie jouée au clavier et l'autre d'une
décision de design que j'avais prise seule. **585 tests verts contre 467.**

`PlayResult`, `SiteReport`, `PhaseReport`, `DayReport` dans `domain/run/` ; `UpkeepReport`
dans `domain/economy/` ; `PlayedAction` et `TargetResult` gagnent un **sens**,
`ProductionReport` perd son upkeep. `PhaseDef` et `RunBalance` ; `DayCycle`, `RunState`,
`SiteResolver`, `RunOrchestrator`. `RunManager` réécrit, trois signaux sur `EventBus`,
`run_harness.gd`. `DESIGN.md` 2, 3.2, 3.3, 3.4, 3.5, 3.8, 4.1, 4.2 et 8.

### La décision qui porte le jalon : ordonner plutôt que muter

`D2` avait laissé *Construire* et *Terraformer* se poser et s'affecter sans rien faire :
leur effet mute le `CityState` et la `HeightGrid`, donc l'état de deux autres systèmes, et
un résolveur d'Économie qui les muterait violerait la règle de dépendance.

`SiteResolver` **ordonne** — tant de crans sur cette ancre, tant de hauteur sur cette
cellule — et ne touche à rien ; `RunOrchestrator` **applique**, parce qu'il est le seul
objet du projet à tenir les deux états à la fois, ce que `DESIGN.md` 3.8 autorise
nommément. Le résolveur reste aussi pur que son jumeau, et il n'a même pas besoin du
terrain : un terrassement rend un delta. Bénéfice non prévu : **un soir devient
rejouable** — appliquer deux fois le même rapport au même état donne le même état.

### Quatre questions arbitrées avant d'écrire

**Le sens d'un terrassement se choisit à la pose**, comme l'orientation d'un bâtiment
appartient au placement et non à sa `BuildingData`. Prix annoncé avant d'être payé : deux
DTO de `contracts/` changent de forme. L'alternative — deux cartes en data — ne coûtait
aucun contrat mais faisait dépendre d'un tirage la correction d'un relief. **Une carte
qu'on oriente vaut mieux qu'une carte qu'on subit.**

**La piste que crédite un chantier est une quatrième famille** — l'`OUVERT` de 3.2 traînait
depuis `C4`. La plus chère des trois issues, pour la bonne raison : bâtir doit être un
métier. Le coût réel s'est révélé nul, **rien dans le code n'énumère les familles** : les
pistes se créent à l'usage, le nom vit dans `data/balance/`.

**Ce que ce multiplicateur multiplie**, question que la précédente a immédiatement ouverte
— sans réponse, la piste aurait accumulé de l'XP que rien ne consomme. Les crans d'un soir
sont la **somme des efficacités de l'équipe, tronquée, plafonnée à ce qu'il reste à
bâtir** : même arithmétique que la production, et le plafond figé à la pose n'est jamais
dépassé.

**L'eau et le rocher ne se terrassent pas**, pour une raison mécanique et non thématique :
terrasser déplace la **hauteur**, pas le `TerrainData`. Monter une case d'eau la laisserait
eau — inconstructible, toujours tagguée — pour le prix d'une carte et d'un ouvrier. Changer
le sol sera un *Défricher*, et c'est un autre verbe.

### Le modèle de journée — une décision prise seule, et qu'il a fallu défaire

**C'est la faute de méthode du jalon.** La première version en data suivait la lettre de
`DESIGN.md` 2 et donnait une seconde phase qui n'autorisait rien et résolvait à sa fin :
**deux validations pour un soir**, une pour entrer dans une phase où il n'y a rien à faire,
une pour en sortir. Défaut réel, invisible aux tests, qui ne se voit qu'en essayant de jouer.

J'ai corrigé le mauvais bout. Au lieu de rendre la seconde phase permissive elle aussi,
j'ai **séparé les deux gestes** — une phase pour poser les cartes, une pour y envoyer les
ouvriers — et je l'ai annoncé en une phrase au passage au lieu de m'arrêter. C'était une
question de design, pas une correction technique, et la consigne de session dit en toutes
lettres de ne jamais en trancher une seul.

La journée voulue est le **modèle symétrique** : deux phases identiques, chacune autorisant
les deux gestes et se résolvant à sa fin — elle ne souffre d'ailleurs pas du défaut que je
cherchais à éviter. Le coût de la correction dit quelque chose sur ce qui avait été bien
fait : **le code n'a rien eu à changer.** Le harnais lit ce que la phase autorise, il ne le
suppose pas ; les tests fabriquent leurs propres journées et vérifient le *mécanisme* de
garde. C'est un `.tres` qui a bougé.

### Ce que la correction a révélé : une journée compte deux résolutions

Deux phases qui résolvent, c'est deux récoltes par jour. Mais on ne mange pas deux fois
parce qu'on a récolté deux fois, et l'upkeep vivait dans le rapport de production depuis
`E1`. Ce n'était pas visible tant qu'une journée n'avait qu'un soir : production et upkeep
tombaient forcément ensemble, et cette **coïncidence avait été prise pour une règle** —
`DESIGN.md` 2 les listait pourtant depuis le premier jour comme deux étapes distinctes.

- une **phase** produit — ce que les actions posées rapportent, les chantiers, l'XP ;
- une **journée** coûte — l'upkeep, et demain l'événement de 3.7 et le combat de `F1`, qui
  entreront par un champ chacun sur `DayReport`.

Sans cette séparation, la structure de la journée deviendrait inséparable de son
équilibrage : passer de deux phases à trois obligerait à rééquilibrer la nourriture, et
l'`OUVERT` de 2 cesserait d'être testable en échangeant un `.tres` — c'est-à-dire qu'il
cesserait d'être ouvert. `ProductionReport` perd quatre accesseurs au profit d'un
`UpkeepReport` (contrat qui change de forme, annoncé et validé cette fois) ; `EveningReport`
devient `PhaseReport`, « soir » ne désignant plus une phase mais la fin de journée.

**La fin de journée n'est pas un champ de data**, seul endroit du jalon où j'ai refusé d'en
ajouter un : une journée se ferme après sa dernière phase, par définition, et un booléen
pourrait dire le contraire de la liste qui le porte. Elle est aussi indépendante de
`resolves` — une journée coûte à nourrir même si sa dernière phase ne produit rien.

### Deux endroits où j'ai changé une règle du projet plutôt que de la contourner

**`ActionTargeting` n'est plus le seul fichier qui nomme des cartes**, `SiteResolver` en
ouvre un second. Ce n'est pas une entorse : **où** un verbe se pose et **ce qu'il fait**
sont deux questions, la seconde étant exactement celle que 4.2 refuse de mettre en data. La
garantie « un seul fichier » est remplacée par une plus forte et **vérifiée** : tout verbe
que le ciblage accepte est soit productif selon `data/balance/`, soit exécuté par le
résolveur de chantiers — un cinquième verbe ne peut plus se poser, s'affecter et ne rien
faire, ce qui était l'état de deux d'entre eux entre `D2` et `I1`. Un second cas tient le
revers : aucun verbe n'est les deux à la fois, sans quoi une carte compterait double.

**Les trois rapports du run ne sont pas des contrats.** `PhaseReport` porte un
`ProgressReport`, interne aux Effectifs : le mettre dans `contracts/` l'y aurait fait entrer
par la porte de derrière. Même argument que `PickResult` — le critère est un second
**système du domaine**, pas un adapter.

### Le piège que les tests ont attrapé, et celui que le clavier a trouvé

**`ProductionReport.idle()` s'est mis à mentir.** Le rapport de production ne connaît que
les postes de production : dès que les chantiers s'exécutent, un ouvrier parti bâtir y
figure comme **oisif**. Les deux lectures sont chacune juste dans leur système et fausses
dans la journée. Le corriger sur place aurait demandé au résolveur d'Économie de recevoir
un rapport qu'un autre système produit ; c'est `PhaseReport.idle()` qui répond pour la phase
entière, seul à voir les deux journaux de travail. Un cas de test épingle les deux lectures
côte à côte : le bâtisseur est oisif dans l'une et pas dans l'autre, et c'est voulu.

**Le rappel des ouvriers au retrait d'une action ne s'exécute jamais avec la journée
livrée** — on ne revient à une phase qui pose qu'après une résolution, qui a déjà tout vidé.
Ce n'est pas du code mort : il s'allume dès qu'une journée laisse poser et affecter dans la
même phase, donc dès qu'un `.tres` change. Le cas construit donc sa propre journée, ce qui
est aussi un rappel qu'une journée est de la data.

**Le défaut que seul le clavier a trouvé — un refus sans cause.** *(Trouvé par l'humain
juste après le jalon.)* Espace sur une action posée répondait « refusé » sans dire pourquoi.
La cause était entière et légitime — la phase Construction n'autorise que *poser*. Le refus
était juste ; c'est le silence qui ne l'était pas. L'origine est une justification écrite un
peu vite : `staff()` rendait un booléen nu, « les quatre refus possibles se voyant tous à
l'écran avant le clic ». Vrai à la lettre, faux à l'usage — rien ne reliait le bandeau à une
touche qui ne répond pas, et **un refus qui ne se nomme pas est indiscernable d'une
panne**, exactement le diagnostic de `D2` sur les touches 4 et 5. La correction ne rajoute
pas un DTO : `staffing_refusal()` devient le **seul juge** des cinq refus, `staff()`
l'appelle et l'écran aussi pour traduire — même partage que le fantôme de `C2` et la pose.

Deux jalons de suite, le défaut que ni le parsing, ni les tests, ni une capture n'ont vu est
venu d'une paire de mains. **Le harnais ne se juge pas en le lisant.**

### Le cas qui rend vraie une promesse de `I0`

`CLAUDE.md` promet depuis le premier jour qu'« un seed plus une liste d'actions doit rejouer
un run à l'identique ». Rien ne pouvait le vérifier, faute d'un objet qui tienne un run
entier. Deux runs sur le même seed, la même suite de gestes sur deux journées, comparaison
de la réserve, des hauteurs, de l'avancement, de l'XP et de la main. Un second cas tient le
revers : un seed différent ne rejoue pas la même partie — sans lui, le premier passerait
tout aussi bien sur un run parfaitement déterministe et vide.

C'est ce qui a décidé que **`RunState` porte son équilibrage** au lieu de le recevoir à
chaque appel, à l'inverse de tout le reste du domaine : un run ne rejoue que s'il rejoue sur
les chiffres avec lesquels il s'est ouvert. Même geste que `Deck`, qui garde son catalogue.

### Ce que la capture a montré

Deux journées jouées en ligne de commande : un chantier ouvert et **payé**, avancé de deux
crans et achevé, une cellule terrassée de +1, six postes tenus, aucun oisif, réserve à
39/100. Première capture du projet où le contrôle porte sur un *enchaînement* et non sur une
image — le rapport imprimé est la seule preuve que la bourse a été débitée. Elle a aussi
confirmé par sonde que le bâtiment au centre n'était pas le Cœur : celui-ci est en (15, 14),
premier emplacement 2×2 plat depuis le centre, **achevé d'office** parce que son
`build_actions` vaut 0 — ce que 4.1 annonçait à `C4` sans avoir pu le vérifier.

**Report notable** : l'équilibrage des ressources devient le premier chantier ouvert. Deux
phases qui résolvent, c'est **deux récoltes par jour pour un seul upkeep** — l'économie est
nettement plus généreuse qu'à `E1b`, qui mesurait un soir par jour. Sciemment laissé en
l'état, le verdict du harnais Économie restant calibré sur l'ancien rythme.

---

## 2026-08-25 — `D2` : les deux gestes, la clé de l'affectation, et un bug trouvé en image

**État : terminé.** Cinq commits sur `feat/d1-deck`, à la suite de `D1`. **467 tests verts
contre 396.** Contrats : `PlayedAction`, `ActionPlan`, `TargetResult`, `Assignment`
**rekeyée** sur l'action posée, `CitySnapshot` gagne son index par cellule. Domaine :
`ActionBoard`, `ActionTargeting`, `ProductionResolver` réécrit. `ActionBalance`.
`TargetHighlight`, `ActionMarker`, `HandView` — premier dossier `src/adapters/deck/`.
`deck_harness.gd` réécrit : plus un rapport, une scène.

### La décision qui porte le jalon : la carte n'est pas l'ouvrier

`DESIGN.md` 8 annonçait que jouer une carte produirait un `Assignment` — donc un geste
**atomique**. `D1` avait repéré en conversation que c'était faux et avait laissé la question
ouverte exprès.

Si une carte valait un ouvrier, cartes et ouvriers se **doubleraient** : chaque action en
consommant une de chaque, la contrainte réelle deviendrait `min(cartes, ouvriers)`, ce que
3.4 refuse en toutes lettres — « deux contraintes qui se croisent, et non deux ressources
qui se doublent ». Le flux compte donc deux gestes : on joue la carte **sur une cible**, ce
qui pose une action ; puis on y affecte **des** ouvriers. Cet objet manquant porte trois
choses figées à la pose : son identité, sa cible canonique, et sa **capacité**.

**À quoi un ouvrier s'affecte-t-il ?** Garder la **cellule** comme clé ne changeait aucun
contrat et laissait le résolveur intact — mais tranchait « une case fait une chose par
phase » par une structure de données, alors que `DESIGN.md` ne le dit nulle part.
*Terraformer* et *Récolter* peuvent viser la même case nue, *Récolter* et *Chasser* la même
forêt. L'**identité propre** a été retenue : elle coûte la rekeyage et la réécriture du
résolveur, et c'était le dernier moment où ça se payait peu. Elle rend les doublets
*représentables* ; les interdire reste possible plus tard comme règle explicite du
validateur, et l'inverse n'aurait pas été vrai.

### Ce que la rekeyage a rendu vrai

`DESIGN.md` 2 dit depuis le début que « la production n'est plus une étape passive qui
balaye les bâtiments : c'est le résultat des actions que le joueur a posées ». **Ce n'était
pas vrai.** Le résolveur de `E1` balayait les ancres de l'affectation et servait le
rendement du bâtiment qu'il y trouvait, sans qu'aucune carte n'ait eu à être jouée. Il part
maintenant du plan : rien ne produit qui n'y figure.

Le contrat de 3.3 gagne deux entrées. L'`ActionPlan` est le pilote ; le `TerrainQuery` vient
avec la seconde lecture de 3.5 — une action à cru rend ce que le **tag de sa cellule**
dicte, donc l'Économie doit voir le relief. Elle voit le contrat, jamais la grille.

**Le témoin que la réécriture n'a rien cassé** : les 396 tests sont restés verts, et les
harnais Économie et Effectifs impriment **exactement** ce qu'ils imprimaient avant — mêmes
récoltes, mêmes famines, mêmes paliers d'XP, soir par soir. Le pilote a changé, pas
l'arithmétique.

### Décisions

**Le résolveur n'écrit aucun nom de carte.** Les deux lectures de 3.5 posent chacune leur
question à `data/balance/` : « cette carte tient-elle un poste ? » dans un bâtiment, « cette
carte tire-t-elle quelque chose de ce tag ? » à cru. *Construire* et *Terraformer* répondent
non aux deux et sortent de la production **structurellement**, sans être nommés, de sorte
qu'un cinquième verbe entre sans qu'on ait à venir l'exclure d'une liste.

**Les noms de verbes vivent en un seul endroit**, `ActionTargeting` — 4.2 pose qu'une nature
d'action est du code. Un cas de test charge `data/cards/` et exige que toute carte du pool
des actions y ait une règle, de sorte qu'une cinquième entrée sans règle de ciblage fasse
tomber la suite au lieu de se poser nulle part.

**`CitySnapshot` a reçu son index par cellule**, dont son docstring disait qu'on n'ouvrirait
pas la porte tant que personne ne la pousserait : on désigne un coin de la ferme, on vise la
ferme. Il ne coûte **aucune entrée de plus** au contrat. **La cible est canonicalisée par le
ciblage** et non par l'adapter — le faire dans la vue aurait laissé passer deux actions qui
se croient différentes.

**`WorkLine` n'a pas bougé de forme** : son `Vector2i` cesse d'être « l'ancre du bâtiment »
pour devenir « la cellule du poste », et l'accesseur est renommé `cell()` — `anchor()` aurait
menti sur toute action à cru.

**Le résolveur fait deux passes sur le plan** — lignes de travail, puis rendements. Une ligne
de travail ne porte que sa cellule, et deux actions peuvent viser la même : repartir des
lignes obligerait à retrouver de quelle action chacune vient. Les deux passes posent les
mêmes questions aux mêmes fonctions pures sur les mêmes entrées.

**La capacité voyage figée sur l'action** — la relire depuis la ville au moment de résoudre
aurait rouvert la porte à ce que l'écran promette trois postes et que le soir n'en serve
que deux.

### Trois défauts, trois contrôles différents

**Les tests.** Sur un bâtiment, le résolveur ne posait qu'une question — « ce bâtiment
produit-il ? » — si bien que **toute** action posée sur une ferme achevée en tirait une
récolte, *Construire* comprise. Le ciblage l'interdit aujourd'hui, mais faire reposer la
justesse du soir sur une règle écrite dans un autre système est la dette que `I1` aurait
payée. `ActionBalance` nomme désormais les cartes qui tiennent un poste. Vérifié de la seule
façon qui vaille : retirer la garde, regarder le test tomber, remettre la garde.

**La capture.** Le harnais avait posé deux *Récolter* sur une même cabane à deux postes et y
avait mis trois ouvriers. Une carte ouvrait les postes de sa cible **à chaque fois qu'elle
était jouée** : la jouer deux fois doublait le bâtiment, et la carte cessait d'être une
permission pour devenir un multiplicateur. Ce bug ne se lisait ni dans l'image ni dans les
tests, mais dans la **table des actions posées** que la capture imprime — premier jalon où
ce que le harnais dit est un défaut de règle et non un chiffre d'équilibrage.

**Le clavier, et il fallait un humain.** Les touches 4 et 5 « ne sélectionnaient pas ».
Elles étaient parfaitement liées : la sélection portait sur l'**identifiant** de la carte
tenue, et une main tient couramment deux exemplaires du même nom — les presser retombait sur
la carte déjà tenue, ce que le code interprétait comme « on la repose ». La sélection porte
désormais sur le **rang** ; le docstring d'origine défendait l'identifiant en disant qu'un
rang ne survivrait pas à une repioche, et la robustesse annoncée n'existait pas. Les cartes
se prennent aussi au **clic** — une main peut tenir plus de neuf cartes.

### Ce que le harnais est devenu

Le rapport texte de `D1` a disparu, remplacé par la scène — le geste exact que `C2` a fait
sur `C1`. C'est le seul harnais où une **phase entière** se joue, et le premier à composer
**trois** systèmes du domaine.

Deux corrections sont venues de deux captures successives, et aucune n'est un bug de code.
La première ne montrait **rien** : les bâtiments s'étaient posés au coin de la carte, là où
le rapport texte les recouvre, et la carte jouée était la seule de son nom en main, si bien
qu'aucune cible ne restait allumée. La seconde résolvait trois soirs qui ne produisaient
rien, parce que le script de capture ne posait qu'un *Construire*. **Un contrôle par l'image
qui ne montre pas ce que le jalon ajoute ne contrôle rien.**

**Constat de contenu, consigné en 4.2** : `data/terrain/` ne contient aucun filon, alors que
3.1 le liste avec le tag `ore`. La règle de récolte à cru le nomme et n'a donc pas de cible
sur une carte réelle ; le minerai ne s'obtient qu'à la mine.

---

## 2026-08-25 — `D1` : trois pools, un mélange qui ne triche pas, et ce qu'un draft coûte

**État : terminé.** Cinq commits sur `feat/d1-deck`, **396 tests verts contre 324**.
`CardData` et `DeckBalance` ; **seize `.tres`** dans `data/cards/` ; `CardCatalogue`,
`CardShuffle`, `Deck`, `Hand`, `DraftPool` ; sept suites, 72 cas neufs ; `deck_harness.gd`.

### Deux arbitrages avant d'écrire

**La colonne « Débloque » de 4.1 est reportée**, alors que ce même tableau l'annonçait pour
`D1`. Les trois actions qu'elle concerne portent `MVP : non` en 4.2, et leurs systèmes sont
`X1`, `X2`, `X3` : en les laissant hors du catalogue, il **n'y a rien à débloquer** — le
champ n'aurait aucun lecteur, et la requête serait une frontière que personne ne franchit,
motif exact qui a sorti `CombatForce` de `W1`. Prix du report chiffré avant d'être pris : un
champ, trois `.tres`, une quatrième lecture de `CitySnapshot.completed()`.

**Le pool est un `StringName` et non un `enum`**, contre la convention générale. Un `enum`
non renseigné vaut 0, donc `&"action"` **en silence** : la doctrine du zéro perdrait sa
prise sur le seul champ qui décide de tout le classement d'une carte, alors qu'un `&""` se
détecte. Et un pool n'est pas un état en mémoire, c'est un identifiant écrit dans `data/`,
où la convention est déjà le `StringName`. L'ensemble reste fermé : `CardData.POOLS` le
tient, et `missing_fields()` refuse tout ce qui n'y est pas.

### La décision qui porte le jalon : le Deck ne décide de rien

**Il ne juge aucune jouabilité.** 3.5 dit qu'un jeu de carte est une *intention* que le
système concerné accepte ou refuse. Le Deck ne connaît ni la grille, ni la bourse, ni le
placement : il n'y a pas de verbe `play()`, `discard()` suffit et ne ment pas.

**Il ne décide d'aucun moment.** Les trois tailles de main vivent dans `data/balance/`, et
*quand* on pioche appartient à la journée, donc à `I1`. `discard_hand()` est une **capacité
et non une politique**. Ce second refus est ce qui laisse entier l'`OUVERT` de 3.5 — le sort
de la main non jouée : un `Deck` qui aurait pris l'habitude de défausser tout seul en fin de
phase aurait tranché la question sans que personne ne le décide, et la trancher dans du
GDScript l'aurait rendue coûteuse à retester.

### Ce que le harnais a trouvé, et ce qu'il a fallu jeter

Un chiffre juste, un faux, un inutile — **et le tri entre les deux derniers est tout le
travail.**

**Le faux.** La première version mesurait le cycle de la pioche en divisant les phases
jouées par le nombre de remélanges, et sortait 2,7 là où le régime établi est 2 : les
premières phases d'un run vident une pioche pleine sans jamais la recycler. **Un chiffre qui
dépend de l'endroit où l'on commence à compter ne mesure rien.**

**L'inutile.** Une fois juste, il s'est révélé **muet** : il vaut deux phases que le pool en
tienne dix ou quatorze, parce qu'une pioche qu'on vient de recharger garde toujours de quoi
faire exactement une main de plus. Il dit quelque chose de vrai sur les piles et rien sur le
jeu. Remplacé par la question que le design pose vraiment : au bout de combien de phases une
main **revoit** la carte qu'on attend.

**Le juste, et il répond à une question de design.** Sur deux cents seeds, **7,8 % des
phases n'offrent aucune carte *Construire***. Et surtout : après quatre drafts pris au
hasard dans l'offre, ce chiffre monte à **11,2 %** et le délai de retour de 1,07 à 1,11
phase. **Grossir son deck le rend moins fiable.** Classique du deckbuilder, mais mesuré sur
les chiffres réels de `data/` — et il dit ce que `I3` devra équilibrer : si drafter est une
récompense, il faudra que ce qu'on gagne compense ce que la dilution coûte.

Premier harnais où c'est un **échantillon** qui parle et non un run : une fréquence lue sur
un seul seed n'aurait rien valu.

### Ce que la commande 2 a rattrapé, et que la commande 1 n'a pas vu

`CardShuffle` ne compilait pas — `var held := mixed[index]` sur un `Array` typé ne s'infère
pas. Le boot est passé **sans un mot** : rien à ce moment-là ne chargeait le fichier, et son
code de sortie valait 0. C'est exactement le piège que `CLAUDE.md` documente, et la première
fois qu'il se manifeste pour de vrai. **Trois commandes, pas une.**

### Décisions

**`CardShuffle` a son propre fichier, pour une seule fonction.** `Array.shuffle()` tire sur
le RNG global de Godot et non sur celui du run : un deck mélangé par lui rendrait un même
seed non rejouable, sans rien signaler. Le piège devait être évité à deux endroits, et une
règle qu'on recopie est une règle qu'on oublie à la troisième occurrence. Le cas de test
reseede le générateur global entre deux mélanges et exige le même ordre — le seul cas qu'un
`Array.shuffle()` échouerait, donc le seul qui protège vraiment.

**Le RNG est un argument, jamais un membre.** Un Deck qui garderait le sien serait un second
flux à seeder, donc un second endroit où un run cesserait d'être rejouable. Choix inverse de
`TerrainGen`, qui prend un seed et le sale, et la différence se justifie : une génération est
un tirage isolé qu'on ne veut pas corréler, une pioche est un événement du run.

**`create()` ne mélange pas** — composer un deck reste sans aléatoire, donc assertable sans
rng. **Une carte draftée entre par la défausse** : elle ne doit pas s'intercaler dans une
pioche entamée et passer devant des cartes qui attendaient depuis deux phases. **`remove()`
cherche dans un ordre fixé** — pioche, défausse, main : arbitraire, mais un retrait qui
dépendrait de l'endroit où la carte se trouve ferait diverger deux runs partis du même seed.

**Les tailles de main sont une table et non trois champs plats** : c'est ce qui rend le zéro
du pool des powers écrivable *et* un pool oublié détectable — la présence de la clé vaut
déclaration. Même geste que le bloc nullable de `E1b`, appliqué à un dictionnaire.

**`list_card_ids()` trie, et ça compte plus ici qu'ailleurs** : c'est dans cet ordre que le
catalogue reçoit les cartes, et cet ordre que les offres de draft mélangent — un catalogue
chargé dans l'ordre d'un `DirAccess` tirerait différemment d'une machine à l'autre sur le
même seed.

**Une carte de bâtiment nomme son bâtiment**, même quand c'est le même mot : deux cartes qui
poseraient la même ferme à des conditions différentes sont exactement ce qu'un draft de
méta-progression fera. `missing_fields()` réclame le lien **dans les deux sens**.

---

## 2026-08-25 — `C4` : le chantier, ses deux lectures, et un contrôle par l'image

**État : terminé.** Cinq commits sur `feat/c4-construction-sites`, **324 tests verts contre
304**. `BuildingData.build_actions` et la colonne **Chantier** de 4.1 écrite dans les treize
`.tres` ; `BuildingSnapshot.progress()/is_complete()/remaining()`, `CitySnapshot.completed()` ;
l'avancement sur `PlacedBuilding`, `CityState.advance()` ; les trois endroits qui devaient
cesser de compter un inachevé ; le rendu distinct.

### Deux arbitrages avant d'écrire

**Le « — » du Cœur est un zéro**, et non un champ réclamé au boot. L'argument qui tranche
n'est pas le confort mais la **cohérence de ligne** : ce même Cœur porte déjà « posé au
départ » dans la colonne Coût, que `data/` représente par un coût vide. Le bénéfice se voit à
ce qui n'a pas été écrit — `is_complete()` étant `progress >= build_actions`, le Cœur est
achevé à la pose et **aucun chemin particulier n'existe** pour lui. Le prix est réel et a été
payé : un `build_actions` oublié vaut 0 et fait sauter le chantier en silence, d'où un cas de
test qui charge tout `data/` et exige qu'au moins un bâtiment en déclare un. Filet à mailles
larges, et dit comme tel.

**Les harnais Économie et Effectifs achèvent à la pose.** Sans intervention ils devenaient
muets, faute de carte *Construire* à jeter sur leurs bâtiments. L'alternative — un cran par
soir — est la version **intéressante** et répondrait à une vraie question, mais elle a été
écartée pour une raison de méthode : les chiffres d'un harnais sont des **repères écrits au
journal**, et les déplacer depuis un jalon dont le sujet est la Construction aurait rendu la
prochaine dérive inattribuable. Vérifié après coup plutôt que supposé — aucun repère de `E1b`
ni de `W1` n'a bougé. Elle a un meilleur moment, et il est nommé : `I1`.

### La décision qui porte le jalon : deux lectures plutôt qu'un filtre recopié

Trois consommateurs devaient cesser de compter un bâtiment inachevé — postes de production,
réserve des entrepôts, places des habitations. Et un quatrième, le Combat, doit au contraire
les **voir** : 3.2 veut qu'un chantier détruit la veille de la vague soit une vraie perte.

Trois clauses `if not is_complete()` recopiées auraient marché, et auraient été oubliées à la
quatrième. Le pire est que **l'oubli aurait été silencieux** : un entrepôt en chantier qui
relève quand même la réserve ne casse rien, il ment — et un mensonge de ce genre ne se
découvre qu'en équilibrage, six jalons plus loin. `CitySnapshot` porte donc `completed()` à
côté de `buildings()` : une implémentation du côté du DTO qui sait déjà tout, et deux
questions qui ont chacune leur consommateur.

### Ce que la capture a trouvé, et ce qu'elle a innocenté

**Un bug à moi.** Le premier étalement donnait à chaque bâtiment un nombre de crans égal à
son rang dans le catalogue, calqué sur ce que `C2` fait des orientations. Sauf que les
orientations bouclent à 4 et que les chantiers plafonnent à **3** : tout ce qui vient après
le quatrième rang était achevé d'office, et la ville d'ouverture ne montrait que **2
chantiers sur 13**. Corrigé en prenant les crans modulo ce que chaque bâtiment réclame — 9
sur 13. **Aucun test n'aurait signalé ça : le code était correct, c'est la mise en scène qui
ne montrait rien.**

**Un bug qui n'est pas à moi.** La même capture montre une **trame en damier** sur le dessus
des boîtes. La tentation était de l'attribuer aux boîtes minces que `C4` introduit. Contrôle
fait plutôt que supposé : une capture avec `SITE_BASE_RATIO` forcé à `1.0` — donc au rendu
exact de `C2` — **montre exactement la même trame**. C'est un défaut de filtrage d'ombre de
`DevWorld`, que `C4` a seulement rendu plus visible. Consigné, pas corrigé.

**Le stratagème mérite d'être retenu : neutraliser son propre paramètre et recapturer**
répond en trente secondes à « est-ce moi ? », là où un `git stash` a fait perdre deux minutes
et failli emporter le travail — la remise au propre rebasculait `HARNESS` sur `&"workforce"`,
un harnais sans `--shot` ni `quit()`, qui a bloqué jusqu'au délai d'expiration.

### Décisions

**L'avancement vit sur `PlacedBuilding`, pas dans un troisième index.** Un avancement rangé
à côté des deux index de `CityState` serait un état séparé du bâtiment qu'il décrit, à
resynchroniser à chaque pose et à chaque retrait. Le docstring qui promettait un
`PlacedBuilding` immuable est corrigé plutôt que contourné : **son placement est figé, son
avancement ne l'est pas**, ce que 3.2 demande en disant qu'un chantier est un *état*.

**`advance()` rend un `bool`, pas un DTO `{ok, reason}`** — profil de `remove()` et non de
`place()`. La convention réserve le DTO aux erreurs récupérables, et un refus de placement en
est une vraie ; ici les deux seuls refus possibles se posent avant l'appel.

**`advance()` n'est pas un verrou, et le docstring le dit.** `place()` est une porte
exclusive, tenue par la structure ; `advance()` ne peut pas l'être — le renderer tient une
liste de `PlacedBuilding` depuis `C2`. Écrire « porte documentée » plutôt que « seule porte »
coûte une phrase et évite qu'on croie à une garantie qui n'existe pas.

**L'achèvement se teste dans `_work_lines()`, avant le bloc de production** — même endroit
unique que `E1b` avait choisi pour `produces()`. L'ordre des deux clauses n'est pas
indifférent : un ouvrier envoyé sur une ferme en chantier chôme parce qu'elle n'est pas
finie, pas parce qu'elle ne produirait pas. La distinction se lira le jour où le rapport dira
pourquoi.

**Hauteur et couleur sont pilotées par le même nombre** — réglés séparément, les deux
signaux auraient fini par se contredire (une boîte presque haute encore grise). Teinte de
fondation et plancher de hauteur sont des constantes d'adapter et non de `data/` : ce que
`data/` décide reste ce qu'un bâtiment **fini** vaut. **Le plancher est non nul**, et c'est
le seul des trois chiffres qui compte : à zéro, un chantier fraîchement posé serait invisible
et on ne verrait pas qu'on vient de payer une case.

**Pas de drapeau `--shot-build`** — l'étalement des avancements met déjà tout sous une seule
capture, et un drapeau qui ne montrerait rien de neuf est une option de plus à maintenir.

**Le nom `build_actions`, et pas `turns`** : `turns` désigne déjà les quarts de tour d'une
orientation. La collision aurait été silencieuse et catastrophique.

**Question de design neuve, inscrite en `OUVERT` dans 3.2** : quelle piste l'action
*Construire* crédite-t-elle ? Aucune des trois familles ne la couvre. Trois issues — une
quatrième famille, un rattachement à l'Artisanat, ou de l'XP de niveau seule.

---

## 2026-08-25 — `W1` : l'ouvrier, ses deux axes, et la boucle refermée sur `E1`

**État : terminé.** Six commits sur `feat/w1-workforce`, **304 tests verts contre 247**.
`domain/workforce/` — `skill_track.gd`, `worker.gd`, `roster.gd`, `skill_resolver.gd`,
`skill_gain.gd`, `progress_report.gd` ; `WorkforceBalance` (cinquième bloc) ;
`BuildingData.roster_places` ; quatre suites ; `workforce_harness.gd`.

**`contracts/` n'a pas bougé d'une ligne de code**, et c'est le résultat que le jalon visait.
`E1` avait été écrit en pensant à ici : `LaborUnit` portait déjà un multiplicateur par
famille, `WorkLine` portait déjà la famille à créditer. `W1` était annoncé comme « le dernier
moment où `LaborForce` peut bouger sans douleur » — elle n'a pas eu à bouger.

### Quatre arbitrages, dont un qui a changé le design

**`CombatForce` sort de `W1` pour `F1`**, contre ce que `DESIGN.md` 8 annonçait. Son contenu
est décidé par le format de combat, `OUVERT` en 3.6 : écrite aujourd'hui, elle serait ou bien
un clone strict de `LaborForce` qui ne prouve rien, ou bien une devinette sur des PV et de
l'équipement. Et contrairement à `skill_family` à `E1`, la repousser ne coûte rien.

Ce que `W1` garantit à la place est plus solide qu'un second DTO : **`Roster` est le seul
propriétaire des `Worker`**, et rien hors de `domain/workforce/` n'en voit un. Le vivier
unique n'est plus une discipline d'écriture, c'est une conséquence de la structure.

**La progression se fait par paliers**, pas par courbe continue. Un passage de niveau est un
événement qu'on annonce, et un ouvrier qu'on peut appeler « Récolte 3 » existe dans une
conversation comme un multiplicateur à 1,37 n'existera jamais. Une progression douce reste
exprimable — c'est beaucoup de petits paliers.

**Un second axe est entré, et il vient de l'humain** : à côté de la piste par famille, un
**niveau d'ouvrier** alimenté par toute source d'XP, qui ne donne aucun multiplicateur et
sert à distinguer un vétéran d'un bleu. `DESIGN.md` ne le portait pas, donc le design est
passé **en premier**, comme les empreintes libres à `C1` et la rotation à `C2`. Il est entré
coupé en deux : l'accumulateur et les paliers sont écrits, ce qu'un palier **offre** devient
`X5`. Une raison de ne pas tout repousser : « XP de toute source » veut dire que `F1` et les
événements devront trouver le compteur déjà là, sinon chacun inventera où loger son XP.

**L'absence de 3.9 entre maintenant**, minimale : un état de présence, et `to_labor()` qui ne
projette que les présents. Coût réel : un booléen, un filtre, trois cas de test. C'est la
contrainte qu'on ne rattrape pas après coup.

### La règle qui relie les deux axes

**Toute XP compte deux fois** — une fois pour la piste concernée, une fois pour le niveau.
Un seul chiffre de gain les alimente tous les deux ; deux montants distincts auraient donné
un levier de plus à régler par source d'XP, et deux chiffres à tenir cohérents pour rien.

Ce qui rend la règle tenable est un choix d'encapsulation : **une `SkillTrack` ne sort jamais
de son `Worker`.** La rendre laisserait un appelant la créditer seule, et l'invariant
redeviendrait une consigne.

**Le niveau est un compteur réel et non la somme des pistes.** Aujourd'hui les deux
coïncident, puisque le travail est la seule source d'XP écrite ; ils divergeront à la
première XP qui n'appartient à aucune famille — celle d'un événement —, et le dériver
maintenant obligerait alors à inventer une famille fourre-tout pour l'y loger.

### Le cas de test qui porte le jalon

Le premier de tout le projet à faire tourner **deux systèmes du domaine ensemble** :
résoudre un soir, distribuer l'XP, reprojeter, résoudre le suivant — et la cabane rend 2 puis
3. `E1` avait écrit un journal de travail que personne ne lisait ; c'est ce cas qui prouve
qu'il sert. Son jumeau compte autant : la même séquence **sans** la distribution rend 2 deux
fois — sans lui, le premier passerait tout aussi bien si la récolte montait toute seule.

Deux autres tiennent un terrain que rien d'autre ne couvre : **spécialiser doit soulever une
famille et laisser les autres à plat**, que 3.4 promet depuis `E1` sans que rien ne le
vérifie ; et **`to_labor()` doit laisser les absents**, la seule ligne qui paie pour 3.9.

### Le constat que le harnais rapporte

Premier harnais à composer deux systèmes — le rôle que `RunOrchestrator` reprendra à `I1`, et
il tient en trois lignes. Sa réponse n'est pas celle qu'on attendait : **la récolte reste
plate dix-neuf soirs alors que toutes les pistes montent.** Le rendement est tronqué **par
ouvrier et par soir** — une décision de `E1` —, or sur des promesses à 2 ou 3, un cran de
0,15 est entièrement avalé tant que le multiplicateur n'a pas franchi l'entier suivant. La
nourriture ne bouge qu'au soir 20 (×1,45), le bois et la pierre qu'au soir 26 (×1,60).

**Le constat est structurel, pas un mauvais réglage** : aucune valeur du cran ne le supprime.
Seuls des rendements plus gros, ou une troncature déplacée — accumuler en flottant et
n'arrondir qu'une fois par ressource —, y changeraient quelque chose. Les deux sont des
questions de `I3`, et la seconde touche `ProductionResolver`.

Il chiffre aussi ce que l'absence coûte : Elric part au soir 12, la carrière tombe de 4
pierre à 2, il revient six soirs plus tard avec une piste de retard sur ses camarades — et il
n'a rien mangé pendant ce temps.

### Décisions

**`SkillTrack.level_at()` est statique, publique, et sert aux deux axes** — les paliers
montent de la même façon des deux côtés, seuls les réglages diffèrent. Une progression qui
accélérerait sur un axe et pas sur l'autre serait une décision d'équilibrage déguisée en
décision de code.

**`SkillResolver` mute le `Roster` et rend un rapport** — profil identique à
`ProductionResolver` qui mute le `Ledger`, et pour la même raison. **`ProgressReport` reste
dans `domain/workforce/`**, comme `PickResult` dans `domain/terrain/`.

**Chaque ligne de travail est créditée séparément**, sans regroupement par ouvrier :
aujourd'hui les deux reviennent au même, mais rien n'en dépend et deux lignes du même ouvrier
cumuleraient correctement. **Un ouvrier nommé au journal mais absent du roster est sauté sans
un mot** — miroir exact de `ProductionResolver._work_lines()` : une affectation peut avoir
survécu à celui qui la portait, et un mort ne progresse pas.

**`roster_places` est un champ plat sur `BuildingData`**, à côté de `storage_bonus` : c'est
un nombre qui relève un plafond global, pas une nature de bâtiment. La doctrine du zéro ne
s'y applique pas non plus — douze bâtiments sur treize ne logent personne.

**Le roster ne consulte jamais son plafond.** `add()` n'oppose aucun refus : c'est la couche
qui orchestre la journée qui pose les deux questions à la suite, comme elle enchaîne
« payable » et « posable ». Un cas de test le dit à voix haute, pour que personne ne
« répare » `add()` plus tard.

**Le harnais lit la famille dans `data/` au lieu de l'écrire** — un `&"harvest"` en dur y
survivrait à un renommage du catalogue sans que rien ne le signale. Constat au passage : les
quatre producteurs de `data/buildings/` emploient tous la même famille, donc la spécialisation
*entre* familles n'est pas encore observable sur le contenu réel.

**Les prénoms sont codés en dur dans le harnais** — un catalogue de prénoms dans `data/` est
du contenu, donc `I3`.

**La duplication des rapports texte n'a pas été traitée** : `_make_label()` existe maintenant
en quatre exemplaires. La mettre en commun est une passe à part entière, et ce n'était pas le
sujet de `W1`. Consigné pour que ça ne passe pas pour un oubli.

---

## 2026-08-25 — `E1b` : le bloc de production, le minerai, et les douze bâtiments

**État : terminé.** Six commits sur `feat/e1b-production-block`, **247 tests verts contre
241**. `production_block.gd` — la classe neuve et le seul vrai sujet du jalon ;
`BuildingData` perd `slots`, `yield_per_slot` et `skill_family`, gagne `production` et
`produces()` ; `data/commodities/ore.tres` et **sept bâtiments neufs**, les six anciens
réécrits ; la file d'attente de construction du harnais. `DESIGN.md` 4.1.

### Ce que le bloc achète, et ça se lit à ce qui a disparu

`E1` avait consigné une entorse assumée : « la doctrine du zéro ne s'applique pas au bloc
économie ». À plat sur `BuildingData`, `slots = 0` était une valeur parfaitement légitime, et
un champ non renseigné y cessait d'être détectable — il avait fallu le remplacer par un
contrôle de cohérence **entre** les trois champs.

L'entorse est levée, et sans avoir été traitée. Un bloc qui existe produit : ses trois champs
se réclament maintenant sans condition. Le gain ne se voit pas dans le code ajouté mais dans
celui qui a disparu — `_economy_fields()` a perdu ses trois clauses croisées et ne fait plus
que déléguer sous un préfixe. **Le cas de test qui porte le jalon est celui des slots à
zéro**, précisément parce que `E1` ne pouvait pas l'écrire.

### Trois arbitrages, dont un qui change le contenu

**Les cinq bâtiments à slot muet entrent sans bloc.** Tour de guet, caserne, marché, atelier
et camp d'exploration portent « 1 slot » dans 4.1 et aucun ne produit de ressource : leur
poste héberge une défense (`F1`), un échange (`I3`) ou une action débloquée. Leur écrire un
`slots = 1` que rien ne lit aurait fait mentir la data **et** détruit la garantie qu'on venait
d'acheter. C'est le cas que 3.3 anticipait en écrivant « le jour où un bâtiment produit
autrement, le bloc devient une classe de base » : ce jour n'est pas aujourd'hui, parce que ces
slots ne produisent pas autrement — **ils ne produisent pas**.

**La palissade entre au tableau 4.1.** Elle existait dans `data/` depuis `C2` sans y figurer,
ce qui faisait diverger le design de son contenu. Elle est la seule empreinte non
rectangulaire du projet, donc le seul cas qui exerce vraiment la rotation du fantôme et le
validateur ; l'atelier lui donne depuis ce jalon un second L.

**Les colonnes Chantier, Déf., PV et Débloque restent dehors** — un champ arrive avec le
système qui le lit. Conséquence à consigner pour ne pas la relire comme un oubli :
**l'habitation entre en coquille vide**, sans rien que son coût, et c'est correct.

### Le harnais a gagné une file, et il a répondu autre chose

La mine coûte 25 bois et 10 pierre, qu'aucune bourse d'ouverture n'a : l'ajouter à la liste
de construction l'aurait fait refuser au premier jour, et le minerai serait entré au
catalogue sans qu'aucun soir n'en produise. Ce qu'un bâtiment impayable devient est donc
devenu une question, et la réponse est une **file** : ce que la bourse refuse y entre, et le
harnais en retente la tête, une par soir. **Elle ne se réordonne jamais** — un bâtiment cher
doublé par un moins cher derrière lui ferait répondre le harnais à une question qu'on ne lui
pose pas. L'affectation se refait à chaque soir en conséquence.

Il dit maintenant ce qu'il ne pouvait pas dire : **la mine se paie au soir 8, la seconde
ferme au soir 10, et c'est cette ferme qui met fin à la famine.** La première famine reste au
soir 6, mais la réserve finit à **189/200 au vingtième soir contre 160 à `E1`** : le plafond
commun est beaucoup plus près de mordre qu'il ne le paraissait.

### Décisions

**Le bloc s'écrit en `sub_resource`, pas en fichier séparé** — un bloc appartient à son
bâtiment et n'a aucune identité au catalogue ; `TerrainDecor` sur un terrain est le même
motif. Un cas de test charge tous les `.tres` et exige qu'au moins un en porte un typé —
sans cette dernière exigence, il passerait par vacuité le jour où le format se casserait
partout.

**`produces()` plutôt qu'un `production != null` recopié** : la nullité est la façon dont
`E1b` dit « ne produit pas », et le jour où le bloc devient une classe de base, la question
restera posée au même endroit.

**L'existence du bloc se teste dans `_work_lines()` et nulle part ailleurs** — toute ligne de
travail en sort, donc tout ce qui en consomme une sait que le bâtiment produit.

**Le contrôle croisé nomme le chemin complet** : `ressource inconnue « oer » dans
data/buildings/mine.tres → production.yield_per_slot`. Sans le préfixe, un `yield_per_slot`
nu ne dirait plus d'où il vient le jour où `BuildingData` portera plusieurs blocs.

**Le terrain `filon` n'est pas écrit.** `TerrainGenBalance` porte cinq emplacements en dur ;
en ajouter un est du travail Terrain, et une `.tres` que rien ne génère serait de la data
morte. La mine produit du minerai sans en avoir besoin — aucun prérequis de tag n'existe au
placement depuis `C1`. Ça redeviendra nécessaire à `D2`, quand *Récolter* à cru voudra une
case `ore`.
---

## 2026-08-24 — `E1` : la réserve, la résolution du soir, l'upkeep et la famine

**État : terminé.** Sept commits sur `feat/e1-economy`, **241 tests verts**. Sept DTO
dans `contracts/` (`CitySnapshot`, `BuildingSnapshot`, `LaborForce`, `LaborUnit`,
`Assignment`, `WorkLine`, `ProductionReport`), `domain/economy/` (`Ledger`,
`ProductionResolver`), le bloc économie de `BuildingData`, `data/commodities/`, la ferme
et l'entrepôt. `DESIGN.md` 3.3 et 3.4.

*Accroc de procédure, réparé sans perte : la session s'est ouverte sans créer de branche
et le premier commit a atterri sur `feat/c2-placement-ghost`. **La branche se crée à
l'orientation, avant le premier commit.***

**La réserve est commune, pas par ressource** — la réponse de l'humain, à l'inverse de ma
recommandation. Cent unités partagées entre bois, pierre et nourriture : remplir sa
réserve de bois, c'est renoncer à stocker de la pierre. Le plafond force à choisir *quoi*
garder, et l'entrepôt devient un arbitrage plutôt qu'un relèvement de trois compteurs.

**Et ce choix a une conséquence que ni le plan ni la question ne voyaient : une récolte
qui déborde doit décider laquelle de ses ressources entre.** Premier arrivé premier servi
est un piège — l'ordre des clés vient de l'ordre de pose des bâtiments, donc deux villes
identiques bâties dans un ordre différent perdraient des choses différentes sans que rien
à l'écran ne l'explique (même famille d'erreur que les quatre passes du validateur à
`C1`). La règle retenue est **proportionnelle à ce que le dépôt apporte**, reste de
division aux plus grosses parts fractionnaires, identifiant tranchant à égalité. Le cas de
test qui compte dépose les mêmes montants dans deux ordres de clés opposés et exige le
même résultat. Le même écrêtage sert quand la capacité **baisse** — un entrepôt détruit
par une vague : une règle écrite une fois, utilisée deux fois.

**La `LaborForce` porte un multiplicateur par famille**, et `BuildingData` déclare la
sienne — l'argument décisif était le coût : un champ dans quatre `.tres` déjà ouverts,
contre les rouvrir tous à `W1` *et* changer un contrat.

**La famine se constate et ne se punit pas**, entrée comme `OUVERT` explicite en 3.3
plutôt que laissée non-dite.

**La doctrine du zéro ne s'applique pas au bloc économie.** 0 slot, un coût vide et une
réserve nulle sont trois valeurs légitimes de `DESIGN.md` 4 — la palissade n'a pas de
poste, la cabane de bûcheron est gratuite. Les réclamer refuserait de démarrer sur des
données correctes. Ce qui les remplace est un contrôle de **cohérence entre eux** : des
slots sans rendement, un rendement sans slot, un poste sans famille.

**Le résolveur mute le `Ledger`, et ce n'est pas une entorse** : le ledger est l'état
*interne* de l'Économie, comme `CityState` l'est de Construction. La ligne de contrat de
3.3 énumère les entrées **inter-systèmes**, ce qui est précisément pourquoi il n'y figure
pas.

**Le rapport rapporte, il ne punit pas, et ne calcule aucune XP** — combien vaut une
soirée de travail est un chiffre des Effectifs. Il porte un journal de travail (qui a tenu
quel poste, dans quelle famille), et `W1` en fera ce qu'il veut.

**L'upkeep tombe sur le roster entier, oisifs compris** : c'est ce qui rend un ouvrier non
affecté coûteux, donc le pool tendu, donc la tension de `DESIGN.md` 1 réelle plutôt que
déclarative. **Les oisifs se déduisent du roster moins ceux qui ont travaillé** — cette
soustraction couvre d'un coup les quatre façons de ne rien produire sans qu'aucune ait à
être énumérée, et un mort ne chôme pas.

**`CommodityData` et non `ResourceData`** : `Resource` est le type de base de Godot, et
`GameDatabase.get_resource()` est déjà l'accesseur générique. Le vocabulaire du jeu ne
bouge pas. **`upkeep_resource` est un champ d'équilibrage** — un `&"food"` en constante
aurait survécu à un renommage du catalogue sans que rien ne le signale.

**Deux bâtiments entrent, chacun pour une raison précise** (le motif de la palissade à
`C2`) : l'entrepôt est la seule chose qui relève la réserve commune, la ferme le seul
producteur de nourriture sans lequel le harnais meurt de faim au premier soir.

**Le harnais pose les deux questions à la suite** — payable, puis posable, puis on
dépense ; payer avant de savoir si ça tient sur le relief laisserait la ville plus pauvre
sans rien de bâti. Comme celui de `C1`, il **cherche** son cas : vingt soirs, et il dit
lequel a cassé le premier. Réponse : **famine au soir 6, réserve jamais pleine (160/200 au
vingtième)** — avec dix ouvriers pour six postes, c'est la nourriture qui étrangle bien
avant le plafond. Un défaut trouvé en lisant ce rapport et pas autrement : la réserve ne
prenait sa nouvelle capacité qu'à la résolution suivante, alors qu'un entrepôt doit compter
dès qu'il est bâti.

---

## 2026-08-24 — `C2` : fantôme de placement, pose et destruction

**État : terminé.** Dix commits sur `feat/c2-placement-ghost`, 160 tests verts.
`dev_world.gd` et `dev_shot.gd` (le plateau et le vocabulaire de capture, partagés),
`building_renderer.gd`, `placement_ghost.gd`, la palissade en L, et la **rotation** —
hors plan, entrée par la porte normale (`DESIGN.md` d'abord).

**Le domaine n'a pas bougé d'une ligne, et c'est le résultat.** `validate()` était déjà
pure et appelable à chaque image, `place()` et `remove()` attendaient leurs clics,
`PlacementResult` portait déjà les cellules et la hauteur auxquelles dessiner. `C1` avait
fait son travail ; `C2` n'a été que de la traduction.

**`TerrainMetrics` et `PickResult` ne montent pas dans `contracts/`** — question ouverte
depuis `T3`, réponse non : ce sont les *adapters* de Construction qui en ont besoin, et la
règle de dépendance contraint le domaine, pas eux.

**Le bug que seule l'image a montré — la carte chauve.** Quatrième jalon d'affilée.
`TerrainRenderer.create()` se peuple lui-même, `TerrainDecorRenderer.create_all()` non :
`DevWorld.create()` promettait dans son docstring un plateau « déjà peuplé » et mentait, ce
que le harnais Terrain masquait en enchaînant sur son propre `show_grid()`. Corrigé à la
source, pour qu'un seul chemin peuple le plateau.

**Une comparaison de captures mal lue, et l'outil qui en sort.** L'image « après » de
l'extraction de `DevWorld` semblait plus zoomée ; elle ne l'était pas — le viewport garde
la largeur de base mais sa **hauteur suit le rapport de la fenêtre**. D'où deux acquis : la
capture imprime une ligne `cadrage` (deux captures ne se comparent que si elle est
identique), et **`cmp` sur les deux `.png` tranche là où l'œil se trompe** — l'extraction
rendait des images identiques octet pour octet.

**Le soleil : un problème annoncé qui n'existe pas.** `CLAUDE.md` prévenait depuis `T3`
que les bâtiments, étant des boîtes, se heurteraient au piège du prisme noir. Ça n'est pas
arrivé : elles présentent à la lumière exactement les orientations des colonnes du terrain,
qui se lisent bien depuis `T2`. Le piège venait de la face *oblique* du prisme. `CLAUDE.md`
corrigé — **une prédiction fausse laissée dans un document permanent se paie plus tard**,
quand quelqu'un « répare » un problème inexistant.

**La palissade est entrée pour une raison précise** : rien de ce qui tournait ne dessinait
une empreinte non rectangulaire, or c'est la seule chose pour laquelle `C1` existait.

**Une boîte par cellule occupée, pas une par bâtiment** — sur un L, un volume unique
couvrirait le trou de l'enveloppe et mentirait sur la forme. **Le fantôme ne décide rien** :
il reçoit un `PlacementResult` déjà calculé et le colore. **La validation a lieu une fois
par image**, et le fantôme et la ligne de rapport lisent le même résultat — une couleur qui
contredirait sa légende serait un bug impossible à voir. **La hauteur du fantôme vient du
survol, pas du résultat** : un refus n'a pas de hauteur, et c'est précisément sur un refus
qu'il faut le voir. Il **dessine aussi les cellules hors carte**, ce qui explique le refus
mieux qu'une empreinte tronquée.

**La rotation : l'orientation appartient au placement, pas au bâtiment.** Rien dans `data/`
ne la décrit ; une même `BuildingData` se pose dans les quatre sens. **Elle se fait autour
de la cellule d'ancrage** — l'ancre est le décalage `(0, 0)`, invariante par rotation, donc
une empreinte pivotée contient toujours son ancre et pivote sous le curseur au lieu de
sauter à côté. Le résultat mérite d'être noté : **pas une ligne du validateur ne parle de
rotation**, ni les index de la ville, ni le renderer. Toute la fonctionnalité tient dans
`rotate_offset()` et un paramètre passé de main en main. Les deux cas de test qui portent
le plus posent la **même empreinte à la même ancre** et obtiennent un verdict différent une
fois tournée.

---

## 2026-08-24 — `C1` : la ville, les empreintes et les règles de placement

**État : terminé.** Six commits sur `feat/c1-placement`, 145 tests verts.
`PlacementResult` dans `contracts/`, `BuildingData`, `domain/city/` (`CityState`,
`PlacementValidator`, `PlacedBuilding`), trois `.tres` de bâtiments. `DESIGN.md` 3.1 et 3.2.

**Quatre points arbitrés avant d'écrire, dont deux qui ont simplifié le jalon :**

- **Le coût sort du placement.** `DESIGN.md` 3.2 se contredisait — ligne de contrat sans
  bourse, liste de validation avec « ressources suffisantes ». Même nature que la signature
  de `pick()` à `T3` : la contradiction était dans le document. « Ai-je les 15 bois ? » ne
  regarde pas la carte ; c'est la couche qui orchestre la journée qui enchaîne les deux.
- **Aucun prérequis dur d'adjacence** — elle reste entièrement la couche de rendement de
  `C3`, et le placement ne regarde jamais le voisinage.
- **`neighbourhood_at()` est écrite quand même**, à la demande de l'humain, sans aucun
  appelant avant `C3` — consigné dans son docstring, parce qu'écrire d'avance est ce que ce
  projet évite et **qu'une exception qui ne se dit pas devient une habitude**.
- **Toutes les cellules à la même hauteur, pour tous les bâtiments** : la règle est
  universelle, l'enum que je proposais disparaît.

**La planéité tranche un `OUVERT`, et `DESIGN.md` est passé en premier.** Exiger du plat
prend la piste *contrainte de construction* de 3.1 et élimine *purement décoratif* : le
relief décide d'où le village peut s'étendre, et c'est ce qui donne à un plateau sa valeur.
Le terrassement rejoint les pistes restantes — c'est cette règle qui le rendrait
intéressant. `DESIGN.md` est modifié dans le **premier** commit et non dans celui du
journal : `CLAUDE.md` interdit d'écrire une feature avant que le design la porte.

**Une empreinte est une liste de décalages, pas un rectangle.** Un L, un T ou une croix
s'écrivent, et un rectangle n'est qu'un cas particulier — pas deux façons de dire la même
chose, pas deux chemins à valider. Ce que j'avais annoncé comme coûteux ne l'était pas :
`TerrainQuery` expose déjà tout par cellule, donc la validation se fait avec le contrat
**tel quel**.

**`bounds_at()` ne valide jamais rien** — l'enveloppe d'un L couvre une cellule que le
bâtiment n'occupe pas. Deux cas de test l'épinglent des deux côtés : de l'eau dans ce trou
n'empêche pas la pose, et le trou reste posable ensuite. C'est ce couple qui prouve que les
formes libres sont réelles et pas décoratives.

**`CityState.place()` est la seule porte mutante, et elle valide avant de muter** : rien ne
peut entrer dans la ville sans être passé par le validateur — invariant tenu par la
structure, pas consigne à respecter. `validate()` reste pure et appelable seule, ce dont le
fantôme de `C2` a besoin.

**Quatre passes sur l'empreinte, pas une boucle.** En une seule, une empreinte à la fois
occupée et sous l'eau rendrait la raison de la cellule qui vient en premier dans le
`.tres` : la raison affichée dépendrait de l'ordre d'écriture de la data. L'ordre des
règles n'est pas libre non plus — les bornes d'abord, parce que `height_at()` lèverait sur
une empreinte qui déborde.

**`missing_fields()` contrôle l'empreinte au-delà de sa présence** (ancre absente, cellule
répétée). En revanche une empreinte **en deux morceaux disjoints** est acceptée : la
refuser serait une règle de contenu déguisée en règle de schéma.

**Le cycle `CityState` ↔ `PlacementValidator` passe** — ce n'est pas le cycle qui avait
mordu à `T3` entre `TerrainData` et `TerrainDecor` : celui-là portait sur une **constante**,
résolue à la compilation.

**`data/buildings/` n'est pas la passe de contenu** : `DESIGN.md` 4 ne donne aucune colonne
d'empreinte, donc les tailles posées ici sont inventées et `I3` les reprendra. Les trois
sont rectangulaires, fidèles à un design qui ne nomme aucun bâtiment en L.

**Le harnais cherche ses refus au lieu de les fabriquer** : il balaye la carte à la
recherche d'une ancre produisant exactement la raison visée, et le dit quand il n'en trouve
pas. C'est ce que les suites ne peuvent pas montrer — une règle qui cesserait de se
déclencher sur du terrain réellement généré remonterait toute seule. Pendant texte de la
sonde caméra de `T3`.

---

## 2026-08-24 — `T3` : picking DDA, surbrillance et décorations

**État : terminé.** Quatre commits sur `feat/t3-cell-picking`, 94 tests verts.
`cell_picker.gd` et `pick_result.gd`, `terrain_decor.gd` + le champ `decor` sur
`TerrainData`, trois adapters (`terrain_decor_renderer`, `cell_highlight`, `cell_cursor`).

**La signature figée qui ne l'était pas.** `CLAUDE.md` donnait `pick(grid, origin, dir)` et
le journal de `T2` la qualifiait de « signature figée ». Elle est inapplicable telle
quelle : le DDA a besoin de `tile_size` et `step_height`, que `T2` lui-même a sortis de
`HeightGrid` pour les mettre dans `TerrainMetrics`. La métrique devient un quatrième
paramètre, et `CLAUDE.md` est corrigé dans le même commit — **une signature figée qui bouge
doit dire qu'elle a bougé.**

**Une colonne est solide vers le bas et sans fond.** Le socle sous la carte n'est qu'une
épaisseur d'affichage ; lui donner un fond ouvrirait des tirs qui passent sous la carte pour
ressortir de l'autre côté. Corollaire assumé et testé : un tir parti de sous le terrain le
touche sur place.

**Le rayon est clippé sur l'emprise avant de marcher** — une caméra orthogonale place son
origine à cent unités de la carte. Le clip a aussi rattrapé un vrai bug : carte traversée
par la *droite* du rayon mais entièrement **derrière** son origine, l'intervalle d'entrée est
négatif et le clamp rendait une cellule inventée.

**Le point d'impact d'une face supérieure est recalé exactement sur le sommet** — le laisser
sortir du calcul flottant y remettrait quelques ulp de bruit, dans la valeur même sur
laquelle un bâtiment se posera. Le test assert l'égalité stricte.

**La décoration se décrit dans `data/`, dimensions en fractions de tuile** — même
raisonnement qu'à `T2` pour la couleur, et les fractions parce que régler `tile_size` doit
redimensionner la carte entière. **`decor` est nullable, seule exception au principe de
sentinelle** : plaine et eau n'ont rien à porter, et « rien » y est évident plutôt que
suspect ; le filet reste tendu sur une décoration *présente* mais à moitié remplie.

**La palette est passée en argument au renderer, pas lue sur `GameDatabase`** : les passes
se construisent sur ce que le jeu *connaît* et non sur ce qu'une grille contient — un seed
sans rocher ne doit pas supprimer la passe des rochers.

**La dispersion vient d'un hash de la cellule** — ni `randf()`, ni `RunState.rng` : une même
carte doit se disperser pareil à chaque affichage, sans faire descendre un flux de tirage
jusqu'à une passe de rendu.

**La surbrillance ne code aucune validité** — une marque verte ou rouge préempterait
Construction. Le picker désigne, il ne juge pas. **Le curseur pique à chaque image**, pas au
mouvement de souris : la caméra bouge aussi.

**Le bug que seule l'image a montré — le prisme noir.** Troisième jalon d'affilée. Les
gisements en `PrismMesh` apparaissaient comme des rectangles noirs, confirmé en recolorant
la forme en magenta pour savoir quels pixels lui appartenaient. **Le `PrismMesh` porte une
grande face verticale plate**, et le soleil n'éclaire que les surfaces tournées vers le
haut : aucune orientation ne sauve, puisque la caméra pivote au-dessus d'un soleil fixe. Le
prisme est **retiré du vocabulaire** plutôt que documenté avec une mise en garde — une
valeur d'enum inutilisée qui produit des trous noirs est un piège pour qui la choisira
ensuite. Le soleil n'a pas bougé : que seules les faces du dessus soient éclairées est
l'aspect établi à `T2`, un choix et non un défaut.

**La sonde caméra, non prévue au plan.** Entre les tests unitaires, qui tirent des rayons
faits à la main, et les trois commandes, qui ne regardent pas l'écran, il restait une
jointure non couverte : `project_ray_origin` et `project_ray_normal` d'une caméra
**orthogonale** donnent-ils au picker ce qu'il attend ? Chaque capture reprojette le point
d'impact vers l'écran, retire un rayon comme le ferait la souris, et dit si les deux tombent
sur la même cellule. D'accord au centre, dans un coin, et après un quart de tour.
`--shot-hover x,y` complète : souris à `(0, 0)`, une capture ne montrerait jamais la
surbrillance.

**Un test qui s'est cassé sur sa propre erreur** : le cas « changer `tile_size` change la
cellule désignée » visait un point hors de l'emprise de la seconde métrique. Le picker
n'avait rien, c'est l'attente qui était fausse.

---

## 2026-08-24 — `T2` : rendu en blocs étagés et caméra isométrique

**État : terminé.** Quatre commits sur `feat/t2-terrain-render`, 66 tests verts.
`src/adapters/` naît ici avec `terrain_renderer.gd` et `camera_rig.gd` ;
`TerrainMetrics` dans le domaine ; `CameraBalance` ; `TerrainData` gagne une `color`.

**Aucun DTO n'entre dans `contracts/`, et l'étape est sautée.** `T2` est interne au Terrain
plus sa couche adapter — inventer un contrat pour respecter la forme de la procédure aurait
figé une frontière que personne ne franchit. **`TerrainMetrics` va dans `domain/terrain/`** :
le renderer la consomme, le `CellPicker` la consommera à `T3` — deux fois le même système —
et elle est du domaine parce que `CellPicker` travaille déjà en coordonnées de monde.

**Trois conventions y sont fixées, et tout le reste du jeu en dépend :**

- l'origine du monde est au **coin** de la carte, pas au centre — `cell_at()` reste un
  `floor` sans décalage, ce dont le DDA de `T3` a besoin ; recentrer devient un travail de
  caméra ;
- grille `+x` → monde `+X`, grille `+y` → monde `+Z` ;
- une cellule de hauteur `h` a sa **face supérieure** à `h * step_height` — ni le socle ni
  l'épaisseur d'affichage ne déplacent ce plan.

**`floori`, pas `int()`** : une troncature ramènerait `-0.3` sur `0` et collerait les
cellules `-1` et `0` l'une sur l'autre.

**La couleur vit sur `TerrainData`, pas dans le renderer** — c'est ce qui interdit au
renderer de commuter sur un identifiant de terrain. **Sentinelle : le noir opaque vaut
« non renseigné »** — même piège qu'à `I0` et `T1`, un `Color` sans défaut vaut
`Color(0,0,0,1)`, donc exactement ce que Godot omet du `.tres`. Un terrain qui voudrait du
noir écrit `Color(0.02, 0.02, 0.02)`. Un test épingle le pari lui-même : que la sentinelle
soit bien la valeur qu'un `Color` neuf porte.

**Les colonnes s'enracinent un cran sous la plus basse de la carte**, pas à `y = 0` :
l'épaisseur reste positive sur un terrain plat comme sur un relief négatif. **Pas de jeu
entre les cellules** — une surface continue lit mieux qu'un damier fissuré, et la lisibilité
de la grille est le travail de la surbrillance de `T3`.

**Le rig lit son propre input, derrière `input_enabled`** — une caméra dont il faut câbler
l'input à chaque scène est une friction permanente. Aucune action d'input n'est utilisée, que
des touches brutes, pour que rien n'ait à être ajouté à `project.godot`.

**Le lacet cible s'accumule sans jamais être replié dans `[0, 360)`** : quatre quarts de
tour doivent faire un tour complet, une valeur repliée rebrousserait chemin au quatrième.

**`pan_speed` est en hauteurs d'écran par seconde**, pas en unités de monde — un pan réglé
au bon rythme de près file à travers la carte de loin. **Le piqué de −35,264° reste une
constante, pas un réglage** : c'est l'isométrique vrai, et le mettre en data inviterait à le
changer.

**Le bug que seule l'image a montré — le lacet de base était à zéro.** `CLAUDE.md` disait
« `rotation_degrees.y` par pas de 90° », lu comme un lacet partant de 0. Tout compilait, les
tests passaient, le boot était propre — et la capture montrait une vue alignée sur les axes,
une grille en damier, un relief réduit à des traits noirs. **Le piqué seul ne fait pas
l'isométrique** : il y faut 45° de lacet, qui sont ce qui projette une grille carrée en
losanges. À lacet nul, les faces `±X` d'une colonne sont exactement de profil, donc d'aire
nulle à l'écran — chaque colonne ne montre qu'**un seul** de ses quatre flancs et une marche
se lit comme une ligne. Le cadrage a suivi : à 45°, c'est la **diagonale** de la carte qui
barre l'écran, et elle est la même aux quatre orientations. Ce qu'il faut en retenir dépasse
le bug : **un jalon de rendu ne se vérifie pas au parsing.**

**Un second bug de rendu, signalé par l'humain — les cascades d'ombre.** Une ligne
horizontale **fixe à l'écran**, ombres floues au-dessus, nettes en dessous. Godot met une
`DirectionalLight3D` en `SHADOW_PARALLEL_4_SPLITS` sans fondu ; sous une caméra orthogonale,
où la profondeur croît linéairement du bas vers le haut de l'écran, ces frontières deviennent
des lignes horizontales fixes. Corrigé en `SHADOW_ORTHOGONAL` — les cascades servent à
couvrir un horizon lointain, et la scène est bornée par construction.
`directional_shadow_max_distance` est passé de 400 à `ORBIT_DISTANCE + 60` : l'étaler
au-delà de ce que la caméra voit ne faisait que diluer les texels. Consigné dans `CLAUDE.md`
et pas seulement ici — le soleil du harnais sera jeté quand la scène de jeu montera le sien.

**La capture en ligne de commande, non prévue au plan.** `-- --shot chemin.png
[--shot-turns n]` : le harnais rend, enregistre et quitte. C'était la seule façon de
regarder le rendu sans dépendre de l'humain à chaque itération, et c'est ce qui a trouvé le
bug ci-dessus. Douze lignes dans un harnais de dev, exactement l'endroit où ce genre
d'échafaudage a sa place.

**Observation d'équilibrage — le relief reste plat, et c'est un chiffre, pas un bug.** La
génération produit `1..5` (4 crans) alors que `max_height = 6` : comportement normal d'un
bruit fractal, dont les extrêmes ne sont statistiquement pas atteints. À
`step_height = 0.25`, cela fait 1,0 unité de relief sur une carte de 32 — la carte lit comme
un plateau froissé. Deux leviers, tous deux dans `data/balance/` : `step_height` (amplifie
sans toucher à la distribution) ou `noise_frequency`/`noise_octaves` (échange le froissement
haute fréquence contre des reliefs plus larges). Non tranché : c'est un choix d'aspect,
adossé à l'`OUVERT` de 3.1 sur le rôle du relief.

---

## 2026-08-24 — `T1` : grille de hauteurs et génération seedée

**État : terminé.** Cinq commits sur `feat/t1-height-grid`, 45 tests verts contre 3.
`contracts/` naît ici avec `TerrainQuery` ; `HeightGrid`, `GridTerrainQuery`, `TerrainGen` ;
les cinq terrains de `DESIGN.md` 3.1 en `.tres`.

**`TerrainQuery` est un contrat abstrait, pas une enveloppe autour de la grille.** Une query
qui aurait tenu une `HeightGrid` en membre privé aurait fait dépendre `contracts/` des
internes du Terrain, et Construction en aurait hérité par transitivité — l'inverse exact de
la règle de dépendance. `TerrainQuery` est `@abstract` dans `contracts/`, `GridTerrainQuery`
l'implémente dans `domain/terrain/` : la vue reste vivante et sans copie, et Combat pourra
recevoir une query fabriquée à la main en test.

**Trois primitives seulement sont abstraites** — `size()`, `height_at()`, `terrain_at()`.
Constructibilité, tags, planéité et dénivelé sont dérivés dans le contrat lui-même, pour que
deux implémentations ne divergent pas sur le sens de « constructible » ou de « plat ». Une
implémentation coûte douze lignes.

**Les bornes sont volontairement asymétriques** : `height_at()` assert hors grille — l'appeler
là est un bug de l'appelant — quand `is_buildable()` rend `false`, parce que Construction teste
couramment des empreintes qui débordent et que « puis-je bâtir hors carte ? » a une réponse.

**La constructibilité est un enum à trois états, pas un `bool`** : sur un `bool`, « non
renseigné » et « non constructible » sont indiscernables, et Godot n'écrit jamais `false` dans
un `.tres` — le champ aurait été invisible au contrôle de complétude. `UNSET = 0` reste
détectable.

**Représentation dense** — deux tableaux plats indexés `y * largeur + x`, pas un
`Dictionary` : la grille est rectangulaire et pleine. C'est le genre de choix que le contrat
rend révocable sans toucher personne.

**`generate()` prend un seed, pas le RNG du run** : la génération ne consomme aucun flux
partagé et se rejoue seule en test. **Le tirage de dispersion est consommé même quand il ne
donne rien** — une cellule tirée en forêt trop haut retombe en plaine sans décaler les bandes
suivantes : relever `forest_max_height` ne doit pas déplacer tous les gisements de la carte.

**`missing_fields()` est un filet partiel, et c'est assumé** : il ne rattrape que les champs
dont `0` est invalide. Pour `min_height` ou une densité, `0` est légitime — mais il transite
correctement, puisque Godot omet alors la ligne du `.tres`. Le piège de `I0` venait de ce que
le défaut du script *était* la vraie valeur.

**Les terrains ne sont pas figés dans les tests** — la structure est vérifiée (cinq fichiers,
aucun champ vide, `id` égal au nom de fichier), pas le contenu : assert que l'eau est
inconstructible recopierait `data/` dans `tests/`.

**Deux pièges de plus, consignés dans `CLAUDE.md`.** Le cache des classes globales est en
retard exactement comme celui des `uid://`, et bien plus souvent : un `class_name` créé hors
éditeur n'existe pour personne tant qu'aucun scan n'a eu lieu, et la commande 1 échoue sur
`Could not find type "X"` sur un fichier parfaitement correct. Et **la commande 1 rend `0`
alors qu'elle imprime des erreurs de script** — constaté directement : quatre `SCRIPT ERROR`
à l'écran et `EXIT=0`. Un contrôle qui ne testerait que `$?` laisserait passer un projet qui
ne compile pas.

**Un bug trouvé par les tests — `GameDatabase` ne triait rien.** `list_ids()` promettait un
ordre trié depuis `I0` et ne le tenait pas : `Array.sort()` sur des `StringName` compare des
**pointeurs internes**, pas du texte, donc un ordre arbitraire, stable le temps d'une session
et différent à la suivante. Corrigé en `sort_custom` sur `String(...)`, et ajouté aux
conventions — c'est un piège à déterminisme, pas une coquetterie.

**Observation laissée ouverte** : `max_height = 6` ne produit jamais de cellule à 6, le
maximum observé plafonne à 5. Comportement normal d'un bruit fractal — un chiffre à ajuster
une fois `T2` en place et le relief visible.

---

## 2026-08-24 — `I0` : squelette

**État : terminé.** `src/schema/` (`BalanceData`, `TerrainBalance`), `data/balance/`, les
trois autoloads (`EventBus`, `GameDatabase`, `RunManager`), `dev_boot.gd`, le README, 3 tests
verts. `src/domain/` encore vide.

**Une scène pivot unique pour tout le dev.** Godot ne sait lancer qu'une scène, jamais un
script, et la scène principale doit être une `PackedScene` : les harnais en `.gd` voulus par
`CLAUDE.md` étaient inatteignables sans au moins un fichier de scène. `dev_boot.tscn` est ce
fichier, et le seul — `dev_boot.gd` instancie le harnais nommé dans sa constante `HARNESS`,
si bien qu'ajouter un harnais coûte un `.gd` et une ligne de table, sans rouvrir l'éditeur.

**La commande de vérification n°1 était fausse, et deux remplaçantes l'étaient aussi.**
`--headless --quit` échoue tant qu'aucune scène principale n'est définie — une fois
`dev_boot.tscn` en place elle est correcte, et même la seule à monter les autoloads, donc à
valider `src/autoload/`, `src/adapters/` et `scenes/dev/`. `--headless --editor --quit` a
semblé un bon substitut : il ne signale les erreurs qu'au **premier** scan, et cache chaud il
rend 0 sur un projet cassé. `--check-only -s` est fiable et indépendant du cache mais compile
hors contexte, donc échoue sur tout script touchant un autoload — il ne sert que sur
`src/domain/`, où la règle de dépendance les interdit déjà. D'où trois commandes au lieu de
deux, chacune couvrant ce que les autres ne voient pas.

**Le cache `uid://` peut simuler un projet cassé.** Juste après avoir créé une scène, éditeur
encore ouvert, `.godot/uid_cache.bin` est en retard et la commande 1 échoue sur
`Unrecognized UID` — ce qui ressemble trait pour trait à une erreur réelle. Une passe
`--headless --editor --quit` reconstruit le cache.

**`EventBus.database_ready` est émis en différé.** Les autoloads sont prêts avant la scène
principale : émis directement dans `_ready()`, le signal n'aurait eu aucun auditeur possible.

**Ni `contracts/` ni `PhaseDef` à `I0`.** Aucun DTO n'a deux systèmes pour le consommer, et
livrer une structure de journée, même par défaut, préempterait la question ouverte 2 de
`DESIGN.md`.

**Correctif — l'éditeur vidait le data d'équilibrage.** Au premier réenregistrement des
`.tres`, `tile_size` et `step_height` ont **disparu** : Godot n'écrit pas une propriété égale
à son défaut `@export`, et je leur avais donné les mêmes valeurs en défaut — les chiffres
d'équilibrage étaient donc silencieusement remontés dans le `.gd`, en contradiction directe
avec un anti-pattern déclaré. Rien ne cassait, ce qui est précisément ce qui rend le piège
dangereux. Corrigé en retirant tout défaut des `@export` de `src/schema/` : un champ non
renseigné vaut `0`, détectable, chaque resource expose `missing_fields()`, `BalanceData` les
agrège et `GameDatabase` refuse de démarrer sur un champ vide. Vérifié dans les deux sens.
**C'est l'origine de la doctrine du zéro.**

**Godot épinglé à 4.7.2-stable** (`ed1daf0bf`), `gdUnit4` 6.2.0. Vérification des API
4.5 → 4.7 faite contre la doc extraite du binaire (`--doctool`) plutôt que contre les
changelogs : `MultiMesh`, `Camera3D` orthographique et les `Resource` personnalisées sont
intacts, aucune décision technique invalidée.

**Chaîne d'outils.** `GODOT_BIN` défini au niveau utilisateur, binaire rangé dans
`C:\Tools\Godot\4.7.2\` — un dossier par version, de sorte qu'une montée de version soit un
changement de `GODOT_BIN` et rien d'autre. Le README reste générique sur ce chemin : il est
propre à la machine.
