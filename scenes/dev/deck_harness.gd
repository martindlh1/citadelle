extends Node
## Harnais de dev du système Cartes — jalon D1 : les trois pools, la pioche, la
## défausse, le remélange et le draft.
##
## Un rapport texte, comme ceux de E1 et W1 : D1 n'a rien à montrer en 3D, la main à
## l'écran est le sujet de D2. Il imprime sur la sortie standard en plus de l'écran, donc
## `godot --headless --quit` suffit à le lire.
##
## Comme les quatre précédents, il **cherche** au lieu de mettre en scène. Trois choses
## qu'aucune suite de tests ne peut dire, parce qu'elles travaillent sur des catalogues
## choisis et sur un seed :
##
##   - à quelle cadence la pioche d'actions boucle, donc tous les combien de tours on
##     revoit une carte donnée ;
##   - à quelle fréquence une phase n'offre **aucune carte Construire** — la tension que
##     DESIGN.md 3.2 annonce quand il dit que piocher un bâtiment sans les Construire
##     pour le finir est une vraie situation ;
##   - ce qu'un draft change à ces deux chiffres, c'est-à-dire si grossir son deck aide
##     ou dilue.
##
## Les deux derniers se mesurent sur deux cents seeds, pas sur un : une fréquence lue sur
## un run ne dit rien, et c'est justement le genre de chiffre qu'un test ne peut pas
## asserter sans figer un tirage.
##
## Rien ici ne joue une carte ni n'affecte un ouvrier : le Deck ne connaît ni ville ni
## roster, et ce qu'une carte **fait** appartient à D2.

## Phases détaillées dans la table. Assez pour que la pioche d'actions boucle plusieurs
## fois avec les chiffres de data/ : en dessous, la colonne « remélange » reste vide.
const PHASES := 8

## Seeds échantillonnés pour le verdict, et phases jouées sur chacun.
const SAMPLE_RUNS := 200
const SAMPLE_PHASES := 8

## Seed du run détaillé, et base des seeds échantillonnés.
const SEED := 20260825

## Drafts d'action appliqués avant de remesurer. Quatre : de quoi grossir le pool
## d'actions de 40 % avec les chiffres de data/, donc de quoi voir la dilution si elle
## existe.
const DRAFTS := 4

## La carte dont on suit la présence en main. C'est celle qui avance un chantier, donc
## celle dont l'absence se paie — DESIGN.md 3.2.
const TRACKED := &"build"

## Largeurs des deux colonnes de main. En dessous, les libellés français débordent dès
## qu'une main tire trois cartes à long nom.
const ACTION_WIDTH := 56
const BUILDING_WIDTH := 34

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13

var _catalogue: CardCatalogue
var _balance: DeckBalance
var _lines := PackedStringArray()

func _ready() -> void:
	_balance = GameDatabase.get_balance().deck
	_catalogue = _make_catalogue()

	_report_opening()
	_report_phases()
	_report_draft()
	_report_verdict()

	var text := "\n".join(_lines)
	print(text)
	add_child(_make_label(text))

func _report_opening() -> void:
	_lines.append("Citadelle — harnais Cartes (D1)")
	_lines.append("")
	_lines.append("Catalogue : %d cartes — %s" % [_catalogue.size(), _pool_census()])
	var deck := _make_deck()
	_lines.append("Deck de départ : %d exemplaires — %s"
		% [deck.size(), _deck_census(deck)])
	for pool in CardData.POOLS:
		var composition := _composition(pool)
		if composition.is_empty():
			continue
		_lines.append("  %-9s %s" % [pool, composition])
	_lines.append("Main par phase : %d action, %d building, %d power"
		% [_hand_of(CardData.POOL_ACTION), _hand_of(CardData.POOL_BUILDING),
			_hand_of(CardData.POOL_POWER)])
	_lines.append("")

func _report_phases() -> void:
	var rng := _rng(SEED)
	var deck := _open(rng)
	_lines.append("Huit phases sur le seed %d — pioche, main, défausse." % SEED)
	_lines.append("")
	_lines.append(" phase | %-*s | %-*s | pioche | remélange"
		% [ACTION_WIDTH, "main d'actions", BUILDING_WIDTH, "main de bâtiments"])
	_lines.append(" ------+-%s-+-%s-+--------+----------"
		% ["-".repeat(ACTION_WIDTH), "-".repeat(BUILDING_WIDTH)])
	for phase in PHASES:
		var before := deck.draw_size(CardData.POOL_ACTION)
		var actions := deck.draw(CardData.POOL_ACTION,
			_hand_of(CardData.POOL_ACTION), rng)
		var buildings := deck.draw(CardData.POOL_BUILDING,
			_hand_of(CardData.POOL_BUILDING), rng)
		deck.draw(CardData.POOL_POWER, _hand_of(CardData.POOL_POWER), rng)
		var recycled := "oui" if actions.size() > before else "—"
		_lines.append(" %5d | %-*s | %-*s | %3d/%-2d | %s"
			% [phase + 1,
				ACTION_WIDTH, _fit(_labels(actions), ACTION_WIDTH),
				BUILDING_WIDTH, _fit(_labels(buildings), BUILDING_WIDTH),
				deck.draw_size(CardData.POOL_ACTION),
				deck.draw_size(CardData.POOL_BUILDING),
				recycled])
		deck.discard_hand()
	_lines.append("")
	_lines.append("La colonne pioche donne ce qui reste — actions/bâtiments — une fois la")
	_lines.append("main tirée. Le pool des powers est pioché comme les deux autres et ne")
	_lines.append("rend rien : data/ règle sa main à zéro, et il est vide jusqu'à X4.")
	_lines.append("")

func _report_draft() -> void:
	var rng := _rng(SEED)
	var deck := _open(rng)
	var offer := DraftPool.offer(_catalogue, CardData.POOL_ACTION,
		_balance.draft_choices, rng)
	_lines.append("Draft — %d cartes d'action proposées : %s"
		% [_balance.draft_choices, _labels(offer)])
	if offer.is_empty():
		_lines.append("")
		return
	var before := deck.total(CardData.POOL_ACTION)
	deck.add(offer[0])
	_lines.append("  prise « %s » : %d exemplaires d'action, puis %d. Elle entre par la"
		% [_label(offer[0]), before, deck.total(CardData.POOL_ACTION)])
	_lines.append("  défausse (%d carte) et non par la pioche, pour ne pas passer devant"
		% deck.discard_size(CardData.POOL_ACTION))
	_lines.append("  ce qui attend son tour.")
	var dropped := offer[offer.size() - 1]
	var removed := deck.remove(dropped)
	_lines.append("  retrait « %s » : %s, %d exemplaires d'action restants."
		% [_label(dropped), "retirée" if removed else "le deck n'en avait pas",
			deck.total(CardData.POOL_ACTION)])
	_lines.append("")

func _report_verdict() -> void:
	var plain := _measure(0)
	var drafted := _measure(DRAFTS)
	_lines.append("Verdict — mesuré sur %d seeds × %d phases." % [SAMPLE_RUNS, SAMPLE_PHASES])
	_lines.append("")
	_lines.append("  Retour. Une main revoit « %s » toutes les %.2f phases en moyenne, sur"
		% [_label(TRACKED), plain[&"return"]])
	_lines.append("  %d exemplaires dans un pool d'actions qui en tient %d."
		% [_copies_of(TRACKED), _make_deck().total(CardData.POOL_ACTION)])
	_lines.append("")
	_lines.append("  Tension. %.1f %% des phases n'offrent aucune carte « %s ». C'est ce"
		% [plain[&"missing"], _label(TRACKED)])
	_lines.append("  que DESIGN.md 3.2 annonce : un chantier posé qui attend une carte qui")
	_lines.append("  ne vient pas, et une main de bâtiments qu'on ne peut pas finir.")
	_lines.append("")
	_lines.append("  Draft. Après %d drafts d'action pris au hasard dans l'offre, le retour"
		% DRAFTS)
	_lines.append("  passe à %.2f phases et le manque à %.1f %%."
		% [drafted[&"return"], drafted[&"missing"]])
	_lines.append("  %s" % _draft_reading(plain, drafted))

## Ce que les deux mesures disent une fois comparées.
##
## La phrase se choisit sur le signe de l'écart plutôt que d'être écrite d'avance : un
## verdict qui conclurait toujours la même chose ne mesurerait rien.
func _draft_reading(plain: Dictionary[StringName, float],
		drafted: Dictionary[StringName, float]) -> String:
	if drafted[&"missing"] > plain[&"missing"]:
		return "Grossir le deck dilue : chaque carte précise revient moins souvent."
	if drafted[&"missing"] < plain[&"missing"]:
		return "Grossir le deck aide encore : le pool est trop petit pour se diluer."
	return "Le draft ne déplace rien à cette échelle."

## Fréquence des phases sans la carte suivie, et délai de son retour, sur un échantillon
## de seeds.
##
## Ce qui est mesuré est le **retour de la carte** et non l'intervalle entre deux
## remélanges. Le second a d'abord été écrit et s'est révélé muet : il vaut deux phases
## que le pool d'actions en tienne dix ou quatorze, parce qu'une pioche rechargée en
## garde toujours assez pour exactement une main de plus. Il dit quelque chose de vrai
## sur les piles et rien sur le jeu. Le remélange se voit dans la table au-dessus, où il
## a sa colonne ; ici on demande ce que le joueur ressent — au bout de combien de phases
## la carte qu'il attend revient.
##
## Le délai se compte entre **deux apparitions successives**, jamais depuis le début du
## run : la première attente commence sur une pioche pleine, qui n'est pas l'état
## courant, et la compter décalerait la moyenne sans rien mesurer.
##
## Le draft applique une politique volontairement bête — prendre la première carte de
## l'offre —, ce qui est le point : elle est déterministe et sans jugement, donc le
## chiffre mesure la **dilution** et non l'habileté d'un drafteur.
func _measure(drafts: int) -> Dictionary[StringName, float]:
	var without := 0
	var phases := 0
	var gaps := 0
	var intervals := 0
	for run in SAMPLE_RUNS:
		var rng := _rng(SEED + run)
		var deck := _open(rng)
		for _draft in drafts:
			var offer := DraftPool.offer(_catalogue, CardData.POOL_ACTION,
				_balance.draft_choices, rng)
			if not offer.is_empty():
				deck.add(offer[0])
		var last_seen := -1
		for phase in SAMPLE_PHASES:
			var drawn := deck.draw(CardData.POOL_ACTION,
				_hand_of(CardData.POOL_ACTION), rng)
			deck.draw(CardData.POOL_BUILDING, _hand_of(CardData.POOL_BUILDING), rng)
			if drawn.has(TRACKED):
				if last_seen >= 0:
					gaps += phase - last_seen
					intervals += 1
				last_seen = phase
			else:
				without += 1
			phases += 1
			deck.discard_hand()
	var measured: Dictionary[StringName, float] = {}
	measured[&"missing"] = 100.0 * without / maxi(phases, 1)
	measured[&"return"] = float(gaps) / maxf(float(intervals), 1.0)
	return measured

## Un deck neuf, ses trois pools mélangés. C'est ce que RunOrchestrator fera à
## l'ouverture d'un run — create() ne mélange pas, exprès.
func _open(rng: RandomNumberGenerator) -> Deck:
	var deck := _make_deck()
	for pool in CardData.POOLS:
		deck.shuffle(pool, rng)
	return deck

func _make_deck() -> Deck:
	return Deck.create(_catalogue, _balance.starting_deck)

## Le catalogue, dans l'ordre trié que GameDatabase rend. Cet ordre est ce que les
## offres de draft mélangent : le prendre trié le rend stable d'une session à l'autre.
func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

## Exemplaires de cette carte dans le deck de départ.
func _copies_of(card: StringName) -> int:
	if not _balance.starting_deck.has(card):
		return 0
	return _balance.starting_deck[card]

## Combien de cartes de ce pool une phase pioche.
func _hand_of(pool: StringName) -> int:
	if not _balance.hand_size.has(pool):
		return 0
	return _balance.hand_size[pool]

## Le catalogue pool par pool : « 4 action, 12 building, 0 power ».
func _pool_census() -> String:
	var parts := PackedStringArray()
	for pool in CardData.POOLS:
		parts.append("%d %s" % [_catalogue.ids_in(pool).size(), pool])
	return ", ".join(parts)

## Le deck pool par pool, exemplaires compris.
func _deck_census(deck: Deck) -> String:
	var parts := PackedStringArray()
	for pool in CardData.POOLS:
		parts.append("%d %s" % [deck.total(pool), pool])
	return ", ".join(parts)

## Ce que le deck de départ met dans ce pool : « 4 Récolter, 3 Construire ».
func _composition(pool: StringName) -> String:
	var parts := PackedStringArray()
	for card in _balance.starting_deck:
		if not _catalogue.has(card) or _catalogue.pool_of(card) != pool:
			continue
		parts.append("%d %s" % [_balance.starting_deck[card], _label(card)])
	return ", ".join(parts)

## Les libellés de ces cartes, dans l'ordre, ou « — » si la main est vide.
func _labels(cards: Array[StringName]) -> String:
	if cards.is_empty():
		return "—"
	var parts := PackedStringArray()
	for card in cards:
		parts.append(_label(card))
	return ", ".join(parts)

## Libellé d'une carte, ou son identifiant si le catalogue l'ignore.
func _label(card: StringName) -> String:
	if not _catalogue.has(card):
		return String(card)
	return _catalogue.card(card).label

## Le texte tenu dans cette largeur, coupé sur une ellipse s'il déborde.
func _fit(text: String, width: int) -> String:
	if text.length() <= width:
		return text
	return "%s…" % text.substr(0, width - 1)

func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.name = "DeckReport"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi la table se désaligne colonne par colonne.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
