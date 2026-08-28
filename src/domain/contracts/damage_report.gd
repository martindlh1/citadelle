class_name DamageReport
extends RefCounted
## Ce qu'une vague a **ordonné** : ce qu'elle casse, qui elle emporte, ce qu'elle vole,
## et ce que la ligne a valu à ceux qui l'ont tenue.
##
## Le seul contrat de sortie du Combat. DESIGN.md 3.6 : « C'est **le seul** contrat qui
## compte. Tout ce qui se passe entre les deux est remplaçable sans toucher au reste du
## jeu. » Ce fichier a été écrit à F1 pour survivre au bouchon qui le produisait, et c'est
## à F2b qu'on le vérifie : le CombatBoard le remplit à son tour, et l'orchestrateur qui
## l'applique n'a pas une ligne à changer.
##
## **Il ordonne, il ne mute rien**, profil de SiteReport et pour la même raison, en plus
## fort : il touche l'état de **trois** autres systèmes — la ville, le roster, la réserve.
## Un résolveur de Combat qui les muterait violerait la règle de dépendance trois fois.
## Le chemin propre est celui de I1 : le résolveur ordonne, l'orchestrateur applique.
##
## **Ce qu'il a perdu à F2b, et c'était annoncé.** `assault`, `defense` et `breach()` sont
## partis : les trois décrivaient l'arithmétique du bouchon — une puissance moins une
## défense — et DESIGN.md 3.6 les donnait pour jetables dès F1. Une vague n'a plus de
## « puissance » une fois qu'elle est une poignée de corps sur une grille, et publier un
## chiffre que plus personne ne calcule aurait fait dire à ce contrat ce que seul le
## bouchon savait faire. Ce qui les remplace n'est pas un autre chiffre mais des **faits** :
## ce qui est tombé, qui est mort, ce qui est parti.
##
## **Ce qu'il ne porte pas, et pourquoi.** Pas de blessure. DESIGN.md 3.6 en réclamait une
## jusqu'à F1, qui l'a déplacée vers X6 : une blessure a besoin d'un état qui dure, un
## Worker n'en porte aucun, et l'inventer ici aurait décidé pour les Effectifs de ce qu'un
## état fait. Le champ entrera le jour où il aura où atterrir — la règle que X6 pose est
## qu'un rapport **compte** un état sans décider de sa conséquence, ce que ce fichier fait
## déjà des pertes et UpkeepReport des non-nourris.
##
## Pas de nombre de manches non plus, alors que le plateau le connaît. Personne ne le lit
## hors du Combat, et un champ que personne ne franchit est la frontière que ce projet
## refuse depuis E1. Il entrera avec l'écran qui voudra dire « tenue cinq manches ».
##
## Il vit dans contracts/ et non dans domain/combat/, à l'inverse de SiteReport : trois
## systèmes du domaine le franchissent — Construction, Effectifs, Économie —, ce qui est
## exactement le critère de CLAUDE.md.
##
## Immuable.

## Ancre -> points encaissés, dans l'ordre où la vague les a frappés.
##
## Le journal complet des coups, morts compris : une ancre de _destroyed y figure avec ce
## qu'elle a pris avant de tomber. Séparer les deux tables ferait perdre le compte du
## dernier coup, qui est justement celui qui se raconte.
var _damaged: Dictionary[Vector2i, int] = {}

## Ancres des bâtiments tombés, dans l'ordre où ils sont tombés.
var _destroyed: Array[Vector2i] = []

## Ancres des seuls chantiers tombés, dans le même ordre.
var _interrupted: Array[Vector2i] = []

## Ouvriers que la vague a emportés, dans l'ordre où ils sont tombés.
var _lost: Array[StringName] = []

## Unités de réserve que la vague emporte.
##
## Un **total**, et non une répartition par ressource, et c'est une ligne de dépendance
## plutôt qu'une simplification. Répartir demanderait de voir le stock, donc le contenu du
## Ledger, qui est un interne de l'Économie — CLAUDE.md l'interdit à tout autre système. Ce
## que la vague décide est *combien* ; ce que la réserve perd est une question de la
## réserve, et Ledger.take_share() y répond avec sa propre règle de prorata.
var _plunder: int

## Qui a tenu la ligne, et dans quelle famille.
var _work: Array[WorkLine] = []

## La vague a-t-elle été balayée jusqu'au dernier ?
var _swept: bool

## Rapport d'une vague.
##
## L'ordre d'insertion des tables est celui dans lequel la vague a frappé, ce qui rend
## l'application déterministe sans avoir à trier : deux runs partis du même seed
## appliquent les mêmes ordres dans le même ordre.
static func create(damaged: Dictionary[Vector2i, int], destroyed: Array[Vector2i],
		interrupted: Array[Vector2i], lost: Array[StringName], plunder: int,
		work: Array[WorkLine], swept: bool) -> DamageReport:
	assert(plunder >= 0, "pillage négatif : %d" % plunder)
	var report := DamageReport.new()
	for anchor in damaged:
		assert(damaged[anchor] > 0,
			"bâtiment frappé de %d point(s) en %s" % [damaged[anchor], anchor])
		report._damaged[anchor] = damaged[anchor]
	for anchor in destroyed:
		assert(report._damaged.has(anchor),
			"bâtiment détruit en %s sans avoir été frappé" % anchor)
		report._destroyed.append(anchor)
	for anchor in interrupted:
		assert(report._destroyed.has(anchor),
			"chantier interrompu en %s sans avoir été détruit" % anchor)
		report._interrupted.append(anchor)
	report._plunder = plunder
	report._lost = lost.duplicate()
	report._work = work.duplicate()
	report._swept = swept
	return report

## Rapport d'une vague qui n'a rien pu faire. C'est l'état d'un village qui tient, et ce
## n'est pas une erreur.
##
## Le balayage reste un **argument** : tenir une vague et la détruire sont deux réussites
## différentes, et la seconde ne se déduit pas de la première. Un village qui bloque une
## porte pendant six manches tient sans avoir tué personne.
static func held(work: Array[WorkLine], swept: bool) -> DamageReport:
	var no_damage: Dictionary[Vector2i, int] = {}
	var no_anchor: Array[Vector2i] = []
	var no_loss: Array[StringName] = []
	return DamageReport.create(no_damage, no_anchor, no_anchor.duplicate(), no_loss,
		0, work, swept)

## La vague a-t-elle été contenue ?
##
## Une question plutôt qu'une comparaison recopiée partout : c'est la phrase que l'écran
## dira, et son docstring de F1 annonçait qu'elle « se redéfinira ici le jour où tenir une
## vague voudra dire autre chose que ne rien encaisser ». Ce jour est arrivé, et la
## définition n'a pas bougé d'un pouce — ce sont les termes qui ont changé de nature. Une
## brèche nulle disait la même chose par un intermédiaire ; ici on la constate.
##
## C'est aussi le seul is_empty() du projet qui a disparu au profit de son synonyme : deux
## noms pour une seule vérité finissent par ne plus dire la même chose.
func is_held() -> bool:
	return _damaged.is_empty() and _lost.is_empty() and _plunder <= 0

## Tous les assaillants sont-ils tombés ?
##
## DESIGN.md 3.6 : « Tenir N tours suffit à ce qu'elle reparte ; **battre tous les ennemis**
## donne un bonus par-dessus. » Ce rapport le **constate** et ne décide pas de ce qu'il
## vaut — le bonus est un chiffre d'équilibrage, donc I3, et c'est la règle que X6 pose déjà
## pour les états : un système qui rencontre un fait le compte, il n'invente pas sa
## conséquence.
##
## Il ne se déduit d'aucun autre champ : rien ici ne dit combien d'assaillants sont venus.
## C'est pourquoi il voyage plutôt que de se recalculer.
func swept() -> bool:
	return _swept

## Ancre -> points encaissés. Copie. Contient aussi les bâtiments tombés.
func damaged() -> Dictionary[Vector2i, int]:
	return _damaged.duplicate()

## Ancres des bâtiments tombés, dans l'ordre où ils sont tombés. Copie.
func destroyed() -> Array[Vector2i]:
	return _destroyed.duplicate()

## Ancres des seuls **chantiers** tombés, dans le même ordre. Copie.
##
## Un sous-ensemble strict de destroyed(), et rapporté à part pour une raison de récit
## plutôt que de règle : DESIGN.md 3.2 veut qu'« un chantier à moitié fini détruit la
## veille de la vague » soit une perte qui se raconte. Le recouper après coup demanderait
## la ville d'**avant** la vague, que plus personne ne tient une fois les ordres appliqués.
func interrupted() -> Array[Vector2i]:
	return _interrupted.duplicate()

## Ouvriers que la vague a emportés, dans l'ordre où ils sont tombés. Copie.
##
## L'ordre est celui de la **chute** depuis que le plateau produit ce rapport, et non
## celui du déploiement comme le rendait le bouchon. Rien n'en dépend — un mort est un
## mort, et l'orchestrateur les retire sans les lire dans l'ordre —, mais qui est tombé
## en premier se raconte, et c'est une information que l'autre ordre effaçait.
func lost() -> Array[StringName]:
	return _lost.duplicate()

## Unités de réserve que la vague emporte, toutes ressources confondues.
##
## Un ordre et non un fait, comme le reste du rapport : c'est ce que la vague **réclame**,
## et une réserve à moitié vide en donnera moins. Ce qu'elle a réellement perdu est ce que
## Ledger.take_share() rend à l'application.
func plunder() -> int:
	return _plunder

## Journal de ceux qui ont tenu la ligne. Copie.
##
## Des WorkLine, et non un format à part : SkillResolver.award_lines() existe depuis I1 et
## son docstring annonce depuis W1 que l'XP de combat « passera par le même gain() ». Elle
## y passe, et les Effectifs n'ont pas eu une ligne à écrire pour ça.
func work() -> Array[WorkLine]:
	return _work.duplicate()

## Qui a été engagé, dans l'ordre du déploiement. Copie.
##
## Dérivé du journal plutôt que stocké à côté : ce sont exactement les mêmes gens, et deux
## listes finiraient par diverger sur le même combat. Même geste que CitySnapshot, qui
## rend deux lectures d'une seule vérité.
##
## Les pertes en font partie : un mort a tenu la ligne. Ce qu'il advient de son XP est
## traité à l'application — SkillResolver saute un ouvrier que le roster ne connaît plus,
## donc l'ordre dans lequel l'orchestrateur crédite et retire décide, et il est écrit là-bas.
func fighters() -> Array[StringName]:
	var engaged: Array[StringName] = []
	for line in _work:
		engaged.append(line.worker())
	return engaged
