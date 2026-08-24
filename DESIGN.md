# DESIGN.md — Citadelle *(titre de travail)*

> **Statut du document.** Les chiffres sont des hypothèses de départ, pas des cibles. Les sections marquées **`OUVERT`** sont des décisions volontairement repoussées : elles seront tranchées par itération, une fois le système concerné jouable isolément. Aucun de ces choix ne doit remonter dans un contrat inter-systèmes.

---

## 1. Pitch

City-builder roguelite en 3D isométrique sur grille en relief. Chaque jour se joue en deux phases : le matin on bâtit avec une main de cartes tirée au hasard, le soir on répartit une main-d'œuvre limitée entre production et défense. Périodiquement, une vague attaque le village et mesure la qualité de ce qui a été construit.

La tension centrale est le **pool d'ouvriers** : un ouvrier en milice ne récolte rien, et les ouvriers ne sont pas interchangeables — ils ont des compétences qui progressent. Envoyer son meilleur récoltant au combat coûte deux fois.

**Références** — *Against the Storm* (boucle roguelite + city-builder), *Slay the Spire* (main, draft, deck), *Islanders* / *Dorfromantik* (lisibilité du relief en blocs, plaisir du placement), *Battle Brothers* (attachement à un roster nommé qui progresse et qui meurt).

---

## 2. Boucle de jeu

**Run** → génération de carte → pose du Cœur → suite de journées → vague finale.

### `OUVERT` — la structure de la journée

Deux modèles sur la table, aucun n'est tranché.

**Deux phases symétriques**, matin et soir, à la *Dead in Vinland*. Chaque phase est un temps d'affectation identique : on joue deux fois par jour. On peut réagir en cours de journée à ce qui vient d'être révélé, et ça ouvre naturellement une mécanique de fatigue — enchaîner les deux phases épuise. Risque : deux phases identiques deviennent une corvée si rien ne change entre les deux. Il faut donc que quelque chose se résolve, se révèle ou se dégrade au milieu de la journée pour justifier la seconde décision.

**Deux phases asymétriques**, construction puis résolution. Rythme plus net, deux types de décision distincts au lieu d'un seul répété, et nettement moins de clics sur la durée d'un run. On perd la réactivité intra-journée.

**Conséquence sur l'implémentation.** Le `DayCycle` ne code ni « matin » ni « soir » en dur. Une journée est une **liste ordonnée de `PhaseDef`** définies en data, chaque phase déclarant les types d'action autorisés — bâtir, affecter, échanger, piocher — et si une résolution se déclenche à sa fin. Les deux modèles ci-dessus deviennent deux fichiers `.tres`, et on peut en tester un troisième sans toucher au code.

### Séquence de résolution

Quel que soit le modèle retenu, une phase qui résout le fait dans cet ordre : production → événement → upkeep → combat s'il y a lieu → gain d'XP → rapport.

**`OUVERT`** — durée d'un run, fréquence des vagues, sort de la main non jouée.

---

## 3. Systèmes

Chaque système est développé et testé isolément. Le contrat est la seule chose que les autres systèmes connaissent de lui.

### 3.1 Terrain

> **Contrat** — expose `TerrainQuery` : hauteur, type et constructibilité d'une cellule, planéité d'une zone. Aucun autre système ne connaît la représentation interne.

Grille de cellules `Vector2i`, chacune portant une hauteur entière et un `TerrainData`. Rendu en **blocs étagés** : une cellule = une colonne, pas de pentes. Génération procédurale seedée produisant du relief, de l'eau en contrebas et des gisements.

| Terrain | Constructible | Tag |
|---|---|---|
| Plaine | oui | — |
| Forêt | oui, déblaie l'arbre | `forest` |
| Gisement | oui | `stone` |
| Eau | non | `water` |
| Rocher | non | `blocker` |

La caméra tourne par pas de 90°, ce qui est l'intérêt du vrai 3D par rapport à des vues pré-rendues. L'occlusion d'un bâtiment par une colline est un problème de ce système et de lui seul.

**Le relief contraint la construction.** *(Tranché à `C1`.)* Un bâtiment exige toutes ses cellules à la même hauteur — la règle est universelle et ne se règle pas par bâtiment. Le relief n'est donc pas décoratif : c'est lui qui décide où le village peut s'étendre, et c'est ce qui donne à un plateau sa valeur.

**`OUVERT`** — le relief joue-t-il *autrement* sur le gameplay ? Trois pistes non exclusives restent entières : avantage défensif en hauteur, accès aux ressources selon l'altitude, et **terrassement** — payer pour aplanir un dénivelé plutôt que de subir la contrainte ci-dessus. Le contrat expose déjà hauteur et planéité, donc les trois restent ouvertes sans refonte.

### 3.2 Construction

> **Contrat** — reçoit `CityState` + `BuildingData` + cellule d'ancrage, rend un `PlacementResult` et mute l'état. Interroge le Terrain en lecture seule.

Validation du placement : empreinte entière dans la carte, cellules libres, terrain constructible, toutes les cellules à la même hauteur *(cf. 3.1)*.

**Le coût n'en fait pas partie.** « Ai-je les 15 bois ? » ne regarde pas la carte, et le contrat ci-dessus ne reçoit aucune bourse. C'est la couche qui orchestre la journée qui pose les deux questions à la suite — placement valide *et* payable. Voir 3.3.

Une empreinte est une **liste de cellules relatives à une ancre**, pas nécessairement un rectangle : les formes en L, en T ou en croix sont exprimables, et un rectangle n'est qu'un cas particulier. L'ancre appartient toujours à l'empreinte. Les autres cellules couvertes stockent une référence vers elle.

**Adjacence** — c'est la couche d'optimisation du jeu. Chaque bâtiment porte des règles de la forme *« +X de rendement par voisin taggé Y dans un rayon Z »*. Le système doit exposer un calcul de prévisualisation appelable pendant le placement fantôme : sans retour visuel en temps réel du delta, le système d'adjacence est invisible, donc inexistant.

### 3.3 Économie

> **Contrat** — `CitySnapshot` + `Assignment` + `LaborForce` → `ProductionReport`. Ne connaît ni la grille ni les Node : tout lui est fourni.

Stocks de ressources plafonnés, résolution de la production par slot occupé, application des modificateurs d'adjacence, upkeep en nourriture, famine si le stock ne couvre pas le roster.

Le plafond de stockage est délibéré : il punit la thésaurisation et force la dépense.

**Hypothèse de départ** — trois ressources : bois (construction), pierre (avancé et défense), nourriture (upkeep). Plafond 100, +100 par entrepôt. Upkeep 1 nourriture par ouvrier et par soir.

**`OUVERT`** — nombre de ressources, existence d'une ressource de conversion type outils ou or.

### 3.4 Effectifs — main-d'œuvre et combattants

> **Contrat** — le système expose une `LaborForce` à l'Économie et une `CombatForce` au Combat, et consomme les rapports en retour pour distribuer XP, blessures et pertes. **Ni l'Économie ni le Combat ne savent d'où viennent ces effectifs.** Qu'il y ait un vivier ou deux est un détail interne, ce qui rend la question ci-dessous entièrement reportable.

Un effectif n'est pas un compteur. Chaque unité est un individu nommé, avec :

- des **pistes de compétence** par famille — Récolte, Artisanat, Combat — qui gagnent de l'XP à l'usage et donnent un multiplicateur d'efficacité
- éventuellement des **traits**, acquis ou de naissance, qui donnent des bonus conditionnels plutôt que des chiffres bruts

Ce qui en découle : spécialiser rend excellent à un poste et médiocre ailleurs, et une unité expérimentée perdue est une vraie perte. C'est ce qui donne au roguelite sa charge émotionnelle.

#### `OUVERT` — un vivier ou deux ?

**Vivier unique.** Les ouvriers sont aussi les combattants. Le compromis est direct et personnel : envoyer son meilleur récoltant en milice coûte la production du soir *et* risque sa vie. C'est la version la plus tendue et la plus lisible. Limite : si le combat devient un vrai système tactique, un paysan sans équipement y est soit inutile, soit il faut immobiliser toute l'économie pour tenir une ligne.

**Deux viviers séparés**, à la *As We Descend*. Les combattants se recrutent et progressent par une voie propre. Le combat gagne son axe de progression sans polluer l'économie, et chaque côté s'équilibre indépendamment. Le compromis se déplace au niveau des ressources — investir dans l'armée ou dans la ville — plutôt qu'au niveau des personnes. On perd un peu du « mon meilleur fermier est mort hier soir », sauf à donner aussi noms et XP aux soldats.

**Piste hybride.** Une garnison dédiée, petite et spécialisée, plus un levier de **conscription** qui arme des ouvriers en urgence, cher et risqué. On garde la tension du vivier unique en en faisant une décision exceptionnelle plutôt qu'un arbitrage quotidien, et le combat garde ses spécialistes.

Cette question est adossée à celle du format de combat (3.6) : plus le combat devient tactique et contrôlé, plus deux viviers se justifient. À trancher après `F2`, pas avant.

#### Risque identifié — le micro-management

Des effectifs à quinze, sur deux phases, pendant quinze jours, c'est plusieurs centaines de décisions par run dont la plupart sont évidentes. Mitigations à prévoir dès la conception de l'UI : effectifs volontairement réduits, bouton d'auto-affectation avec surcharge manuelle, affectation persistante d'une phase à l'autre par défaut. C'est du travail d'adapter, pas de domaine. Ce risque augmente mécaniquement si le modèle à deux phases symétriques est retenu.

**`OUVERT`** — taille des effectifs, granularité (statistiques chiffrées visibles vs traits qualitatifs), recrutement (croissance passive, événement, carte ?).

### 3.5 Cartes

> **Contrat** — `Deck` rend une main et des intentions de jeu. Ne connaît ni la grille, ni les ressources, ni le placement. Jouer une carte est une intention que le système Construction accepte ou refuse.

Deck de départ fixe, pioche d'une main chaque matin, défausse, remélange quand le deck est vide. Draft entre les runs et après les jalons de progression : ajouter une carte parmi plusieurs, en retirer une définitivement, ou une récompense alternative.

**`OUVERT`** — taille de la main et du deck, sort des cartes non jouées en fin de matin. Défausser toute la main crée de la tension et empêche la thésaurisation, mais frustre quand on pioche trois bâtiments impayables. Alternatives à tester : conserver une carte, défausser contre une petite ressource, ou main persistante avec limite de jeu par tour. Décision reportée après le premier playtest de la boucle complète.

### 3.6 Combat

> **Contrat** — `CitySnapshot` + `CombatForce` + `WaveDef` → `DamageReport`. C'est **le seul** contrat qui compte. Tout ce qui se passe entre les deux est remplaçable sans toucher au reste du jeu.

Format non arrêté. Les pistes envisagées — tower-defense sur la grille du village, auto-battler observé, tactique au tour par tour dans une vue dédiée — ont toutes le même contrat d'entrée et de sortie.

**Stratégie de développement.** Une première implémentation `InstantCombatResolver`, purement arithmétique et sans vue, sert de bouchon pour boucler la boucle de jeu au plus tôt. Le vrai système de combat, avec sa propre vue et sa propre scène, se développe ensuite en parallèle du reste, dans `scenes/dev/combat_test.tscn`, alimenté par des `CitySnapshot` fabriqués à la main. Le jour où il est prêt, on échange l'implémentation dans l'orchestrateur : une ligne.

Le `DamageReport` doit couvrir dès maintenant les cas dont les autres systèmes ont besoin : bâtiments détruits ou endommagés, pertes et blessures parmi les effectifs engagés, XP de combat gagnée, ressources pillées.

**`OUVERT`** — à peu près tout : format, vue, durée, degré de contrôle du joueur, direction et nature des vagues, rôle du relief. C'est `F2` qui tranchera, et cette décision entraîne celle du vivier unique ou double (3.4).

### 3.7 Événements

> **Contrat** — un modificateur tiré chaque soir, appliqué avant ou après la production selon son type.

Source d'aléatoire quotidien indépendante de la pioche. Pistes : arrivée d'ouvriers, tempête qui détruit une défense, filon révélé, disette, caravane marchande, éclaireur qui révèle la prochaine vague.

### 3.8 Cycle de jour

> Le seul système qui connaît tous les autres. C'est volontaire : il orchestre, les autres s'ignorent.

Machine à états sur les deux phases, séquence de résolution du soir, conditions de fin, transition vers l'écran de récompense.

---

## 4. Contenu de départ

Dix bâtiments suffisent pour valider les boucles. Chiffres à prendre comme point de départ d'équilibrage, pas comme cible.

| Bâtiment | Coût | Slots | Rendement / slot | Déf. | PV | Adjacence |
|---|---|---|---|---|---|---|
| Cœur | posé au départ | 0 | — | 0 | 30 | — |
| Cabane de bûcheron | 0 | 2 | +2 bois | 0 | 4 | +1 bois par `forest` voisine |
| Carrière | 15 bois | 2 | +2 pierre | 0 | 6 | requiert `stone` voisin, +2 pierre |
| Ferme | 10 bois | 2 | +3 nourriture | 0 | 4 | +1 par `water` voisine, +1 par ferme |
| Habitation | 20 bois | 0 | +2 places de roster | 0 | 5 | −1 par voisin `industry` |
| Palissade | 5 bois | 0 | — | 3 | 3 | +1 déf. par palissade voisine |
| Tour de guet | 15 bois, 10 pierre | 1 | +8 déf. si occupée | 8 | 10 | bonus de hauteur ? *(cf. 3.1)* |
| Entrepôt | 20 bois | 0 | +100 de plafond | 0 | 6 | +1 rendement aux producteurs voisins |
| Atelier | 25 bois, 15 pierre | 1 | +1 rendement aux producteurs dans un rayon 2 | 0 | 8 | tag `industry` |
| Marché | 30 bois | 1 | 2 échanges 3:1 par soir | 0 | 6 | — |

---

## 5. Fin de run

- **Défaite** — Cœur détruit, ou roster vide
- **Victoire** — dernière vague survécue
- **Score** — ressources, bâtiments intacts, ouvriers vivants et leur niveau

---

## 6. Méta-progression *(après le MVP)*

Déblocage de cartes dans le pool de draft, gouverneurs de départ avec deck et bonus modifiés, biomes aux paramètres de génération distincts, modificateurs de difficulté cumulatifs.

---

## 7. Hors périmètre

- Citoyens simulés individuellement dans le monde — le roster est une liste de fiches, pas des agents qui marchent
- Routes, logistique, transport de ressources
- Ponts, tunnels, superposition verticale — le relief reste une hauteur par cellule
- Sauvegarde en cours de run — seule la méta persiste
- Son, art final, animations

Toute demande d'ajout passe d'abord par une mise à jour de ce document.

---

## 8. Jalons

Le développement est par système, pas linéaire. Chaque système avance dans sa scène de dev jusqu'à tenir debout seul. Le fil d'intégration ne fait que brancher ce qui est déjà prêt.

### Terrain — `T`
- **T1** — `HeightGrid`, génération seedée, tests. Aucun rendu.
- **T2** — Rendu `MultiMeshInstance3D` en blocs étagés, `CameraRig` isométrique avec rotation 90° et zoom.
- **T3** — `CellPicker` en DDA, surbrillance de la cellule survolée, décorations de terrain.
- **T4** — Traitement de l'occlusion, si le playtest montre que c'est un problème réel.

### Construction — `C`
- **C1** — `CityState`, `PlacementValidator`, empreintes, tests. Sans rendu.
- **C2** — Fantôme de placement, pose et destruction dans la scène de dev.
- **C3** — Règles d'adjacence + prévisualisation du delta au survol.

### Économie — `E`
- **E1** — `Ledger`, `ProductionResolver`, upkeep, famine, tests.
- **E2** — HUD des ressources, panneau de rapport de production.

### Effectifs — `W`
- **W1** — unité individuelle, pistes de compétence, XP, `Assignment`, projection en `LaborForce` et `CombatForce`, tests. Écrit pour rester valable avec un vivier comme avec deux.
- **W2** — Panneau d'affectation, fiches d'unité, auto-affectation.

### Cartes — `D`
- **D1** — `Deck`, `Hand`, défausse, remélange, draft, tests.
- **D2** — Main à l'écran, jouer une carte émet une intention de placement.

### Combat — `F`
- **F1** — `InstantCombatResolver` arithmétique, `DamageReport` complet, tests. Bouchon.
- **F2** — Prototype du vrai combat dans `scenes/dev/combat_test.tscn`, sur snapshots fabriqués. *Format à définir.*
- **F3** — Vue de combat intégrée, échange de l'implémentation dans l'orchestrateur.

### Intégration — `I`
- **I0** — Squelette : projet, arborescence, autoloads, `EventBus`, `GameDatabase`, scène de dev vide.
- **I1** — Boucle minimale : Terrain + Construction + Économie branchés, une journée en deux phases.
- **I2** — Boucle complète : Cartes + Main-d'œuvre + Combat bouchon, run jouable du début à la fin.
- **I2b** — Playtest de la boucle : arbitrage de la **structure de journée** (2.) et du sort de la main non jouée (3.5). Les deux se testent en échangeant un `.tres`.
- **I3** — Passe de contenu et d'équilibrage : dix bâtiments, pool d'événements, courbe de difficulté, **arbitrage des `OUVERT`** restants.

**Ordre de démarrage suggéré** — `I0`, puis `T1→T3`, puis `C1→C2`, puis `I1`. Terrain d'abord parce qu'il ne dépend de rien et qu'il donne le premier retour visuel ; `E1`, `W1`, `D1` et `F1` sont écrits sans aucune dépendance et peuvent s'intercaler à tout moment.

Le jeu devient jouable à `I2`. Tout ce qui suit est de l'enrichissement.
