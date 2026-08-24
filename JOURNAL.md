# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

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
