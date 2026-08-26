class_name DamageReport
extends RefCounted
## Ce qu'une vague a **ordonné** : ce qu'elle casse, qui elle emporte, ce qu'elle vole,
## et ce que la ligne a valu à ceux qui l'ont tenue.
##
## Le seul contrat de sortie du Combat. DESIGN.md 3.6 : « C'est **le seul** contrat qui
## compte. Tout ce qui se passe entre les deux est remplaçable sans toucher au reste du
## jeu. » Ce fichier est donc écrit pour survivre à l'InstantCombatResolver qui le
## produit aujourd'hui — c'est un bouchon, ce rapport ne l'est pas.
##
## **Il ordonne, il ne mute rien**, profil de SiteReport et pour la même raison, en plus
## fort : il touche l'état de **trois** autres systèmes — la ville, le roster, la réserve.
## Un résolveur de Combat qui les muterait violerait la règle de dépendance trois fois.
## Le chemin propre est celui de I1 : le résolveur ordonne, l'orchestrateur applique.
##
## **Ce qu'il ne porte pas, et pourquoi.** Pas de blessure. DESIGN.md 3.6 en réclamait une
## jusqu'à F1, qui l'a déplacée vers X6 : une blessure a besoin d'un état qui dure, un
## Worker n'en porte aucun, et l'inventer ici aurait décidé pour les Effectifs de ce qu'un
## état fait. Le champ entrera le jour où il aura où atterrir — la règle que X6 pose est
## qu'un rapport **compte** un état sans décider de sa conséquence, ce que ce fichier fait
## déjà des pertes et UpkeepReport des non-nourris.
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

## Ouvriers que la vague a emportés, dans l'ordre du déploiement.
var _lost: Array[StringName] = []

## Ce que la vague a volé dans la réserve.
var _plunder: Dictionary[StringName, int] = {}

## Qui a tenu la ligne, et dans quelle famille.
var _work: Array[WorkLine] = []

## Puissance de la vague.
var _assault: int

## Ce que la ville et les engagés lui opposaient.
var _defense: int

## Rapport d'une vague.
##
## L'ordre d'insertion des tables est celui dans lequel la vague a frappé, ce qui rend
## l'application déterministe sans avoir à trier : deux runs partis du même seed
## appliquent les mêmes ordres dans le même ordre.
static func create(damaged: Dictionary[Vector2i, int], destroyed: Array[Vector2i],
		interrupted: Array[Vector2i], lost: Array[StringName],
		plunder: Dictionary[StringName, int], work: Array[WorkLine],
		assault: int, defense: int) -> DamageReport:
	assert(assault >= 0, "vague de puissance négative : %d" % assault)
	assert(defense >= 0, "défense négative : %d" % defense)
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
	for resource in plunder:
		assert(plunder[resource] > 0,
			"pillage de %d en %s" % [plunder[resource], resource])
		report._plunder[resource] = plunder[resource]
	report._lost = lost.duplicate()
	report._work = work.duplicate()
	report._assault = assault
	report._defense = defense
	return report

## Rapport d'une vague qui n'a rien pu faire. C'est l'état d'un village qui tient, et ce
## n'est pas une erreur.
static func held(assault: int, defense: int, work: Array[WorkLine]) -> DamageReport:
	var no_damage: Dictionary[Vector2i, int] = {}
	var no_anchor: Array[Vector2i] = []
	var no_loss: Array[StringName] = []
	var no_plunder: Dictionary[StringName, int] = {}
	return DamageReport.create(no_damage, no_anchor, no_anchor.duplicate(), no_loss,
		no_plunder, work, assault, defense)

## Puissance de la vague.
func assault() -> int:
	return _assault

## Ce que la ville et les engagés lui opposaient.
func defense() -> int:
	return _defense

## Ce qui est passé, borné à zéro. C'est le seul chiffre dont tout le reste découle.
func breach() -> int:
	return maxi(0, _assault - _defense)

## La vague a-t-elle été contenue ?
##
## Une question plutôt qu'un `breach() == 0` recopié partout : c'est la phrase que l'écran
## dira, et le jour où tenir une vague voudra dire autre chose que ne rien encaisser, elle
## se redéfinira ici.
func is_held() -> bool:
	return breach() <= 0

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

## Ouvriers que la vague a emportés, dans l'ordre du déploiement. Copie.
func lost() -> Array[StringName]:
	return _lost.duplicate()

## Ce que la vague a volé, par ressource. Copie.
func plunder() -> Dictionary[StringName, int]:
	return _plunder.duplicate()

## Total pillé, toutes ressources confondues.
func total_plunder() -> int:
	var stolen := 0
	for resource in _plunder:
		stolen += _plunder[resource]
	return stolen

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

## Le village a-t-il perdu quelque chose ?
func is_empty() -> bool:
	return _damaged.is_empty() and _lost.is_empty() and _plunder.is_empty()
