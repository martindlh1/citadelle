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

*(Écrit à `I1`.)* La machine existe, et la promesse tient jusqu'au bout : **aucun nom de phase n'apparaît nulle part**, ni dans le domaine, ni dans les adapters, ni même dans les tests. L'écran lit son libellé et les gestes qu'il allume sur la phase courante. Deux gestes seulement sont déclarables aujourd'hui — poser et affecter ; *échanger* attend le marché et *piocher* n'est pas encore un geste du joueur.

La journée que `data/` porte est le **modèle symétrique**, plus un soir : deux phases identiques — matin et après-midi —, chacune autorisant les deux gestes de `D2` et se résolvant à sa fin, puis une troisième qui n'autorise rien, ne résout rien, et se contente de **fermer la journée**. On joue deux fois par jour, et chaque tour est un tour complet : poser ses cartes, y envoyer ses ouvriers, voir ce que ça rend.

*(Retenu à `I2b`, et c'est le troisième modèle que 2. annonçait comme possible sans le décrire.)* Le soir n'est pas une phase de plus à jouer, c'est le moment de ce que la journée **coûte**. Sans lui, l'upkeep tombait dans le compte rendu de l'après-midi, à côté d'une récolte, et la vague arrivait dans le même souffle : ce qu'on paie se lisait comme une ligne de ce qu'on gagne. La chronique de `I2b` a mesuré ce qu'il coûte en retour — **rien** : à équilibrage égal, un run de quinze journées rend le même score, la même réserve et la même date de famine avec ou sans lui, puisqu'il ne résout pas. Il ne se paie qu'en un `Entrée` de plus par jour.

Deux conséquences que le modèle porte et qu'il faut connaître pour le lire. La main est tirée à la fin de la dernière phase qui **produit**, donc elle traverse le soir : on regarde l'upkeep tomber en tenant déjà celle de demain matin, ce qui est une information plutôt qu'un défaut. Et une phase qui ne résout pas ne compte **aucun oisif** — un oisif est un reproche, et un reproche suppose qu'on pouvait faire autrement.

Ce que `I2b` laisse ouvert n'est donc plus « lequel des deux modèles », mais « celui-ci tient-il quinze journées » : le modèle à deux phases reste dans `data/balance/` et se rebranche en repointant une ligne.

#### Le soir est l'endroit où l'on lit sa journée

*(Tranché après les premiers runs complets joués à la main.)* Le soir a une seconde moitié, et c'est elle qui le sort du statut de clic : **on y lit le bilan de la journée avant de la fermer.** Ce que les deux phases ont récolté, les paliers franchis, les chantiers achevés, et ce que l'upkeep va coûter.

Il tombe **à l'entrée du soir** et non après, et le choix se paie en une nuance qu'il faut assumer : l'upkeep est prélevé à la fermeture, donc le bilan annonce ce qui est **dû** et non ce qui a été mangé. Les deux ne diffèrent qu'en famine, et la famine a déjà son alarme ailleurs. Ce qu'on achète en échange vaut mieux que cette nuance : aucun geste de plus dans la journée — le bouton qui referme le bilan **est** celui qui ferme la journée —, et une phase du soir qui a quelque chose à montrer plutôt qu'à attendre.

Il remplace ce que le compte rendu de phase disait de travers, et c'est ce qui a fait remonter le sujet : un panneau titré « Jour 3 · Soir » sous un bandeau titré « Jour 4 · Matin » est **deux horloges qui se contredisent sur le même écran**, et la plus petite avait raison. Le compte rendu de phase reste — on veut voir ce qu'une résolution vient de rendre —, mais il cesse d'être ce qu'on lit pour savoir où l'on en est.

**Quelqu'un doit donc se souvenir de la journée**, ce que rien ne fait aujourd'hui : chaque `PhaseReport` est émis puis oublié, et `DayReport` ne porte que l'upkeep et la vague. L'accumulation appartient au **domaine** et non à une vue, pour une raison qui n'est pas de principe : l'événement de 3.7 et les états d'ouvrier de `X6` voudront tous deux poser une ligne dans ce bilan, et un accumulateur d'adapter devrait réapprendre chaque nouvelle source. Le domaine, lui, la reçoit déjà.

**Une journée compte donc deux sortes de résolution**, et c'est ce qui rend le modèle symétrique jouable sans le confondre avec son équilibrage :

- une **phase** produit — ce que les actions posées rapportent, ce que les chantiers avancent, l'XP que ça vaut ;
- une **journée** coûte — l'upkeep, et demain l'événement de 3.7 et le combat de `F1`.

Manger deux fois parce qu'on a récolté deux fois serait un contresens, et forcerait à rééquilibrer la nourriture chaque fois qu'on change le nombre de phases. La fin de journée n'est d'ailleurs **pas un champ** de la data : c'est la fin de la dernière phase, par définition — un booléen pourrait dire le contraire de la liste qui le porte. Elle est aussi indépendante du fait de résoudre : une journée coûte à nourrir même si sa dernière phase ne produit rien.

**La durée d'un run est un champ de `data/balance/`** depuis le même jalon, pour la même raison.

### Séquence de résolution

Quel que soit le modèle retenu, l'ordre est : **actions jouées** → événement → upkeep → combat s'il y a lieu → gain d'XP → rapport.

*(Précisé à `I1`.)* Ces étapes ne tombent pas toutes au même moment. **Les actions jouées et l'XP appartiennent à la phase** ; **l'événement, l'upkeep et le combat appartiennent à la journée**, et ne se déclenchent qu'à la fin de la dernière phase. La séquence les listait déjà séparément — leur simultanéité n'était vraie que tant qu'une journée n'avait qu'une seule résolution.

*(Occupé à `I2`.)* Le combat tombe vraiment, et **après** l'upkeep : un village affamé le soir d'un siège l'est toujours pendant, et l'inverse ferait payer à manger à des morts qui viennent de tomber. La seule case encore vide de la séquence est l'événement de 3.7.

La production n'est plus une étape passive qui balaye les bâtiments : c'est le résultat des actions que le joueur a posées. Un bâtiment dont aucun slot n'a reçu d'action ne rend rien.

**Les actions jouées se résolvent en deux temps, et l'ordre est imposé.** *(Tranché à `I1`.)* La production se calcule sur la ville **d'avant le soir** ; les chantiers et les terrassements s'appliquent ensuite. Sans cette règle, un entrepôt achevé le soir même relèverait la réserve du même soir, et l'ordre dans lequel les cartes ont été posées déciderait du résultat — ce que 3.3 refuse déjà pour l'écrêtage, et pour le même motif : deux villes identiques bâties dans un ordre différent doivent rendre la même chose.

Conséquence à connaître pour lire un rapport : le rapport de production ne connaît que les postes de production, donc il **compte un bâtisseur parmi les oisifs**. Chacun des deux rapports est juste dans son système ; c'est le rapport de la soirée, qui voit les deux journaux de travail, qui répond pour le soir entier.

**Une vague tombe à la fermeture d'une journée, et le calendrier est de la data.** *(Écrit à `I2`.)* Un `WaveSlot` associe un jour à une vague, et `RunBalance` en porte la liste — au même endroit que `days`, parce que le seul contrôle qui compte croise les deux : une vague datée au-delà de la dernière journée est une vague que personne ne verra tomber.

C'est une **liste explicite** et non une période — « une vague tous les N jours » —, et pour deux raisons. Une liste dit une période en l'écrivant, alors qu'une période ne sait exprimer ni un creux ni deux vagues rapprochées. Et surtout la **vague finale** ci-dessus tombe sur le dernier jour parce qu'on l'y a mise ; avec une période elle n'y tomberait que par coïncidence arithmétique, et changer la durée du run la déplacerait sans qu'on le veuille.

Un calendrier **vide** reste légitime : c'est le run paisible d'un harnais qui mesure une économie sans qu'on lui casse ses murs, exactement comme un `starting_building` vide donne une carte nue.

**`OUVERT`** — durée d'un run, fréquence des vagues, sort de la main non jouée. Les trois se tournent désormais en éditant un `.tres` — quinze journées, trois vagues aux jours 5, 10 et 15, et le report de main de 3.5 depuis `I2b` —, ce qui est tout ce qu'on leur demande jusqu'à `I3`. Aucune n'est **répondue** pour autant : un bouton n'est pas un arbitrage.

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

**`OUVERT`** — le relief joue-t-il encore *autrement* ? Une piste reste entière : l'accès aux ressources selon l'altitude. Le contrat expose déjà hauteur et planéité, donc elle reste ouverte sans refonte.

*(À moitié refermé après `F1`.)* L'**avantage en hauteur** cesse d'être une piste : le format de combat retenu en 3.6 fait du relief une contrainte de déplacement — monter coûte, une marche trop haute bloque. Ce n'est pas encore le bonus défensif qu'on imaginait, mais c'est mieux, parce que ça se joue au lieu de se subir : un plateau devient une position, et le terrassement de cette section devient un geste militaire autant qu'économique.

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

**La piste que *Construire* crédite est une quatrième famille.** *(Tranché à `I1`.)* La question était ouverte depuis `C4` et avait trois issues — une quatrième famille, un rattachement à l'Artisanat, ou de l'XP de niveau seule. C'est la première : bâtir est un **métier**, avec sa piste et son multiplicateur, et non un travail qu'on subit. Le rattacher à l'Artisanat aurait rempli une piste que `X2` n'a pas encore ouverte ; l'XP de niveau seule aurait fait d'un chantier un pur coût.

Ce que ce multiplicateur multiplie est écrit et vérifié : les crans d'un soir sont la **somme des efficacités de l'équipe, tronquée, plafonnée à ce qu'il reste à bâtir**. Deux ouvriers chevronnés posent trois crans là où deux bleus en posent deux. C'est la même arithmétique que la production, et c'est ce qui distingue une piste d'un compteur.

Le nom de la famille vit dans `data/balance/`, comme celui de la famille qu'emploie une action à cru. Rien dans le code n'énumère les familles — les pistes se créent à l'usage —, donc en ajouter une n'a coûté aucune ligne de GDScript. *Terraformer* crédite la même : les deux verbes remuent la même terre.

**`OUVERT`** — un bâtiment qui couvre plusieurs cellules peut-il recevoir **plusieurs fois** la même action ? *(Posé après `I2`.)* Deux *Construire* sur un chantier large, deux *Récolter* sur une ferme en L. La question naît de la contrainte provisoire de 3.5 — une cible ne porte qu'une action — et elle est plus large qu'elle : une empreinte de quatre cellules est aujourd'hui **une** cible, celle de son ancre, donc elle accepte exactement autant de travail qu'une cabane 1×1. Est-ce que la taille devrait acheter du débit, ou seulement des points de vie et de la place ? Les deux réponses sont défendables, et celle qu'on retiendra décide aussi de ce que valent les grands bâtiments dans le tableau de 4.1.

#### Adjacence

C'est la couche d'optimisation du jeu. Chaque bâtiment porte des règles de la forme *« +X de rendement par voisin taggé Y dans un rayon Z »*. Le système doit exposer un calcul de prévisualisation appelable pendant le placement fantôme : sans retour visuel en temps réel du delta, le système d'adjacence est invisible, donc inexistant.

### 3.3 Économie

> **Contrat** — deux portes depuis `I1`, parce qu'une journée compte deux sortes de résolution *(cf. 2)*. Une **phase** : `TerrainQuery` + `CitySnapshot` + `ActionPlan` + `Assignment` + `LaborForce` → `ProductionReport`. Une **journée** : `LaborForce` → `UpkeepReport`, et rien d'autre — ce qu'on doit à manger ne dépend que de qui est là. Ne connaît ni la grille ni les Node : tout lui est fourni.

*(Le contrat a gagné deux entrées à `D2`, et elles se justifient l'une l'autre.)* L'**`ActionPlan`** est le pilote : la phrase de 2 — « un bâtiment dont aucun slot n'a reçu d'action ne rend rien » — n'était pas vraie tant que le résolveur balayait les ancres de l'affectation et servait le rendement du bâtiment qu'il y trouvait, sans qu'aucune carte n'ait eu à être jouée. Elle l'est maintenant par construction. Le **`TerrainQuery`** vient avec la seconde lecture de 3.5 : une action jouée à cru rend ce que le **tag de sa cellule** dicte, donc l'Économie doit voir le relief — le contrat, jamais la grille.

Stocks de ressources sous réserve commune, résolution des actions jouées, application des modificateurs d'adjacence, upkeep en nourriture, famine si le stock ne couvre pas le roster.

Le plafond de stockage est délibéré : il punit la thésaurisation et force la dépense.

**C'est une réserve commune, et non un plafond par ressource.** *(Tranché à `E1`.)* Les cent unités sont partagées entre toutes les ressources : remplir sa réserve de bois, c'est renoncer à stocker de la pierre. C'est la plus mordante des deux lectures, et celle qui donne à l'entrepôt une valeur d'arbitrage au lieu d'un simple relèvement de compteurs indépendants. Le plafond ne force plus seulement à dépenser, il force à choisir *quoi* garder.

Conséquence directe, et c'est le prix de ce choix : une récolte qui déborde doit décider **lesquelles** de ses ressources entrent. La répartition est **proportionnelle à ce que le soir a produit**, et jamais fonction de l'ordre des bâtiments — deux villes identiques bâties dans un ordre différent doivent perdre exactement la même chose.

**L'ensemble des ressources vit dans `data/`**, un fichier par ressource, et non dans une énumération du code. C'est ce qui rend leur nombre réglable sans toucher à du GDScript, et ce qui permet de refuser au démarrage un coût qui nommerait une ressource inexistante.

**Quatre ressources** — nourriture (upkeep), bois (construction), pierre (avancé et défense), minerai (bâtiments tardifs et, plus tard, artisanat). Réserve commune 100, +100 par entrepôt. Upkeep 1 nourriture par ouvrier et par soir, **oisifs compris** — c'est ce qui rend un ouvrier non affecté coûteux, et le pool tendu.

**La famine se constate, elle ne se punit pas encore.** *(Tranché à `E1`.)* La résolution vide ce qui reste de nourriture et rapporte combien d'ouvriers n'ont pas mangé. Ce qu'il leur arrive ensuite appartient aux Effectifs, qui possèdent les unités.

**L'upkeep tombe une fois par jour, quel que soit le nombre de phases.** *(Précisé à `I1`.)* Il a vécu dans le rapport de production tant qu'une journée n'avait qu'un soir ; il en est sorti dès qu'elle en a eu deux. C'est ce qui permet de changer la structure de la journée sans rééquilibrer la nourriture — les deux questions sont séparées, et elles doivent le rester.

#### Ce qu'un bâtiment déclare produire

*(Tranché avant `E1b`, écrit à `E1b`.)* Un bâtiment ne porte pas de champs de production en vrac. Il porte un **bloc `production` nullable** : ou bien il produit, et le bloc dit tout — slots, famille de compétence, rendement —, ou bien il ne produit pas et le bloc est absent. L'entrepôt et l'habitation n'ont pas « zéro slot », ils n'ont **pas de bloc**.

Deux bénéfices immédiats. La cohérence devient **structurelle** au lieu d'être vérifiée : il n'est plus possible d'écrire des slots sans rendement, ou un poste sans famille, parce que les trois vivent ou meurent ensemble. Et le jour où un bâtiment produit *autrement* — au voisinage, à l'événement, au palier —, le bloc devient une classe de base et le résolveur commute sur son type.

**La règle qui décide où va le code.** Ajouter un **bâtiment** doit rester une édition de `data/`. Ajouter une **nature** de bâtiment est légitimement une modification de code — mais dans `src/domain/`, jamais dans le schéma ni dans la data. Une `Resource` qui porterait une méthode de résolution serait du domaine déguisé, et le jour où il lui faut le terrain, la ville et le roster, on aurait recodé le résolveur dans `src/schema/`.

#### Ce que la réserve montre, et ce qu'elle ne détaille pas

*(Écrit à `E2`.)* La réserve commune n'était jusqu'ici qu'une règle de résolution ; elle est maintenant **une seule jauge segmentée**, où chaque ressource prend la place que les autres n'ont pas. Quatre jauges côte à côte auraient dessiné quatre plafonds indépendants, c'est-à-dire exactement la lecture que `E1` a écartée — et la phrase de cette section, « un joueur qui ne la voit pas ne comprend pas pourquoi son entrepôt manque », serait restée une intention.

**L'ordre des ressources à l'écran vit dans `data/`**, un rang par `CommodityData`, pour la même raison que leur nombre : trier par identifiant triait en anglais interne, et rangeait la nourriture entre le minerai et la pierre. Deux ressources ne peuvent pas partager un rang, et c'est un cas de test qui le tient — à rangs égaux, l'ordre retomberait sur une comparaison de `StringName`, stable le temps d'une session et différente à la suivante.

**Un entrepôt achevé relève la réserve à l'instant où il est fini.** Ce n'est pas une entorse à la règle d'ordre de 2 — la production du soir est déjà calculée quand le plafond bouge, donc l'entrepôt ne sauve toujours pas la récolte de ce soir-là. C'est la règle **d'affichage** qui manquait : jusqu'à `E2` le plafond ne montait qu'à la résolution suivante, si bien qu'un entrepôt visiblement terminé sur la carte cohabitait une phase entière avec une jauge qui annonçait l'ancien chiffre. Aucun écran n'affichant la réserve en continu, le défaut avait traversé `I1` sans se faire remarquer.

**Les oisifs restent un compte, sans raison distinguée.** *(Tranché à `E2`.)* Trois raisons se cachaient derrière ce chiffre — non affecté, affecté à une ancre vide, arrivé quand les slots étaient pris —, et la question était explicitement renvoyée « devant une vraie maquette ». La voici : au niveau de la **phase**, les trois s'effondrent de toute façon en « n'a tenu aucun poste », qui est la seule lecture juste *(cf. 2)*. Les séparer aurait demandé au résolveur de tracer une information que le joueur voit déjà sur le plateau **avant** de résoudre, donc au moment où il peut encore agir. Un chiffre qu'on ne peut plus corriger n'a pas besoin de trois colonnes.

**`OUVERT`** — la conséquence de la famine. Perte d'efficacité le lendemain, blessure, départ, mort ? Le rapport d'upkeep porte déjà le compte des non-nourris : les quatre restent ouvertes sans que le contrat bouge. C'est le jour où l'une sera choisie que ce rapport entrera dans `contracts/`, puisque ce jour-là ce sont les Effectifs qui le liront.

*(Précisé à `F1`.)* Cette question a désormais un **toit** plutôt qu'une réponse : elle appartient au système d'**états d'ouvrier** de `X6`, où la faim rejoindra la blessure et ce qui viendra après. Trois des quatre issues listées ci-dessus décrivent le même objet — un ouvrier qui porte quelque chose et le porte dans le temps —, et les trancher une par une à mesure que les systèmes les rencontrent produirait trois mécaniques qui ne se parlent pas. Ce qui reste ouvert n'est donc plus « que fait la famine », mais « que fait un état », et c'est une question de moins.

**`HORS MVP` — artisanat.** L'atelier et l'action *Fabriquer* convertiront des ressources brutes en ressources ouvrées. Rien n'est écrit tant que la boucle n'est pas jouable, mais la réserve commune et le catalogue de `data/` accueillent une cinquième ressource sans refonte.

### 3.4 Effectifs — main-d'œuvre et combattants

> **Contrat** — le système expose une `LaborForce` à l'Économie et une `CombatForce` au Combat, et consomme les rapports en retour pour distribuer XP, blessures et pertes. **Ni l'Économie ni le Combat ne savent d'où viennent ces effectifs.**

Un effectif n'est pas un compteur. Chaque unité est un individu nommé, avec :

- des **pistes de compétence** par famille — Récolte, Construction, Artisanat, Combat — qui gagnent de l'XP à l'usage et donnent un multiplicateur d'efficacité. **La liste n'est pas close** : elle vit dans `data/`, aucun code ne l'énumère, et une famille naît le jour où un travail la crédite. La Construction est entrée ainsi à `I1` *(cf. 3.2)*
- un **niveau d'ouvrier**, qui agrège toute l'XP gagnée quelle qu'en soit la source *(cf. ci-dessous)*
- éventuellement des **traits**, acquis ou de naissance, qui donnent des bonus conditionnels plutôt que des chiffres bruts. C'est aux paliers de niveau qu'ils s'acquerront — `X5`

Les familles ne sont pas décoratives. *(Tranché à `E1`.)* La `LaborForce` expose un multiplicateur **par famille**, et chaque bâtiment déclare dans `data/` celle qu'il emploie : un même ouvrier rend donc différemment au camp de bûcheron et à l'atelier. C'est ce qui donne son sens à la spécialisation, et ce qui permet à l'XP de savoir quelle piste créditer.

Ce qui en découle : spécialiser rend excellent à un poste et médiocre ailleurs, et une unité expérimentée perdue est une vraie perte. C'est ce qui donne au roguelite sa charge émotionnelle.

#### Deux axes de progression

*(Tranché à `W1`.)* Un ouvrier progresse sur **deux compteurs distincts**, qui ne disent pas la même chose.

La **piste de compétence** dit *ce qu'il sait faire*. Une par famille, elle monte par paliers, et chaque palier ajoute un cran au multiplicateur d'efficacité de cette famille. C'est le seul des deux que l'Économie consomme, via la `LaborForce` — et depuis `I1`, aussi le Cycle de jour, qui l'applique aux crans d'un chantier.

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

*(Écrit à `F1`.)* La `CombatForce` existe, et elle est le **miroir strict** de la `LaborForce` : tout le roster présent, sans distinction. Ce n'est pas un doublon, c'est la même symétrie qu'entre les deux — l'Économie reçoit tout le monde et n'en emploie que ce que l'`Assignment` place, le Combat reçoit tout le monde et n'en engage que ce que le déploiement de 3.6 tient. Le filtre appartient au consommateur, jamais à la projection. Une unité y porte **un** multiplicateur et non un par famille, ce qui est le seul écart réel entre les deux contrats et vient de ce que le Combat est une famille et le travail plusieurs.

#### Les ouvriers sont l'énergie, et ils sont nominatifs

Il n'y a **qu'un seul budget d'ouvriers**, et il joue le rôle de l'énergie d'un deckbuilder : les cartes disent ce qu'on peut faire, les ouvriers disent combien on peut en faire. Deux contraintes qui se croisent, et non deux ressources qui se doublent.

La subtilité qui distingue ça d'un simple compteur : **on choisit *qui* on place.** Les ouvriers n'ayant pas les mêmes pistes, envoyer le bon sur la bonne action est la décision de fond de chaque phase. C'est pourquoi l'affectation reste nominative jusque dans les contrats — `Assignment` associe un **ouvrier** à une action et à une cible, jamais un nombre.

#### Risque identifié — le micro-management

Des effectifs à quinze, sur deux phases, pendant quinze jours, c'est plusieurs centaines de décisions par run dont la plupart sont évidentes. Mitigations à prévoir dès la conception de l'UI : effectifs volontairement réduits, bouton d'auto-affectation avec surcharge manuelle, affectation persistante d'une phase à l'autre par défaut. Ce risque augmente mécaniquement si le modèle à deux phases symétriques est retenu.

*(Corrigé à `W2`.)* Cette liste se terminait par « c'est du travail d'adapter, pas de domaine », et c'est vrai des deux mitigations qui encadrent la troisième : un effectif réduit est un chiffre d'équilibrage, une affectation persistante est une politique d'écran. **Le bouton, lui, est du domaine.** Classer des ouvriers exige la famille que chaque action posée créditera — que seul le résolveur de production sait calculer —, les multiplicateurs de la `LaborForce`, et la capacité figée à la pose ; l'écrire dans une vue reviendrait à y recopier une règle dont le résolveur dit qu'elle est « posée ici et nulle part ailleurs ». Et le bouton est **un geste** : le déterminisme promis depuis `I0` — un seed plus une suite de gestes rejoue un run — ne tient que si son résultat est reproductible et testable, ce que `src/adapters/` n'est pas.

**Ce que le bouton décide, et ce qu'il refuse de décider.** *(Tranché à `W2`.)* Il parcourt les actions **dans l'ordre de pose** et remplit les postes qui restent avec l'ouvrier libre le plus efficace dans la famille de cette action ; à égalité, l'ordre du roster départage. Il saute une action que rien ne crédite, et ne déplace **jamais** un ouvrier placé à la main — c'est ce qui fait de la surcharge manuelle un geste qui tient, quel que soit l'ordre dans lequel on s'y prend.

**Il départage à multiplicateur égal par l'XP de piste.** *(Écrit après `I2`.)* Un multiplicateur vient d'un **palier**, donc six ouvriers frais valent tous 1.00 et le classement n'avait plus rien à comparer : il retombait sur l'ordre du roster, c'est-à-dire pendant toutes les journées où le bouton sert le plus. Préférer celui qui est le plus près du palier suivant concentre l'XP au lieu de l'étaler, ce qui est exactement la spécialisation que cette section réclame. L'XP ne renverse jamais un palier acquis — c'est le seul des deux que la production multiplie.

C'est ce qui a fait entrer l'XP de piste dans la `LaborForce`, premier contrat à bouger depuis `F1`. Elle n'y donne aucun rendement : elle sert à **ordonner**, jamais à calculer.

Il ne pondère **pas** par le rendement : une récolte à 3 et une case nue à 1 se valent devant lui. Pondérer rendrait un cran de chantier comparable à une récolte, ce qui est un arbitrage d'équilibrage et appartient à `I3`. Le bouton ne choisit donc jamais quelle action mérite un ouvrier — **l'ordre de pose est la priorité que le joueur a déjà exprimée**. Il ne choisit que *qui*, et c'est précisément la moitié évidente de la décision.

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

**Une carte ouvre les postes de sa cible une fois.** Une seconde du même nom au même endroit les rouvrirait, et trois ouvriers produiraient dans une cabane qui n'en tient que deux — la carte cesserait d'être une permission pour devenir un multiplicateur.

**Et pour l'instant, une cible ne porte qu'une action, quelle qu'elle soit.** *(Renversé après `I2`.)* Cette section disait le contraire — « deux cartes *différentes* sur une même cellule restent acceptées ; c'est le doublon qui est refusé, pas le partage » —, et c'était le cas pour lequel `D2` avait donné une identité aux actions : *Récolter* et *Chasser* sur une même forêt, « deux métiers sur une même terre ».

La règle n'a pas survécu à une partie jouée à la main, et pour une raison d'**écran** et non de design. Une case se désigne d'un seul curseur : la touche qui affecte, le clic qui retire et la ligne de survol ne peuvent atteindre qu'une des deux actions, et l'autre n'existe plus que dans une liste de panneau bornée. Le domaine autorisait un geste que rien ne pouvait viser — c'est-à-dire une règle que le joueur ne pouvait ni voir ni employer.

Le retour en arrière est **provisoire et assumé** : c'est la contrainte la moins chère qui rend la carte lisible, et elle se lève le jour où un écran sait désigner l'une des deux — un cycle au clic, un menu, ou une pile visible sur la case. Ce que le partage protégeait reste vrai d'une journée à l'autre ; il cesse de l'être dans la même phase.

**Retirer une action rend sa carte.** *(Tranché à `W2`.)* Le retrait est une **annulation**, pas un sacrifice : il n'est possible que dans la phase qui a posé, et à ce moment rien n'a été consommé — aucun ouvrier n'a travaillé, la réserve n'a pas bougé. Il n'y a donc rien à faire payer, et une carte qui ne reviendrait pas punirait une cible mal visée plutôt qu'une décision.

Ce n'est **pas** une réponse à l'`OUVERT` ci-dessous, et la distinction vaut d'être écrite parce que le code les avait confondues de `D2` à `W2` : cet `OUVERT` porte sur les cartes **non jouées en fin de phase**, celle-ci a été jouée et reprise dans la phase même. Deux gestes, deux moments, deux questions. Le scumming qu'on pourrait craindre — poser pour lire la capacité, retirer, reposer ailleurs — n'existe pas : le ciblage annonce déjà la capacité avant le jeu.

Une **carte de bâtiment** ne s'annule pas, puisqu'elle ouvre un chantier et qu'aucun geste ne le retire. Ce que rendrait un chantier annulé reste l'`OUVERT` de 3.2.

**Le sens d'un terrassement se choisit à la pose.** *(Tranché à `I1`.)* Il y a **une** carte *Terraformer* et deux sens, et le sens appartient au **jeu** de la carte, exactement comme l'orientation d'un bâtiment appartient au placement et non à sa `BuildingData`. La carte reste un outil que l'on oriente plutôt qu'un tirage dont on subit le sens.

Le prix est connu et il a été payé sciemment : deux DTO de `contracts/` — l'action posée et le verdict de ciblage — portent désormais un sens, et le ciblage le reçoit en argument. Un défaut le rend invisible aux trois verbes qui ne déplacent rien.

**L'eau et le rocher ne se terrassent pas.** *(Tranché à `I1`.)* Seul un terrain **constructible** l'accepte, et la raison est mécanique plutôt que thématique : terrasser déplace la **hauteur**, pas le `TerrainData`. Monter une case d'eau la laisserait eau — inconstructible, toujours tagguée `water` — pour le prix d'une carte et d'un ouvrier. Le jour où l'on voudra changer le sol lui-même, ce sera un *Défricher*, et c'est un autre verbe.

Deux **bornes de relief** encadrent le terrassement, dans `data/balance/`, et elles sont volontairement distinctes de celles de la génération : celles-là décrivent la carte qu'on reçoit, celles-ci jusqu'où on a le droit de la pousser. Les confondre interdirait de creuser sous le point le plus bas de la génération, ce qui est pourtant le geste évident quand on veut un plateau.

#### Certains bâtiments débloquent des actions

La caserne fait exister *S'entraîner*, l'atelier *Fabriquer*, le camp d'exploration *Explorer*. Ces actions n'ont **pas** de version à cru : sans le bâtiment, la carte est injouable.

C'est une flèche neuve dans l'architecture — jusqu'ici rien ne remontait de la ville vers les cartes. Le sens à respecter est **le Deck interroge la ville**, via un contrat qui énumère ce qui est débloqué ; la ville ne pousse rien dans le deck. Un système du domaine ne notifie personne, il répond.

**`OUVERT` — la nature d'une carte de bâtiment.** *(Posé après `I2`.)* Les actions tournent : jouées, défaussées, remélangées quand la pioche s'épuise. Un bâtiment devrait-il faire de même ? La piste est qu'il soit **à usage unique** — détruit quand il est posé, puisqu'on ne bâtit pas deux fois la même ferme au même endroit — ce qui rendrait le pool des bâtiments fini et donc précieux. Elle en appelle immédiatement une autre : **comment en gagne-t-on ?** Un choix parmi trois, à la façon d'un roguelite, après une vague ou dans un événement de 3.7. Les deux se tranchent ensemble ou pas du tout.

**`OUVERT` — garder, redessiner, et ce qu'un départ offre.** *(Posé après `I2`.)* Trois questions voisines qui touchent toutes au même endroit du tour. Un moyen de **conserver** une carte d'une phase à l'autre — un pouvoir, une règle de héros de départ, une méta-progression de 6.1. Un principe de **redraw**, qui est la réponse classique à une main impayable. Et ce qu'un gouverneur de départ change au deck, que 6.1 annonce sans le décrire. Elles ne se posent qu'après l'`OUVERT` ci-dessous, dont elles sont des variantes : toutes répondent à « que fait-on d'une main qu'on ne peut pas jouer ».

**Les piles se consultent, et sans leur ordre.** *(Écrit à `P1b`.)* Une pioche et une défausse s'ouvrent à la touche `P`, par pool. Ce qu'elles montrent est un **recensement** — combien de *Récolter* restent — et jamais l'ordre du paquet, et le refus est une décision de design et non une commodité d'affichage : lire les trois prochaines cartes répondrait par accident à l'`OUVERT` ci-dessous, en faisant de « que fait-on d'une main qu'on ne peut pas jouer » un calcul au lieu d'un pari. Le domaine ne rend donc pas l'ordre, ce qui met la règle hors de portée d'une vue distraite plutôt que dans un commentaire — même geste que le bloc `production` nullable de 3.3.

C'est ce qui rend l'`OUVERT` ci-dessous **jouable** plutôt que répondu : `I2b` doit arbitrer ce que devient une main non jouée, et personne ne peut arbitrer ça sans savoir ce qu'il reste à piocher.

**`OUVERT`** — taille de la main et du deck, et sort des cartes non jouées en fin de phase. Défausser toute la main crée de la tension et empêche la thésaurisation, mais frustre quand on pioche trois bâtiments impayables. La question se pose **par pool**, ce qui la complique — trois pioches, trois défausses, trois tailles de main.

*(Mise en état d'être jouée à `I2b`, et pas répondue.)* C'est un **bouton de `data/balance/`** depuis ce jalon : `carry_over` dit par pool combien de cartes non jouées survivent à une phase qui résout, et la pioche **complète** la main au lieu d'en servir une neuve. Deux valeurs seulement, et c'est ce qui rend le bouton lisible : zéro défausse tout — la tension d'origine —, la taille de la main garde tout — la « main persistante » ci-dessus. Garder se paie alors tout seul : **une carte gardée est une carte de moins piochée**, ce qui rend inutile la « limite de jeu par tour » qu'on lui adjoignait, et ce qu'une chronique chiffre — deux cent dix cartes vues sur un run qui défausse contre cent cinquante-trois sur un run qui garde.

**Le milieu est refusé, et c'est structurel plutôt qu'un manque.** Garder deux cartes sur cinq demande de dire *lesquelles*, et la seule règle qui ne choisisse pas à la place du joueur est qu'il choisisse — donc un geste de fin de phase, donc un écran. Le résoudre par une règle d'ancienneté aurait répondu à cet `OUVERT` par un arbitraire, ce que le recensement des piles a refusé pour la même raison ci-dessus. Le jour où le geste existe, c'est le contrôle de `DeckBalance` qui se desserre et rien d'autre.

Des deux alternatives qui restent, **« défausser contre une petite ressource » n'est pas un bouton** : c'est une conversion qui touche la réserve plus un geste pour désigner quoi vendre, donc une mécanique et non un réglage. Elle ne se teste pas en échangeant un `.tres`, et elle attend qu'on ait joué les deux qui le peuvent.

### 3.6 Combat

> **Contrat** — `CitySnapshot` + `CombatForce` + `WaveDef` → `DamageReport`. C'est **le seul** contrat qui compte. Tout ce qui se passe entre les deux est remplaçable sans toucher au reste du jeu.

**Contrainte désormais fixée : le vivier est unique** *(cf. 3.4)*. Le format retenu devra rendre un ouvrier ordinaire utile au combat, ou assumer que l'on immobilise l'économie pour tenir une ligne. Ce n'est plus une question ouverte que `F2` tranchera, c'est une contrainte d'entrée que `F2` doit satisfaire.

#### Le format — tactique au tour par tour, sur la grille du village

*(Tranché après `F1`, en discussion.)* Les trois pistes envisagées — tower-defense, auto-battler observé, tactique au tour par tour — avaient le même contrat ; c'est la troisième. Référence assumée : *The Last Spell*, avec beaucoup moins d'unités.

**Deux tours par manche, par camp.** Un tour où l'on déplace les ouvriers déployés et où chacun agit ; un tour où les ennemis se déplacent et frappent. Pas d'initiative entrelacée : c'est ce qui rend les intentions ci-dessous possibles, et c'est le format le plus lisible à trois pions.

**Les ennemis annoncent leur tour entier.** Chaque ennemi affiche, pendant le tour du joueur, **où il ira et quelle case il frappera** — pas seulement son action, mais sa planification complète. Une intention qui ne dirait que « il attaquera » laisserait une incertitude qui viderait la promesse : l'information doit être complète, sinon le tour du joueur n'est plus un puzzle mais un pari.

**Une intention frappe la case, pas la cible.** Esquiver l'annule — l'attaque s'exécute dans le vide. C'est ce qui fait du déplacement la décision centrale plutôt qu'un préambule à l'attaque. Conséquence gardée volontairement ouverte : si un **autre** corps se trouve sur la case au moment de l'exécution, il prend le coup, ennemi compris. Les effets de poussée qui feraient de cette règle un vrai puzzle de manipulation ne sont pas au périmètre de `F2` — mais la règle est écrite dans ce sens dès maintenant, pour n'avoir pas à la retourner le jour où ils arriveront.

**Ils visent les ouvriers à portée, les bâtiments sinon.** Une seule ligne d'IA, et c'est elle qui empêche la stratégie dominante la plus bête du format : sur une carte de 32×32 très majoritairement vide, fuir en rond serait autrement gratuit. Ici fuir est un **troc** — on garde ses gens, ils mangent les murs —, et c'est exactement ce que le rapport de sortie sait déjà dire.

**Le champ de bataille est le village, entier.** Pas de recadrage ni d'arène : la caméra zoome sur le côté attaqué, et c'est suffisant. La contrepartie est que **la vague entre à la lisière du bâti et non au bord de la carte** — seize cases de marche avant le premier contact seraient quatre tours où personne ne décide rien.

**La direction s'annonce à l'avance**, par une flèche à l'écran. Ce n'est pas du confort : 3.2 veut qu'on pense à la bataille en posant un bâtiment, et une direction révélée le soir même transformerait cette prévoyance en loterie. C'est aussi ce qui donne au relief et à l'empreinte d'un bâtiment un second sens, celui que l'`OUVERT` de 3.1 cherchait.

**La date s'annonce par le même argument.** *(Écrit après `I2`.)* Elle avait été oubliée, et c'est plus grave que la direction, qui attend de toute façon `F2` : jusqu'ici une vague apparaissait à l'écran le soir où elle tombait, si bien que la palissade se bâtissait après coup ou par superstition. Ce que le calendrier de 2 sait — quelle vague, dans combien de journées — se lit donc en permanence, et c'est une information de décision plutôt qu'un compte rendu. La **composition** reste ce qu'un éclaireur de 3.7 révélerait en plus.

**Le relief joue, et c'est la première chose qui l'emploie autrement que comme contrainte de pose.** Monter coûte, une marche trop haute bloque. Le terrassement de 3.1 devient donc un geste militaire autant qu'économique.

#### Ce qu'une manche gagne, et ce qu'elle coûte

**Une vague est une razzia, pas un duel.** Tenir N tours suffit à ce qu'elle reparte ; **battre tous les ennemis** donne un bonus par-dessus. Il n'y a donc pas de victoire ni de défaite au combat, seulement une facture — ce qu'ils ont cassé et emporté entre-temps. La défaite d'un **run** reste celle de 5. : le Cœur détruit ou le roster vide.

C'est aussi ce qui rend la borne de tours honnête. Sans elle, une manche s'étire ; avec elle mais sans objectif ennemi, elle s'esquive. Les deux ensemble donnent une pression qui monte et une sortie qui se paie.

**Un ouvrier à zéro point de vie meurt.** C'est le choix le plus dur et il sert le pitch : une unité expérimentée perdue est une vraie perte, et chaque dégât compte. Il a un revers qu'il faut nommer — **sans blessure, un combat n'a que deux issues, rien ou définitif**, et le joueur qui a bien joué ne sent rien du tout. Les points de vie sont la ressource **de la manche** ; ce qu'un survivant en emporte est un **effet progressif selon la part de vie perdue**, et c'est `X6` qui l'écrira. Le combat rend donc `X6` structurant plutôt que confortable.

#### Ce que `F2` livre, et ce qu'il ne livre pas

Deux verbes : **se déplacer** et **attaquer**. Plus les intentions, le relief dans le déplacement, les bâtiments qui bloquent et qui tombent, et la borne de tours.

**Les capacités spéciales n'y sont pas**, et c'est la seule chose que ce document retient volontairement d'un format qu'il vient d'accepter. Un système de capacités générique — ciblage, effets, coûts — est un jeu entier, et il tuerait `F2` avant qu'on sache si le format tient. Elles ont déjà leur place : `X5` demande depuis `W1` « ce qu'un palier de niveau d'ouvrier offre », et la réponse est là. **Une capacité est ce qu'un palier de piste Combat débloque** — ce qui enracine le combat dans le roster nominatif au lieu d'en faire un jeu d'échecs greffé, et donne enfin une raison d'être à *S'entraîner* (`X3`).

Les états — poison, étourdissement, saignement — sont `X6` et rien d'autre. `F2` ne doit pas en inventer un seul, il en inventerait quatre.

**Stratégie de développement.** Une première implémentation `InstantCombatResolver`, purement arithmétique et sans vue, sert de bouchon pour boucler la boucle de jeu au plus tôt — c'est `F1`, et c'est fait. Le vrai système se développe ensuite en parallèle, alimenté par des `CitySnapshot` fabriqués à la main.

*(Branché à `I2`.)* Le bouchon est en place dans la boucle : les vagues du calendrier de 2 tombent à leur date, et le run se joue du premier jour au dernier. Ce qui reste à `F2` est le **milieu** — le plateau, les deux verbes, les intentions — et non les deux bouts, qui sont écrits et exercés.

*(Corrigé après `F1`.)* Ce paragraphe promettait que l'échange serait « une ligne dans l'orchestrateur ». **C'est faux pour un format au tour par tour**, et le savoir maintenant coûte moins cher que de le découvrir à `I2`. Un résolveur rend un rapport ; un combat tactique **attend le joueur**, pendant des dizaines de frames et de clics, et le domaine n'a pas le droit d'`await`.

Ce qui est vrai en revanche, et c'est ce que `F1` a livré sans le chercher : `RunOrchestrator.fight()` sépare déjà **produire** le rapport — une ligne — et **l'appliquer** aux trois systèmes — tout le reste. L'applicateur ne bouge pas. Le producteur, lui, cesse d'être une fonction pour devenir un **état** : un plateau mutable dans `domain/combat/`, des fonctions pures qui appliquent un geste à la fois, et un `DamageReport` au bout. L'adapter pilote le milieu, comme il pilote déjà une phase.

Le `DamageReport` doit couvrir dès maintenant les cas dont les autres systèmes ont besoin : bâtiments détruits ou endommagés, **chantiers interrompus**, pertes parmi les effectifs engagés, XP de combat gagnée, ressources pillées.

*(Corrigé à `F1`.)* Cette liste disait « pertes **et blessures** », et la blessure en est retirée : elle appartient au système d'états de `X6`, avec la faim de 3.3. Ce n'est pas un renoncement mais un déménagement — une blessure a besoin d'un état qui dure, un `Worker` n'en porte aucun aujourd'hui, et l'inventer dans le rapport d'un système neuf aurait décidé pour les Effectifs de ce qu'un état fait. Le champ entrera dans ce rapport le jour où il aura quelque part où atterrir.

#### Le déploiement, et pourquoi il est capé

*(Tranché à `F1`.)* Un combat s'ouvre par un **déploiement** : on choisit qui va sur la ligne, dans un nombre de places **borné**. La borne est une base d'équilibrage plus ce que certains bâtiments ajoutent — la caserne au premier chef —, exactement comme l'entrepôt relève la réserve et l'habitation les places du roster. C'est le troisième plafond du jeu bâti sur le même modèle, et le troisième champ plat d'un `BuildingData`.

C'est ce qui fait exister au combat la tension que le pitch promet. Sans borne, tout le roster se bat, un ouvrier de plus est un défenseur de plus, et « envoyer son meilleur récoltant en milice » ne coûte rien puisqu'on les envoie tous. Avec elle, une place est rare : la donner à son meilleur récoltant est un vrai choix, et **construire une caserne devient une décision de guerre** plutôt qu'un déblocage d'action.

Deux conséquences que le contrat porte déjà. Seuls les **engagés** meurent et gagnent de l'XP de combat — les autres sont au village. Et le plafond se lit sur la ville **achevée** : une caserne en chantier n'ouvre aucune place, pour la raison qui vaut depuis `C4` — un toit qu'on n'a pas posé ne loge personne.

*Qui* se déploie est un geste, et `F1` ne l'écrit pas : il engage automatiquement les plus aguerris jusqu'à la borne. C'est un bouchon du même ordre que le Cœur posé au centre à `I1` — l'écran qui pose la question appartient à `F2`, et la règle automatique lui survivra comme bouton par défaut.

#### Ce que le bouchon calcule, et ce qui reste jetable

*(Écrit à `F1`.)* L'arithmétique tient en une ligne : la ville et les engagés opposent une **défense**, la vague une **puissance**, et la différence est une **brèche** qui se dépense. Rien n'y est définitif — c'est un bouchon, et `F2` le remplacera entier.

Une seule de ses règles mérite d'être ici plutôt que dans le code, parce qu'elle se discute : **une brèche casse d'abord ce qui la retenait**, puis ce qui cède le plus vite. Défense décroissante, puis points de vie croissants. Elle a deux vertus — la palissade sert vraiment à quelque chose, et le Cœur se retrouve en dernier sans qu'une ligne de code n'écrive son nom, puisqu'il est le plus solide du tableau de 4.1. Elle ignore délibérément l'ordre de pose : deux villes identiques bâties dans un ordre différent doivent perdre la même chose, ce que 3.3 exige déjà de l'écrêtage.

**`OUVERT`** — ce qui reste après la discussion qui a suivi `F1`, et c'est nettement moins qu'avant : **la nature des vagues** — qui vient, combien, avec quelles portées —, **la borne de tours** d'une manche, et **le bonus** que vaut un nettoyage complet. Les trois sont des chiffres et du contenu, donc `I3` et `F2` ; aucun ne remet en cause le format.

Le format, la vue, le degré de contrôle du joueur, la direction des vagues et le rôle du relief **ne sont plus ouverts** : ils sont ci-dessus.

L'ordre des dégâts du bouchon, lui, reste **explicitement jetable** : il disparaît le jour où une vague vient d'une direction plutôt que d'un chiffre, ce qui est désormais daté.

### 3.7 Événements

> **Contrat** — un modificateur tiré chaque soir, appliqué avant ou après la production selon son type.

Source d'aléatoire quotidien indépendante de la pioche. Pistes : arrivée d'ouvriers, tempête qui détruit une défense, filon révélé, disette, caravane marchande.

*(Précisé après `F1`.)* L'« éclaireur qui révèle la prochaine vague » sort de cette liste : 3.6 fait de la direction d'une vague une **information de base**, annoncée par une flèche à l'écran, parce que sans elle on ne peut pas poser un bâtiment en pensant à la bataille. Ce qui reste à un éclaireur événementiel est donc ce qu'il révélerait **de plus** — la composition, la portée, le nombre —, et c'est un meilleur événement : il ajoute de la lecture au lieu de rendre jouable ce qui ne l'était pas sans lui.

### 3.8 Cycle de jour

> Le seul système qui connaît tous les autres. C'est volontaire : il orchestre, les autres s'ignorent.

Machine à états sur les phases, séquence de résolution, conditions de fin, transition vers l'écran de récompense.

*(Écrit à `I1`.)* Il enchaîne **deux sortes de résolution** — la phase produit, la journée coûte *(cf. 2)* — et c'est la seule chose du projet qui sache que les deux existent. Chaque système ne connaît que sa part.

Il tient trois choses. Le **cycle**, qui marche sur la liste de `PhaseDef` sans jamais savoir où il est. L'**état du run** — relief, ville, réserve, roster, deck, actions posées, brouillon d'affectation —, qui est le seul objet du projet à tenir les internes de plusieurs systèmes, et c'est cette section qui l'autorise. L'**orchestrateur**, qui ne calcule rien : il enchaîne deux questions là où chaque système n'en répond qu'à une, et il applique des ordres que les résolveurs se contentent de rendre.

C'est ce qui a permis à deux choses annoncées de longue date de devenir vraies. La **bourse au moment de bâtir** de 3.2 — « ai-je les 15 bois ? » est une seconde question, posée par la couche qui orchestre la journée. Et l'**exécution** de *Construire* et de *Terraformer*, que `D2` avait laissée en attente parce que leur effet mute l'état de deux autres systèmes : le résolveur ordonne, l'orchestrateur applique, et il est le seul à tenir les deux.

**Le déterminisme cesse d'être une consigne.** Un seed plus une suite de gestes rejoue un run à l'identique — la réserve, le relief, l'avancement des chantiers, l'XP —, et c'est vérifié plutôt que promis.

#### La fin de journée devra cesser d'être atomique

*(Écrit après `F1`, avant d'en avoir besoin.)* Le combat de 3.6 **clôt la journée** : il se déclenche à la fermeture, après la résolution de la dernière phase et après l'upkeep, exactement à la place que la séquence de 2 lui garde. Et il attend le joueur pendant des dizaines de tours.

Or la fin d'une phase est aujourd'hui **un seul geste indivisible** — résoudre, vider le plateau, avancer. La rupture interactive tombe au milieu. Le cycle devra donc **refuser d'avancer tant qu'une bataille est en attente**, ce qui est un état de plus sur le run et une porte de moins qui fait tout d'un coup.

C'est écrit ici plutôt que découvert à `I2` parce que le coût des deux n'est pas le même : une demi-heure aujourd'hui, un écran à moitié câblé à défaire ensuite. Le rapport de journée n'accueillera d'ailleurs pas un rapport de bataille mais **la vague en attente** ; ce que la bataille a coûté revient par la seconde porte.

*(Fait à `I2`, et la prévoyance a été payante.)* La coupure existe, exactement dans ces termes. Une journée qui se ferme sur une vague **arme** au lieu de frapper ; la fin de phase résout, vide le plateau, défausse la main, et s'arrête là ; c'est la seconde porte qui ouvre la phase suivante quand la bataille est passée. Le run a donc un état de plus, et il n'en a coûté **qu'un** : quand une bataille attend, le cycle pointe encore sur la phase qui vient de finir, si bien que « fallait-il repiocher ? » se relit au lieu de se retenir.

Le prix annoncé — une demi-heure — était juste, et il aurait été bien plus élevé après coup : les deux moitiés de la coupure ont chacune leur cas de test, et l'écran n'a eu qu'à lire un état de plus.

### 3.9 Expéditions — `HORS MVP`

L'action *Explorer*, débloquée par le camp d'exploration, envoie des ouvriers **hors de la carte** pour plusieurs jours. Ils reviennent avec un événement dont l'issue dépend de leurs pistes de compétence — butin, découverte, blessure, ou personne ne revient.

Ce n'est pas une carte, c'est un système : il lui faut un état persistant entre les jours, une table d'issues en data, et une place dans la séquence de résolution. Rien n'en est écrit avant que la boucle soit jouable.

**Ce que ça contraint aujourd'hui**, et c'est la seule raison de cette section : des ouvriers peuvent être **absents du roster** sans être morts. Rien dans les Effectifs ne doit supposer que tout le roster est disponible tous les soirs — ni l'upkeep, qui devra décider si un absent mange, ni l'affectation, qui ne doit pas pouvoir les placer.

---

## 4. Contenu de départ

### 4.1 Bâtiments

Chiffres à prendre comme point de départ d'équilibrage, pas comme cible. La colonne **Chantier** est le nombre d'actions *Construire* à jouer pour l'achever ; la colonne **Dépl.** ce que le bâtiment ajoute aux places de déploiement de 3.6, par-dessus la base d'équilibrage.

| Bâtiment | Coût | Chantier | Production | Déf. | PV | Dépl. | Débloque |
|---|---|---|---|---|---|---|---|
| Cœur | posé au départ | — | — | 0 | 30 | 0 | — |
| Camp de bûcheron | 0 | 1 | 2 slots, +2 bois — Récolte | 0 | 4 | 0 | — |
| Ferme | 10 bois | 2 | 2 slots, +3 nourriture — Récolte | 0 | 4 | 0 | — |
| Carrière | 15 bois | 2 | 2 slots, +2 pierre — Récolte | 0 | 6 | 0 | — |
| Mine | 25 bois, 10 pierre | 3 | 2 slots, +2 minerai — Récolte | 0 | 8 | 0 | — |
| Habitation | 20 bois | 2 | +2 places de roster | 0 | 5 | 0 | — |
| Entrepôt | 20 bois | 2 | +100 de réserve | 0 | 6 | 0 | — |
| Palissade | 5 bois | 1 | — | 3 | 4 | 0 | — |
| Tour de guet | 15 bois, 10 pierre | 3 | 1 slot, +8 déf. si occupée | 8 | 10 | 0 | — |
| Caserne | 30 bois, 15 pierre | 3 | 1 slot | 0 | 10 | **+1** | *S'entraîner* |
| Marché | 30 bois, 10 minerai | 3 | 1 slot, 2 échanges 3:1 | 0 | 6 | 0 | — |
| Atelier | 25 bois, 15 minerai | 3 | 1 slot | 0 | 8 | 0 | *Fabriquer* |
| Camp d'exploration | 20 bois, 10 minerai | 2 | 1 slot | 0 | 6 | 0 | *Explorer* |

La **palissade** est entrée par la pratique et non par le design : `C2` l'a créée pour son empreinte en L, la seule forme non rectangulaire du projet, donc le seul cas qui exerce vraiment la rotation du fantôme et le validateur. Elle est inscrite ici à `E1b` pour que ce tableau redise ce que `data/` contient. Une défense de départ bon marché y a sa place de toute façon.

Les bonus d'adjacence ne sont pas dans cette table : ils viennent avec `C3`, qui décidera de leur forme avant de les chiffrer.

**Ce que `data/` porte, et ce qu'il ne porte pas encore.** *(Constaté à `E1b`, complété à `F1`.)* Un champ arrive avec le système qui le lit : la colonne **Chantier** y est entrée à `C4`, **Déf.**, **PV** et **Dépl.** à `F1`. Il ne reste dehors que **Débloque**, ci-dessous, et les bonus d'adjacence de `C3`.

La **caserne** cesse à ce jalon d'être une coquille : ses places de déploiement sont la première chose qu'elle fasse, et elles arrivent avant l'action qu'elle débloquera à `X3`. C'est un renversement de ce que le tableau laissait croire — on la bâtissait pour *S'entraîner*, on la bâtira d'abord pour tenir la ligne — et il est délibéré : un bâtiment dont le seul intérêt est de débloquer une carte n'a rien à faire dans un MVP dont cette carte est absente.

La colonne **Dépl.** est celle où le zéro règne le plus largement — douze bâtiments sur treize —, et c'est le troisième champ plat construit sur ce modèle après `storage_bonus` et `roster_places`. Les trois relèvent un plafond global et ne décrivent aucune nature ; c'est ce qui les distingue du bloc `production` de 3.3, et ce qui leur vaut d'échapper à la doctrine du zéro : réclamer un chiffre que presque personne ne porte refuserait de démarrer sur des données correctes.

*(Corrigé juste après `F1`.)* La caserne y valait **+2**, et c'était trop : sur une base de trois places, un seul bâtiment ajoutait deux tiers de la ligne d'un coup. Une place de déploiement se gagne **très progressivement** — c'est un pion de plus à jouer chaque tour, donc autant de la profondeur que de la longueur *(cf. 3.6)*. À +1, bâtir une seconde caserne redevient une décision au lieu d'être une évidence.

**Débloque** était annoncée pour `D1` et n'y est pas entrée. *(Tranché à `D1`.)* Les trois actions qu'elle concerne — *S'entraîner*, *Fabriquer*, *Explorer* — sont marquées `MVP : non` en 4.2 et ne sont donc pas au catalogue de cartes ; un champ qui ne débloquerait rien serait une frontière que personne ne franchit, ce qui est exactement l'argument qui a sorti `CombatForce` de `W1`. Elle entrera avec `X3`, `X2` et `X1`, en même temps que les cartes qu'elle verrouille. Le coût du report est connu et faible : un champ sur `BuildingData`, trois `.tres` à rouvrir, et une lecture de plus sur `CitySnapshot.completed()` — qui a déjà trois consommateurs et la porte ouverte.

Le « — » du Cœur dans la colonne Chantier est un **zéro**, comme son « posé au départ » dans la colonne Coût est un coût vide. C'est ce qui lui évite un chemin de pose particulier : un bâtiment qui ne réclame aucune action est achevé dès qu'il est posé, sans que rien n'ait à connaître le cas. *(Vérifié à `I1`, où l'ouverture d'un run le pose vraiment : il sort achevé, sans une ligne de cas particulier. Son « posé au départ » est un champ de `data/balance/` — l'identifiant d'un bâtiment écrit dans du GDScript aurait été le nombre magique que les conventions refusent. Le poser au centre est un bouchon : l'écran qui le demandera au joueur appartient à `I2`.)* Le prix assumé de ce choix est qu'un `build_actions` oublié dans un `.tres` vaut 0 et fait sauter le chantier en silence ; un cas de test exige donc qu'au moins un bâtiment de `data/` en déclare un, ce qui rattrape la disparition du format entier. *(Tranché à `C4`.)*

Les places de roster de l'habitation y sont entrées à `W1`, ce qui a sorti ce bâtiment de la coquille vide où `E1b` l'avait laissé. La conséquence à ne pas confondre avec un oubli : **cinq bâtiments portent « 1 slot » dans ce tableau et n'ont pourtant aucun bloc `production`** — tour de guet, caserne, marché, atelier, camp d'exploration. Leur poste n'est pas un poste de production ; il héberge une défense, un échange ou une action débloquée, et la nature qui le décrira n'existe pas encore. Leur écrire un `slots = 1` que rien ne lit ferait mentir la data et détruirait la garantie que `E1b` vient d'acheter — un bloc qui existe produit.

*(Toujours vrai à `F1`, et il fallait le vérifier.)* La tour de guet porte « +8 déf. **si occupée** », et `F1` était le jalon nommé pour la lire. Elle n'entre pourtant pas : **aucun verbe de 4.2 ne tient un poste de défense.** Il faudrait une carte pour y envoyer quelqu'un, et l'inventer ferait un huitième verbe hors de ce tableau. `F1` ne lit donc que le `Déf.` **plat** de la colonne, celui qu'un bâtiment offre du seul fait d'être debout, et la tour de guet vaut 8 sans qu'on ait à la garnir. Le poste occupé attend son verbe, comme les quatre autres attendent le leur.

### 4.2 Actions

| Action | À cru | En slot | MVP |
|---|---|---|---|
| Récolter | +1 de la ressource du tag visé (`forest`, `stone`, `ore`) | rendement du bâtiment × piste Récolte | oui |
| Chasser | +1 nourriture sur une case `forest` | — *(pas de bâtiment de chasse pour l'instant)* | oui |
| Construire | — | avance un chantier d'un cran | oui |
| Terraformer | monte **ou** descend d'un cran une case libre et **constructible**, sens choisi à la pose | — | oui |
| S'entraîner | — | XP de la piste choisie, à la caserne | non |
| Fabriquer | — | convertit des ressources, à l'atelier | non |
| Explorer | — | envoie une expédition, au camp d'exploration | non |

*Chasser* est la façon d'obtenir de la nourriture avant d'avoir une ferme : la version à cru d'un besoin qui devient ensuite un bâtiment. Un bâtiment de chasse pourra s'ajouter plus tard sans rien changer à la règle.

***Terraformer* est sorti du deck de départ après `I2`**, et le verbe reste écrit. Ce n'est pas un renoncement : son **sens** — monter ou descendre — ne s'affiche nulle part. La touche le retourne bien, mais seulement carte en main, et ni la ligne de survol ni les cibles allumées ne disent lequel des deux on s'apprête à faire. Une carte qu'on oriente à l'aveugle est pire qu'une carte qu'on subit, ce qui est précisément l'inverse de ce que 3.5 cherchait en faisant du sens un choix de pose. Elle revient dans le deck le jour où l'écran montre où va la terre. **Ce jour n'est rattaché à aucun jalon**, et c'est voulu : la passe de confort l'a écarté de `P1a` puis de `P1b`, et c'est l'humain qui dira quand. Le verbe, son ciblage et sa résolution restent écrits et exercés en attendant.

**`data/cards/` ne contient que les quatre premières.** *(Écrit à `D1`.)* La colonne MVP n'est pas indicative : les trois dernières n'ont ni résolution, ni bâtiment pour les débloquer, et les écrire aujourd'hui reviendrait à mettre dans le deck des cartes injouables pour plusieurs jalons. Elles entrent avec `X1`, `X2` et `X3`, en même temps que la colonne **Débloque** de 4.1.

Ce qu'une action **fait** n'est pas dans `data/` non plus, et ne le sera pas : les sept verbes se résolvent chacun autrement, donc une *nature* d'action est du code de `src/domain/`. La carte porte son identité et son pool ; c'est tout ce que le deck consomme. Même règle qu'en 3.3 pour les bâtiments.

*(Écrit à `D2`.)* Cette règle a tenu à l'épreuve : les quatre verbes MVP sont ciblés par un seul fichier de `src/domain/deck/`. Leurs **chiffres**, eux, sont en data — quels tags chaque verbe exploite, ce qu'une case nue rend, combien d'ouvriers elle accepte —, et c'est cette séparation qui permet au résolveur d'Économie de n'avoir aucune liste de noms.

*(Corrigé à `I1`.)* `D2` ajoutait que ce fichier était « le seul endroit du projet où un identifiant de carte est écrit en dur ». Il y en a deux depuis que les verbes s'exécutent, et c'est juste : **où** un verbe se pose et **ce qu'il fait** sont deux questions, la seconde étant précisément celle que le paragraphe ci-dessus refuse de mettre en data. Ce que la phrase protégeait — que le résolveur d'Économie ne nomme personne — tient toujours. La garantie « un seul fichier » est remplacée par une plus forte, et vérifiée par un cas de test : **tout verbe que le ciblage accepte est soit productif selon `data/balance/`, soit exécuté par le résolveur de chantiers.** Aucun ne peut se poser, s'affecter et ne rien faire — ce qui était l'état de deux d'entre eux entre `D2` et `I1`.

**La colonne « À cru » de la ligne *Récolter* n'a pas de cible pour `ore`.** *(Constaté à `D2`.)* La règle est écrite et la table de data la nomme, mais `data/terrain/` ne contient aucun terrain « filon » et la génération n'en pose pas — la palette de 3.1 s'arrête à la plaine, la forêt, le gisement, l'eau et le rocher. Le minerai ne s'obtient donc aujourd'hui qu'à la mine. Ce n'est pas un bug de ce jalon : c'est une ligne de 3.1 que `data/` n'a jamais reçue, et elle entrera avec le terrain, pas avec la carte.

---

## 5. Fin de run

- **Défaite** — Cœur détruit, ou roster vide
- **Victoire** — dernière vague survécue
- **Score** — ressources, bâtiments intacts, ouvriers vivants et leur niveau

*(Écrit à `I2`.)* Les trois tiennent dans un `RunOutcome` — une cause, un jour, quatre comptes et un total — et **une défaite ne s'attend pas** : elle peut tomber au jour sept, donc « le run est fini » devient vrai au milieu. C'est le cycle des jours qui porte cette vérité et lui seul ; la cause vit à côté. Deux drapeaux qui pourraient se contredire auraient été pires que le cas qu'ils couvrent.

Trois précisions que l'écriture a demandées, et aucune n'était dans la ligne ci-dessus :

- **Le Cœur se reconnaît à son ancre**, retenue quand on le pose, et non à son identifiant. C'est ce qui garde `heart` dans `data/balance/` et hors de tout `.gd`, comme depuis `I1`.
- **« Victoire » se lit « dernière journée franchie »** plutôt que « dernière vague survécue ». Les deux disent la même chose dès lors que le calendrier pose sa dernière vague sur le dernier jour — ce qu'il fait —, et la première n'a pas besoin d'inventer une règle pour un calendrier qui s'arrêterait avant la fin. Un run paisible se gagne en le survivant, ce qui reste vrai.
- **Un bâtiment intact est un bâtiment achevé.** Un chantier laissé en plan à la dernière journée ne compte pas, par la règle qui vaut depuis `C4`.

Les quatre poids du score vivent dans `data/balance/`, et un poids nul y est un choix lisible — « la thésaurisation ne rapporte rien ». Le filet est un cran plus haut, comme pour `resolves` : **au moins un des quatre doit compter**. Une défaite vaut d'ailleurs son score : un run perdu au douzième jour a duré plus longtemps qu'un run perdu au deuxième, et rien ci-dessus ne réserve le score aux vainqueurs.

**Et un run commence par la pose du Cœur**, au clic, ce que 2 annonce depuis le premier jour et que `I1` bouchonnait en le posant au centre. La main n'est tirée qu'à ce moment : une main tirée devant une carte nue serait une main qu'on ne peut pas jouer. Le balayage du centre survit comme **suggestion** — la règle automatique devient le bouton par défaut, ce que `F1` avait annoncé mot pour mot du déploiement.

**Et un run se termine sur un écran, pas sur une ligne.** *(Tranché après les premiers runs complets.)* `I2` a livré le verdict dans le pavé de texte du harnais, à côté de l'aide au clavier : une partie de quinze journées s'achevait sur une phrase qu'on pouvait manquer. Une victoire montre le score et ses quatre termes, une défaite montre sa cause et le jour où elle est tombée, et les deux offrent de **relancer**.

La place lui est gardée depuis `I2` sans qu'on l'ait dit ainsi : `EventBus` porte deux signaux distincts — l'un annonce qu'une partie est *jouée*, l'autre qu'elle est *rangée* — et le commentaire qui les sépare dit déjà « un écran de fin vit entre les deux ». Il n'y a qu'une vue à écrire.

**Relancer prend le seed suivant**, et non un seed au hasard. Un tirage libre rendrait le harnais différent à chaque lancement, donc les captures incomparables d'une session à l'autre — ce que tout ce projet refuse depuis `I0`. Le seed est affiché, ce qui garde un run rejouable quand on veut le rejouer.

---

## 6. Autour du run

### 6.1 Méta-progression *(après le MVP)*

Déblocage de cartes dans les pools de draft, gouverneurs de départ avec deck et bonus modifiés, biomes aux paramètres de génération distincts, modificateurs de difficulté cumulatifs.

### 6.2 Le menu

*(Ouvert après les premiers runs complets.)* Un écran de fin qui propose de relancer suppose qu'il existe un endroit d'où l'on lance, et cet endroit n'existe pas : le jeu **est** un run, ouvert au démarrage par un harnais de dev. Il faut donc une coquille — écran titre, lancer un run, y revenir quand il est fini — et c'est le premier morceau du projet qui vive hors d'un run.

Deux conséquences pratiques, et elles sortent toutes deux du périmètre de ce que Claude Code écrit seul. C'est une **`.tscn` sous `scenes/ui/`**, et c'est la **scène principale** de `project.godot` : les deux appartiennent à l'humain, dans l'éditeur. Et `RunManager` cesse d'avoir toujours un run — il le sait déjà, `is_running()` existe depuis `I0` et les vues le gardent, mais aucun écran n'a encore vécu dans ce trou.

C'est aussi ce qui donnera une place à 6.1 : la méta-progression n'a nulle part où s'afficher tant qu'il n'y a pas d'entre-deux-runs.

### 6.3 `OUVERT` — ce qu'on sauvegarde, et sous quelle forme

*(Rouvert après les premiers runs complets. La ligne de 7 disait « pas de sauvegarde en cours de run », et c'est cette ligne qui est en question.)*

Deux formes sont sur la table, et elles ne coûtent pas le même prix.

**Un journal de gestes** — le seed, puis la suite des gestes joués. C'est la forme que **l'architecture paie déjà** : « un seed plus une liste d'actions rejoue un run à l'identique » est promis depuis `I0` et *vérifié par un cas de test* depuis `I1`. Un fichier, aucun format par système, et un effet de bord utile — un bug rapporté devient un fichier qu'on relance. Son défaut est net et il faut le dire : **toute sauvegarde meurt au prochain changement d'équilibrage ou de règle**, puisqu'elle rejoue au lieu de restituer. Elle sert à reprendre une partie ce soir, pas dans six mois.

**Un instantané de `RunState`** — sérialiser le relief, la ville, la réserve, le roster, le deck, le plateau et le cycle. Robuste aux reprises longues, et c'est le seul avantage. Le prix est le plus gros chantier jamais ouvert sur ce projet : **chaque système du domaine gagne un format de sauvegarde et une migration à tenir**, alors que la règle de dépendance a justement été écrite pour qu'aucun d'eux n'ait à connaître le monde extérieur.

Ce qui décide n'est pas écrit ici parce que personne ne l'a encore mesuré : **combien de temps prend un run joué à la main.** Quinze journées de trois phases tiennent-elles dans une session ? Si oui, la question ne se pose pas et 7 garde sa ligne. Sinon, le journal de gestes est la réponse par défaut, et il faudra dire ce qu'on fait du save-scumming — un roguelite qui se recharge devant une vague perd l'enjeu que la vague porte.

---

## 7. Hors périmètre

- Citoyens simulés individuellement dans le monde — le roster est une liste de fiches, pas des agents qui marchent
- Routes, logistique, transport de ressources
- Ponts, tunnels, superposition verticale — le relief reste une hauteur par cellule
- ~~Sauvegarde en cours de run — seule la méta persiste~~ — **rouvert**, voir 6.3. La ligne tenait tant qu'un run était réputé court ; elle attend la seule mesure qui la tranche, la durée réelle d'une partie.
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
- **E2** ✅ — **HUD des ressources et panneau de résolution.** `ResourceBar`, `ProductionPanel` et `CommodityPalette` sous `src/adapters/hud/`, la **jauge commune segmentée** qui rend regardable la décision de `E1`, et le rang d'affichage d'une ressource entré dans `data/`. Le harnais Run y perd les deux morceaux de son pavé de texte qu'ils remplacent, plutôt que de les doubler. Un jalon d'écran a aussi trouvé un défaut de domaine que personne ne pouvait voir sans écran : la réserve annonçait l'ancien plafond pendant toute une phase après qu'un entrepôt était achevé. Un `OUVERT` refermé : les oisifs restent un compte, sans raison distinguée.

### Effectifs — `W`
- **W1** ✅ — `Worker`, `SkillTrack`, `Roster`, XP depuis les `WorkLine`, projection en `LaborForce`, tests. **Vivier unique**, et rien qui suppose le roster entier disponible *(cf. 3.9)*.
  La `CombatForce` **n'y est pas** : son contenu est décidé par le format de combat, qui est `OUVERT` en 3.6, et l'écrire ici serait ou bien un clone de `LaborForce` qui ne prouve rien, ou bien une devinette. Elle arrive à `F1`, avec le `DamageReport` et pour le même système neuf — c'est la règle « on n'invente pas une frontière que personne ne franchit », déjà appliquée à `E1`. Ce que `W1` garantit à sa place est plus solide : `Roster` est le seul propriétaire des `Worker`, et rien hors de `domain/workforce/` n'en voit un.
- **W2** ✅ — **Panneau d'affectation, fiches d'unité, auto-affectation.** `WorkerCard` et `AssignmentPanel` sous `src/adapters/workforce/`, et `StaffingAdvisor` dans `domain/run/` — le classement des ouvriers est du domaine, ce qui **corrige** une phrase de 3.4 *(voir ci-dessus)*. `ProductionResolver.family_of()` devient publique pour son second appelant, même geste que `staffing_refusal()` à `I1`. Le harnais Run perd ses deux dernières lignes de plateau et de roster, et Espace cesse de prendre le premier ouvrier libre. **Aucun DTO de `contracts/` créé ni modifié**, comme à `E2` : une vue n'est pas un second système du domaine. Le palier franchi s'annonce sur la **fiche de l'intéressé** plutôt que dans le compte rendu de récolte, ce que `E2` avait laissé en attente en toutes lettres. Deux défauts de mise en page trouvés en capture, tous deux structurels : deux panneaux qui grandissent l'un vers l'autre finissent par se recouvrir, et une liste sans borne sort de n'importe quel HUD de taille fixe.

### Cartes — `D`
- **D1** ✅ — `Deck`, `Hand`, `CardCatalogue`, `DraftPool`, les **trois pools**, défausse, remélange, draft, tests. Les cartes sont de la data : seize `.tres` dans `data/cards/`, les quatre actions MVP de 4.2 et une par bâtiment de 4.1 sauf le Cœur, qui est posé au départ. Le pool des powers existe et reste vide. La colonne **Débloque** n'y est pas entrée, voir 4.1. Le mélange est écrit à la main — `Array.shuffle()` tire sur le RNG global de Godot et non sur celui du run.
- **D2** ✅ — **Main à l'écran**, et les **deux gestes** : jouer une carte sur une cible pose une *action*, puis on y affecte des ouvriers. `PlayedAction`, `ActionPlan`, `TargetResult`, `ActionBoard`, `ActionTargeting`, le bloc `action_balance`. L'`Assignment` est rekeyée sur l'action et non sur l'ancre, et le `ProductionResolver` part enfin des actions posées, ce qui rend vraie la phrase de 2. *Récolter* et *Chasser* se résolvent à cru comme en slot ; *Construire* et *Terraformer* se posent, s'affectent et attendent `I1`, parce que leur effet mute le `CityState` et la `HeightGrid`.
  La ligne de ce jalon annonçait un geste **atomique** — une carte pour un ouvrier — et c'était une erreur de design, pas une simplification : voir 3.5.

### Combat — `F`
- **F1** ✅ — **Bouchon de combat.** `InstantCombatResolver` sous `domain/combat/`, `CombatUnit`, `CombatForce` et `DamageReport` dans `contracts/`, `WaveDef` et `CombatBalance` dans `src/schema/`, `BattleReport` dans `domain/run/`, et `RunOrchestrator.fight()` qui applique. Les colonnes **Déf.**, **PV** et **Dépl.** de 4.1 entrées dans `data/`, plus `data/waves/`. `Roster.to_combat()` et `CityState.damage()` — la troisième porte mutante de la ville, et la seule qui retire elle-même ce qu'elle tue.
  Le jalon a **ajouté une règle de design** plutôt que d'en appliquer une : le **déploiement capé** ci-dessus en 3.6, qui vient de l'humain comme le second axe de progression à `W1`. C'est lui qui fait exister au combat la tension du pitch, et il sort la caserne de sa coquille avant l'action qu'elle débloquera à `X3`.
  Il **touche trois DTO de `contracts/`** — deux neufs, plus `WorkLine` qui gagne un `NO_CELL` parce qu'on ne défend pas le village *en* une case. Et il **retire** une ligne de `CLAUDE.md` : `WaveDef` n'est pas un contrat mais une `Resource`, comme `PhaseDef`. Une blessure est sortie du `DamageReport` pour `X6`, ce qui est la troisième correction de `DESIGN.md` par un jalon après `D2` et `W2`.
  Ce qu'il ne fait pas, et c'est écrit dans son harnais : rien ne déclenche une vague. La fréquence est l'`OUVERT` de 2, la défaite est en 5, et les deux sont `I2`.
- **F2** — Prototype du vrai combat, sur snapshots fabriqués. **Le format n'est plus à définir** : tactique au tour par tour sur la grille du village, intentions ennemies complètes, deux verbes — se déplacer, attaquer. Voir 3.6, écrit en discussion après `F1`.
  Il livre un **plateau mutable** dans `domain/combat/` et des fonctions pures qui appliquent un geste à la fois, et non un résolveur : c'est là que la promesse de « l'échange en une ligne » est tombée, et 3.6 dit pourquoi. Il ne livre **ni capacités** — `X5` — **ni états** — `X6`.
- **F3** — Vue de combat intégrée, et la fin de journée qui cesse d'être atomique *(cf. 3.8)*. L'applicateur de `RunOrchestrator.fight()` ne bouge pas ; c'est le producteur qui change de nature.

### Intégration — `I`
- **I0** ✅ — Squelette : projet, arborescence, autoloads, `EventBus`, `GameDatabase`.
- **I1** ✅ — **Boucle minimale.** `PhaseDef`, `DayCycle`, `RunState`, `SiteResolver`, `RunOrchestrator`, le bloc `run_balance`, et les rapports du run — `PlayResult`, `SiteReport`, `PhaseReport`, `DayReport`, plus l'`UpkeepReport` que l'Économie a sorti du rapport de production. `RunManager` cesse d'être la coquille de `I0`. Une journée en deux phases identiques, en data, **deux sortes de résolution**, et aucun nom de phase dans le code. La **bourse au moment de bâtir** que 3.2 annonçait depuis `C1`, et l'**exécution** de *Construire* et *Terraformer* que `D2` avait laissée en attente. Trois `OUVERT` refermés : la piste que crédite un chantier *(3.2)*, le sens d'un terrassement et les terrains qu'il accepte *(3.5)*.
  Le jalon touche **deux DTO de `contracts/`**, ce qui est rare et a été décidé avant d'écrire : le sens du terrassement voyage sur l'action posée et sur le verdict de ciblage. Les trois rapports neufs, eux, restent dans `domain/run/` — aucun second système du domaine ne les franchit, ce qui est l'argument que `PickResult` et `ProgressReport` portaient déjà.
- **I2** ✅ — **Boucle complète.** Un run se fonde, se joue quinze journées, encaisse trois vagues et se termine sur un verdict. `WaveSlot` et le calendrier dans `RunBalance`, les quatre poids du score, `RunOutcome` et `DayCycle.end()`, `RunOrchestrator.found()` et `fight()` qui consomme une vague **armée**, `DayReport` qui porte la vague en attente, `BattlePanel` sous `src/adapters/hud/`. `EventBus` gagne `battle_pending` et `battle_resolved`, et `run_finished` porte l'issue plutôt que le jour.
  **Aucun DTO de `contracts/` n'a bougé**, ce qui était la promesse tenue en passant `F1` avant : tout ce que le jalon crée vit dans `domain/run/` ou dans `src/schema/`. La coupure de la fin de journée que 3.8 avait écrite d'avance a coûté ce qu'elle annonçait.
  Trois défauts trouvés **en capture**, aucun cherché par un test : le panneau de bataille nommait les morts par leur identifiant, parce qu'ils quittent le roster avant que le rapport n'arrive ; trois panneaux dans la colonne de droite débordaient de l'écran là où deux tenaient ; et le bandeau de fin passait sous ces panneaux. `--shot-evenings 0` capture désormais l'écran de fondation, qu'aucune journée jouée ne peut montrer.
- **I2b** ✅ *(les boutons ; l'arbitrage se joue)* — **Les deux questions mises en état d'être tranchées.** `DeckBalance.carry_over`, `Deck.discard_pool()`, une pioche qui **complète** au lieu de servir une main neuve, et la règle du « tour perdu » montée de `PhaseDef` à `RunBalance`. Le modèle de journée retenu est un **troisième** — deux phases qui produisent, un soir qui ne fait que fermer *(cf. 2)* —, et le modèle à deux phases reste dans `data/balance/` comme rechange, avec un cas de test qui garde toute rechange jouable.
  La ligne de ce jalon annonçait « les deux se testent en échangeant un `.tres` », et **c'était vrai à moitié** : la structure de la journée l'était depuis `I1`, le sort de la main était en dur dans `RunOrchestrator.end_phase()`. C'est la quatrième correction de ce document par un jalon après `D2`, `W2` et `F1`. `PhaseDef` refusait par-dessus le marché le seul modèle de journée qu'on voulait — une phase ne sait pas qu'elle est la dernière, donc ne peut pas savoir que fermer la journée est ce qu'elle fait.
  Il livre aussi `--chronicle`, qui rejoue le run sous les quatre croisements et rend quatre tables. Elle ne tranche rien et le dit : « est-ce une corvée » n'a pas de colonne. Ce qu'elle a servi tout de suite : montrer que le soir ne coûte **rien** en équilibrage, et que la famine tombe au sixième jour dans les quatre variantes — donc que c'est `I3` et non le modèle.
  **Ce qui reste, c'est de jouer.** Quinze journées par variante, au clavier, et l'arbitrage des deux `OUVERT`.
- **I3** — Passe de contenu et d'équilibrage, **arbitrage des `OUVERT`** restants.

### Confort — `P`

*(Ouvert après `I2`, sur une passe complète jouée à la main.)* Une famille à part, et il
faut dire pourquoi elle n'est pas simplement « de l'UI qu'on fera plus tard ».

Les jalons d'écran — `E2`, `W2`, l'écran de `I2` — ont chacun livré la vue **dont leur
système avait besoin** : la réserve pour l'Économie, l'affectation pour les Effectifs, la
bataille pour le Combat. Aucun n'avait pour charge ce qui rend une partie *agréable* à
mener bout à bout, et c'est une question qu'on ne peut poser qu'après avoir joué — donc
après `I2`, et avant que `I2b` demande à quelqu'un de jouer quinze journées d'affilée pour
arbitrer un `.tres`.

- **P1** — **La passe de confort.** Ce que la première partie complète a réclamé.

  La passe de confort s'est découpée en trois à son ouverture, et la découpe suit ce que
  chaque point **touche** plutôt que sa taille : quatre d'entre eux ne sortent pas de
  `src/adapters/`, deux demandent une vue neuve ou une place neuve, et le dernier rouvre une
  règle du domaine et une ligne de ce document. Les mélanger aurait donné un jalon dont
  aucune couche ne se serait vérifiée seule.

  - **P1a** ✅ — **Les gestes et ce qu'on lit avant d'agir.** Trois points, aucun contrat
    touché, aucune règle de domaine changée.
    - **Affecter à la souris de bout en bout.** Sélectionner une fiche puis appuyer sur une
      barre était un mélange de deux vocabulaires. C'est un clic sur la fiche puis un clic
      sur son action, sur la carte comme dans la liste ; Espace survit en raccourci.
    - **Le coût sur la carte elle-même**, un chiffre par ressource, de la couleur que la
      jauge de réserve emploie déjà, et l'encre s'affaiblit quand `Ledger.can_afford()` dit
      non. La vue ne juge pas : elle pose la question au domaine et dessine la réponse. Une
      carte d'**action** n'en porte pas, et ce n'est pas un oubli — ce qu'elle dépense, ce
      sont des ouvriers, et combien dépend de la cible, donc ce prix-là n'existe qu'en visant.
    - **Replier le panneau d'affectation**, d'un clic sur son chevron ou par `F2`. Ce point
      n'était pas dans la liste d'origine : il est venu de l'humain en cours de jalon, et il
      complète les deux crans de dégagement qui existaient déjà sans les doubler — `H` ne
      touche qu'au pavé de texte, `F1` emporte la main avec le reste et empêche donc de
      jouer. Replié, le panneau garde le compte des ouvriers, le bouton **Auto** et son
      liseré de phase : de quoi savoir s'il faut rouvrir, et de quoi ne pas avoir à le faire.
    - **Distinguer les phases autrement qu'en toutes lettres.** Un liseré sur le bord haut du
      panneau d'affectation, à la couleur de la phase courante. `PhaseDef` porte une `color`
      sur le patron exact de `TerrainData` — pas de défaut, une sentinelle, un contrôle au
      boot — et **aucun nom de phase n'est entré dans le code**, ce qui était la condition
      posée ci-dessous.

    Ce que le jalon a trouvé en regardant, et qu'aucun test ne cherchait : un coût de vingt
    se dessinait « 2 » au-dessus de « 0 », lisible et faux ; et le chemin de capture jouait
    ses cartes sans redessiner la main, si bien que **toutes les captures du projet depuis
    `D2` montraient une main d'avant leurs propres poses**, en contradiction avec le compte
    des piles deux panneaux plus loin. Rien sur une carte ne dépendait d'un état mutable
    avant ce jalon, donc personne ne pouvait le voir.

    Il a aussi buté sur un défaut qu'il ne répare pas et qui appartient à `P1b` : **le
    panneau d'affectation déborde de sa colonne** et couvre le haut des cartes posées sous
    lui — dix-huit pixels de bande au sixième jour d'un run de test, c'est-à-dire la ligne du
    rang au clavier, déjà illisible là avant `P1a`, et toujours mesurable en 1920×1080.
    C'est la troisième fois qu'une colonne de droite ne tient pas, après `W2` et `I2`, et la
    première où elle cache une information plutôt que d'en tronquer une. Le repli lui donne
    une **échappatoire** — un clic rend les cartes entières — mais pas une réparation : un
    panneau ouvert déborde toujours, et c'est `P1b` qui devra le loger. *(Fait, et la
    mesure de dix-huit pixels était juste sur le jour six et optimiste sur la suite : au
    douzième jour, où une cinquième ligne d'action s'ajoute, le recouvrement montait à
    vingt-huit.)*

    `--shot-phases` est né du même jalon, et de la phrase que ce projet s'applique depuis
    `I2` : un écran qu'aucune capture ne peut atteindre est celui que personne ne regardera.
    `--shot-evenings` résout des journées entières, donc toute capture s'arrêtait sur le
    premier créneau ; les autres phases étaient inatteignables, ce qui n'a gêné personne tant
    qu'une phase ressemblait à sa voisine. `--shot-fold` est venu par la même porte, et le
    repli en est le cas le plus net : c'est un état qu'aucune suite de journées ne produit,
    puisqu'il ne s'obtient que par un geste.

  - **P1b** ✅ — **Les listes qui cessent de mentir sur ce qu'elles cachent.** Quatre points,
    le quatrième venu de l'humain en cours de jalon comme le repli à `P1a`.
    - **Loger le panneau d'affectation**, ce que `P1a` lui avait laissé. Le harnais tient le
      budget de hauteur de la colonne et le passe au panneau ; le panneau sert les fiches
      d'abord et donne le reste à la liste, qui défile. Le partage vient de l'humain :
      **les fiches sont prioritaires**, une action se relit de toute façon sur la carte.
    - **La liste des actions posées, pour de bon.** `MAX_ROWS` disparaît, et le remplaçant
      n'est pas un chiffre mieux choisi mais un **changement d'instrument**. La mesure qui le
      dit : à quatre lignes le panneau s'arrêtait 16 px au-dessus des cartes, à cinq il
      descendait 28 px dessous. Le plafond avait été calibré à `I2`, sur « ce qu'une main
      peut poser en une phase », et il était faux d'exactement une ligne — un plafond
      calibré sur une hauteur qu'il ne mesure pas se trompe dès qu'autre chose bouge.
    - **Voir les piles.** `PileView`, modale, une section par pool et deux colonnes.
      `Deck.draw_census()` et `discard_census()` répondent par un **recensement** — carte vers
      nombre d'exemplaires — et non par une liste : voir 3.5, où ce refus a une conséquence
      de design. `P` l'ouvre dans les harnais Run et Cartes ; le pavé de texte perd ses trois
      lignes de compteurs plutôt que de les doubler.
    - **La fiche d'ouvrier passe à quatre lignes**, et ce point n'était pas dans la liste
      d'origine. Les pistes qui ont franchi un palier tiennent sur une ligne ; les
      multiplicateurs, les pistes sans palier et l'XP totale passent à l'infobulle. Ce qui
      **décide** reste à l'écran, ce qui s'en déduit s'obtient au survol. Une passe unique
      remplit les deux formes, faute de quoi c'est l'infobulle — qu'aucune capture ne montre
      — qui aurait dérivé en silence.

    Le jalon **ne touche aucun DTO de `contracts/`**, le quatrième d'affilée après `E2`,
    `W2` et `P1a`. Il ajoute deux accesseurs au `Deck`, et rien d'autre au domaine.

    Ce qu'il a trouvé en mesurant, et que trois jalons d'écran n'avaient pas vu : **un
    conteneur qui borne grandit avec ce qu'il borne.** Le budget était tiré de la taille du
    `MarginContainer` qui porte la colonne, et un `MarginContainer` prend le plus grand de
    son ancrage et du minimum de son contenu — donc il se desserrait exactement quand il
    aurait dû serrer. Vingt-huit pixels sont passés par là. Il **demande** désormais à la
    main où elle commence, ce que `P1a` avait déjà fait pour la hauteur de la bande.

    Et la capture du harnais Run annonce désormais la mise en page en toutes lettres : où
    finit la colonne, où commence la main, lequel mord sur l'autre. C'est la discipline de
    `F1` — une table dit ce qu'elle doit montrer — appliquée à une image. Elle a servi tout
    de suite, et pas pour la raison attendue : c'est elle qui a montré que le budget était
    trop généreux de vingt-huit pixels, après une heure passée à sonder des PNG pour un
    chiffre qui, lui, était dans le mauvais repère — une capture est en pixels de fenêtre,
    la mise en page en pixels logiques, et le facteur vaut 1,667 en 1920×1080.
  - **P1c** — **Désigner l'une des deux actions d'une même case**, ce qui lèverait la
    contrainte provisoire de 3.5. Seul point de la famille qui touche le domaine, et le seul
    qui renverse une décision : il ne se traite qu'une fois choisi *comment* on désigne —
    un cycle au clic, un menu, ou une pile visible sur la case. La question précède le code.

- **P2** — **Ce que plusieurs runs entiers ont réclamé.** Seconde passe de confort, ouverte
  après `I2b` et sur le même argument que la première : le contenu vient d'une partie jouée,
  pas d'une déduction. Découpée par ce que chaque point **touche**, comme `P1`.

  - **P2a** ✅ — **Le geste qu'on répète, et l'écran qu'on ne voyait pas.** Aucun domaine,
    aucun contrat — le sixième jalon d'affilée après `E2`, `W2`, `P1a`, `P1b` et `I2b`.
    - **Un bouton de fin de phase**, qui dit ce qu'il va faire : fonder, finir la phase,
      fermer la journée, ou tenir la ligne. `Entrée` fait déjà ces quatre choses selon l'état
      du run et le harnais calcule déjà laquelle — le bouton n'est que cette dispatch rendue
      visible, et il pose la question au domaine plutôt que de nommer une phase. Il vit
      **dans la rangée de la main** et non dans la colonne de droite, qui a débordé trois
      fois — `W2`, `I2`, `P1a` — et à qui l'on ne confie pas le geste le plus fréquent du jeu.
    - **Un écran de fin de run** *(cf. 5)*, victoire ou défaite, avec le score et ses quatre
      termes, et de quoi relancer sur le seed suivant.

    Le pavé de texte perd la cause et le détail du score plutôt que de les doubler,
    quatrième fois après `E2`, `W2` et `P1b`. `--shot-restart` naît de la porte habituelle :
    relancer ne s'obtient que par un clic sur un écran de fin, donc `_restart()` aurait été
    le seul chemin du harnais qui reconstruise un run entier sans qu'aucune passe
    automatique ne l'emprunte.

    Deux défauts trouvés en regardant, et tous deux **antérieurs au jalon**. « Main vide »
    se dessinait une lettre par ligne sur l'écran de fondation depuis `I2` — un `Label` qui
    s'enroule, seul dans un conteneur qui distribue, reçoit la largeur minuscule qu'il
    déclare —, c'est-à-dire sur le seul texte de la seule image que `--shot-evenings 0`
    existe pour montrer. Et le panneau d'affectation annonçait « cette phase ferme la
    journée » à un run terminé, qui n'en a plus aucune.
  - **P2b** — **Le bilan de journée** *(cf. 2)*. Le seul point de la famille qui touche le
    domaine : quelqu'un doit se souvenir de la journée, et ce quelqu'un n'existe pas. Il
    répare du même coup les deux horloges qui se contredisaient — un compte rendu de phase
    titré d'une phase passée, sous un bandeau titré de la phase courante.

### Autour du run — `M`

*(Ouvert après les premiers runs complets. C'est la première famille qui vive **hors** d'un
run, ce qui est exactement pourquoi elle est à part.)*

- **M1** — **Le menu** *(cf. 6.2)*. Écran titre, lancer un run, y revenir quand il est fini.
  Il ne se livre pas comme les autres : c'est une `.tscn` sous `scenes/ui/` et la scène
  principale de `project.godot`, donc **deux fichiers que l'humain seul écrit**. Claude Code
  décrit l'arbre et s'arrête. `P2a` le précède parce qu'un écran de fin qui propose de
  relancer est ce qui rend le menu nécessaire, et non l'inverse.
- **M2** — **La persistance**, dont la forme est l'`OUVERT` de 6.3 et ne se tranche pas avant
  qu'on ait mesuré la durée d'un run joué. Elle rouvre une ligne de 7, ce qui en fait le
  premier jalon du projet à contredire le hors-périmètre plutôt qu'à le contourner.

  **Le sens d'un terrassement n'est dans aucun des trois**, et c'est une décision et non un
  oubli. Il était au périmètre de `P1a`, l'humain l'en a retiré, puis l'a retiré de `P1b`
  aussi : il dira quand le remettre. Le verbe, sa résolution et son ciblage restent écrits
  et exercés ; ce qui attend est l'écran qui montrerait où va la terre, donc le retour de la
  carte au deck de départ *(cf. 4.2)*. La promesse tient, elle n'a simplement pas de date.

  Deux gestes de la liste d'origine étaient **déjà faits** avant l'ouverture de la
  famille : le clic droit sur une fiche rappelle son ouvrier, et la ligne de survol a
  quitté le rapport pliable pour rester visible pendant qu'on vise. Ils l'ont été parce
  qu'ils coûtaient une heure et que `I2b` se joue avec.

### Différés — `X`

Écrits après `I2`, jamais avant. Ils ne contraignent que l'abstraction, pas le calendrier.

- **X1** — Expéditions *(3.9)*.
- **X2** — Artisanat : atelier et *Fabriquer* *(3.3)*.
- **X3** — Entraînement : caserne et *S'entraîner* *(3.4)*.
- **X4** — Powers : le troisième pool se remplit *(3.5)*.
- **X5** — Ce qu'un palier de **niveau d'ouvrier** offre : le choix de compétence *(3.4)*. `W1` écrit l'accumulateur et les paliers, qui se gagnent et se lisent ; ce qu'ils débloquent est du contenu et de l'UI, et se décide devant un roster qui a vraiment vécu quinze jours.
  *(Précisé après `F1`.)* La réponse a désormais une forme : **une capacité de combat est ce qu'un palier de piste Combat débloque** *(cf. 3.6)*. C'est ce qui a permis à `F2` de n'avoir que deux verbes sans que le combat soit plat à terme, et ce qui enracine ces capacités dans le roster nominatif plutôt que dans un catalogue hors-sol. Le jalon cesse d'être une question ouverte pour devenir du contenu à écrire.
- **X6** — **États d'ouvrier** : la faim, la blessure, et ce qui viendra ensuite *(3.3, 3.4, 3.6)*.
  Trois systèmes ont buté sur le même manque et l'ont chacun contourné à leur façon : `E1` a laissé la famine « se constater sans se punir », `F1` a sorti la blessure du `DamageReport`, et l'`OUVERT` de 3.3 listait quatre issues dont trois décrivent le même objet. Un `Worker` porte aujourd'hui une présence et de l'XP, rien qui dure et qui pèse.
  Ce jalon est ici et non plus haut pour une raison de méthode et non de calendrier : un système d'états se conçoit **devant la liste de ceux qui existent vraiment**, et cette liste n'est complète qu'une fois la boucle jouable — la faim vient de l'upkeep, la blessure du combat, et le reste des événements de 3.7, qui ne sont pas écrits. En trancher un seul aujourd'hui, dans le rapport du système qui le rencontre, produirait trois mécaniques qui ne se parlent pas et qu'il faudrait défaire.
  Ce qu'il contraint en attendant, et c'est sa seule raison d'être écrit maintenant : **aucun rapport ne doit inventer sa propre conséquence.** Un système qui rencontre un état le **compte** et le rapporte ; il ne décide pas de ce qu'il fait. C'est ce que `UpkeepReport` fait déjà des non-nourris, et ce que `DamageReport` fait des pertes.
  *(Relevé après `F1`.)* Le format de combat de 3.6 le fait passer de confortable à **structurant**, et lui donne sa première forme concrète : les points de vie sont la ressource d'une manche, un ouvrier à zéro meurt, et ce qu'un **survivant** emporte est un effet progressif selon la part de vie perdue. Sans lui, un combat n'a que deux issues — rien, ou définitif —, et le joueur qui a bien joué ne sent rien du tout. C'est le premier état dont on connaisse déjà et la source et la graduation.

**Ordre suivant** — **`P2b`**, le bilan de journée, seul point de `P2` qui reste. Plusieurs runs entiers ont été joués après `I2b`, et ils ont rendu une liste : elle est ci-dessus, et elle se périme comme celle de `P1` si on attend. Puis **`I3`**, avec la nourriture en tête et son premier chiffre.

`M1` suit de près, parce que l'écran de fin de `P2a` propose désormais de relancer, ce qui désigne un endroit d'où l'on lance. `M2` attend une mesure et non du temps. Et il reste toujours **`P1c`**, qui attend une **question de design** : comment désigner l'une des deux actions d'une case.

**L'arbitrage de `I2b` reste ouvert** et ne se referme qu'en jouant. `P2` ne le remplace pas — il rend les quinze journées moins pénibles à mener, ce qui est exactement le service que `P1` a rendu avant lui.

*(Écrit avant `P1a`, et toujours vrai du reste de la famille.)* **`P1` peut s'intercaler à tout moment** : c'est le seul jalon dont le contenu vient d'une partie jouée plutôt que d'une déduction, donc le seul qui se périme si on attend. La boucle est jouable du début à la fin, donc la question n'est plus « qu'est-ce qui manque » mais « est-ce que ça se joue ».

*(Corrigé à `I2b`.)* Ce paragraphe se terminait par « les deux arbitrages se testent en échangeant un `.tres`, et c'est la première fois du projet qu'un jalon ne demande pas d'écrire une ligne de GDScript ». **C'était vrai à moitié, et c'est la moitié fausse qui a fait le jalon.** La structure de la journée était bien en data depuis `I1` — `PhaseDef` et `RunBalance` ont tenu leur promesse mot pour mot. Le sort de la main, lui, était une ligne en dur dans `RunOrchestrator.end_phase()`, et aucun champ ne le réglait : le `Deck` avait été écrit pour accueillir la réponse — `discard_hand()` se dit « une capacité, pas une politique » — mais personne n'avait posé le bouton.

La leçon n'est pas qu'on s'était trompé, c'est **où** on s'était trompé : la promesse portait sur deux questions, une seule avait été instrumentée, et rien ne distinguait les deux tant qu'on ne cherchait pas à tourner le bouton. Un jalon annoncé « sans code » mérite qu'on vérifie, avant de le planifier, que chacune de ses questions a vraiment sa prise.

`I3` suit avec les chiffres, et il en a désormais une liste précise plutôt qu'une intention : **la nourriture d'abord**, qui est le déséquilibre le plus visible d'un run entier — la famine tombe dès la cinquième journée et ne s'arrête plus —, puis le calendrier des vagues, le barème du score, et le `breach_per_casualty` que `F1` avait déjà signalé comme le plus fragile de ses cinq.

*(Chiffré à `I2b`.)* La chronique donne l'ampleur, et elle est plus grande qu'« un peu juste » : sur quinze journées, un run scripté récolte **27 nourritures pour 85 dues**. Le village mange donc un jour sur trois, et la première famine tombe au sixième jour dans **les quatre variantes** — donc ni le modèle de journée ni le report de main n'y sont pour quelque chose. C'est un chiffre d'équilibrage et rien d'autre.

*(Écrit à `F1`.)* Ce qui reste à câbler tient en trois fils, et chacun a déjà sa prise. La vague entre dans `close_the_day()`, où `I1` lui a gardé sa place et où `DayReport` l'accueillera par un champ. Le calendrier des vagues est un bloc de `data/balance/` qui n'existe pas encore, exprès — un champ que personne ne lit serait la frontière que ce document refuse depuis `E1`. Et la défaite lit ce que la ville et le roster disent déjà.

*(Constaté à `E2`, confirmé à `W2`.)* Ce que les jalons d'écran apprennent : **un écran trouve des défauts qu'aucun test ne cherche**. Les tests avaient raison sur chaque chiffre pris isolément ; c'est la juxtaposition d'un entrepôt visiblement fini et d'une jauge inchangée qui a montré un mensonge d'une phase. Les pièges de mise en page, eux, ne se voient qu'en capture — un panneau à taille nulle ne dessine pas son fond, une taille minimale se lit en retard d'une passe, et deux panneaux qui grandissent l'un vers l'autre se recouvrent à la phase la plus chargée, donc le plus tard possible.

*(Historique.)* `E1b` est passé avant `W1` parce qu'il touchait les `.tres` de bâtiments et que leur nombre a doublé ; `W1` a suivi parce qu'il était le dernier moment où `LaborForce` pouvait bouger sans douleur — elle n'a finalement pas bougé — et parce qu'il est le seul jalon qui rende le journal de travail de `E1` utile à quelque chose. `C4` est venu ensuite parce qu'il rouvrait ces mêmes `.tres` une dernière fois avant que les cartes n'arrivent, et parce que `D2` a besoin d'une cible pour *Construire* : sans chantier, cette carte n'aurait rien à avancer. `D1` a suivi sans surprise, étant le seul jalon qui ne dépende de rien — le `Deck` ne connaît ni la grille, ni la bourse, ni le roster.

Le jeu devient jouable à `I2`. Tout ce qui suit est de l'enrichissement.
