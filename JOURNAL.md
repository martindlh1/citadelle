# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

---

## 2026-08-24 — `T2` : rendu en blocs étagés et caméra isométrique

**État : terminé.** Quatre commits, une couche chacun, sur `feat/t2-terrain-render`.
Les trois commandes de vérification passent : boot sans erreur ni warning, tout
`src/domain/` parse, 66 tests verts contre 45 à l'ouverture. Le rendu a été vérifié
en image, pas seulement au parsing — voir plus bas.

### Ce qui a été livré

- `src/adapters/` — le dossier naît ici, avec `terrain/`.
- `src/adapters/terrain/terrain_renderer.gd` — une passe `MultiMeshInstance3D`, une
  colonne par cellule, couleur par instance.
- `src/adapters/terrain/camera_rig.gd` — rig isométrique, rotation par quarts de tour
  tweenée, zoom orthographique, pan clavier et souris.
- `src/domain/terrain/terrain_metrics.gd` — le passage grille ↔ monde.
- `src/schema/camera_balance.gd` + `data/balance/camera_balance.tres`, chaîné dans
  `BalanceData`.
- `TerrainData` gagne une `color`, les cinq `.tres` de `data/terrain/` la renseignent.
- `tests/domain/terrain/terrain_metrics_test.gd` — 15 cas ; 6 de plus répartis dans
  les deux fume-tests de schema.
- `scenes/dev/terrain_harness.gd` — réécrit : le rendu remplace la carte ASCII, les
  décomptes restent en surimpression.

### Décisions

**Aucun DTO n'entre dans `contracts/`, et l'étape est sautée.** `T2` est interne au
Terrain plus sa couche adapter ; aucun second système ne consomme quoi que ce soit de
nouveau. Inventer un contrat pour respecter la forme de la procédure aurait figé une
frontière que personne ne franchit encore.

**`TerrainMetrics` va dans `domain/terrain/`, pas dans `contracts/`.** Le renderer la
consomme aujourd'hui, le `CellPicker` la consommera à `T3` : deux fois le même
système. Elle est du domaine et non de l'adapter parce que `CellPicker` est du domaine
et travaille déjà en coordonnées de monde — `pick(grid, origin: Vector3, dir: Vector3)`
est une signature figée de `CLAUDE.md`. Si Construction en a besoin directement à
`C2`, ce sera le moment de la promouvoir.

**Trois conventions y sont fixées**, et tout le reste du jeu en dépendra :

- l'origine du monde est au **coin** de la carte, pas au centre. `cell_at()` reste un
  `floor` sans décalage, ce dont le DDA de `T3` a besoin ; recentrer devient un travail
  de caméra ;
- grille `+x` → monde `+X`, grille `+y` → monde `+Z` ;
- une cellule de hauteur `h` a sa **face supérieure** à `h * step_height`. Ni le socle
  sous la colonne ni l'épaisseur que le renderer lui donne ne déplacent ce plan.

**`floori`, pas `int()`.** Une troncature ramènerait `-0.3` sur `0` et collerait les
cellules `-1` et `0` l'une sur l'autre. Trois cas de test tiennent ce point, dont
l'appartenance d'un point posé sur une arête exacte à la cellule supérieure.

**La couleur vit sur `TerrainData`, pas dans le renderer.** C'est ce qui interdit au
renderer de commuter sur un identifiant de terrain : ajouter un terrain reste une
édition de `data/`. Le jour où un vrai matériau arrive, il se pose au même endroit.

**Sentinelle de couleur : le noir opaque vaut « non renseigné ».** Même piège qu'à
`I0` et `T1` — un `Color` sans défaut vaut `Color(0,0,0,1)`, donc exactement ce que
Godot omet du `.tres`, donc indiscernable d'un champ oublié. On tranche pour
« oublié » ; un terrain qui voudrait du noir écrit `Color(0.02, 0.02, 0.02)`. Arbitré
avec l'humain avant écriture. Un test épingle le pari lui-même : que la sentinelle
soit bien la valeur qu'un `Color` neuf porte. Si une version du moteur changeait ce
défaut, la détection deviendrait muette sans rien casser d'autre — ce test-là le dirait.

**Les colonnes s'enracinent un cran sous la plus basse de la carte**, et non à `y = 0`.
L'épaisseur reste positive sur un terrain parfaitement plat comme sur un relief
négatif, et la carte gagne un socle plein plutôt que des colonnes flottantes.

**Pas de jeu entre les cellules.** Les colonnes se touchent exactement : une surface
continue lit mieux qu'un damier fissuré. La lisibilité de la grille est le travail de
la surbrillance de `T3`, pas d'un liseré permanent.

**Le rig lit son propre input, derrière `input_enabled`.** Une caméra dans laquelle il
faut câbler l'input à chaque scène est une friction permanente ; une scène de jeu qui
veut ses propres liaisons coupe le drapeau et garde l'API. Aucune action d'input n'est
utilisée — que des touches brutes et la molette — pour que rien n'ait à être ajouté à
`project.godot`, qui n'est pas mon fichier.

**Le lacet cible s'accumule sans jamais être replié dans `[0, 360)`.** Quatre quarts
de tour enchaînés doivent faire un tour complet ; une valeur repliée ferait rebrousser
chemin au quatrième.

**`pan_speed` est en hauteurs d'écran par seconde**, pas en unités de monde. La vitesse
ressentie devient indépendante du zoom, ce qui est la seule définition utilisable — un
pan réglé au bon rythme de près file à travers la carte de loin.

**Le piqué de −35,264° reste une constante, pas un réglage.** `CameraBalance` porte le
zoom, le pan, la durée de rotation et la marge de cadrage. Le piqué non : c'est
l'isométrique vrai, une décision figée, et le mettre en data inviterait à le changer.

### Le bug que seule l'image a montré — le lacet de base était à zéro

`CLAUDE.md` dit « `rotation_degrees.x = -35.264` (isométrique vrai),
`rotation_degrees.y` par pas de 90° ». J'ai lu ça comme un lacet partant de 0, et le
projet a compilé, les tests sont passés, le boot était propre. La capture a montré
autre chose : une vue alignée sur les axes, une grille en damier rectangulaire, et un
relief réduit à des traits noirs.

**Le piqué seul ne fait pas l'isométrique.** Il y faut aussi 45° de lacet, qui sont ce
qui projette une grille carrée en losanges. La conséquence est directe sur un relief en
blocs : à lacet nul, les faces `±X` d'une colonne sont exactement de profil, donc
d'aire nulle à l'écran — chaque colonne ne montre qu'**un seul** de ses quatre flancs,
et une marche se lit comme une ligne. À 45°, deux flancs sont visibles, à deux
éclairements différents, et le volume apparaît. C'est toute la différence entre les
deux captures.

Le lacet démarre donc à `ISO_YAW_DEGREES = 45.0` et les quarts de tour en dérivent.
Le cadrage a suivi : à 45°, c'est la **diagonale** de la carte qui barre l'écran, et
elle reste la même aux quatre orientations.

Ce qu'il faut en retenir dépasse le bug : **un jalon de rendu ne se vérifie pas au
parsing.** Les trois commandes de `CLAUDE.md` étaient toutes vertes sur une caméra qui
ne faisait pas son travail.

### Un second bug de rendu, signalé par l'humain — les cascades d'ombre

Symptôme : une ligne horizontale **fixe à l'écran**, ombres floues au-dessus, nettes en
dessous, le terrain traversant la frontière quand on déplace la vue.

C'est le découpage en cascades de l'ombre directionnelle. Godot met une
`DirectionalLight3D` en `SHADOW_PARALLEL_4_SPLITS` par défaut, avec
`directional_shadow_blend_splits` à `false` : quatre cartes d'ombre de résolutions
différentes selon la profondeur, raccordées sans fondu. Sous une **caméra
orthogonale**, la profondeur croît linéairement du bas vers le haut de l'écran — ces
frontières de profondeur deviennent donc des lignes horizontales à position fixe à
l'écran. Sous une caméra en perspective elles suivraient le relief et passeraient
inaperçues ; c'est le choix de l'orthogonale, figé par `CLAUDE.md`, qui les rend
visibles.

Corrigé en une ligne : `SHADOW_ORTHOGONAL`, une seule carte. Les cascades servent à
couvrir un horizon lointain, et la scène ici est bornée par construction — elle tient
dans une carte sans rien perdre.

`directional_shadow_max_distance` est passé de 400 à `ORBIT_DISTANCE + 60`, soit 180.
Il était réglé au doigt mouillé pour « dépasser le recul du rig » ; l'étaler deux fois
et demi plus loin que ce que la caméra voit ne faisait que diluer les texels de la
carte d'ombre. La constante est maintenant dérivée de `CameraRig.ORBIT_DISTANCE` plutôt
que recopiée, pour que le couplage soit visible plutôt que silencieux.

**Consigné dans `CLAUDE.md`, section Caméra**, et pas seulement ici : le soleil du
harnais sera jeté quand la scène de jeu montera son propre éclairage, et la contrainte
doit lui survivre.

Deuxième bug de rendu de ce jalon que les trois commandes de vérification laissent
passer, après le lacet. Elles disent que le code compile et que le domaine est juste ;
elles ne disent rien de ce qui s'affiche. Pour un jalon de rendu, la capture n'est pas
un confort.

### Une addition non prévue au plan — la capture en ligne de commande

Le harnais accepte `-- --shot chemin.png [--shot-turns n]` : il rend, enregistre et
quitte. C'était la seule façon de regarder le rendu sans dépendre de l'humain à chaque
itération, et c'est ce qui a trouvé le bug ci-dessus. `--shot-turns` exerce la rotation,
qui autrement n'était vérifiable qu'en appuyant sur une touche.

Douze lignes dans un harnais de dev, qui est exactement l'endroit où ce genre
d'échafaudage a sa place. Documenté dans le README. Ça sert aussi la suite : comparer
deux valeurs d'équilibrage visuel revient désormais à éditer un `.tres` et relancer.

### Observation d'équilibrage — le relief reste plat, et c'est un chiffre, pas un bug

`T1` avait laissé ceci ouvert, explicitement pour « une fois `T2` en place et le relief
réellement visible ». C'est le cas, alors voici la mesure plutôt qu'une décision :

- la génération produit des hauteurs `1..5`, soit **4 crans** de dénivelé, alors que
  `max_height = 6` — le comportement normal d'un bruit fractal, dont les extrêmes ne
  sont statistiquement pas atteints ;
- à `step_height = 0.25`, ça fait **1,0 unité de relief sur une carte de 32 unités**.
  Une amplitude de 1:32 : la carte lit comme un plateau froissé, pas comme des
  collines ;
- deux tiers des cellules tiennent sur deux altitudes seulement (`h = 2` et `h = 3`).

Deux leviers, tous deux dans `data/balance/`, aucun dans du GDScript :

| Levier | Fichier | Effet |
|---|---|---|
| `step_height` 0,25 → 0,4 ou 0,5 | `terrain_balance.tres` | amplifie ce que la génération produit déjà, sans toucher à sa distribution |
| `noise_frequency` 0,08 → plus bas, `noise_octaves` 3 → 2 | `terrain_gen_balance.tres` | échange le froissement haute fréquence contre des reliefs plus larges |

Je ne tranche pas : c'est un choix d'aspect, et il est adossé à la question `OUVERT` de
`DESIGN.md` 3.1 sur le rôle du relief dans le gameplay — un relief décoratif et un
relief qui contraint la construction ne demandent pas la même amplitude. La comparaison
coûte deux relances :

```
"$GODOT_BIN" --path . --resolution 1280x720 -- --shot avant.png
# éditer data/balance/terrain_balance.tres
"$GODOT_BIN" --path . --resolution 1280x720 -- --shot apres.png
```

### Ce qui reste

Rien pour `T2`. `DESIGN.md` n'a pas bougé : aucune question `OUVERT` n'a été tranchée,
et c'est délibéré. `T2` **montre** le relief, il ne le fait pas **jouer** — les quatre
pistes de 3.1 restent entières.

Deux choses volontairement laissées de côté, et pourquoi :

- **pas de teinte du relief par altitude.** L'éclairage directionnel suffit à faire
  lire les marches, et ajouter une teinte aurait inventé des chiffres d'équilibrage que
  personne n'a demandés. À rouvrir si la lecture pose problème une fois le relief
  amplifié.
- **pas de liseré de grille.** C'est le rôle de la surbrillance de survol, à `T3`.

### Prochain jalon

`T3` — `CellPicker` en DDA sur la grille de hauteurs, surbrillance de la cellule
survolée, décorations de terrain. `TerrainMetrics` lui a posé ses fondations, et
`CameraRig.get_camera()` lui fournira `origin` et `dir` via `project_ray_origin` et
`project_ray_normal`. C'est le premier jalon où les conventions de coin d'origine et de
face supérieure vont vraiment être mises à l'épreuve.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni réglage de projet n'a changé, aucune action
d'input n'a été ajoutée. `HARNESS` vaut toujours `&"terrain"` : `F5` affiche la carte,
Espace passe au seed suivant, Q et E tournent, la molette zoome, les flèches ou WASD et
le clic milieu déplacent, R recadre.

Deux points de suite :

- `data/balance/camera_balance.tres` a été créé sans `uid`. L'éditeur lui en attribuera
  un à la première ouverture : **diff à committer, pas à jeter**, comme à `I0` et `T1`.
- si l'amplitude du relief te va telle quelle, il n'y a rien à faire ; sinon, c'est
  l'édition d'un ou deux chiffres décrite plus haut, et ça n'a pas à attendre `T3`.

---

## 2026-08-24 — `T1` : grille de hauteurs et génération seedée

**État : terminé.** Cinq commits, une couche chacun, sur `feat/t1-height-grid`. Les
trois commandes de vérification passent : boot exit 0 sans erreur ni warning, tout
`src/domain/` parse, 45 tests verts contre 3 à l'ouverture.

### Ce qui a été livré

- `src/domain/contracts/` — le dossier naît ici, comme annoncé à `I0`, avec `TerrainQuery`.
- `src/domain/terrain/` — `HeightGrid`, `GridTerrainQuery`, `TerrainGen`.
- `src/schema/` — `TerrainData` et `TerrainGenBalance`, ce dernier chaîné dans `BalanceData`.
- `data/terrain/` — les cinq terrains du tableau de `DESIGN.md` 3.1, un `.tres` chacun.
- `tests/domain/terrain/` — 36 cas sur la grille, le contrat et la génération.
- `scenes/dev/terrain_harness.gd` — carte ASCII, décomptes par terrain, histogramme d'altitudes.
- `GameDatabase` — `get_terrain()`, `list_terrain_ids()`, et refus de démarrer sur un terrain incomplet.

### Décisions

**`TerrainQuery` est un contrat abstrait, pas une enveloppe autour de la grille.**
Une query qui aurait tenu une `HeightGrid` en membre privé aurait fait dépendre
`contracts/` des internes du système Terrain, et Construction en aurait hérité par
transitivité — l'inverse exact de la règle de dépendance. `TerrainQuery` est donc
`@abstract` dans `contracts/`, et `GridTerrainQuery` l'implémente dans
`domain/terrain/`. La vue reste vivante et sans copie, et Combat pourra recevoir une
query fabriquée à la main en test, comme `DESIGN.md` 3.6 le prévoit déjà pour les
`CitySnapshot`. Arbitré avec l'humain avant écriture.

**Trois primitives seulement sont abstraites** — `size()`, `height_at()`,
`terrain_at()`. Constructibilité, tags, planéité et dénivelé sont dérivés dans le
contrat lui-même, pour que deux implémentations ne puissent pas diverger sur le sens
de « constructible » ou de « plat ». Une implémentation coûte douze lignes.

**Les bornes sont volontairement asymétriques.** `height_at()` assert hors grille —
l'appeler là est un bug de l'appelant. `is_buildable()` et les requêtes de zone
rendent `false` : Construction teste couramment des empreintes qui débordent d'un
bord, et « puis-je bâtir hors carte ? » a une réponse.

**La constructibilité est un enum à trois états, pas un `bool`.** Sur un `bool`,
« non renseigné » et « non constructible » sont indiscernables, et Godot n'écrit
jamais `false` dans un `.tres` — le champ aurait été invisible au contrôle de
complétude. `UNSET = 0` reste détectable.

**Représentation dense** dans `HeightGrid` : deux tableaux plats indexés
`y * largeur + x`, pas un `Dictionary[Vector2i, …]`. La grille est rectangulaire et
toutes ses cellules sont remplies ; le dictionnaire n'aurait payé que du surcoût.
C'est précisément le genre de choix que le contrat rend révocable sans toucher
personne.

**`generate()` prend un seed, pas le RNG du run.** La génération ne consomme donc
aucun flux partagé : elle se rejoue seule en test, sans dépendre de ce qui a été tiré
avant elle. L'intention de la règle — jamais de `randf()` global — est respectée. Le
jour où `RunState` existera, lui passer `run_seed` restera une ligne. Un test couvre
explicitement cette indépendance à l'ordre d'appel.

**Le tirage de dispersion est consommé même quand il ne donne rien.** Une cellule
tirée en forêt trop haut retombe en plaine sans décaler les bandes suivantes :
relever `forest_max_height` ne doit pas déplacer tous les gisements de la carte. Un
test le vérifie en comparant deux plafonds extrêmes.

**`missing_fields()` est un filet partiel, et c'est assumé.** Il ne rattrape que les
champs dont `0` est une valeur invalide. Pour `min_height`, `water_level` ou une
densité, `0` est légitime — mais il transite correctement, puisque Godot omet alors
la ligne du `.tres` et que le chargement rend bien `0`. Le piège de `I0` venait de ce
que le défaut du script *était* la vraie valeur ; avec un défaut à `0`, toute valeur
utile est écrite. La règle tient, le filet est simplement plus court qu'il n'en a
l'air.

**Les terrains ne sont pas figés dans les tests.** `terrain_data_test.gd` vérifie la
structure — les cinq fichiers présents, aucun champ vide, `id` égal au nom de fichier
— mais n'assert nulle part que l'eau est inconstructible. Le faire aurait recopié
`data/` dans `tests/`, ce que `balance_data_test.gd` évite déjà délibérément.

### Deux pièges de plus, consignés dans `CLAUDE.md`

**Le cache des classes globales est en retard exactement comme celui des `uid://`,
et bien plus souvent.** `.godot/global_script_class_cache.cfg` n'est écrit que par le
scan de l'éditeur : un `class_name` créé hors éditeur n'existe pour personne tant que
ce scan n'a pas eu lieu. La commande 1 échoue alors sur
`Could not find type "TerrainData" in the current scope` sur un fichier parfaitement
correct. Même remède qu'à `I0` — une passe `--headless --editor --quit`. À faire après
chaque ajout de `class_name`, donc à chaque nouveau fichier de domaine ou de schema.

**La commande 1 rend `0` alors qu'elle imprime des erreurs de script.** Constaté
directement : parse error, assertion échouée, quatre `SCRIPT ERROR` à l'écran, et
`EXIT=0`. Son code de sortie ne dit rien de la santé du projet. Un contrôle qui ne
testerait que `$?` laisserait passer un projet dont un script ne compile pas.

### Un bug trouvé par les tests — `GameDatabase` ne triait rien

`list_ids()` et `list_categories()` promettaient un ordre trié depuis `I0` et ne le
tenaient pas. `Array.sort()` sur des `StringName` compare des **pointeurs internes**,
pas du texte : l'ordre rendu était arbitraire, stable le temps d'une session et
différent à la suivante. Le test qui attendait les cinq terrains dans l'ordre
alphabétique l'a fait tomber tout de suite.

Corrigé par un `sort_custom` sur `String(...)` dans les deux méthodes. La règle est
ajoutée aux conventions de code : c'est un piège à déterminisme, pas une coquetterie.

### Observation d'équilibrage, laissée ouverte

`max_height = 6` ne produit jamais de cellule à 6, et le maximum observé plafonne à 5.
C'est le comportement normal d'un bruit fractal, dont les extrêmes ne sont
statistiquement pas atteints : l'amplitude réglée est plus large que l'amplitude
obtenue. Rien à corriger dans le code — c'est un chiffre à ajuster dans
`data/balance/`, une fois `T2` en place et le relief réellement visible.

### Ce qui reste

Rien pour `T1`. `DESIGN.md` n'a pas bougé : aucune question `OUVERT` n'a été
tranchée, et c'est délibéré — `TerrainQuery` expose hauteur et planéité sans en
consommer aucune, ce qui laisse ouvertes les quatre pistes de 3.1 sur le rôle du
relief dans le gameplay.

### Prochain jalon

`T2` — rendu `MultiMeshInstance3D` en blocs étagés et `CameraRig` isométrique avec
rotation par pas de 90° et zoom. C'est le premier jalon à produire une vraie scène 3D,
donc le premier à consommer `terrain.tile_size` et `terrain.step_height`, restés
inutilisés jusqu'ici.

### À faire dans l'éditeur avant la prochaine session

Rien d'obligatoire — aucune scène ni réglage de projet n'a changé, et `HARNESS` est
déjà passé à `&"terrain"` : `F5` affiche la carte, Espace passe au seed suivant.

Un seul point de suite : les six `.tres` créés cette session l'ont été sans `uid`,
qui se résolvent très bien par chemin. L'éditeur leur en attribuera à la première
ouverture. Comme à `I0`, ce diff est à committer plutôt qu'à jeter, pour qu'un
prochain clone ne les régénère pas différemment.

---

## 2026-08-24 — `I0` : squelette

**État : terminé.** Code écrit, scène pivot et autoloads câblés dans l'éditeur, les
trois commandes de vérification passent sur le dépôt : boot exit 0, `src/domain/`
encore vide, 3 tests verts.

### Ce qui a été livré

- `src/schema/` — `BalanceData`, racine de l'équilibrage, et `TerrainBalance`
  (`tile_size`, `step_height`).
- `data/balance/` — `balance.tres` et `terrain_balance.tres`, chaînés.
- `src/autoload/` — `EventBus` (3 signaux), `GameDatabase` (index à deux niveaux),
  `RunManager` (coquille : seed et RNG).
- `tests/schema/balance_data_test.gd` — 3 cas, tous verts.
- `scenes/dev/dev_boot.gd` — scène pivot, rapport de boot.
- `README.md` — version de Godot épinglée, mise en route.

### Décisions

**Une scène pivot unique pour tout le dev.** Godot ne sait lancer qu'une scène, jamais
un script, et la scène principale doit être une `PackedScene`. Les harnais en `.gd`
voulus par `CLAUDE.md` étaient donc inatteignables sans au moins un fichier de scène.
`scenes/dev/dev_boot.tscn` est ce fichier, et le seul : `dev_boot.gd` instancie le
harnais nommé dans sa constante `HARNESS`. Ajouter un harnais coûte désormais un `.gd`
et une ligne de table, sans jamais rouvrir l'éditeur.

**La commande de vérification n°1 était fausse, et deux remplaçantes l'étaient aussi.**
Trois observations, toutes reproduites sur 4.7.2 :

- `--headless --quit` échoue tant qu'aucune scène principale n'est définie. Une fois
  `dev_boot.tscn` en place, la commande d'origine est correcte — elle est même la seule
  à monter les autoloads, donc la seule à valider `src/autoload/`, `src/adapters/` et
  `scenes/dev/`.
- `--headless --editor --quit` a semblé un bon substitut : il ne l'est pas. Il ne
  signale les erreurs qu'au **premier** scan. Cache `.godot/` chaud, il rend 0 sur un
  projet dont un script ne compile pas. Piège sérieux, écarté.
- `--check-only -s` est fiable et indépendant du cache, mais compile hors contexte :
  tout script touchant un autoload y échoue avec « Identifier not found ». Il ne sert
  donc que sur `src/domain/`, où la règle de dépendance interdit déjà les autoloads.

D'où trois commandes au lieu de deux, chacune couvrant ce que les autres ne voient pas.
`CLAUDE.md` est à jour, avec les pièges consignés.

**`EventBus.database_ready` est émis en différé.** Les autoloads sont prêts avant la
scène principale : émis directement dans `_ready()`, le signal n'aurait eu aucun
auditeur possible. `emit.call_deferred()` le fait atterrir après le `_ready()` de la
scène. Vérifié : `dev_boot` le reçoit.

**Pas de `contracts/` à `I0`.** Aucun DTO n'a deux systèmes pour le consommer. Le
dossier naîtra avec `T1`.

**Pas de `PhaseDef` à `I0`.** Livrer une structure de journée, même par défaut,
préempterait la question ouverte 2. de `DESIGN.md`. Elle se tranche à `I2b`.

**Vérification des API 4.5 → 4.7 faite**, contre la doc de classes extraite du binaire
(`--doctool`) plutôt que contre les changelogs. `MultiMesh`, `Camera3D` orthographique
et les `Resource` personnalisées sont intacts. Aucune décision technique invalidée.
Détail dans `CLAUDE.md`.

**Le cache `uid://` peut simuler un projet cassé.** L'éditeur référence la scène
principale et les autoloads par `uid://`, résolus depuis `.godot/uid_cache.bin`. Juste
après avoir créé la scène, éditeur encore ouvert, ce cache est en retard : la commande 1
échoue sur `Unrecognized UID`, ce qui ressemble trait pour trait à une erreur réelle.
Une passe `--headless --editor --quit` reconstruit le cache. Consigné dans `CLAUDE.md`
pour ne pas y perdre du temps deux fois.

**Godot épinglé à 4.7.2-stable** (`ed1daf0bf`). `gdUnit4` 6.2.0.

### Ce qui reste

Rien. `DESIGN.md` n'a pas été touché : aucune question `OUVERT` n'a bougé.

### Prochain jalon

`T1` — `HeightGrid`, génération seedée, tests. Aucun rendu. C'est le premier système à
avoir un vrai `domain/`, donc le premier à exercer la commande de vérification n°2.

### Câblage éditeur — fait

`dev_boot.tscn` créé, défini comme scène principale, les trois autoloads enregistrés
dans l'ordre `EventBus` → `GameDatabase` → `RunManager`. Identité git configurée.

### Chaîne d'outils — fait

`GODOT_BIN` défini au niveau utilisateur. Le binaire a quitté le Bureau pour
`C:\Tools\Godot\4.7.2\`, un dossier par version, de sorte qu'une montée de version soit
un changement de `GODOT_BIN` et rien d'autre. Les trois commandes de vérification ont
été rejouées depuis ce nouvel emplacement : même build `ed1daf0bf`, boot exit 0,
3 tests verts.

Le README reste volontairement générique sur ce chemin : il est propre à la machine, il
n'a rien à faire dans le dépôt.

### Correctif — l'éditeur vidait le data d'équilibrage

Au premier réenregistrement des `.tres` par l'éditeur, `tile_size` et `step_height` ont
**disparu** de `data/balance/terrain_balance.tres`. Godot n'écrit pas une propriété
égale à son défaut `@export`, et je leur avais donné les mêmes valeurs en défaut : les
chiffres d'équilibrage étaient donc silencieusement remontés dans le `.gd`, en
contradiction directe avec la règle d'équilibrage et avec un anti-pattern déclaré. Rien
ne cassait, ce qui est précisément ce qui rend le piège dangereux.

Corrigé en retirant tout défaut des `@export` de `src/schema/`. Un champ non renseigné
vaut désormais `0`, détectable : chaque resource expose `missing_fields()`, `BalanceData`
les agrège, `GameDatabase` refuse de démarrer sur un champ vide. Vérifié dans les deux
sens — en supprimant `step_height` d'un `.tres`, le boot lève l'assertion et le test
échoue, tous deux en nommant `terrain.step_height`.

Les `uid://` que l'éditeur a ajoutés aux `.tres` au passage sont commités : `project.godot`
référence déjà la scène principale et les autoloads par `uid`, et des uid non versionnés
seraient régénérés différemment au prochain clone.

### Git

`feat/i0-skeleton` fusionnée en fast-forward dans `master`, poussée, et `master` remis
en branche par défaut sur GitHub — la branche de feature s'y était installée par défaut
au premier push. Remote nommé `citadelle`, pas `origin`.

### À faire avant la prochaine session

Rien. `T1` peut démarrer.
