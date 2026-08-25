# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

---

## 2026-08-25 — `D1` : trois pools, un mélange qui ne triche pas, et ce qu'un draft coûte

**État : terminé.** Cinq commits sur `feat/d1-deck`, tirée de `master` — la chaîne
empilée de trois jalons s'arrête ici, `C4` ayant été fusionné entre-temps. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **396 tests
verts contre 324** à l'ouverture.

La branche a de nouveau été créée **à l'orientation**, avant la première ligne. Quatre
jalons d'affilée.

### Ce qui a été livré

- `CardData` et `DeckBalance` ; **seize `.tres`** dans `data/cards/` — les quatre
  actions MVP de `DESIGN.md` 4.2 et une carte par bâtiment de 4.1 sauf le Cœur ; le
  sixième bloc de `BalanceData`.
- `CardCatalogue`, `CardShuffle`, `Deck`, `Hand`, `DraftPool`.
- **Sept suites, 72 cas neufs.**
- `GameDatabase` — `get_card()`, `list_card_ids()`, et deux contrôles de boot de plus.
- `deck_harness.gd`, cinquième harnais, troisième en rapport texte.
- `DESIGN.md` 3.5, 4.1, 4.2 et 8 ; `README.md`.

### Deux arbitrages avant d'écrire

**La colonne « Débloque » de 4.1 est reportée**, alors que ce même tableau l'annonçait
pour `D1`. Les trois actions qu'elle concerne — *S'entraîner*, *Fabriquer*, *Explorer* —
portent `MVP : non` en 4.2, et leurs systèmes sont `X1`, `X2`, `X3`. En les laissant hors
du catalogue, il **n'y a rien à débloquer** : le champ n'aurait aucun lecteur et la
requête « qu'est-ce qui est débloqué ? » serait une frontière que personne ne franchit —
le motif exact qui a sorti `CombatForce` de `W1`. Le prix du report a été chiffré avant
de le prendre : un champ sur `BuildingData`, trois `.tres` à rouvrir, une quatrième
lecture de `CitySnapshot.completed()`. C'est peu, et `C4` a déjà laissé la porte ouverte.

**Le pool est un `StringName` et non un `enum`**, contre la convention générale du
projet — « `enum` plutôt que `String` pour les états ». Deux raisons se cumulent et
l'emportent. Un `enum` non renseigné vaut 0, donc `&"action"` **en silence** : la
doctrine du zéro perdrait sa prise sur le seul champ qui décide de tout le classement
d'une carte, alors qu'un `&""` se détecte. Et un pool n'est pas un état en mémoire, c'est
un identifiant écrit dans `data/`, où la convention est déjà le `StringName` — `&"wood"`,
`&"harvest"`. L'ensemble reste fermé : `CardData.POOLS` le tient, et `missing_fields()`
refuse tout ce qui n'y est pas.

### La décision qui porte le jalon : le Deck ne décide de rien

Il refuse deux choses, et ces deux refus sont le jalon.

**Il ne juge aucune jouabilité.** `DESIGN.md` 3.5 dit qu'un jeu de carte est une
*intention* que le système concerné accepte ou refuse. Le Deck ne connaît ni la grille,
ni la bourse, ni le placement, et jouer une carte, vu d'ici, c'est l'appelant qui la
défausse une fois la réponse obtenue. Il n'y a donc pas de verbe `play()` : `discard()`
suffit, et il ne ment pas.

**Il ne décide d'aucun moment.** Les trois tailles de main vivent dans `data/balance/`,
et *quand* on pioche appartient à la journée, donc à `I1`. `discard_hand()` est une
**capacité et non une politique** : rien dans le domaine ne dit qu'une phase se termine
ainsi.

Ce second refus est ce qui laisse entier l'`OUVERT` de 3.5 — le sort de la main non
jouée. Un `Deck` qui aurait pris l'habitude de défausser tout seul en fin de phase aurait
tranché la question sans que personne ne le décide, et la trancher dans du GDScript
l'aurait rendue coûteuse à retester. Là, les deux réponses candidates s'essaieront en
échangeant un `.tres`, ce qui est précisément la promesse de `data/balance/`.

### Ce que le harnais a trouvé, et ce qu'il a fallu jeter

Le harnais a produit un chiffre juste, un chiffre faux, et un chiffre inutile. Les trois
méritent d'être consignés, parce que le tri entre les deux derniers est tout le travail.

**Le chiffre faux.** La première version mesurait le cycle de la pioche en divisant les
phases jouées par le nombre de remélanges, et sortait 2,7 phases là où le régime établi
est 2. Les premières phases d'un run vident une pioche pleine sans jamais la recycler :
les compter allonge le cycle d'un tiers. Un chiffre qui dépend de l'endroit où l'on
commence à compter ne mesure rien. Corrigé en comptant l'écart entre deux remélanges
successifs, ce qui donne 2,0.

**Le chiffre inutile.** Une fois juste, il s'est révélé **muet** : il vaut deux phases
que le pool d'actions en tienne dix ou quatorze, parce qu'une pioche qu'on vient de
recharger garde toujours de quoi faire exactement une main de plus. Il dit quelque chose
de vrai sur les piles et rien sur le jeu. Remplacé par la question que le design pose
vraiment : au bout de combien de phases une main **revoit** la carte qu'on attend. Le
remélange, lui, n'a pas disparu du rapport — il a sa colonne dans la table, où il se voit
au lieu de se moyenner.

**Le chiffre juste, et il répond à une question de design.** Sur deux cents seeds,
7,8 % des phases n'offrent aucune carte *Construire* — la tension que `DESIGN.md` 3.2
annonce quand il dit qu'un chantier qui attend est une vraie situation. Et surtout :
après quatre drafts d'action pris au hasard dans l'offre, ce chiffre monte à **11,2 %**
et le délai de retour de 1,07 à 1,11 phase. **Grossir son deck le rend moins fiable.**
C'est le classique du deckbuilder, mais il est ici mesuré sur les chiffres réels de
`data/` et non supposé, et il dit quelque chose que `I3` devra équilibrer : si drafter
est une récompense, il faudra que ce qu'on gagne compense ce que la dilution coûte.

Cinquième jalon d'affilée où le harnais dit quelque chose qu'aucune des trois commandes
ne pouvait dire — et le premier où c'est un **échantillon** qui parle, pas un run. Une
fréquence lue sur un seul seed n'aurait rien valu.

### Ce que la commande 2 a rattrapé, et que la commande 1 n'a pas vu

`CardShuffle` ne compilait pas — `var held := mixed[index]` sur un `Array` typé ne
s'infère pas. Le boot est passé **sans un mot** : rien à ce moment-là ne chargeait le
fichier, et son code de sortie valait 0. C'est exactement le piège que `CLAUDE.md`
documente en disant que la commande 1 ne dit rien de la santé du projet, et la première
fois qu'il se manifeste pour de vrai. Trois commandes, pas une.

### Décisions

**`CardShuffle` a son propre fichier, pour une seule fonction.** `Array.shuffle()` tire
sur le RNG global de Godot et non sur celui du run : un deck mélangé par lui rendrait un
même seed non rejouable, sans rien signaler. Le piège devait être évité à deux endroits —
la pioche et l'offre de draft —, et une règle qu'on recopie est une règle qu'on oublie à
la troisième occurrence. Un cas de test le garde en reseedant le générateur global entre
deux mélanges et en exigeant le même ordre : c'est le seul cas qu'un `Array.shuffle()`
échouerait, donc le seul qui protège vraiment.

**Le RNG est un argument, jamais un membre.** Le Deck ne possède pas de flux d'aléatoire,
il consomme celui du run. Un Deck qui garderait le sien serait un second flux à seeder,
donc un second endroit où un run cesserait d'être rejouable. C'est le choix inverse de
`TerrainGen`, qui prend un seed et le sale — et la différence se justifie : une
génération est un tirage isolé qu'on ne veut pas corréler, une pioche est un événement du
run comme un autre.

**`create()` ne mélange pas.** Composer un deck reste sans aléatoire, donc assertable
sans rng, et `shuffle(pool, rng)` est un geste public que l'ouverture d'un run fait sur
les trois pools. Le risque assumé est qu'on l'oublie ; il est documenté, et il n'y aura
qu'un seul appelant à `I1`.

**Une carte draftée entre par la défausse.** Elle ne doit pas s'intercaler dans une
pioche déjà entamée, ce qui la ferait passer devant des cartes qui attendaient leur tour
depuis deux phases. Entre deux runs la question ne se pose pas, tout est recomposé.

**`remove()` cherche dans un ordre fixé** — pioche, puis défausse, puis main. L'ordre est
arbitraire, mais un retrait qui dépendrait de l'endroit où la carte se trouve ferait
diverger deux runs partis du même seed.

**Les tailles de main sont une table et non trois champs plats.** C'est ce qui rend le
zéro du pool des powers écrivable *et* un pool oublié détectable : la présence de la clé
vaut déclaration. Trois champs plats auraient rendu les deux situations indiscernables —
même geste que le bloc nullable de `E1b`, appliqué à un dictionnaire.

**`list_card_ids()` trie, et ça compte plus ici qu'ailleurs.** C'est dans cet ordre que
le `CardCatalogue` reçoit les cartes, et c'est cet ordre que les offres de draft
mélangent : un catalogue chargé dans l'ordre d'un `DirAccess` tirerait différemment d'une
machine à l'autre sur le même seed.

**Une carte de bâtiment nomme son bâtiment**, même quand c'est le même mot. Rien
n'oblige une carte à porter le nom de ce qu'elle pose, et deux cartes qui poseraient la
même ferme à des conditions différentes sont exactement ce qu'un draft de
méta-progression fera. `missing_fields()` réclame le lien **dans les deux sens** : une
carte de bâtiment sans bâtiment n'aurait rien à poser, une carte d'action qui en nommerait
un ferait croire à un lien que rien ne suivra.

### Ce qui reste

Rien pour `D1`. Cinq choses volontairement laissées de côté :

- **jouer une carte, et la jouabilité** — `D2`. Le Deck rend une intention ; qui
  l'accepte n'existe pas encore.
- **les trois actions non-MVP et la colonne « Débloque »** — `X1`, `X2`, `X3`, argumenté
  plus haut.
- **le pool des powers** — il existe, il est vide, il se pioche sans rien rendre. `X4`.
- **le moment de piocher et de défausser** — `I1`, et c'est ce qui garde l'`OUVERT` de
  3.5 ouvert.
- **la récompense alternative d'un draft** — choix d'écran, il viendra avec l'écran.

Et un constat de design neuf, à porter à `D2` — le seul de la session, et il est venu de
la conversation et non du code. La ligne de 8 dit aujourd'hui que jouer une carte produit
un `Assignment` — ouvrier → (action, cible) —, donc un geste **atomique**. Le flux
réellement voulu en compte deux : on joue la carte **sur une cible**, ce qui crée une
*action posée*, puis on y affecte **des** ouvriers. La différence n'est pas ergonomique.
Si une carte valait un ouvrier, cartes et ouvriers se **doubleraient** — chaque action en
consommant une de chaque, la contrainte réelle deviendrait `min(cartes, ouvriers)` — et
c'est exactement ce que 3.4 refuse en disant « deux contraintes qui se croisent, et non
deux ressources qui se doublent ». Il manque donc un objet de domaine entre la carte et
l'ouvrier. `Assignment` ne changerait presque pas de forme — il associe déjà
`ouvrier → clé`, et la clé cesserait de désigner un bâtiment pour désigner une action
posée —, mais une question resterait franchement ouverte : **si deux actions posées
visent la même cellule**, l'ancre `Vector2i` ne suffit plus comme clé. Rien n'a été écrit
ni dans `DESIGN.md` ni dans le code : la question se tranchera à `D2`, avec la main à
l'écran sous les yeux, et c'est le choix explicite de la session.

Les reports de `W1` et `C4` tiennent tous : la troncature du rendement à `I3`, la trame
d'ombre sur le dessus des boîtes qui est du travail Terrain, et la mise en commun des
rapports texte des harnais — toujours sans jalon attitré, `_make_label()` en est
maintenant à **six** exemplaires.

### Prochain jalon

**`D2`** — la main à l'écran, et la question ci-dessus tranchée : ce qu'une carte jouée
crée, et à quoi un ouvrier s'affecte. `I1` ensuite.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée — le harnais Cartes ne lit pas le clavier.

- `F5` lance le **harnais Cartes** : `HARNESS` vaut `&"deck"` dans
  `scenes/dev/dev_boot.gd`. Il n'affiche rien en 3D — un rapport texte, également
  imprimé sur la sortie standard, donc `godot --headless --quit --path .` suffit à le
  lire. `&"city"`, `&"economy"`, `&"workforce"` et `&"terrain"` restent à un mot près.
- **les chiffres du deck de départ sont à relire.** Dix cartes d'action — 4 *Récolter*,
  3 *Construire*, 2 *Chasser*, 1 *Terraformer* — et six de bâtiment, mains de 5 et 2,
  draft à 3 choix. Ce sont des hypothèses au même titre que les coûts de 4.1, et ce sont
  elles que le verdict du harnais mesure : les changer change les deux pourcentages.
- **dix-sept `.tres` neufs**, sans `uid://` — comme les treize bâtiments écrits à la main
  avant eux. L'éditeur leur en ajoutera un la première fois qu'il les réenregistrera ;
  c'est un diff à attendre, pas un problème. Les caches de classes et d'uid ont été
  reconstruits pendant la session, et les `.gd.uid` des quinze scripts neufs — huit de
  code, sept de tests — sont commités.

---

## 2026-08-25 — `C4` : le chantier, ses deux lectures, et un contrôle par l'image

**État : terminé.** Cinq commits sur `feat/c4-construction-sites`, tirée de
`feat/w1-workforce` — `master` n'a toujours pas reçu `W1`, la chaîne empilée continue.
Les trois commandes passent : boot sans erreur ni warning, tout `src/domain/` parse,
**324 tests verts contre 304** à l'ouverture.

La branche a de nouveau été créée **à l'orientation**, avant la première ligne. Trois
jalons d'affilée.

### Ce qui a été livré

- `BuildingData.build_actions`, et la colonne **Chantier** de `DESIGN.md` 4.1 écrite
  dans les treize `.tres`.
- `BuildingSnapshot` — `progress()`, `is_complete()`, `remaining()` ; `CitySnapshot` —
  `completed()` à côté de `buildings()`.
- `PlacedBuilding` — l'avancement et `advance()` ; `CityState.advance(anchor)`.
- `ProductionResolver` et `Roster.capacity_for()` — les trois endroits qui devaient
  cesser de compter un inachevé.
- `tests/` — quatorze cas neufs répartis sur quatre suites.
- `BuildingRenderer` — le rendu distinct ; `city_harness.gd` — `Espace`, l'état sous le
  curseur, l'étalement des avancements.
- `DESIGN.md` 3.2, 4.1 et 8.

### Deux arbitrages avant d'écrire

**Le « — » du Cœur est un zéro**, et non un champ réclamé au boot. L'argument qui a
tranché n'est pas le confort mais la **cohérence de ligne** : ce même Cœur porte déjà
« posé au départ » dans la colonne Coût, et `data/` le représente par un coût vide que
le schéma accepte sans broncher. Représenter « — » par un zéro est le même geste sur la
même ligne du tableau. Le bénéfice se voit à ce qui n'a pas été écrit : `is_complete()`
étant `progress >= build_actions`, le Cœur est achevé à la pose et **aucun chemin
particulier n'existe** pour lui — ni dans `place()`, ni dans le harnais, ni demain dans
`RunOrchestrator`.

Le prix est réel et a été payé, pas ignoré : un `build_actions` oublié vaut 0 et fait
sauter le chantier en silence. Un cas de test charge tout `data/` et exige qu'au moins un
bâtiment en déclare un — le filet que `production_block_test.gd` tend déjà sous les blocs
de production, et qui rattrape la disparition du **format entier** sinon rien. C'est un
filet à mailles larges, et c'est dit comme tel.

**Les harnais Économie et Effectifs achèvent à la pose.** Sans intervention ils
devenaient muets : leurs bâtiments seraient restés des chantiers pour toujours, faute de
carte *Construire* à leur jeter dessus. Chez l'Économie ça vidait le rapport ; chez les
Effectifs ça cascadait — pas de poste, pas de ligne de travail, pas d'XP, deux tableaux
et un verdict à zéro.

L'alternative — un cran par soir — est la version **intéressante**, et elle répondrait à
une vraie question : ce que le délai de chantier coûte à l'économie. Elle a été écartée
pour une raison de méthode et non de goût : les chiffres d'un harnais sont des **repères
écrits au journal**, et déplacer ceux de `E1b` et `W1` depuis un jalon dont le sujet est
la Construction aurait rendu la prochaine dérive inattribuable. Vérifié après coup plutôt
que supposé — la famine tombe toujours au soir 6, la mine se paie toujours au soir 8, la
réserve finit toujours à 189/200 ; côté Effectifs, la nourriture bouge toujours au soir
20 et Elric revient toujours avec 24 postes et 96 XP. Aucun repère n'a bougé.

Elle a un meilleur moment, et il est nommé : **`I1`**, où l'orchestrateur séquence une
vraie journée et où le délai est *joué* au lieu d'être simulé par un harnais qui ferait
semblant d'avoir des cartes.

### La décision qui porte le jalon : deux lectures plutôt qu'un filtre recopié

Trois consommateurs devaient cesser de compter un bâtiment inachevé — les postes de
production, la réserve que les entrepôts relèvent, les places que les habitations
ajoutent. Et un quatrième, le Combat, doit au contraire les **voir** : `DESIGN.md` 3.2
veut qu'un chantier détruit la veille de la vague soit une vraie perte.

Trois clauses `if not is_complete()` recopiées auraient marché, et auraient été oubliées
à la quatrième. Le pire est que **l'oubli aurait été silencieux** : un entrepôt en
chantier qui relève quand même la réserve ne casse rien, il ment — et un mensonge de ce
genre ne se découvre qu'en équilibrage, six jalons plus loin.

`CitySnapshot` porte donc `completed()` à côté de `buildings()`. Une implémentation, du
côté du DTO qui sait déjà tout ce qu'il faut pour répondre, et deux questions qui ont
chacune leur consommateur — ce qui est précisément la condition que le projet s'impose
avant d'ouvrir une porte.

### Ce que la capture a trouvé, et ce qu'elle a innocenté

Cinquième jalon d'affilée où l'image dit quelque chose qu'aucune des trois commandes ne
pouvait dire. Deux fois, et les deux comptent.

**Un bug à moi.** Le premier étalement donnait à chaque bâtiment un nombre de crans égal
à son rang dans le catalogue, calqué sur ce que `C2` fait des orientations. Sauf que les
orientations bouclent à 4 et que les chantiers de `DESIGN.md` 4.1 plafonnent à **3** :
tout ce qui vient après le quatrième rang était achevé d'office, et la ville d'ouverture
ne montrait que **2 chantiers sur 13**. Corrigé en prenant les crans modulo ce que chaque
bâtiment réclame — 9 chantiers sur 13, et toute la gamme sous une seule capture. Aucun
test n'aurait signalé ça : le code était correct, c'est la mise en scène qui ne montrait
rien.

**Un bug qui n'est pas à moi.** La même capture montre une **trame en damier** sur le
dessus des boîtes, là où l'ombre d'un bâtiment haut tombe sur un bâtiment bas. La
tentation était de l'attribuer aux boîtes minces que `C4` introduit. Contrôle fait plutôt
que supposé : une capture avec `SITE_BASE_RATIO` forcé à `1.0` — donc au rendu exact de
`C2`, toutes les boîtes à pleine hauteur — **montre exactement la même trame**. C'est un
défaut de filtrage d'ombre de la lumière de `DevWorld`, que `C4` a seulement rendu plus
visible en posant des boîtes basses à côté d'une tour. Consigné, pas corrigé : c'est du
travail Terrain, et `CLAUDE.md` interdit depuis `C2` de « réparer » un problème qu'on n'a
pas d'abord constaté chez soi.

Le stratagème du contrôle mérite d'être retenu : neutraliser **son propre** paramètre et
recapturer répond en trente secondes à « est-ce moi ? », là où un `git stash` a fait
perdre deux minutes et failli emporter le travail — la remise au propre rebasculait
`HARNESS` sur `&"workforce"`, un harnais sans `--shot` ni `quit()`, qui a bloqué jusqu'au
délai d'expiration.

### Décisions

**L'avancement vit sur `PlacedBuilding`, pas dans un troisième index.** `CityState` tient
deux index qui disent la même vérité — ce qui existe, quelle cellule renvoie à quoi. Un
avancement rangé à côté d'eux serait un état séparé du bâtiment qu'il décrit, à
resynchroniser à chaque pose et à chaque retrait. Le docstring qui promettait un
`PlacedBuilding` immuable est corrigé plutôt que contourné : **son placement est figé,
son avancement ne l'est pas**, et c'est exactement ce que `DESIGN.md` 3.2 demande en
disant qu'un chantier est un *état* du bâtiment posé.

**`advance()` rend un `bool`, pas un DTO `{ok, reason}`.** Profil de `remove()` et non de
`place()`. La convention réserve le DTO aux erreurs récupérables, et un refus de
placement en est une vraie — le fantôme interroge le validateur à chaque image et la
plupart des réponses sont des refus. Ici les deux seuls refus possibles — rien à cette
ancre, chantier déjà fini — se posent avant l'appel, et un booléen suffit à dire lequel
s'est produit quand même.

**`advance()` n'est pas un verrou, et le docstring le dit.** `place()` est une porte
exclusive : rien n'entre dans la ville sans être passé par le validateur, et c'est tenu
par la structure. `advance()` ne peut pas l'être — le renderer tient une liste de
`PlacedBuilding` depuis `C2`, et fermer ça demanderait de ne plus jamais en laisser
sortir un. Écrire « porte documentée » plutôt que « seule porte » coûte une phrase et
évite qu'on croie à une garantie qui n'existe pas.

**L'achèvement se teste dans `_work_lines()`, avant le bloc de production.** Même endroit
unique que `E1b` avait choisi pour `produces()` : toute ligne de travail en sort, donc
tout ce qui en consomme une sait que le bâtiment produit **et** qu'il est fini. L'ordre
des deux clauses n'est pas indifférent — un ouvrier envoyé sur une ferme en chantier
chôme parce qu'elle n'est pas finie, pas parce qu'elle ne produirait pas. La distinction
ne se lit nulle part aujourd'hui ; elle se lira le jour où le rapport dira pourquoi.

**Hauteur et couleur sont pilotées par le même nombre.** Un chantier monte et reprend sa
couleur ensemble. Réglés séparément, les deux signaux auraient fini par se contredire —
une boîte presque haute encore grise. La teinte de fondation et le plancher de hauteur
sont des constantes d'adapter et non de `data/` : ce que `data/` décide reste ce qu'un
bâtiment **fini** vaut, l'écart qu'un chantier montre est de l'affichage. `PlacementGhost`
tient ses deux teintes exactement là pour la même raison.

**Le plancher de hauteur est non nul, et c'est le seul des trois chiffres qui compte.** À
zéro, un chantier fraîchement posé serait une boîte d'épaisseur nulle, donc invisible, et
on ne verrait pas qu'on vient de payer une case. Il faut qu'il se voie *pour* se lire
comme inachevé.

**Pas de drapeau `--shot-build`.** `--shot-rotate` existait parce que rien d'autre ne
pivotait un bâtiment posé ; ici l'étalement des avancements met déjà chantiers et
bâtiments finis sous les yeux d'une seule capture. Un drapeau qui ne montrerait rien de
neuf est une option de plus à documenter et à maintenir.

**Le nom `build_actions`, et pas `turns`.** `turns` désigne déjà les quarts de tour d'une
orientation, partout dans le système. La collision aurait été silencieuse et
catastrophique.

### Ce qui reste

Rien pour `C4`. Cinq choses volontairement laissées de côté :

- **la carte *Construire* et l'affectation typée par action** — `D1` et `D2`. Inventer
  aujourd'hui un verbe dans `Assignment` serait deviner la forme du Deck : c'est la règle
  qui a sorti `CombatForce` de `W1`.
- **ce que rend un chantier détruit** — `OUVERT` de 3.2, laissé entier. Détruire libère
  les cellules et ne rend rien, ce qui est l'état par défaut et non une réponse.
- **le Combat qui voit les chantiers** — `F1`. `buildings()` lui garde la porte ouverte,
  et c'est tout ce que `C4` lui devait.
- **l'adjacence** — `C3`, inchangé.
- **le délai de chantier dans les harnais Économie et Effectifs** — `I1`, argumenté
  ci-dessus.

Et deux constats à porter ailleurs :

- **une question de design neuve, inscrite en `OUVERT` dans 3.2** : quelle piste l'action
  *Construire* crédite-t-elle ? Aucune des trois familles ne la couvre. Elle appartient à
  `D2`, et elle a trois issues — une quatrième famille, un rattachement à l'Artisanat, ou
  de l'XP de niveau seule, ce que les deux axes de `W1` rendent déjà possible.
- **la trame d'ombre sur le dessus des boîtes** — travail Terrain, antérieure à `C4`,
  prouvée telle par capture de contrôle.

Les deux reports de `W1` tiennent toujours : la troncature du rendement à `I3`, et la
mise en commun des rapports texte des harnais, toujours sans jalon attitré — `_make_label()`
en est maintenant à cinq exemplaires.

### Prochain jalon

**`D1`** — le `Deck`, la `Hand`, les trois pools, défausse, remélange, draft. Puis `D2`,
qui donnera enfin à *Construire* une carte et un ouvrier, et qui trouvera le chantier
déjà là à viser. `I1` ensuite.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée — `Espace` est lu en `InputEventKey` brut comme le reste.

- `F5` lance le **harnais Construction** : la carte, treize bâtiments posés en haut à
  droite dont neuf en chantier à des stades différents, le fantôme sous le curseur. Clic
  gauche pose, clic droit détruit, **Espace bâtit un cran**, 1 à 9 choisissent, Tab
  pivote. Q/E, molette, WASD et R restent à la caméra. `HARNESS` revient à `&"economy"`,
  `&"workforce"` ou `&"terrain"` en un mot dans `scenes/dev/dev_boot.gd`.
- **les treize chiffres de chantier sont à relire.** Ils viennent du tableau de
  `DESIGN.md` 4.1, donc ce sont des hypothèses au même titre que les coûts — et le Cœur
  n'en porte volontairement aucun. Le boot ne peut pas refuser un zéro, puisque c'est une
  valeur légitime : c'est le seul champ de `BuildingData` où une faute de saisie passe
  sans bruit, et c'est la raison de le relire une fois.
- rien de neuf dans `data/` : aucun `.tres` créé, donc **aucun `uid` manquant** cette
  fois-ci — pour la première fois depuis `T1`.

---

## 2026-08-25 — `W1` : l'ouvrier, ses deux axes, et la boucle refermée sur `E1`

**État : terminé.** Six commits sur `feat/w1-workforce`, tirée de **`master`** — la
première depuis `I0`, la chaîne de branches empilées s'arrête ici parce que `E1b` y a
été fusionnée entre-temps. Les trois commandes passent : boot sans erreur ni warning,
tout `src/domain/` parse, **304 tests verts contre 247** à l'ouverture, 21 suites contre
16.

La branche a de nouveau été créée **à l'orientation**, avant la première ligne. Deux
jalons d'affilée : la leçon de `E1` tient.

### Ce qui a été livré

- `src/domain/workforce/` — six fichiers : `skill_track.gd`, `worker.gd`, `roster.gd`,
  `skill_resolver.gd`, et les deux du rapport, `skill_gain.gd` et `progress_report.gd`.
- `src/schema/workforce_balance.gd` + `data/balance/workforce_balance.tres`, chaînés
  dans `BalanceData` — cinquième bloc.
- `BuildingData.roster_places`, et `house.tres` qui cesse d'être une coquille vide.
- `tests/domain/workforce/` — quatre suites, plus `workforce_balance_test.gd` et la
  couture dans les deux suites de schéma voisines.
- `scenes/dev/workforce_harness.gd`, `HARNESS` basculé sur `&"workforce"`.
- `DESIGN.md` 3.4, 4.1 et 8 ; `README.md`.

**`contracts/` n'a pas bougé d'une ligne de code**, et c'est le résultat que le jalon
visait. `E1` avait été écrit en pensant à ici : `LaborUnit` portait déjà un
multiplicateur par famille, `WorkLine` portait déjà la famille à créditer. `W1` était
annoncé comme « le dernier moment où `LaborForce` peut bouger sans douleur » — elle n'a
pas eu à bouger. Seul un docstring y a gagné une précision, celle de savoir ce que « le
roster » veut dire une fois les absents retirés.

### Quatre arbitrages avant d'écrire, dont un qui a changé le design

**`CombatForce` sort de `W1` pour `F1`**, contre ce que `DESIGN.md` 8 annonçait. Son
contenu est décidé par le format de combat, qui est `OUVERT` en 3.6 : écrite
aujourd'hui, elle serait ou bien un clone strict de `LaborForce` qui ne prouve rien, ou
bien une devinette sur des PV et de l'équipement. Et contrairement à `skill_family` à
`E1`, la repousser ne coûte rien — `F1` l'écrira avec le `DamageReport`, pour le même
système neuf. C'est la règle de `E1` appliquée à la classe qui l'avait fait énoncer.

Ce que `W1` garantit à la place est plus solide qu'un second DTO : **`Roster` est le
seul propriétaire des `Worker`**, et rien hors de `domain/workforce/` n'en voit un. Le
vivier unique n'est plus une discipline d'écriture, c'est une conséquence de la
structure.

**La progression se fait par paliers**, pas par courbe continue. Un passage de niveau
est un événement qu'on annonce, et un ouvrier qu'on peut appeler « Récolte 3 » existe
dans une conversation comme un multiplicateur à 1,37 n'existera jamais. Une progression
douce reste exprimable — c'est beaucoup de petits paliers.

**Un second axe est entré, et il vient de l'humain.** À côté de la piste par famille,
un **niveau d'ouvrier** alimenté par toute source d'XP — travail, combat, événement —,
qui ne donne aucun multiplicateur et sert à distinguer un vétéran d'un bleu d'un coup
d'œil. `DESIGN.md` ne le portait pas : le design est donc passé **en premier**, dans le
commit d'ouverture, comme les empreintes libres à `C1` et la rotation à `C2`.

Il est entré coupé en deux, et la coupure compte. L'**accumulateur et les paliers** sont
écrits ; ce qu'un palier **offre** — le menu de compétences — devient `X5`. Une raison
de ne pas tout repousser : « XP de toute source » veut dire que `F1` et les événements
devront trouver le compteur déjà là, sinon chacun inventera où loger son XP.

**L'absence de 3.9 entre maintenant**, minimale : un état de présence, et `to_labor()`
qui ne projette que les présents. Coût réel : un booléen, un filtre, trois cas de test.
C'est la contrainte qu'on ne rattrape pas après coup.

### La règle qui relie les deux axes, et pourquoi elle est structurelle

**Toute XP compte deux fois** — une fois pour la piste concernée, une fois pour le
niveau. Un seul chiffre de gain les alimente tous les deux ; deux montants distincts
auraient donné un levier de plus à régler par source d'XP, et deux chiffres à tenir
cohérents pour rien.

Ce qui rend la règle tenable est un choix d'encapsulation : **une `SkillTrack` ne sort
jamais de son `Worker`**. La rendre laisserait un appelant la créditer seule, et
l'invariant redeviendrait une consigne. Le prix est une poignée d'accesseurs qui
délèguent, et il est faible.

Le niveau est un **compteur réel et non la somme des pistes**. Aujourd'hui les deux
coïncident, puisque le travail est la seule source d'XP écrite. Ils divergeront à la
première XP qui n'appartient à aucune famille — celle d'un événement —, et le dériver
maintenant obligerait alors à inventer une famille fourre-tout pour l'y loger.

### Le cas de test qui porte le jalon

C'est le premier de tout le projet à faire tourner **deux systèmes du domaine
ensemble** : résoudre un soir, distribuer l'XP, reprojeter, résoudre le suivant — et la
cabane rend 2 puis 3. `E1` avait écrit un journal de travail que personne ne lisait ;
c'est ce cas qui prouve qu'il sert.

Son jumeau compte autant : la même séquence **sans** la distribution rend 2 deux fois.
Sans lui, le premier passerait tout aussi bien si la récolte montait toute seule.

Deux autres tiennent un terrain que rien d'autre ne couvre — **spécialiser doit
soulever une famille et laisser les autres à plat**, ce que `DESIGN.md` 3.4 promet
depuis `E1` sans que rien ne le vérifie ; et **`to_labor()` doit laisser les absents**,
la seule ligne qui paie pour 3.9 et celle dont la disparition ne réveillerait personne
avant `X1`.

### Le harnais, et le constat qu'il rapporte

Premier harnais à composer deux systèmes : chaque soir, l'Économie résout, les Effectifs
distribuent, la main-d'œuvre est reprojetée. C'est le rôle que `RunOrchestrator`
reprendra à `I1`, et il tient en trois lignes.

Il répond, et sa réponse n'est pas celle qu'on attendait : **la récolte reste plate
dix-neuf soirs alors que toutes les pistes montent.** Le rendement est tronqué **par
ouvrier et par soir** — une décision de `E1`, écrite et argumentée —, or sur des
promesses à 2 ou 3, un cran de 0,15 est entièrement avalé tant que le multiplicateur n'a
pas franchi l'entier suivant. La nourriture ne bouge qu'au soir 20 (×1,45), le bois et
la pierre qu'au soir 26 (×1,60).

**Le constat est structurel, pas un mauvais réglage** : aucune valeur du cran ne le
supprime. Seuls des rendements plus gros, ou une troncature déplacée — accumuler en
flottant et n'arrondir qu'une fois par ressource —, y changeraient quelque chose. Les
deux sont des questions de `I3`, et la seconde touche `ProductionResolver`. À consigner
plutôt qu'à corriger dans un jalon qui n'est pas le sien.

Il chiffre aussi ce que l'absence coûte, ce qu'aucun test ne montre : Elric part au soir
12, la carrière tombe de 4 pierre à 2, il revient six soirs plus tard avec une piste de
retard sur ses camarades — et il n'a rien mangé pendant ce temps.

C'est le quatrième harnais d'affilée à répondre quelque chose qu'aucune suite de tests
ne pouvait donner. Le motif est maintenant une règle : ils travaillent sur les chiffres
de `data/`, là où les tests travaillent sur des chiffres choisis.

### Décisions

**`SkillTrack.level_at()` est statique, publique, et sert aux deux axes.** Les paliers
montent de la même façon des deux côtés ; seuls les réglages diffèrent. Une progression
qui accélérerait sur un axe et pas sur l'autre serait une décision d'équilibrage
déguisée en décision de code.

**`SkillResolver` mute le `Roster` et rend un rapport.** Profil identique à
`ProductionResolver` qui mute le `Ledger`, et pour la même raison : le roster est l'état
interne des Effectifs, ce qui est précisément pourquoi il ne figure dans aucune ligne de
contrat.

**`ProgressReport` reste dans `domain/workforce/`.** Comme `PickResult` est resté dans
`domain/terrain/` : aucun second système du domaine ne le franchit, et la table des DTO
de `CLAUDE.md` ne le liste pas. Son seul consommateur sera un adapter de `W2`.

**Chaque ligne de travail est créditée séparément**, sans regroupement par ouvrier.
Aujourd'hui les deux reviennent au même — une `Assignment` envoie un ouvrier à une seule
ancre —, mais rien n'en dépend, et deux lignes du même ouvrier cumuleraient
correctement. Un cas de test le tient.

**Un ouvrier nommé au journal mais absent du roster est sauté sans un mot.** Miroir exact
de `ProductionResolver._work_lines()` : une affectation peut avoir survécu à celui qui la
portait, et un mort ne progresse pas.

**`roster_places` est un champ plat sur `BuildingData`**, à côté de `storage_bonus` et
pour la même raison : c'est un nombre qui relève un plafond global, pas une nature de
bâtiment. La doctrine du zéro ne s'y applique donc pas non plus — douze bâtiments sur
treize ne logent personne. Il remonte sous son propre nom et non sous le préfixe
économique, parce que c'est un chiffre des Effectifs.

**Le roster ne consulte jamais son plafond.** `add()` n'oppose aucun refus : c'est la
couche qui orchestre la journée qui pose les deux questions à la suite, exactement comme
elle enchaîne « payable » et « posable ». Un cas de test le dit à voix haute, pour que
personne ne « répare » `add()` plus tard.

**Le harnais lit la famille dans `data/` au lieu de l'écrire.** Un `&"harvest"` en dur y
survivrait à un renommage du catalogue sans que rien ne le signale. Constat au passage :
les quatre producteurs de `data/buildings/` emploient tous la même famille, donc la
spécialisation *entre* familles n'est pas encore observable sur le contenu réel —
l'atelier, qui en emploierait une autre, n'a toujours pas de bloc de production.

**Les prénoms sont codés en dur dans le harnais.** Un catalogue de prénoms dans `data/`
est du contenu, donc `I3`, exactement comme les empreintes inventées à `C1`.

**La duplication des rapports texte n'a pas été traitée.** `_make_label()` existe
maintenant en quatre exemplaires, `_bundle_text()` en deux. La mettre en commun est une
passe à part entière — les variantes diffèrent, surimpression sur de la 3D contre
rapport plein écran —, et ce n'était pas le sujet de `W1`. Consigné ici pour que ça ne
passe pas pour un oubli.

### Ce qui reste

Rien pour `W1`. Cinq choses volontairement laissées de côté :

- **les traits** — sous l'`OUVERT` de granularité de 3.4, et désormais rattachés à `X5` :
  c'est aux paliers de niveau qu'ils s'acquerront.
- **le recrutement** — `OUVERT` de 3.4. Le plafond de places existe ; ce qui le remplit
  non.
- **la conséquence de la famine** — `OUVERT` de 3.3. La tentation était ici, puisque les
  Effectifs possèdent les unités ; les quatre issues restent entières.
- **blessures, morts, XP de combat, `CombatForce`** — `F1`, tous les quatre.
- **le panneau d'affectation, les fiches, l'auto-affectation** — `W2`, nommément.

Et deux constats à porter ailleurs :

- **la troncature du rendement** — `I3`, et elle touche `ProductionResolver`.
- **la mise en commun des rapports texte des harnais** — une passe de nettoyage, sans
  jalon attitré.

### Prochain jalon

**`C4`** — les chantiers. Il rouvrira les treize `.tres` de `data/buildings/` pour y
écrire la colonne **Chantier** de `DESIGN.md` 4.1, fera porter l'avancement à
`CityState`, et le fera traverser `CitySnapshot`. `D1` et `D2` suivent, puis `I1`.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée.

- `F5` lance le **harnais Effectifs** : deux tableaux texte et un verdict, aucune 3D. Il
  s'imprime aussi sur la sortie standard, donc `godot --headless --quit --path .` suffit
  à le lire. `HARNESS` revient à `&"economy"`, `&"city"` ou `&"terrain"` en un mot dans
  `scenes/dev/dev_boot.gd`.
- `data/balance/workforce_balance.tres` naît **sans `uid`**, comme à chaque jalon :
  **diff à committer, pas à jeter**.
- **les sept chiffres d'équilibrage sont à relire.** `DESIGN.md` ne donne aucune courbe
  de compétence : `base_roster_places`, `xp_per_shift`, les deux seuils, les deux
  plafonds et le cran d'efficacité sont **inventés**, comme les empreintes depuis `C1`.
  Le harnais est fait pour dire ce qu'ils valent, et il a déjà répondu que le cran est
  trop fin pour les rendements actuels. Le boot refuse un champ vide, donc les corriger
  dans l'inspecteur est sans risque.
- `house.tres` porte désormais `roster_places = 2`, repris du tableau de `DESIGN.md` 4.1.

---

## 2026-08-25 — `E1b` : le bloc de production, le minerai, et les douze bâtiments

**État : terminé.** Six commits sur `feat/e1b-production-block`, tirée de
`feat/e1-economy` — la chaîne habituelle, `master` n'a toujours rien reçu. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **247 tests
verts contre 241** à l'ouverture.

La leçon de `E1` a été appliquée sans qu'on ait à la réapprendre : **la branche a été
créée à l'orientation**, avant la première ligne écrite.

### Ce qui a été livré

- `src/schema/production_block.gd` — la classe neuve, et le seul vrai sujet du jalon.
- `BuildingData` — perd `slots`, `yield_per_slot` et `skill_family`, gagne
  `production` et `produces()`.
- `ProductionResolver` — lit le bloc, et pose une meilleure question qu'avant.
- `GameDatabase` — le contrôle croisé traverse le bloc et nomme le chemin.
- `data/commodities/ore.tres`, et **sept bâtiments neufs** : mine, habitation, tour de
  guet, caserne, marché, atelier, camp d'exploration. Les six anciens réécrits.
- `tests/schema/production_block_test.gd`, et la couture dans les deux suites voisines.
- `scenes/dev/economy_harness.gd` — la file d'attente de construction.
- `DESIGN.md` 4.1.

### Ce que le bloc achète, et ça se lit à ce qui a disparu

`E1` avait consigné une entorse assumée : « la doctrine du zéro ne s'applique pas au
bloc économie ». À plat sur `BuildingData`, `slots = 0` était une valeur parfaitement
légitime — la palissade n'a pas de poste. Un champ non renseigné y cessait donc d'être
détectable, et il avait fallu le remplacer par un contrôle de cohérence **entre** les
trois champs.

L'entorse est levée, et sans avoir été traitée. Un bloc qui existe produit : ses trois
champs se réclament maintenant sans condition, comme partout ailleurs dans le projet.
Le gain ne se voit pas dans le code ajouté mais dans celui qui a disparu —
`BuildingData._economy_fields()` a perdu ses trois clauses croisées et ne fait plus que
déléguer sous un préfixe.

**Le cas de test qui porte le jalon est celui des slots à zéro**, précisément parce que
`E1` ne pouvait pas l'écrire.

### Trois arbitrages, dont un qui change le contenu

**Les cinq bâtiments à slot muet entrent sans bloc.** Tour de guet, caserne, marché,
atelier et camp d'exploration portent « 1 slot » dans le tableau de `DESIGN.md` 4.1, et
aucun ne produit de ressource : leur poste héberge une défense (`F1`), un échange
(`I3`) ou une action débloquée (`X1`, `X2`, `X3`). Leur écrire un `slots = 1` que rien
ne lit aurait fait mentir la data **et** détruit la garantie qu'on venait d'acheter, en
rouvrant la possibilité d'un bloc qui ne produit rien. C'est exactement le cas que
`DESIGN.md` 3.3 anticipait en écrivant « le jour où un bâtiment produit autrement, le
bloc devient une classe de base » : ce jour n'est pas aujourd'hui, parce que ces slots
ne produisent pas autrement — ils ne produisent pas.

**La palissade entre au tableau 4.1.** Elle existait dans `data/` depuis `C2` sans y
figurer, ce qui faisait diverger le design de son contenu. Elle est la seule empreinte
non rectangulaire du projet, donc le seul cas qui exerce vraiment la rotation du
fantôme et le validateur. L'atelier lui donne depuis ce jalon un second L.

**Les colonnes Chantier, Déf., PV et Débloque restent dehors.** Un champ arrive avec le
système qui le lit — `C4`, `F1`, `D1` —, et les places de roster de l'habitation avec
`W1`. Conséquence à consigner pour ne pas la relire comme un oubli : **l'habitation
entre en coquille vide**, sans rien que son coût, et c'est correct.

### Le harnais a gagné une file, et il a répondu autre chose

La mine coûte 25 bois et 10 pierre. Aucune bourse d'ouverture ne les a : ajouter la
mine à la liste de construction du harnais l'aurait fait refuser au premier jour, et le
minerai serait entré au catalogue sans qu'aucun soir n'en produise — une quatrième
ressource déclarative, ce qui est exactement ce que le jalon ne voulait pas.

Ce qu'un bâtiment impayable devient est donc devenu une question, et la réponse est une
**file** : ce que la bourse refuse à l'ouverture y entre, et le harnais en retente la
tête, une par soir. Elle ne se réordonne jamais — un bâtiment cher qui se ferait doubler
par un moins cher derrière lui ferait répondre le harnais à une question qu'on ne lui
pose pas. L'affectation se refait à chaque soir en conséquence : sans ça, les postes
d'un bâtiment apparu en cours de route seraient restés vides.

Il dit maintenant ce qu'il ne pouvait pas dire : **la mine se paie au soir 8, la
seconde ferme au soir 10, et c'est cette ferme qui met fin à la famine.** La première
famine reste au soir 6 — les chiffres de `data/balance/` n'ont pas bougé —, mais la
réserve finit à **189/200 au vingtième soir contre 160 à `E1`** : le plafond commun est
beaucoup plus près de mordre qu'il ne le paraissait. À `I3` de trancher.

C'est le troisième harnais d'affilée à répondre quelque chose qu'aucune suite de tests
ne pouvait donner. Le motif se confirme : ils travaillent sur les chiffres de `data/`,
là où les tests travaillent sur des chiffres choisis.

### Décisions

**Le bloc s'écrit en `sub_resource`, pas en fichier séparé.** Un bloc appartient à son
bâtiment et n'a aucune identité au catalogue ; `TerrainDecor` sur un terrain est le même
motif, déjà éprouvé depuis `T3`. Un cas de test charge tous les `.tres` de `data/` et
exige qu'au moins un en porte un typé — sans cette dernière exigence, il passerait par
vacuité le jour où le format se casserait partout.

**`produces()` plutôt qu'un `production != null` recopié.** La nullité est la façon dont
`E1b` dit « ne produit pas » ; le jour où le bloc devient une classe de base, la question
restera posée au même endroit. Trois appelants s'en servent déjà.

**L'existence du bloc se teste dans `_work_lines()` et nulle part ailleurs.** Toute ligne
de travail en sort, donc tout ce qui en consomme une sait que le bâtiment produit —
`_harvest()` lit le bloc sans garde, et son docstring dit pourquoi.

**Le contrôle croisé nomme le chemin complet.** Vérifié en cassant une clé exprès :
`ressource inconnue « oer » dans data/buildings/mine.tres → production.yield_per_slot`.
Sans le préfixe, un `yield_per_slot` nu ne dirait plus d'où il vient le jour où
`BuildingData` portera plusieurs blocs.

**Le terrain `filon` n'est pas écrit.** `TerrainGenBalance` porte cinq emplacements de
terrain en dur ; en ajouter un est du travail Terrain, et une `.tres` que rien ne génère
serait de la data morte. La mine produit du minerai sans en avoir besoin — aucun
prérequis de tag n'existe au placement depuis `C1`. Ça redeviendra nécessaire à `D2`,
quand *Récolter* à cru voudra une case `ore`.

**`economy_harness.gd.uid` manquait depuis `E1`.** Tous les autres scripts de
`scenes/dev/` ont le leur suivi ; le scan éditeur de ce jalon l'a révélé. Corrigé dans
son propre commit, parce que ce n'est pas du contenu de `E1b`.

### Ce qui reste

Rien pour `E1b`. Les mêmes reports qu'à `E1`, plus deux :

- **les modificateurs d'adjacence** — `C3`. Le bloc est l'endroit naturel où les mettre
  le jour venu, ce qui n'était pas vrai des champs à plat.
- **le HUD et le panneau de rapport** — `E2`.
- **l'XP** — `W1`, qui consommera le journal de travail.
- **les 3:1 du marché, le rayon de l'atelier, les chiffres de 4.1** — `I3`.
- **les slots des cinq bâtiments muets** — chacun avec son système.

### Prochain jalon

**`W1`.** Il est le dernier moment où `LaborForce` peut bouger sans douleur, et le seul
qui rende utile le journal de travail écrit à `E1`. `C4` — les chantiers — vient
ensuite, et rouvrira les treize `.tres` pour y écrire la colonne Chantier.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- `F5` lance toujours le **harnais Économie** : un rapport texte, aucune 3D, lisible
  par `godot --headless --quit --path .`.
- les `.tres` neufs — `ore` et les sept bâtiments — naissent **sans `uid`**, comme à
  chaque jalon : **diff à committer, pas à jeter**.
- **les chiffres et les formes des sept bâtiments neufs sont à relire.** Les coûts
  viennent du tableau de `DESIGN.md` 4.1 ; **les empreintes, les couleurs et les
  hauteurs sont inventées**, comme toutes les autres depuis `C1`. Le boot refuse un bloc
  incomplet ou un coût nommant une ressource inconnue, donc les corriger dans
  l'inspecteur est sans risque. La tour de guet est volontairement haute (1.6) et
  l'atelier volontairement en L.

---

## 2026-08-24 — `E1` : la réserve, la résolution du soir, l'upkeep et la famine

**État : terminé.** Sept commits sur `feat/e1-economy`, tirée de
`feat/c2-placement-ghost` — la chaîne habituelle, `master` n'a toujours rien reçu. Les
trois commandes passent : boot sans erreur ni warning, tout `src/domain/` parse,
**241 tests verts contre 160** à l'ouverture.

Un accroc de procédure à consigner, parce qu'il explique l'histoire de la branche : la
session s'est ouverte **sans créer de branche**, et le premier commit — la mise à jour
de `DESIGN.md` — a atterri sur `feat/c2-placement-ghost`. Repéré par l'humain avant
tout push. Réparé en créant `feat/e1-economy` à cet endroit et en ramenant `c2` sur sa
remote : aucun commit perdu, `c2` de nouveau identique à ce qu'elle valait. La leçon
tient en une ligne : **la branche se crée à l'orientation, avant le premier commit**,
pas quand on y pense.

### Ce qui a été livré

- `src/domain/contracts/` — sept DTO : `CitySnapshot` et `BuildingSnapshot`,
  `LaborForce` et `LaborUnit`, `Assignment`, `WorkLine`, `ProductionReport`.
- `src/domain/economy/` — `ledger.gd` et `production_resolver.gd`.
- `CityState.to_snapshot()`, seule ligne touchée dans `domain/city/`.
- `src/schema/` — `commodity_data.gd`, `economy_balance.gd`, et le bloc économie de
  `BuildingData`.
- `data/commodities/` — trois ressources ; `data/balance/economy_balance.tres` ;
  `data/buildings/farm.tres` et `warehouse.tres`.
- `GameDatabase` — `get_commodity()`, `list_commodity_ids()`, et le contrôle croisé.
- `scenes/dev/economy_harness.gd`, et `HARNESS` basculé sur `&"economy"`.
- `DESIGN.md` 3.3 et 3.4, `README.md`.

### Quatre questions arbitrées avant d'écrire

Comme à `C1`, le plan en posait quatre. Une réponse a franchement changé le jalon.

**La réserve est commune, pas par ressource.** C'est la réponse qui coûte, et c'est
l'inverse de ce que je recommandais. Cent unités partagées entre le bois, la pierre et
la nourriture : remplir sa réserve de bois, c'est renoncer à stocker de la pierre. Le
plafond ne force plus seulement à dépenser, il force à choisir *quoi* garder, et
l'entrepôt devient un vrai arbitrage au lieu d'un relèvement de trois compteurs
indépendants.

**La `LaborForce` porte un multiplicateur par famille**, et `BuildingData` déclare la
sienne. L'argument décisif n'était pas la pureté mais le coût : c'est un champ dans
quatre `.tres` que j'ouvrais déjà, contre les rouvrir tous à `W1` *et* changer un
contrat.

**La famine se constate et ne se punit pas.** `DESIGN.md` ne disait nulle part ce
qu'elle fait. Plutôt que de le laisser non-dit, c'est entré comme un `OUVERT` explicite
en 3.3 : le rapport porte le compte des non-nourris, donc mort, blessure, départ ou
malus restent les quatre également ouvertes.

**Le catalogue de ressources existe**, dans `data/`. Sans lui, un `&"wodo"` dans un coût
créerait une ressource fantôme qui se stockerait, ne s'achèterait jamais et ne
s'afficherait nulle part.

### La réserve commune, et ce qu'elle coûte vraiment

Le choix a une conséquence que ni le plan ni la question ne voyaient : **une récolte qui
déborde doit décider laquelle de ses ressources entre.** Avec un plafond par ressource,
ce problème n'existe simplement pas.

La réponse évidente — premier arrivé, premier servi — est un piège. L'ordre des clés
vient de l'ordre de pose des bâtiments : deux villes identiques bâties dans un ordre
différent perdraient des choses différentes, sans que rien à l'écran ne l'explique.
C'est la même famille d'erreur que les quatre passes du validateur à `C1`, où la raison
affichée aurait dépendu de l'ordre d'écriture du `.tres`.

La règle retenue est **proportionnelle à ce que le dépôt apporte**, le reste de la
division allant aux plus grosses parts fractionnaires, l'identifiant tranchant à
égalité. Elle est entièrement déterminée par les quantités. Le cas de test qui compte
dépose les mêmes montants dans deux ordres de clés opposés et exige le même résultat :
un premier-arrivé-premier-servi passerait tous les autres cas et échouerait sur
celui-là.

Le même écrêtage sert quand la capacité **baisse** — un entrepôt détruit par une vague.
Une règle écrite une fois, utilisée deux fois.

### La doctrine du zéro ne s'applique pas au bloc économie

Tout le projet repose depuis `I0` sur « un champ non renseigné vaut 0, donc détectable ».
Les quatre champs économiques de `BuildingData` y échappent, et il valait mieux le dire
que le contourner : **0 slot, un coût vide et une réserve nulle sont trois valeurs
légitimes** du tableau de `DESIGN.md` 4 — la palissade n'a pas de poste, la cabane de
bûcheron est gratuite. Les réclamer refuserait de démarrer sur des données correctes.

Ce qui les remplace est un contrôle de **cohérence entre eux**, qui lui est bien réel :
des slots sans rendement ne produiraient rien, un rendement sans slot ne serait jamais
versé, un poste sans famille ne saurait quelle piste créditer. Les trois se chargent
sans erreur et ne cassent qu'au premier soir. Un cas de test énonce le point à voix
haute : un bâtiment sans aucun bloc économie est complet.

### Décisions

**`CommodityData` et non `ResourceData`.** Deux raisons qui se cumulent : `Resource` est
déjà le type de base de Godot dont le fichier hérite, et `GameDatabase.get_resource()`
est déjà l'accesseur générique de l'index — un `get_resource(&"resources", &"wood")`
serait illisible. Le vocabulaire du jeu ne bouge pas : `DESIGN.md` dit « ressource » et
les identifiants restent `&"wood"`, `&"stone"`, `&"food"`.

**Le résolveur mute le `Ledger`, et ce n'est pas une entorse.** Le ledger est l'état
*interne* de l'Économie, exactement comme `CityState` l'est de Construction, et
`place()` a déjà le même profil — valider, muter, rendre le résultat. La ligne de
contrat de `DESIGN.md` 3.3 énumère les entrées **inter-systèmes**, ce qui est
précisément pourquoi le ledger n'y figure pas.

**Le rapport rapporte, il ne punit pas.** Il ne calcule aucune XP non plus : combien
vaut une soirée de travail est un chiffre des Effectifs. Il porte un **journal de
travail** — qui a tenu quel poste, dans quelle famille — et `W1` en fera ce qu'il veut.
La famille y figure pour que les Effectifs n'aient pas à rouvrir la ville pour retrouver
le bâtiment.

**L'upkeep tombe sur le roster entier, oisifs compris.** C'est ce qui rend un ouvrier
non affecté coûteux, donc le pool tendu, donc la tension centrale de `DESIGN.md` 1
réelle plutôt que déclarative. `LaborForce.size()` est le roster et non le nombre
d'affectés, et son docstring le dit.

**Les oisifs se déduisent du roster moins ceux qui ont travaillé.** Cette soustraction
couvre d'un coup les quatre façons de ne rien produire — non affecté, ancre vide,
bâtiment sans poste, slot déjà pris — sans qu'aucune ait à être énumérée. Un ouvrier que
l'affectation nomme mais que le roster ignore n'apparaît nulle part : une affectation
peut survivre à celui qui la portait, et un mort ne chôme pas.

**`upkeep_resource` est un champ d'équilibrage**, trouvé en écrivant le résolveur. Un
`&"food"` en constante dans `src/domain/` aurait été le nombre magique que les
conventions interdisent, et surtout il aurait survécu à un renommage du catalogue sans
que rien ne le signale.

**Le contrôle croisé vit dans `GameDatabase`.** C'est le seul contrôle qu'aucune
`Resource` de `src/schema/` ne peut faire seule, puisqu'aucune ne lit l'index — et c'est
très bien ainsi. Vérifié en cassant une clé exprès : le boot nomme le fautif et liste ce
qu'il connaît. Quatrième copie de la même boucle de validation ; le seuil annoncé à `C1`
se rapproche sans être atteint.

**Deux bâtiments entrent, chacun pour une raison précise** — le motif de la palissade à
`C2`. L'**entrepôt** est la seule chose qui relève la réserve commune, soit la décision
phare du jalon ; la **ferme** est le seul producteur de nourriture, sans lequel le
harnais meurt de faim au premier soir et la boucle ne montre rien.

### Le harnais, et ce qu'il a répondu

Il fait ce que `C1` a rendu possible et que rien n'avait encore fait tourner : il pose
les **deux** questions à la suite — payable, puis posable, puis on dépense. L'ordre
compte, payer avant de savoir si ça tient sur le relief laisserait la ville plus pauvre
sans rien de bâti. La sixième entrée de sa liste de construction est là pour être
refusée bourse vide, ce qui n'est pas un refus de placement.

Et comme celui de `C1`, il **cherche** son cas au lieu de le mettre en scène : il laisse
tourner vingt soirs et dit lequel a cassé le premier, la famine ou la réserve pleine.

Réponse sur l'équilibrage actuel : **famine au soir 6, réserve jamais pleine — 160/200
au vingtième.** C'est un signal qu'aucune suite de tests ne peut donner, puisqu'elles
travaillent sur des chiffres choisis et que la question porte justement sur ceux de
`data/balance/`. Il dit qu'avec dix ouvriers pour six postes, c'est la nourriture qui
étrangle bien avant le plafond. À `I3` de décider si c'est le bon dosage.

Un défaut trouvé en lisant le rapport, et pas autrement : deux lignes voisines
annonçaient `20/100` puis « capacité 200 ». La réserve ne prenait sa nouvelle capacité
qu'à la résolution suivante, alors qu'un entrepôt doit compter dès qu'il est bâti. Le
résolveur la repose de toute façon, ce qui rendait l'oubli parfaitement silencieux —
donc à écrire là où le HUD de `E2` le fera aussi.

### Ce qui reste

Rien pour `E1`. Quatre choses volontairement laissées de côté :

- **les modificateurs d'adjacence** — `C3`. Le résolveur documente la couture : ils
  entreront comme un argument de plus, appliqués au rendement d'un slot juste avant le
  multiplicateur de l'ouvrier.
- **le HUD et le panneau de rapport** — `E2`, nommément. `capacity_for()` est publique
  et pure exprès, pour qu'il affiche « 47 / 200 » sans rien résoudre.
- **l'application de l'XP** — `W1`, qui consommera le journal de travail.
- **les 3:1 du marché et le rayon de l'atelier** — du contenu, donc `I3`.

`CombatForce` et `DamageReport` ne sont pas écrits : `F1` n'existe pas, et on n'invente
pas une frontière que personne ne franchit. `BuildingSnapshot` ne porte pas de PV pour
la même raison.

### Prochain jalon

**`E2`** — HUD des ressources et panneau de rapport de production — si l'on veut voir
l'économie ; **`W1`** si l'on préfère fermer la boucle du domaine avant toute UI. Les
deux sont débloqués et `W1` est le seul des deux qui rende le journal de travail utile
à quelque chose. Il est aussi le dernier à pouvoir encore faire bouger `LaborForce` sans
douleur.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée.

- `F5` lance le **harnais Économie** : un rapport texte, aucune 3D. Il s'imprime aussi
  sur la sortie standard, donc `godot --headless --quit --path .` suffit à le lire —
  c'est la commande de vérification n°1. `HARNESS` revient à `&"city"` ou `&"terrain"`
  en un mot dans `scenes/dev/dev_boot.gd`.
- les `.tres` neufs — trois dans `data/commodities/`, `economy_balance.tres`, `farm` et
  `warehouse` — naissent **sans `uid`**, comme à chaque jalon : **diff à committer, pas
  à jeter**.
- **les chiffres du bloc économie sont à relire.** Coûts, slots et rendements viennent du
  tableau de `DESIGN.md` 4 ; les empreintes de la ferme et de l'entrepôt, elles, sont
  inventées, comme les quatre autres depuis `C1`. Le boot refuse un bloc incohérent —
  des slots sans rendement, un rendement sans slot, un coût nommant une ressource
  inconnue — donc les corriger dans l'inspecteur est sans risque.

---

## 2026-08-24 — `C2` : fantôme de placement, pose et destruction

**État : terminé.** Dix commits sur `feat/c2-placement-ghost`, tirée de
`feat/c1-placement` : `master` n'a rien reçu, c'était la consigne. Boot sans erreur ni
warning, tout `src/domain/` parse, 160 tests verts contre 145 à l'ouverture.

Le jalon a été élargi en cours de route à la **rotation des bâtiments**, qui n'était
pas au plan et que `DESIGN.md` ne prévoyait pas. Elle est traitée en fin d'entrée.

Mais ces trois commandes ne prouvent presque rien ici, et c'est le fait marquant du
jalon : `src/adapters/` n'est pas testé, le domaine n'a pas bougé d'une ligne, et
**tout ce que `C2` apporte est à l'écran**. La capture n'est pas un supplément de
confort, c'est le contrôle principal — elle a d'ailleurs trouvé le seul vrai bug.

### Ce qui a été livré

- `scenes/dev/dev_world.gd` — le plateau commun aux harnais : ciel, soleil, caméra,
  relief, décorations, survol.
- `scenes/dev/dev_shot.gd` — le vocabulaire de capture, partagé.
- `src/adapters/city/building_renderer.gd` et `placement_ghost.gd`.
- `BuildingData` gagne `color` et `height`, et les `.tres` avec.
- `data/buildings/palisade.tres` — une empreinte en L.
- `scenes/dev/city_harness.gd` réécrit : la scène remplace le rapport texte.
- la **rotation** : `BuildingData.rotate_offset()`, l'orientation portée par
  `PlacedBuilding`, traversant `validate()`, `place()` et le fantôme.
- `CLAUDE.md`, `README.md`.

### Le domaine n'a pas bougé, et c'est le résultat

Pas une ligne de `src/domain/` n'a changé. `validate()` était déjà pure et appelable à
chaque image, `place()` et `remove()` attendaient leurs clics, `PlacementResult`
portait déjà les cellules et la hauteur auxquelles dessiner. `C1` avait fait son
travail, et `C2` n'a été que de la traduction : un clic vers le domaine, une réponse
vers l'écran.

`TerrainMetrics` et `PickResult` ne sont **pas** montés dans `contracts/`. La question
traînait depuis `T3` et le journal de `C1` la reposait pour ici : la réponse est non.
Ce sont les *adapters* de Construction qui en ont besoin, et la règle de dépendance
contraint le domaine, pas eux. Aucun système du domaine ne franchit cette frontière.

### Le plateau partagé, et ce que sa vérification a appris

Le harnais Construction avait besoin exactement de la scène que le harnais Terrain
montait déjà — on ne pose pas un bâtiment sur un terrain qu'on ne voit pas. D'où
`DevWorld`, plutôt que soixante lignes recopiées dont le soleil réglé à `T2` et tout
son raisonnement.

Pour prouver que l'extraction ne changeait rien, capture avant et capture après. La
première comparaison a été **mal lue** : l'image « après » semblait franchement plus
zoomée. Elle ne l'était pas.

Le viewport garde la largeur de base du projet mais sa **hauteur suit le rapport de la
fenêtre**, et le tout premier lancement n'avait pas obtenu la fenêtre qu'il demandait.
Deux enseignements, consignés au README :

- la capture imprime désormais une ligne `cadrage` — `camera.size` et taille du
  viewport. Deux captures ne se comparent que si cette ligne est identique ;
- **`cmp` sur les deux `.png` tranche là où l'oeil se trompe.** Vérification faite
  ainsi, l'extraction rend des images *strictement identiques*, octet pour octet.

C'est un outil que je n'avais pas et qui a resservi trois fois dans la journée.

### Le bug que seule l'image a montré — la carte chauve

Quatrième jalon d'affilée, quatrième bug de rendu invisible aux trois commandes.

La première capture du harnais Construction montrait une carte **sans un seul arbre ni
rocher**. Le relief était là, les bâtiments aussi, mais la végétation avait disparu.

`TerrainRenderer.create()` se peuple lui-même ; `TerrainDecorRenderer.create_all()`
**non** — elle construit une passe par terrain, vides, que seul `rebuild()` remplit.
`DevWorld.create()` promettait dans son propre docstring un plateau « déjà peuplé » et
mentait sur ce point. Le harnais Terrain masquait la faute depuis toujours en
enchaînant sur son propre `show_grid()` juste après.

Corrigé à la source : `create()` termine par `show_grid(grid)`, donc un seul chemin
peuple le plateau et la promesse redevient vraie. Le harnais Terrain rebâtit une
seconde fois, ce qui ne coûte rien et ne change rien — vérifié en capture, byte à byte.

### Le soleil : un problème annoncé qui n'existe pas

`CLAUDE.md` prévenait depuis `T3` que les bâtiments, étant des boîtes, se heurteraient
au piège du prisme noir, et tranchait d'avance qu'il faudrait déplacer le soleil.

**Ça n'est pas arrivé.** Les boîtes posées sur le relief gardent leurs quatre flancs
parfaitement lisibles. C'était prévisible après coup : elles présentent à la lumière
exactement les orientations des colonnes du terrain, qui se lisent bien depuis `T2`.
Le piège du prisme venait de sa face *oblique*, pas du fait d'avoir des flancs
verticaux.

Le soleil n'a donc pas bougé, et `CLAUDE.md` est corrigé : une prédiction fausse laissée
dans un document permanent se paie plus tard, quand quelqu'un « répare » un problème
inexistant et casse la lecture de toute la carte au passage.

### La palissade, entrée pour une raison précise

Rien de ce qui tournait ne dessinait une empreinte **non rectangulaire** — or c'est la
seule chose pour laquelle `C1` existait. Les tests couvraient le domaine, mais le
renderer n'avait jamais tracé un L.

`palisade.tres` comble ça : un angle de trois cellules, que la capture montre bien
comme un L et non comme un rectangle. Le chemin data → domaine → rendu est vérifié de
bout en bout. `DESIGN.md` 4 liste une palissade et n'en donne pas la forme ; en faire un
angle reste une empreinte provisoire, comme les trois autres.

### Décisions

**Une boîte par cellule occupée, pas une par bâtiment.** Sur un L, un volume unique
couvrirait le trou de l'enveloppe et mentirait sur la forme. Le rendu suit l'empreinte
pour la même raison que la validation : `bounds_at()` est une enveloppe, pas un
bâtiment.

**Le fantôme ne décide rien.** `CellHighlight` annonçait à `T3` qu'elle ne coderait
aucune validité et que la question appartiendrait à `C2` : elle y est, et la réponse
vient toujours du domaine. Le fantôme reçoit un `PlacementResult` déjà calculé et le
colore.

**La validation a lieu une fois par image, et les deux consommateurs lisent le même
résultat.** Le fantôme et la ligne de rapport ne revalident pas chacun de leur côté :
une couleur qui contredirait sa propre légende serait un bug impossible à voir.

**La hauteur du fantôme vient du survol, pas du résultat.** Un refus n'a pas de hauteur
— `PlacementResult.height()` lève sur un placement refusé — et c'est précisément sur un
refus qu'il faut voir le fantôme. Il se pose donc à la hauteur de la cellule survolée,
qui est toujours connue.

**Le fantôme dessine aussi les cellules hors carte.** Un bâtiment à moitié dans le vide
se voit alors tel qu'il est, ce qui explique le refus mieux qu'une empreinte tronquée.
Vérifié en capture au bord est de la carte.

**Couleur et hauteur des bâtiments vivent dans `data/`.** Même raison que pour les
terrains : un renderer qui commuterait sur un identifiant obligerait à toucher au
GDScript à chaque ajout. La hauteur est en **fractions de tuile**, la leçon des
décorations de `T3` : régler `tile_size` doit emporter les bâtiments avec la carte.

**`DevShot` tient les drapeaux de capture.** Le README les documente comme une
fonctionnalité du projet et non d'un harnais ; deux harnais qui les redéfiniraient
chacun de leur côté finiraient par diverger sans que personne ne s'en aperçoive avant
de taper la commande de l'un sur l'autre.

### La rotation, ajoutée en cours de jalon

Demandée après coup, et entrée par la porte normale : `DESIGN.md` 3.2 n'en disait rien,
donc le design est passé en premier — c'est la même règle qui avait fait précéder les
empreintes de forme libre à `C1`.

**L'orientation appartient au placement, pas au bâtiment.** Rien dans `data/` ne la
décrit : une même `BuildingData` se pose dans les quatre sens. Quatre crans, comme la
caméra, et le même vocabulaire.

**La rotation se fait autour de la cellule d'ancrage.** C'est la décision qui porte tout
le reste. L'ancre est le décalage `(0, 0)`, et elle est invariante par rotation : une
empreinte pivotée contient donc toujours son ancre, `missing_fields()` n'a rien à
revérifier, et la forme pivote sous le curseur au lieu de sauter à côté. L'alternative
— normaliser les décalages pour les garder positifs — aurait déplacé le bâtiment à
chaque quart de tour.

Le résultat mérite d'être noté : **pas une ligne du validateur ne parle de rotation.**
Il reçoit une liste de cellules et ne sait pas d'où elle vient. Les deux index de la
ville non plus. `BuildingRenderer` non plus — il lit `PlacedBuilding.cells()`, qui
applique l'orientation en amont. Toute la fonctionnalité tient dans `rotate_offset()`
et dans un paramètre passé de main en main.

Les deux cas de test qui portent le plus posent la **même empreinte à la même ancre** et
obtiennent un verdict différent une fois tournée : l'une échappe au bord de la carte,
l'autre se range le long d'une marche au lieu de la traverser. Ce sont eux qui prouvent
que les règles travaillent sur des cellules déjà pivotées.

Côté harnais, `Tab` pivote — pas `R`, qui recadre la caméra depuis `T2`. Un vrai jeu du
genre mettrait la rotation sur `R` et déplacerait le recadrage ; c'est une décision d'UI
qui appartient à `D2`, pas au sélecteur de debug d'un harnais.

`--shot-rotate` a été ajouté pour la même raison que `--shot-hover` existait : sans lui,
aucune capture ne montrerait jamais un bâtiment pivoté, donc rien ne le vérifierait. Et
la ville d'ouverture pose désormais chaque bâtiment dans une orientation différente —
arbitraire et assumé, parce que le fantôme seul ne prouve rien sur `BuildingRenderer`.

La capture a d'ailleurs montré tout de suite un comportement juste et pas évident : le
Cœur accepté au centre de la carte devient `uneven_ground` une fois pivoté d'un quart de
tour. Normal — il couvre alors quatre autres cellules, de l'autre côté de son ancre.

### Ce qui reste

Rien pour `C2`. Trois choses volontairement laissées de côté :

- **l'adjacence et la prévisualisation du delta** — c'est `C3`, nommément.
- **le coût à la pose** — `E1`, et la décision est déjà prise : il passera par
  l'Économie ou les cartes, pas par le placement.
- **la sélection par carte** — `D2`. Les touches 1 à 9 du harnais sont un sélecteur de
  debug, pas une UI.

### Prochain jalon

`C3` — règles d'adjacence et prévisualisation du delta au survol. Le terrain est prêt :
`BuildingData.neighbourhood_at()` attend son premier appelant depuis `C1`, la
validation tourne déjà à chaque image sous le curseur, et le rapport a la place
d'afficher un delta à côté de son verdict.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée — les clics sont lus en `InputEventMouseButton` brut.

- `F5` lance le **harnais Construction** : la carte, quatre bâtiments déjà posés en
  haut à droite — chacun dans une orientation différente —, le fantôme sous le curseur.
  Clic gauche pose, clic droit détruit, 1 à 9 choisissent, **Tab pivote**. Q/E, molette,
  WASD et R restent à la caméra. `HARNESS` revient à `&"terrain"` en un mot.
- les quatre `.tres` de `data/buildings/` sont toujours **sans `uid`** — une passe
  headless de l'éditeur ne leur en attribue pas, seule l'ouverture réelle le fait :
  **diff à committer, pas à jeter**. Leurs empreintes, couleurs et hauteurs sont
  provisoires et se corrigent sans risque dans l'inspecteur : le boot refuse toute
  empreinte vide, sans ancre ou redondante, ainsi qu'une couleur ou une hauteur non
  renseignée.

---

## 2026-08-24 — `C1` : la ville, les empreintes et les règles de placement

**État : terminé.** Six commits, une couche chacun, sur `feat/c1-placement`. Les trois
commandes de vérification passent : boot sans erreur ni warning, tout `src/domain/`
parse, 145 tests verts contre 100 à l'ouverture.

### Ce qui a été livré

- `src/domain/contracts/placement_result.gd` — la réponse à « puis-je poser ici ? ».
- `src/schema/building_data.gd` — identité, empreinte, et la géométrie qui en découle.
- `src/domain/city/` — `city_state.gd`, `placement_validator.gd`, `placed_building.gd`.
- `tests/domain/city/` — 16 cas de placement, 15 cas de rangement.
- `tests/schema/building_data_test.gd` — 14 cas.
- `data/buildings/` — trois `.tres`.
- `GameDatabase` — `get_building()`, `list_building_ids()`, contrôle de complétude.
- `scenes/dev/city_harness.gd`, et `HARNESS` basculé sur `&"city"`.
- `DESIGN.md` 3.1 et 3.2.

### Quatre points arbitrés avant d'écrire

Le plan en posait quatre à l'humain. Les quatre réponses ont changé le jalon, et deux
l'ont simplifié.

**Le coût sort du placement.** `DESIGN.md` 3.2 se contredisait : sa ligne de contrat
prend `CityState + BuildingData + ancre`, sans bourse, mais sa liste de validation
disait « ressources suffisantes ». Même nature que la signature de `pick()` à `T3` — la
contradiction était dans le document, pas dans le code. Tranché pour la ligne de
contrat : « ai-je les 15 bois ? » ne regarde pas la carte, et c'est la couche qui
orchestre la journée qui enchaînera les deux questions. `REASON_INSUFFICIENT_RESOURCES`
rejoindra `PlacementResult` ce jour-là sans que le validateur ne bouge. 3.2 le dit
maintenant explicitement.

**Aucun prérequis dur d'adjacence.** « Requiert un gisement voisin » était dans la liste
de validation ; il en sort. L'adjacence reste entièrement la couche de rendement de
`C3`, et le placement ne regarde jamais le voisinage.

**Mais la zone de recherche est écrite quand même**, à la demande de l'humain :
`BuildingData.neighbourhood_at(anchor, radius)`. Elle n'a **aucun appelant** avant `C3`,
et c'est consigné dans son propre docstring — écrire d'avance est exactement ce que ce
projet évite, et une exception qui ne se dit pas devient une habitude. Ce qui la rend
acceptable : c'est de la géométrie pure, elle se teste sans terrain ni ville, et le
rayon y est un argument et non un champ de data — rien dans `data/buildings/` ne le
porte.

**Toutes les cellules à la même hauteur, pour tous les bâtiments.** Je proposais que
chaque `.tres` déclare s'il exige du plat. La version de l'humain est plus simple : la
règle est universelle, l'enum disparaît, le validateur tient en une passe de plus.

### La planéité tranche un `OUVERT`, et `DESIGN.md` est passé en premier

3.1 demandait « le relief joue-t-il sur le gameplay, et comment ? » et listait quatre
pistes. Exiger du plat prend la piste *contrainte de construction* et élimine *purement
décoratif* : le relief décide désormais d'où le village peut s'étendre, et c'est ce qui
donne à un plateau sa valeur. Les deux autres — avantage défensif en hauteur, accès aux
ressources selon l'altitude — restent entières, et le **terrassement** les rejoint :
c'est précisément cette règle qui le rendrait intéressant.

`DESIGN.md` est modifié dans le **premier** commit, et non dans celui du journal comme
la procédure de session le voudrait. `CLAUDE.md` interdit d'écrire une feature avant que
le design la porte, et les empreintes de forme libre n'y figuraient pas : la mise à jour
devait donc précéder le code, pas le conclure.

### Décisions

**Une empreinte est une liste de décalages, pas un rectangle.** `Array[Vector2i]` depuis
l'ancre : un L, un T ou une croix s'écrivent, et un rectangle n'est qu'un cas
particulier — ce qui évite d'avoir deux façons de dire la même chose et deux chemins à
valider. Ce que j'avais annoncé comme coûteux ne l'était pas : `TerrainQuery` expose
déjà `in_bounds()`, `is_buildable()` et `height_at()` par cellule, donc une validation
cellule par cellule se fait avec le contrat **tel quel**, sans y ajouter une seule
méthode. Les helpers `Rect2i` de `T1` restent, simplement inutilisés par le placement.

**`bounds_at()` ne valide jamais rien.** L'enveloppe d'un L couvre une cellule que le
bâtiment n'occupe pas. Deux cas de test l'épinglent des deux côtés : de l'eau dans ce
trou n'empêche pas la pose, et le trou reste posable ensuite. C'est ce couple qui prouve
que tout travaille sur l'empreinte et non sur son enveloppe — autrement dit que les
formes libres sont réelles et pas décoratives.

**`PlacementResult` entre dans `contracts/` tout de suite**, contrairement à
`PickResult` à `T3`. Non par changement de doctrine : la table de `CLAUDE.md` l'y liste
déjà, quand elle ne listait pas `PickResult`. Sa raison est un `StringName` et non un
`enum`, comme la convention le prescrit pour ce DTO précisément — un adapter la mappe
sur un libellé sans rien importer du domaine.

**`CityState.place()` est la seule porte mutante, et elle valide avant de muter.** Rien
ne peut donc entrer dans la ville sans être passé par `PlacementValidator` : invariant
tenu par la structure, pas consigne à respecter. `validate()` reste pure et appelable
seule, ce dont le fantôme de `C2` a besoin — il l'appellera à chaque image sous le
curseur, et la pose lui rend exactement le résultat qu'il affichait.

**Quatre passes sur l'empreinte, pas une boucle.** En une seule, une empreinte dont une
cellule est occupée et une autre sous l'eau rendrait la raison de celle qui vient en
premier dans le `.tres` : la raison affichée dépendrait de l'ordre d'écriture de la
data. En quatre passes, elle ne dépend que de l'ordre des règles. Deux cas de test font
échouer deux règles à la fois pour le tenir.

L'ordre des règles n'est pas libre non plus : les bornes d'abord, parce que
`height_at()` exige une cellule dans la grille et lèverait sur une empreinte qui
déborde. C'est une précondition du contrat Terrain, pas une préférence d'ergonomie.

**`missing_fields()` contrôle l'empreinte au-delà de sa présence.** Une empreinte qui ne
contient pas son ancre, ou qui nomme deux fois la même cellule, se charge sans erreur et
ne casse qu'à la pose. Les deux remontent préfixées `footprint.`, comme `TerrainData`
préfixe `decor.`, et le boot les refuse. En revanche une empreinte **en deux morceaux
disjoints** est acceptée : elle se pose sans rien casser, et la refuser serait une règle
de contenu déguisée en règle de schéma.

**Le cycle `CityState` ↔ `PlacementValidator` passe.** L'un prend l'autre en paramètre,
l'autre l'appelle dans un corps de fonction. Ce n'est pas le cycle qui avait mordu à
`T3` entre `TerrainData` et `TerrainDecor` : celui-là portait sur une **constante**,
résolue à la compilation. Types et corps de fonction se résolvent plus tard, et la
commande 2 le confirme.

**`data/buildings/` n'est pas la passe de contenu.** `DESIGN.md` 4 liste dix bâtiments
et ne donne **aucune** colonne d'empreinte : les trois `.tres` posés ici ont des tailles
inventées, que `I3` reprendra. Ils existent pour que `GameDatabase` ait une catégorie à
indexer et à contrôler, et pour que le harnais tourne sur de vrais fichiers. Les trois
sont rectangulaires, fidèles à un design qui ne nomme aucun bâtiment en L : inventer une
forme aurait été trancher du contenu à la place de l'humain, et les tests couvrent les
formes libres sans rien figer dans `data/`.

### Le harnais cherche ses refus au lieu de les fabriquer

C'est la seule chose non prévue au plan. Plutôt que de coder en dur une cellule d'eau et
une marche, le harnais balaye la carte à la recherche d'une ancre qui produit
**exactement** la raison visée, et le dit quand il n'en trouve pas.

Sur le seed 1234, les quatre y sont. C'est ce que les suites de tests ne peuvent pas
montrer : elles travaillent sur des grilles de six cases faites à la main, où chaque
règle est déclenchée par construction. Ici, une règle qui cesserait de se déclencher sur
du terrain réellement généré remonterait toute seule — et une carte trop lisse pour la
déclencher se signalerait, au lieu de passer pour un succès.

C'est le pendant texte de la sonde caméra de `T3` : quelques lignes dans un harnais, à
l'endroit exact où ce genre d'échafaudage a sa place.

### Ce qui reste

Rien pour `C1`. Deux choses volontairement laissées de côté :

- **les PV, le coût, les slots, le rendement.** Ils viendront avec `E1`, `C3` et `F1`,
  comme `BalanceData` gagne un bloc quand un système atterrit. Un champ ajouté plus tard
  oblige à rouvrir les `.tres` ; un champ ajouté d'avance oblige à deviner sa forme, ce
  qui coûte plus cher.
- **`CitySnapshot`.** La table de `CLAUDE.md` le donne à l'Économie et au Combat, dont
  aucun n'existe. Même raisonnement qu'à `T2` et `T3` : on n'invente pas une frontière
  que personne ne franchit. Il arrive à `E1`.

`TerrainMetrics` et `PickResult` sont restés dans `domain/terrain/`. Le journal de `T3`
posait la question pour `C1` ; la réponse est non — sans rendu, Construction ne touche
ni au monde ni aux rayons. Elle se repose à `C2`, qui est justement le jalon où le
fantôme aura besoin des deux.

### Prochain jalon

`C2` — fantôme de placement, pose et destruction dans la scène de dev. Tout ce dont il a
besoin est en place : `validate()` est pure et appelable à chaque image, un
`PlacementResult` rend déjà les cellules et la hauteur auxquelles dessiner, et
`CityState.remove()` attend son clic droit.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'input
ajoutée.

Deux points de suite :

- `F5` lance maintenant le **harnais Construction**, un rapport texte sur fond noir :
  `HARNESS` vaut `&"city"` dans `scenes/dev/dev_boot.gd`. Le remettre à `&"terrain"`
  rend la carte en relief, la souris, Q et E, la molette.
- les trois `.tres` de `data/buildings/` naissent **sans `uid`**. Une passe headless de
  l'éditeur ne leur en attribue pas — vérifié cette fois-ci —, seule l'ouverture réelle
  le fait : **diff à committer, pas à jeter**, comme à `I0`, `T1`, `T2` et `T3`. Leurs
  empreintes sont provisoires, et les corriger dans l'inspecteur est sans risque : le
  boot refuse toute empreinte devenue vide, sans ancre, ou redondante.

---

## 2026-08-24 — `T3` : picking DDA, surbrillance et décorations

**État : terminé.** Quatre commits, une couche chacun, sur `feat/t3-cell-picking`. Les
trois commandes de vérification passent : boot sans erreur ni warning, tout
`src/domain/` parse, 94 tests verts contre 66 à l'ouverture. Le rendu a été vérifié en
image, et cette fois aussi c'est l'image qui a trouvé le bug.

### Ce qui a été livré

- `src/domain/terrain/cell_picker.gd` — la marche DDA, fonction pure.
- `src/domain/terrain/pick_result.gd` — ce qu'elle rend.
- `tests/domain/terrain/cell_picker_test.gd` — 20 cas.
- `src/schema/terrain_decor.gd` + le champ `decor` sur `TerrainData`, et les trois
  `.tres` de `data/terrain/` qui le renseignent.
- `tests/schema/terrain_decor_test.gd` — 8 cas.
- `src/adapters/terrain/` — `terrain_decor_renderer.gd`, `cell_highlight.gd`,
  `cell_cursor.gd`.
- `scenes/dev/terrain_harness.gd` — les trois branchés, le survol au rapport,
  `--shot-hover` et la sonde caméra.
- `CLAUDE.md` et `README.md` mis à jour.

### La signature figée qui ne l'était pas

`CLAUDE.md` donnait `pick(grid, origin, dir)` et le journal de `T2` la qualifiait de
« signature figée ». Elle est inapplicable telle quelle : le DDA a besoin de
`tile_size` et de `step_height` pour savoir où sont les cellules dans le monde, et
c'est `T2` lui-même qui a sorti ces deux chiffres de `HeightGrid` pour les mettre dans
`TerrainMetrics`. La contradiction était dans le document, pas dans le code.

Arbitré avec l'humain avant écriture : la métrique devient un quatrième paramètre. La
fonction reste pure et statique, sans état caché, et reçoit son réglage en argument
comme `TerrainGen.generate()` reçoit le sien. `CLAUDE.md` est corrigé dans le même
commit que le reste, avec la mention de ce qu'elle valait avant — une signature figée
qui bouge doit dire qu'elle a bougé.

### Décisions

**Aucun DTO n'entre dans `contracts/`, et l'étape est sautée**, comme à `T2`. Seul
l'adapter du Terrain consomme `PickResult`, et la table de `CLAUDE.md` ne le liste pas.
Il se promeut à `C2` si le fantôme de placement en a besoin. Inventer un contrat pour
respecter la forme de la procédure figerait une frontière que personne ne franchit.

**Une colonne est solide vers le bas et sans fond.** Le socle que le renderer dessine
sous la carte n'est qu'une épaisseur d'affichage : lui donner un fond dans le picker
ouvrirait des tirs qui passent sous la carte pour ressortir de l'autre côté. Corollaire
assumé et testé : un tir parti de sous le terrain est déjà dans la roche et la touche
sur place. Consigné dans `CLAUDE.md`, parce que c'est le genre de modèle qu'on
réinvente autrement six mois plus tard.

**Le rayon est clippé sur l'emprise de la carte avant de marcher.** Une caméra
orthogonale place l'origine de son rayon à cent unités de la carte ; sans le clip, la
marche dépenserait son budget dans le vide. Le clip a aussi rattrapé un vrai bug : quand
la carte est traversée par la *droite* du rayon mais entièrement **derrière** son
origine, l'intervalle d'entrée est négatif, et le point ramené dans la grille par le
clamp rendait une cellule inventée. Un cas de test le tient.

**Le point d'impact d'une face supérieure est recalé exactement sur le sommet.**
Mathématiquement il y est déjà ; le laisser sortir du calcul flottant y remettrait
quelques ulp de bruit, dans la valeur même sur laquelle un bâtiment se posera. Le test
assert l'égalité stricte, pas l'égalité approchée.

**La décoration se décrit dans `data/`, dimensions en fractions de tuile.** Même
raisonnement qu'à `T2` pour la couleur : le renderer ne commute jamais sur un
identifiant de terrain. Et les fractions plutôt que les unités de monde, parce que
régler `tile_size` doit redimensionner la carte entière — décorations comprises — et non
laisser les arbres à leur ancienne taille au milieu de cellules qui ont changé.

**`decor` est nullable, seule exception au principe de sentinelle.** La plaine et l'eau
n'ont rien à porter, et « rien » y est évident plutôt que suspect. Le filet reste tendu
là où il sert : une décoration *présente* mais à moitié remplie remonte préfixée
`decor.`, comme `BalanceData` préfixe ses blocs, et le boot la refuse.

**La sentinelle de couleur est recopiée dans `TerrainDecor` au lieu d'être importée.**
`TerrainData` nomme déjà `TerrainDecor` dans un `@export` ; lui répondre par une
constante fermerait le cycle de types. Un cas de test épingle l'égalité des deux copies,
pour que la duplication ne dérive pas.

**La palette est passée en argument au renderer, pas lue sur `GameDatabase`.** Les
passes se construisent alors sur ce que le jeu *connaît* et non sur ce qu'une grille
contient : un seed sans rocher ne doit pas supprimer la passe des rochers, que le seed
suivant remplirait. L'adapter reçoit ses données comme le domaine reçoit les siennes.

**La dispersion vient d'un hash de la cellule.** Ni `randf()`, qui est interdit, ni
`RunState.rng` : une même carte doit se disperser pareil à chaque affichage, et faire
descendre un flux de tirage jusqu'à une passe de rendu coûterait une dépendance pour un
résultat identique.

**La surbrillance ne code aucune validité.** Une marque verte ou rouge selon qu'on peut
y bâtir préempterait Construction, à qui la question appartient. Une seule couleur :
« c'est cette cellule-là ». Le picker désigne, il ne juge pas — un test vérifie qu'on
survole l'eau aussi bien que la plaine.

**Le curseur pique à chaque image, pas au mouvement de souris.** La caméra bouge aussi :
pendant un quart de tour tweené, le rayon change sans que le curseur n'ait remué.

### Le bug que seule l'image a montré — le prisme noir

Troisième jalon d'affilée, troisième bug de rendu que les trois commandes de
vérification laissent passer.

J'avais donné trois formes au vocabulaire des décorations : cône pour les arbres, sphère
pour les rochers, **prisme** pour les gisements. La capture a montré des rectangles noirs
posés sur les cellules de gisement. Une passe de diagnostic — recolorer la forme en
magenta pour savoir quels pixels lui appartiennent vraiment, plutôt que de deviner entre
la décoration et son ombre — a confirmé que c'était bien le prisme, et pas une ombre.

**Le `PrismMesh` porte une grande face verticale plate.** Et le soleil de la scène
n'éclaire que les surfaces tournées vers le haut : toute face verticale ne reçoit que
l'ambiante. Dès que la face plate se présente à la caméra, elle se lit comme un trou. Il
n'y a pas d'orientation qui sauve, puisque la caméra pivote par quarts de tour au-dessus
d'un soleil fixe.

Ce qui a été fait, et ce qui ne l'a pas été :

- **le prisme est retiré du vocabulaire**, pas documenté avec une mise en garde. Une
  valeur d'enum inutilisée qui produit des trous noirs est un piège pour qui la choisira
  ensuite. Il reste deux formes, sans face plate, qui gardent un dégradé sous tous les
  angles ;
- **le soleil n'a pas bougé.** Que seules les faces du dessus soient éclairées est
  l'aspect établi à `T2` — tops clairs, arêtes sombres — et c'est un choix, pas un
  défaut. Le renverser unilatéralement pour sauver une décoration aurait changé toute la
  lecture de la carte ;
- le gisement est donc devenu une **sphère aplatie**, qui offre un dessus éclairé et se
  distingue du rocher par sa proportion.

La contrainte est consignée dans `CLAUDE.md`, avec sa suite : **les bâtiments seront des
boîtes**, donc ils la rencontreront aussi. Le jour où leurs flancs poseront problème, ce
sera le soleil qu'il faudra bouger, pas la forme.

### Une addition non prévue au plan — la sonde caméra

Entre les tests unitaires, qui tirent des rayons fabriqués à la main, et les trois
commandes de vérification, qui ne regardent pas l'écran, il restait une jointure non
couverte : est-ce que `project_ray_origin` et `project_ray_normal` d'une caméra
**orthogonale** donnent au picker ce qu'il attend ?

Chaque capture imprime donc une sonde. Elle reprojette le point d'impact désigné *vers*
l'écran, retire un rayon depuis cette position exactement comme le ferait la souris, et
dit si les deux tombent sur la même cellule. Vérifié au centre, dans un coin, et après
un quart de tour : d'accord dans les trois cas.

C'est le pendant de `--shot` à `T2` — quelques lignes dans un harnais, qui est
exactement l'endroit où ce genre d'échafaudage a sa place, et qui rendent vérifiable
depuis un terminal ce qui ne l'était pas.

`--shot-hover x,y` complète le dispositif : souris à `(0, 0)`, une capture ne montrerait
jamais la surbrillance, donc ne prouverait rien à son sujet. À défaut d'argument, la
capture désigne le centre de la carte.

### Un test qui s'est cassé sur sa propre erreur

Le cas « changer `tile_size` change la cellule désignée » visait un point à `z = 5` sur
une grille de 4 × 3. À `tile_size` 1, l'emprise ne fait plus que 4 × 3 unités : le tir
manquait la carte, ce qui est correct. C'est l'`assert` de `PickResult.cell()` qui a
levé, en disant exactement ce qu'il fallait. Le picker n'avait rien ; c'est l'attente
qui était fausse. Le cas vise maintenant un point qui tombe dans l'emprise des deux
métriques, et le commentaire dit pourquoi.

### Ce qui reste

Rien pour `T3`. `DESIGN.md` n'a pas bougé, et c'est délibéré : `T3` ne tranche aucune
question `OUVERT`. Désigner une cellule ne dit rien du rôle du relief dans le gameplay,
et les quatre pistes de 3.1 restent entières.

Deux choses volontairement laissées de côté :

- **plus d'une décoration par cellule.** Un `MultiMesh` à compte variable par cellule
  pour un gain purement esthétique, pas à ce stade.
- **l'amplitude du relief**, toujours ouverte depuis `T2` avec ses deux leviers chiffrés.
  Les décorations ne changent rien à l'arbitrage : c'est le même choix d'aspect, adossé
  à la même question `OUVERT`.

### Prochain jalon

`C1` — `CityState`, `PlacementValidator`, empreintes, tests, sans rendu. C'est l'ordre
de démarrage suggéré par `DESIGN.md` 8 : `T1→T3`, puis `C1→C2`.

`T4`, l'occlusion, reste conditionné à un playtest qui montrerait que c'en est vraiment
un problème — `DESIGN.md` le dit explicitement, et rien de ce jalon ne l'a rendu plus
urgent.

`C1` sera aussi le moment de rouvrir la question de `TerrainMetrics` et de `PickResult` :
si Construction en a besoin directement, c'est là qu'ils montent dans `contracts/`.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni réglage de projet n'a changé, aucune action
d'input n'a été ajoutée — le curseur lit la position brute de la souris. `HARNESS` vaut
toujours `&"terrain"` : `F5` affiche la carte, la souris survole, Espace passe au seed
suivant, Q et E tournent, la molette zoome, R recadre.

Deux points de suite :

- `data/balance/camera_balance.tres` n'a toujours pas de `uid`, et les trois `.tres` de
  terrain décorés viennent d'être réécrits sans `uid` non plus. L'éditeur leur en
  attribuera à la première ouverture : **diff à committer, pas à jeter**, comme à `I0`,
  `T1` et `T2`.
- une capture écrite dans l'arborescence du projet se fait importer par le scan suivant,
  qui lui colle un `.png.import`. Écrire les captures hors de `res://` — noté au README.

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
