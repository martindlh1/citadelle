extends Node
## Harnais de dev du système Effectifs — jalon W1 : l'unité individuelle, les deux axes
## de progression, l'XP prise au journal de travail, et la projection.
##
## Un rapport texte, comme celui de E1 : W1 n'a rien à montrer en 3D, les fiches et le
## panneau d'affectation sont le sujet de W2.
##
## Il compose **deux systèmes du domaine**, ce qu'aucun harnais n'avait encore fait :
## chaque soir, l'Économie résout la production, les Effectifs distribuent l'XP, et la
## main-d'œuvre est reprojetée avant le soir suivant. C'est le rôle que RunOrchestrator
## reprendra à I1.
##
## La ville est fabriquée à la main, sans terrain ni génération : le sujet est la
## courbe, pas la carte. Les BuildingData, eux, viennent des vrais .tres — la question
## porte justement sur les chiffres de data/.
##
## Comme les trois précédents, il **cherche** au lieu de mettre en scène. Trois choses
## qu'aucune suite de tests ne peut dire, parce qu'elles travaillent sur des chiffres
## choisis :
##
##   - au bout de combien de soirs un ouvrier devient bon, et s'il plafonne jamais ;
##   - ce que la spécialisation rapporte vraiment, une fois la troncature passée ;
##   - ce qu'une absence coûte, en production comme en retard de progression.
##
## La réserve et la famine sont hors sujet ici — le harnais Économie les a mesurées. Ce
## que la table affiche est la **récolte brute**, que ni le plafond ni la famine
## n'altèrent : le plafond écrête ce qui entre, pas ce qui est produit.

## Nombre de soirs simulés. Assez pour que le troisième et le quatrième palier tombent
## dans la fenêtre : en dessous, la table s'arrête avant d'avoir montré quoi que ce soit.
const EVENINGS := 30

## Prénoms du roster. Inventés et codés en dur : un catalogue de prénoms dans data/ est
## du contenu, donc I3, exactement comme les empreintes inventées à C1.
const GIVEN_NAMES: PackedStringArray = [
	"Alaric", "Brenne", "Cadoc", "Doria", "Elric",
	"Fenn", "Gwen", "Hervé", "Iona", "Jarl",
]

## Ville de travail, dans l'ordre. Trois producteurs à deux postes, un entrepôt, deux
## habitations — assez pour que le plafond de places ne soit pas la base toute nue.
const CITY: Array[StringName] = [
	&"lumberjack_hut", &"farm", &"quarry", &"warehouse", &"house", &"house",
]

## Écartement des ancres. Aucune importance : rien ici ne valide un placement.
const ANCHOR_STRIDE := 3

## L'ouvrier qu'on fait partir, et la fenêtre de son absence.
##
## Il est affecté à un poste, sinon son départ ne coûterait rien et ne montrerait rien.
## Il revient, parce que DESIGN.md 3.9 dit « absent sans être mort » : ce que la table
## doit rendre visible, c'est que son XP l'a attendu.
const AWAY := &"elric"
const AWAY_FROM := 12
const AWAY_UNTIL := 18

## Largeur de la colonne « produit ». Même raison qu'au harnais Économie : en dessous,
## la colonne déborde le soir où un palier fait apparaître une quatrième ressource.
const PRODUCED_WIDTH := 42

const REPORT_MARGIN := 16.0
const REPORT_FONT_SIZE := 13

var _city: CitySnapshot
var _roster: Roster
var _assign: Assignment
var _ledger: Ledger
var _economy: EconomyBalance
var _workforce: WorkforceBalance
var _family: StringName
var _lines := PackedStringArray()

## Ouvrier -> nombre de postes tenus. Compté au fil des soirs, jamais déduit de l'XP :
## c'est la mesure indépendante qui dirait qu'un gain a été versé deux fois.
var _shifts: Dictionary[StringName, int] = {}

func _ready() -> void:
	var balance := GameDatabase.get_balance()
	_economy = balance.economy
	_workforce = balance.workforce
	_city = _make_city()
	_family = _reference_family()
	_roster = _make_roster()
	_assign = _make_assignment()
	_ledger = Ledger.from_stock(_economy.starting_stock, _economy.base_storage_cap)

	_report_opening()
	_report_evenings()
	_report_roster()
	_report_verdict()

	var text := "\n".join(_lines)
	print(text)
	add_child(_make_label(text))

func _report_opening() -> void:
	_lines.append("Citadelle — harnais Effectifs (W1)")
	_lines.append("")
	_lines.append("Ville : %d bâtiments, %d postes de production, famille « %s »"
		% [_city.count(), _slot_count(), _family])
	_lines.append("Roster : %d ouvriers — %d/%d places (%d de base + %d d'habitation)"
		% [_roster.size(), _roster.size(), _capacity(), _workforce.base_roster_places,
			_capacity() - _workforce.base_roster_places])
	_lines.append("Affectation : %d aux postes, %d oisifs, figée d'un soir à l'autre."
		% [_assign.size(), _roster.size() - _assign.size()])
	_lines.append("  Personne ne remplace un absent : c'est ce qui rend son coût lisible.")
	_lines.append("")
	_lines.append("Réglages de data/balance/workforce_balance.tres")
	_lines.append("  %d XP par poste tenu, versés à la piste ET au niveau"
		% _workforce.xp_per_shift)
	_lines.append("  piste  : un palier tous les %d, plafond %d, +%.2f par palier"
		% [_workforce.skill_xp_per_level, _workforce.max_skill_level,
			_workforce.efficiency_per_skill_level])
	_lines.append("  niveau : un palier tous les %d, plafond %d, aucun multiplicateur"
		% [_workforce.worker_xp_per_level, _workforce.max_worker_level])
	_lines.append("")

## Le cœur du harnais : Économie puis Effectifs, et la reprojection entre les deux.
##
## L'ordre n'est pas indifférent. Reprojeter avant de distribuer ferait travailler le
## soir courant avec l'XP qu'il n'a pas encore gagnée, et la courbe avancerait d'un cran.
func _report_evenings() -> void:
	_lines.append("soir  %-*s  mult.   XP  notes" % [PRODUCED_WIDTH, "produit (brut)"])
	for evening in range(1, EVENINGS + 1):
		_move_the_absent(evening)
		var report := ProductionResolver.resolve(_city, _assign, _roster.to_labor(_workforce),
			_ledger, _economy)
		var multiplier := _reference_multiplier()
		var progress := SkillResolver.award(_roster, report, _workforce)
		_count_shifts(report)
		_lines.append(("%4d  %-*s  %.2f %4d  %s"
			% [evening, PRODUCED_WIDTH, _bundle_text(report.produced()), multiplier,
				progress.total_xp(), _notes(progress, evening)]).rstrip(" "))
	_lines.append("")

## Le multiplicateur **avant** distribution : c'est celui qui vient de produire la ligne
## que la table affiche à côté.
func _reference_multiplier() -> float:
	return _roster.worker(_reference_worker()).efficiency(_family, _workforce)

func _move_the_absent(evening: int) -> void:
	if evening == AWAY_FROM:
		_roster.worker(AWAY).set_present(false)
	elif evening == AWAY_UNTIL:
		_roster.worker(AWAY).set_present(true)

## Postes tenus, comptés au journal de travail et non déduits de l'XP. Deux mesures
## indépendantes du même fait : si elles divergent, un gain a été versé deux fois.
func _count_shifts(report: ProductionReport) -> void:
	for line in report.work():
		_shifts[line.worker()] = _shifts.get(line.worker(), 0) + 1

## Ce qui mérite d'être signalé ce soir-là : les paliers franchis et les allées et venues.
##
## Les paliers sont regroupés par niveau atteint plutôt que listés un par un : six
## ouvriers qui franchissent le même soir donnent six lignes identiques, et la table
## devient illisible là où elle devrait être la plus claire.
func _notes(progress: ProgressReport, evening: int) -> String:
	var notes := PackedStringArray()
	if evening == AWAY_FROM:
		notes.append("%s part" % AWAY)
	elif evening == AWAY_UNTIL:
		notes.append("%s revient" % AWAY)
	notes.append_array(_crossings(progress.skill_level_ups(), true))
	notes.append_array(_crossings(progress.worker_level_ups(), false))
	if notes.is_empty():
		return ""
	return "← %s" % ", ".join(notes)

## Un libellé par palier atteint, avec le nombre d'ouvriers qui l'ont franchi.
func _crossings(gains: Array[SkillGain], is_skill: bool) -> PackedStringArray:
	var counts: Dictionary[int, int] = {}
	for gain in gains:
		var reached := gain.skill_level_after() if is_skill else gain.worker_level_after()
		counts[reached] = counts.get(reached, 0) + 1
	var levels: Array[int] = []
	levels.assign(counts.keys())
	levels.sort()
	var notes := PackedStringArray()
	for level in levels:
		var what := "%s %d" % [_family, level] if is_skill else "niveau %d" % level
		notes.append("%s (%d)" % [what, counts[level]])
	return notes

func _report_roster() -> void:
	_lines.append("Ouvriers au %de soir" % EVENINGS)
	_lines.append("  %-10s %-8s %6s  %-16s %-8s %s"
		% ["nom", "présent", "postes", "piste", "niveau", "XP"])
	for worker in _roster.workers():
		var level := worker.skill_level(_family, _workforce)
		var track := "%d (×%.2f)" % [level, worker.efficiency(_family, _workforce)] \
			if worker.has_track(_family) else "—"
		_lines.append("  %-10s %-8s %6d  %-16s %-8d %d"
			% [worker.given_name(), "oui" if worker.is_present() else "non",
				_shifts.get(worker.id(), 0), track, worker.level(_workforce), worker.xp()])
	_lines.append("")

## Ce qu'aucune suite de tests ne peut dire, puisque la question porte sur les chiffres
## de data/balance/ et non sur des chiffres choisis.
func _report_verdict() -> void:
	var veteran := _roster.worker(_reference_worker())
	var idler := _roster.worker(_idle_worker())
	var absentee := _roster.worker(AWAY)
	var yields := _reference_yield()

	_lines.append("Ce que le harnais répond")
	_lines.append("  Plafond de piste : %s."
		% ("atteint" if veteran.is_skill_capped(_family, _workforce)
			else "jamais en %d soirs — le meilleur est à %s %d sur %d"
				% [EVENINGS, _family, veteran.skill_level(_family, _workforce),
					_workforce.max_skill_level]))
	_lines.append("  Plafond de niveau : %s."
		% ("atteint" if veteran.is_capped(_workforce)
			else "jamais — le meilleur est niveau %d sur %d"
				% [veteran.level(_workforce), _workforce.max_worker_level]))
	_lines.append("")
	_lines.append("  Spécialisation, sur un poste qui promet %d :" % yields)
	_lines.append("    un ouvrier de %d postes rend ×%.2f, soit %d"
		% [_shifts.get(veteran.id(), 0), veteran.efficiency(_family, _workforce),
			floori(yields * veteran.efficiency(_family, _workforce))])
	_lines.append("    un oisif rend ×%.2f, soit %d"
		% [idler.efficiency(_family, _workforce),
			floori(yields * idler.efficiency(_family, _workforce))])
	_lines.append("  Le rendement est tronqué par ouvrier et par soir, ce qui est une")
	_lines.append("  décision de E1. Sur des promesses à 2 ou 3, un cran de %.2f est"
		% _workforce.efficiency_per_skill_level)
	_lines.append("  donc entièrement avalé tant que le multiplicateur n'a pas franchi")
	_lines.append("  l'entier suivant : la table reste plate 19 soirs alors que les")
	_lines.append("  pistes montent. C'est le seul vrai constat du harnais, et il est")
	_lines.append("  structurel — aucun réglage de cran ne le supprime, seuls des")
	_lines.append("  rendements plus gros ou une troncature déplacée le feraient.")
	_lines.append("")
	_lines.append("  Ce que l'absence a coûté à %s, parti du soir %d au soir %d :"
		% [absentee.given_name(), AWAY_FROM, AWAY_UNTIL - 1])
	_lines.append("    %d postes contre %d pour ses camarades, %d XP contre %d,"
		% [_shifts.get(AWAY, 0), _shifts.get(veteran.id(), 0), absentee.xp(), veteran.xp()])
	_lines.append("    %s %d contre %s %d. Il n'a rien perdu, il a pris du retard —"
		% [_family, absentee.skill_level(_family, _workforce), _family,
			veteran.skill_level(_family, _workforce)])
	_lines.append("    et pendant ce temps il ne mangeait pas.")

## Le premier ouvrier affecté : celui qui a tenu un poste tous les soirs, et donc le
## témoin de la progression maximale.
func _reference_worker() -> StringName:
	return _assign.workers()[0]

## Le premier ouvrier que l'affectation ignore : le témoin à l'autre bout.
func _idle_worker() -> StringName:
	for worker in _roster.workers():
		if not _assign.is_assigned(worker.id()):
			return worker.id()
	return _reference_worker()

## Ce qu'un poste du premier producteur promet, avant tout multiplicateur. Sert au
## verdict : un écart de multiplicateur ne dit rien tant qu'on ne l'a pas tronqué.
func _reference_yield() -> int:
	for building in _city.buildings():
		if not building.data().produces():
			continue
		for resource in building.data().production.yield_per_slot:
			return building.data().production.yield_per_slot[resource]
	return 0

## Famille employée par le premier producteur de la ville.
##
## Lue dans data/ et non écrite ici : un &"harvest" en dur dans un harnais survivrait à
## un renommage du catalogue sans que rien ne le signale. Aujourd'hui les quatre
## producteurs de data/buildings/ emploient la même — l'atelier, qui en emploierait une
## autre, n'a pas encore de bloc de production.
func _reference_family() -> StringName:
	for building in _city.buildings():
		if building.data().produces():
			return building.data().production.skill_family
	return &""

## La ville de travail, **tous chantiers achevés**.
##
## Elle est fabriquée en instantanés à la main, sans CityState : ce harnais n'a pas de
## carte et n'a rien à valider. L'avancement est donc écrit directement, à hauteur de ce
## que chaque bâtiment réclame.
##
## Même choix que dans le harnais Économie, et pour la même raison : sans lui, aucun
## poste ne s'ouvrirait, donc aucune ligne de travail, donc aucune XP — les deux
## tableaux et le verdict de ce harnais se videraient entièrement. Le délai de chantier
## se joue à I1, quand *Construire* existera comme carte.
func _make_city() -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = []
	for index in CITY.size():
		var data := GameDatabase.get_building(CITY[index])
		assert(data != null, "bâtiment introuvable : %s" % CITY[index])
		placed.append(BuildingSnapshot.create(
			data, Vector2i(index * ANCHOR_STRIDE, 0), 0, 0, data.build_actions))
	return CitySnapshot.create(placed)

## Un ouvrier par prénom, tous neufs et tous présents.
func _make_roster() -> Roster:
	var workers: Array[Worker] = []
	for given_name in GIVEN_NAMES:
		workers.append(Worker.create(StringName(given_name.to_lower()), given_name))
	return Roster.create(workers)

## Les postes se remplissent dans l'ordre de la ville, et on s'arrête quand il n'y en a
## plus. Le reste du roster chôme, ce qui est exactement le témoin qu'on veut.
func _make_assignment() -> Assignment:
	var table: Dictionary[StringName, Vector2i] = {}
	var hired := 0
	var workers := _roster.workers()
	for building in _city.buildings():
		var data := building.data()
		if not data.produces():
			continue
		for _slot in data.production.slots:
			if hired >= workers.size():
				break
			table[workers[hired].id()] = building.anchor()
			hired += 1
	return Assignment.create(table)

func _slot_count() -> int:
	var slots := 0
	for building in _city.buildings():
		if building.data().produces():
			slots += building.data().production.slots
	return slots

func _capacity() -> int:
	return Roster.capacity_for(_city, _workforce)

## Lot rendu lisible, trié par identifiant.
##
## Le tri se fait sur le texte et non sur le StringName : deux affichages du même lot
## doivent donner la même ligne, or comparer deux StringName compare des pointeurs.
## Recopié du harnais Économie, comme _make_label() l'est déjà des trois autres — la
## mise en commun des rapports texte est une passe à part entière, pas du W1.
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
	label.name = "WorkforceReport"
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = REPORT_MARGIN
	label.offset_top = REPORT_MARGIN
	label.add_theme_font_size_override("font_size", REPORT_FONT_SIZE)
	label.add_theme_font_override("font", _monospace())
	return label

## Une police à chasse fixe, sans quoi les deux tableaux se désalignent colonne par
## colonne et deviennent illisibles.
func _monospace() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return font
