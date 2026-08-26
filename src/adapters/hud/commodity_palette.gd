class_name CommodityPalette
extends RefCounted
## Ce que le HUD sait d'une ressource : son rang, son libellé, sa couleur.
##
## Couche adapter, et rien d'autre. Elle ne calcule aucune quantité, ne juge aucun coût,
## et le domaine ne la connaît pas — c'est une table de correspondance entre un
## identifiant et de quoi le dessiner.
##
## Elle existe pour deux raisons qui se cumulent.
##
## La première est que **l'ordre des ressources à l'écran est une décision**, et qu'elle
## n'avait aucun endroit où vivre. `GameDatabase.list_commodity_ids()` trie par
## identifiant, donc en anglais interne : la nourriture — celle qui tue — atterrissait
## entre le minerai et la pierre. Le rang vit désormais sur la `CommodityData`, et cette
## classe est le seul endroit qui le lit.
##
## La seconde est un doublon que `E2` aurait porté à trois exemplaires.
## `run_harness._bundle()` et `economy_harness._bundle_text()` étaient la même fonction
## écrite deux fois, et un panneau de production en voulait une troisième. C'est le
## problème que le journal de `I1` note à propos de `_make_label()` : « elle n'appartient
## à aucun jalon, ce qui est précisément pourquoi elle ne se fait jamais ». Celle-ci
## appartient à celui-ci — afficher un lot de ressources *est* le sujet de `E2`.
##
## Elle lit `GameDatabase` une fois, à la construction. Un identifiant inconnu ne la fait
## pas tomber : elle rend son texte brut et une couleur neutre. Le boot refuse déjà un
## `.tres` qui nommerait une ressource inexistante, mais un `assert` ne survit pas à une
## export release, et une barre de ressources n'est pas l'endroit où découvrir ça.

## Couleur d'un identifiant que le catalogue ignore.
const UNKNOWN_COLOR := Color(0.55, 0.55, 0.58)

## Rang d'un identifiant que le catalogue ignore. Au-delà de la borne du champ, donc
## toujours après les ressources connues.
const UNKNOWN_ORDER := 1000

## Lot vide, en clair.
const EMPTY_BUNDLE := "—"

## Identifiants connus, du premier rang au dernier.
var _ordered: Array[StringName] = []

## Identifiant -> la CommodityData qui le décrit.
var _by_id: Dictionary[StringName, CommodityData] = {}

## Palette bâtie sur le catalogue indexé au boot.
##
## Le seul constructeur : une palette qui recevrait ses ressources d'ailleurs servirait à
## fabriquer des cas, et les vues n'ont pas besoin de ça — c'est le harnais qui fabrique
## des rapports, jamais un catalogue.
static func from_database() -> CommodityPalette:
	var palette := CommodityPalette.new()
	for id in GameDatabase.list_commodity_ids():
		var commodity := GameDatabase.get_commodity(id)
		if commodity == null:
			continue
		palette._by_id[id] = commodity
		palette._ordered.append(id)
	palette._ordered = palette._sorted(palette._ordered)
	return palette

## Les ressources du catalogue, dans l'ordre où le HUD les montre. Copie.
func ordered() -> Array[StringName]:
	return _ordered.duplicate()

## Le catalogue connaît-il cet identifiant ?
func has(id: StringName) -> bool:
	return _by_id.has(id)

## Libellé affichable, ou l'identifiant brut si le catalogue l'ignore.
func label_of(id: StringName) -> String:
	if not _by_id.has(id):
		return String(id)
	return _by_id[id].label

## Couleur d'affichage, ou une teinte neutre si le catalogue l'ignore.
func color_of(id: StringName) -> Color:
	if not _by_id.has(id):
		return UNKNOWN_COLOR
	return _by_id[id].color

## Rang d'affichage, ou un rang de queue si le catalogue l'ignore.
func order_of(id: StringName) -> int:
	if not _by_id.has(id):
		return UNKNOWN_ORDER
	return _by_id[id].order

## Les ressources d'un lot, dans l'ordre du HUD. Copie triée des clés.
##
## Le même ordre que `ordered()`, et c'est tout l'intérêt : la barre et le panneau
## alignent leurs colonnes sans que l'un ait à connaître l'autre.
func keys_of(bundle: Dictionary[StringName, int]) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(bundle.keys())
	return _sorted(ids)

## Un lot de ressources en clair, dans l'ordre du HUD. « — » pour un lot vide.
##
## Remplace `run_harness._bundle()` et `economy_harness._bundle_text()`, qui triaient
## tous deux par identifiant. La sortie change donc de « 1 Nourriture, 5 Bois » à « 5
## Bois, 1 Nourriture » : c'est l'ordre de la barre, et deux affichages du même lot
## doivent donner la même ligne.
func bundle_text(bundle: Dictionary[StringName, int]) -> String:
	if bundle.is_empty():
		return EMPTY_BUNDLE
	var parts := PackedStringArray()
	for id in keys_of(bundle):
		parts.append("%d %s" % [bundle[id], label_of(id)])
	return ", ".join(parts)

## Trie des identifiants par rang, puis par texte.
##
## Le repli sur le texte ne sert qu'aux inconnus : deux ressources du catalogue ne
## partagent jamais un rang, et un cas de test le tient. Il se fait sur `String(...)` et
## jamais par `sort()` — comparer deux `StringName` compare leurs pointeurs internes,
## donc rend un ordre stable le temps d'une session et différent à la suivante.
func _sorted(ids: Array[StringName]) -> Array[StringName]:
	var sorted := ids.duplicate()
	sorted.sort_custom(func(first: StringName, second: StringName) -> bool:
		var left := order_of(first)
		var right := order_of(second)
		if left != right:
			return left < right
		return String(first) < String(second))
	return sorted
