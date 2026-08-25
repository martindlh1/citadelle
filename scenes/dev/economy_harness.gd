extends Node
## Harnais de dev du système Économie — jalon E1 : la réserve, la résolution du soir,
## l'upkeep et la famine.
##
## Un rapport texte, comme celui de C1 : E1 n'a rien à montrer en 3D, le HUD est le
## sujet de E2. Ce qu'il y a à regarder ici, ce sont des chiffres qui s'enchaînent.
##
## Il ne décide rien. Il compose deux systèmes du domaine et affiche ce qu'ils rendent.
## C'est précisément le rôle que DESIGN.md 3.2 donne à « la couche qui orchestre la
## journée », et qui reviendra à RunOrchestrator à I1 : poser une carte demande deux
## questions distinctes — **payable**, puis **posable** — et c'est ici qu'elles
## s'enchaînent, jamais dans le validateur.
##
## Comme le harnais de C1, il **cherche** ses cas au lieu de les mettre en scène. Il
## laisse tourner les soirs et dit lequel a cassé le premier : la famine ou la réserve
## pleine. Une suite de tests ne peut pas répondre à ça — elle travaille sur des
## chiffres choisis, quand la question porte justement sur ceux de data/balance/.

## Seed de la carte. Fixe : deux lancements doivent se comparer.
const SEED := 1234

## Nombre de soirs simulés.
const EVENINGS := 20

## Taille du roster. Volontairement au-dessus du nombre de postes : l'upkeep tombe sur
## tout le monde, et c'est ce qu'il faut voir.
const ROSTER := 10

## Ce que le harnais tente de bâtir, dans cet ordre.
##
## Les deux derniers sont hors de portée à l'ouverture, chacun pour une raison
## différente, et c'est voulu. La **mine** demande 10 pierre que la carte ne donne pas
## au premier jour : il faut que la carrière les produise. La seconde **ferme** ne
## demande que du bois, mais la bourse est vide — un refus qui n'est pas un refus de
## placement. Les deux entrent dans la file et se posent quand l'économie le permet.
const BUILD_ORDER: Array[StringName] = [
	&"warehouse", &"farm", &"quarry", &"lumberjack_hut", &"palisade", &"mine", &"farm",
]

## Rendu quand aucune cellule ne convient.
const NO_CELL := Vector2i(-1, -1)

## Largeur de la colonne « produit », en caractères. Assez pour les quatre ressources
## du catalogue à trois chiffres chacune : en dessous, la colonne déborde et tout le
## tableau se décale à partir du soir où la mine entre en service.
const PRODUCED_WIDTH := 46

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13

var _grid: HeightGrid
var _terrain: TerrainQuery
var _city: CityState
var _ledger: Ledger
var _economy: EconomyBalance
var _lines := PackedStringArray()

## Ce que la bourse a refusé à l'ouverture, dans l'ordre. Se vide un soir à la fois.
var _deferred: Array[StringName] = []

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_economy = balance.economy
	_grid = TerrainGen.generate(SEED, balance.terrain_gen.map_size, balance.terrain_gen)
	_terrain = _grid.to_query()
	_city = CityState.new()
	_ledger = Ledger.from_stock(_economy.starting_stock, _economy.base_storage_cap)

	_report_opening()
	_report_construction()
	_report_workforce()
	_report_evenings()

	var text := "\n".join(_lines)
	print(text)
	add_child(_make_label(text))

func _report_opening() -> void:
	_lines.append("Citadelle — harnais Économie (E1)")
	_lines.append("Carte seed %d, %s" % [SEED, _grid.size()])
	_lines.append("")
	_lines.append("Réserve d'ouverture : %s — %d/%d"
		% [_bundle_text(_ledger.amounts()), _ledger.total(), _ledger.capacity()])
	_lines.append("")

## Chaque pose enchaîne les deux questions dans cet ordre : la bourse d'abord, la carte
## ensuite, la dépense en dernier. L'ordre compte — payer avant de savoir si ça tient
## sur le relief laisserait la ville plus pauvre sans rien de bâti.
func _report_construction() -> void:
	_lines.append("Construction — deux questions distinctes, cf. DESIGN.md 3.2")
	for id in BUILD_ORDER:
		var data := GameDatabase.get_building(id)
		if data == null:
			_lines.append("  %-16s introuvable dans data/buildings/" % id)
			continue
		_lines.append("  %-16s %s" % [id, _build(data)])
	# Un entrepôt compte dès qu'il est bâti et non au prochain soir : sans cette ligne,
	# le rapport annoncerait la capacité d'avant juste au-dessus de celle d'après. La
	# résolution la repose de toute façon, ce qui rend l'oubli silencieux — donc à
	# écrire ici, là où le HUD de E2 le fera aussi.
	_ledger.set_capacity(_capacity())
	_lines.append("")
	_lines.append("Réserve après construction : %s — %d/%d"
		% [_bundle_text(_ledger.amounts()), _ledger.total(), _ledger.capacity()])
	_lines.append("  capacité %d = %d de base + %d d'entrepôt"
		% [_capacity(), _economy.base_storage_cap, _capacity() - _economy.base_storage_cap])
	_lines.append("")

func _build(data: BuildingData) -> String:
	var anchor := _first_valid_anchor(data)
	if anchor == NO_CELL:
		return "aucune ancre ne l'accepte sur cette carte"
	if not _ledger.can_afford(data.cost):
		_deferred.append(data.id)
		return "posable en %s, impayable : %s — mis en file" % [anchor, _bundle_text(data.cost)]
	if not _place(data, anchor):
		return "refus inattendu en %s" % anchor
	if data.cost.is_empty():
		return "posé en %s, gratuit" % anchor
	return "posé en %s pour %s" % [anchor, _bundle_text(data.cost)]

## Pose, dépense, et **achève le chantier sur-le-champ**, la bourse ayant déjà répondu
## oui. Partagée entre la construction d'ouverture et la file, pour que les deux paient
## exactement de la même façon.
##
## L'achèvement immédiat est un choix, pas un oubli. Depuis C4 une pose ouvre un
## chantier, et ce harnais n'a aucune action *Construire* à lui jeter dessus — la carte
## est D1 et D2. Sans ça, ses sept bâtiments resteraient des chantiers pendant vingt
## soirs et le rapport tomberait à zéro partout.
##
## L'alternative — un cran par soir — est la version intéressante, et elle répondrait à
## une vraie question : ce que le délai de chantier coûte à l'économie. Elle déplacerait
## en revanche tous les repères écrits aux journaux de E1b et W1 — le soir où la mine se
## paie, celui où la famine cesse — depuis un jalon dont le sujet est la Construction.
## Elle a un meilleur moment : I1, où l'orchestrateur séquence une vraie journée et où
## le délai est **joué** au lieu d'être simulé par un harnais qui fait semblant d'avoir
## des cartes. Le chantier se regarde d'ici là dans le harnais Construction, qui est
## fait pour ça.
func _place(data: BuildingData, anchor: Vector2i) -> bool:
	if not _city.place(_terrain, data, anchor).is_ok():
		return false
	while _city.advance(anchor):
		pass
	_ledger.spend(data.cost)
	return true

## Tente la tête de file, et rend l'identifiant posé ou &"" si rien ne bouge.
##
## Un seul par soir : ce qu'on veut lire, c'est le soir où chaque chose devient
## payable, pas une ville qui apparaît d'un coup. La file ne se réordonne jamais —
## un bâtiment cher ne doit pas se faire doubler par un moins cher derrière lui,
## sinon le harnais répondrait à une question qu'on ne lui pose pas.
func _drain_queue() -> StringName:
	if _deferred.is_empty():
		return &""
	var id: StringName = _deferred[0]
	var data := GameDatabase.get_building(id)
	if data == null or not _ledger.can_afford(data.cost):
		return &""
	var anchor := _first_valid_anchor(data)
	if anchor == NO_CELL or not _place(data, anchor):
		return &""
	_deferred.remove_at(0)
	return id

## Première ancre que le domaine accepte, balayée dans un ordre fixe.
##
## Elle n'est pas payée ici : validate() est pure et ne mute rien, ce que C1 a rendu
## appelable exprès. La bourse se consulte juste après, sur une ancre déjà connue.
func _first_valid_anchor(data: BuildingData) -> Vector2i:
	var size := _grid.size()
	for y in size.y:
		for x in size.x:
			var anchor := Vector2i(x, y)
			if PlacementValidator.validate(_city, _terrain, data, anchor).is_ok():
				return anchor
	return NO_CELL

func _report_workforce() -> void:
	var assign := _assignment()
	_lines.append("Effectifs : %d ouvriers, %d affectés au départ, %d oisifs"
		% [ROSTER, assign.size(), ROSTER - assign.size()])
	_lines.append("  l'upkeep tombe sur les %d, oisifs compris — %d nourriture par soir"
		% [ROSTER, ROSTER * _economy.upkeep_per_worker])
	_lines.append("")

## Les postes se remplissent dans l'ordre de pose, et on s'arrête quand il n'y en a
## plus. Le reste du roster chôme, ce qui est exactement ce qu'on veut voir payer.
func _assignment() -> Assignment:
	var table: Dictionary[StringName, Vector2i] = {}
	var hired := 0
	for building in _city.buildings():
		var data := building.data()
		if not data.produces():
			continue
		for _slot in data.production.slots:
			if hired >= ROSTER:
				break
			table[_worker(hired)] = building.anchor()
			hired += 1
	return Assignment.create(table)

## L'affectation se refait à chaque soir, et non une fois pour toutes : la file peut
## poser un bâtiment en cours de route, et ses postes seraient restés vides.
func _report_evenings() -> void:
	var labor := _labor()
	var first_famine := 0
	var first_full := 0
	_lines.append("soir  %-*s réserve    upkeep  mangé  à jeun"
		% [PRODUCED_WIDTH, "produit"])
	for evening in range(1, EVENINGS + 1):
		var raised := _drain_queue()
		var report := ProductionResolver.resolve(_city.to_snapshot(), _assignment(), labor,
			_ledger, _economy)
		if first_famine == 0 and report.is_famine():
			first_famine = evening
		if first_full == 0 and _ledger.is_full():
			first_full = evening
		var notes := PackedStringArray()
		if not raised.is_empty():
			notes.append("← %s posé" % raised)
		if evening == first_famine:
			notes.append("← famine")
		_lines.append(("%4d  %-*s %4d/%-4d %6d %6d %6d   %s"
			% [evening, PRODUCED_WIDTH, _bundle_text(report.produced()), _ledger.total(),
				_ledger.capacity(), report.upkeep(), report.consumed(), report.unfed(),
				", ".join(notes)]).rstrip(" "))
	_lines.append("")
	_lines.append(_verdict(first_famine, first_full))

## Ce que la suite de tests ne peut pas dire : avec les chiffres de data/balance/, qui
## casse en premier. Une réserve qui se remplirait avant la première famine voudrait
## dire que le plafond ne mord jamais, et donc que le réglage est à revoir.
func _verdict(first_famine: int, first_full: int) -> String:
	var famine := "soir %d" % first_famine if first_famine > 0 else "jamais en %d soirs" % EVENINGS
	var full := "soir %d" % first_full if first_full > 0 else "jamais — %d/%d au dernier" \
		% [_ledger.total(), _ledger.capacity()]
	return "Première famine : %s.\nRéserve pleine : %s." % [famine, full]

## Roster d'ouvriers sans aucune piste entamée. Fabriqué à la main : W1 n'existe pas,
## et l'Économie ne sait pas d'où viennent ses effectifs — c'est le contrat.
func _labor() -> LaborForce:
	var units: Array[LaborUnit] = []
	for index in ROSTER:
		units.append(LaborUnit.novice(_worker(index)))
	return LaborForce.create(units)

func _worker(index: int) -> StringName:
	return StringName("ouvrier_%d" % (index + 1))

func _capacity() -> int:
	return ProductionResolver.capacity_for(_city.to_snapshot(), _economy)

## Lot rendu lisible, trié par identifiant.
##
## Le tri se fait sur le texte et non sur le StringName : deux affichages du même lot
## doivent donner la même ligne, or comparer deux StringName compare des pointeurs.
func _bundle_text(bundle: Dictionary[StringName, int]) -> String:
	if bundle.is_empty():
		return "—"
	var ids: Array[StringName] = []
	ids.assign(bundle.keys())
	ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second))
	var parts := PackedStringArray()
	for id in ids:
		var commodity := GameDatabase.get_commodity(id)
		var label := commodity.label if commodity != null else String(id)
		parts.append("%d %s" % [bundle[id], label])
	return ", ".join(parts)

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.name = "EconomyReport"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi le tableau des soirs se désaligne colonne par
## colonne et devient illisible.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
