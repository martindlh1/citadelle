# JOURNAL.md — Citadelle

Décisions prises en cours de route, la plus récente en haut.

---

## 2026-08-27 — `P1a` : la souris suffit, la main affiche ses prix, la phase a une couleur

**État : terminé.** Quatre commits sur `feat/p1a-comfort`. Les trois commandes passent :
boot sans erreur ni warning, tout `src/domain/` parse, **779 tests verts contre 777**.
Sept captures, dont trois qui ont renvoyé le travail à l'établi.

`P1` s'est découpé en trois à l'ouverture, et la découpe suit ce que chaque point
**touche** plutôt que sa taille : quatre ne sortent pas de `src/adapters/`, deux réclament
une vue ou une place neuve, le septième rouvre une règle du domaine et une ligne de
`DESIGN.md`. `P1a` prend les gestes ; `P1b` les listes ; `P1c` la désignation.

Le sens du terrassement était au périmètre initial et **l'humain l'a retiré**. Il reste
écrit en `P1b`, donc la promesse de 4.2 — la carte revient dans le deck le jour où l'écran
montre où va la terre — tient.

### Ce que le jalon livre

**Affecter à la souris de bout en bout.** On cliquait une fiche, puis on appuyait sur
Espace en visant à la souris : une intention, deux vocabulaires. Le clic gauche sur le sol
route désormais trois questions dans un ordre qui a chacun sa raison — fonder d'abord,
parce qu'aucun autre geste n'a de sens sur une carte nue ; l'ouvrier avant la carte, et
c'est gratuit puisqu'une case qui porte déjà une action en refuse une seconde depuis `I2`,
si bien que jouer y serait de toute façon refusé ; la carte en dernier, ce qui laisse
`_play_here()` intact. Le fichier n'a pas gagné une règle, il a gagné un aiguillage.

**Le coût sur la carte.** Un chiffre par ressource, de la couleur que la jauge de réserve
emploie déjà, et l'encre s'affaiblit quand `Ledger.can_afford()` dit non. Ce n'est pas une
entorse au « la vue ne juge aucune jouabilité » de `HandView` : la vue pose la question au
domaine et dessine la réponse, ce que `CLAUDE.md` écrit noir sur blanc. La faute serait
`if ledger.wood >= data.cost`, pas l'appel.

L'affaiblissement plutôt qu'une couleur d'alarme, et c'est la leçon de la passe jouée à la
main appliquée d'avance : l'orange veut dire *danger* sur les quatre autres panneaux. Une
main de sept cartes dont trois sont trop chères s'afficherait entièrement en alarme le
premier jour, où rien ne va mal. « Pas maintenant » et « attention » sont deux messages.

Une carte d'**action** ne porte pas de coût. Ce qu'elle dépense, ce sont des ouvriers, et
combien dépend de la cible — les postes d'un bâtiment, les crans d'un chantier, un chiffre
d'équilibrage sur une case nue. Ce prix-là n'existe qu'en visant ; lui inventer un nombre
fixe sur la carte serait mentir sur la seule chose qu'on voudrait comparer.

**La phase a une couleur.** Un liseré de trois pixels sur le bord haut du panneau
d'affectation. `PhaseDef` porte une `color` sur le patron exact de `TerrainData` — pas de
défaut, une sentinelle `UNSET_COLOR`, un contrôle dans `missing_fields()` — et **aucun nom
de phase n'est entré dans le code**, ce qui était la condition posée par `DESIGN.md` 8. La
vue lit une couleur en data, comme le renderer de terrain.

Le liseré est sur ce panneau-là et pas ailleurs parce que la phase décide de ce qu'on a le
droit de faire et que ce panneau est l'endroit où on le fait : son bouton **Auto** s'éteint
déjà quand la phase interdit d'affecter. Le liseré et le bouton disent la même chose, l'un
en couleur, l'autre en gris.

La phase arrive en **argument** et non par le `RunState`, alors que tout le reste de cette
vue en vient. « Quelle phase ? » n'a de réponse qu'avant la dernière journée, et
`RunManager.phase()` porte déjà ce garde-fou ; le redemander au cycle ici en aurait fait un
second exemplaire, donc un endroit de plus où la fin d'un run pourrait se lire autrement.

### Les trois défauts trouvés en regardant

Aucun n'était cherché par un test, et deux ne pouvaient pas l'être.

**Un coût de vingt s'affichait « 2 » au-dessus de « 0 ».** `AUTOWRAP_WORD_SMART` ne se
contente pas de replier sur les espaces : il coupe aussi ce qui n'en a pas dès qu'un
`HBoxContainer` serre. Le résultat était **lisible et faux**, ce qui est pire
qu'illisible — un prix de vingt lu comme deux chiffres empilés.

**Toutes les captures du projet depuis `D2` montraient une main d'avant leurs propres
poses.** `_play_scripted()` appelle `RunManager.play()` en direct, sans passer par le geste
que la souris déclenche, donc sans rien redessiner. L'image affichait sept cartes pendant
que la ligne « Piles » en annonçait deux, deux panneaux plus loin, sur la même image. Le
défaut a traversé `D2`, `W2` et `I2` sans se voir parce que rien sur une carte ne dépendait
d'un état mutable : la liste était fausse d'une façon qu'aucun œil ne rattrapait. Le coût
l'a rendue visible d'un coup — une Habitation à pleine encre sur une réserve qui ne la
payait plus.

C'est le piège que `F1` avait nommé, appliqué à une image au lieu d'une table : un harnais
peut être **faux sur ce qu'il prétend montrer**, ce qui est pire qu'une panne parce qu'on
lui fait confiance.

**Le panneau d'affectation déborde de sa colonne et couvre le haut des cartes.** Dix-huit
pixels de bande au sixième jour du run de test, c'est-à-dire exactement la ligne du rang au
clavier — déjà illisible là **avant** ce jalon. C'est la troisième fois qu'une colonne de
droite ne tient pas, après `W2` et `I2`, et la première où elle **cache** une information
au lieu d'en tronquer une.

Ce défaut n'est pas réparé, et c'est délibéré : sa réponse est le point « la liste des
actions posées, pour de bon » que `DESIGN.md` 8 garde, donc `P1b`. Il a en revanche décidé
d'un choix de ce jalon-ci, et c'est ce qui mérite d'être écrit.

### Le coût a changé de ligne deux fois, et la deuxième était la bonne

Il a d'abord été posé sur une **troisième ligne**, ce qui portait la carte de 74 à 86
pixels. La bande a grandi d'autant, son bord haut est monté de douze pixels, et le
chevauchement du panneau est passé de trois à trente.

Le réflexe a été de tout ramener à 74 en rangeant le coût sur la ligne du rang, qui
semblait à moitié vide. **La capture a refusé.** Cette ligne-là est précisément celle que
le panneau recouvre : le prix devenait invisible aux journées chargées, et un prix qu'on ne
voit que certains jours est pire qu'un prix absent.

Le coût est donc revenu sous le libellé, dans le tiers **bas** de la carte, celui que rien
ne couvre. La carte plus haute élargit ce que le panneau cache — mais ce qu'il cache reste
le rang, qui est un rappel de touche et non une information de décision.

La leçon est notée dans `CLAUDE.md` : **agrandir une vue qui en touche une autre déplace un
défaut, il n'en crée pas.** Mesurer ce qui recouvre quoi, en pixels, sur une capture, avant
de rogner la marge qu'on vient d'ajouter.

### `--shot-phases`, et la phrase que ce projet se répète

`--shot-evenings` résout des **journées entières**, donc toute capture s'arrêtait sur le
premier créneau : les autres phases n'étaient joignables par aucun drapeau. Sans
conséquence tant qu'une phase ressemblait à sa voisine, et un trou dès qu'une phase a eu
une couleur à montrer — le liseré n'aurait jamais pu se regarder qu'en une seule teinte.

C'est mot pour mot la raison qui a valu son drapeau à `--shot-view` : **un écran qu'aucune
capture ne peut atteindre est celui que personne ne regardera.** Les deux teintes sont
maintenant vérifiées à l'image et au pixel — `115,168,224` le matin, `237,168,79`
l'après-midi, exactement ce que `run_balance.tres` porte.

### Un doublon retiré au passage

La marge basse du HUD était un `88.0` écrit à la main dans le harnais, censé valoir la
hauteur de la main. Il ne la valait déjà pas — trois pixels d'écart, assez pour faire mordre
le panneau sur le haut des cartes. `HandView.band_height()` la calcule à un seul endroit.
Même doublon que celui qu'`E2` a retiré de la réserve, et il avait déjà dérivé.

### Ce qui ne bouge pas

**Aucun DTO de `contracts/` n'a été créé ni modifié**, comme à `E2` et `W2` : une vue n'est
pas un second système du domaine. Aucune règle de domaine n'a changé non plus — les trois
points sont des questions auxquelles le domaine répondait déjà et que l'écran n'affichait
pas, ou affichait mal.

`PhaseDef` a gagné un champ, ce qui a forcé cinq fixtures de test à le renseigner :
`RunState.open()` asserte que l'équilibrage est complet, donc resserrer le schéma les casse
par construction. Elles sont dans le **même commit** que le schéma — les séparer aurait
laissé un commit rouge derrière.

### Prochain jalon

**`P1b`** ou **`I2b`**. Les trois gestes qui rendaient une phase pénible à mener sont faits,
donc `I2b` peut se jouer sans attendre. Mais `P1b` porte maintenant un défaut qui **cache**
une information, et ça pèse plus lourd qu'un confort qui manque. `P1b` doit régler le
débordement de la colonne **avant** ses deux points, qui s'y heurteraient tous les deux.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **Le clic gauche sur le sol a un sens de plus** : fiche en main + action sous le curseur =
  l'ouvrier y va. Espace reste, en raccourci.
- **Les cartes de bâtiment affichent leur coût**, en couleur de ressource, et pâlissent
  quand la réserve ne suit pas. L'infobulle porte le texte entier.
- **`data/balance/run_balance.tres` a deux lignes de plus** : une `color` par phase — bleu
  le matin, ambre l'après-midi. C'est de la data, donc réglable sans toucher au GDScript ;
  une phase sans couleur fait **refuser le boot**.
- **Nouveau drapeau de capture** : `--shot-phases n` franchit n phases après les journées.
  `--shot-evenings 3 --shot-phases 1` donne l'après-midi du quatrième jour.
- **La branche n'est pas fusionnée** : `feat/p1a-comfort`, quatre commits.

---

## 2026-08-27 — la première partie jouée à la main, et ce qu'elle a rapporté

**État : terminé.** Cinq commits sur `feat/i2-qol`, à la suite des trois QOL de la veille.
Les trois commandes passent : boot sans erreur ni warning, tout `src/domain/` parse,
**777 tests verts contre 771**. Quatre captures.

C'est la première fois du projet qu'un jalon vient **entièrement** d'une passe humaine.
`E2`, `W2` et `I2` avaient chacun trouvé leurs défauts en capture, ce qui est déjà autre
chose qu'un test ; là, rien de ce qui suit n'aurait été trouvé sans quinze journées jouées
au clavier.

### Les deux bugs, et pourquoi le second était invisible

**Deux actions sur une même case.** Le symptôme signalé — « ça bugue, on ne peut pas
attribuer deux fois » — était plus large que ça : `_action_here()` ne rend que la
**dernière** action posée sur une cellule, donc la touche qui affecte, le clic droit qui
retire et la ligne de survol ne peuvent en atteindre qu'une. L'autre n'existait plus que
dans une liste de panneau bornée à trois lignes.

La correction demandée — interdire deux actions par case — **renverse une ligne écrite de
`DESIGN.md` 3.5**, et c'est le cas même pour lequel `D2` avait donné une identité aux
actions : *Récolter* et *Chasser* sur une même forêt, « deux métiers sur une même terre ».
Elle est renversée quand même, et le journal doit dire l'argument exact : le domaine
autorisait un geste que **rien à l'écran ne pouvait viser**. Une règle que le joueur ne
peut ni voir ni employer n'est pas une règle, c'est une intention.

Le retour en arrière est écrit comme provisoire dans les trois endroits qui comptent — le
code, le cas de test, et 3.5 —, avec la condition qui le lèvera : un écran qui sait
désigner l'une des deux.

**L'auto-affectation classait par ordre du roster.** Le diagnostic tient en une phrase :
un multiplicateur vient d'un **palier**, donc six ouvriers frais valent tous 1.00, et
`ranked_for()` n'avait plus rien à comparer. Le départage par l'ordre du roster, écrit à
`W2` comme dernier recours, était devenu le **seul** recours — pendant précisément les
journées où le bouton sert le plus.

Ce défaut ne pouvait pas se voir autrement. Les tests de `W2` comparaient des ouvriers aux
multiplicateurs distincts, ce qui est le cas intéressant et le cas rare ; le cas fréquent,
celui de six bleus, ne prouvait rien et n'était donc pas écrit. C'est un trou de couverture
que seule une partie révèle.

### Le contrat qui bouge, et le seul depuis `F1`

`LaborUnit` porte l'XP de piste. Son docstring disait « ni les traits, ni l'XP, ni les
blessures », et le refus était juste tant que rien ne posait la question — c'est la règle
qui a fait attendre `CombatForce` jusqu'à `F1`. Le bouton d'auto-affectation la pose.

Ce qui entre est l'**XP** et non le niveau, et la distinction porte tout : un niveau est un
palier de plus, donc la même égalité un cran plus haut. Ce qui manquait est *où l'on en est
à l'intérieur d'un palier*, et il n'y a que l'XP pour le dire. Elle ne donne aucun
rendement et n'en donnera jamais : elle **ordonne**, elle ne calcule pas.

Le choix a un effet de design qu'il faut assumer : préférer celui qui est le plus près du
palier suivant **concentre** l'XP au lieu de l'étaler, donc le bouton fabrique des
spécialistes. C'est ce que 3.4 réclame — « spécialiser rend excellent à un poste et
médiocre ailleurs » — mais c'est une décision et non une correction.

### Ce qu'un écran disait de travers

**L'orange voulait dire deux choses.** Sur le panneau d'affectation, une action à qui il
manque du monde s'affichait en orange — la couleur qui veut dire *danger* sur les trois
autres panneaux : famine, écrêtage au plafond, pertes d'une vague. Une phase qui commence
s'affichait donc entièrement en alarme. Le vert reste, parce que « cette ligne est finie »
mérite un coup d'œil ; la fraction `1/2` portait déjà le compte, donc la couleur n'a jamais
eu à le répéter.

**Le sens d'un terrassement n'est visible nulle part.** La touche le retourne bien, mais
seulement carte en main, et ni la ligne de survol ni les cibles allumées ne disent lequel
des deux on fait. Une carte qu'on oriente à l'aveugle est pire qu'une carte qu'on subit,
ce qui est exactement l'inverse de ce que `I1` cherchait en faisant du sens un choix de
pose. La carte sort du deck de départ ; le verbe reste écrit et revient avec `P1`.

### La bande de survol, posée trois fois

Elle devait aller « en haut au milieu ». Elle y a été mise, et **deux captures l'ont
refusée** : cette rangée est prise en étau entre la barre de réserve à gauche et le compte
rendu de phase à droite, et une bande centrée grandit des deux côtés — « Survol : » se
dessinait par-dessus « Minerai 0 ». La couper en deux lignes plus courtes n'a pas suffi.

Ce n'est pas une marge à régler : c'est la leçon de `W2` appliquée à une **rangée** plutôt
qu'à une colonne. Deux vues qui grandissent l'une vers l'autre doivent vivre dans le même
conteneur. Elle est donc dans la colonne de gauche, sous la barre, où elle pousse au lieu
de recouvrir — et elle y gagne un voisinage juste, le coût d'une carte tenue se lisant à un
centimètre de la réserve qui doit le payer.

Elle reste visible quand `H` replie le rapport, ce qui était tout l'objet de la demande :
c'est la seule ligne qu'on lit **en visant**.

### La règle de travail que j'ai dû me faire rappeler

J'ai lancé la suite complète — deux minutes quarante-cinq — cinq ou six fois pour des
changements qui touchaient deux fichiers. `-a` se répète et une suite isolée revient en
treize secondes.

La règle est notée : **suites concernées pendant l'itération, suite complète une fois par
couche, avant le commit.** Le coût n'était pas le mien.

### Le jalon `P1`, et pourquoi c'en est un

La liste de confort ne va pas dans un coin de `JOURNAL.md` : elle devient une famille de
jalons, `P`, avec une raison qui tient. Les jalons d'écran ont chacun livré la vue **dont
leur système avait besoin** ; aucun n'avait pour charge ce qui rend une partie agréable à
mener bout en bout. C'est une question qu'on ne peut poser qu'après avoir joué, donc après
`I2` — et **avant** `I2b`, qui va demander à quelqu'un de jouer quinze journées d'affilée
pour arbitrer un `.tres`.

`P1` porte sept points, dont deux sont déjà faits parce qu'ils coûtaient une heure : le
clic droit sur une fiche pour rappeler un seul ouvrier, et la ligne de survol qui survit au
repli du rapport. Les cinq autres sont écrits en 8.

### Quatre `OUVERT` de plus, tous sur les cartes

Ils viennent de la même passe et se tiennent, ce qui est la raison de les écrire ensemble
plutôt que de les trancher séparément :

- **Une carte de bâtiment est-elle à usage unique ?** Les actions tournent ; un bâtiment
  posé ne se rebâtit pas au même endroit. S'il est détruit à l'usage, le pool devient fini
  et précieux — et il faut aussitôt un moyen d'en gagner : un choix parmi trois après une
  vague, ou dans un événement de 3.7. Les deux se tranchent ensemble ou pas du tout.
- **Conserver une carte, redessiner sa main, ce qu'un gouverneur de départ offre.** Trois
  variantes d'une même question, et c'est l'`OUVERT` que 3.5 garde depuis `D1` : que fait-on
  d'une main qu'on ne peut pas jouer.
- **Un bâtiment large peut-il recevoir plusieurs fois la même action ?** Une empreinte de
  quatre cellules est aujourd'hui **une** cible, donc elle accepte autant de travail qu'une
  cabane 1×1. La taille devrait-elle acheter du débit, ou seulement des points de vie et de
  la place ? La réponse décide de ce que valent les grands bâtiments dans le tableau de 4.1.

### Prochain jalon

**`I2b`** ou **`P1`**, dans l'ordre qu'on veut. `P1` est le seul jalon du projet dont le
contenu vient d'une partie jouée plutôt que d'une déduction, donc le seul qui se périme si
on attend — et il rend `I2b` nettement moins pénible à mener.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché.

- **Les commandes ont deux ajouts** : **clic droit sur une fiche** rappelle cet ouvrier-là
  sans défaire l'action, et **H** replie le rapport en gardant la ligne de survol, qui a
  quitté le pavé pour se poser sous la barre de réserve.
- **`data/balance/deck_balance.tres` a perdu une ligne** : *Terraformer* n'est plus dans le
  deck de départ. La carte, le verbe et sa résolution sont intacts — c'est une ligne de data
  à remettre quand `P1` aura montré le sens.
- **Le panneau d'affectation montre cinq lignes d'action** au lieu de trois, et une action
  incomplète n'est plus orange.
- **Les deux branches ne sont pas fusionnées** : `feat/i2-full-loop` (5 commits) puis
  `feat/i2-qol` (9), la seconde tirée de la première.

---

## 2026-08-26 — `I2` : le run se fonde, se bat et se termine

**État : terminé.** Cinq commits sur `feat/i2-full-loop`, tirée de `master`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **768 tests
verts contre 715** à l'ouverture, 44 suites contre 42. Les huit harnais ont été bootés un
par un. Quatre captures — la fondation, une vague en approche, la même après coup, et la
fin d'un run entier.

Le jeu se joue du premier geste au dernier. C'est ce que le titre du jalon promettait
depuis `I0`.

### Ce qui a été livré

- **Schéma et data** — `WaveSlot`, le calendrier et les quatre poids du score dans
  `RunBalance`, `run_balance.tres` réécrit.
- **Domaine** — `RunOutcome`, `DayCycle.end()`, `RunOrchestrator.found()`,
  `close_the_day()` qui arme, `end_phase()` coupée en deux, `fight()` qui consomme une
  vague en attente, `Roster.total_level()`, `DayReport.wave()`, trois refus nommés de plus
  sur `PlayResult`.
- **Adapters** — `BattlePanel` sous `src/adapters/hud/`, `RunManager.found()` et
  `fight()`, `EventBus` qui gagne `battle_pending` et `battle_resolved` et dont
  `run_finished` porte l'issue.
- **Cinquante-trois cas de plus**, dont une suite neuve sur `RunOutcome`.
- `DESIGN.md` 2, 3.6, 3.8, 5 et 8 ; `CLAUDE.md` ; `README.md`.

### Ce que le jalon n'a pas eu à faire, et c'est le plus important

**Aucun DTO de `contracts/` n'a bougé.** `DESIGN.md` 8 le promettait — « aucun contrat ne
bougera plus, ce qui était la raison de passer `F1` avant » — et c'était une promesse
vérifiable, pas une intention. Tout ce que `I2` crée vit dans `domain/run/` ou dans
`src/schema/`, par le critère habituel : aucun second système du domaine ne le franchit.

Un jalon d'intégration qui aurait fait bouger un contrat aurait été un jalon qui découvre
trop tard ce qu'il branche. L'ordre `F1` puis `I2` a coûté un jalon de plus et il valait
exactement son prix.

### La coupure écrite à l'avance, et ce qu'elle a coûté

`DESIGN.md` 3.8 a été écrit après `F1`, avant qu'on en ait besoin : « le cycle devra
refuser d'avancer tant qu'une bataille est en attente », et le rapport de journée
« n'accueillera pas un rapport de bataille mais **la vague en attente** ». Le prix annoncé
était d'une demi-heure contre un écran à moitié câblé à défaire ensuite.

L'estimation était juste, et la forme aussi. Ce qui est différé n'est pas la résolution —
elle a bien lieu, le plateau se vide, la main part à la défausse — mais l'**ouverture de
la phase suivante**, que `fight()` fait à sa place. Les deux portes passent par la même
fonction privée, ce qui garantit qu'une journée fermée par un combat s'ouvre sur la
suivante dans le même état qu'une journée paisible.

**Et le run n'a coûté qu'un champ.** L'idée était de porter la vague *et* de se souvenir
que la phase interrompue résolvait, pour savoir s'il faudrait repiocher. C'est inutile :
quand une bataille attend, **le cycle pointe encore sur la phase qui vient de finir**,
donc `resolves()` dit encore ce que cette phase faisait. Un état qu'on peut relire n'a pas
besoin d'être retenu.

### Le calendrier : une liste, et pas une période

La question était réelle et j'ai demandé avant d'écrire. Une période — « une vague tous
les N jours » — rendrait l'`OUVERT` de 2 plus facile à tourner, puisqu'un seul entier
bouge.

C'est la liste, pour deux raisons dont la seconde tranche. Une liste **dit** une période
en l'écrivant, alors qu'une période ne sait exprimer ni un creux ni deux vagues
rapprochées. Et surtout la **vague finale** de 2 tombe sur le dernier jour parce qu'on l'y
a mise ; avec une période elle n'y tomberait que par coïncidence arithmétique, et changer
`days` la déplacerait sans qu'on le veuille.

Elle vit dans `RunBalance` et non dans `CombatBalance`, qui s'en défausse en toutes
lettres depuis `F1`. L'argument qui décide n'est pas thématique : le seul contrôle qui
compte croise le calendrier avec `days`, et seul le bloc qui tient la durée du run peut
dire qu'une vague datée au jour vingt ne tombera jamais.

### Ce que la fin de run a demandé de plus que sa ligne de design

`DESIGN.md` 5 tient en trois puces depuis le premier jour. L'écrire en a demandé trois
précisions qu'aucune des trois ne portait :

- **Une défaite ne s'attend pas.** Elle tombe au jour sept, donc « le run est fini » doit
  pouvoir devenir vrai au milieu. Une seule vérité pour ça — le cycle des jours —, et la
  cause à côté ; deux drapeaux qui peuvent se contredire auraient été pires que le cas
  qu'ils couvrent. Le bénéfice se lit en une ligne : tous les gardes déjà écrits se
  ferment sur une défaite sans qu'un seul ait bougé.
- **Le Cœur se reconnaît à son ancre**, retenue à la fondation, et non à son identifiant.
  C'est ce qui garde `heart` dans `data/balance/` et hors de tout `.gd`.
- **« Victoire » se lit « dernière journée franchie »** plutôt que « dernière vague
  survécue ». Les deux disent la même chose tant que le calendrier pose sa dernière vague
  sur le dernier jour, et la première n'a pas à inventer une règle pour un calendrier qui
  s'arrêterait avant.

**Il n'y a pas de `RunScorer`**, et c'est la seule chose du plan que j'ai retirée en
écrivant. Un score est une somme pondérée de quatre nombres ; ce qui méritait un fichier
n'était pas la somme mais le fait d'aller chercher les quatre au bon endroit — or c'est
exactement le métier de l'orchestrateur, qui « n'ajoute que ce qu'aucun résolveur ne peut
faire seul ». Un fichier de plus n'aurait fait que retransporter quatre entiers.
`Roster.total_level()` répond pour le roster comme `Ledger.total()` répond pour la
réserve : aucun contenu d'état ne traverse, ce qui est la ligne que `F1` a tracée sur le
pillage.

### Trois défauts, tous trouvés en capture

`E2` et `W2` ont appris qu'un écran trouve ce qu'aucun test ne cherche, et `F1` que le
pire est un affichage **faux sur ce qu'il prétend montrer**. `I2` en donne le meilleur
exemple du projet.

**Le panneau de bataille annonçait « Pertes : bo, cy »** — les identifiants internes. La
traduction interroge le roster, et au moment où le signal arrive **les morts n'y sont
plus** : `fight()` les retire avant de rendre son rapport, ce qui est précisément l'ordre
qui fait qu'un mort ne gagne pas d'XP. Rien ne plantait, tout compilait, les 768 tests
passaient, et la seule ligne du jeu qui raconte quelque chose disait des matricules. Le
relevé se prend maintenant avant que la vague tombe.

**Trois panneaux ne tiennent pas dans une colonne qui en portait deux.** `W2` avait appris
que deux vues qui grandissent l'une vers l'autre doivent vivre dans le même conteneur ; le
cran suivant est que ce conteneur a lui aussi une hauteur. Le jour de la dernière vague,
la dernière fiche d'ouvrier sortait de l'écran par le bas — et rétrécir une marge
aggraverait la chose. Le panneau de bataille est parti dans la colonne de gauche, où la
place est, et la lecture y gagne : la vague est voisine de la réserve qu'elle va piller.

**Le bandeau de fin passait sous les panneaux de droite**, si bien que la seule chose
qu'il devait annoncer se lisait « Victoire — la dernière journée est passée au jour 15.
Score 431 — 71 en ré ». Le raccourcir une fois n'a pas suffi : la moitié gauche de l'écran
fait sept cents pixels et un bandeau ne se replie pas. Ce qui tient est **un mot** ; la
cause et les quatre termes du score sont des lignes du rapport, où le texte va à la ligne.

**Et un quatrième qui n'en était pas un, mais qui aurait été le pire.** L'écran de
fondation n'était atteignable par aucune capture, puisque toute journée jouée commence par
poser le Cœur — donc le seul écran neuf du jalon aurait été le seul que personne n'aurait
regardé. `--shot-evenings 0` le capture désormais. Le contrôle a d'ailleurs servi tout de
suite : la première ligne du jeu conseillait encore « prendre une carte », geste que le
domaine refuse tant que le Cœur n'est pas posé.

### Ce qu'un run entier dit de l'équilibrage

Une partie complète, seed 20260825, quinze journées, trois vagues, victoire à 431 points :
71 en réserve, 23 bâtiments debout, 4 ouvriers sur 6, 10 niveaux cumulés.

- **La famine s'installe et ne repart pas.** Elle tombe à la cinquième journée et tient
  jusqu'au bout — « 6 dû, 2 mangé, 4 à jeun » au quinzième jour. C'est le déséquilibre le
  plus visible du run, et il est cohérent avec ce que `I1` avait noté sans pouvoir le
  mesurer : deux récoltes par jour pour un seul upkeep, mais une main qui pioche
  rarement une ferme. Elle ne punit encore rien — `X6` —, ce qui est la seule raison pour
  laquelle le run se gagne quand même.
- **Le village grossit beaucoup.** Vingt-cinq bâtiments à la fin, dont vingt-trois
  achevés. Le bois ne manque jamais ; la nourriture, toujours.
- **Le siège final mord.** Quarante contre vingt-sept de défense, treize de brèche, trois
  bâtiments détruits, deux morts et treize unités pillées. C'est la seule vague dont on se
  souvienne, ce qui est le bon dosage pour une dernière — mais les deux premières sont
  peut-être trop douces.
- **Le score est dominé par les ouvriers**, ce qui sert le pitch : quatre survivants
  valent quatre-vingts points là où soixante-et-onze unités de réserve en valent
  soixante-et-onze. Un chiffre de départ, pas une cible.

### Ce qui reste

Rien pour `I2`. Ce qui est resté dehors était annoncé dehors :

- **Le vrai combat** — `F2` et `F3`. La vague se résout encore instantanément ; ce que ce
  jalon livre est le **moment** où elle tombe et l'attente autour.
- **L'événement quotidien** *(3.7)* — la dernière case vide de la séquence de 2.
- **Les états d'ouvrier** — `X6`. La famine se constate toujours sans punir.
- **Le poste occupé de la tour de guet**, la colonne **Débloque**, les bonus d'adjacence
  de `C3` : inchangés, et chacun attend son jalon.

La mise en commun des `_make_label()` est passée de neuf à **dix** exemplaires. Elle
n'appartient toujours à aucun jalon.

### Prochain jalon

**`I2b`** — le playtest. La boucle est jouable de bout en bout, donc la question n'est plus
« qu'est-ce qui manque » mais « est-ce que ça se joue ». Les deux arbitrages — la structure
de la journée en 2, le sort de la main non jouée en 3.5 — se testent en échangeant un
`.tres`, et c'est le premier jalon du projet qui ne demande pas d'écrire une ligne de
GDScript.

`I3` suit avec les chiffres, et il en a désormais une liste précise plutôt qu'une
intention : la nourriture d'abord, puis le calendrier des vagues, le barème du score, et le
`breach_per_casualty` que `F1` avait déjà signalé comme le plus fragile de ses cinq.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'`InputMap`
ajoutée.

- `F5` lance le **harnais Run** : `HARNESS` vaut de nouveau `&"run"`.
- **Les commandes ont un ajout** : **Entrée** fait avancer le run quoi qu'il attende — elle
  fonde le village, elle mène la bataille, ou elle finit la phase. Le reste est inchangé.
  Le Cœur se pose au **clic gauche** sur la carte ; Entrée le met sur la case suggérée.
- **`data/balance/run_balance.tres` a changé de forme** : il porte trois sous-ressources
  `WaveSlot` de plus, qui **référencent** les `.tres` de `data/waves/`, et quatre poids de
  score. C'est le premier `.tres` du projet dont une sous-ressource pointe sur un fichier
  externe — l'éditeur devrait le réenregistrer sans broncher, mais c'est le diff à
  surveiller.
- **Les chiffres à relire** : trois vagues aux jours 5, 10 et 15 — escarmouche, razzia,
  siège — et un score à 1 par unité de réserve, 10 par bâtiment achevé, 20 par ouvrier
  vivant, 5 par niveau.
- **Les captures** : `--shot-evenings 0` montre la fondation, `10` une vague en approche,
  `16` la fin d'un run entier.
- **L'équilibrage de la nourriture est le premier chantier ouvert**, et il l'est maintenant
  avec une mesure plutôt qu'un soupçon : famine du jour 5 au jour 15.
- Les caches de classes et d'uid ont été reconstruits pendant la session, et les `.gd.uid`
  des trois scripts neufs sont commités.
- **La branche n'est pas fusionnée** : `feat/i2-full-loop`, cinq commits.

---

## 2026-08-26 — le format de combat, tranché en discussion juste après `F1`

**État : décidé, rien d'écrit.** Un commit sur `feat/f1-combat-stub`. Aucune ligne de `F2`
n'existe ; ce qui change est `DESIGN.md`, plus **une correction de data** que la
conversation a fait tomber. Les trois commandes passent, 715 tests toujours verts.

C'est le plus gros `OUVERT` du document qui se referme — 3.6 gardait sept questions
depuis `I0`. Il en reste trois, et ce sont des chiffres.

### Le format

**Tactique au tour par tour, sur la grille du village.** Un tour joueur où l'on déplace
les déployés et où chacun agit ; un tour ennemi. Référence assumée : *The Last Spell*,
avec beaucoup moins d'unités.

Les trois pistes que 3.6 listait avaient le même contrat — c'était l'intérêt de les
laisser ouvertes —, et c'est la troisième. Elle est aussi la plus testable des trois :
tout y est discret, un plateau et des entiers, donc du domaine pur.

### Ce que le projet avait déjà pour ça

Beaucoup, et c'est ce qui a rendu la décision facile. `HeightGrid`, `CellPicker` en DDA,
`CellHighlight`, `TargetHighlight`, la caméra orthographique qui pivote par quarts de
tour, `BuildingRenderer` : un combat sur la grille du village n'en réécrit **rien**.

Et la **borne de déploiement**, ajoutée à `F1` il y a une heure, devient littéralement la
phase de déploiement d'un jeu tactique. Elle était une rareté stratégique ; elle est aussi,
maintenant, le régulateur du rythme tactique — trois places, trois pions à jouer. Une
propriété qu'on n'avait pas cherchée et qu'il faut connaître : **desserrer la borne ne
rend pas le combat plus riche, ça le rend plus long.**

### La collision entre deux bonnes réponses

Prises séparément, « garder la carte entière » et « tenir N tours » sont justes. Ensemble,
elles donnaient la stratégie dominante la plus bête possible : **courir en rond dans les
vingt-huit colonnes vides** jusqu'au compteur. Zéro perte, zéro décision.

La réponse n'a pas été de recadrer la carte, mais de fixer **ce que les ennemis veulent** :
les ouvriers à portée, les bâtiments sinon. Fuir devient un troc — on garde ses gens, ils
mangent les murs — et le rapport de sortie sait déjà dire exactement ça, depuis `F1`.

Ce qui a en retour transformé la condition de victoire : **une vague est une razzia, pas un
duel.** Tenir N tours suffit à ce qu'elle reparte, nettoyer donne un bonus. Il n'y a plus
de défaite au combat, seulement une facture. La défaite d'un run reste celle de 5.

Second effet de garder le 32×32 : **la vague entre à la lisière du bâti**, pas au bord de
la carte. Le Cœur est au centre, donc seize cases de marche — quatre tours où personne ne
décide rien.

### La phrase de `DESIGN.md` qui est tombée

3.6 promettait depuis toujours : « Le jour où il est prêt, on échange l'implémentation dans
l'orchestrateur : **une ligne**. » C'est faux pour un format au tour par tour, et ça
n'aurait aucune importance si on l'avait découvert ailleurs qu'à `I2`, l'écran à moitié
câblé.

Un résolveur rend un rapport ; un combat tactique **attend le joueur**, et le domaine n'a
pas le droit d'`await`. Le producteur cesse donc d'être une fonction pour devenir un
**état** — un plateau mutable dans `domain/combat/`, des fonctions pures qui appliquent un
geste à la fois, un `DamageReport` au bout.

Ce qui est vrai en revanche, et `F1` l'a livré sans le chercher : `fight()` sépare déjà
**produire** — une ligne — et **appliquer** aux trois systèmes — tout le reste.
L'applicateur ne bouge pas d'un pouce. La promesse était bonne, elle portait juste sur la
mauvaise moitié.

### La conséquence qui touche du code déjà écrit

Le combat clôt la journée, après l'upkeep, à la place que la séquence de 2 lui garde. Mais
`end_phase()` est aujourd'hui **indivisible** — résoudre, vider, avancer — et la rupture
interactive tombe au milieu.

Le cycle devra refuser d'avancer tant qu'une bataille est en attente. C'est une demi-heure
aujourd'hui contre un écran à défaire plus tard, et c'est entré dans 3.8 **avant** d'en
avoir besoin, ce qui est la première fois que ce document écrit une contrainte
d'implémentation en avance. Corollaire : `DayReport` n'accueillera pas un rapport de
bataille mais **la vague en attente**.

### Deux `OUVERT` qui se referment par ricochet

**Le relief joue enfin autrement** *(3.1)*. Monter coûte, une marche trop haute bloque.
L'« avantage défensif en hauteur » qu'on imaginait est remplacé par mieux : une contrainte
de déplacement, donc quelque chose qui **se joue** au lieu de se subir. Le terrassement
devient un geste militaire autant qu'économique.

**`X5` a une forme.** « Ce qu'un palier de niveau offre » était en blanc depuis `W1` : une
**capacité de combat**. C'est ce qui a permis de ne donner que deux verbes à `F2` — se
déplacer, attaquer — sans condamner le combat à rester plat, et ça enracine les capacités
dans le roster nominatif au lieu d'un catalogue hors-sol. Un système de capacités
générique dans `F2` aurait été un jeu entier, et il aurait tué le jalon avant qu'on sache
si le format tient.

### Ce que `X6` devient

Un ouvrier à zéro point de vie **meurt**. C'est le choix qui sert le pitch, et il a un
revers qu'il valait mieux nommer tout de suite : **sans blessure, un combat n'a que deux
issues, rien ou définitif.** Le joueur qui a bien joué ne sent rien du tout, et la courbe de
difficulté est une falaise.

Les points de vie sont donc la ressource d'une **manche** ; ce qu'un survivant en emporte
est un effet progressif **selon la part de vie perdue**. `X6`, écrit ce matin comme un
rangement, devient structurant — et c'est le premier état dont on connaisse à la fois la
source et la graduation.

### Ce que la conversation a corrigé dans `data/`

**La caserne valait +2 places de déploiement, elle vaut +1.** Sur une base de trois, un
seul bâtiment ajoutait deux tiers de la ligne d'un coup. Une place se gagne très
progressivement — c'est un pion de plus à jouer chaque tour.

Le chiffre datait de `F1`, écrit ce matin, et c'est le harnais Combat qui rend la
correction lisible : la table « ce que la borne retient » montre maintenant trois, quatre
et quatre engagés au lieu de trois, cinq et cinq.

### Ce qui reste ouvert en 3.6

Trois choses, toutes des chiffres ou du contenu : **la nature des vagues** — qui vient,
combien, avec quelles portées —, **la borne de tours** d'une manche, et **le bonus** que
vaut un nettoyage complet. Aucune ne remet en cause le format.

L'éclaireur de 3.7 a changé de métier au passage : la direction d'une vague est désormais
une information de base, annoncée par une flèche, parce que 3.2 veut qu'on pense à la
bataille en posant un bâtiment et qu'une direction révélée le soir même transformerait
cette prévoyance en loterie. Ce qu'un éclaireur révélerait est donc ce qui vient **en
plus** — composition, portée, nombre —, ce qui en fait un meilleur événement.

### Prochain jalon

**`I2`** — inchangé. Cette discussion ne l'avance ni ne le retarde ; elle lui dit quelle
place réserver, ce qui est exactement ce qu'on lui demandait. Le seul travail qu'elle lui
ajoute est la coupure de `end_phase()`, et il vaut mieux la faire là que dans `F3`.

### À faire dans l'éditeur avant la prochaine session

**Rien.** Aucune `.tscn`, aucun `project.godot`, aucun champ neuf.

- `data/buildings/barracks.tres` a changé d'un chiffre. Rien d'autre dans `data/`.
- `HARNESS` vaut toujours `&"combat"` ; `&"run"` rend le jeu.

---

## 2026-08-26 — `F1` : le bouchon de combat, et la borne qui lui donne un enjeu

**État : terminé.** Six commits sur `feat/f1-combat-stub`, tirée de `master`. Les trois
commandes passent : boot sans erreur ni warning, tout `src/domain/` parse, **715 tests
verts contre 625** à l'ouverture, 42 suites contre 39. Les sept autres harnais ont été
bootés un par un — trois champs neufs sur `BuildingData` traversent tout le projet.

### Ce qui a été livré

- **Contrats** — `CombatUnit`, `CombatForce`, `DamageReport`. `WorkLine` gagne `NO_CELL`.
- **Schéma et data** — `WaveDef`, `CombatBalance`, les colonnes **Déf.**, **PV** et
  **Dépl.** de 4.1 dans treize `.tres`, `data/waves/` et son indexation par
  `GameDatabase`.
- **Domaine** — `InstantCombatResolver` sous `domain/combat/`, `BattleReport` sous
  `domain/run/`, `RunOrchestrator.fight()`, `Roster.to_combat()`,
  `Worker.to_combat_unit()`, `CityState.damage()`, `PlacedBuilding.take()`,
  `Ledger.take_share()`.
- **Harnais** — `scenes/dev/combat_harness.gd`, quatre tables et une chronique.
- **Quatre-vingt-dix cas de plus**, dont trente-huit sur le résolveur.
- `DESIGN.md` 3.3, 3.4, 3.6, 4.1 et 8 ; `CLAUDE.md`.

### Le déploiement capé, qui vient de l'humain et change le jalon

Le plan proposait que **tout le monde** se batte, en assumant le prix : à `F1` la vague
n'aurait concurrencé la production en rien, donc la tension centrale du pitch n'aurait pas
été exercée. C'était honnête pour un bouchon et ça restait un trou.

La réponse — *« un nombre de slot serait pas mal, la phase de combat commence par une phase
de déploiement capé qui pourra augmenter plus tard, peut-être avec la construction d'une
caserne »* — est meilleure, et pour une raison qui se dit en une ligne : **sans borne, un
ouvrier de plus est un défenseur de plus, donc « envoyer son meilleur récoltant en milice »
ne coûte rien puisqu'on les envoie tous.** La borne rend une place rare, et une place rare
rend le choix réel.

Elle a aussi un effet qu'on n'attendait pas de ce jalon : **elle sort la caserne de sa
coquille**, et avant l'action qu'elle débloquera à `X3`. On la bâtissait pour *S'entraîner*,
qui n'existe pas ; on la bâtira d'abord pour tenir la ligne. C'est un renversement du
tableau de 4.1, et il est délibéré — un bâtiment dont le seul intérêt est de débloquer une
carte absente n'a rien à faire dans un MVP.

Le design est donc passé **en premier**, dans le commit d'ouverture, comme le second axe de
progression à `W1` et la rotation à `C2`. Il a coûté une colonne à 4.1, un champ plat de
plus sur `BuildingData`, et zéro ligne au reste : `slots_for()` est le miroir exact de
`ProductionResolver.capacity_for()` et de `Roster.capacity_for()`, filtre `completed()`
compris.

### Ce que `CombatForce` n'est pas, et pourquoi `W1` avait raison d'attendre

`W1` refusait de l'écrire : « ou bien un clone strict de `LaborForce` qui ne prouve rien,
ou bien une devinette sur des PV et de l'équipement ». Le refus était juste, et l'écart
tient en un mot — **un** multiplicateur, pas un par famille. Un ouvrier récolte
différemment au camp de bûcheron et à l'atelier, donc `LaborUnit` répond par métier ; il ne
se bat que d'une seule façon. Ce qui en aurait fait un clone est précisément ce qui a
disparu.

Elle porte **tout le roster présent**, pas les engagés, et c'est le miroir strict de
`LaborForce`, qui porte tout le monde et non les affectés. Le filtre appartient au
consommateur : l'Économie n'emploie que ce que l'`Assignment` place, le Combat n'engage que
ce que la borne tient. Projeter les seuls déployés aurait donné aux Effectifs à connaître un
plafond qui vient de la ville.

Et le vivier unique cesse d'être une phrase : `to_labor()` et `to_combat()` sont deux
fonctions jumelles qui partent du même `present()`.

### La ligne de dépendance que le pillage a révélée

La règle de `CLAUDE.md` interdit de dépendre des **internes** d'un autre système. Le
corollaire s'est découvert ici : **recevoir le contenu d'un état voisin, même en copie,
revient au même.**

Le plan prévoyait que le résolveur reçoive le stock et rende un pillage réparti par
ressource. C'est faux : répartir demande de lire le `Ledger`, qui est un interne de
l'Économie. Le `DamageReport` dit donc **combien**, jamais quoi, et `Ledger.take_share()`
répond avec la règle de prorata de l'Économie — la même que l'écrêtage d'une récolte, écrite
une seule fois et déjà testée. Le Combat ignore jusqu'à ce que le village stocke.

Le test qui dit de quel côté on est : **la question posée appartient-elle au système qui
répond ?** « Combien la vague emporte » est une question du Combat ; « ce que la réserve
perd quand on lui prend N » est une question de la réserve. `take_share()` est nommée pour
aucun combat en particulier, et un événement de 3.7 lui posera la même question.

Conséquence en cascade : `BattleReport` est né de là. Le `DamageReport` est un ordre, et
deux choses n'existent qu'à l'application — ce que la réserve a **vraiment** perdu, et ce
que la ligne a valu. « Ils ont tout pris » et « ils sont repartis les mains vides » sont
deux fins de vague différentes, et seul ce rapport connaît l'écart.

### La règle de dégâts, écrite dans `DESIGN.md` parce qu'elle se discute

**Une brèche casse d'abord ce qui la retenait, puis ce qui cède le plus vite.** Deux vertus,
et une propriété qui n'était pas cherchée.

La palissade sert vraiment à quelque chose, ce qui n'allait pas de soi pour un bâtiment
entré « par la pratique et non par le design » à `C2`. Et le **Cœur se retrouve en dernier
sans qu'une ligne de code n'écrive son nom**, puisqu'il est le plus solide du tableau de
4.1 : c'est un identifiant de contenu en moins dans du GDScript, obtenu par accident et
gardé exprès.

L'ordre ignore la pose, et c'est le cas de test qui porte le jalon —
`test_the_pose_order_decides_nothing`. Deux villes aux mêmes bâtiments posés dans deux
ordres différents perdent exactement la même chose. Le risque est celui que `E1` avait déjà
nommé pour l'écrêtage : silencieux, invisible à l'œil, et il ne se manifeste que sur deux
parties qu'on compare.

Tu as dit « on modifiera peut-être plus tard », et c'est écrit tel quel : 3.6 la range
explicitement parmi ce que `F2` jettera en premier.

### La blessure déménage, et la famine avec

3.6 réclamait « pertes **et blessures** » depuis le premier jour. La blessure n'entre pas,
et ce n'est pas un renoncement : **elle n'a nulle part où atterrir.** Un `Worker` porte une
présence et de l'XP, rien qui dure et qui pèse. L'inventer dans le rapport d'un système neuf
aurait décidé pour les Effectifs de ce qu'un état fait.

Ta réponse a transformé un report en jalon. `X6` — **états d'ouvrier** — accueille la faim,
la blessure, et ce qui viendra des événements de 3.7. Trois systèmes avaient buté sur le même
manque et l'avaient chacun contourné : `E1` en laissant la famine « se constater sans se
punir », l'`OUVERT` de 3.3 en listant quatre issues dont trois décrivent le même objet, et
`F1` en sortant la blessure.

Il est dans les différés, après `I2`, et pour une raison de méthode : **un système d'états se
conçoit devant la liste de ceux qui existent vraiment**, et cette liste n'est complète
qu'une fois la boucle jouable. Ce qu'il contraint en attendant tient en une ligne, et elle
est dans `DESIGN.md` : **aucun rapport n'invente sa propre conséquence.** Un système qui
rencontre un état le compte ; il ne décide pas de ce qu'il fait.

C'est la troisième fois qu'un jalon **corrige** `DESIGN.md` au lieu de l'appliquer, après
`D2` sur le geste atomique et `W2` sur le micro-management.

### `WaveDef` sort de `contracts/`, et c'est une ligne de `CLAUDE.md` en moins

Elle y figurait depuis `I0`. C'est une `Resource` de `src/schema/`, éditée dans
`data/waves/`, exactement comme `PhaseDef` décrit la forme d'une journée. `contracts/` est
l'endroit où deux systèmes **du code** se rencontrent ; un contenu qu'on règle dans un
`.tres` voyage déjà partout — le domaine reçoit ses blocs d'équilibrage en argument depuis
`E1`, et une `BuildingData` traverse tous les systèmes dans un `BuildingSnapshot`.

Le Combat reçoit donc sa vague comme le résolveur de chantiers reçoit son `ActionBalance`.

### Trois défauts que seule l'exécution a montrés — tous dans le harnais

`E2` et `W2` ont appris qu'un écran trouve ce qu'aucun test ne cherche. `F1` ajoute une
variante plus désagréable : **un tableau de chiffres peut être faux sur ce qu'il prétend
montrer**, ce qui est pire qu'une panne parce qu'on lui fait confiance.

**Un `Array[StringName]` ne s'additionne pas à un tableau littéral non typé**, et le
`as Array[T]` ne rattrape rien. Ça compile, ça casse à l'exécution. Dans un harnais, donc
hors de toute suite de tests.

**La table des murs mesurait sur le plus petit roster**, si bien que la caserne ouvrait des
places que personne ne venait occuper et que sa ligne était identique à la précédente. La
table faisait passer pour inutile le seul bâtiment que ce jalon ajoute.

**La chronique annonçait une vague tombant sur un village déjà entamé** en jouant les trois
vagues par puissance croissante — que le village tenait deux fois sur trois. Elle rejoue
maintenant la plus dure, et la quatrième ligne est le seul endroit du harnais qui montre ce
qu'aucune table ne peut dire : les dégâts restent sur les murs, et les morts ne reviennent
pas.

D'où la discipline entrée dans `CLAUDE.md` : **chaque table annonce ce qu'elle doit
montrer**, en toutes lettres, dans le rapport lui-même. Une table dont on ne sait pas dire
ce qu'elle prouverait ne prouve rien.

### Ce que le harnais dit de l'équilibrage

Sur les chiffres de départ, et à prendre comme un premier relevé et non comme un verdict :

- **La palissade est rentable et la tour l'est davantage.** Cinq bois pour trois de défense,
  vingt-cinq pour huit — la progression est saine, la tour n'écrase pas.
- **La piste Combat ne rattrape pas la pierre**, et c'est voulu. Du palier 0 au plafond, un
  trio passe de 6 à 10 de défense ; une seule tour en donne 8. Bâtir reste le levier, monter
  la piste est un complément. Si l'inverse s'était produit, la caserne n'aurait rien acheté.
- **La borne mord franchement.** Trois, cinq ou huit ouvriers donnent la même défense sans
  caserne, et cinq avec. C'est la démonstration en trois lignes de ce que 3.6 affirme.
- **Un second siège est dévastateur.** Le village passe de six bâtiments à un et de huit
  ouvriers à trois. C'est exactement la spirale qu'un roguelite veut, et c'est aussi le
  chiffre le plus suspect du lot : `breach_per_casualty` est le réglage le plus fragile des
  cinq, et `I3` le verra de près.

### Ce qui n'a pas été fait, et qui était au plan

**Rien du plan n'a été retiré.** Deux choses en ont été ajoutées en cours de route —
`BattleReport` et `Ledger.take_share()` —, toutes deux conséquences de la ligne de
dépendance ci-dessus.

Ce qui est resté dehors était annoncé dehors :

- **Rien ne déclenche une vague.** `RunOrchestrator.fight()` existe, le harnais l'appelle,
  et personne d'autre. La fréquence est l'`OUVERT` de 2, et un calendrier que personne ne
  lit serait la frontière que ce projet refuse depuis `E1`.
- **La fin de run** — 5. veut un score et des conditions de défaite. `I2`.
- **Le poste occupé de la tour de guet** — « +8 déf. si occupée ». `F1` était le jalon
  nommé, et il n'entre pas : **aucun verbe de 4.2 ne tient un poste de défense.** Il en
  faudrait un huitième, hors du tableau. Même refus que `E1b` a opposé à cinq `slots = 1`.
- **La blessure** — `X6`.
- **Le rendu d'un bâtiment endommagé** — `BuildingRenderer` ne montre rien des PV. Les
  dégâts traversent `BuildingSnapshot`, la vue les lira quand il y aura un écran de combat.

### Prochain jalon

**`I2`** — la boucle complète. Tous les systèmes du MVP existent et tiennent debout seuls, et
**aucun contrat ne bougera plus** : c'était la raison de passer `F1` d'abord, et elle est
tenue. Il reste trois fils à brancher, chacun sur une prise déjà posée — la vague dans
`close_the_day()`, où `DayReport` l'accueillera par un champ ; le calendrier des vagues, qui
sera un bloc de `data/balance/` ; et la défaite, qui lit ce que la ville et le roster disent
déjà.

### À faire dans l'éditeur avant la prochaine session

**Rien d'obligatoire.** Aucune `.tscn` ni `project.godot` touché, aucune action d'`InputMap`
ajoutée.

- `F5` lance le **harnais Combat** — `HARNESS` vaut `&"combat"`. `&"run"` rend le jeu.
- **Une catégorie neuve dans `data/`** : `data/waves/`, trois vagues. Le rapport de boot
  annonce désormais six catégories.
- **Trois `.tres` neufs sans `uid://`** — les trois vagues, plus `combat_balance.tres`.
  L'éditeur leur en ajoutera un au premier réenregistrement : c'est un diff à attendre, pas
  un problème.
- **Treize `.tres` de bâtiments rouverts.** Seules les valeurs non nulles y sont écrites,
  puisque Godot n'écrit jamais un champ égal à son défaut — un `defense = 0` disparaîtrait
  au premier réenregistrement de toute façon.
- **Les chiffres du bloc `combat` sont à relire** : trois places de déploiement, deux de
  défense par homme, un mort tous les six points de brèche, une unité pillée par point. Le
  harnais mesure les quatre.
- **L'équilibrage des ressources reste le premier chantier ouvert**, inchangé depuis `I1` :
  deux récoltes par jour pour un seul upkeep. `F1` n'y a pas touché, et vient d'ajouter une
  seconde source de pertes.
- Les caches de classes et d'uid ont été reconstruits pendant la session, et les `.gd.uid`
  des sept scripts neufs sont commités.
- **La branche n'est pas fusionnée** : `feat/f1-combat-stub`, six commits.

---

## 2026-08-26 — `W2` : choisir qui, et une phrase de design qu'il a fallu corriger

**État : terminé.** Sept commits sur `feat/w2-assignment` — dont trois qui corrigent le
jalon après coup, sur un défaut trouvé au clavier. Les trois commandes passent : boot sans
erreur ni warning, tout `src/domain/` parse, **625 tests verts contre 589** à l'ouverture.

`StaffingAdvisor` dans `domain/run/` ; `ProductionResolver.family_of()` devient publique ;
`RunOrchestrator.auto_staff()` ; `WorkerCard` et `AssignmentPanel` sous
`src/adapters/workforce/`, le dossier que l'arborescence réservait depuis `I0` et que rien
n'habitait ; `Deck.take_back()`. Une suite neuve et 36 cas de plus, dont dix sur
l'orchestrateur. **Aucun DTO de `contracts/` créé ni modifié**, pour la deuxième fois
d'affilée. `DESIGN.md` 3.4, 3.5 et 8.

### La phrase de `DESIGN.md` qu'il a fallu corriger, et pourquoi je ne l'ai pas contournée

3.4 listait trois mitigations du micro-management et concluait : « C'est du travail
d'adapter, pas de domaine. » C'est vrai des deux qui encadrent la troisième — un effectif
réduit est un chiffre d'équilibrage, une affectation persistante est une politique
d'écran. **Ce n'est pas vrai du bouton.**

Classer des ouvriers exige la famille que chaque action posée créditera, les
multiplicateurs de la `LaborForce`, et la capacité figée à la pose. La famille n'est
calculable qu'à un seul endroit : `ProductionResolver.family_of()`, dont le docstring dit
qu'elle est « posée ici et nulle part ailleurs ». L'écrire dans une vue aurait donc demandé
de l'y recopier, et une vue qui classerait sur une famille que le soir ne crédite pas est
un défaut qui ne se voit qu'au bout de dix journées, sur une courbe d'XP.

L'argument décisif est ailleurs : **le bouton est un geste.** `CLAUDE.md` promet depuis
`I0` qu'un seed plus une suite de gestes rejoue un run à l'identique. Un geste dont le
résultat n'est pas reproductible casse cette promesse, et `src/adapters/` n'est pas testé.
La question a été posée avant d'écrire une ligne, et la réponse est entrée dans
`DESIGN.md` dans le même commit que le domaine — le journal seul n'aurait pas suffi : la
prochaine session lit le design.

### La règle du bouton, qui est du gameplay et non de la technique

Écrite en 3.4 parce qu'elle se discute :

> Parcourir les actions **dans l'ordre de pose**, remplir les postes qui restent avec
> l'ouvrier libre le plus efficace dans la famille de cette action, départager à égalité
> par l'ordre du roster. Sauter une action que rien ne crédite. Ne jamais déplacer un
> ouvrier placé à la main.

Le choix le plus discutable est ce qu'elle **refuse** de faire : elle ne pondère pas par le
rendement. Une récolte à 3 bois et une case nue à 1 se valent devant elle. Pondérer aurait
demandé de lire `_yield_of()`, et surtout rendu un cran de chantier comparable à une
récolte — un arbitrage d'équilibrage, donc `I3`.

Ce que ça achète en échange vaut mieux que l'optimalité : **l'ordre de pose est la priorité
que le joueur a déjà exprimée**, et le bouton s'y tient. Il ne décide jamais quelle action
mérite un ouvrier, seulement *qui* y va — la moitié évidente de la décision, celle que 3.4
veut retirer. Un bouton plus malin serait un bouton qu'on ne pourrait pas prédire, donc
contre lequel la surcharge manuelle serait un combat.

### Le cas de test qui porte le jalon

`test_the_announced_family_is_the_one_the_evening_credits` résout un vrai soir avec les
deux résolveurs, puis confronte **chaque ligne de travail** à ce que l'advisor annonçait
pour l'action dont elle vient. C'est le seul vrai risque du jalon, et il est silencieux :
un classement sur la mauvaise piste produit des affectations plausibles, un soir qui résout
normalement, et une courbe d'XP qui dérive sans que rien ne tombe.

Deux égalités sont épinglées exprès. À efficacité égale c'est l'ordre reçu qui départage,
et une famille que personne n'a entamée laisse l'ordre du roster intact. Sans les deux,
deux runs partis du même seed enverraient deux ouvriers différents sur le même poste, et ni
la bourse ni le relief ne le montreraient. Le cas de rejeu de `I1` a gagné un jumeau qui
passe par le bouton.

### Ce que le domaine n'a pas eu à inventer

`family_of()` devient publique plutôt que d'être recopiée — même geste que
`staffing_refusal()` à `I1` : une seconde question se pose sur la même règle, donc la règle
sort, elle ne se duplique pas. `auto_staff()` applique le plan **à travers** `staff()`,
jamais autour — une porte d'affectation qui court-circuiterait les cinq refus serait une
seconde liste de règles.

`StaffingAdvisor.plan()` **ordonne et ne mute rien**, comme `SiteResolver` depuis `I1` : il
se teste sans run, et l'écran pourrait l'appeler pour prévisualiser sans rien engager. Il
compte les postes exactement comme `staffing_refusal()`, ce qui garantit qu'aucune paire
proposée ne peut se faire refuser — un plan à moitié appliqué serait invisible à l'écran.

### Ce qu'un `Worker` fait dans une vue

`W1` a écrit que « rien hors de `domain/workforce/` n'en voit un », et la fiche en reçoit
un. Ce n'est pas une entorse : la phrase vise les **systèmes du domaine**, ceux à qui l'on
ne montre que des projections. Un adapter lit le domaine — `ResourceBar` prend un `Ledger`,
`HandView` une `Hand`, `BuildingRenderer` un `CityState`. Passer par la `LaborForce` aurait
coûté le niveau, l'XP et la présence, qui n'y traversent pas justement parce que l'Économie
n'a pas à les connaître.

Le panneau, lui, reçoit un **`RunState`**, ce qu'aucune vue n'avait fait. Une affectation a
besoin du plateau, du roster et du brouillon qui les relie, plus le relief et la ville pour
la famille de chaque action : `RunState` est le seul objet qui les tienne ensemble, et 3.8
l'autorise à exister pour cette raison même.

### Le legs de `E2` repris, et déplacé

`ProductionPanel` « ne nomme pas qui a franchi un palier » parce que ça lui demanderait le
`Roster`, « c'est-à-dire exactement la dépendance que `W2` existe pour porter ». Elle est
portée — mais **sur la fiche de l'intéressé**, pas dans le compte rendu de récolte. Un
palier appartient à la personne, et l'annoncer aux deux endroits aurait rejoué le doublon
que `E2` avait précisément défait en retirant la réserve du pavé de texte.

### Trois défauts de mise en page, tous trouvés en capture

Cette fois sur des défauts **structurels** plutôt que sur des pièges d'API.

**Deux panneaux qui grandissent l'un vers l'autre finissent par se recouvrir.** Le compte
rendu de phase en haut à droite et le panneau d'affectation en bas à droite tiennent tant
que le plateau est vide, et se chevauchent dès cinq actions posées. Ce n'est pas une marge
à régler : c'est un chevauchement qui n'attend que la phase la plus chargée, donc qui se
manifeste le plus tard possible. Une colonne les fait se pousser au lieu de se croiser.

**Une liste qui suit la partie sort de n'importe quel HUD de taille fixe.** Elle est bornée
et le reste est compté. Corollaire contre-intuitif appris en chemin : augmenter la marge
basse **aggrave** le débordement, parce qu'un conteneur trop petit pour son contenu le
laisse déborder par le bas au lieu de le remonter.

**Une ligne qui n'apparaît qu'au palier fait sauter toute la grille**, et elle le fait au
moment exact où le compte rendu de phase est le plus long. La ligne est désormais toujours
là, et montre l'XP totale à défaut de palier : pas du remplissage, l'axe du niveau
d'ouvrier, celui que les pistes n'expliquent pas. Même raison que les quatre colonnes de
`ResourceBar` qui ne bougent pas à zéro.

Les trois sont dans `CLAUDE.md` : la prochaine vue n'a pas à les réapprendre.

### Ce que la capture a dû changer pour prouver quelque chose

Elle s'arrêtait après une résolution, donc sur un plateau vide et six fiches oisives —
c'est-à-dire sur tout `W2` sauf ce qu'il fait. Elle joue maintenant une manche de plus
qu'elle **ne finit pas** : la seule image qui prouve quelque chose est celle où des
ouvriers tiennent des postes. Elle remplit ces postes par le **bouton**, ce qui fait passer
le chemin neuf du jalon sous le seul contrôle qui regarde l'écran. Et elle perd la table
des actions posées, à contrecœur : c'est elle qui avait attrapé le seul vrai bug de `D2`,
mais la garder aurait laissé la version imprimée dire vrai pendant qu'une mise en page
fautive cachait l'autre.

### Une heure perdue sur un `cd`

À noter parce que ça se reproduira. Un `cd src/adapters/workforce &&` dans une commande a
laissé le shell dans ce dossier, et les commandes suivantes ont lancé Godot avec `--path .`
sur un dossier sans projet. Symptômes : le boot cesse d'imprimer sa ligne, une capture ne
rend jamais la main, le renderer bascule en OpenGL, `.godot/` « a disparu ». Rien n'était
cassé. **Toujours des chemins absolus**, et vérifier `pwd` avant de conclure qu'un projet
est en vrac.

### Ce qui n'a pas été fait, et qui était au plan

**La bande de fiches dans le harnais Effectifs.** Retirée plutôt que forcée : ce harnais
est un rapport texte plein écran sur dix ouvriers et trente soirs, et six fiches graphiques
n'y ont ni la place ni l'idiome. La fiche se regarde dans le harnais Run, qui est aussi
l'endroit où elle sert. Le seul manque réel est de la voir aux paliers 3 et 4, que quinze
journées n'atteignent pas.

### Le défaut que le clavier a trouvé, deux jalons de suite

*(Trouvé par l'humain juste après le jalon, corrigé dans la foulée.)* Retirer une action ne
rendait pas sa carte.

Le comportement était **documenté comme volontaire** dans `RunOrchestrator.withdraw()` —
« elle est à la défausse depuis qu'on l'a jouée, c'est l'état par défaut et non une
réponse » — et renvoyé à l'`OUVERT` de 3.5. Le docstring avait tort, et sur un point
précis : **il confondait deux gestes.** Cet `OUVERT` porte sur les cartes *non jouées en
fin de phase* ; un retrait reprend une carte *jouée*, dans la phase même, avant que quoi
que ce soit n'ait été consommé. Deux moments, deux questions, et `I2b` garde la sienne
entière.

Le prix de l'ancienne lecture ne se voyait qu'au clavier : le clic droit n'était pas une
annulation mais un sacrifice, et il punissait une cible mal visée plutôt qu'une décision.
Le scumming qu'on aurait pu craindre en retour — poser pour lire la capacité, retirer,
reposer ailleurs — n'existe pas, la ligne de survol annonçant déjà « accepté, N poste(s) »
avant le jeu.

**Aucun test ne figeait l'ancien comportement**, et c'est la différence avec le cas que
`E2` avait dû réécrire : les trois cas de retrait ne vérifiaient que le plateau et les
ouvriers. Rien n'avait été prouvé, seulement supposé.

`Deck.take_back()` est l'inverse exact de `discard()`, et reprend le **dernier exemplaire
tombé** — sans conséquence observable, deux exemplaires étant interchangeables, mais ça
fixe l'ordre et garde deux runs du même seed identiques jusque dans les piles. Le cas qui
compte est que la carte rendue **se rejoue** ; son revers aussi — un retrait que la phase
refuse ne rend rien, sans quoi un clic droit dans la mauvaise phase serait une source de
cartes gratuites.

**Et un second défaut est tombé avec, que personne n'avait signalé.** Le harnais garde un
**rang** dans la main, jamais un identifiant — la leçon de `D2`. Une carte rendue s'insère
dans son pool et décale tout ce qui suit : tenir une carte de bâtiment et retirer une
action changeait donc silencieusement ce qu'on tenait. `_play_here()` reposait déjà la
sélection pour cette raison exacte ; `_withdraw_here()` le fait maintenant aussi.

### Ce qui reste

- **l'affectation persistante d'une phase à l'autre** — la troisième mitigation de 3.4.
  Elle touche au vidage du board et au sort de la main non jouée, qui est l'`OUVERT` de
  3.5 : c'est `I2b`, sur un `.tres`.
- **le recrutement** — `OUVERT` de 3.4. Le panneau affiche « 6/12 places » ; ce qui les
  remplit n'existe toujours pas.
- **`X5`** — le niveau se gagne et se lit sur la fiche, il n'ouvre rien.
- **le libellé français d'une famille.** La fiche affiche « Harvest » et « Construction »,
  parce qu'aucune famille n'est déclarée nulle part : 3.4 pose que la liste n'est pas close
  et qu'aucun code ne l'énumère. Écrire une table identifiant → libellé dans une vue
  rouvrirait l'énumération que la Construction a pu rejoindre sans une ligne de GDScript à
  `I1`. Le jour où ça comptera, ce sera un champ de `.tres`.
- **la sortie sous `scenes/ui/`** — `I2`, comme les trois vues de `E2`. C'est là aussi que
  la borne de trois lignes du panneau devra être traitée pour de bon.

**Repères d'équilibrage** : la capture au jour 8 montre une famine à 5 ouvriers à jeun et
une réserve à 29 — deux récoltes par jour pour un seul upkeep n'ont pas suffi. Et les
paliers sont lents à voir : quatre XP par poste, vingt-cinq par palier, donc sept soirs de
travail dans la même famille pour le premier cran.

---

## 2026-08-26 — `E2` : la réserve regardable, et le mensonge qu'un écran a trouvé

**État : terminé.** Six commits sur `master`, **589 tests verts contre 585**. Premier jalon
d'écran du projet. `CommodityPalette`, `ResourceBar`, `ProductionPanel` sous
`src/adapters/hud/` ; `CommodityData` gagne un `order` ; `RunOrchestrator` relève la
réserve dès qu'un chantier d'entrepôt est achevé. `hud_harness` neuf, `run_harness` allégé.
**Aucun DTO de `contracts/` créé ni modifié** — c'est la première chose à dire du jalon.

### Ce qu'un jalon d'écran n'a pas à écrire

Le plan tenait en une ligne qui a décidé de tout le reste : **aucun DTO de `contracts/` ne
bouge**. Deux vues qui lisent un `Ledger` et un `PhaseReport` ne franchissent aucune
frontière neuve — `CLAUDE.md` pose depuis `I1` que le critère d'entrée est un second
**système du domaine**, pas un adapter. Un `LedgerSnapshot` aurait été le geste réflexe, et
il aurait figé une forme que personne ne traverse.

Corollaire assumé : **peu de tests**. `src/adapters/` n'est pas testé, et un jalon dont le
contenu est trois `Control` n'a pas à inventer du domaine pour se donner de quoi tester.

### La jauge est unique, et c'est tout le sujet

`E1` a tranché pour une **réserve commune** : cent unités partagées. Depuis, c'était une
règle de résolution que rien ne montrait. Quatre jauges côte à côte auraient dessiné quatre
plafonds indépendants, c'est-à-dire exactement la lecture que `E1` a écartée — et la phrase
de 3.3, « un joueur qui ne la voit pas ne comprend pas pourquoi son entrepôt manque »,
serait restée une intention. Une seule barre segmentée où le bois qui monte pousse la place
de la pierre est la décision de `E1` rendue regardable.

Deux détails d'affichage qui sont des décisions, pas de la mise en forme. **Les quatre
colonnes ne bougent jamais**, même à zéro : une ressource qui apparaîtrait le jour où l'on
en gagne la première unité ferait glisser ses voisines sous l'œil. Et **le reste de la
division va à la place libre**, jamais à une ressource : lui donner un pixel de plus ferait
mentir la seule barre qui compte, celle qui dit s'il reste de la place. Une réserve pleine
n'a donc aucune place libre à l'écran, pas même d'un pixel.

### Le mensonge d'une phase, que seul un écran pouvait trouver

**C'est le vrai apport du jalon, et il n'était pas au plan.**

`ProductionResolver.resolve()` pose la capacité de la réserve, puis `_apply()` achève les
chantiers. Un entrepôt fini ce soir ne relevait donc la réserve qu'**au soir suivant** :
entre les deux, un bâtiment visiblement terminé sur la carte cohabitait une phase entière
avec une jauge annonçant l'ancien plafond.

Personne ne l'avait vu, et pour une raison qui vaut d'être écrite : **aucun écran
n'affichait la capacité en continu**, et la résolution suivante la reposait de toute façon.
**Un mensonge qui se corrige tout seul reste un mensonge le temps qu'il dure.** Le harnais
Économie contournait d'ailleurs la même chose depuis `E1`, en reposant la capacité à la
main, et son commentaire renvoyait la question « là où le HUD de `E2` le fera aussi ».

Elle n'a pas été faite là. Un adapter qui appellerait `Ledger.set_capacity()` serait la
faute d'architecture que `CLAUDE.md` refuse en premier. C'est `RunOrchestrator` qui relève
la réserve, juste après avoir appliqué les chantiers, parce qu'il est le seul à tenir la
ville et la bourse. **La règle d'ordre de `I1` ne bouge pas d'un pouce** : la production
est déjà calculée quand le plafond monte, donc un entrepôt achevé ce soir ne sauve toujours
pas la récolte de ce soir. Ce qui change n'est pas la résolution, c'est ce que l'écran
raconte entre deux.

### Le test de `I1` qu'il a fallu réécrire, et pourquoi ce n'est pas un recul

`test_a_warehouse_finished_tonight_only_raises_the_cap_tomorrow` affirmait exactement ce
que la correction change. Son docstring justifiait la **règle** — la récolte du soir n'est
pas sauvée — mais son assertion portait sur un **effet de bord** : que le compteur vaille
encore 100 à la fin de la phase. Les deux ne sont pas la même affirmation, et `I1` les a
confondues parce que la seconde était la seule chose observable à l'époque.

Le cas remplit désormais la réserve à ras bord avant de résoudre : la récolte du soir n'a
nulle part où entrer, et elle est visiblement perdue alors même que l'entrepôt s'achève.
C'est **plus fort** que ce que `I1` pouvait épingler.

Réécrire un test qu'un jalon précédent a délibérément écrit, docstring argumentée à
l'appui, mérite d'être signalé plutôt que fait en passant. La question à se poser était :
**est-ce que je casse la règle, ou est-ce que je casse l'observation qu'on en faisait ?**
La réponse était la seconde.

### L'ordre des ressources, ou le troisième `_bundle_text()` évité

`run_harness._bundle()` et `economy_harness._bundle_text()` étaient la même fonction écrite
deux fois, et un panneau de production en voulait une troisième. C'est exactement le
problème que `I1` note à propos du `_make_label()` à neuf exemplaires : « elle n'appartient
à aucun jalon, ce qui est précisément pourquoi elle ne se fait jamais ». Celle-ci
appartenait à celui-ci — afficher un lot de ressources *est* le sujet.

`CommodityPalette` les remplace, et donne au passage un foyer à une question que personne
n'avait posée : **dans quel ordre affiche-t-on les ressources ?** Les deux copies triaient
par identifiant, donc en anglais interne, ce qui rangeait la nourriture — celle qui tue —
entre le minerai et la pierre. Le rang vit désormais sur la `CommodityData`, parce que la
seule alternative était une liste d'identifiants dans un `.gd` : le nombre magique que les
conventions refusent, et que 3.3 refuse nommément en sortant l'ensemble des ressources de
l'énumération du code.

Il commence à **1** et non à 0 : un champ non renseigné vaut 0, et un rang 0 légitime
aurait rendu l'oubli indétectable. Un cas de test tient le seul vrai piège du champ — deux
ressources ne partagent pas un rang, sans quoi leur ordre retomberait sur une comparaison
de `StringName`, stable le temps d'une session et différente à la suivante.

### L'`OUVERT` refermé : les oisifs restent un compte

`production_report.gd` portait la question depuis `E1`, renvoyée à « ce que E2 tranchera
devant une vraie maquette ». Trois raisons se cachaient derrière un seul chiffre : non
affecté, affecté à une ancre vide, arrivé quand les slots étaient pris.

Devant la maquette, la réponse est **non**. Au niveau de la phase les trois s'effondrent de
toute façon en « n'a tenu aucun poste », qui est la seule lecture juste depuis `I1`. Et les
séparer aurait demandé au résolveur de tracer une information que le joueur voit **déjà**
sur le plateau avant de résoudre, donc au moment où il peut encore agir. **Un chiffre qu'on
ne peut plus corriger n'a pas besoin de trois colonnes.**

### Ce que le panneau lit, et ce qu'il refuse de lire

Il prend un **`PhaseReport`** et non un `ProductionReport`, alors que le jalon s'appelle
Économie. `I1` a trouvé que le rapport de production compte comme oisif un ouvrier parti
bâtir, et que seul le rapport de phase voit les deux journaux de travail. Un panneau qui
lirait le second réintroduirait le mensonge que `I1` a diagnostiqué, et il le
réintroduirait en grand, à l'écran.

Il **ne nomme pas** qui a franchi un palier : le faire demanderait le `Roster`, la
dépendance que `W2` existe pour porter.

Le libellé de la phase lui est **fourni** plutôt que lu. Un `PhaseReport` porte
l'identifiant de sa phase et non son libellé, et au moment où `phase_resolved` arrive le
cycle a déjà avancé. Le harnais, lui, connaît celle qu'il finit — il la retient avant
d'appeler `end_phase()`. Aucun nom de phase n'est écrit nulle part, ce que `DESIGN.md` 2
exige jusque dans les adapters.

### Les deux pièges de mise en page, trouvés en capture l'un après l'autre

**Premier piège.** `set_anchors_preset()` prend un **booléen** en second argument, là où
`set_anchors_and_offsets_preset()` prend un `LayoutPresetMode`. Lui passer
`PRESET_MODE_MINSIZE` revient à lui dire « garde tes décalages », donc à laisser la vue à
la taille qu'elle avait — zéro, la mise en page n'ayant pas encore tourné. Un
`PanelContainer` de taille nulle **ne dessine pas son fond** pendant que ses libellés
débordent par-dessus la carte.

**Second piège**, qui survit à la correction du premier : `get_combined_minimum_size()` lu
juste après avoir ajouté des enfants rend encore la valeur d'**avant**, Godot la
recalculant à la passe suivante. Le panneau se plaçait donc sur la taille du rapport
précédent, ce qui n'aurait été visible qu'au deuxième rapport d'une session.

La correction n'est pas un calcul plus fin, c'est **l'abandon du calcul** : un
`MarginContainer` plein écran dont l'enfant porte `SIZE_SHRINK_BEGIN` ou `SIZE_SHRINK_END`
ne se trompe sur aucun des deux, et ne se trompe pas davantage à la dixième mise à jour du
contenu. C'est écrit dans `CLAUDE.md`.

### Ce que le harnais Run perd, et pourquoi c'est le vrai livrable

Le jalon aurait pu ajouter deux vues et laisser le pavé de texte tranquille. Il en a retiré
deux morceaux à la place : la réserve sort du bandeau, le compte rendu de résolution
disparaît entièrement.

Garder les deux aurait laissé **le même chiffre lisible à deux endroits**, et un chiffre
affiché deux fois est un chiffre qui finira par différer de lui-même. La capture ne vérifie
qu'une seule des deux mises en forme ; l'autre dérive en silence. Pour la même raison, la
capture du harnais Run n'imprime plus le rapport du soir — elle imprime la réserve
chiffrée, qui est ce qu'aucune image ne rend lisible d'un coup d'œil et la seule preuve que
la bourse a été débitée.

### Le harnais qui fabrique ses cas

Le harnais Run montre les deux vues **en situation**. Ce qu'il ne peut pas montrer, c'est à
quoi elles ressemblent quand ça va mal : une réserve pleine qui gaspille, une famine, une
journée qui ne se ferme pas. Un run met une dizaine de journées à y arriver, et une capture
ne sait pas attendre.

`hud_harness.gd` **fabrique** donc ses cinq scènes au lieu de les jouer, sur le même
principe que le harnais Économie cherche le soir où l'économie casse. Il n'y a **pas de run
ouvert** derrière — ce qui est aussi le contrôle que les deux vues ne lisent rien d'autre
que ce qu'on leur donne. Il réutilise `--shot-evenings` pour désigner la scène plutôt que
d'inventer un neuvième drapeau : seul harnais où ce drapeau ne compte pas un temps mais un
cas, ce que `dev_shot.gd` permet en posant que chaque harnais ignore ceux qui ne le
concernent pas.

### Ce qui reste

- **la prévisualisation de ce qu'une action posée rapporterait.** C'est `C3` : le calcul de
  delta au survol vient avec l'adjacence, et l'écrire ici demanderait au résolveur une
  porte « à blanc » qu'aucun jalon n'a réclamée.
- **la sortie sous `scenes/ui/`.** Les trois vues restent construites en code, comme
  `HandView` depuis `D2`. Elles déménageront quand `I2` fera un vrai écran, et elles
  déménageront avec leur mise en forme : elles n'ont pas de règles à emporter.
---

## 2026-08-25 — `I1` : la journée, la bourse, et les deux verbes enfin exécutés

**État : terminé.** Dix commits sur `feat/d1-deck`, à la suite de `D2` — dont deux qui
corrigent le jalon lui-même, l'un venu d'une partie jouée au clavier et l'autre d'une
décision de design que j'avais prise seule. **585 tests verts contre 467.**

`PlayResult`, `SiteReport`, `PhaseReport`, `DayReport` dans `domain/run/` ; `UpkeepReport`
dans `domain/economy/` ; `PlayedAction` et `TargetResult` gagnent un **sens**,
`ProductionReport` perd son upkeep. `PhaseDef` et `RunBalance` ; `DayCycle`, `RunState`,
`SiteResolver`, `RunOrchestrator`. `RunManager` réécrit, trois signaux sur `EventBus`,
`run_harness.gd`. `DESIGN.md` 2, 3.2, 3.3, 3.4, 3.5, 3.8, 4.1, 4.2 et 8.

### La décision qui porte le jalon : ordonner plutôt que muter

`D2` avait laissé *Construire* et *Terraformer* se poser et s'affecter sans rien faire :
leur effet mute le `CityState` et la `HeightGrid`, donc l'état de deux autres systèmes, et
un résolveur d'Économie qui les muterait violerait la règle de dépendance.

`SiteResolver` **ordonne** — tant de crans sur cette ancre, tant de hauteur sur cette
cellule — et ne touche à rien ; `RunOrchestrator` **applique**, parce qu'il est le seul
objet du projet à tenir les deux états à la fois, ce que `DESIGN.md` 3.8 autorise
nommément. Le résolveur reste aussi pur que son jumeau, et il n'a même pas besoin du
terrain : un terrassement rend un delta. Bénéfice non prévu : **un soir devient
rejouable** — appliquer deux fois le même rapport au même état donne le même état.

### Quatre questions arbitrées avant d'écrire

**Le sens d'un terrassement se choisit à la pose**, comme l'orientation d'un bâtiment
appartient au placement et non à sa `BuildingData`. Prix annoncé avant d'être payé : deux
DTO de `contracts/` changent de forme. L'alternative — deux cartes en data — ne coûtait
aucun contrat mais faisait dépendre d'un tirage la correction d'un relief. **Une carte
qu'on oriente vaut mieux qu'une carte qu'on subit.**

**La piste que crédite un chantier est une quatrième famille** — l'`OUVERT` de 3.2 traînait
depuis `C4`. La plus chère des trois issues, pour la bonne raison : bâtir doit être un
métier. Le coût réel s'est révélé nul, **rien dans le code n'énumère les familles** : les
pistes se créent à l'usage, le nom vit dans `data/balance/`.

**Ce que ce multiplicateur multiplie**, question que la précédente a immédiatement ouverte
— sans réponse, la piste aurait accumulé de l'XP que rien ne consomme. Les crans d'un soir
sont la **somme des efficacités de l'équipe, tronquée, plafonnée à ce qu'il reste à
bâtir** : même arithmétique que la production, et le plafond figé à la pose n'est jamais
dépassé.

**L'eau et le rocher ne se terrassent pas**, pour une raison mécanique et non thématique :
terrasser déplace la **hauteur**, pas le `TerrainData`. Monter une case d'eau la laisserait
eau — inconstructible, toujours tagguée — pour le prix d'une carte et d'un ouvrier. Changer
le sol sera un *Défricher*, et c'est un autre verbe.

### Le modèle de journée — une décision prise seule, et qu'il a fallu défaire

**C'est la faute de méthode du jalon.** La première version en data suivait la lettre de
`DESIGN.md` 2 et donnait une seconde phase qui n'autorisait rien et résolvait à sa fin :
**deux validations pour un soir**, une pour entrer dans une phase où il n'y a rien à faire,
une pour en sortir. Défaut réel, invisible aux tests, qui ne se voit qu'en essayant de jouer.

J'ai corrigé le mauvais bout. Au lieu de rendre la seconde phase permissive elle aussi,
j'ai **séparé les deux gestes** — une phase pour poser les cartes, une pour y envoyer les
ouvriers — et je l'ai annoncé en une phrase au passage au lieu de m'arrêter. C'était une
question de design, pas une correction technique, et la consigne de session dit en toutes
lettres de ne jamais en trancher une seul.

La journée voulue est le **modèle symétrique** : deux phases identiques, chacune autorisant
les deux gestes et se résolvant à sa fin — elle ne souffre d'ailleurs pas du défaut que je
cherchais à éviter. Le coût de la correction dit quelque chose sur ce qui avait été bien
fait : **le code n'a rien eu à changer.** Le harnais lit ce que la phase autorise, il ne le
suppose pas ; les tests fabriquent leurs propres journées et vérifient le *mécanisme* de
garde. C'est un `.tres` qui a bougé.

### Ce que la correction a révélé : une journée compte deux résolutions

Deux phases qui résolvent, c'est deux récoltes par jour. Mais on ne mange pas deux fois
parce qu'on a récolté deux fois, et l'upkeep vivait dans le rapport de production depuis
`E1`. Ce n'était pas visible tant qu'une journée n'avait qu'un soir : production et upkeep
tombaient forcément ensemble, et cette **coïncidence avait été prise pour une règle** —
`DESIGN.md` 2 les listait pourtant depuis le premier jour comme deux étapes distinctes.

- une **phase** produit — ce que les actions posées rapportent, les chantiers, l'XP ;
- une **journée** coûte — l'upkeep, et demain l'événement de 3.7 et le combat de `F1`, qui
  entreront par un champ chacun sur `DayReport`.

Sans cette séparation, la structure de la journée deviendrait inséparable de son
équilibrage : passer de deux phases à trois obligerait à rééquilibrer la nourriture, et
l'`OUVERT` de 2 cesserait d'être testable en échangeant un `.tres` — c'est-à-dire qu'il
cesserait d'être ouvert. `ProductionReport` perd quatre accesseurs au profit d'un
`UpkeepReport` (contrat qui change de forme, annoncé et validé cette fois) ; `EveningReport`
devient `PhaseReport`, « soir » ne désignant plus une phase mais la fin de journée.

**La fin de journée n'est pas un champ de data**, seul endroit du jalon où j'ai refusé d'en
ajouter un : une journée se ferme après sa dernière phase, par définition, et un booléen
pourrait dire le contraire de la liste qui le porte. Elle est aussi indépendante de
`resolves` — une journée coûte à nourrir même si sa dernière phase ne produit rien.

### Deux endroits où j'ai changé une règle du projet plutôt que de la contourner

**`ActionTargeting` n'est plus le seul fichier qui nomme des cartes**, `SiteResolver` en
ouvre un second. Ce n'est pas une entorse : **où** un verbe se pose et **ce qu'il fait**
sont deux questions, la seconde étant exactement celle que 4.2 refuse de mettre en data. La
garantie « un seul fichier » est remplacée par une plus forte et **vérifiée** : tout verbe
que le ciblage accepte est soit productif selon `data/balance/`, soit exécuté par le
résolveur de chantiers — un cinquième verbe ne peut plus se poser, s'affecter et ne rien
faire, ce qui était l'état de deux d'entre eux entre `D2` et `I1`. Un second cas tient le
revers : aucun verbe n'est les deux à la fois, sans quoi une carte compterait double.

**Les trois rapports du run ne sont pas des contrats.** `PhaseReport` porte un
`ProgressReport`, interne aux Effectifs : le mettre dans `contracts/` l'y aurait fait entrer
par la porte de derrière. Même argument que `PickResult` — le critère est un second
**système du domaine**, pas un adapter.

### Le piège que les tests ont attrapé, et celui que le clavier a trouvé

**`ProductionReport.idle()` s'est mis à mentir.** Le rapport de production ne connaît que
les postes de production : dès que les chantiers s'exécutent, un ouvrier parti bâtir y
figure comme **oisif**. Les deux lectures sont chacune juste dans leur système et fausses
dans la journée. Le corriger sur place aurait demandé au résolveur d'Économie de recevoir
un rapport qu'un autre système produit ; c'est `PhaseReport.idle()` qui répond pour la phase
entière, seul à voir les deux journaux de travail. Un cas de test épingle les deux lectures
côte à côte : le bâtisseur est oisif dans l'une et pas dans l'autre, et c'est voulu.

**Le rappel des ouvriers au retrait d'une action ne s'exécute jamais avec la journée
livrée** — on ne revient à une phase qui pose qu'après une résolution, qui a déjà tout vidé.
Ce n'est pas du code mort : il s'allume dès qu'une journée laisse poser et affecter dans la
même phase, donc dès qu'un `.tres` change. Le cas construit donc sa propre journée, ce qui
est aussi un rappel qu'une journée est de la data.

**Le défaut que seul le clavier a trouvé — un refus sans cause.** *(Trouvé par l'humain
juste après le jalon.)* Espace sur une action posée répondait « refusé » sans dire pourquoi.
La cause était entière et légitime — la phase Construction n'autorise que *poser*. Le refus
était juste ; c'est le silence qui ne l'était pas. L'origine est une justification écrite un
peu vite : `staff()` rendait un booléen nu, « les quatre refus possibles se voyant tous à
l'écran avant le clic ». Vrai à la lettre, faux à l'usage — rien ne reliait le bandeau à une
touche qui ne répond pas, et **un refus qui ne se nomme pas est indiscernable d'une
panne**, exactement le diagnostic de `D2` sur les touches 4 et 5. La correction ne rajoute
pas un DTO : `staffing_refusal()` devient le **seul juge** des cinq refus, `staff()`
l'appelle et l'écran aussi pour traduire — même partage que le fantôme de `C2` et la pose.

Deux jalons de suite, le défaut que ni le parsing, ni les tests, ni une capture n'ont vu est
venu d'une paire de mains. **Le harnais ne se juge pas en le lisant.**

### Le cas qui rend vraie une promesse de `I0`

`CLAUDE.md` promet depuis le premier jour qu'« un seed plus une liste d'actions doit rejouer
un run à l'identique ». Rien ne pouvait le vérifier, faute d'un objet qui tienne un run
entier. Deux runs sur le même seed, la même suite de gestes sur deux journées, comparaison
de la réserve, des hauteurs, de l'avancement, de l'XP et de la main. Un second cas tient le
revers : un seed différent ne rejoue pas la même partie — sans lui, le premier passerait
tout aussi bien sur un run parfaitement déterministe et vide.

C'est ce qui a décidé que **`RunState` porte son équilibrage** au lieu de le recevoir à
chaque appel, à l'inverse de tout le reste du domaine : un run ne rejoue que s'il rejoue sur
les chiffres avec lesquels il s'est ouvert. Même geste que `Deck`, qui garde son catalogue.

### Ce que la capture a montré

Deux journées jouées en ligne de commande : un chantier ouvert et **payé**, avancé de deux
crans et achevé, une cellule terrassée de +1, six postes tenus, aucun oisif, réserve à
39/100. Première capture du projet où le contrôle porte sur un *enchaînement* et non sur une
image — le rapport imprimé est la seule preuve que la bourse a été débitée. Elle a aussi
confirmé par sonde que le bâtiment au centre n'était pas le Cœur : celui-ci est en (15, 14),
premier emplacement 2×2 plat depuis le centre, **achevé d'office** parce que son
`build_actions` vaut 0 — ce que 4.1 annonçait à `C4` sans avoir pu le vérifier.

**Report notable** : l'équilibrage des ressources devient le premier chantier ouvert. Deux
phases qui résolvent, c'est **deux récoltes par jour pour un seul upkeep** — l'économie est
nettement plus généreuse qu'à `E1b`, qui mesurait un soir par jour. Sciemment laissé en
l'état, le verdict du harnais Économie restant calibré sur l'ancien rythme.

---

## 2026-08-25 — `D2` : les deux gestes, la clé de l'affectation, et un bug trouvé en image

**État : terminé.** Cinq commits sur `feat/d1-deck`, à la suite de `D1`. **467 tests verts
contre 396.** Contrats : `PlayedAction`, `ActionPlan`, `TargetResult`, `Assignment`
**rekeyée** sur l'action posée, `CitySnapshot` gagne son index par cellule. Domaine :
`ActionBoard`, `ActionTargeting`, `ProductionResolver` réécrit. `ActionBalance`.
`TargetHighlight`, `ActionMarker`, `HandView` — premier dossier `src/adapters/deck/`.
`deck_harness.gd` réécrit : plus un rapport, une scène.

### La décision qui porte le jalon : la carte n'est pas l'ouvrier

`DESIGN.md` 8 annonçait que jouer une carte produirait un `Assignment` — donc un geste
**atomique**. `D1` avait repéré en conversation que c'était faux et avait laissé la question
ouverte exprès.

Si une carte valait un ouvrier, cartes et ouvriers se **doubleraient** : chaque action en
consommant une de chaque, la contrainte réelle deviendrait `min(cartes, ouvriers)`, ce que
3.4 refuse en toutes lettres — « deux contraintes qui se croisent, et non deux ressources
qui se doublent ». Le flux compte donc deux gestes : on joue la carte **sur une cible**, ce
qui pose une action ; puis on y affecte **des** ouvriers. Cet objet manquant porte trois
choses figées à la pose : son identité, sa cible canonique, et sa **capacité**.

**À quoi un ouvrier s'affecte-t-il ?** Garder la **cellule** comme clé ne changeait aucun
contrat et laissait le résolveur intact — mais tranchait « une case fait une chose par
phase » par une structure de données, alors que `DESIGN.md` ne le dit nulle part.
*Terraformer* et *Récolter* peuvent viser la même case nue, *Récolter* et *Chasser* la même
forêt. L'**identité propre** a été retenue : elle coûte la rekeyage et la réécriture du
résolveur, et c'était le dernier moment où ça se payait peu. Elle rend les doublets
*représentables* ; les interdire reste possible plus tard comme règle explicite du
validateur, et l'inverse n'aurait pas été vrai.

### Ce que la rekeyage a rendu vrai

`DESIGN.md` 2 dit depuis le début que « la production n'est plus une étape passive qui
balaye les bâtiments : c'est le résultat des actions que le joueur a posées ». **Ce n'était
pas vrai.** Le résolveur de `E1` balayait les ancres de l'affectation et servait le
rendement du bâtiment qu'il y trouvait, sans qu'aucune carte n'ait eu à être jouée. Il part
maintenant du plan : rien ne produit qui n'y figure.

Le contrat de 3.3 gagne deux entrées. L'`ActionPlan` est le pilote ; le `TerrainQuery` vient
avec la seconde lecture de 3.5 — une action à cru rend ce que le **tag de sa cellule**
dicte, donc l'Économie doit voir le relief. Elle voit le contrat, jamais la grille.

**Le témoin que la réécriture n'a rien cassé** : les 396 tests sont restés verts, et les
harnais Économie et Effectifs impriment **exactement** ce qu'ils imprimaient avant — mêmes
récoltes, mêmes famines, mêmes paliers d'XP, soir par soir. Le pilote a changé, pas
l'arithmétique.

### Décisions

**Le résolveur n'écrit aucun nom de carte.** Les deux lectures de 3.5 posent chacune leur
question à `data/balance/` : « cette carte tient-elle un poste ? » dans un bâtiment, « cette
carte tire-t-elle quelque chose de ce tag ? » à cru. *Construire* et *Terraformer* répondent
non aux deux et sortent de la production **structurellement**, sans être nommés, de sorte
qu'un cinquième verbe entre sans qu'on ait à venir l'exclure d'une liste.

**Les noms de verbes vivent en un seul endroit**, `ActionTargeting` — 4.2 pose qu'une nature
d'action est du code. Un cas de test charge `data/cards/` et exige que toute carte du pool
des actions y ait une règle, de sorte qu'une cinquième entrée sans règle de ciblage fasse
tomber la suite au lieu de se poser nulle part.

**`CitySnapshot` a reçu son index par cellule**, dont son docstring disait qu'on n'ouvrirait
pas la porte tant que personne ne la pousserait : on désigne un coin de la ferme, on vise la
ferme. Il ne coûte **aucune entrée de plus** au contrat. **La cible est canonicalisée par le
ciblage** et non par l'adapter — le faire dans la vue aurait laissé passer deux actions qui
se croient différentes.

**`WorkLine` n'a pas bougé de forme** : son `Vector2i` cesse d'être « l'ancre du bâtiment »
pour devenir « la cellule du poste », et l'accesseur est renommé `cell()` — `anchor()` aurait
menti sur toute action à cru.

**Le résolveur fait deux passes sur le plan** — lignes de travail, puis rendements. Une ligne
de travail ne porte que sa cellule, et deux actions peuvent viser la même : repartir des
lignes obligerait à retrouver de quelle action chacune vient. Les deux passes posent les
mêmes questions aux mêmes fonctions pures sur les mêmes entrées.

**La capacité voyage figée sur l'action** — la relire depuis la ville au moment de résoudre
aurait rouvert la porte à ce que l'écran promette trois postes et que le soir n'en serve
que deux.

### Trois défauts, trois contrôles différents

**Les tests.** Sur un bâtiment, le résolveur ne posait qu'une question — « ce bâtiment
produit-il ? » — si bien que **toute** action posée sur une ferme achevée en tirait une
récolte, *Construire* comprise. Le ciblage l'interdit aujourd'hui, mais faire reposer la
justesse du soir sur une règle écrite dans un autre système est la dette que `I1` aurait
payée. `ActionBalance` nomme désormais les cartes qui tiennent un poste. Vérifié de la seule
façon qui vaille : retirer la garde, regarder le test tomber, remettre la garde.

**La capture.** Le harnais avait posé deux *Récolter* sur une même cabane à deux postes et y
avait mis trois ouvriers. Une carte ouvrait les postes de sa cible **à chaque fois qu'elle
était jouée** : la jouer deux fois doublait le bâtiment, et la carte cessait d'être une
permission pour devenir un multiplicateur. Ce bug ne se lisait ni dans l'image ni dans les
tests, mais dans la **table des actions posées** que la capture imprime — premier jalon où
ce que le harnais dit est un défaut de règle et non un chiffre d'équilibrage.

**Le clavier, et il fallait un humain.** Les touches 4 et 5 « ne sélectionnaient pas ».
Elles étaient parfaitement liées : la sélection portait sur l'**identifiant** de la carte
tenue, et une main tient couramment deux exemplaires du même nom — les presser retombait sur
la carte déjà tenue, ce que le code interprétait comme « on la repose ». La sélection porte
désormais sur le **rang** ; le docstring d'origine défendait l'identifiant en disant qu'un
rang ne survivrait pas à une repioche, et la robustesse annoncée n'existait pas. Les cartes
se prennent aussi au **clic** — une main peut tenir plus de neuf cartes.

### Ce que le harnais est devenu

Le rapport texte de `D1` a disparu, remplacé par la scène — le geste exact que `C2` a fait
sur `C1`. C'est le seul harnais où une **phase entière** se joue, et le premier à composer
**trois** systèmes du domaine.

Deux corrections sont venues de deux captures successives, et aucune n'est un bug de code.
La première ne montrait **rien** : les bâtiments s'étaient posés au coin de la carte, là où
le rapport texte les recouvre, et la carte jouée était la seule de son nom en main, si bien
qu'aucune cible ne restait allumée. La seconde résolvait trois soirs qui ne produisaient
rien, parce que le script de capture ne posait qu'un *Construire*. **Un contrôle par l'image
qui ne montre pas ce que le jalon ajoute ne contrôle rien.**

**Constat de contenu, consigné en 4.2** : `data/terrain/` ne contient aucun filon, alors que
3.1 le liste avec le tag `ore`. La règle de récolte à cru le nomme et n'a donc pas de cible
sur une carte réelle ; le minerai ne s'obtient qu'à la mine.

---

## 2026-08-25 — `D1` : trois pools, un mélange qui ne triche pas, et ce qu'un draft coûte

**État : terminé.** Cinq commits sur `feat/d1-deck`, **396 tests verts contre 324**.
`CardData` et `DeckBalance` ; **seize `.tres`** dans `data/cards/` ; `CardCatalogue`,
`CardShuffle`, `Deck`, `Hand`, `DraftPool` ; sept suites, 72 cas neufs ; `deck_harness.gd`.

### Deux arbitrages avant d'écrire

**La colonne « Débloque » de 4.1 est reportée**, alors que ce même tableau l'annonçait pour
`D1`. Les trois actions qu'elle concerne portent `MVP : non` en 4.2, et leurs systèmes sont
`X1`, `X2`, `X3` : en les laissant hors du catalogue, il **n'y a rien à débloquer** — le
champ n'aurait aucun lecteur, et la requête serait une frontière que personne ne franchit,
motif exact qui a sorti `CombatForce` de `W1`. Prix du report chiffré avant d'être pris : un
champ, trois `.tres`, une quatrième lecture de `CitySnapshot.completed()`.

**Le pool est un `StringName` et non un `enum`**, contre la convention générale. Un `enum`
non renseigné vaut 0, donc `&"action"` **en silence** : la doctrine du zéro perdrait sa
prise sur le seul champ qui décide de tout le classement d'une carte, alors qu'un `&""` se
détecte. Et un pool n'est pas un état en mémoire, c'est un identifiant écrit dans `data/`,
où la convention est déjà le `StringName`. L'ensemble reste fermé : `CardData.POOLS` le
tient, et `missing_fields()` refuse tout ce qui n'y est pas.

### La décision qui porte le jalon : le Deck ne décide de rien

**Il ne juge aucune jouabilité.** 3.5 dit qu'un jeu de carte est une *intention* que le
système concerné accepte ou refuse. Le Deck ne connaît ni la grille, ni la bourse, ni le
placement : il n'y a pas de verbe `play()`, `discard()` suffit et ne ment pas.

**Il ne décide d'aucun moment.** Les trois tailles de main vivent dans `data/balance/`, et
*quand* on pioche appartient à la journée, donc à `I1`. `discard_hand()` est une **capacité
et non une politique**. Ce second refus est ce qui laisse entier l'`OUVERT` de 3.5 — le sort
de la main non jouée : un `Deck` qui aurait pris l'habitude de défausser tout seul en fin de
phase aurait tranché la question sans que personne ne le décide, et la trancher dans du
GDScript l'aurait rendue coûteuse à retester.

### Ce que le harnais a trouvé, et ce qu'il a fallu jeter

Un chiffre juste, un faux, un inutile — **et le tri entre les deux derniers est tout le
travail.**

**Le faux.** La première version mesurait le cycle de la pioche en divisant les phases
jouées par le nombre de remélanges, et sortait 2,7 là où le régime établi est 2 : les
premières phases d'un run vident une pioche pleine sans jamais la recycler. **Un chiffre qui
dépend de l'endroit où l'on commence à compter ne mesure rien.**

**L'inutile.** Une fois juste, il s'est révélé **muet** : il vaut deux phases que le pool en
tienne dix ou quatorze, parce qu'une pioche qu'on vient de recharger garde toujours de quoi
faire exactement une main de plus. Il dit quelque chose de vrai sur les piles et rien sur le
jeu. Remplacé par la question que le design pose vraiment : au bout de combien de phases une
main **revoit** la carte qu'on attend.

**Le juste, et il répond à une question de design.** Sur deux cents seeds, **7,8 % des
phases n'offrent aucune carte *Construire***. Et surtout : après quatre drafts pris au
hasard dans l'offre, ce chiffre monte à **11,2 %** et le délai de retour de 1,07 à 1,11
phase. **Grossir son deck le rend moins fiable.** Classique du deckbuilder, mais mesuré sur
les chiffres réels de `data/` — et il dit ce que `I3` devra équilibrer : si drafter est une
récompense, il faudra que ce qu'on gagne compense ce que la dilution coûte.

Premier harnais où c'est un **échantillon** qui parle et non un run : une fréquence lue sur
un seul seed n'aurait rien valu.

### Ce que la commande 2 a rattrapé, et que la commande 1 n'a pas vu

`CardShuffle` ne compilait pas — `var held := mixed[index]` sur un `Array` typé ne s'infère
pas. Le boot est passé **sans un mot** : rien à ce moment-là ne chargeait le fichier, et son
code de sortie valait 0. C'est exactement le piège que `CLAUDE.md` documente, et la première
fois qu'il se manifeste pour de vrai. **Trois commandes, pas une.**

### Décisions

**`CardShuffle` a son propre fichier, pour une seule fonction.** `Array.shuffle()` tire sur
le RNG global de Godot et non sur celui du run : un deck mélangé par lui rendrait un même
seed non rejouable, sans rien signaler. Le piège devait être évité à deux endroits, et une
règle qu'on recopie est une règle qu'on oublie à la troisième occurrence. Le cas de test
reseede le générateur global entre deux mélanges et exige le même ordre — le seul cas qu'un
`Array.shuffle()` échouerait, donc le seul qui protège vraiment.

**Le RNG est un argument, jamais un membre.** Un Deck qui garderait le sien serait un second
flux à seeder, donc un second endroit où un run cesserait d'être rejouable. Choix inverse de
`TerrainGen`, qui prend un seed et le sale, et la différence se justifie : une génération est
un tirage isolé qu'on ne veut pas corréler, une pioche est un événement du run.

**`create()` ne mélange pas** — composer un deck reste sans aléatoire, donc assertable sans
rng. **Une carte draftée entre par la défausse** : elle ne doit pas s'intercaler dans une
pioche entamée et passer devant des cartes qui attendaient depuis deux phases. **`remove()`
cherche dans un ordre fixé** — pioche, défausse, main : arbitraire, mais un retrait qui
dépendrait de l'endroit où la carte se trouve ferait diverger deux runs partis du même seed.

**Les tailles de main sont une table et non trois champs plats** : c'est ce qui rend le zéro
du pool des powers écrivable *et* un pool oublié détectable — la présence de la clé vaut
déclaration. Même geste que le bloc nullable de `E1b`, appliqué à un dictionnaire.

**`list_card_ids()` trie, et ça compte plus ici qu'ailleurs** : c'est dans cet ordre que le
catalogue reçoit les cartes, et cet ordre que les offres de draft mélangent — un catalogue
chargé dans l'ordre d'un `DirAccess` tirerait différemment d'une machine à l'autre sur le
même seed.

**Une carte de bâtiment nomme son bâtiment**, même quand c'est le même mot : deux cartes qui
poseraient la même ferme à des conditions différentes sont exactement ce qu'un draft de
méta-progression fera. `missing_fields()` réclame le lien **dans les deux sens**.

---

## 2026-08-25 — `C4` : le chantier, ses deux lectures, et un contrôle par l'image

**État : terminé.** Cinq commits sur `feat/c4-construction-sites`, **324 tests verts contre
304**. `BuildingData.build_actions` et la colonne **Chantier** de 4.1 écrite dans les treize
`.tres` ; `BuildingSnapshot.progress()/is_complete()/remaining()`, `CitySnapshot.completed()` ;
l'avancement sur `PlacedBuilding`, `CityState.advance()` ; les trois endroits qui devaient
cesser de compter un inachevé ; le rendu distinct.

### Deux arbitrages avant d'écrire

**Le « — » du Cœur est un zéro**, et non un champ réclamé au boot. L'argument qui tranche
n'est pas le confort mais la **cohérence de ligne** : ce même Cœur porte déjà « posé au
départ » dans la colonne Coût, que `data/` représente par un coût vide. Le bénéfice se voit à
ce qui n'a pas été écrit — `is_complete()` étant `progress >= build_actions`, le Cœur est
achevé à la pose et **aucun chemin particulier n'existe** pour lui. Le prix est réel et a été
payé : un `build_actions` oublié vaut 0 et fait sauter le chantier en silence, d'où un cas de
test qui charge tout `data/` et exige qu'au moins un bâtiment en déclare un. Filet à mailles
larges, et dit comme tel.

**Les harnais Économie et Effectifs achèvent à la pose.** Sans intervention ils devenaient
muets, faute de carte *Construire* à jeter sur leurs bâtiments. L'alternative — un cran par
soir — est la version **intéressante** et répondrait à une vraie question, mais elle a été
écartée pour une raison de méthode : les chiffres d'un harnais sont des **repères écrits au
journal**, et les déplacer depuis un jalon dont le sujet est la Construction aurait rendu la
prochaine dérive inattribuable. Vérifié après coup plutôt que supposé — aucun repère de `E1b`
ni de `W1` n'a bougé. Elle a un meilleur moment, et il est nommé : `I1`.

### La décision qui porte le jalon : deux lectures plutôt qu'un filtre recopié

Trois consommateurs devaient cesser de compter un bâtiment inachevé — postes de production,
réserve des entrepôts, places des habitations. Et un quatrième, le Combat, doit au contraire
les **voir** : 3.2 veut qu'un chantier détruit la veille de la vague soit une vraie perte.

Trois clauses `if not is_complete()` recopiées auraient marché, et auraient été oubliées à la
quatrième. Le pire est que **l'oubli aurait été silencieux** : un entrepôt en chantier qui
relève quand même la réserve ne casse rien, il ment — et un mensonge de ce genre ne se
découvre qu'en équilibrage, six jalons plus loin. `CitySnapshot` porte donc `completed()` à
côté de `buildings()` : une implémentation du côté du DTO qui sait déjà tout, et deux
questions qui ont chacune leur consommateur.

### Ce que la capture a trouvé, et ce qu'elle a innocenté

**Un bug à moi.** Le premier étalement donnait à chaque bâtiment un nombre de crans égal à
son rang dans le catalogue, calqué sur ce que `C2` fait des orientations. Sauf que les
orientations bouclent à 4 et que les chantiers plafonnent à **3** : tout ce qui vient après
le quatrième rang était achevé d'office, et la ville d'ouverture ne montrait que **2
chantiers sur 13**. Corrigé en prenant les crans modulo ce que chaque bâtiment réclame — 9
sur 13. **Aucun test n'aurait signalé ça : le code était correct, c'est la mise en scène qui
ne montrait rien.**

**Un bug qui n'est pas à moi.** La même capture montre une **trame en damier** sur le dessus
des boîtes. La tentation était de l'attribuer aux boîtes minces que `C4` introduit. Contrôle
fait plutôt que supposé : une capture avec `SITE_BASE_RATIO` forcé à `1.0` — donc au rendu
exact de `C2` — **montre exactement la même trame**. C'est un défaut de filtrage d'ombre de
`DevWorld`, que `C4` a seulement rendu plus visible. Consigné, pas corrigé.

**Le stratagème mérite d'être retenu : neutraliser son propre paramètre et recapturer**
répond en trente secondes à « est-ce moi ? », là où un `git stash` a fait perdre deux minutes
et failli emporter le travail — la remise au propre rebasculait `HARNESS` sur `&"workforce"`,
un harnais sans `--shot` ni `quit()`, qui a bloqué jusqu'au délai d'expiration.

### Décisions

**L'avancement vit sur `PlacedBuilding`, pas dans un troisième index.** Un avancement rangé
à côté des deux index de `CityState` serait un état séparé du bâtiment qu'il décrit, à
resynchroniser à chaque pose et à chaque retrait. Le docstring qui promettait un
`PlacedBuilding` immuable est corrigé plutôt que contourné : **son placement est figé, son
avancement ne l'est pas**, ce que 3.2 demande en disant qu'un chantier est un *état*.

**`advance()` rend un `bool`, pas un DTO `{ok, reason}`** — profil de `remove()` et non de
`place()`. La convention réserve le DTO aux erreurs récupérables, et un refus de placement en
est une vraie ; ici les deux seuls refus possibles se posent avant l'appel.

**`advance()` n'est pas un verrou, et le docstring le dit.** `place()` est une porte
exclusive, tenue par la structure ; `advance()` ne peut pas l'être — le renderer tient une
liste de `PlacedBuilding` depuis `C2`. Écrire « porte documentée » plutôt que « seule porte »
coûte une phrase et évite qu'on croie à une garantie qui n'existe pas.

**L'achèvement se teste dans `_work_lines()`, avant le bloc de production** — même endroit
unique que `E1b` avait choisi pour `produces()`. L'ordre des deux clauses n'est pas
indifférent : un ouvrier envoyé sur une ferme en chantier chôme parce qu'elle n'est pas
finie, pas parce qu'elle ne produirait pas. La distinction se lira le jour où le rapport dira
pourquoi.

**Hauteur et couleur sont pilotées par le même nombre** — réglés séparément, les deux
signaux auraient fini par se contredire (une boîte presque haute encore grise). Teinte de
fondation et plancher de hauteur sont des constantes d'adapter et non de `data/` : ce que
`data/` décide reste ce qu'un bâtiment **fini** vaut. **Le plancher est non nul**, et c'est
le seul des trois chiffres qui compte : à zéro, un chantier fraîchement posé serait invisible
et on ne verrait pas qu'on vient de payer une case.

**Pas de drapeau `--shot-build`** — l'étalement des avancements met déjà tout sous une seule
capture, et un drapeau qui ne montrerait rien de neuf est une option de plus à maintenir.

**Le nom `build_actions`, et pas `turns`** : `turns` désigne déjà les quarts de tour d'une
orientation. La collision aurait été silencieuse et catastrophique.

**Question de design neuve, inscrite en `OUVERT` dans 3.2** : quelle piste l'action
*Construire* crédite-t-elle ? Aucune des trois familles ne la couvre. Trois issues — une
quatrième famille, un rattachement à l'Artisanat, ou de l'XP de niveau seule.

---

## 2026-08-25 — `W1` : l'ouvrier, ses deux axes, et la boucle refermée sur `E1`

**État : terminé.** Six commits sur `feat/w1-workforce`, **304 tests verts contre 247**.
`domain/workforce/` — `skill_track.gd`, `worker.gd`, `roster.gd`, `skill_resolver.gd`,
`skill_gain.gd`, `progress_report.gd` ; `WorkforceBalance` (cinquième bloc) ;
`BuildingData.roster_places` ; quatre suites ; `workforce_harness.gd`.

**`contracts/` n'a pas bougé d'une ligne de code**, et c'est le résultat que le jalon visait.
`E1` avait été écrit en pensant à ici : `LaborUnit` portait déjà un multiplicateur par
famille, `WorkLine` portait déjà la famille à créditer. `W1` était annoncé comme « le dernier
moment où `LaborForce` peut bouger sans douleur » — elle n'a pas eu à bouger.

### Quatre arbitrages, dont un qui a changé le design

**`CombatForce` sort de `W1` pour `F1`**, contre ce que `DESIGN.md` 8 annonçait. Son contenu
est décidé par le format de combat, `OUVERT` en 3.6 : écrite aujourd'hui, elle serait ou bien
un clone strict de `LaborForce` qui ne prouve rien, ou bien une devinette sur des PV et de
l'équipement. Et contrairement à `skill_family` à `E1`, la repousser ne coûte rien.

Ce que `W1` garantit à la place est plus solide qu'un second DTO : **`Roster` est le seul
propriétaire des `Worker`**, et rien hors de `domain/workforce/` n'en voit un. Le vivier
unique n'est plus une discipline d'écriture, c'est une conséquence de la structure.

**La progression se fait par paliers**, pas par courbe continue. Un passage de niveau est un
événement qu'on annonce, et un ouvrier qu'on peut appeler « Récolte 3 » existe dans une
conversation comme un multiplicateur à 1,37 n'existera jamais. Une progression douce reste
exprimable — c'est beaucoup de petits paliers.

**Un second axe est entré, et il vient de l'humain** : à côté de la piste par famille, un
**niveau d'ouvrier** alimenté par toute source d'XP, qui ne donne aucun multiplicateur et
sert à distinguer un vétéran d'un bleu. `DESIGN.md` ne le portait pas, donc le design est
passé **en premier**, comme les empreintes libres à `C1` et la rotation à `C2`. Il est entré
coupé en deux : l'accumulateur et les paliers sont écrits, ce qu'un palier **offre** devient
`X5`. Une raison de ne pas tout repousser : « XP de toute source » veut dire que `F1` et les
événements devront trouver le compteur déjà là, sinon chacun inventera où loger son XP.

**L'absence de 3.9 entre maintenant**, minimale : un état de présence, et `to_labor()` qui ne
projette que les présents. Coût réel : un booléen, un filtre, trois cas de test. C'est la
contrainte qu'on ne rattrape pas après coup.

### La règle qui relie les deux axes

**Toute XP compte deux fois** — une fois pour la piste concernée, une fois pour le niveau.
Un seul chiffre de gain les alimente tous les deux ; deux montants distincts auraient donné
un levier de plus à régler par source d'XP, et deux chiffres à tenir cohérents pour rien.

Ce qui rend la règle tenable est un choix d'encapsulation : **une `SkillTrack` ne sort jamais
de son `Worker`.** La rendre laisserait un appelant la créditer seule, et l'invariant
redeviendrait une consigne.

**Le niveau est un compteur réel et non la somme des pistes.** Aujourd'hui les deux
coïncident, puisque le travail est la seule source d'XP écrite ; ils divergeront à la
première XP qui n'appartient à aucune famille — celle d'un événement —, et le dériver
maintenant obligerait alors à inventer une famille fourre-tout pour l'y loger.

### Le cas de test qui porte le jalon

Le premier de tout le projet à faire tourner **deux systèmes du domaine ensemble** :
résoudre un soir, distribuer l'XP, reprojeter, résoudre le suivant — et la cabane rend 2 puis
3. `E1` avait écrit un journal de travail que personne ne lisait ; c'est ce cas qui prouve
qu'il sert. Son jumeau compte autant : la même séquence **sans** la distribution rend 2 deux
fois — sans lui, le premier passerait tout aussi bien si la récolte montait toute seule.

Deux autres tiennent un terrain que rien d'autre ne couvre : **spécialiser doit soulever une
famille et laisser les autres à plat**, que 3.4 promet depuis `E1` sans que rien ne le
vérifie ; et **`to_labor()` doit laisser les absents**, la seule ligne qui paie pour 3.9.

### Le constat que le harnais rapporte

Premier harnais à composer deux systèmes — le rôle que `RunOrchestrator` reprendra à `I1`, et
il tient en trois lignes. Sa réponse n'est pas celle qu'on attendait : **la récolte reste
plate dix-neuf soirs alors que toutes les pistes montent.** Le rendement est tronqué **par
ouvrier et par soir** — une décision de `E1` —, or sur des promesses à 2 ou 3, un cran de
0,15 est entièrement avalé tant que le multiplicateur n'a pas franchi l'entier suivant. La
nourriture ne bouge qu'au soir 20 (×1,45), le bois et la pierre qu'au soir 26 (×1,60).

**Le constat est structurel, pas un mauvais réglage** : aucune valeur du cran ne le supprime.
Seuls des rendements plus gros, ou une troncature déplacée — accumuler en flottant et
n'arrondir qu'une fois par ressource —, y changeraient quelque chose. Les deux sont des
questions de `I3`, et la seconde touche `ProductionResolver`.

Il chiffre aussi ce que l'absence coûte : Elric part au soir 12, la carrière tombe de 4
pierre à 2, il revient six soirs plus tard avec une piste de retard sur ses camarades — et il
n'a rien mangé pendant ce temps.

### Décisions

**`SkillTrack.level_at()` est statique, publique, et sert aux deux axes** — les paliers
montent de la même façon des deux côtés, seuls les réglages diffèrent. Une progression qui
accélérerait sur un axe et pas sur l'autre serait une décision d'équilibrage déguisée en
décision de code.

**`SkillResolver` mute le `Roster` et rend un rapport** — profil identique à
`ProductionResolver` qui mute le `Ledger`, et pour la même raison. **`ProgressReport` reste
dans `domain/workforce/`**, comme `PickResult` dans `domain/terrain/`.

**Chaque ligne de travail est créditée séparément**, sans regroupement par ouvrier :
aujourd'hui les deux reviennent au même, mais rien n'en dépend et deux lignes du même ouvrier
cumuleraient correctement. **Un ouvrier nommé au journal mais absent du roster est sauté sans
un mot** — miroir exact de `ProductionResolver._work_lines()` : une affectation peut avoir
survécu à celui qui la portait, et un mort ne progresse pas.

**`roster_places` est un champ plat sur `BuildingData`**, à côté de `storage_bonus` : c'est
un nombre qui relève un plafond global, pas une nature de bâtiment. La doctrine du zéro ne
s'y applique pas non plus — douze bâtiments sur treize ne logent personne.

**Le roster ne consulte jamais son plafond.** `add()` n'oppose aucun refus : c'est la couche
qui orchestre la journée qui pose les deux questions à la suite, comme elle enchaîne
« payable » et « posable ». Un cas de test le dit à voix haute, pour que personne ne
« répare » `add()` plus tard.

**Le harnais lit la famille dans `data/` au lieu de l'écrire** — un `&"harvest"` en dur y
survivrait à un renommage du catalogue sans que rien ne le signale. Constat au passage : les
quatre producteurs de `data/buildings/` emploient tous la même famille, donc la spécialisation
*entre* familles n'est pas encore observable sur le contenu réel.

**Les prénoms sont codés en dur dans le harnais** — un catalogue de prénoms dans `data/` est
du contenu, donc `I3`.

**La duplication des rapports texte n'a pas été traitée** : `_make_label()` existe maintenant
en quatre exemplaires. La mettre en commun est une passe à part entière, et ce n'était pas le
sujet de `W1`. Consigné pour que ça ne passe pas pour un oubli.

---

## 2026-08-25 — `E1b` : le bloc de production, le minerai, et les douze bâtiments

**État : terminé.** Six commits sur `feat/e1b-production-block`, **247 tests verts contre
241**. `production_block.gd` — la classe neuve et le seul vrai sujet du jalon ;
`BuildingData` perd `slots`, `yield_per_slot` et `skill_family`, gagne `production` et
`produces()` ; `data/commodities/ore.tres` et **sept bâtiments neufs**, les six anciens
réécrits ; la file d'attente de construction du harnais. `DESIGN.md` 4.1.

### Ce que le bloc achète, et ça se lit à ce qui a disparu

`E1` avait consigné une entorse assumée : « la doctrine du zéro ne s'applique pas au bloc
économie ». À plat sur `BuildingData`, `slots = 0` était une valeur parfaitement légitime, et
un champ non renseigné y cessait d'être détectable — il avait fallu le remplacer par un
contrôle de cohérence **entre** les trois champs.

L'entorse est levée, et sans avoir été traitée. Un bloc qui existe produit : ses trois champs
se réclament maintenant sans condition. Le gain ne se voit pas dans le code ajouté mais dans
celui qui a disparu — `_economy_fields()` a perdu ses trois clauses croisées et ne fait plus
que déléguer sous un préfixe. **Le cas de test qui porte le jalon est celui des slots à
zéro**, précisément parce que `E1` ne pouvait pas l'écrire.

### Trois arbitrages, dont un qui change le contenu

**Les cinq bâtiments à slot muet entrent sans bloc.** Tour de guet, caserne, marché, atelier
et camp d'exploration portent « 1 slot » dans 4.1 et aucun ne produit de ressource : leur
poste héberge une défense (`F1`), un échange (`I3`) ou une action débloquée. Leur écrire un
`slots = 1` que rien ne lit aurait fait mentir la data **et** détruit la garantie qu'on venait
d'acheter. C'est le cas que 3.3 anticipait en écrivant « le jour où un bâtiment produit
autrement, le bloc devient une classe de base » : ce jour n'est pas aujourd'hui, parce que ces
slots ne produisent pas autrement — **ils ne produisent pas**.

**La palissade entre au tableau 4.1.** Elle existait dans `data/` depuis `C2` sans y figurer,
ce qui faisait diverger le design de son contenu. Elle est la seule empreinte non
rectangulaire du projet, donc le seul cas qui exerce vraiment la rotation du fantôme et le
validateur ; l'atelier lui donne depuis ce jalon un second L.

**Les colonnes Chantier, Déf., PV et Débloque restent dehors** — un champ arrive avec le
système qui le lit. Conséquence à consigner pour ne pas la relire comme un oubli :
**l'habitation entre en coquille vide**, sans rien que son coût, et c'est correct.

### Le harnais a gagné une file, et il a répondu autre chose

La mine coûte 25 bois et 10 pierre, qu'aucune bourse d'ouverture n'a : l'ajouter à la liste
de construction l'aurait fait refuser au premier jour, et le minerai serait entré au
catalogue sans qu'aucun soir n'en produise. Ce qu'un bâtiment impayable devient est donc
devenu une question, et la réponse est une **file** : ce que la bourse refuse y entre, et le
harnais en retente la tête, une par soir. **Elle ne se réordonne jamais** — un bâtiment cher
doublé par un moins cher derrière lui ferait répondre le harnais à une question qu'on ne lui
pose pas. L'affectation se refait à chaque soir en conséquence.

Il dit maintenant ce qu'il ne pouvait pas dire : **la mine se paie au soir 8, la seconde
ferme au soir 10, et c'est cette ferme qui met fin à la famine.** La première famine reste au
soir 6, mais la réserve finit à **189/200 au vingtième soir contre 160 à `E1`** : le plafond
commun est beaucoup plus près de mordre qu'il ne le paraissait.

### Décisions

**Le bloc s'écrit en `sub_resource`, pas en fichier séparé** — un bloc appartient à son
bâtiment et n'a aucune identité au catalogue ; `TerrainDecor` sur un terrain est le même
motif. Un cas de test charge tous les `.tres` et exige qu'au moins un en porte un typé —
sans cette dernière exigence, il passerait par vacuité le jour où le format se casserait
partout.

**`produces()` plutôt qu'un `production != null` recopié** : la nullité est la façon dont
`E1b` dit « ne produit pas », et le jour où le bloc devient une classe de base, la question
restera posée au même endroit.

**L'existence du bloc se teste dans `_work_lines()` et nulle part ailleurs** — toute ligne de
travail en sort, donc tout ce qui en consomme une sait que le bâtiment produit.

**Le contrôle croisé nomme le chemin complet** : `ressource inconnue « oer » dans
data/buildings/mine.tres → production.yield_per_slot`. Sans le préfixe, un `yield_per_slot`
nu ne dirait plus d'où il vient le jour où `BuildingData` portera plusieurs blocs.

**Le terrain `filon` n'est pas écrit.** `TerrainGenBalance` porte cinq emplacements en dur ;
en ajouter un est du travail Terrain, et une `.tres` que rien ne génère serait de la data
morte. La mine produit du minerai sans en avoir besoin — aucun prérequis de tag n'existe au
placement depuis `C1`. Ça redeviendra nécessaire à `D2`, quand *Récolter* à cru voudra une
case `ore`.
---

## 2026-08-24 — `E1` : la réserve, la résolution du soir, l'upkeep et la famine

**État : terminé.** Sept commits sur `feat/e1-economy`, **241 tests verts**. Sept DTO
dans `contracts/` (`CitySnapshot`, `BuildingSnapshot`, `LaborForce`, `LaborUnit`,
`Assignment`, `WorkLine`, `ProductionReport`), `domain/economy/` (`Ledger`,
`ProductionResolver`), le bloc économie de `BuildingData`, `data/commodities/`, la ferme
et l'entrepôt. `DESIGN.md` 3.3 et 3.4.

*Accroc de procédure, réparé sans perte : la session s'est ouverte sans créer de branche
et le premier commit a atterri sur `feat/c2-placement-ghost`. **La branche se crée à
l'orientation, avant le premier commit.***

**La réserve est commune, pas par ressource** — la réponse de l'humain, à l'inverse de ma
recommandation. Cent unités partagées entre bois, pierre et nourriture : remplir sa
réserve de bois, c'est renoncer à stocker de la pierre. Le plafond force à choisir *quoi*
garder, et l'entrepôt devient un arbitrage plutôt qu'un relèvement de trois compteurs.

**Et ce choix a une conséquence que ni le plan ni la question ne voyaient : une récolte
qui déborde doit décider laquelle de ses ressources entre.** Premier arrivé premier servi
est un piège — l'ordre des clés vient de l'ordre de pose des bâtiments, donc deux villes
identiques bâties dans un ordre différent perdraient des choses différentes sans que rien
à l'écran ne l'explique (même famille d'erreur que les quatre passes du validateur à
`C1`). La règle retenue est **proportionnelle à ce que le dépôt apporte**, reste de
division aux plus grosses parts fractionnaires, identifiant tranchant à égalité. Le cas de
test qui compte dépose les mêmes montants dans deux ordres de clés opposés et exige le
même résultat. Le même écrêtage sert quand la capacité **baisse** — un entrepôt détruit
par une vague : une règle écrite une fois, utilisée deux fois.

**La `LaborForce` porte un multiplicateur par famille**, et `BuildingData` déclare la
sienne — l'argument décisif était le coût : un champ dans quatre `.tres` déjà ouverts,
contre les rouvrir tous à `W1` *et* changer un contrat.

**La famine se constate et ne se punit pas**, entrée comme `OUVERT` explicite en 3.3
plutôt que laissée non-dite.

**La doctrine du zéro ne s'applique pas au bloc économie.** 0 slot, un coût vide et une
réserve nulle sont trois valeurs légitimes de `DESIGN.md` 4 — la palissade n'a pas de
poste, la cabane de bûcheron est gratuite. Les réclamer refuserait de démarrer sur des
données correctes. Ce qui les remplace est un contrôle de **cohérence entre eux** : des
slots sans rendement, un rendement sans slot, un poste sans famille.

**Le résolveur mute le `Ledger`, et ce n'est pas une entorse** : le ledger est l'état
*interne* de l'Économie, comme `CityState` l'est de Construction. La ligne de contrat de
3.3 énumère les entrées **inter-systèmes**, ce qui est précisément pourquoi il n'y figure
pas.

**Le rapport rapporte, il ne punit pas, et ne calcule aucune XP** — combien vaut une
soirée de travail est un chiffre des Effectifs. Il porte un journal de travail (qui a tenu
quel poste, dans quelle famille), et `W1` en fera ce qu'il veut.

**L'upkeep tombe sur le roster entier, oisifs compris** : c'est ce qui rend un ouvrier non
affecté coûteux, donc le pool tendu, donc la tension de `DESIGN.md` 1 réelle plutôt que
déclarative. **Les oisifs se déduisent du roster moins ceux qui ont travaillé** — cette
soustraction couvre d'un coup les quatre façons de ne rien produire sans qu'aucune ait à
être énumérée, et un mort ne chôme pas.

**`CommodityData` et non `ResourceData`** : `Resource` est le type de base de Godot, et
`GameDatabase.get_resource()` est déjà l'accesseur générique. Le vocabulaire du jeu ne
bouge pas. **`upkeep_resource` est un champ d'équilibrage** — un `&"food"` en constante
aurait survécu à un renommage du catalogue sans que rien ne le signale.

**Deux bâtiments entrent, chacun pour une raison précise** (le motif de la palissade à
`C2`) : l'entrepôt est la seule chose qui relève la réserve commune, la ferme le seul
producteur de nourriture sans lequel le harnais meurt de faim au premier soir.

**Le harnais pose les deux questions à la suite** — payable, puis posable, puis on
dépense ; payer avant de savoir si ça tient sur le relief laisserait la ville plus pauvre
sans rien de bâti. Comme celui de `C1`, il **cherche** son cas : vingt soirs, et il dit
lequel a cassé le premier. Réponse : **famine au soir 6, réserve jamais pleine (160/200 au
vingtième)** — avec dix ouvriers pour six postes, c'est la nourriture qui étrangle bien
avant le plafond. Un défaut trouvé en lisant ce rapport et pas autrement : la réserve ne
prenait sa nouvelle capacité qu'à la résolution suivante, alors qu'un entrepôt doit compter
dès qu'il est bâti.

---

## 2026-08-24 — `C2` : fantôme de placement, pose et destruction

**État : terminé.** Dix commits sur `feat/c2-placement-ghost`, 160 tests verts.
`dev_world.gd` et `dev_shot.gd` (le plateau et le vocabulaire de capture, partagés),
`building_renderer.gd`, `placement_ghost.gd`, la palissade en L, et la **rotation** —
hors plan, entrée par la porte normale (`DESIGN.md` d'abord).

**Le domaine n'a pas bougé d'une ligne, et c'est le résultat.** `validate()` était déjà
pure et appelable à chaque image, `place()` et `remove()` attendaient leurs clics,
`PlacementResult` portait déjà les cellules et la hauteur auxquelles dessiner. `C1` avait
fait son travail ; `C2` n'a été que de la traduction.

**`TerrainMetrics` et `PickResult` ne montent pas dans `contracts/`** — question ouverte
depuis `T3`, réponse non : ce sont les *adapters* de Construction qui en ont besoin, et la
règle de dépendance contraint le domaine, pas eux.

**Le bug que seule l'image a montré — la carte chauve.** Quatrième jalon d'affilée.
`TerrainRenderer.create()` se peuple lui-même, `TerrainDecorRenderer.create_all()` non :
`DevWorld.create()` promettait dans son docstring un plateau « déjà peuplé » et mentait, ce
que le harnais Terrain masquait en enchaînant sur son propre `show_grid()`. Corrigé à la
source, pour qu'un seul chemin peuple le plateau.

**Une comparaison de captures mal lue, et l'outil qui en sort.** L'image « après » de
l'extraction de `DevWorld` semblait plus zoomée ; elle ne l'était pas — le viewport garde
la largeur de base mais sa **hauteur suit le rapport de la fenêtre**. D'où deux acquis : la
capture imprime une ligne `cadrage` (deux captures ne se comparent que si elle est
identique), et **`cmp` sur les deux `.png` tranche là où l'œil se trompe** — l'extraction
rendait des images identiques octet pour octet.

**Le soleil : un problème annoncé qui n'existe pas.** `CLAUDE.md` prévenait depuis `T3`
que les bâtiments, étant des boîtes, se heurteraient au piège du prisme noir. Ça n'est pas
arrivé : elles présentent à la lumière exactement les orientations des colonnes du terrain,
qui se lisent bien depuis `T2`. Le piège venait de la face *oblique* du prisme. `CLAUDE.md`
corrigé — **une prédiction fausse laissée dans un document permanent se paie plus tard**,
quand quelqu'un « répare » un problème inexistant.

**La palissade est entrée pour une raison précise** : rien de ce qui tournait ne dessinait
une empreinte non rectangulaire, or c'est la seule chose pour laquelle `C1` existait.

**Une boîte par cellule occupée, pas une par bâtiment** — sur un L, un volume unique
couvrirait le trou de l'enveloppe et mentirait sur la forme. **Le fantôme ne décide rien** :
il reçoit un `PlacementResult` déjà calculé et le colore. **La validation a lieu une fois
par image**, et le fantôme et la ligne de rapport lisent le même résultat — une couleur qui
contredirait sa légende serait un bug impossible à voir. **La hauteur du fantôme vient du
survol, pas du résultat** : un refus n'a pas de hauteur, et c'est précisément sur un refus
qu'il faut le voir. Il **dessine aussi les cellules hors carte**, ce qui explique le refus
mieux qu'une empreinte tronquée.

**La rotation : l'orientation appartient au placement, pas au bâtiment.** Rien dans `data/`
ne la décrit ; une même `BuildingData` se pose dans les quatre sens. **Elle se fait autour
de la cellule d'ancrage** — l'ancre est le décalage `(0, 0)`, invariante par rotation, donc
une empreinte pivotée contient toujours son ancre et pivote sous le curseur au lieu de
sauter à côté. Le résultat mérite d'être noté : **pas une ligne du validateur ne parle de
rotation**, ni les index de la ville, ni le renderer. Toute la fonctionnalité tient dans
`rotate_offset()` et un paramètre passé de main en main. Les deux cas de test qui portent
le plus posent la **même empreinte à la même ancre** et obtiennent un verdict différent une
fois tournée.

---

## 2026-08-24 — `C1` : la ville, les empreintes et les règles de placement

**État : terminé.** Six commits sur `feat/c1-placement`, 145 tests verts.
`PlacementResult` dans `contracts/`, `BuildingData`, `domain/city/` (`CityState`,
`PlacementValidator`, `PlacedBuilding`), trois `.tres` de bâtiments. `DESIGN.md` 3.1 et 3.2.

**Quatre points arbitrés avant d'écrire, dont deux qui ont simplifié le jalon :**

- **Le coût sort du placement.** `DESIGN.md` 3.2 se contredisait — ligne de contrat sans
  bourse, liste de validation avec « ressources suffisantes ». Même nature que la signature
  de `pick()` à `T3` : la contradiction était dans le document. « Ai-je les 15 bois ? » ne
  regarde pas la carte ; c'est la couche qui orchestre la journée qui enchaîne les deux.
- **Aucun prérequis dur d'adjacence** — elle reste entièrement la couche de rendement de
  `C3`, et le placement ne regarde jamais le voisinage.
- **`neighbourhood_at()` est écrite quand même**, à la demande de l'humain, sans aucun
  appelant avant `C3` — consigné dans son docstring, parce qu'écrire d'avance est ce que ce
  projet évite et **qu'une exception qui ne se dit pas devient une habitude**.
- **Toutes les cellules à la même hauteur, pour tous les bâtiments** : la règle est
  universelle, l'enum que je proposais disparaît.

**La planéité tranche un `OUVERT`, et `DESIGN.md` est passé en premier.** Exiger du plat
prend la piste *contrainte de construction* de 3.1 et élimine *purement décoratif* : le
relief décide d'où le village peut s'étendre, et c'est ce qui donne à un plateau sa valeur.
Le terrassement rejoint les pistes restantes — c'est cette règle qui le rendrait
intéressant. `DESIGN.md` est modifié dans le **premier** commit et non dans celui du
journal : `CLAUDE.md` interdit d'écrire une feature avant que le design la porte.

**Une empreinte est une liste de décalages, pas un rectangle.** Un L, un T ou une croix
s'écrivent, et un rectangle n'est qu'un cas particulier — pas deux façons de dire la même
chose, pas deux chemins à valider. Ce que j'avais annoncé comme coûteux ne l'était pas :
`TerrainQuery` expose déjà tout par cellule, donc la validation se fait avec le contrat
**tel quel**.

**`bounds_at()` ne valide jamais rien** — l'enveloppe d'un L couvre une cellule que le
bâtiment n'occupe pas. Deux cas de test l'épinglent des deux côtés : de l'eau dans ce trou
n'empêche pas la pose, et le trou reste posable ensuite. C'est ce couple qui prouve que les
formes libres sont réelles et pas décoratives.

**`CityState.place()` est la seule porte mutante, et elle valide avant de muter** : rien ne
peut entrer dans la ville sans être passé par le validateur — invariant tenu par la
structure, pas consigne à respecter. `validate()` reste pure et appelable seule, ce dont le
fantôme de `C2` a besoin.

**Quatre passes sur l'empreinte, pas une boucle.** En une seule, une empreinte à la fois
occupée et sous l'eau rendrait la raison de la cellule qui vient en premier dans le
`.tres` : la raison affichée dépendrait de l'ordre d'écriture de la data. L'ordre des
règles n'est pas libre non plus — les bornes d'abord, parce que `height_at()` lèverait sur
une empreinte qui déborde.

**`missing_fields()` contrôle l'empreinte au-delà de sa présence** (ancre absente, cellule
répétée). En revanche une empreinte **en deux morceaux disjoints** est acceptée : la
refuser serait une règle de contenu déguisée en règle de schéma.

**Le cycle `CityState` ↔ `PlacementValidator` passe** — ce n'est pas le cycle qui avait
mordu à `T3` entre `TerrainData` et `TerrainDecor` : celui-là portait sur une **constante**,
résolue à la compilation.

**`data/buildings/` n'est pas la passe de contenu** : `DESIGN.md` 4 ne donne aucune colonne
d'empreinte, donc les tailles posées ici sont inventées et `I3` les reprendra. Les trois
sont rectangulaires, fidèles à un design qui ne nomme aucun bâtiment en L.

**Le harnais cherche ses refus au lieu de les fabriquer** : il balaye la carte à la
recherche d'une ancre produisant exactement la raison visée, et le dit quand il n'en trouve
pas. C'est ce que les suites ne peuvent pas montrer — une règle qui cesserait de se
déclencher sur du terrain réellement généré remonterait toute seule. Pendant texte de la
sonde caméra de `T3`.

---

## 2026-08-24 — `T3` : picking DDA, surbrillance et décorations

**État : terminé.** Quatre commits sur `feat/t3-cell-picking`, 94 tests verts.
`cell_picker.gd` et `pick_result.gd`, `terrain_decor.gd` + le champ `decor` sur
`TerrainData`, trois adapters (`terrain_decor_renderer`, `cell_highlight`, `cell_cursor`).

**La signature figée qui ne l'était pas.** `CLAUDE.md` donnait `pick(grid, origin, dir)` et
le journal de `T2` la qualifiait de « signature figée ». Elle est inapplicable telle
quelle : le DDA a besoin de `tile_size` et `step_height`, que `T2` lui-même a sortis de
`HeightGrid` pour les mettre dans `TerrainMetrics`. La métrique devient un quatrième
paramètre, et `CLAUDE.md` est corrigé dans le même commit — **une signature figée qui bouge
doit dire qu'elle a bougé.**

**Une colonne est solide vers le bas et sans fond.** Le socle sous la carte n'est qu'une
épaisseur d'affichage ; lui donner un fond ouvrirait des tirs qui passent sous la carte pour
ressortir de l'autre côté. Corollaire assumé et testé : un tir parti de sous le terrain le
touche sur place.

**Le rayon est clippé sur l'emprise avant de marcher** — une caméra orthogonale place son
origine à cent unités de la carte. Le clip a aussi rattrapé un vrai bug : carte traversée
par la *droite* du rayon mais entièrement **derrière** son origine, l'intervalle d'entrée est
négatif et le clamp rendait une cellule inventée.

**Le point d'impact d'une face supérieure est recalé exactement sur le sommet** — le laisser
sortir du calcul flottant y remettrait quelques ulp de bruit, dans la valeur même sur
laquelle un bâtiment se posera. Le test assert l'égalité stricte.

**La décoration se décrit dans `data/`, dimensions en fractions de tuile** — même
raisonnement qu'à `T2` pour la couleur, et les fractions parce que régler `tile_size` doit
redimensionner la carte entière. **`decor` est nullable, seule exception au principe de
sentinelle** : plaine et eau n'ont rien à porter, et « rien » y est évident plutôt que
suspect ; le filet reste tendu sur une décoration *présente* mais à moitié remplie.

**La palette est passée en argument au renderer, pas lue sur `GameDatabase`** : les passes
se construisent sur ce que le jeu *connaît* et non sur ce qu'une grille contient — un seed
sans rocher ne doit pas supprimer la passe des rochers.

**La dispersion vient d'un hash de la cellule** — ni `randf()`, ni `RunState.rng` : une même
carte doit se disperser pareil à chaque affichage, sans faire descendre un flux de tirage
jusqu'à une passe de rendu.

**La surbrillance ne code aucune validité** — une marque verte ou rouge préempterait
Construction. Le picker désigne, il ne juge pas. **Le curseur pique à chaque image**, pas au
mouvement de souris : la caméra bouge aussi.

**Le bug que seule l'image a montré — le prisme noir.** Troisième jalon d'affilée. Les
gisements en `PrismMesh` apparaissaient comme des rectangles noirs, confirmé en recolorant
la forme en magenta pour savoir quels pixels lui appartenaient. **Le `PrismMesh` porte une
grande face verticale plate**, et le soleil n'éclaire que les surfaces tournées vers le
haut : aucune orientation ne sauve, puisque la caméra pivote au-dessus d'un soleil fixe. Le
prisme est **retiré du vocabulaire** plutôt que documenté avec une mise en garde — une
valeur d'enum inutilisée qui produit des trous noirs est un piège pour qui la choisira
ensuite. Le soleil n'a pas bougé : que seules les faces du dessus soient éclairées est
l'aspect établi à `T2`, un choix et non un défaut.

**La sonde caméra, non prévue au plan.** Entre les tests unitaires, qui tirent des rayons
faits à la main, et les trois commandes, qui ne regardent pas l'écran, il restait une
jointure non couverte : `project_ray_origin` et `project_ray_normal` d'une caméra
**orthogonale** donnent-ils au picker ce qu'il attend ? Chaque capture reprojette le point
d'impact vers l'écran, retire un rayon comme le ferait la souris, et dit si les deux tombent
sur la même cellule. D'accord au centre, dans un coin, et après un quart de tour.
`--shot-hover x,y` complète : souris à `(0, 0)`, une capture ne montrerait jamais la
surbrillance.

**Un test qui s'est cassé sur sa propre erreur** : le cas « changer `tile_size` change la
cellule désignée » visait un point hors de l'emprise de la seconde métrique. Le picker
n'avait rien, c'est l'attente qui était fausse.

---

## 2026-08-24 — `T2` : rendu en blocs étagés et caméra isométrique

**État : terminé.** Quatre commits sur `feat/t2-terrain-render`, 66 tests verts.
`src/adapters/` naît ici avec `terrain_renderer.gd` et `camera_rig.gd` ;
`TerrainMetrics` dans le domaine ; `CameraBalance` ; `TerrainData` gagne une `color`.

**Aucun DTO n'entre dans `contracts/`, et l'étape est sautée.** `T2` est interne au Terrain
plus sa couche adapter — inventer un contrat pour respecter la forme de la procédure aurait
figé une frontière que personne ne franchit. **`TerrainMetrics` va dans `domain/terrain/`** :
le renderer la consomme, le `CellPicker` la consommera à `T3` — deux fois le même système —
et elle est du domaine parce que `CellPicker` travaille déjà en coordonnées de monde.

**Trois conventions y sont fixées, et tout le reste du jeu en dépend :**

- l'origine du monde est au **coin** de la carte, pas au centre — `cell_at()` reste un
  `floor` sans décalage, ce dont le DDA de `T3` a besoin ; recentrer devient un travail de
  caméra ;
- grille `+x` → monde `+X`, grille `+y` → monde `+Z` ;
- une cellule de hauteur `h` a sa **face supérieure** à `h * step_height` — ni le socle ni
  l'épaisseur d'affichage ne déplacent ce plan.

**`floori`, pas `int()`** : une troncature ramènerait `-0.3` sur `0` et collerait les
cellules `-1` et `0` l'une sur l'autre.

**La couleur vit sur `TerrainData`, pas dans le renderer** — c'est ce qui interdit au
renderer de commuter sur un identifiant de terrain. **Sentinelle : le noir opaque vaut
« non renseigné »** — même piège qu'à `I0` et `T1`, un `Color` sans défaut vaut
`Color(0,0,0,1)`, donc exactement ce que Godot omet du `.tres`. Un terrain qui voudrait du
noir écrit `Color(0.02, 0.02, 0.02)`. Un test épingle le pari lui-même : que la sentinelle
soit bien la valeur qu'un `Color` neuf porte.

**Les colonnes s'enracinent un cran sous la plus basse de la carte**, pas à `y = 0` :
l'épaisseur reste positive sur un terrain plat comme sur un relief négatif. **Pas de jeu
entre les cellules** — une surface continue lit mieux qu'un damier fissuré, et la lisibilité
de la grille est le travail de la surbrillance de `T3`.

**Le rig lit son propre input, derrière `input_enabled`** — une caméra dont il faut câbler
l'input à chaque scène est une friction permanente. Aucune action d'input n'est utilisée, que
des touches brutes, pour que rien n'ait à être ajouté à `project.godot`.

**Le lacet cible s'accumule sans jamais être replié dans `[0, 360)`** : quatre quarts de
tour doivent faire un tour complet, une valeur repliée rebrousserait chemin au quatrième.

**`pan_speed` est en hauteurs d'écran par seconde**, pas en unités de monde — un pan réglé
au bon rythme de près file à travers la carte de loin. **Le piqué de −35,264° reste une
constante, pas un réglage** : c'est l'isométrique vrai, et le mettre en data inviterait à le
changer.

**Le bug que seule l'image a montré — le lacet de base était à zéro.** `CLAUDE.md` disait
« `rotation_degrees.y` par pas de 90° », lu comme un lacet partant de 0. Tout compilait, les
tests passaient, le boot était propre — et la capture montrait une vue alignée sur les axes,
une grille en damier, un relief réduit à des traits noirs. **Le piqué seul ne fait pas
l'isométrique** : il y faut 45° de lacet, qui sont ce qui projette une grille carrée en
losanges. À lacet nul, les faces `±X` d'une colonne sont exactement de profil, donc d'aire
nulle à l'écran — chaque colonne ne montre qu'**un seul** de ses quatre flancs et une marche
se lit comme une ligne. Le cadrage a suivi : à 45°, c'est la **diagonale** de la carte qui
barre l'écran, et elle est la même aux quatre orientations. Ce qu'il faut en retenir dépasse
le bug : **un jalon de rendu ne se vérifie pas au parsing.**

**Un second bug de rendu, signalé par l'humain — les cascades d'ombre.** Une ligne
horizontale **fixe à l'écran**, ombres floues au-dessus, nettes en dessous. Godot met une
`DirectionalLight3D` en `SHADOW_PARALLEL_4_SPLITS` sans fondu ; sous une caméra orthogonale,
où la profondeur croît linéairement du bas vers le haut de l'écran, ces frontières deviennent
des lignes horizontales fixes. Corrigé en `SHADOW_ORTHOGONAL` — les cascades servent à
couvrir un horizon lointain, et la scène est bornée par construction.
`directional_shadow_max_distance` est passé de 400 à `ORBIT_DISTANCE + 60` : l'étaler
au-delà de ce que la caméra voit ne faisait que diluer les texels. Consigné dans `CLAUDE.md`
et pas seulement ici — le soleil du harnais sera jeté quand la scène de jeu montera le sien.

**La capture en ligne de commande, non prévue au plan.** `-- --shot chemin.png
[--shot-turns n]` : le harnais rend, enregistre et quitte. C'était la seule façon de
regarder le rendu sans dépendre de l'humain à chaque itération, et c'est ce qui a trouvé le
bug ci-dessus. Douze lignes dans un harnais de dev, exactement l'endroit où ce genre
d'échafaudage a sa place.

**Observation d'équilibrage — le relief reste plat, et c'est un chiffre, pas un bug.** La
génération produit `1..5` (4 crans) alors que `max_height = 6` : comportement normal d'un
bruit fractal, dont les extrêmes ne sont statistiquement pas atteints. À
`step_height = 0.25`, cela fait 1,0 unité de relief sur une carte de 32 — la carte lit comme
un plateau froissé. Deux leviers, tous deux dans `data/balance/` : `step_height` (amplifie
sans toucher à la distribution) ou `noise_frequency`/`noise_octaves` (échange le froissement
haute fréquence contre des reliefs plus larges). Non tranché : c'est un choix d'aspect,
adossé à l'`OUVERT` de 3.1 sur le rôle du relief.

---

## 2026-08-24 — `T1` : grille de hauteurs et génération seedée

**État : terminé.** Cinq commits sur `feat/t1-height-grid`, 45 tests verts contre 3.
`contracts/` naît ici avec `TerrainQuery` ; `HeightGrid`, `GridTerrainQuery`, `TerrainGen` ;
les cinq terrains de `DESIGN.md` 3.1 en `.tres`.

**`TerrainQuery` est un contrat abstrait, pas une enveloppe autour de la grille.** Une query
qui aurait tenu une `HeightGrid` en membre privé aurait fait dépendre `contracts/` des
internes du Terrain, et Construction en aurait hérité par transitivité — l'inverse exact de
la règle de dépendance. `TerrainQuery` est `@abstract` dans `contracts/`, `GridTerrainQuery`
l'implémente dans `domain/terrain/` : la vue reste vivante et sans copie, et Combat pourra
recevoir une query fabriquée à la main en test.

**Trois primitives seulement sont abstraites** — `size()`, `height_at()`, `terrain_at()`.
Constructibilité, tags, planéité et dénivelé sont dérivés dans le contrat lui-même, pour que
deux implémentations ne divergent pas sur le sens de « constructible » ou de « plat ». Une
implémentation coûte douze lignes.

**Les bornes sont volontairement asymétriques** : `height_at()` assert hors grille — l'appeler
là est un bug de l'appelant — quand `is_buildable()` rend `false`, parce que Construction teste
couramment des empreintes qui débordent et que « puis-je bâtir hors carte ? » a une réponse.

**La constructibilité est un enum à trois états, pas un `bool`** : sur un `bool`, « non
renseigné » et « non constructible » sont indiscernables, et Godot n'écrit jamais `false` dans
un `.tres` — le champ aurait été invisible au contrôle de complétude. `UNSET = 0` reste
détectable.

**Représentation dense** — deux tableaux plats indexés `y * largeur + x`, pas un
`Dictionary` : la grille est rectangulaire et pleine. C'est le genre de choix que le contrat
rend révocable sans toucher personne.

**`generate()` prend un seed, pas le RNG du run** : la génération ne consomme aucun flux
partagé et se rejoue seule en test. **Le tirage de dispersion est consommé même quand il ne
donne rien** — une cellule tirée en forêt trop haut retombe en plaine sans décaler les bandes
suivantes : relever `forest_max_height` ne doit pas déplacer tous les gisements de la carte.

**`missing_fields()` est un filet partiel, et c'est assumé** : il ne rattrape que les champs
dont `0` est invalide. Pour `min_height` ou une densité, `0` est légitime — mais il transite
correctement, puisque Godot omet alors la ligne du `.tres`. Le piège de `I0` venait de ce que
le défaut du script *était* la vraie valeur.

**Les terrains ne sont pas figés dans les tests** — la structure est vérifiée (cinq fichiers,
aucun champ vide, `id` égal au nom de fichier), pas le contenu : assert que l'eau est
inconstructible recopierait `data/` dans `tests/`.

**Deux pièges de plus, consignés dans `CLAUDE.md`.** Le cache des classes globales est en
retard exactement comme celui des `uid://`, et bien plus souvent : un `class_name` créé hors
éditeur n'existe pour personne tant qu'aucun scan n'a eu lieu, et la commande 1 échoue sur
`Could not find type "X"` sur un fichier parfaitement correct. Et **la commande 1 rend `0`
alors qu'elle imprime des erreurs de script** — constaté directement : quatre `SCRIPT ERROR`
à l'écran et `EXIT=0`. Un contrôle qui ne testerait que `$?` laisserait passer un projet qui
ne compile pas.

**Un bug trouvé par les tests — `GameDatabase` ne triait rien.** `list_ids()` promettait un
ordre trié depuis `I0` et ne le tenait pas : `Array.sort()` sur des `StringName` compare des
**pointeurs internes**, pas du texte, donc un ordre arbitraire, stable le temps d'une session
et différent à la suivante. Corrigé en `sort_custom` sur `String(...)`, et ajouté aux
conventions — c'est un piège à déterminisme, pas une coquetterie.

**Observation laissée ouverte** : `max_height = 6` ne produit jamais de cellule à 6, le
maximum observé plafonne à 5. Comportement normal d'un bruit fractal — un chiffre à ajuster
une fois `T2` en place et le relief visible.

---

## 2026-08-24 — `I0` : squelette

**État : terminé.** `src/schema/` (`BalanceData`, `TerrainBalance`), `data/balance/`, les
trois autoloads (`EventBus`, `GameDatabase`, `RunManager`), `dev_boot.gd`, le README, 3 tests
verts. `src/domain/` encore vide.

**Une scène pivot unique pour tout le dev.** Godot ne sait lancer qu'une scène, jamais un
script, et la scène principale doit être une `PackedScene` : les harnais en `.gd` voulus par
`CLAUDE.md` étaient inatteignables sans au moins un fichier de scène. `dev_boot.tscn` est ce
fichier, et le seul — `dev_boot.gd` instancie le harnais nommé dans sa constante `HARNESS`,
si bien qu'ajouter un harnais coûte un `.gd` et une ligne de table, sans rouvrir l'éditeur.

**La commande de vérification n°1 était fausse, et deux remplaçantes l'étaient aussi.**
`--headless --quit` échoue tant qu'aucune scène principale n'est définie — une fois
`dev_boot.tscn` en place elle est correcte, et même la seule à monter les autoloads, donc à
valider `src/autoload/`, `src/adapters/` et `scenes/dev/`. `--headless --editor --quit` a
semblé un bon substitut : il ne signale les erreurs qu'au **premier** scan, et cache chaud il
rend 0 sur un projet cassé. `--check-only -s` est fiable et indépendant du cache mais compile
hors contexte, donc échoue sur tout script touchant un autoload — il ne sert que sur
`src/domain/`, où la règle de dépendance les interdit déjà. D'où trois commandes au lieu de
deux, chacune couvrant ce que les autres ne voient pas.

**Le cache `uid://` peut simuler un projet cassé.** Juste après avoir créé une scène, éditeur
encore ouvert, `.godot/uid_cache.bin` est en retard et la commande 1 échoue sur
`Unrecognized UID` — ce qui ressemble trait pour trait à une erreur réelle. Une passe
`--headless --editor --quit` reconstruit le cache.

**`EventBus.database_ready` est émis en différé.** Les autoloads sont prêts avant la scène
principale : émis directement dans `_ready()`, le signal n'aurait eu aucun auditeur possible.

**Ni `contracts/` ni `PhaseDef` à `I0`.** Aucun DTO n'a deux systèmes pour le consommer, et
livrer une structure de journée, même par défaut, préempterait la question ouverte 2 de
`DESIGN.md`.

**Correctif — l'éditeur vidait le data d'équilibrage.** Au premier réenregistrement des
`.tres`, `tile_size` et `step_height` ont **disparu** : Godot n'écrit pas une propriété égale
à son défaut `@export`, et je leur avais donné les mêmes valeurs en défaut — les chiffres
d'équilibrage étaient donc silencieusement remontés dans le `.gd`, en contradiction directe
avec un anti-pattern déclaré. Rien ne cassait, ce qui est précisément ce qui rend le piège
dangereux. Corrigé en retirant tout défaut des `@export` de `src/schema/` : un champ non
renseigné vaut `0`, détectable, chaque resource expose `missing_fields()`, `BalanceData` les
agrège et `GameDatabase` refuse de démarrer sur un champ vide. Vérifié dans les deux sens.
**C'est l'origine de la doctrine du zéro.**

**Godot épinglé à 4.7.2-stable** (`ed1daf0bf`), `gdUnit4` 6.2.0. Vérification des API
4.5 → 4.7 faite contre la doc extraite du binaire (`--doctool`) plutôt que contre les
changelogs : `MultiMesh`, `Camera3D` orthographique et les `Resource` personnalisées sont
intacts, aucune décision technique invalidée.

**Chaîne d'outils.** `GODOT_BIN` défini au niveau utilisateur, binaire rangé dans
`C:\Tools\Godot\4.7.2\` — un dossier par version, de sorte qu'une montée de version soit un
changement de `GODOT_BIN` et rien d'autre. Le README reste générique sur ce chemin : il est
propre à la machine.
