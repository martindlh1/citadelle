# CLAUDE.md — Citadelle *(titre de travail)*

Contexte permanent pour Claude Code. À lire intégralement avant toute modification.

- Design, systèmes et jalons : `DESIGN.md`
- Décisions prises en cours de route : `JOURNAL.md`

---

## Stack

- **Godot 4.7.2-stable** (`ed1daf0bf`) — GDScript uniquement, pas de C#, pas de GDExtension
- Version épinglée dans le README, figée pour toute la durée du projet. Une montée de version est une tâche à part entière, jamais un effet de bord.
- Renderer **Forward+**
- Seule dépendance : `gdUnit4` dans `addons/`
- Aucun asset final pour l'instant : primitives et matériaux colorés
- Les `Dictionary` typés (`Dictionary[Vector2i, CellState]`) sont disponibles depuis 4.4 : les utiliser partout dans le domaine plutôt qu'un `Dictionary` nu.

> **Vérifié le 2026-08-24**, non pas contre les changelogs mais contre la doc de classes extraite du binaire 4.7.2 lui-même (`--doctool`), qui fait foi.
>
> - `MultiMesh` — `use_colors`, `set_instance_color`, `instance_count`, `transform_format` : présents, non dépréciés. Ajouts 4.4+ sans impact sur nos choix (`physics_interpolation_quality`, `set_buffer_interpolated`).
> - `Camera3D` orthographique — `projection`, `size`, `PROJECTION_ORTHOGONAL`, `project_ray_origin`, `project_ray_normal` : présents, non dépréciés.
> - `Resource` personnalisées — intactes. 4.5 ajoute `duplicate_deep(mode)` à côté de `duplicate()` : à connaître le jour où une resource d'équilibrage devra être dupliquée avant mutation.
>
> Aucune décision technique de ce fichier n'est invalidée. À refaire à la prochaine montée de version, pas avant.

---

## Architecture — hexagonale

Le projet est découpé en **systèmes indépendants**, chacun structuré en trois couches. La règle de dépendance pointe **vers l'intérieur**, sans exception.

```
        adapters/  (Node, scènes, input, rendu, UI)
              │  appelle
              ▼
        domain/    (RefCounted pur, règles du jeu)
              │  utilise
              ▼
        contracts/ (DTO partagés entre systèmes)
```

### `src/domain/` — le cœur

Règles du jeu en GDScript pur. **Interdits dans ce dossier** : `Node`, `get_node`, `get_tree`, `await`, `Input`, `EventBus`, `Time`, `randf()` non seedé, `preload` d'une `.tscn`.

Un système du domaine expose des fonctions qui prennent un état et rendent un résultat :

```gdscript
class_name ProductionResolver extends RefCounted

static func resolve(city: CityState, assign: Assignment, roster: Roster) -> ProductionReport
```

Le domaine **ne notifie personne**. Il retourne. C'est l'appelant qui publie.

### `src/adapters/` — les vues et les entrées

Scripts attachés à des `Node`. Ils traduisent un input en appel de domaine, et un résultat de domaine en affichage. Ils n'appliquent **jamais** une règle métier. Si tu écris `if ledger.wood >= data.cost` dans un script d'UI, c'est un bug d'architecture : la question se pose au domaine, l'UI affiche la réponse.

### `src/domain/contracts/` — les frontières

Les DTO échangés entre systèmes. C'est le seul endroit où deux systèmes se rencontrent. Un système du domaine peut dépendre de `contracts/`, **jamais** des internes d'un autre système.

| DTO | Producteur | Consommateur |
|---|---|---|
| `TerrainQuery` | Terrain | Construction, Combat |
| `CitySnapshot` | Ville | Économie, Combat |
| `PlacementResult` | Construction | adapters |
| `Assignment` | Effectifs | Économie, Combat |
| `LaborForce` | Effectifs | Économie |
| `CombatForce` | Effectifs | Combat |
| `ProductionReport` | Économie | Effectifs (XP), adapters |
| `WaveDef` | Run | Combat |
| `DamageReport` | Combat | Ville, Effectifs, adapters |

**Changer l'intérieur d'un système est libre. Changer un contrat se discute.**

---

## Arborescence

```
res://
├── addons/gdunit4/
├── data/                       # contenu, .tres uniquement
│   ├── buildings/  cards/  terrain/  waves/  events/
│   └── balance/                # tous les chiffres réglables, un seul endroit
├── src/
│   ├── domain/
│   │   ├── contracts/          # DTO inter-systèmes
│   │   ├── terrain/            # HeightGrid, TerrainGen, CellPicker
│   │   ├── city/               # CityState, PlacementValidator
│   │   ├── economy/            # Ledger, ProductionResolver
│   │   ├── workforce/          # Worker, Roster, SkillTrack, Assignment
│   │   ├── deck/               # Deck, Hand, DraftPool
│   │   ├── combat/             # CombatResolver (interchangeable)
│   │   └── run/                # RunState, DayCycle, RunOrchestrator
│   ├── schema/                 # définitions des Resource (BuildingData…)
│   ├── adapters/
│   │   ├── terrain/  city/  deck/  workforce/  combat/  hud/
│   └── autoload/               # EventBus, GameDatabase, RunManager
├── scenes/
│   ├── dev/                    # dev_boot.tscn (seule .tscn) + un harnais .gd par système
│   ├── game/
│   └── ui/
└── tests/                      # miroir de src/domain/
```

---

## Développement par système

Chaque système se construit **isolément**, dans sa propre scène de dev sous `scenes/dev/`, avec des données bidon. On ne le branche au jeu qu'une fois qu'il tient debout seul.

Procédure pour un système :

1. Écrire les DTO dans `contracts/`
2. Écrire le domaine + les tests, sans aucun `Node`
3. Écrire le harnais de dev `scenes/dev/<systeme>_harness.gd` (voir ci-dessous)
4. Écrire les adapters
5. Brancher sur `RunOrchestrator` et `EventBus`

**Ne jamais entamer un système en commençant par sa scène.** Le domaine d'abord, toujours.

### Harnais de dev — en code, pas en `.tscn`

Un harnais de dev est un **script**, pas un fichier de scène. Il hérite de `Node` et construit son arbre dans `_ready()` : caméra, multimesh, quelques `Button`, tout instancié à la main.

```gdscript
# scenes/dev/terrain_harness.gd
extends Node

func _ready() -> void:
    var grid := TerrainGen.generate(1234, Vector2i(16, 16))
    add_child(_make_camera_rig())
    add_child(TerrainRenderer.new(grid))
```

Trois raisons : c'est diffable dans git, ça ne casse jamais au réenregistrement, et Claude Code peut l'écrire seul. Les vrais fichiers de scène sont réservés au jeu, sous `scenes/game/` et `scenes/ui/`.

**Une seule `.tscn` existe dans tout `scenes/dev/`** : `dev_boot.tscn`, un `Node` nu portant `dev_boot.gd`. Godot ne sait lancer qu'une scène, jamais un script, et la scène principale d'un projet doit être une `PackedScene` — cette scène pivot est donc le seul moyen d'entrer dans du code au démarrage. Elle est aussi la scène principale du projet.

`dev_boot.gd` instancie le harnais dont l'identifiant est dans sa constante `HARNESS`, choisi dans `HARNESS_SCRIPTS`. **Ajouter un harnais, c'est ajouter un `.gd` et une ligne de table** — jamais une scène, jamais une intervention dans l'éditeur. `HARNESS` vide affiche le rapport de boot : version du moteur, contenu de `GameDatabase`, état de `RunManager`.

---

## Propriété des fichiers

| Chemin | Écrit par |
|---|---|
| `src/**/*.gd` | Claude Code |
| `data/**/*.tres` | Claude Code |
| `tests/**/*.gd` | Claude Code |
| `scenes/dev/*.gd` | Claude Code |
| `scenes/**/*.tscn` | **l'humain, dans l'éditeur** |
| `project.godot` | **l'humain, dans l'éditeur** |

**Claude Code n'écrit ni ne modifie jamais un `.tscn` ni `project.godot` à la main.** Les ids d'`ext_resource`, les `uid` et les chemins de nœuds y sont fragiles, et une erreur ne se manifeste qu'à l'ouverture dans l'éditeur.

Quand une scène ou un réglage de projet est nécessaire, Claude Code **décrit ce qu'il faut créer** — arbre de nœuds, types, propriétés, scripts à attacher — et s'arrête là. C'est l'humain qui le câble dans l'éditeur, puis confirme.

Les `.tres` sont exemptés : format plat, très peu référentiel, sans risque.

---

## Vérification avant de conclure

Aucune tâche n'est terminée tant que ces trois commandes ne passent pas. Les lancer soi-même, ne pas demander à l'humain de le faire.

`godot` n'est pas forcément dans le `PATH` : `GODOT_BIN` doit pointer sur le binaire épinglé, et sur Windows sur la variante `_console`, seule à écrire sur la sortie standard. Voir le README.

```bash
# 1. Boot réel — instancie les autoloads et charge la scène principale.
#    Seule passe qui résout les identifiants d'autoload, donc seule à valider
#    src/autoload/, src/adapters/ et scenes/dev/.
godot --headless --quit --path .

# 2. Parsing des scripts que le boot n'atteint pas — tout src/domain/.
#    --check-only compile hors contexte : à n'utiliser que là où aucun autoload
#    n'est référencé, ce que la règle de dépendance garantit déjà pour le domaine.
for f in $(find src/domain -name '*.gd'); do
  godot --headless --path . --check-only -s "res://$f" || echo "FAIL $f"
done

# 3. Suite de tests du domaine
addons/gdUnit4/runtest.sh -a tests --headless --ignoreHeadlessMode
```

Cinq pièges constatés en 4.7.2, à ne pas réapprendre :

- `--headless --quit` **échoue tant qu'aucune scène principale n'est définie**. C'est un vrai défaut de configuration, pas un faux positif à contourner.
- `--headless --editor --quit` ne signale les erreurs qu'au **premier** scan. Cache `.godot/` chaud, il repasse à 0 sur un projet cassé : inutilisable comme contrôle.
- `--check-only` échoue avec « Identifier not found » sur tout script référençant un autoload, même quand tout va bien. D'où la commande 1, et d'où la restriction de la commande 2 au domaine.
- `runtest.sh` refuse de démarrer sans `GODOT_BIN`, et refuse le mode headless sans `--ignoreHeadlessMode`.
- L'éditeur écrit ses références en `uid://`, résolues via `.godot/uid_cache.bin`. Tant que ce cache est en retard sur l'éditeur — typiquement juste après avoir créé une scène, éditeur encore ouvert —, la commande 1 échoue sur `Unrecognized UID: "uid://…"`. Ce n'est pas un projet cassé : une passe `godot --headless --editor --quit --path .` reconstruit le cache et la commande repasse. Ne pas confondre avec les erreurs réelles, et ne pas se servir de cette passe comme d'un contrôle (voir ci-dessus).

Si la sortie contient une erreur ou un warning de script, la tâche n'est pas finie. Ne jamais annoncer un travail terminé sur la seule base que le code « devrait » compiler.

---

## Autoloads

| Nom | Rôle |
|---|---|
| `EventBus` | Signaux typés globaux. Aucune logique, aucun état. Couche adapter uniquement — le domaine ne le connaît pas. |
| `GameDatabase` | Charge et indexe les `.tres` de `data/` au boot, par (catégorie, identifiant) où la catégorie est le sous-dossier. `get_balance()`, `get_resource(category, id)`, `list_ids(category)`, `list_categories()`. Les accesseurs typés par système — `get_building(id)` et consorts — s'ajoutent avec le système concerné. |
| `RunManager` | Possède le `RunState` courant, pilote le `DayCycle`, publie les résultats du domaine sur `EventBus`. C'est l'unique pont domaine → adapters. |

Le bus transporte des DTO immuables. Jamais une référence mutable sur un état du domaine.

---

## Décisions techniques figées

### Terrain — blocs étagés

- **Clé de grille : `Vector2i`.** La hauteur est un `int` sur la cellule, pas une troisième dimension de navigation. On ne passe à `Vector3i` que le jour où il y aura des ponts ou des tunnels.
- Une cellule = une colonne de hauteur `h`, pas de pentes, pas d'interpolation.
- `STEP_HEIGHT` et `TILE_SIZE` dans `data/balance/`.

### Rendu du terrain

**`MultiMeshInstance3D`**, une instance par cellule, `BoxMesh` unitaire mis à l'échelle en Y. Une passe pour le sol, une par type de décoration (forêt, rocher, gisement). Un seul draw call par matériau, couleur par instance via `set_instance_color`.

Pas de `GridMap` : il ne gère pas la hauteur variable par cellule sans empiler des cubes unitaires.

### Sélection de cellule

**Pas de collider, pas de physique.** Raycast analytique en DDA sur la grille de hauteurs, implémenté dans `domain/terrain/cell_picker.gd` comme fonction pure :

```gdscript
static func pick(grid: HeightGrid, origin: Vector3, dir: Vector3) -> PickResult
```

L'adapter caméra fournit `origin` et `dir` via `project_ray_origin` / `project_ray_normal`. Exact, testable, zéro `PhysicsServer`.

### Caméra

`CameraRig` (`Node3D`) → `Camera3D` enfant en `PROJECTION_ORTHOGONAL`.
- Rig : `rotation_degrees.x = -35.264` (isométrique vrai), `rotation_degrees.y` par pas de 90°, interpolé au `Tween`
- Zoom = `camera.size`
- Pan dans le plan XZ, corrigé de la rotation Y courante

L'occlusion par le relief est un problème connu du système Terrain. V1 : la rotation suffit. Fondu par shader plus tard si nécessaire.

### Structure de la journée — pilotée par data

`DayCycle` ne connaît ni « matin » ni « soir ». Une journée est une liste ordonnée de `PhaseDef` chargées depuis `data/balance/`, chacune déclarant ses types d'action autorisés et si une résolution se déclenche à sa fin. Aucun nom de phase ne doit apparaître en dur dans le code, ni dans le domaine ni dans les adapters — l'UI lit le libellé et les actions permises depuis la `PhaseDef` courante.

### Effectifs — un vivier ou deux, indécidé

Le système Effectifs projette ses unités en `LaborForce` et `CombatForce`. Économie et Combat ne consomment que ces projections. Aucun code hors de `domain/workforce/` ne doit supposer que les deux viennent de la même liste, ni qu'elles viennent de deux listes distinctes.

### Déterminisme

Tout l'aléatoire passe par `RunState.rng`, un `RandomNumberGenerator` seedé à l'ouverture du run. Jamais `randi()` global. Un seed plus une liste d'actions doit rejouer un run à l'identique — c'est ce qui rend l'équilibrage et le débogage possibles.

### Équilibrage

Tous les nombres réglables vivent dans `data/balance/*.tres`. Modifier un équilibrage ne doit jamais toucher à du GDScript. Corollaire : `data/balance/` est le seul endroit où l'on itère sur les questions encore ouvertes de `DESIGN.md`.

**Aucun `@export` de `src/schema/` ne porte de valeur par défaut.** Godot n'écrit pas dans un `.tres` une propriété égale à son défaut : en donner un fait remonter le chiffre dans le `.gd` dès le premier réenregistrement par l'éditeur, et le fichier de data se vide en silence sans que rien ne casse. Un champ non renseigné vaut donc `0`, ce qui est détectable — chaque `Resource` d'équilibrage expose `missing_fields() -> PackedStringArray`, `BalanceData` les agrège, et `GameDatabase` refuse de démarrer sur un champ vide. Le test `tests/schema/balance_data_test.gd` couvre la même chose sans figer aucun chiffre.

---

## Conventions de code

- Fichiers `snake_case.gd`, classes `PascalCase`, constantes `SCREAMING_SNAKE`, membres privés préfixés `_`
- `class_name` sur toute classe réutilisée
- Typage strict : paramètres, retours, membres. `enum` plutôt que `String` pour les états
- `StringName` (`&"lumberjack"`) pour tous les identifiants
- Ordre dans un script : `class_name` → `extends` → docstring → signals → enums → constants → `@export` → variables → `_ready` → publiques → privées
- Aucun nombre magique dans `domain/` : constante nommée ou champ de `Resource`
- Préconditions par `assert()`. Les erreurs récupérables retournent un DTO `{ ok: bool, reason: StringName }`, pas un `push_error`

---

## Tests

- Tout `src/domain/` est testé. `src/adapters/` ne l'est pas.
- Les tests instancient le domaine directement, sans arbre de scène ni `.tscn`.
- Priorité : `CellPicker`, `PlacementValidator`, `ProductionResolver`, `CombatResolver`, `Deck`.
- Un bug d'équilibrage se reproduit avec un seed et une séquence d'actions → en faire un cas de test.

---

## Git

- Branches : `feat/`, `fix/`, `balance/`, `refactor/`
- Commits en anglais, à l'impératif : `add dda cell picker`
- Un commit = une couche d'un système (contracts, puis domain, puis adapters). Pas les trois mélangés.

---

## Anti-patterns à refuser

- Logique métier dans `_process`, `_input` ou un script d'UI
- `get_node("../../UI/HUD")` — passer par `EventBus`
- Un système du domaine qui `preload` un autre système du domaine hors `contracts/`
- `EventBus` référencé depuis `src/domain/`
- Une nouvelle sous-classe de bâtiment — un bâtiment est une scène générique pilotée par une `BuildingData`
- `randf()` hors de `RunState.rng`
- Un chiffre d'équilibrage écrit en dur dans un `.gd`
- L'écriture ou la modification d'un `.tscn` ou de `project.godot`
- Un harnais de dev livré sous forme de fichier de scène plutôt que de script
- Une tâche annoncée terminée sans avoir lancé le contrôle de parsing et les tests
- Une feature hors périmètre sans mise à jour préalable de `DESIGN.md`
