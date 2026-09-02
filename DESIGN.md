# DESIGN.md — Citadelle *(titre de travail)*

> **Statut du document.** Réécrit le 2026-09-01 par le **rescope**, en discussion et avant
> toute modification de code. Il remplace le document qui a porté le projet de `I0` à `F2b`,
> et qui reste consultable dans l'historique git — dernière version sur `master`, commit
> `144689b`.
>
> Les sections marquées **`OUVERT`** sont des décisions volontairement repoussées. Les
> sections marquées **`HORS MVP`** décrivent ce qu'on n'écrit pas mais qu'on ne rend pas
> impossible. Les deux conventions sont celles du document qu'il remplace, et pour la même
> raison : un choix repoussé doit se voir, sinon il se prend par accident.
>
> La section **9** dit ce qui est supprimé et pourquoi. Elle n'est pas un regret : c'est ce
> qui empêche le document de mentir sur son propre passé, ce que l'ancien n'a jamais fait.

---

## 0. Pourquoi ce document

Le projet a accumulé quatre genres — city-builder, roguelite, deckbuilding, combat
tactique — parce que chacun était aimé séparément. Ils se chevauchent : trois contraintes
de tempo (cartes, ouvriers, ressources) se doublent au lieu de se croiser, et le combat
tactique est un second jeu qui demande deux systèmes différés (`X5`, `X6`) rien que pour
ne pas être plat.

Ce rescope garde **une** idée et l'instrumente jusqu'au bout :

> **Un city-builder de placement sur un terrain accidenté, où l'on bâtit ce qui produit et
> ce qui défend sur les mêmes cases, parce qu'il n'y en a pas assez.**

Tout ce qui suit en découle. Chaque système supprimé l'est parce qu'il ajoutait une
contrainte qui n'était pas spatiale.

---

## 1. Pitch

City-builder roguelite en 3D isométrique sur grille en relief. On fonde un village autour
d'un **Cœur**, on l'étend sur un terrain qui décide où l'on peut bâtir, et périodiquement
une vague marche sur ce Cœur par les accès que le relief lui laisse. Ce qui l'arrête est ce
qu'on a construit, et où.

**La tension centrale est spatiale, et elle a un seul étage.** Les plateaux plats sont les
bonnes cases de production *et* les bonnes cases de défense, et les cols qui y mènent sont
les seuls endroits où une tour sert à quelque chose. Chaque case donnée à la défense est
une case retirée à l'économie qui la paie.

**Références** — *Islanders* / *Dorfromantik* (lisibilité du relief en blocs, plaisir du
placement, adjacence comme moteur), *Against the Storm* (boucle roguelite + city-builder),
*Anno* / *Banished* (la population qui bâtit, qui mange et qui plafonne), *Kingdom Rush* /
*Rampart* (une défense qui se prépare et s'observe, jamais une bataille qu'on pilote).

---

## 2. Boucle de jeu

**Run** → génération de carte → pose du Cœur → suite de tours → vagues datées → fin.

### Un tour

Il n'y a **qu'une sorte de tour**, et c'est le principal gain du rescope. La journée en
phases disparaît : elle existait parce que deux gestes différents — poser une carte, y
envoyer des ouvriers — demandaient chacun leur moment.

```
  1. On lit ce que le tour précédent a rendu.
  2. On lance des chantiers, dans la limite de la capacité que la population autorise.
     On peut aussi démolir.
  3. On passe le tour.
  4. Résolution, dans cet ordre imposé :
       a. les bâtiments finis produisent      (sur la ville d'avant, cf. ci-dessous)
       b. les chantiers avancent, et ceux qui s'achèvent deviennent des bâtiments
       c. la population mange
       d. la population croît ou décroît
       e. si une vague est datée ce tour, elle se joue
```

**L'ordre a-b est imposé et c'est la règle héritée qui survit intacte.** La production se
calcule sur la ville **d'avant** l'avancement des chantiers, sans quoi un entrepôt achevé
ce tour-ci relèverait la réserve du même tour, et l'ordre dans lequel les chantiers ont été
lancés déciderait du résultat. Deux villes identiques bâties dans un ordre différent doivent
rendre la même chose.

**La production n'est plus pilotée par une action jouée.** Un bâtiment fini qui a ses
habitants produit, tous les tours, sans qu'on lui demande rien. C'est un renversement
explicite de la règle qui portait l'ancien document — « un bâtiment dont aucun slot n'a reçu
d'action ne rend rien » —, et il est nécessaire : cette règle n'existait que pour donner un
emploi aux cartes.

### Ce qui remplace le tempo

L'ancien jeu avait deux régulateurs qui se doublaient : la main de cartes disait *quoi*, le
pool d'ouvriers disait *combien*. Les deux disparaissent, et **un seul** les remplace.

> **Les travailleurs** disent ce que le village peut **posséder**. Un bâtiment en immobilise
> à l'ouverture de son chantier et les garde à vie *(cf. 3.4)*. Sans bras libres, on ne bâtit
> pas, quel que soit le bois qu'on ait.

Il **relie la construction à la population**, donc à la nourriture, donc au placement des
fermes : la boucle se referme sur elle-même sans qu'aucune règle n'ait à le dire. C'est le
seul régulateur du jeu, et il est spatial de bout en bout — les bras viennent des habitants,
les habitants d'un toit, le toit d'une case plate.

*Ce document a porté un second régulateur, une **file de chantiers** en nombre fixe, de
l'écriture du rescope jusqu'à `I3`.* Il est retiré, et l'argument est celui qui a fait couper
le reste : il **doublait** le premier au lieu de le croiser. Ce qu'un village peut mener de
front est déjà ce que ses bras autorisent, puisqu'un chantier les immobilise à son ouverture ;
un plafond de plus par-dessus posait la même question deux fois, et devenait la contrainte
réelle dès qu'elle mordait la première.

Son seul argument propre était l'arbitrage **réparer ou grandir** au lendemain d'une vague.
Il ne disparaît pas avec elle : réparer coûte des ressources et occupe le village, et la
vraie rareté d'un lendemain de vague est le bois et le temps, pas un jeton d'emplacement.

**Ce que ça change, et il faut l'écrire.** Un bâtiment gratuit en bras — l'habitation, la
palissade — n'est plus borné que par la ressource et par la place au sol. On peut en ouvrir
dix d'un coup si l'on a le bois et les cases. C'est cohérent avec le pitch, où la contrainte
est spatiale, et c'est un chiffre de `B1` s'il s'avère trop permissif.

### La durée d'un run

Un calendrier de vagues, comme aujourd'hui : une **liste explicite** de couples
(tour, vague) dans `data/balance/`, et une durée de run. Une liste dit une période en
l'écrivant, alors qu'une période ne sait exprimer ni un creux ni deux vagues rapprochées.

**`OUVERT`** — run fini ou mode sans fin. La question ne coûte rien à repousser : les deux
sont le même champ rempli différemment, et c'est exactement ce que la liste explicite a
acheté. On garde un calendrier fini pour l'instant, parce qu'il donne au run une forme.

---

## 3. Systèmes

Chaque système est développé et testé isolément. Le contrat est la seule chose que les
autres connaissent de lui. La règle de dépendance ne change pas : `adapters → domain →
contracts`, et un système du domaine ne voit jamais le contenu d'un état voisin.

### 3.1 Terrain

> **Contrat** — `TerrainQuery` : hauteur, type et constructibilité d'une cellule, planéité
> d'une zone, et depuis ce rescope **franchissabilité et coût de passage**, parce qu'une
> vague marche dessus.

Grille de cellules `Vector2i`, chacune portant une hauteur entière et un `TerrainData`.
Rendu en blocs étagés, une cellule = une colonne. Caméra orthographique qui pivote par
quarts de tour. **Rien de tout cela ne change** : `T1` à `T3` sont conservés entiers.

| Terrain | Constructible | Franchissable | Tag |
|---|---|---|---|
| Plaine | oui | oui | — |
| Forêt | oui, déblaie l'arbre | oui | `forest` |
| Gisement | oui | oui | `stone` |
| Filon | oui | oui | `ore` |
| Eau | non | non | `water` |
| Rocher | non | non | `blocker` |

**Le relief joue trois fois, et c'est nouveau.** Il décidait déjà où l'on peut bâtir — un
bâtiment exige toutes ses cellules à la même hauteur, règle universelle et non réglable.
Il décide maintenant aussi **par où l'on passe** — monter coûte, une marche trop haute
bloque, descendre ne coûte que le pas — et par conséquence il **fabrique les goulots** qui
sont le sujet du jeu.

C'est la réponse à l'`OUVERT` que l'ancien document gardait depuis le premier jour : « le
relief joue-t-il encore autrement ? ». Il n'y a plus rien d'ouvert là — le relief *est* la
carte de tower-defense.

#### La génération doit garantir une carte jouable

*(Entré au périmètre à la demande de l'humain, et c'est le changement le plus profond du
Terrain.)* La génération actuelle est du bruit de Perlin plus des seuils. Elle produit du
relief crédible et **ne garantit rien** : elle peut rendre une plaine sans goulot, un Cœur
sans plateau, ou trop d'accès pour qu'aucun ne compte. Tant que le relief n'était qu'une
contrainte de pose, ça n'avait pas d'importance. Maintenant que le placement défensif est
l'essence du jeu, une carte sans topographie est une partie sans jeu.

Elle devient donc un **producteur de topographie jouable**, avec des garanties nommées :

- un **replat constructible** d'au moins *N* cellules pour le Cœur et ses premiers voisins,
  trouvé **au plus près du centre** et non *sur* le centre ;
- un nombre **borné d'accès distincts** à ce plateau — deux à quatre, jamais un, jamais
  douze ;
- une **surface plate totale** minimale, sans quoi la boucle économique ne démarre pas ;
- des **gisements atteignables**, c'est-à-dire du côté constructible des accès.

**La méthode : du bruit, penché par des règles qui ne se voient pas, et un village qui
s'installe où le terrain le permet.** Et la génération **se vérifie elle-même** : elle compte
ses corridors d'approche par un parcours de grille, mesure sa surface plate, et **rejette le
seed** s'il ne tient pas ses promesses.

*`T4` a d'abord essayé l'inverse — poser la structure et décorer au bruit — sous la forme d'une
**mesa** : un plateau central surélevé, une plaine plus basse, des rampes taillées en marches
pour seules montées.* La méthode tenait toutes ses promesses **par construction**, ce qui était
son argument, et elle a été retirée entière parce qu'elle échouait sur ce qu'aucune promesse ne
mesure : on y lisait le générateur au lieu d'y lire un paysage. Une garantie structurelle ne
vaut rien si la carte qui la porte n'est pas une carte qu'on a envie de regarder.

Ce qui la remplace est le bruit d'avant, **penché** : un centre un peu plus haut, des crêtes
qui barrent parce qu'elles sont hautes et non parce qu'on les a posées là. Aucune de ces règles
n'a de bord — elles s'ajoutent au relief *avant* qu'il soit découpé en crans, donc aucune ne
laisse de trace qu'on puisse montrer du doigt.

**Et le village descend du centre.** C'est la décision qui rend le reste tenable : un bruit n'a
aucune raison de laisser une place à bâtir sur une case désignée d'avance, et sur des crêtes le
centre géométrique est le plus souvent un **pic**. On cherche donc le replat jouable le plus
proche du milieu, et ce qu'on borne est la **distance** entre les deux. C'est aussi la seule
des deux règles qu'un joueur puisse deviner en regardant la carte.

Le prix de ce renversement est que plus rien n'est garanti par construction : c'est l'audit qui
tient les promesses, seed après seed. Mesuré sur deux cents brouillons, **cent neuf sont
rejetés** — un accès unique le plus souvent, puis un village trop loin du milieu, puis un
plateau sans gisement — et il en coûte **2,15 essais** pour une carte, neuf au pire. Les deux
cents seeds rendent tous une carte.

**La franchissabilité entre en data au même jalon.** La colonne *Franchissable* du tableau
ci-dessus n'existait nulle part ailleurs que dans ce document ; elle est maintenant un champ
de `TerrainData`, à côté de la constructibilité et **distinct d'elle**. Les six terrains
répondent aujourd'hui la même chose aux deux questions, ce qui est précisément pourquoi il
fallait deux champs : une franchissabilité déduite se serait trompée en silence le jour d'un
marécage.

**`OUVERT`** — où vit la hauteur d'enjambée. Elle est dans `TerrainGenBalance` parce que la
génération en est le seul lecteur : c'est avec elle qu'elle compte ses accès. `V1`
donnera la sienne à une vague, et le jour où les deux doivent être le même chiffre, le champ
déménage. Inventer maintenant un bloc commun pour un consommateur qui n'existe pas est ce que
ce projet refuse depuis toujours.

L'aléatoire reste entier partout ailleurs : où sont les accès, comment le relief se plisse,
où tombent les gisements et les forêts, à quoi ressemble le pourtour.

Ce qui rend la chose mesurable, et c'est la discipline habituelle du projet : un harnais
génère deux cents seeds et imprime la distribution des accès, de la surface plate et de la
distance lisière → Cœur. Une carte injouable devient un chiffre plutôt qu'une surprise en
jeu.

`HeightGrid`, `CellPicker`, `TerrainMetrics` et tout le rendu ne bougent pas. C'est
`TerrainGen` qui est réécrit, et `TerrainGenBalance` qui gagne des champs.

**`OUVERT`** — l'occlusion par le relief. Toujours pas traitée, et le rescope l'aggrave :
« agréable à regarder » et « une colline cache mon village » ne cohabitent pas. La rotation
suffit peut-être ; sinon, un fondu par shader. À constater en capture avant d'y toucher.

### 3.2 Construction

> **Contrat** — reçoit `CityState` + `BuildingData` + cellule d'ancrage, rend un
> `PlacementResult` et mute l'état. Interroge le Terrain en lecture seule. Expose
> l'avancement des chantiers, que le `CitySnapshot` transporte.

**Conservé entier** : validation du placement, empreintes en liste de cellules relatives à
une ancre, quatre orientations par quarts de tour autour de l'ancre, chantiers, destruction,
`CitySnapshot` en deux lectures — tout, et les seuls achevés.

Ce qui change tient en trois points.

**Un chantier avance tout seul, pas par une carte.** L'action *Construire* n'existe plus ;
ce qui la remplace est le tour lui-même. Chaque tour, chaque chantier ouvert avance d'un
cran. Un bâtiment coûte donc autant de **tours** que sa colonne Chantier le dit — ce qui est
plus lisible que l'ancien modèle, où le même chiffre voulait dire « autant de cartes
*Construire* qu'il faudra piocher ».

**Un chantier paie tout à l'ouverture, ressources et travailleurs.** Il occupe ses cellules,
débite la réserve, et **immobilise les travailleurs du bâtiment à venir** *(cf. 3.4)*. Ces
gens-là bâtissent puis restent. Pendant ce temps ils ne produisent rien, ce qui est
exactement l'investissement de main-d'œuvre étalé qu'on veut : un bâtiment cher n'est pas
qu'un mur de ressources.

**Réparer est un chantier**, et c'est ce qui donne un prix à une vague passée. Un bâtiment
abîmé **fonctionne normalement** — ses points de vie sont ce qu'il encaisse, jamais ce qu'il
rend — mais il tombera plus vite à la vague suivante. Le remettre à neuf coûte une fraction
de son coût de construction et prend quelques tours. Il n'immobilise **aucun** travailleur de
plus : ce sont ceux du bâtiment qui le réparent, et une palissade qui n'en a aucun se répare
quand même.

#### Un seul régulateur, et il est spatial

C'est la réponse au trou que le rescope ouvrait — les cartes et les ouvriers réglaient le
tempo à eux deux, et ils disparaissent. Une seule chose les remplace :

| | dit | vient de |
|---|---|---|
| **Les travailleurs** | ce que le village peut **posséder** | la population, donc le logement, donc la terre |

Bâtir, terrasser et réparer puisent tous dans le même budget de bras, et ce budget se gagne
sur la carte. **Ouvrir un chantier, c'est immobiliser des gens** ; le nombre de chantiers
qu'on mène de front n'a donc pas besoin d'un second plafond pour être borné — il l'est déjà,
par le même chiffre.

*La file de chantiers, retirée à `I3`, est décrite en 2 avec la raison de sa disparition.*

**Ce qu'un chantier détruit rend** reste l'`OUVERT` de l'ancien document, et il devient un
peu plus pressant : une vague qui casse un chantier à moitié fait maintenant partie du jeu
plutôt que d'être une éventualité. Ses **travailleurs**, eux, reviennent au pool dans tous
les cas *(cf. 3.4)*. La réponse par défaut pour les ressources — rien — tient tant qu'elle
n'a pas été jouée.

#### Adjacence — et ce n'est plus une option

*(Promu par le rescope.)* C'était « la couche d'optimisation du jeu », un jalon confortable
qu'on pouvait repousser. Sans cartes et sans ouvriers, **c'est la moitié du jeu** : ce qui
rend un placement intéressant tient à deux choses, où l'on *peut* poser (le relief) et où il
*vaut mieux* poser (l'adjacence).

Chaque bâtiment porte des règles de la forme *« +X de rendement par voisin taggé Y dans un
rayon Z »*. Le système doit exposer un calcul de prévisualisation appelable pendant le
placement fantôme : **sans retour visuel en temps réel du delta, l'adjacence est invisible,
donc inexistante.** Cette phrase était déjà dans l'ancien document et elle n'a jamais été
aussi vraie.

*La forme est tranchée à `C3`, et elle l'a été devant une carte générée comme ce paragraphe
l'exigeait.* Une règle porte **cinq** choses : un tag de terrain, un rayon, une ressource, ce
que chaque case rapporte, et un **plafond**.

Le plafond est le cinquième nombre, et il n'est pas décoratif. `T4` rend des cartes couvertes
à 22 % de forêt **en bosquets** : un camp de bûcheron posé au milieu d'une futaie a ses huit
voisines boisées, donc sans plafond il rend `+2` de base et `+8` de bonus. Le placement cesse
alors d'être un choix pour devenir un gros lot, et le reste de la carte n'a plus d'intérêt. Ce
qu'on veut est qu'un bon emplacement **double** à peu près un bâtiment, pas qu'il le quintuple.

**Le rayon compte l'empreinte, pas seulement le pourtour.** Le mot « voisin » ci-dessus était
plus étroit que ce qu'on veut : bâtir une carrière **sur** le gisement doit être le bon geste,
c'est ce qu'un joueur essaie en premier et ce que tout jeu de bâtisseur lui a appris. Le terrain
n'est d'ailleurs pas consommé par la pose — la forêt reste sous la cabane —, donc rien ne s'y
oppose. La distance est en anneaux (Chebyshev) depuis la case la plus proche de l'empreinte, ce
qui fait qu'un rayon 1 est bien « la couronne autour du bâtiment, empreinte comprise ».

**Le terrain, et pas encore les bâtiments voisins.** La règle lit un tag de `data/terrain/`. Un
bâtiment n'a pas de tags aujourd'hui, et lui en donner sans qu'aucune règle les lise serait le
champ ajouté d'avance que ce projet refuse depuis `E1b`. C'est un mot de plus dans le schéma le
jour où une règle le veut.

| Bâtiment | Règle | Plafond |
|---|---|---|
| Camp de bûcheron | +1 bois par case `forest` à 1 | +2 |
| Carrière | +1 pierre par case `stone` à 1 | +2 |
| Mine | +1 minerai par case `stone` à 1 | +2 |
| Ferme | +2 nourriture par case `water` à 1 | +4 |

Le rendement de base n'est **pas** répété ici : il est dans la table de 4.1, et le recopier
serait deux chiffres à tenir d'accord. Les plafonds sont réglés pour à peu près doubler chaque
bâtiment — mais contre ce que `data/` verse aujourd'hui, pas contre 4.1 : *la ligne de la ferme
a dérivé*, le document annonce `+3 nourriture` et le `.tres` en verse 8. C'est la table de 4.1
qui a raison de se dire « chiffres de départ », et l'écart est noté ici plutôt que corrigé en
passant — retoucher un équilibrage au détour d'un jalon d'adjacence serait le changer sans
l'avoir mesuré.

La ferme est la seule dont le tag est **inconstructible**, et c'est ce qui la distingue : elle
ne peut jamais se poser *sur* ce qu'elle veut, seulement à côté. Elle est aussi la raison pour
laquelle `T4` a insisté sur les **vrais lacs** plutôt que sur des flaques d'une case — une
flaque qu'on ne contourne pas est aussi une flaque qui ne nourrit personne.

La carrière et la mine cherchent le **même** tag, ce qui est voulu : `DESIGN.md` 3.1 décrit un
Gisement et un Filon, et le second n'existe pas encore en data. Le jour où `ore` arrive, c'est
un mot à changer dans `mine.tres` — et rien d'autre nulle part.

**`OUVERT`** — le chiffrage lui-même. Ces quatre lignes sont des points de départ, pas des
cibles, au même titre que la table de 4.1. C'est `B1`.

### 3.3 Économie

> **Contrat** — `CitySnapshot` + `PopulationState` → `ProductionReport`. Ne connaît ni la
> grille ni les `Node` : tout lui est fourni.

*Ce contrat portait un `TerrainQuery` jusqu'à `I3`, et il l'a perdu là.* Le relief y était
parce que le jeu d'avant laissait jouer une carte **à cru** sur une case, auquel cas le tag
de cette case décidait du rendement ; ce geste n'existe plus. Un bâtiment rend son bloc, et
rien dans le résolveur ne pourrait aujourd'hui faire quoi que ce soit d'un relief — le
passer serait un champ ajouté d'avance, avec en prime une signature qui ment sur ce qu'elle
lit. **Le relief revient dans l'Économie à `C3`**, avec l'adjacence, qui est son premier
consommateur réel.

**Conservé** : le `Ledger` en **réserve commune** — les cent unités sont partagées entre
toutes les ressources, remplir de bois c'est renoncer à stocker de la pierre —, l'écrêtage
**proportionnel** à ce que le tour a produit, le catalogue de ressources en data avec son
rang d'affichage, la jauge segmentée qui rend la décision regardable.

**Quatre ressources** — nourriture, bois, pierre, minerai. Réserve commune 100, +100 par
entrepôt.

Ce qui change : **la production est passive**. Un bâtiment achevé et peuplé produit chaque
tour, sans qu'on lui demande rien. Comme ses travailleurs ont été payés à l'ouverture du
chantier et qu'ils y restent *(cf. 3.4)*, il est peuplé par construction — la question ne se
repose qu'après une famine ou un toit perdu, et la réponse est alors **tout ou rien** : un
bâtiment en sommeil ne rend rien.

**Tout ou rien, et pas au prorata.** Un bâtiment à moitié servi qui produirait à moitié est
un chiffre mou et une explication à donner. « Cette ferme dort, il me manque un toit » est
une phrase qu'un joueur comprend et corrige.

**`HORS MVP` — artisanat.** La réserve commune et le catalogue en data accueillent une
cinquième ressource sans refonte.

### 3.4 Population

> **Contrat** — `PopulationState` : combien d'habitants, combien sont immobilisés, combien
> de places de logement. C'est un **compteur**, jamais une liste.

C'est le système neuf du rescope, et il remplace à lui seul les deux régulateurs supprimés.

**La frontière à tenir, et elle porte tout le rescope** : la population est un **entier**.
Pas de noms, pas de pistes de compétence, pas d'XP, pas de traits, pas d'affectation
nominative, pas de panneau où l'on clique des fiches. Le jour où l'on se surprend à vouloir
savoir *lequel* des douze habitants fait quoi, on est en train de réécrire ce qu'on vient de
couper, et il faut s'arrêter.

#### Le travailleur est une ressource de construction

*(Corrigé par l'humain, et c'est le modèle qui a été retenu.)* Un bâtiment ne « demande pas
du personnel chaque tour » : il **coûte des travailleurs comme il coûte du bois**, à
l'ouverture du chantier, et il les garde à vie.

> Une ferme coûte 10 bois **et 4 travailleurs**. Les quatre quittent le pool disponible dès
> que le chantier s'ouvre, ils bâtissent, puis ils restent.

La différence avec le bois tient en un mot : le bois est **consommé**, le travailleur est
**immobilisé**. Il revient au pool si le bâtiment est démoli ou détruit.

Trois choses tombent de ce modèle, et c'est pourquoi il est meilleur que celui qu'il
remplace. Il n'y a **plus rien à réattribuer chaque tour** — un bâtiment bâti a ses gens,
point, donc la question « qui travaille où » ne se repose jamais. Le coût en main-d'œuvre
d'un bâtiment devient **une ligne de sa fiche**, lisible avant de le poser, exactement comme
son coût en bois. Et **un seul champ suffit** : ceux qui l'ont bâti sont ceux qui y vivent.

**Ce que ça préserve du jeu supprimé**, et il faut le dire parce que c'est le cœur du pitch
d'origine : « envoyer son meilleur récoltant en milice coûte deux fois » devient **« une
baliste coûte deux bûcherons »**. La tension entre produire et défendre survit à la coupe,
en pure arithmétique, sans un seul clic d'affectation.

**`OUVERT` — plusieurs classes de travailleurs**, à la *Anno*. Le modèle y mène naturellement
— un coût en travailleurs devient un coût par classe —, et rien n'est écrit qui l'empêche.
Ce n'est pas au périmètre : une seule classe d'abord, et on verra si le jeu la réclame.

#### La boucle

```
   nourriture ──►  population  ──►  travailleurs disponibles  ──►  bâtiments
        ▲               ▲                                              │
        │               │                                              │
        │               └───────  places de logement  ◄────────────────┤
        │                                                              │
        └──────────────────────────────────────────────────────────────┘
```

Chaque tour :

- **tout le monde mange** — une nourriture par tête, immobilisés compris ;
- la population **croît** d'un cran s'il reste de la nourriture après le repas *et* qu'il
  reste une place de logement ;
- elle **décroît** d'un cran si la réserve n'a pas couvert le repas.

Trois quantités, et deux invariants qui ne se violent jamais :

| | |
|---|---|
| `population` | l'effectif total |
| `immobilisés` | la somme des travailleurs retenus par les chantiers et les bâtiments |
| `disponibles` | `population − immobilisés` |

```
    population ≤ places de logement
    immobilisés ≤ population
```

#### Le frein est spatial, et c'est un choix

Une boucle où plus d'habitants produisent plus de nourriture qui nourrit plus d'habitants
s'emballe si rien ne la borne. Le frein retenu est **le logement et la terre**, jamais un
upkeep qui grossirait : un chiffre non linéaire est invisible, donc il se ressent comme
arbitraire, alors qu'un plateau plein **est sur la carte, sous les yeux du joueur**.

Une habitation occupe une case qu'une ferme n'aura pas. C'est tout le frein, et il est du
même métal que le jeu.

L'upkeep reste donc bête : **une nourriture par habitant et par tour**. Le champ existe déjà.

#### L'habitation ne coûte aucun travailleur, et ce n'est pas un oubli

C'est une **contrainte de structure et non un réglage**, et elle mérite d'être écrite parce
que l'ignorer produit une partie bloquée.

Si tous les travailleurs sont immobilisés et que le logement est plein, plus rien ne peut
être bâti — il faudrait des travailleurs libres, et il n'y en aura plus jamais. Le village
est mort debout. **L'habitation à zéro travailleur est la soupape** : tant qu'il reste du
bois et une case plate, on peut toujours relever le plafond, donc faire venir du monde, donc
repartir.

La démolition est la seconde soupape, et elle existe déjà : elle rend ses travailleurs.

#### Quand la population baisse, le dernier bâti s'éteint le premier

*(Question posée par l'humain, et elle est la bonne : quand une habitation tombe, qui perd
ses gens ?)*

Deux réponses étaient possibles. **Suivre** qui loge où et qui travaille où — précis, et
c'est de la comptabilité qui réintroduit l'individu par la porte de derrière. Ou une **règle
d'ordre** sans aucun suivi, et c'est celle-ci :

> Quand l'effectif doit baisser et qu'aucun travailleur n'est disponible, **le bâtiment bâti
> le plus récemment passe en sommeil** et rend ses travailleurs. On répète tant qu'il le
> faut.

C'est la **symétrie exacte** de la règle qui gouverne déjà le reste : l'ordre de construction
est la priorité que le joueur a exprimée, donc on démonte par le bout le moins prioritaire.
Une seule règle à apprendre, aucun état à tenir, et surtout un comportement **prévisible** —
le joueur sait d'avance que sa dernière construction est la plus fragile.

Elle se déclenche dans exactement deux cas :

- **la famine** — la réserve n'a pas nourri tout le monde ;
- **une habitation détruite** — le plafond passe sous l'effectif, et le surplus s'en va.

Un bâtiment **en sommeil** reste debout, occupe ses cases, encaisse les coups et ne produit
rien. Il se **repeuple tout seul** dès qu'il y a assez de travailleurs disponibles, dans
l'ordre de construction. C'est une réparation automatique et non un geste : il n'y a rien à
décider, seulement à laisser revenir.

**Un bâtiment de production détruit rend ses travailleurs au pool.** Ils ne meurent pas avec
lui — ils y avaient un emploi, pas un tombeau. Sans cette règle, une vague qui casse trois
fermes coûterait la production *et* douze habitants *et* la capacité de reconstruire, ce qui
est une cascade que le joueur ne peut plus rattraper. Seules la famine et la perte d'un toit
tuent.

#### Une soupape se joue, elle ne se déclare pas — y compris pour ce qui la garde

*(Trouvé à `I3`, en jouant l'interdit ci-dessus dans un vrai tour.)* Le contrôle du boot
vérifiait qu'un bâtiment gratuit en bras **existe**, pas qu'on puisse le **bâtir**. Le Cœur
le satisfaisait à lui seul — il loge quatre personnes et ne coûte aucun bras —, alors qu'il
est posé une fois à la fondation et jamais reconstruit : la soupape qu'il semblait offrir ne
s'ouvre jamais. Le garde-fou aurait donc laissé passer un catalogue où l'habitation coûte des
bras, c'est-à-dire exactement la partie mortellement bloquée qu'il existe pour interdire.

C'est la règle de cette section retournée contre ce qui la protège, et il a fallu un tour
jouable pour que la différence se voie.

*Une seconde forme de blocage a existé entre l'écriture du rescope et `I3` : des chantiers
endormis gardaient à jamais leurs places dans la file de 3.2, y compris contre l'habitation
qui aurait tout débloqué. Elle disparaît avec la file.*

**`OUVERT`** — pouvoir réordonner les priorités, donc décider qui s'éteint. C'est le bout
pointu de l'affectation, donc c'est refusé pour l'instant. Si le manque se fait sentir en
jouant, c'est un glisser-déposer sur une liste, et rien d'autre.

**`OUVERT`** — le recrutement au-delà de la croissance passive. Un événement, une caravane,
un bâtiment qui attire. À voir quand la boucle tourne.

#### Où vit ce système

**Dans `domain/economy/`**, et non dans un dossier à lui. Sa boucle est entièrement
économique — elle mange, elle est nourrie, elle plafonne —, elle se dépense comme une
ressource, et le seul chiffre qui en sort vers un autre système est le nombre de
travailleurs disponibles, que l'orchestrateur lit pour savoir si un chantier peut s'ouvrir.
Inventer un dossier et un contrat pour trois entiers serait la frontière que ce projet
refuse depuis toujours : on ne crée pas une frontière que personne ne franchit.

### 3.5 Vagues — le tower-defense

> **Contrat** — `CitySnapshot` + `TerrainQuery` + `WaveDef` → `BattleReport`. C'est **le
> seul** contrat qui compte. Tout ce qui se passe entre les deux est remplaçable.

**Le joueur ne joue pas pendant une vague.** Il l'a jouée avant, en construisant. Une vague
se regarde, se met en pause, s'accélère et se passe — jamais ne se pilote. C'est ce qui
distingue ce format du combat tactique supprimé, et c'est ce qui le rend équilibrable par
quelqu'un qui n'a jamais équilibré de jeu.

#### Ce qu'une vague fait

Elle entre **à la lisière du bâti**, par une direction **annoncée à l'avance**. La direction
n'est pas du confort : on pose un bâtiment en pensant à la bataille, et une direction révélée
au dernier moment transformerait cette prévoyance en loterie. La **date** est annoncée par le
même argument, et le calendrier de 2 la connaît déjà.

Elle cherche ensuite le **chemin le moins coûteux vers le Cœur**. Coûtent : la distance, la
montée. Barrent : l'eau, le rocher, une marche trop haute, et **tout bâtiment**.

**Elle casse ce qui la barre quand le détour est trop long.** C'est la règle qui empêche le
labyrinthe : boucher cesse d'être une astuce pour devenir un troc — *je te barre, tu me manges
le mur*. Le seuil au-delà duquel elle préfère casser est un champ de `data/`.

> **Le mécanisme entre dès le premier jour, le seuil se règle au ressenti.** Un champ de
> data se tourne ; un chemin de code absent ne se tourne pas, et un joueur qui boucle tout
> serait invulnérable sans qu'on le découvre avant d'avoir bâti le jeu par-dessus.

Elle **ignore ce qui ne la barre pas**. Elle ne se détourne pas pour manger une ferme. C'est
ce qui fait du chemin toute l'histoire, et ça crée l'arbitrage que l'on veut sur une tour :
**sur le chemin**, elle barre et se bat, mais elle meurt ; **à côté**, elle survit, mais il
lui faut de la portée.

Elle s'arrête quand elle est morte — le village a tenu — ou quand elle atteint le Cœur.

#### Ce que la vague mesure

> Le chemin de la lisière au Cœur est-il assez **long** et assez **couvert** pour que les
> défenses tuent la vague avant qu'elle arrive ?

Les deux moitiés sont spatiales, et c'est le sujet du jeu. **Long** : ce qui barre allonge
le détour, le relief gratuitement et la palissade contre du bois et une case. **Couvert** :
une tour ne sert que si le chemin passe à sa portée, donc la poser est un pari sur un trajet.

Et la topographie remplace le labyrinthe : le joueur ne dessine pas le chemin, il le
**reçoit** du relief. Sa décision n'est pas « comment je serpente » mais **« quel col je
tiens, et à quel prix en cases de production »**.

#### Le Cœur encaisse

Une vague qui atteint le Cœur lui inflige ses dégâts et se dissout. Le Cœur a des points de
vie, et **le run est perdu quand ils tombent à zéro**.

Ce n'est pas tout ou rien : une vague à moitié arrêtée coûte la moitié. C'est ce qui donne
au run une jauge de santé lisible d'un bout à l'autre, et ce qui rend une mauvaise vague
survivable mais coûteuse.

**Le Cœur se répare comme le reste** *(tranché avec l'humain)*, par un chantier, contre des
ressources et des tours *(cf. 3.2)*. La règle est donc universelle — tout ce qui tient debout
s'abîme et se remet à neuf — et le run n'a pas d'horloge dure : ce qu'une vague coûte est un
retard de reconstruction plutôt qu'une dette définitive.

#### Ce qu'une vague laisse derrière elle

Trois règles, et elles décident ensemble de la brutalité du jeu.

**Un bâtiment abîmé travaille normalement.** Ses points de vie sont ce qu'il encaisse, jamais
ce qu'il rend. Sans cette règle il faudrait un second chiffre — un rendement dégradé — et une
explication à donner ; avec elle, l'état d'un bâtiment se lit sur une seule jauge.

**Un bâtiment détruit rend ses travailleurs au pool** *(cf. 3.4)*. Ils y avaient un emploi,
pas un tombeau. La perte est le bâtiment — le bois, les tours de chantier, la production
manquée — et c'est assez.

**Seules l'habitation détruite et la famine tuent.** Perdre un toit fait partir ceux qu'il
logeait ; c'est ce qui fait du logement une cible qu'on protège, et c'est la seule cascade
que le jeu s'autorise.

#### Le pas de simulation

*(La question a été posée par l'humain, et elle est la bonne.)* « Tour par tour » et
« continu à l'écran » ne s'opposent pas : ce qui les sépare est la **finesse du pas**.

- **Un tour de jeu** est un pas grossier. Rien ne se passe entre deux tours ; l'animation qui
  les sépare est purement décorative.
- **Une bataille** est un pas fin. Le domaine avance par **ticks**, et à chaque tick :

```
  · chaque corps avance de sa vitesse le long de son chemin
  · chaque défense décrémente son cooldown ; à zéro, elle tire → un projectile naît
  · chaque projectile avance ; à l'arrivée, il inflige ses dégâts
  · ce qui tombe à zéro meurt
```

`CombatBoard.tick()` reste une **fonction pure**, en entiers, donc déterministe et testable.
Mais à quelques dizaines de pas par seconde, l'écran interpole entre deux états consécutifs
et l'on obtient du mouvement continu, des projectiles qui voyagent et une cadence qui se
ressent. C'est le patron *pas fixe + rendu interpolé*, celui de tous les jeux déterministes
qui bougent, et il ne coûte rien ici parce que le domaine est déjà pur.

**Aucun flottant dans le domaine.** Un corps est *sur la case X, avec un compteur de
progression vers la suivante*. La grille reste la source de vérité — c'est elle que le
chemin, le blocage et la portée interrogent — et la fraction n'est qu'une indication de
rendu. Même traitement pour un projectile : origine, cible, compteur.

**Ce que ce choix donne gratuitement**, et c'est pourquoi il est retenu :

- **pause et vitesse ×2** — consommer plus ou moins de ticks par seconde ; le résultat ne
  change pas d'un point de vie ;
- **passer la bataille** — boucler les ticks sans rien dessiner ;
- **mesurer une bataille sans écran** — `while not board.finished(): board.tick()`, donc une
  chronique de batailles comme le projet en fait déjà pour les runs.

**Et la fin de tour reste atomique.** Une bataille n'attend **jamais** une entrée du joueur,
donc il n'y a ni état « en attente », ni seconde porte, ni bataille à reprendre. C'était la
seule chose qui rendait nécessaire la coupure que l'ancien jeu avait dû écrire, et elle se
défait.

#### Le joueur ne joue pas pendant qu'une animation joue

*(Posé à `I3b`, sur la course du soleil, et valable pour tout ce qui viendra.)* « Purement
décorative » ne veut pas dire « sans conséquence ». Un geste posé pendant qu'une transition
se joue arrive dans un état que le joueur **ne regarde pas encore** : il pose un bâtiment sur
une ville qu'il n'a pas vue, et découvre les deux ensemble. Rien ne casse — le domaine répond
correctement — mais l'écran a menti par omission.

Une transition est donc **le moment où le plateau parle et où le joueur se tait**. Elle
interdit d'agir, jamais de regarder : la caméra continue de tourner et de zoomer, parce que
regarder est précisément ce qu'on demande.

**Et c'est un verrou d'adapter, jamais un état du domaine.** Y remettre une attente parce
qu'une animation dure trois secondes rouvrirait la coupure que le paragraphe ci-dessus vient
de refermer, et pour une raison encore plus faible. Le domaine ignore qu'un écran existe ;
c'est l'écran qui sait quand il n'a pas fini de parler.

Il y a **un seul** verrou, et les animations s'y déclarent au lieu d'inventer le leur : deux
verrous à tenir d'accord finissent par diverger, et celui qu'on oublie laisse passer les
gestes en silence. La bataille de `V3` prendra le même.

#### Le vocabulaire de défense, et il est volontairement minuscule

Un bâtiment de défense porte **quatre chiffres** :

| | |
|---|---|
| **portée** | en cases, distance Manhattan sur la grille |
| **dégâts** | par tir |
| **cadence** | ticks entre deux tirs |
| **points de vie** | ce qu'il encaisse quand la vague le casse |

Il n'y a **pas** de types de dégâts, pas d'armure, pas de ralentissement, pas de zone, pas
de priorité de ciblage réglable. La cible est l'ennemi à portée le plus avancé sur son
chemin, une ligne de code, la même pour tous.

**Un projectile dont la cible meurt en vol est perdu.** Ça punit le surkill, ça rend la
cadence lisible, et c'est une règle de moins.

Un assaillant porte **quatre chiffres** : points de vie, vitesse (ticks par case), dégâts
au bâti, et seuil de patience. Une `WaveDef` dit qui vient, en combien d'exemplaires, et par
où.

*Soit une vingtaine de nombres au total, contre les quatre-vingts d'un tower-defense
complet. C'est la seule raison pour laquelle ce format est retenu plutôt qu'un autre.*

**`OUVERT`** — tous les chiffres ci-dessus, et la composition des vagues. Ils se règlent
devant une partie, pas dans ce document.

### 3.6 Événements — `HORS MVP`

Une source d'aléatoire indépendante du terrain : arrivée d'habitants, tempête qui abîme une
défense, filon révélé, disette, caravane. Rien n'en est écrit tant que la boucle n'est pas
jouable. Ce que ça contraint aujourd'hui : la séquence de résolution de 2 doit pouvoir
accueillir une étape de plus sans se réécrire.

### 3.7 Cycle de tour

> Le seul système qui connaît tous les autres. C'est volontaire : il orchestre, les autres
> s'ignorent.

Il tient l'**état du run** — relief, ville, réserve, population, chantiers, calendrier — et
l'**orchestrateur**, qui ne calcule rien : il enchaîne des questions là où chaque système
n'en répond qu'à une, et applique des ordres que les résolveurs se contentent de rendre.

Il rétrécit beaucoup. Il orchestrait cinq systèmes, il en orchestre trois ; il connaissait
deux sortes de résolution, il n'en connaît qu'une ; la machine à phases disparaît avec les
phases.

**Le déterminisme ne bouge pas** : un seed plus une suite de gestes rejoue un run à
l'identique, batailles comprises — un tick est un pas discret, et le nombre de ticks est ce
qui compte, jamais l'horloge murale. C'est vérifié par un cas de test, comme aujourd'hui.

---

## 4. Contenu de départ

### 4.1 Bâtiments

Chiffres de départ, pas des cibles. **Chantier** = nombre de tours pour l'achever.
**Trav.** = travailleurs immobilisés à l'ouverture du chantier, et gardés à vie.
**Loge** = places de logement ajoutées.

| Bâtiment | Coût | Chantier | Production | Trav. | Loge | PV | Portée | Dégâts | Cadence |
|---|---|---|---|---|---|---|---|---|---|
| Cœur | posé au départ | — | — | 0 | 4 | 40 | — | — | — |
| Camp de bûcheron | 0 | 1 | +2 bois | 2 | 0 | 6 | — | — | — |
| Ferme | 10 bois | 2 | +3 nourriture | 4 | 0 | 6 | — | — | — |
| Carrière | 15 bois | 2 | +2 pierre | 3 | 0 | 8 | — | — | — |
| Mine | 25 bois, 10 pierre | 3 | +2 minerai | 4 | 0 | 10 | — | — | — |
| **Habitation** | 20 bois | 2 | — | **0** | 4 | 6 | — | — | — |
| Entrepôt | 20 bois | 2 | +100 de réserve | 1 | 0 | 8 | — | — | — |
| Palissade | 5 bois | 1 | — | 0 | 0 | 8 | — | — | — |
| Tour de guet | 15 bois, 10 pierre | 3 | — | 1 | 0 | 12 | 4 | 3 | 20 |
| Baliste | 30 bois, 20 pierre | 4 | — | 2 | 0 | 14 | 7 | 6 | 45 |

Quatre remarques sur cette table.

**Tous les bâtiments ont des points de vie et se réparent.** Il n'y a aucune exception, pas
même le Cœur : ce qui tient debout peut être abîmé et remis à neuf. Un bâtiment abîmé
travaille normalement — les points de vie sont son encaisse, jamais son rendement — et la
réparation est un chantier *(cf. 3.2)*.

**L'habitation est le seul zéro obligatoire de la colonne Trav.** Ce n'est pas un
équilibrage, c'est la soupape qui empêche une partie de se bloquer *(cf. 3.4)*. Tous les
autres chiffres de cette colonne se règlent librement.

**La palissade perd sa `defense` et garde ses points de vie.** Elle ne « défend » plus par un
chiffre abstrait, parce qu'il n'y a plus de total de défense à opposer à une puissance : elle
**barre**, et elle encaisse. C'est le seul bâtiment dont c'est le seul métier, et son
empreinte en L reste la seule forme non rectangulaire du projet — donc le seul cas qui
exerce vraiment la rotation et le validateur.

**La baliste est neuve**, et elle existe pour une raison de design : avec un seul bâtiment
qui tire, « où poser ma tour » n'a qu'une réponse. Deux portées et deux cadences donnent un
vrai choix — la tour couvre un col de près et vite, la baliste tient un axe de loin et
lentement.

**Les noms de la première colonne sont dans `data/` depuis `N2`**, et c'est le seul endroit de
ce document dont le contenu ait été recopié dans un `.tres`. Ils n'y étaient pas, si bien
qu'un écran qui nommait un bâtiment affichait son identifiant interne — `lumberjack_hut` sur
la fiche que 3.4 réclame « lisible avant de poser ». Même partage que pour les ressources
depuis `E2` : un identifiant sert le code, un libellé sert l'écran.

**Quatre bâtiments ont disparu** : caserne, marché, atelier, camp d'exploration. Ils
existaient tous les quatre pour débloquer une carte ou ouvrir des places de déploiement,
c'est-à-dire pour des systèmes supprimés. La colonne **Débloque**, jamais entrée en data,
n'entrera pas.

**Aucun `@export` de `src/schema/` ne porte de valeur par défaut**, et chaque `Resource`
d'équilibrage expose `missing_fields()`. La doctrine du zéro est conservée telle quelle : un
champ non renseigné vaut `0`, ce qui est détectable, et `GameDatabase` refuse de démarrer
dessus.

### 4.2 Gestes du joueur

Il n'y a plus de cartes, donc plus de verbes. Un tour offre :

| Geste | Coût | Note |
|---|---|---|
| **Bâtir** | ressources + travailleurs, à l'ouverture | les bras sont rendus à la démolition |
| **Réparer** | une fraction du coût de construction | aucun travailleur de plus |
| **Terrasser** | un coût en ressources | monte ou descend d'un cran |
| **Démolir** | rien, et ne rend aucune ressource | libère les cellules **et les travailleurs** |
| **Passer le tour** | — | le seul geste obligatoire |

Les trois premiers puisent dans le même budget de **bras** *(cf. 3.2)*. C'est tout le tempo
du jeu, et il tient dans la colonne des coûts de ce tableau.

**Le Cœur n'est dans aucune de ces lignes.** Il se **fonde** — c'est l'étape de 2, avant le
premier tour —, et il ne se bâtit ni ne se démolit ensuite. Les deux refus sont la même
phrase : le porter dans *Bâtir* en ferait le meilleur bâtiment du jeu à répétition, gratuit,
sans chantier et logeant quatre personnes ; le porter dans *Démolir* donnerait un bouton
« perdre la partie » sans confirmation, puisque 5 fait du Cœur détruit une défaite.

**Le terrassement redevient central, et il redevient jouable.** Il avait été retiré du deck
parce que son sens — monter ou descendre — ne s'affichait nulle part sur une carte à jouer.
Le problème disparaît avec les cartes : c'est un chantier comme un autre, il s'ouvre en
désignant une case et un sens, et le chantier lui-même montre lequel.

Il ne se joue que sur un terrain **constructible** : terrasser déplace la hauteur, pas le
`TerrainData`, donc monter une case d'eau la laisserait eau. Deux bornes de relief dans
`data/balance/`, distinctes de celles de la génération — celles-là décrivent la carte qu'on
reçoit, celles-ci jusqu'où on a le droit de la pousser.

---

## 5. Fin de run

- **Défaite** — Cœur détruit, ou population à zéro
- **Victoire** — dernière vague survécue
- **Score** — ressources, bâtiments intacts, population, points de vie restants du Cœur

Un run se termine sur un **écran**, victoire ou défaite, avec le score et ses termes, et de
quoi relancer sur le seed suivant. C'est écrit et livré ; il n'y a qu'à retailler ce qu'il
affiche.

Un bâtiment intact est un bâtiment **achevé** : un chantier laissé en plan ne compte pas.
Les poids du score vivent dans `data/balance/`, et au moins un doit compter.

---

## 6. Autour du run

### 6.1 Méta-progression — *après le MVP*

Déblocage de bâtiments, biomes aux paramètres de génération distincts, modificateurs de
difficulté cumulatifs. Les gouverneurs de départ, qui modifiaient un deck, n'ont plus d'objet
sous cette forme : ils deviendraient un village de départ ou un bonus de génération.

### 6.2 Le menu

Le jeu **est** un run, ouvert par un harnais de dev. Il faut une coquille — écran titre,
lancer un run, y revenir quand il est fini. C'est le premier morceau qui vive hors d'un run,
c'est une `.tscn` sous `scenes/ui/`, et c'est la scène principale de `project.godot` : deux
fichiers que **l'humain seul écrit**.

### 6.3 `OUVERT` — la sauvegarde

Inchangé, et le rescope la rend moins urgente : un run sans phases et sans affectation
nominative se joue nettement plus vite. La question reste adossée à la même mesure, la
durée réelle d'une partie jouée à la main.

---

## 7. Hors périmètre

- Citoyens simulés individuellement — la population est un nombre, pas des agents qui marchent
- Routes, logistique, transport de ressources
- Ponts, tunnels, superposition verticale — le relief reste une hauteur par cellule
- Un roster nommé, des compétences, de l'expérience — **supprimé par ce rescope**, voir 9
- Un combat que le joueur pilote — **supprimé par ce rescope**, voir 9
- Des cartes, une main, un deck — **supprimé par ce rescope**, voir 9
- Son, art final, animations

Toute demande d'ajout passe d'abord par une mise à jour de ce document.

---

## 8. Jalons

Le développement reste par système. Les familles de lettres sont conservées là où le système
survit, ce qui garde le journal lisible ; `R` et `N` sont neuves.

### `R` — le rescope

- **R0** — **La démolition.** Supprimer `domain/combat/`, `domain/workforce/`, `domain/deck/`
  et leurs adapters, tests, schémas, `.tres` et harnais. Retirer les contrats devenus vides.
  Réduire `run/` à ce qui compile. **Rien n'est ajouté dans ce jalon** : il est fini quand le
  boot est propre, tout `src/domain/` parse, et la suite restante est verte.
  *On supprime des dossiers entiers, jamais des lignes : c'est ce qui empêche un reste de
  traîner, et GDScript dénonce immédiatement toute référence pendante.*

### `N` — la population

- **N1** — **Le compteur et sa boucle.** Population, immobilisés, disponibles, plafond de
  logement, repas, croissance, décroissance. Le travailleur comme **coût de construction**
  payé à l'ouverture d'un chantier et rendu à la démolition. La règle du **dernier bâti qui
  s'éteint le premier**, l'état de sommeil, et le repeuplement automatique. Domaine et tests,
  aucun `Node`. `EconomyBalance` et `BuildingData` gagnent leurs champs.
  *Le cas de test qui porte le jalon est l'interdit de blocage : une partie où tout le monde
  est immobilisé et le logement plein doit rester jouable, parce que l'habitation ne coûte
  personne.*
- **N2** — **Ce qu'on en voit.** La population dans le HUD à côté de la réserve : effectif,
  immobilisés, disponibles, places restantes, et lesquels des bâtiments dorment. La
  `ResourceBar` et la `CommodityPalette` existent et servent telles quelles. Le coût en
  travailleurs s'affiche sur la fiche d'un bâtiment **avant** qu'on le pose, comme son coût
  en bois.

### `I` — l'intégration

- **I3** — **Le tour.** `RunState` et `RunOrchestrator` réécrits sans phases, sans deck,
  sans roster. Un tour se joue : ouvrir des chantiers, passer, voir la résolution. Le
  harnais Run refait autour de ce seul geste. *C'est le jalon qui rend le jeu jouable à
  nouveau, et il doit venir tôt.*

### `T` — le terrain

- **T4** — **La génération garantie.** `TerrainGen` réécrit en producteur de topographie :
  relief bruité et penché, village trouvé au plus près du centre, accès comptés, surface plate
  minimale, vérification par parcours, rejet du seed. Le harnais mesure deux cents seeds et
  imprime la distribution.
- **T5** — **L'occlusion**, si une capture montre que c'en est une.

### `C` — la construction

- **C5** — **Le terrassement comme chantier.** Le verbe revient, avec son sens montré.
- **C6** — **La réparation.** Un bâtiment abîmé, un chantier qui le remet à neuf, et le bois
  qui fait choisir entre réparer et grandir. Il vient **après `V4`** : réparer n'a aucun sens
  tant que rien n'abîme.
- **C3** — **L'adjacence**, et sa prévisualisation du delta au survol. Promu au rang de
  jalon central par le rescope.

### `V` — les vagues

- **V1** — **Le chemin.** Recherche du plus court chemin vers le Cœur avec coûts de relief,
  ce qui barre, le seuil de patience et le choix casser/contourner. Domaine pur et tests,
  aucune vue, aucun tick. *Un chemin se vérifie sur une grille fabriquée à la main.*
- **V2** — **La bataille en ticks.** Corps, défenses, cadence, projectiles, dégâts, morts.
  `tick()`, `finished()`, `run_to_end()`, `BattleReport`. Domaine et tests. Un harnais qui
  résout une bataille sans écran et imprime ce qui s'est passé.
- **V3** — **La bataille à l'écran.** Interpolation entre deux ticks, projectiles dessinés,
  pause, vitesse, passer. C'est un jalon d'adapter, et le premier du projet où le *game feel*
  est le livrable.
- **V4** — **L'intégration.** La vague tombe à sa date dans la résolution du tour, la
  direction et la date s'annoncent à l'avance, le Cœur encaisse, le run se perd.

### `M` — autour du run

- **M1** — **Le menu.** Une `.tscn` et la scène principale : **l'humain seul les écrit.**
- **M2** — **La persistance**, dont la forme reste l'`OUVERT` de 6.3.

### `B` — l'équilibrage

- **B1** — **La passe de chiffres.** Elle vient après `V4`, jamais avant : on n'équilibre pas
  une boucle dont il manque un morceau. Elle a déjà ses fronts nommés — la nourriture, le
  frein de la population, la dureté des vagues, le coût des défenses.

### Ordre

```
R0 ──► N1 ──► I3 ──► N2 ──► T4 ──► V1 ──► V2 ──► V3 ──► V4 ──► C6 ──► B1
                │            │                            │
                │            │                            └── la vague abîme,
                │            │                                donc réparer a un sens
                │            └── les cols existent, donc un chemin veut dire quelque chose
                └── le jeu se relance et se mesure à nouveau
```

**Quatre raisons à cet ordre.** `I3` vient tôt parce qu'un projet qui ne se lance pas est un
projet dont on ne mesure plus rien. `T4` vient avant `V1` parce qu'on ne teste pas un pathing
sur des cartes qui n'ont pas de cols. `V1` est séparé de `V2` parce que le chemin se vérifie
sur une grille fabriquée à la main, alors que la bataille demande le chemin — c'est la
découpe qui a marché pour `F2a`/`F2b`, et pour la même raison : ce qui décide vient après ce
qui bouge. Et `C6` vient après `V4` parce que **réparer n'a aucun sens tant que rien
n'abîme** : l'écrire avant produirait un geste que rien n'appelle, donc un geste qu'aucune
partie ne mesure.

`C3` et `C5` peuvent s'intercaler à tout moment après `I3`.

---

## 9. Ce que le rescope supprime, et pourquoi

Cette section existe pour que le document ne mente pas sur son passé. Chacun des trois
systèmes ci-dessous était **écrit, testé et jouable**. Aucun n'est supprimé parce qu'il était
raté.

### Le combat tactique

`F1`, `F2a`, `F2b`, `F3a` — un plateau, deux verbes, le relief dans le déplacement, des
intentions annoncées, une IA de vague, une vue jouable à la souris. Environ 2 200 lignes de
domaine et d'adapters, 1 800 de tests.

**Il est supprimé parce que c'est un second jeu.** Le document qui le décrivait le disait
lui-même : sans blessure, un combat n'a que deux issues, *rien* ou *définitif*, et le joueur
qui a bien joué ne sent rien du tout. Le format retenu **exigeait** deux systèmes différés —
les capacités et les états — rien que pour ne pas être plat. C'était un chantier de plusieurs
jalons avant d'être bon, greffé sur un jeu qui n'en avait pas besoin.

Ce qui le remplace fait la même chose en mieux pour ce jeu-ci : la défense **découle** du
placement au lieu de s'y ajouter.

**Ce qui en survit, et ce n'est pas rien** : l'idée qu'un plateau est un état mutable
manipulé par des fonctions pures, le relief comme coût de déplacement, et la borne
d'affrontement comme régulateur de rythme. La vague de 3.5 en hérite directement.

### La gestion des effectifs

`W1`, `W2` — un roster nommé, deux axes de progression, des pistes de compétence par famille,
un panneau d'affectation, un conseiller d'auto-affectation. Environ 1 550 lignes plus 720 de
tests.

**Il est supprimé parce que sa décision était soit évidente, soit pénible.** Le risque était
identifié dès le premier jour du projet — « plusieurs centaines de décisions par run dont la
plupart sont évidentes » — et il s'est réalisé exactement comme annoncé : il a fallu mettre
le bouton d'auto-affectation **dans le domaine**, puis quatre jalons de confort pour rendre
quinze journées supportables. Le document l'admettait en toutes lettres : le bouton ne
choisit « que *qui*, et c'est précisément la moitié évidente de la décision ».

La population de 3.4 garde ce que la mécanique apportait vraiment — un budget qui se gagne,
se nourrit et se perd — et jette ce qui coûtait : l'identité, le clic, et l'arbitrage entre
six personnes interchangeables.

**Ce qui en survit** : la boucle « ça mange, donc ça contraint », et l'argument de l'ordre de
construction comme priorité déjà exprimée.

### Le deckbuilding

`D1`, `D2` — trois pools, une main, un draft, un mélange déterministe, un ciblage, un plateau
d'actions. Environ 1 900 lignes plus 1 290 de tests.

**Il est supprimé parce qu'il n'a jamais trouvé sa place.** Il jouait le rôle de *ce qu'on
peut faire* pendant que les ouvriers jouaient *combien* — deux contraintes qui devaient se
croiser et qui, dans les faits, se doublaient : chaque action consommant une carte et un
ouvrier, la contrainte réelle était le minimum des deux. Le document l'avait vu et avait
dédoublé le geste pour y échapper ; ça a marché, au prix d'un geste de plus par action.

Et le pool des powers est resté vide du premier jour au dernier, ce qui est le signe le plus
net qu'un tiers du système attendait une raison d'être.

**Ce qui en survit** : la structure de tour, la notion de coût payé à la pose, et le refus de
donner au joueur une information qui répondrait à sa place — le recensement des piles sans
leur ordre était une bonne règle et elle a laissé une trace dans la doctrine.

### Ce que le rescope ne touche pas

Le Terrain, la Construction, l'Économie, les autoloads, les harnais, les captures, le
déterminisme, la doctrine du zéro, la règle de dépendance, et les trois commandes de
vérification. C'est-à-dire tout ce qui a été le plus dur à écrire et le plus long à
apprendre.

Et `CLAUDE.md` et `JOURNAL.md` ne perdent **pas une ligne**. Les pièges de mise en page, les
pièges de Godot 4.7.2, la discipline des harnais et des tables, les règles sur ce qu'une
mesure mesure vraiment — rien de tout ça n'appartenait aux systèmes supprimés. C'est le vrai
capital du projet, et il n'est pas en jeu.
