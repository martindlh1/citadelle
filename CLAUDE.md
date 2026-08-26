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
| `TerrainQuery` | Terrain | Construction, Économie, Combat |
| `CitySnapshot` | Ville | Économie, Cartes, Combat |
| `PlacementResult` | Construction | adapters |
| `PlayedAction` | Cartes | Économie, adapters |
| `ActionPlan` | Cartes | Économie, adapters |
| `TargetResult` | Cartes | adapters |
| `Assignment` | Effectifs | Économie, Combat |
| `LaborForce` | Effectifs | Économie |
| `CombatForce` | Effectifs | Combat |
| `ProductionReport` | Économie | Effectifs (XP), adapters |
| `DamageReport` | Combat | Ville, Effectifs, Économie, adapters |

**`WaveDef` a quitté cette table à `F1`, et c'est une correction.** Elle y figurait depuis
`I0` comme un DTO de `contracts/` ; c'est une `Resource` de `src/schema/`, éditée dans
`data/waves/`, exactement comme `PhaseDef` décrit la forme d'une journée et `BuildingData`
un bâtiment. `contracts/` est l'endroit où deux systèmes **du code** se rencontrent ; un
contenu que l'on règle dans un `.tres` voyage déjà partout — le domaine reçoit ses blocs
d'équilibrage en argument depuis `E1`, et une `BuildingData` traverse tous les systèmes
dans un `BuildingSnapshot`. Le Combat reçoit donc sa vague comme le résolveur de chantiers
reçoit son `ActionBalance`.

L'Économie voit le relief depuis `D2`, et c'est la conséquence directe de la seconde
lecture de `DESIGN.md` 3.5 : une action jouée **à cru** rend ce que le tag de sa cellule
dicte, donc le résolveur doit pouvoir le lire. Il voit le contrat, jamais la grille.

**`Assignment` associe un ouvrier à une action posée, pas à un lieu.** Une ancre ne
suffisait plus à désigner sans ambiguïté ce qu'un ouvrier fait — *Terraformer* et
*Récolter* peuvent viser la même case nue.

**Un rapport reste chez son système tant qu'aucun autre ne le franchit.** `PickResult`
vit dans `domain/terrain/`, `ProgressReport` dans `domain/workforce/`, et `I1` y a rangé
`PlayResult`, `SiteReport`, `PhaseReport` et `DayReport` sous `domain/run/`. Le critère est un
second **système du domaine**, pas un adapter : les adapters lisent le domaine, c'est
leur métier. Le coût d'une promotion ultérieure est un déplacement de fichier ; le coût
d'une frontière inventée trop tôt est une forme figée avant qu'on la connaisse. Et une
frontière qui doit vraiment traverser se remarque : `PhaseReport` porte un
`ProgressReport`, ce qui l'aurait fait entrer dans `contracts/` en traînant un interne
des Effectifs derrière lui.

**`domain/run/` est le seul dossier autorisé à connaître les autres**, et c'est
`DESIGN.md` 3.8 qui l'autorise nommément. Il tient les états internes de tous les
systèmes ; aucun ne le connaît en retour.

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
│   ├── dev/                    # dev_boot.tscn (seule .tscn), un harnais .gd par système,
│   │                           # et le décor qu'ils partagent (dev_world.gd, dev_shot.gd)
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

Huit pièges constatés en 4.7.2, à ne pas réapprendre :

- `--headless --quit` **échoue tant qu'aucune scène principale n'est définie**. C'est un vrai défaut de configuration, pas un faux positif à contourner.
- `--headless --editor --quit` ne signale les erreurs qu'au **premier** scan. Cache `.godot/` chaud, il repasse à 0 sur un projet cassé : inutilisable comme contrôle.
- `--check-only` échoue avec « Identifier not found » sur tout script référençant un autoload, même quand tout va bien. D'où la commande 1, et d'où la restriction de la commande 2 au domaine.
- `runtest.sh` refuse de démarrer sans `GODOT_BIN`, et refuse le mode headless sans `--ignoreHeadlessMode`.
- L'éditeur écrit ses références en `uid://`, résolues via `.godot/uid_cache.bin`. Tant que ce cache est en retard sur l'éditeur — typiquement juste après avoir créé une scène, éditeur encore ouvert —, la commande 1 échoue sur `Unrecognized UID: "uid://…"`. Ce n'est pas un projet cassé : une passe `godot --headless --editor --quit --path .` reconstruit le cache et la commande repasse. Ne pas confondre avec les erreurs réelles, et ne pas se servir de cette passe comme d'un contrôle (voir ci-dessus).
- Le même retard frappe **le cache des classes globales**, et plus souvent : `.godot/global_script_class_cache.cfg` n'est écrit que par le scan de l'éditeur. Un `class_name` créé hors éditeur n'existe donc pour personne tant que ce scan n'a pas eu lieu, et la commande 1 échoue sur `Could not find type "X" in the current scope` alors que le fichier est parfaitement correct. Même remède : une passe `godot --headless --editor --quit --path .`. À faire après **chaque** ajout de `class_name`, donc à chaque nouveau fichier de `src/domain/` ou de `src/schema/`.
- **La commande 1 rend `0` même quand elle imprime des erreurs de script.** Son code de sortie ne dit rien de la santé du projet — un contrôle qui ne teste que `$?` laisse passer un projet dont un script ne compile pas. Il faut lire la sortie, toujours.
- **Un script lancé par `-s` n'a pas les autoloads.** `godot --headless --path . -s res://sonde.gd` échoue sur « Identifier not found: GameDatabase », exactement comme `--check-only`. C'est le mode qui sert à écrire une sonde jetable pour inspecter du data ou instancier du domaine ; il faut alors charger les `.tres` par `load()` et `DirAccess` plutôt que par l'index. Constaté à `I1`.

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

Ce que la décoration dessine se décrit dans `data/`, sur le `TerrainData` de la cellule, exactement comme sa couleur : le renderer ne commute jamais sur un identifiant de terrain. **Les dimensions y sont en fractions de tuile**, jamais en unités de monde — régler `tile_size` doit redimensionner la carte entière, décorations comprises.

**Aucune primitive à grande face verticale plate.** Le soleil de la scène n'éclaire que les surfaces tournées vers le haut ; toute face verticale ne reçoit que l'ambiante. Une face plate qui se présente à la caméra se lit alors comme un rectangle noir, et sous une caméra qui pivote par quarts de tour au-dessus d'un soleil fixe, aucune orientation n'y échappe. Les formes utilisables gardent un dégradé sous tous les angles — cône, sphère. Constaté à `T3` en essayant un `PrismMesh`, retiré le jour même.

*Ce paragraphe annonçait que les bâtiments, étant des boîtes, rencontreraient le même problème et qu'il faudrait déplacer le soleil.* **`C2` l'a vérifié en image : ce n'est pas arrivé.** Une boîte posée sur le relief garde ses quatre flancs lisibles, parce qu'elle présente à la lumière les mêmes orientations que les colonnes du terrain, qui se lisent bien depuis `T2`. Le piège du prisme venait de sa face oblique, pas du fait d'avoir des flancs verticaux. Ne pas « corriger » un problème qui ne se pose pas : si un jour une forme de bâtiment vire au noir, la constater d'abord en capture.

La dispersion d'une décoration — dérive, échelle, orientation — vient d'un **hash de la cellule**, jamais de `randf()` ni de `RunState.rng`. Une même carte doit se disperser pareil à chaque affichage, sans qu'une passe de rendu ait à transporter un flux de tirage.

Pas de `GridMap` : il ne gère pas la hauteur variable par cellule sans empiler des cubes unitaires.

### HUD — vues construites en code

Les vues de `src/adapters/hud/` sont des `Control` bâtis dans un `static func create()`, sans `.tscn`, comme `HandView` depuis `D2`. Elles reçoivent un objet du domaine et dessinent ; elles ne jugent rien. « La réserve est-elle pleine ? » se demande au domaine, et la vue affiche la réponse — **un adapter qui appellerait `Ledger.set_capacity()` serait la faute d'architecture que ce fichier refuse en premier.**

**Placer une vue dans un coin se fait par un conteneur, jamais par des ancres calculées.** `E2` a essayé les ancres et a payé deux pièges de suite, tous deux invisibles au parsing comme aux tests :

- `set_anchors_preset()` prend un **booléen** en second argument, là où `set_anchors_and_offsets_preset()` prend un `LayoutPresetMode`. Lui passer `PRESET_MODE_MINSIZE` revient à lui dire « garde tes décalages ». La vue reste à la taille qu'elle avait — zéro —, et **un `PanelContainer` de taille nulle ne dessine pas son fond** pendant que ses libellés débordent par-dessus la scène.
- `get_combined_minimum_size()` lu juste après avoir ajouté des enfants rend encore la valeur d'**avant** : Godot la recalcule à la passe de mise en page suivante. Une vue placée sur cette mesure se place donc toujours sur le contenu précédent.

Un `MarginContainer` plein écran dont l'enfant porte `SIZE_SHRINK_BEGIN` ou `SIZE_SHRINK_END` ne se trompe sur aucun des deux, et ne se trompe pas davantage à la dixième mise à jour du contenu.

**Une vue rafraîchie à chaque image met ses nœuds à jour sur place** plutôt que de les reconstruire. C'est ce qui permet de l'appeler depuis `_process` sans churn d'allocation, et surtout sans avoir à énumérer tous les gestes qui touchent son sujet — un oubli dans cette liste se lit comme un compteur qui ne bouge pas.

**Deux vues qui grandissent l'une vers l'autre vivent dans le même conteneur.** `W2` a posé le panneau d'affectation en bas à droite et laissé le compte rendu de phase en haut à droite : les deux tiennent tant que le plateau est vide, et se **recouvrent** dès qu'il porte cinq actions. Ce n'est pas une marge à régler — c'est un chevauchement qui n'attend que la phase la plus chargée, donc qui se manifeste le plus tard possible. Empilées dans un `VBoxContainer`, elles se poussent au lieu de se croiser.

**Et une liste qui suit la partie se borne.** Un HUD a une hauteur fixe, une phase peut poser un nombre quelconque d'actions : une liste sans plafond finit dehors. On en affiche un nombre nommé et on compte le reste sur une ligne. Corollaire : augmenter une marge basse **aggrave** le débordement au lieu de le corriger, parce qu'un conteneur trop petit pour son contenu le laisse déborder par le bas au lieu de le remonter.

**Une vue sur laquelle on clique porte `MOUSE_FILTER_STOP`**, à l'inverse des vues de lecture, qui laissent passer en `IGNORE` pour que le curseur de cellule continue de piocher dessous. Le geste tombe alors dans le `gui_input` de la vue et n'atteint jamais `_unhandled_input` du harnais, ce qui est exactement le partage voulu — sans quoi un clic sur une fiche jouerait aussi la carte tenue sur la case cachée derrière.

### Sélection de cellule

**Pas de collider, pas de physique.** Raycast analytique en DDA sur la grille de hauteurs, implémenté dans `domain/terrain/cell_picker.gd` comme fonction pure :

```gdscript
static func pick(grid: HeightGrid, metrics: TerrainMetrics,
        origin: Vector3, dir: Vector3) -> PickResult
```

L'adapter caméra fournit `origin` et `dir` via `project_ray_origin` / `project_ray_normal`. Exact, testable, zéro `PhysicsServer`.

La métrique est un argument et non un membre : le passage monde ↔ grille en dépend, et `T2` a sorti `tile_size` et `step_height` de `HeightGrid` pour les mettre dans `TerrainMetrics`. La fonction reçoit son réglage comme `TerrainGen.generate()` reçoit le sien. *(Cette signature portait trois paramètres jusqu'à `T3`, où elle s'est révélée inapplicable telle quelle.)*

Une colonne est **solide vers le bas et sans fond**. Le socle que le renderer dessine sous la carte n'est qu'une épaisseur d'affichage ; lui donner un fond ouvrirait des tirs qui passent sous la carte pour ressortir de l'autre côté. Un tir parti de sous le terrain le touche donc sur place.

### Caméra

`CameraRig` (`Node3D`) → `Camera3D` enfant en `PROJECTION_ORTHOGONAL`.
- Rig : `rotation_degrees.x = -35.264` (isométrique vrai), `rotation_degrees.y` par pas de 90°, interpolé au `Tween`
- Zoom = `camera.size`
- Pan dans le plan XZ, corrigé de la rotation Y courante

L'occlusion par le relief est un problème connu du système Terrain. V1 : la rotation suffit. Fondu par shader plus tard si nécessaire.

**Toute `DirectionalLight3D` éclairant cette caméra doit être en `SHADOW_ORTHOGONAL`**, jamais en cascades. Le défaut de Godot (`SHADOW_PARALLEL_4_SPLITS`, sans fondu) découpe l'ombre en quatre résolutions selon la profondeur : sous une caméra orthogonale, où la profondeur croît linéairement du bas vers le haut de l'écran, ces frontières deviennent des **lignes horizontales fixes à l'écran**, floues d'un côté et nettes de l'autre, que le terrain traverse quand on déplace la vue. Les cascades servent à couvrir un horizon lointain ; ici la scène est bornée. Serrer aussi `directional_shadow_max_distance` sur ce que la caméra voit vraiment — l'étaler au-delà ne fait que diluer les texels. Constaté à `T2`.

### Structure de la journée — pilotée par data

`DayCycle` ne connaît ni « matin » ni « soir ». Une journée est une liste ordonnée de `PhaseDef` chargées depuis `data/balance/`, chacune déclarant ses types d'action autorisés et si une résolution se déclenche à sa fin. Aucun nom de phase ne doit apparaître en dur dans le code, ni dans le domaine ni dans les adapters — l'UI lit le libellé et les actions permises depuis la `PhaseDef` courante.

*(Écrit à `I1`.)* La règle vaut aussi pour **les tests** : un cas qui écrirait `&"evening"` pour vérifier une règle figerait exactement ce que `DESIGN.md` 2 garde ouvert. Les suites fabriquent leurs propres journées, sur des noms qui n'existent dans aucun `.tres`.

`resolves` est un booléen, donc le seul champ de tout `data/balance/` que la doctrine du zéro ne protège pas : effacé par un réenregistrement, il vaut faux sans que rien ne le dise. Le filet est posé un cran plus haut — `RunBalance` exige qu'**au moins une** phase de la journée résolve. Même geste que `C4` sur `build_actions`.

**Une phase résout, une journée ferme, et ce sont deux choses.** Une phase produit ce que les actions posées rapportent ; une journée prélève l'upkeep, et demain l'événement et le combat. La fin de journée n'est **pas** un champ de `PhaseDef` : c'est la fin de la dernière phase, par définition, et un booléen en data pourrait dire le contraire de la liste qui le porte. Elle ne dépend pas non plus de `resolves` — une journée coûte à nourrir même si sa dernière phase ne produit rien. Écrire quoi que ce soit qui fasse manger une fois par phase reviendrait à rendre la structure de la journée inséparable de son équilibrage, ce que `DESIGN.md` 2 veut précisément pouvoir échanger séparément.

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
- Ne jamais trier un `Array[StringName]` avec `sort()` : comparer deux `StringName` compare leurs pointeurs internes, pas leur texte. L'ordre obtenu est arbitraire, stable le temps d'une session et différent à la suivante — un piège direct pour le déterminisme. Trier par `sort_custom` sur `String(...)`.

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
