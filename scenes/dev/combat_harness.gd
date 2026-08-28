extends Node
## Harnais de dev du système Combat — jalon `F1` : le bouchon arithmétique, la borne de
## déploiement, et ce qu'une brèche coûte.
##
## Un rapport texte, comme ceux de `E1` et `W1`. `DESIGN.md` 3.6 veut le bouchon « purement
## arithmétique et **sans vue** » : il n'y a rien à montrer en 3D, et la vue de combat est
## `F3`.
##
## Comme les précédents, il **cherche** au lieu de mettre en scène. Quatre questions
## qu'aucune suite de tests ne peut poser, parce qu'elles portent sur les chiffres de
## `data/` et non sur les règles :
##
##   - **combien de murs il faut** pour tenir chacune des trois vagues du catalogue ;
##   - **ce qu'une palissade achète** par rapport à ses cinq bois, et si elle vaut mieux
##     qu'un homme de plus sur la ligne ;
##   - **si un roster qui s'aguerrit rattrape jamais de la pierre**, ce qui est la question
##     que la borne de déploiement pose vraiment ;
##   - **ce qu'une seconde vague finit** de ce que la première avait entamé, qui est la
##     seule chose ici qu'une table ne peut pas dire.
##
## Les vagues et les bâtiments viennent des vrais `.tres` : la question porte justement sur
## ces chiffres-là. Le roster et la ville sont fabriqués, comme au harnais Effectifs — le
## sujet est la courbe, pas la carte.

## Prénoms du roster de mesure. Inventés et codés en dur, comme au harnais Effectifs : un
## catalogue de prénoms dans `data/` est du contenu, donc `I3`.
const GIVEN_NAMES: PackedStringArray = [
	"Alaric", "Brenne", "Cadoc", "Doria", "Elric", "Fenn", "Gwen", "Hervé",
]

## Bâtiments du village de mesure, dans l'ordre où on les ajoute.
##
## Le Cœur d'abord parce qu'un run l'a toujours, puis ce qui produit, puis ce qui défend.
## L'ordre de cette liste ne change **rien** au résultat — c'est la règle de `DESIGN.md`
## 3.6 —, et le fait qu'on puisse le réordonner sans que le rapport bouge est en soi une
## vérification.
const VILLAGE: Array[StringName] = [
	&"heart", &"lumberjack_hut", &"farm", &"warehouse", &"house",
]

## Ce qu'on ajoute au village de mesure, cran par cran, pour voir ce que ça achète.
const REINFORCEMENTS: Array[StringName] = [
	&"palisade", &"palisade", &"palisade", &"watchtower", &"barracks",
]

## Rosters à confronter à la même vague. Le premier est le roster de mesure ; les autres
## disent ce que la borne fait d'un vivier plus large.
const CROWD_SIZES: Array[int] = [3, 5, 8]

## Écartement des ancres. Aucune importance : rien ici ne valide un placement, la ville de
## mesure est un `CitySnapshot` fabriqué.
const ANCHOR_STRIDE := 3

## Paliers de piste Combat parcourus par la table de progression. Le plafond réel vient de
## `data/balance/`, et la table s'y arrête d'elle-même.
const TRACK_LEVELS := 6

## Vagues de la chronique finale. Une de plus qu'il n'y en a au catalogue, exprès : les
## trois premières montent en puissance et le village tient les deux premières, si bien
## qu'aucune ne trouverait de mur déjà entamé. C'est la **quatrième**, qui rejoue la plus
## dure, qui montre ce qu'aucune table ne peut dire — les dégâts restent sur les murs et
## les morts ne reviennent pas.
const CHRONICLE_WAVES := 4

## Seed de la chronique. Le run est ouvert pour de vrai, donc il lui en faut un.
const SEED := 4413

const NAME_WIDTH := 22
const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13

var _combat: CombatBalance
var _workforce: WorkforceBalance
var _waves: Array[WaveDef] = []
var _lines := PackedStringArray()

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_combat = balance.combat
	_workforce = balance.workforce
	_waves = _make_waves()

	_report_opening()
	_report_walls()
	_report_the_line()
	_report_the_cap()
	_report_chronicle(balance)
	_report_verdict()

	var text := "\n".join(_lines)
	print(text)
	add_child(_make_label(text))

func _report_opening() -> void:
	_lines.append("Citadelle — harnais Combat (F1)")
	_lines.append("")
	_lines.append("Réglages de data/balance/combat_balance.tres")
	_lines.append("  %d place(s) de déploiement de base, +ce que les bâtiments ouvrent"
		% _combat.base_deployment_slots)
	_lines.append("  %d de défense par homme engagé, avant son multiplicateur"
		% _combat.defense_per_fighter)
	_lines.append("  un mort tous les %d points de brèche, %d unité(s) pillée(s) par point"
		% [_combat.breach_per_casualty, _combat.plunder_per_breach])
	_lines.append("  piste créditée : « %s »" % _combat.combat_skill_family)
	_lines.append("")
	_lines.append("Vagues de data/waves/, par puissance croissante")
	for wave in _waves:
		_lines.append("  %-*s %3d" % [NAME_WIDTH, wave.label, wave.power])
	_lines.append("")

## Ce que chaque mur achète, cran par cran.
##
## La première ligne est le village nu : c'est le point de comparaison sans lequel les
## suivantes ne veulent rien dire. Chaque ligne ajoute un bâtiment de REINFORCEMENTS et
## dit ce que la défense est devenue, et laquelle des vagues tient.
##
## Le roster est le **plus large** des trois, et ce n'est pas un détail de présentation :
## avec trois ouvriers, la caserne n'ouvre que des places que personne ne vient occuper, et
## sa ligne est identique à la précédente. La table ferait alors passer pour inutile le
## seul bâtiment que ce jalon ajoute. Trouvé à l'exécution, et c'est le genre de mensonge
## qu'aucun test ne cherche.
func _report_walls() -> void:
	var crowd: int = CROWD_SIZES[CROWD_SIZES.size() - 1]
	_lines.append("Ce qu'un mur achète — roster de %d, tous bleus" % crowd)
	_lines.append("  %-*s %5s %5s  %s"
		% [NAME_WIDTH, "village", "déf.", "coût", _wave_columns()])
	var force := _force(crowd)
	var placed := VILLAGE.duplicate()
	_lines.append(_wall_row("nu", placed, force))
	for extra in REINFORCEMENTS:
		placed.append(extra)
		_lines.append(_wall_row("+ %s" % extra, placed, force))
	_lines.append("")

func _wall_row(what: String, placed: Array[StringName], force: CombatForce) -> String:
	var city := _city(placed)
	return "  %-*s %5d %5s  %s" % [NAME_WIDTH, what,
		InstantCombatResolver.defense_of(city, force, _combat), _cost_of(placed),
		_verdicts(city, force)]

## Si un roster qui s'aguerrit rattrape jamais de la pierre.
##
## C'est **la** question que la borne de déploiement pose : monter la piste Combat vaut-il
## mieux que bâtir ? Une réponse trop nette dans un sens ou dans l'autre est un défaut
## d'équilibrage que `I3` aura à corriger, et cette table est là pour la voir.
func _report_the_line() -> void:
	_lines.append("Ce qu'une piste achète — village nu, %d hommes déployables"
		% _combat.base_deployment_slots)
	_lines.append("  %-*s %5s %5s  %s"
		% [NAME_WIDTH, "piste Combat", "mult.", "déf.", _wave_columns()])
	var city := _city(VILLAGE)
	for level in TRACK_LEVELS:
		if level > _workforce.max_skill_level:
			break
		var force := _force(CROWD_SIZES[0], level)
		var capped := " (plafond)" if level == _workforce.max_skill_level else ""
		_lines.append("  %-*s %5.2f %5d  %s" % [NAME_WIDTH,
			"%s %d%s" % [_combat.combat_skill_family, level, capped],
			_multiplier(level), InstantCombatResolver.defense_of(city, force, _combat),
			_verdicts(city, force)])
	_lines.append("")

## Ce que la borne fait d'un vivier plus large.
##
## La table dit en trois lignes ce que `DESIGN.md` 3.6 affirme en un paragraphe : au-delà
## de la borne, un volontaire de plus ne change **rien**. Si les trois lignes divergeaient,
## la borne ne mordrait pas et la caserne n'achèterait rien.
func _report_the_cap() -> void:
	_lines.append("Ce que la borne retient — village nu, tous bleus")
	_lines.append("  %-*s %5s %5s  %s"
		% [NAME_WIDTH, "roster", "engag.", "déf.", _wave_columns()])
	var city := _city(VILLAGE)
	var slots := InstantCombatResolver.slots_for(city, _combat)
	for size in CROWD_SIZES:
		var force := _force(size)
		_lines.append("  %-*s %5d %5d  %s" % [NAME_WIDTH, "%d ouvriers" % size,
			InstantCombatResolver.deploy(force, slots).size(),
			InstantCombatResolver.defense_of(city, force, _combat), _verdicts(city, force)])
	_lines.append("  ")
	_lines.append("  Et avec une caserne achevée :")
	var fort := _city(_village_with(&"barracks"))
	var wider := InstantCombatResolver.slots_for(fort, _combat)
	for size in CROWD_SIZES:
		var force := _force(size)
		_lines.append("  %-*s %5d %5d  %s" % [NAME_WIDTH, "%d ouvriers" % size,
			InstantCombatResolver.deploy(force, wider).size(),
			InstantCombatResolver.defense_of(fort, force, _combat), _verdicts(fort, force)])
	_lines.append("")

## Trois vagues sur un vrai run, appliquées pour de bon.
##
## La seule partie du harnais qui passe par `RunOrchestrator.fight()`, donc la seule qui
## mute quoi que ce soit. Les tables ci-dessus mesurent des états ; celle-ci montre ce
## qu'aucune d'elles ne peut dire — **une seconde vague finit ce que la première avait
## entamé**, parce que les dégâts restent sur les murs et que les morts ne reviennent pas.
##
## Elle bâtit par `city().place()` plutôt qu'en jouant des cartes : un harnais a le droit
## de bâtir sans jouer, et le sujet ici est la vague et non la pose.
##
## Elle **arme** chaque vague avant de la faire tomber, depuis que `I2` a daté les vagues :
## on ne se bat plus que contre une vague en attente, ce que `close_the_day()` fait le reste
## du temps en lisant le calendrier. Le cycle avance donc d'une phase à chaque ligne, ce qui
## est sans effet sur ce que ces tables mesurent — un état de ville et un roster.
func _report_chronicle(balance: BalanceData) -> void:
	var state := _open_run(balance)
	_lines.append("%d vagues sur un vrai village — %d bâtiments dont un chantier, %d ouvriers"
		% [CHRONICLE_WAVES, state.city().count(), state.roster().size()])
	_lines.append("  %-*s %5s %5s %6s  %s"
		% [NAME_WIDTH, "vague", "déf.", "brè.", "pillé", "ce qui reste"])
	for index in CHRONICLE_WAVES:
		var wave := _waves[mini(index, _waves.size() - 1)]
		var defense := _defense_of(state)
		state.arm_wave(wave)
		var report := RunOrchestrator.fight(state)
		_lines.append("  %-*s %5d %5d %6d  %s" % [NAME_WIDTH, wave.label, defense,
			report.damage().breach(), report.total_plundered(), _aftermath(state, report)])
	_lines.append("")

## Ce que la vague a laissé debout, et ce qu'elle a emporté.
func _aftermath(state: RunState, report: BattleReport) -> String:
	var parts := PackedStringArray()
	parts.append("%d bât." % state.city().count())
	parts.append("%d ouvr." % state.roster().size())
	parts.append("%d en réserve" % state.ledger().total())
	var damage := report.damage()
	if not damage.destroyed().is_empty():
		parts.append("−%d détruit(s)" % damage.destroyed().size())
	if not damage.interrupted().is_empty():
		parts.append("dont %d chantier(s)" % damage.interrupted().size())
	if not damage.lost().is_empty():
		parts.append("morts : %s" % ", ".join(_names_of(state, damage.lost())))
	return ", ".join(parts)

func _report_verdict() -> void:
	_lines.append("Ce que ces tables doivent montrer")
	_lines.append("  — une palissade doit valoir mieux que rien et moins qu'une tour ;")
	_lines.append("  — la piste Combat ne doit pas rattraper la pierre à elle seule,")
	_lines.append("    sinon bâtir ne sert plus à rien et la caserne non plus ;")
	_lines.append("  — les trois lignes d'un même déploiement doivent être identiques,")
	_lines.append("    sinon la borne ne mord pas ;")
	_lines.append("  — la dernière vague doit trouver un village déjà entamé.")
	_lines.append("")
	_lines.append("Ce que F1 ne dit pas : quand une vague tombe (OUVERT de 2, donc I2),")
	_lines.append("ce qu'une défaite déclenche (5., donc I2), ni ce qu'une blessure fait")
	_lines.append("(X6). Le bouchon rapporte, il ne punit pas.")

# --- fabrique ---------------------------------------------------------------------------

## Les vagues de `data/`, par puissance croissante.
##
## Le tri est sur un `int` et non sur l'identifiant : `data/waves/` est indexé par ordre
## alphabétique, ce qui rangerait le siège avant l'escarmouche et rendrait les tables
## illisibles.
func _make_waves() -> Array[WaveDef]:
	var waves: Array[WaveDef] = []
	for id in GameDatabase.list_wave_ids():
		waves.append(GameDatabase.get_wave(id))
	waves.sort_custom(func(first: WaveDef, second: WaveDef) -> bool:
		if first.power != second.power:
			return first.power < second.power
		return String(first.id) < String(second.id))
	return waves

## Une colonne par vague, en en-tête.
func _wave_columns() -> String:
	var columns := PackedStringArray()
	for wave in _waves:
		columns.append("%-10s" % wave.label.left(10))
	return " ".join(columns)

## Ce que chaque vague fait à cette ville, en un mot par colonne.
func _verdicts(city: CitySnapshot, force: CombatForce) -> String:
	var verdicts := PackedStringArray()
	for wave in _waves:
		var report := InstantCombatResolver.resolve(city, force, wave, _combat)
		if report.is_held():
			verdicts.append("%-10s" % "tenue")
			continue
		verdicts.append("%-10s" % ("−%db %dm" % [report.destroyed().size(),
			report.lost().size()]))
	return " ".join(verdicts)

## Le village de mesure, plus ce bâtiment. Recopié plutôt que concaténé : GDScript refuse
## d'additionner un `Array[StringName]` et un tableau littéral non typé, et le `as` ne
## rattrape pas — constaté à l'exécution, invisible au parsing.
func _village_with(extra: StringName) -> Array[StringName]:
	var placed := VILLAGE.duplicate()
	placed.append(extra)
	return placed

## Ville de mesure : ces bâtiments, tous **achevés**, sur des ancres espacées.
##
## Achevés parce que la question porte sur ce qu'un village fini oppose. Ce qu'un chantier
## encaisse est une règle, donc une affaire de tests ; la chronique en montre un vrai.
func _city(placed: Array[StringName]) -> CitySnapshot:
	var buildings: Array[BuildingSnapshot] = []
	for index in placed.size():
		var data := GameDatabase.get_building(placed[index])
		buildings.append(BuildingSnapshot.create(data,
			Vector2i(index * ANCHOR_STRIDE, 0), 0, 0, data.build_actions))
	return CitySnapshot.create(buildings)

## Ce que ces bâtiments coûtent, tous postes confondus, en une chaîne courte.
##
## Le coût est là pour que la table réponde vraiment à « ce qu'un mur achète » : une
## défense sans son prix ne se compare à rien.
func _cost_of(placed: Array[StringName]) -> String:
	var total := 0
	for id in placed:
		for resource in GameDatabase.get_building(id).cost:
			total += GameDatabase.get_building(id).cost[resource]
	return str(total)

## Une force de ce nombre d'hommes, tous au même palier de piste Combat.
##
## Elle part de **vrais `Worker`** qu'on crédite, depuis que `F2a` a donné au `CombatUnit`
## un profil complet. La version d'avant fabriquait ses unités à la main, ce qui était sans
## danger tant qu'un combattant n'était qu'un multiplicateur — il y en a six maintenant, et
## les recopier ici serait exactement la mesure qui emprunte un raccourci et finit par
## mesurer le raccourci. Le coût que le commentaire d'origine craignait n'existe pas :
## monter un palier est un `gain()`, pas une courbe à rejouer.
func _force(size: int, level := 0) -> CombatForce:
	var workers: Array[Worker] = []
	for index in size:
		var worker := Worker.create(_id_at(index), GIVEN_NAMES[index % GIVEN_NAMES.size()])
		if level > 0:
			worker.gain(_combat.combat_skill_family, level * _workforce.skill_xp_per_level)
		workers.append(worker)
	return Roster.create(workers).to_combat(_combat.combat_skill_family, _workforce,
		_combat)

## Le multiplicateur qu'un palier vaut. Sert à l'**affichage** de la table des pistes ;
## ce que les unités portent vient de la projection, pas d'ici.
func _multiplier(level: int) -> float:
	return CombatUnit.BASE_EFFICIENCY + level * _workforce.efficiency_per_skill_level

func _id_at(index: int) -> StringName:
	return StringName(GIVEN_NAMES[index % GIVEN_NAMES.size()].to_lower())

## Ouvre un vrai run et lui bâtit un village. Le relief et le Cœur viennent de
## `RunState.open()` ; le reste est posé à la main, la réserve étant remplie d'office pour
## que la pose ne bute pas sur la bourse.
func _open_run(balance: BalanceData) -> RunState:
	var grid := TerrainGen.generate(SEED, balance.terrain_gen.map_size,
		balance.terrain_gen)
	var state := RunState.open(SEED, grid, _make_roster(), _make_catalogue(),
		_make_buildings(), balance)
	for id in REINFORCEMENTS:
		_raise(state, GameDatabase.get_building(id))
	state.ledger().set_capacity(
		ProductionResolver.capacity_for(state.city().to_snapshot(), balance.economy))
	return state

## Pose ce bâtiment sur la première ancre qui l'accepte et le mène à son dernier cran,
## sauf le dernier de la liste — qu'on laisse **en chantier**, pour que la chronique ait
## quelque chose à interrompre.
func _raise(state: RunState, data: BuildingData) -> void:
	var extent := state.terrain().size()
	for y in extent.y:
		for x in extent.x:
			var anchor := Vector2i(x, y)
			if not state.city().place(state.terrain(), data, anchor).is_ok():
				continue
			if data.id == REINFORCEMENTS[REINFORCEMENTS.size() - 1]:
				return
			while not state.city().building_at(anchor).is_complete():
				state.city().advance(anchor)
			return

func _defense_of(state: RunState) -> int:
	return InstantCombatResolver.defense_of(state.city().to_snapshot(),
		state.roster().to_combat(_combat.combat_skill_family, _workforce, _combat), _combat)

## Les prénoms de ces ouvriers, tant que le roster les connaît encore. Un mort vient d'en
## sortir : c'est son identifiant qui reste, et c'est suffisant pour le nommer.
func _names_of(state: RunState, ids: Array[StringName]) -> PackedStringArray:
	var names := PackedStringArray()
	for id in ids:
		names.append(String(id).capitalize() if not state.roster().has(id)
			else state.roster().worker(id).given_name())
	return names

func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

func _make_catalogue() -> CardCatalogue:
	var cards: Array[CardData] = []
	for id in GameDatabase.list_card_ids():
		cards.append(GameDatabase.get_card(id))
	return CardCatalogue.create(cards)

func _make_buildings() -> Dictionary[StringName, BuildingData]:
	var table: Dictionary[StringName, BuildingData] = {}
	for id in GameDatabase.list_building_ids():
		table[id] = GameDatabase.get_building(id)
	return table

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.name = "CombatReport"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi les quatre tableaux se désalignent colonne par
## colonne et deviennent illisibles.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
