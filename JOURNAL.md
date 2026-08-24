# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

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
