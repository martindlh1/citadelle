# DESIGN.md — Citadelle *(titre de travail)*

> **Statut du document.** Les chiffres sont des hypothèses de départ, pas des cibles. Les sections marquées **`OUVERT`** sont des décisions volontairement repoussées : elles seront tranchées par itération, une fois le système concerné jouable isolément. Aucun de ces choix ne doit remonter dans un contrat inter-systèmes.
>
> Les sections marquées **`HORS MVP`** décrivent des systèmes qui ne seront pas écrits avant que la boucle soit jouable. Elles figurent ici pour une raison précise : **elles contraignent l'abstraction d'aujourd'hui.** On n'écrit pas leur code, mais on n'écrit rien qui les rende impossibles.

---

## 1. Pitch

City-builder roguelite en 3D isométrique sur grille en relief. On joue une **main de cartes** avec une **main-d'œuvre limitée** : les cartes disent ce qu'on peut faire, les ouvriers disent combien on peut en faire. Périodiquement, une vague attaque le village et mesure la qualité de ce qui a été construit.

La tension centrale est le **pool d'ouvriers**, et elle a deux étages. Le premier est quantitatif : un ouvrier en milice ne récolte rien. Le second est qualitatif, et c'est lui qui compte — les ouvriers ne sont **pas interchangeables**, ils ont des compétences qui progressent, et c'est *qui* on envoie qui décide du rendement. Envoyer son meilleur récoltant au combat coûte deux fois.

**Références** — *Against the Storm* (boucle roguelite + city-builder), *Slay the Spire* (main, draft, deck ; cartes et énergie comme deux contraintes distinctes), *Islanders* / *Dorfromantik* (lisibilité du relief en blocs, plaisir du placement), *Battle Brothers* (attachement à un roster nommé qui progresse et qui meurt).

---

## 2. Boucle de jeu

**Run** → génération de carte → pose du Cœur → suite de journées → vague finale.

### `OUVERT` — la structure de la journée

Deux modèles sur la table, aucun n'est tranché.

**Deux phases symétriques**, matin et soir, à la *Dead in Vinland*. Chaque phase est un temps d'affectation identique : on joue deux fois par jour. On peut réagir en cours de journée à ce qui vient d'être révélé, et ça ouvre naturellement une mécanique de fatigue — enchaîner les deux phases épuise. Risque : deux phases identiques deviennent une corvée si rien ne change entre les deux. Il faut donc que quelque chose se résolve, se révèle ou se dégrade au milieu de la journée pour justifier la seconde décision.

**Deux phases asymétriques**, construction puis résolution. Rythme plus net, deux types de décision distincts au lieu d'un seul répété, et nettement moins de clics sur la durée d'un run. On perd la réactivité intra-journée.

**Conséquence sur l'implémentation.** Le `DayCycle` ne code ni « matin » ni « soir » en dur. Une journée est une **liste ordonnée de `PhaseDef`** définies en data, chaque phase déclarant les types d'action autorisés — bâtir, affecter, échanger, piocher — et si une résolution se déclenche à sa fin. Les deux modèles ci-dessus deviennent deux fichiers `.tres`, et on peut en tester un troisième sans toucher au code.

### Séquence de résolution

Quel que soit le modèle retenu, une phase qui résout le fait dans cet ordre : **actions jouées** → événement → upkeep → combat s'il y a lieu → gain d'XP → rapport.

La production n'est plus une étape passive qui balaye les bâtiments : c'est le résultat des actions que le joueur a posées. Un bâtiment dont aucun slot n'a reçu d'action ne rend rien.

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
| Filon | oui | `ore` |
| Eau | non | `water` |
| Rocher | non | `blocker` |

La caméra tourne par pas de 90°, ce qui est l'intérêt du vrai 3D par rapport à des vues pré-rendues. L'occlusion d'un bâtiment par une colline est un problème de ce système et de lui seul.

**Le relief contraint la construction.** *(Tranché à `C1`.)* Un bâtiment exige toutes ses cellules à la même hauteur — la règle est universelle et ne se règle pas par bâtiment. Le relief n'est donc pas décoratif : c'est lui qui décide où le village peut s'étendre, et c'est ce qui donne à un plateau sa valeur.

**Le terrassement existe, et c'est une carte.** *(Tranché avant `E1b`.)* L'action *Terraformer* dépense de la force ouvrière pour monter ou descendre une case d'un cran. C'est la réponse à la contrainte ci-dessus : le relief n'est plus subi, il se paie. Et comme c'est une action et non un bouton, elle entre en concurrence avec récolter et bâtir dans la même main — ce qui est exactement le genre d'arbitrage qu'on cherche.

Les **tags de terrain** cessent d'être décoratifs avec les actions : c'est eux qui décident où une action à cru peut se jouer. *Récolter* sur une case `forest` rend du bois sans qu'aucun bâtiment existe.

**`OUVERT`** — le relief joue-t-il encore *autrement* ? Deux pistes restent entières : avantage défensif en hauteur, et accès aux ressources selon l'altitude. Le contrat expose déjà hauteur et planéité, donc les deux restent ouvertes sans refonte.

### 3.2 Construction

> **Contrat** — reçoit `CityState` + `BuildingData` + cellule d'ancrage, rend un `PlacementResult` et mute l'état. Interroge le Terrain en lecture seule. Expose en plus l'état d'avancement des chantiers, que le `CitySnapshot` transporte.

Validation du placement : empreinte entière dans la carte, cellules libres, terrain constructible, toutes les cellules à la même hauteur *(cf. 3.1)*.

**Le coût n'en fait pas partie.** « Ai-je les 15 bois ? » ne regarde pas la carte, et le contrat ci-dessus ne reçoit aucune bourse. C'est la couche qui orchestre la journée qui pose les deux questions à la suite — placement valide *et* payable. Voir 3.3.

Une empreinte est une **liste de cellules relatives à une ancre**, pas nécessairement un rectangle : les formes en L, en T ou en croix sont exprimables, et un rectangle n'est qu'un cas particulier. L'ancre appartient toujours à l'empreinte. Les autres cellules couvertes stockent une référence vers elle.

**Un bâtiment se pose dans l'une de quatre orientations**, par quarts de tour, comme la caméra. L'orientation appartient au *placement* et non au bâtiment : une même `BuildingData` se pose dans les quatre sens, et rien dans `data/` ne la décrit. Une empreinte symétrique — le 1×1, le carré — rend simplement les quatre identiques, sans cas particulier à écrire.

La rotation se fait **autour de la cellule d'ancrage**, qui est donc invariante : la forme pivote sous le curseur au lieu de sauter à côté, et l'ancre ne peut pas sortir de sa propre empreinte. C'est ce qui rend l'orientation gratuite pour tout le reste du système — les deux index de la ville, la validation et le rendu ne voient qu'une liste de cellules, sans savoir d'où elle vient.

#### Un bâtiment posé n'est pas un bâtiment fini

**Poser une carte de bâtiment ouvre un chantier**, pas un bâtiment. Le chantier occupe ses cellules et paie son coût tout de suite, mais il ne produit rien, n'offre aucun slot et ne débloque aucune action. Il faut lui jeter des actions *Construire* dessus, autant que sa `BuildingData` en réclame, pour qu'il devienne un vrai bâtiment.

Trois raisons de le vouloir :

- **La construction cesse d'être gratuite en temps.** Un bâtiment cher n'est plus seulement un mur de ressources, c'est un investissement de main-d'œuvre étalé — et pendant ce temps ces ouvriers ne récoltent pas.
- **Ça donne à *Construire* une raison d'exister** comme carte, donc au deck une tension de plus : piocher un bâtiment sans les *Construire* pour le finir est une vraie situation.
- **Ça rend une vague plus mordante.** Un chantier à moitié fini détruit la veille de la vague, c'est le genre de perte qui se raconte.

Un chantier est donc un **état du bâtiment posé**, pas un type de bâtiment à part : `CityState` en garde l'avancement, et `CitySnapshot` le dit à qui le consomme. L'Économie ignore un bâtiment inachevé ; le Combat, lui, peut très bien le voir.

*(Écrit à `C4`.)* Cette dernière phrase est devenue une ligne de contrat plutôt qu'une consigne : `CitySnapshot` expose **deux lectures** — `buildings()` rend tout, chantiers compris, et `completed()` ne rend que les finis. Trois consommateurs posent exactement la seconde question — les postes de production, la réserve que les entrepôts relèvent, les places que les habitations ajoutent —, et le Combat posera la première. Laisser chacun recopier son filtre l'aurait fait oublier au quatrième, et l'oubli aurait été silencieux : un entrepôt en chantier qui relève quand même la réserve ne casse rien, il ment.

**`OUVERT`** — que rend un chantier détruit ou annulé ? Rien, une partie du coût, tout ? Et un chantier peut-il être abandonné volontairement pour récupérer la case ? `C4` n'y a pas touché : détruire un chantier libère ses cellules et ne rend rien, ce qui est l'état par défaut et non une réponse.

**`OUVERT`** — quelle piste de compétence l'action *Construire* crédite-t-elle ? Aucune des trois familles de 3.4 — Récolte, Artisanat, Combat — ne la couvre. La question est apparue à `C4`, qui ne la tranche pas : elle appartient à `D2`, où *Construire* deviendra une carte jouée par un ouvrier nommé, et elle a trois issues — une quatrième famille, un rattachement à l'Artisanat, ou de l'XP de niveau seule, ce que 3.4 rend déjà possible.

#### Adjacence

C'est la couche d'optimisation du jeu. Chaque bâtiment porte des règles de la forme *« +X de rendement par voisin taggé Y dans un rayon Z »*. Le système doit exposer un calcul de prévisualisation appelable pendant le placement fantôme : sans retour visuel en temps réel du delta, le système d'adjacence est invisible, donc inexistant.

### 3.3 Économie

> **Contrat** — `TerrainQuery` + `CitySnapshot` + `ActionPlan` + `Assignment` + `LaborForce` → `ProductionReport`. Ne connaît ni la grille ni les Node : tout lui est fourni.

*(Le contrat a gagné deux entrées à `D2`, et elles se justifient l'une l'autre.)* L'**`ActionPlan`** est le pilote : la phrase de 2 — « un bâtiment dont aucun slot n'a reçu d'action ne rend rien » — n'était pas vraie tant que le résolveur balayait les ancres de l'affectation et servait le rendement du bâtiment qu'il y trouvait, sans qu'aucune carte n'ait eu à être jouée. Elle l'est maintenant par construction. Le **`TerrainQuery`** vient avec la seconde lecture de 3.5 : une action jouée à cru rend ce que le **tag de sa cellule** dicte, donc l'Économie doit voir le relief — le contrat, jamais la grille.

Stocks de ressources sous réserve commune, résolution des actions jouées, application des modificateurs d'adjacence, upkeep en nourriture, famine si le stock ne couvre pas le roster.

Le plafond de stockage est délibéré : il punit la thésaurisation et force la dépense.

**C'est une réserve commune, et non un plafond par ressource.** *(Tranché à `E1`.)* Les cent unités sont partagées entre toutes les ressources : remplir sa réserve de bois, c'est renoncer à stocker de la pierre. C'est la plus mordante des deux lectures, et celle qui donne à l'entrepôt une valeur d'arbitrage au lieu d'un simple relèvement de compteurs indépendants. Le plafond ne force plus seulement à dépenser, il force à choisir *quoi* garder.

Conséquence directe, et c'est le prix de ce choix : une récolte qui déborde doit décider **lesquelles** de ses ressources entrent. La répartition est **proportionnelle à ce que le soir a produit**, et jamais fonction de l'ordre des bâtiments — deux villes identiques bâties dans un ordre différent doivent perdre exactement la même chose.

**L'ensemble des ressources vit dans `data/`**, un fichier par ressource, et non dans une énumération du code. C'est ce qui rend leur nombre réglable sans toucher à du GDScript, et ce qui permet de refuser au démarrage un coût qui nommerait une ressource inexistante.

**Quatre ressources** — nourriture (upkeep), bois (construction), pierre (avancé et défense), minerai (bâtiments tardifs et, plus tard, artisanat). Réserve commune 100, +100 par entrepôt. Upkeep 1 nourriture par ouvrier et par soir, **oisifs compris** — c'est ce qui rend un ouvrier non affecté coûteux, et le pool tendu.

**La famine se constate, elle ne se punit pas encore.** *(Tranché à `E1`.)* La résolution vide ce qui reste de nourriture et rapporte combien d'ouvriers n'ont pas mangé. Ce qu'il leur arrive ensuite appartient aux Effectifs, qui possèdent les unités.

#### Ce qu'un bâtiment déclare produire

*(Tranché avant `E1b`, écrit à `E1b`.)* Un bâtiment ne porte pas de champs de production en vrac. Il porte un **bloc `production` nullable** : ou bien il produit, et le bloc dit tout — slots, famille de compétence, rendement —, ou bien il ne produit pas et le bloc est absent. L'entrepôt et l'habitation n'ont pas « zéro slot », ils n'ont **pas de bloc**.

Deux bénéfices immédiats. La cohérence devient **structurelle** au lieu d'être vérifiée : il n'est plus possible d'écrire des slots sans rendement, ou un poste sans famille, parce que les trois vivent ou meurent ensemble. Et le jour où un bâtiment produit *autrement* — au voisinage, à l'événement, au palier —, le bloc devient une classe de base et le résolveur commute sur son type.

**La règle qui décide où va le code.** Ajouter un **bâtiment** doit rester une édition de `data/`. Ajouter une **nature** de bâtiment est légitimement une modification de code — mais dans `src/domain/`, jamais dans le schéma ni dans la data. Une `Resource` qui porterait une méthode de résolution serait du domaine déguisé, et le jour où il lui faut le terrain, la ville et le roster, on aurait recodé le résolveur dans `src/schema/`.

**`OUVERT`** — la conséquence de la famine. Perte d'efficacité le lendemain, blessure, départ, mort ? Le rapport de production porte déjà le compte des non-nourris : les quatre restent ouvertes sans que le contrat bouge.

**`HORS MVP` — artisanat.** L'atelier et l'action *Fabriquer* convertiront des ressources brutes en ressources ouvrées. Rien n'est écrit tant que la boucle n'est pas jouable, mais la réserve commune et le catalogue de `data/` accueillent une cinquième ressource sans refonte.

### 3.4 Effectifs — main-d'œuvre et combattants

> **Contrat** — le système expose une `LaborForce` à l'Économie et une `CombatForce` au Combat, et consomme les rapports en retour pour distribuer XP, blessures et pertes. **Ni l'Économie ni le Combat ne savent d'où viennent ces effectifs.**

Un effectif n'est pas un compteur. Chaque unité est un individu nommé, avec :

- des **pistes de compétence** par famille — Récolte, Artisanat, Combat — qui gagnent de l'XP à l'usage et donnent un multiplicateur d'efficacité
- un **niveau d'ouvrier**, qui agrège toute l'XP gagnée quelle qu'en soit la source *(cf. ci-dessous)*
- éventuellement des **traits**, acquis ou de naissance, qui donnent des bonus conditionnels plutôt que des chiffres bruts. C'est aux paliers de niveau qu'ils s'acquerront — `X5`

Les familles ne sont pas décoratives. *(Tranché à `E1`.)* La `LaborForce` expose un multiplicateur **par famille**, et chaque bâtiment déclare dans `data/` celle qu'il emploie : un même ouvrier rend donc différemment au camp de bûcheron et à l'atelier. C'est ce qui donne son sens à la spécialisation, et ce qui permet à l'XP de savoir quelle piste créditer.

Ce qui en découle : spécialiser rend excellent à un poste et médiocre ailleurs, et une unité expérimentée perdue est une vraie perte. C'est ce qui donne au roguelite sa charge émotionnelle.

#### Deux axes de progression

*(Tranché à `W1`.)* Un ouvrier progresse sur **deux compteurs distincts**, qui ne disent pas la même chose.

La **piste de compétence** dit *ce qu'il sait faire*. Une par famille — Récolte, Artisanat, Combat —, elle monte par paliers, et chaque palier ajoute un cran au multiplicateur d'efficacité de cette famille. C'est le seul des deux que l'Économie consomme, via la `LaborForce`.

Le **niveau d'ouvrier** dit *ce qu'il a vécu*. Un seul par unité, alimenté par **toute** source d'XP — travail, combat, événement —, il ne donne par lui-même aucun multiplicateur. Sa raison d'être est double : un vétéran se distingue d'un bleu d'un coup d'œil, sans lire trois pistes, et c'est à ses paliers que se branchera le choix de compétence *(cf. `X5`)*.

La règle qui les relie tient en une ligne : **toute XP compte deux fois** — une fois pour la piste concernée, une fois pour le niveau. Une XP qui n'appartient à aucune famille, celle d'un événement, n'alimente que le niveau : c'est précisément pourquoi ce compteur est réel et non dérivé de la somme des pistes.

Les deux courbes de paliers vivent dans `data/balance/` et se règlent séparément. Un ouvrier peut donc plafonner sa spécialité en continuant à monter en niveau, ce qui est exactement la situation qui rendra `X5` intéressant.

**Les paliers plutôt qu'une courbe continue**, et pour une raison d'affichage autant que de design : un passage de niveau est un événement qu'on annonce, et un ouvrier qu'on peut appeler « Récolte 3 » existe dans une conversation comme un multiplicateur à 1,37 n'existera jamais. Une progression douce reste exprimable — c'est beaucoup de petits paliers.

#### Qui est là, et combien de places

*(Tranché à `W1`.)* Le roster porte un **état de présence** par unité, et les projections ne montrent que les présents. C'est la contrainte que 3.9 impose d'honorer d'avance : des ouvriers partis en expédition sont absents sans être morts, et rien ne doit supposer le roster entier disponible.

Conséquence directe, décidée par construction : **un absent ne mange pas**, puisqu'il ne compte pas dans la `LaborForce` sur laquelle l'upkeep tombe. L'inverser coûterait un champ sur ce contrat.

Le roster a un **plafond de places** — une base d'équilibrage, plus ce que les habitations ajoutent, exactement comme l'entrepôt relève la réserve commune. Ce qui remplit ces places reste ouvert ci-dessous.

#### Vivier unique — tranché

**Les ouvriers *sont* les combattants.** Le compromis est direct et personnel : envoyer son meilleur récoltant en milice coûte la production du soir *et* risque sa vie. C'est la version la plus tendue et la plus lisible, et c'est celle qui sert le pitch.

Les deux alternatives écartées — deux viviers séparés à la *As We Descend*, ou une garnison plus un levier de conscription — étaient plus confortables à équilibrer et moins chargées émotionnellement. La question était adossée au format de combat, et elle est tranchée avant lui : c'est le combat qui devra s'accommoder d'un vivier unique, pas l'inverse.

La limite est connue et assumée : si le combat devient très tactique, un paysan sans équipement y est peu utile. La réponse prévue est l'action ***S'entraîner*** — investir dans un ouvrier qu'on a déjà plutôt qu'en recruter un autre — plutôt qu'un second vivier.

Le contrat, lui, ne change pas d'un mot : `LaborForce` et `CombatForce` restent deux projections, et rien hors de `domain/workforce/` ne suppose qu'elles viennent de la même liste. Ce qui était un report devient une simple discipline d'écriture.

#### Les ouvriers sont l'énergie, et ils sont nominatifs

Il n'y a **qu'un seul budget d'ouvriers**, et il joue le rôle de l'énergie d'un deckbuilder : les cartes disent ce qu'on peut faire, les ouvriers disent combien on peut en faire. Deux contraintes qui se croisent, et non deux ressources qui se doublent.

La subtilité qui distingue ça d'un simple compteur : **on choisit *qui* on place.** Les ouvriers n'ayant pas les mêmes pistes, envoyer le bon sur la bonne action est la décision de fond de chaque phase. C'est pourquoi l'affectation reste nominative jusque dans les contrats — `Assignment` associe un **ouvrier** à une action et à une cible, jamais un nombre.

#### Risque identifié — le micro-management

Des effectifs à quinze, sur deux phases, pendant quinze jours, c'est plusieurs centaines de décisions par run dont la plupart sont évidentes. Mitigations à prévoir dès la conception de l'UI : effectifs volontairement réduits, bouton d'auto-affectation avec surcharge manuelle, affectation persistante d'une phase à l'autre par défaut. C'est du travail d'adapter, pas de domaine. Ce risque augmente mécaniquement si le modèle à deux phases symétriques est retenu.

**`OUVERT`** — taille des effectifs, et **recrutement** : le plafond de places existe, ce qui le remplit non. Croissance passive, événement, carte ? La question est adossée à celle du sort de la main non jouée en 3.5, et se tranchera au même playtest.

La **granularité** cesse d'être ouverte, et la réponse est *les deux* : des chiffres visibles sur les pistes, et du qualitatif au niveau d'ouvrier quand `X5` y branchera le choix de compétence. Ce qu'un palier de niveau offre reste entièrement à définir.

### 3.5 Cartes — trois pools

> **Contrat** — `Deck` rend une main et des intentions de jeu. Ne connaît ni la grille, ni les ressources, ni le placement. Jouer une carte est une **intention** que le système concerné accepte ou refuse.

Deck de départ fixe, pioche d'une main chaque tour, défausse, remélange quand le deck est vide. Draft entre les runs et après les jalons de progression : ajouter une carte parmi plusieurs, en retirer une définitivement, ou une récompense alternative.

Le deck est réparti en **trois pools**, qui se piochent et se draftent séparément.

**Actions** — le verbe du jeu. Une action dépense de la force ouvrière pour faire quelque chose : récolter, chasser, bâtir, terraformer. C'est le seul pool qui consomme des ouvriers, et c'est par lui que passe toute la production.

**Bâtiments** — payants, posés sur la carte, et ouverts en chantier plutôt que finis *(cf. 3.2)*.

**Powers** — **`HORS MVP`.** Effets qui ne dépensent pas d'ouvriers : buffs de production ou de combat, apparition de ressources, coups d'éclat ponctuels. Le pool existe dès `D1`, vide, pour que rien dans le `Deck` ne suppose qu'il n'y a que deux natures de cartes.

**Ce que `D1` a écrit, et ce qu'il a délibérément laissé ouvert.** Le `Deck` tient trois pioches, trois défausses et une main ; il pioche, défausse, remélange quand une pioche s'épuise, et drafte. Il ne juge **aucune** jouabilité — une intention se refuse ailleurs — et ne décide d'**aucun moment** : les trois tailles de main vivent dans `data/balance/`, et *quand* on pioche appartient à la journée, donc à `I1`. C'est ce qui laisse l'`OUVERT` ci-dessous entier plutôt que tranché par accident, et ce qui permettra d'en tester deux réponses en échangeant un `.tres`.

**Et où la jouabilité a fini par atterrir.** *(`D2`.)* Un seul fichier du domaine dit où chaque verbe peut se poser et combien d'ouvriers il y accepte, et il répond en `{ ok, reason }` comme le validateur de placement — un refus est le résultat normal d'un curseur promené sur la carte, pas un incident. Le `Deck`, lui, n'a rien appris : il ne connaît toujours ni la grille ni la ville.

#### Une action se joue à cru ou dans un bâtiment

C'est la règle qui donne aux bâtiments leur raison d'être sans les rendre obligatoires.

Une action jouée **à cru**, sur une case nue dont le tag l'autorise, rend peu — *Récolter* sur une `forest` donne un bois. La même action jouée **dans un slot de bâtiment** rend bien davantage, et applique le multiplicateur de la famille du bâtiment.

On peut donc jouer sans rien construire, mal. On construit pour multiplier, pas pour débloquer — sauf là où c'est explicitement le contraire, voir ci-dessous.

*(Écrit à `D2`.)* Le versant « à cru » vit dans `data/balance/`, sur le même principe que le bloc `production` d'un bâtiment porte le versant « en slot ». Une table y associe **une carte aux tags qu'elle sait exploiter et à ce que chacun rend**, ce qui est la mise en data de la phrase de 3.1 — les tags décident où une action à cru peut se jouer. Elle sert deux fois, au ciblage pour dire où la carte peut aller et à la résolution pour dire ce qu'elle paie : deux tables auraient dérivé, et l'écran aurait promis une récolte que le soir n'aurait pas versée.

Une carte absente de cette table ne se joue pas à cru — c'est le cas de *Construire*, qui vise un chantier, et de *Terraformer*, qui ne rend rien. Une seconde table dit symétriquement quelles cartes **tiennent un poste de production** dans un bâtiment. C'est par ces deux absences, et non par leur nom, que les deux verbes sortent de la production : le résolveur n'écrit aucun identifiant de carte, et un cinquième verbe entrera sans qu'on ait à venir l'exclure d'une liste.

#### Jouer une carte, puis y envoyer des ouvriers

*(Tranché et écrit à `D2`.)* Le jalon annonçait que jouer une carte produirait un `Assignment` — ouvrier → (action, cible) —, donc un geste **atomique** où une carte vaut un ouvrier. C'est faux, et pour une raison qui touche au cœur du pitch : cartes et ouvriers se **doubleraient**. Chaque action en consommant une de chaque, la contrainte réelle deviendrait `min(cartes, ouvriers)`, alors que 3.4 veut « deux contraintes qui se croisent, et non deux ressources qui se doublent ».

Le flux compte donc **deux gestes**. On joue la carte **sur une cible**, ce qui pose une *action* ; puis on y affecte **des** ouvriers. La carte dit ce qu'on peut faire, les ouvriers disent combien on peut en faire.

Une action posée porte sa propre **identité**, et c'est elle que l'affectation désigne — plus l'ancre d'un bâtiment. Une cellule ne suffisait plus : *Terraformer* et *Récolter* peuvent viser la même case nue, *Récolter* et *Chasser* la même forêt, et ce sont deux métiers sur une même terre. Interdire ces doublets aurait tranché une question de design par une structure de données ; les autoriser laisse la règle s'écrire là où elle se discute.

Elle porte aussi sa **capacité**, figée à la pose : les postes du bâtiment visé, les crans qui restent à un chantier, ou un chiffre d'équilibrage sur une case nue. C'est ce plafond que les ouvriers remplissent, et au-delà duquel ils chôment.

**Une carte ouvre les postes de sa cible une fois.** Une seconde du même nom au même endroit les rouvrirait, et trois ouvriers produiraient dans une cabane qui n'en tient que deux — la carte cesserait d'être une permission pour devenir un multiplicateur. Deux cartes *différentes* sur une même cellule restent acceptées ; c'est le doublon qui est refusé, pas le partage.

**`OUVERT`** — la direction de *Terraformer*. 4.2 dit « monte ou descend », `data/cards/` n'en contient qu'une carte, donc le sens est un choix fait à la pose. `D2` ne l'a pas tranché : le verbe se pose et s'affecte sans être exécuté, et lui inventer un champ avant que quoi que ce soit le lise reviendrait à deviner sa forme. La question appartient au jalon qui l'exécute. Même remarque pour les terrains qu'il accepte — l'eau et le rocher se terrassent-ils ?

#### Certains bâtiments débloquent des actions

La caserne fait exister *S'entraîner*, l'atelier *Fabriquer*, le camp d'exploration *Explorer*. Ces actions n'ont **pas** de version à cru : sans le bâtiment, la carte est injouable.

C'est une flèche neuve dans l'architecture — jusqu'ici rien ne remontait de la ville vers les cartes. Le sens à respecter est **le Deck interroge la ville**, via un contrat qui énumère ce qui est débloqué ; la ville ne pousse rien dans le deck. Un système du domaine ne notifie personne, il répond.

**`OUVERT`** — taille de la main et du deck, et sort des cartes non jouées en fin de phase. Défausser toute la main crée de la tension et empêche la thésaurisation, mais frustre quand on pioche trois bâtiments impayables. Alternatives à tester : conserver une carte, défausser contre une petite ressource, ou main persistante avec limite de jeu par tour. La question se pose désormais **par pool**, ce qui la complique — trois pioches, trois défausses, trois tailles de main. Décision reportée après le premier playtest de la boucle complète.

### 3.6 Combat

> **Contrat** — `CitySnapshot` + `CombatForce` + `WaveDef` → `DamageReport`. C'est **le seul** contrat qui compte. Tout ce qui se passe entre les deux est remplaçable sans toucher au reste du jeu.

Format non arrêté. Les pistes envisagées — tower-defense sur la grille du village, auto-battler observé, tactique au tour par tour dans une vue dédiée — ont toutes le même contrat d'entrée et de sortie.

**Contrainte désormais fixée : le vivier est unique** *(cf. 3.4)*. Le format retenu devra rendre un ouvrier ordinaire utile au combat, ou assumer que l'on immobilise l'économie pour tenir une ligne. Ce n'est plus une question ouverte que `F2` tranchera, c'est une contrainte d'entrée que `F2` doit satisfaire.

**Stratégie de développement.** Une première implémentation `InstantCombatResolver`, purement arithmétique et sans vue, sert de bouchon pour boucler la boucle de jeu au plus tôt. Le vrai système de combat, avec sa propre vue et sa propre scène, se développe ensuite en parallèle du reste, alimenté par des `CitySnapshot` fabriqués à la main. Le jour où il est prêt, on échange l'implémentation dans l'orchestrateur : une ligne.

Le `DamageReport` doit couvrir dès maintenant les cas dont les autres systèmes ont besoin : bâtiments détruits ou endommagés, **chantiers interrompus**, pertes et blessures parmi les effectifs engagés, XP de combat gagnée, ressources pillées.

**`OUVERT`** — format, vue, durée, degré de contrôle du joueur, direction et nature des vagues, rôle du relief. C'est `F2` qui tranchera.

### 3.7 Événements

> **Contrat** — un modificateur tiré chaque soir, appliqué avant ou après la production selon son type.

Source d'aléatoire quotidien indépendante de la pioche. Pistes : arrivée d'ouvriers, tempête qui détruit une défense, filon révélé, disette, caravane marchande, éclaireur qui révèle la prochaine vague.

### 3.8 Cycle de jour

> Le seul système qui connaît tous les autres. C'est volontaire : il orchestre, les autres s'ignorent.

Machine à états sur les phases, séquence de résolution, conditions de fin, transition vers l'écran de récompense.

### 3.9 Expéditions — `HORS MVP`

L'action *Explorer*, débloquée par le camp d'exploration, envoie des ouvriers **hors de la carte** pour plusieurs jours. Ils reviennent avec un événement dont l'issue dépend de leurs pistes de compétence — butin, découverte, blessure, ou personne ne revient.

Ce n'est pas une carte, c'est un système : il lui faut un état persistant entre les jours, une table d'issues en data, et une place dans la séquence de résolution. Rien n'en est écrit avant que la boucle soit jouable.

**Ce que ça contraint aujourd'hui**, et c'est la seule raison de cette section : des ouvriers peuvent être **absents du roster** sans être morts. Rien dans les Effectifs ne doit supposer que tout le roster est disponible tous les soirs — ni l'upkeep, qui devra décider si un absent mange, ni l'affectation, qui ne doit pas pouvoir les placer.

---

## 4. Contenu de départ

### 4.1 Bâtiments

Chiffres à prendre comme point de départ d'équilibrage, pas comme cible. La colonne **Chantier** est le nombre d'actions *Construire* à jouer pour l'achever.

| Bâtiment | Coût | Chantier | Production | Déf. | PV | Débloque |
|---|---|---|---|---|---|---|
| Cœur | posé au départ | — | — | 0 | 30 | — |
| Camp de bûcheron | 0 | 1 | 2 slots, +2 bois — Récolte | 0 | 4 | — |
| Ferme | 10 bois | 2 | 2 slots, +3 nourriture — Récolte | 0 | 4 | — |
| Carrière | 15 bois | 2 | 2 slots, +2 pierre — Récolte | 0 | 6 | — |
| Mine | 25 bois, 10 pierre | 3 | 2 slots, +2 minerai — Récolte | 0 | 8 | — |
| Habitation | 20 bois | 2 | +2 places de roster | 0 | 5 | — |
| Entrepôt | 20 bois | 2 | +100 de réserve | 0 | 6 | — |
| Palissade | 5 bois | 1 | — | 3 | 4 | — |
| Tour de guet | 15 bois, 10 pierre | 3 | 1 slot, +8 déf. si occupée | 8 | 10 | — |
| Caserne | 30 bois, 15 pierre | 3 | 1 slot | 0 | 10 | *S'entraîner* |
| Marché | 30 bois, 10 minerai | 3 | 1 slot, 2 échanges 3:1 | 0 | 6 | — |
| Atelier | 25 bois, 15 minerai | 3 | 1 slot | 0 | 8 | *Fabriquer* |
| Camp d'exploration | 20 bois, 10 minerai | 2 | 1 slot | 0 | 6 | *Explorer* |

La **palissade** est entrée par la pratique et non par le design : `C2` l'a créée pour son empreinte en L, la seule forme non rectangulaire du projet, donc le seul cas qui exerce vraiment la rotation du fantôme et le validateur. Elle est inscrite ici à `E1b` pour que ce tableau redise ce que `data/` contient. Une défense de départ bon marché y a sa place de toute façon.

Les bonus d'adjacence ne sont pas dans cette table : ils viennent avec `C3`, qui décidera de leur forme avant de les chiffrer.

**Ce que `data/` porte, et ce qu'il ne porte pas encore.** *(Constaté à `E1b`.)* Un champ arrive avec le système qui le lit : la colonne **Chantier** y est entrée à `C4`, **Déf.** et **PV** viendront à `F1`.

**Débloque** était annoncée pour `D1` et n'y est pas entrée. *(Tranché à `D1`.)* Les trois actions qu'elle concerne — *S'entraîner*, *Fabriquer*, *Explorer* — sont marquées `MVP : non` en 4.2 et ne sont donc pas au catalogue de cartes ; un champ qui ne débloquerait rien serait une frontière que personne ne franchit, ce qui est exactement l'argument qui a sorti `CombatForce` de `W1`. Elle entrera avec `X3`, `X2` et `X1`, en même temps que les cartes qu'elle verrouille. Le coût du report est connu et faible : un champ sur `BuildingData`, trois `.tres` à rouvrir, et une lecture de plus sur `CitySnapshot.completed()` — qui a déjà trois consommateurs et la porte ouverte.

Le « — » du Cœur dans la colonne Chantier est un **zéro**, comme son « posé au départ » dans la colonne Coût est un coût vide. C'est ce qui lui évite un chemin de pose particulier : un bâtiment qui ne réclame aucune action est achevé dès qu'il est posé, sans que rien n'ait à connaître le cas. Le prix assumé de ce choix est qu'un `build_actions` oublié dans un `.tres` vaut 0 et fait sauter le chantier en silence ; un cas de test exige donc qu'au moins un bâtiment de `data/` en déclare un, ce qui rattrape la disparition du format entier. *(Tranché à `C4`.)*

Les places de roster de l'habitation y sont entrées à `W1`, ce qui a sorti ce bâtiment de la coquille vide où `E1b` l'avait laissé. La conséquence à ne pas confondre avec un oubli : **cinq bâtiments portent « 1 slot » dans ce tableau et n'ont pourtant aucun bloc `production`** — tour de guet, caserne, marché, atelier, camp d'exploration. Leur poste n'est pas un poste de production ; il héberge une défense, un échange ou une action débloquée, et la nature qui le décrira n'existe pas encore. Leur écrire un `slots = 1` que rien ne lit ferait mentir la data et détruirait la garantie que `E1b` vient d'acheter — un bloc qui existe produit.

### 4.2 Actions

| Action | À cru | En slot | MVP |
|---|---|---|---|
| Récolter | +1 de la ressource du tag visé (`forest`, `stone`, `ore`) | rendement du bâtiment × piste Récolte | oui |
| Chasser | +1 nourriture sur une case `forest` | — *(pas de bâtiment de chasse pour l'instant)* | oui |
| Construire | — | avance un chantier d'un cran | oui |
| Terraformer | monte ou descend une case d'un cran | — | oui |
| S'entraîner | — | XP de la piste choisie, à la caserne | non |
| Fabriquer | — | convertit des ressources, à l'atelier | non |
| Explorer | — | envoie une expédition, au camp d'exploration | non |

*Chasser* est la façon d'obtenir de la nourriture avant d'avoir une ferme : la version à cru d'un besoin qui devient ensuite un bâtiment. Un bâtiment de chasse pourra s'ajouter plus tard sans rien changer à la règle.

**`data/cards/` ne contient que les quatre premières.** *(Écrit à `D1`.)* La colonne MVP n'est pas indicative : les trois dernières n'ont ni résolution, ni bâtiment pour les débloquer, et les écrire aujourd'hui reviendrait à mettre dans le deck des cartes injouables pour plusieurs jalons. Elles entrent avec `X1`, `X2` et `X3`, en même temps que la colonne **Débloque** de 4.1.

Ce qu'une action **fait** n'est pas dans `data/` non plus, et ne le sera pas : les sept verbes se résolvent chacun autrement, donc une *nature* d'action est du code de `src/domain/`. La carte porte son identité et son pool ; c'est tout ce que le deck consomme. Même règle qu'en 3.3 pour les bâtiments.

*(Écrit à `D2`.)* Cette règle a tenu à l'épreuve : les quatre verbes MVP sont ciblés par un seul fichier de `src/domain/deck/`, qui est le seul endroit du projet où un identifiant de carte est écrit en dur. Leurs **chiffres**, eux, sont en data — quels tags chaque verbe exploite, ce qu'une case nue rend, combien d'ouvriers elle accepte —, et c'est cette séparation qui permet au résolveur d'Économie de n'avoir aucune liste de noms.

**La colonne « À cru » de la ligne *Récolter* n'a pas de cible pour `ore`.** *(Constaté à `D2`.)* La règle est écrite et la table de data la nomme, mais `data/terrain/` ne contient aucun terrain « filon » et la génération n'en pose pas — la palette de 3.1 s'arrête à la plaine, la forêt, le gisement, l'eau et le rocher. Le minerai ne s'obtient donc aujourd'hui qu'à la mine. Ce n'est pas un bug de ce jalon : c'est une ligne de 3.1 que `data/` n'a jamais reçue, et elle entrera avec le terrain, pas avec la carte.

---

## 5. Fin de run

- **Défaite** — Cœur détruit, ou roster vide
- **Victoire** — dernière vague survécue
- **Score** — ressources, bâtiments intacts, ouvriers vivants et leur niveau

---

## 6. Méta-progression *(après le MVP)*

Déblocage de cartes dans les pools de draft, gouverneurs de départ avec deck et bonus modifiés, biomes aux paramètres de génération distincts, modificateurs de difficulté cumulatifs.

---

## 7. Hors périmètre

- Citoyens simulés individuellement dans le monde — le roster est une liste de fiches, pas des agents qui marchent
- Routes, logistique, transport de ressources
- Ponts, tunnels, superposition verticale — le relief reste une hauteur par cellule
- Sauvegarde en cours de run — seule la méta persiste
- Son, art final, animations

Les systèmes marqués **`HORS MVP`** — powers (3.5), artisanat (3.3), entraînement (3.4), expéditions (3.9) — ne sont pas hors périmètre : ils sont *différés*. La distinction compte, parce qu'ils ont le droit de contraindre l'abstraction d'aujourd'hui, alors que la liste ci-dessus n'en a aucun.

Toute demande d'ajout passe d'abord par une mise à jour de ce document.

---

## 8. Jalons

Le développement est par système, pas linéaire. Chaque système avance dans sa scène de dev jusqu'à tenir debout seul. Le fil d'intégration ne fait que brancher ce qui est déjà prêt.

### Terrain — `T`
- **T1** ✅ — `HeightGrid`, génération seedée, tests. Aucun rendu.
- **T2** ✅ — Rendu `MultiMeshInstance3D` en blocs étagés, `CameraRig` isométrique.
- **T3** ✅ — `CellPicker` en DDA, surbrillance, décorations de terrain.
- **T4** — Traitement de l'occlusion, si le playtest montre que c'est un problème réel.

### Construction — `C`
- **C1** ✅ — `CityState`, `PlacementValidator`, empreintes, tests.
- **C2** ✅ — Fantôme de placement, pose et destruction, rotation.
- **C4** ✅ — **Chantiers** : bâtiment posé non fini, avancement porté par `CityState`, `CitySnapshot` qui le dit en deux lectures — tout, et les seuls achevés —, rendu distinct, colonne **Chantier** de 4.1 entrée dans `data/`. L'action *Construire* elle-même est une carte, donc `D1` et `D2` : `C4` écrit la porte qu'elle visera, et le harnais y frappe au clavier en attendant.
- **C3** — Règles d'adjacence + prévisualisation du delta au survol.

### Économie — `E`
- **E1** ✅ — `Ledger` en réserve commune, `ProductionResolver`, upkeep, famine, tests.
- **E1b** ✅ — Le bloc **`production` nullable** sorti de `BuildingData`, quatrième ressource, contenu de 4.1. Petit, et il a déblayé avant que douze bâtiments écrivent l'ancien format.
- **E2** — HUD des ressources, panneau de rapport de production.

### Effectifs — `W`
- **W1** ✅ — `Worker`, `SkillTrack`, `Roster`, XP depuis les `WorkLine`, projection en `LaborForce`, tests. **Vivier unique**, et rien qui suppose le roster entier disponible *(cf. 3.9)*.
  La `CombatForce` **n'y est pas** : son contenu est décidé par le format de combat, qui est `OUVERT` en 3.6, et l'écrire ici serait ou bien un clone de `LaborForce` qui ne prouve rien, ou bien une devinette. Elle arrive à `F1`, avec le `DamageReport` et pour le même système neuf — c'est la règle « on n'invente pas une frontière que personne ne franchit », déjà appliquée à `E1`. Ce que `W1` garantit à sa place est plus solide : `Roster` est le seul propriétaire des `Worker`, et rien hors de `domain/workforce/` n'en voit un.
- **W2** — Panneau d'affectation, fiches d'unité, auto-affectation.

### Cartes — `D`
- **D1** ✅ — `Deck`, `Hand`, `CardCatalogue`, `DraftPool`, les **trois pools**, défausse, remélange, draft, tests. Les cartes sont de la data : seize `.tres` dans `data/cards/`, les quatre actions MVP de 4.2 et une par bâtiment de 4.1 sauf le Cœur, qui est posé au départ. Le pool des powers existe et reste vide. La colonne **Débloque** n'y est pas entrée, voir 4.1. Le mélange est écrit à la main — `Array.shuffle()` tire sur le RNG global de Godot et non sur celui du run.
- **D2** ✅ — **Main à l'écran**, et les **deux gestes** : jouer une carte sur une cible pose une *action*, puis on y affecte des ouvriers. `PlayedAction`, `ActionPlan`, `TargetResult`, `ActionBoard`, `ActionTargeting`, le bloc `action_balance`. L'`Assignment` est rekeyée sur l'action et non sur l'ancre, et le `ProductionResolver` part enfin des actions posées, ce qui rend vraie la phrase de 2. *Récolter* et *Chasser* se résolvent à cru comme en slot ; *Construire* et *Terraformer* se posent, s'affectent et attendent `I1`, parce que leur effet mute le `CityState` et la `HeightGrid`.
  La ligne de ce jalon annonçait un geste **atomique** — une carte pour un ouvrier — et c'était une erreur de design, pas une simplification : voir 3.5.

### Combat — `F`
- **F1** — `InstantCombatResolver` arithmétique, **`CombatForce`** et `DamageReport` complets, tests. Bouchon.
- **F2** — Prototype du vrai combat, sur snapshots fabriqués. *Format à définir, vivier unique imposé.*
- **F3** — Vue de combat intégrée, échange de l'implémentation dans l'orchestrateur.

### Intégration — `I`
- **I0** ✅ — Squelette : projet, arborescence, autoloads, `EventBus`, `GameDatabase`.
- **I1** — Boucle minimale : Terrain + Construction + Économie branchés, une journée en deux phases.
- **I2** — Boucle complète : Cartes + Effectifs + Combat bouchon, run jouable du début à la fin.
- **I2b** — Playtest : arbitrage de la **structure de journée** (2.) et du sort de la main non jouée (3.5). Les deux se testent en échangeant un `.tres`.
- **I3** — Passe de contenu et d'équilibrage, **arbitrage des `OUVERT`** restants.

### Différés — `X`

Écrits après `I2`, jamais avant. Ils ne contraignent que l'abstraction, pas le calendrier.

- **X1** — Expéditions *(3.9)*.
- **X2** — Artisanat : atelier et *Fabriquer* *(3.3)*.
- **X3** — Entraînement : caserne et *S'entraîner* *(3.4)*.
- **X4** — Powers : le troisième pool se remplit *(3.5)*.
- **X5** — Ce qu'un palier de **niveau d'ouvrier** offre : le choix de compétence *(3.4)*. `W1` écrit l'accumulateur et les paliers, qui se gagnent et se lisent ; ce qu'ils débloquent est du contenu et de l'UI, et se décide devant un roster qui a vraiment vécu quinze jours.

**Ordre suivant** — `I1`, qui a maintenant tout ce qu'il lui faut : la journée, la bourse au moment de poser un bâtiment, et l'exécution de *Construire* et *Terraformer* que `D2` a laissée à l'orchestrateur. `E1b` est passé avant `W1` parce qu'il touchait les `.tres` de bâtiments et que leur nombre a doublé ; `W1` a suivi parce qu'il était le dernier moment où `LaborForce` pouvait bouger sans douleur — elle n'a finalement pas bougé — et parce qu'il est le seul jalon qui rende le journal de travail de `E1` utile à quelque chose. `C4` est venu ensuite parce qu'il rouvrait ces mêmes `.tres` une dernière fois avant que les cartes n'arrivent, et parce que `D2` a besoin d'une cible pour *Construire* : sans chantier, cette carte n'aurait rien à avancer. `D1` a suivi sans surprise, étant le seul jalon qui ne dépende de rien — le `Deck` ne connaît ni la grille, ni la bourse, ni le roster.

Le jeu devient jouable à `I2`. Tout ce qui suit est de l'enrichissement.
