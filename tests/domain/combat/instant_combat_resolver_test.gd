class_name InstantCombatResolverTest
extends GdUnitTestSuite
## Ce qu'une vague ordonne : ce qu'elle casse, qui elle emporte, ce qu'elle vole.
##
## Le résolveur est un bouchon que `F2` remplacera entier, et cette suite est écrite en
## conséquence : elle épingle les **règles** que `DESIGN.md` 3.6 énonce, pas les chiffres
## que `data/` porte. Un cas qui figerait « une escarmouche fait quatre points de dégâts »
## serait cassé à la première passe d'équilibrage sans avoir jamais rien prouvé.
##
## Village de travail, tous à des ancres distinctes :
##   - une **palissade** achevée en (1, 1) — défense 3, 4 PV ;
##   - une **ferme** achevée en (4, 4) — aucune défense, 4 PV ;
##   - une **ferme en chantier** en (6, 6) — mêmes PV, aucune défense ;
##   - un **cœur** achevé en (8, 8) — aucune défense, 30 PV.
##
## Deux places de déploiement, deux points de défense par homme, un mort tous les six
## points de brèche, une unité pillée par point. Ces chiffres sont ceux de la suite et non
## ceux de `data/` : ils sont choisis pour que chaque seuil tombe sur un cas lisible.

const WALL := Vector2i(1, 1)
const FARM := Vector2i(4, 4)
const SITE := Vector2i(6, 6)
const HEART := Vector2i(8, 8)
const KEEP := Vector2i(2, 8)

const WALL_DEFENSE := 3
const WALL_HP := 4
const FARM_HP := 4
const HEART_HP := 30
const SITE_ACTIONS := 3
const KEEP_SLOTS := 2

const SLOTS := 2
const PER_FIGHTER := 2
const BREACH_PER_CASUALTY := 6
const PLUNDER_PER_BREACH := 1
const COMBAT := &"combat"

## Défense du village de référence : les 3 de la palissade, plus deux bleus à 2.
const PLAIN_DEFENSE := WALL_DEFENSE + SLOTS * PER_FIGHTER

var _city: CitySnapshot
var _balance: CombatBalance

func before_test() -> void:
	_city = _make_city()
	_balance = _make_balance()

# --- Le déploiement, et sa borne ------------------------------------------------------

## La base d'équilibrage seule, quand aucun bâtiment n'ouvre de place. C'est le cas de
## référence sans lequel les deux suivants ne veulent rien dire.
func test_the_balance_alone_grants_the_base_slots() -> void:
	assert_int(InstantCombatResolver.slots_for(_city, _balance)).is_equal(SLOTS)

## Un bâtiment achevé relève la borne, exactement comme un entrepôt relève la réserve et
## une habitation les places du roster. C'est ce qui fait de la caserne une décision de
## guerre, et `DESIGN.md` 3.6 est écrit pour ça.
func test_a_finished_keep_opens_more_slots() -> void:
	var city := _city_with(_placed(_keep(), KEEP))
	assert_int(InstantCombatResolver.slots_for(city, _balance)) \
		.is_equal(SLOTS + KEEP_SLOTS)

## Et un chantier n'en ouvre aucune. Le filtre est celui de `completed()`, le même depuis
## `C4` : on ne poste personne sur des murs qu'on n'a pas montés.
func test_a_keep_under_construction_opens_none() -> void:
	assert_int(InstantCombatResolver.slots_for(_city_with(_keep_site()), _balance)) \
		.is_equal(SLOTS)

## La borne mord : cinq volontaires pour deux places, trois restent au village.
func test_only_the_cap_takes_the_line() -> void:
	var line := InstantCombatResolver.deploy(_force({
		&"ana": 1.0, &"bo": 1.0, &"cyd": 1.0, &"dag": 1.0, &"eli": 1.0}), SLOTS)
	assert_int(line.size()).is_equal(SLOTS)

## Les plus aguerris montent devant. C'est un bouchon — le geste appartient à `F2` — mais
## il doit être le bon bouchon : envoyer les bleus tenir la ligne serait un défaut qu'aucun
## écran ne montrerait avant dix journées de courbe d'XP.
func test_the_most_seasoned_take_the_line() -> void:
	var line := InstantCombatResolver.deploy(_force({
		&"ana": 1.0, &"bo": 2.0, &"cyd": 1.5}), SLOTS)
	assert_array(line).is_equal([&"bo", &"cyd"])

## À efficacité égale, c'est l'ordre reçu qui départage — donc celui du roster. Sans cette
## clause, deux runs partis du même seed enverraient deux personnes différentes mourir, et
## ni la ville ni la réserve ne le montreraient. Même piège qu'au classement de `W2`.
func test_equal_fighters_are_split_by_the_order_received() -> void:
	var line := InstantCombatResolver.deploy(_force({
		&"ana": 1.0, &"bo": 1.0, &"cyd": 1.0}), SLOTS)
	assert_array(line).is_equal([&"ana", &"bo"])

## Un village vide se défend quand même par ses murs, et ce n'est pas une erreur.
func test_an_empty_roster_deploys_nobody() -> void:
	assert_array(InstantCombatResolver.deploy(CombatForce.empty(), SLOTS)).is_empty()

# --- Ce que le village oppose ---------------------------------------------------------

## Les murs et les hommes s'additionnent, et c'est toute la formule.
func test_walls_and_men_add_up() -> void:
	assert_int(InstantCombatResolver.defense_of(_city, _plain_force(), _balance)) \
		.is_equal(PLAIN_DEFENSE)

## Un chantier ne retient rien. La palissade qu'on n'a pas finie ne se dresse devant
## personne, et `completed()` est le seul endroit qui le dise.
func test_a_site_holds_nothing() -> void:
	var city := CitySnapshot.create(_only(_wall_site()))
	assert_int(InstantCombatResolver.defense_of(city, _plain_force(), _balance)) \
		.is_equal(SLOTS * PER_FIGHTER)

## Un homme resté au village ne défend rien. C'est là que la borne du déploiement cesse
## d'être un chiffre et devient la tension de `DESIGN.md` 3.6 : le sixième volontaire est
## exactement aussi utile que le zéroième.
func test_a_man_left_at_the_village_defends_nothing() -> void:
	var crowd := _force({&"ana": 1.0, &"bo": 1.0, &"cyd": 1.0, &"dag": 1.0})
	assert_int(InstantCombatResolver.defense_of(_city, crowd, _balance)) \
		.is_equal(PLAIN_DEFENSE)

## La piste Combat **fait** quelque chose, et c'est ce qui en fait un métier plutôt qu'un
## compteur. Deux vétérans à 1,5 opposent six là où deux bleus opposent quatre.
func test_a_seasoned_line_holds_more() -> void:
	var veterans := _force({&"ana": 1.5, &"bo": 1.5})
	assert_int(InstantCombatResolver.defense_of(_city, veterans, _balance)) \
		.is_equal(WALL_DEFENSE + 6)

## Le total des hommes est tronqué vers le bas, jamais arrondi. Même arithmétique que la
## production et que les crans d'un chantier.
func test_the_line_total_is_floored() -> void:
	var uneven := _force({&"ana": 1.4, &"bo": 1.4})
	assert_int(InstantCombatResolver.defense_of(_city, uneven, _balance)) \
		.is_equal(WALL_DEFENSE + 5)

# --- Une vague contenue ---------------------------------------------------------------

## Rien ne passe, donc rien ne coûte. Le cas le plus important de la suite, parce que c'est
## celui qu'un joueur qui a bien joué doit obtenir.
func test_a_held_wave_costs_nothing() -> void:
	var report := _resolve(PLAIN_DEFENSE)
	assert_bool(report.is_held()).is_true()
	assert_bool(report.is_empty()).is_true()
	assert_int(report.breach()).is_equal(0)
	assert_array(report.destroyed()).is_empty()
	assert_int(report.plunder()).is_equal(0)

## Une défense supérieure ne rend pas la brèche négative : on ne gagne rien à surdéfendre,
## on ne perd rien non plus.
func test_an_overwhelming_defense_leaves_no_negative_breach() -> void:
	assert_int(_resolve(1).breach()).is_equal(0)

## La ligne est payée même quand elle n'a pas saigné. L'inverse rendrait une bonne défense
## punitive à la progression, ce qui serait exactement le contraire de ce qu'on veut
## encourager.
func test_a_held_wave_still_pays_the_line() -> void:
	assert_int(_resolve(PLAIN_DEFENSE).work().size()).is_equal(SLOTS)

# --- Ce que la brèche casse -----------------------------------------------------------

## La brèche est la puissance moins la défense, et tout le reste en découle.
func test_the_breach_is_the_power_minus_the_defense() -> void:
	assert_int(_resolve(PLAIN_DEFENSE + 3).breach()).is_equal(3)

## **Ce qui la retenait casse d'abord.** C'est la règle de `DESIGN.md` 3.6, et c'est elle
## qui fait qu'une palissade sert à quelque chose : sans elle, cinq bois n'achèteraient
## qu'un compteur.
func test_the_wave_breaks_the_defences_first() -> void:
	var report := _resolve(PLAIN_DEFENSE + 3)
	assert_int(report.damaged()[WALL]).is_equal(3)
	assert_bool(report.damaged().has(FARM)).is_false()

## Puis ce qui cède le plus vite. Le Cœur, à trente points, se retrouve **dernier** sans
## qu'une ligne de code n'écrive son nom — c'est ce que la règle achète en plus de
## l'ordre, et c'est ce qui évite un identifiant de contenu dans du GDScript.
func test_then_what_gives_way_soonest() -> void:
	var report := _resolve(PLAIN_DEFENSE + WALL_HP + 1)
	assert_array(report.destroyed()).contains([WALL])
	assert_int(report.damaged()[FARM]).is_equal(1)
	assert_bool(report.damaged().has(HEART)).is_false()

## **Le cas qui porte le jalon.** Deux villes aux mêmes bâtiments posés dans deux ordres
## différents perdent exactement la même chose. C'est ce que `E1` exige déjà de l'écrêtage
## d'une récolte, et le risque est le même : silencieux, invisible à l'œil, et il ne se
## manifeste que sur deux parties qu'on compare.
func test_the_pose_order_decides_nothing() -> void:
	var forward := InstantCombatResolver.resolve(_make_city(), _plain_force(),
		_wave(PLAIN_DEFENSE + 9), _balance)
	var backward := InstantCombatResolver.resolve(_make_city(true), _plain_force(),
		_wave(PLAIN_DEFENSE + 9), _balance)
	assert_dict(backward.damaged()).is_equal(forward.damaged())
	assert_array(backward.destroyed()).is_equal(forward.destroyed())

## Un mur déjà entamé la veille tombe plus vite. C'est la seule raison pour laquelle les
## dégâts traversent le `CitySnapshot` : une brèche se dépense sur ce qui **reste**, pas
## sur les PV du neuf.
func test_a_wall_already_hit_falls_sooner() -> void:
	var city := CitySnapshot.create(_only(_placed(_wall(), WALL, true, WALL_HP - 1)))
	var report := InstantCombatResolver.resolve(city, CombatForce.empty(),
		_wave(WALL_DEFENSE + 1), _balance)
	assert_array(report.destroyed()).is_equal([WALL])
	assert_int(report.damaged()[WALL]).is_equal(1)

## Un chantier est frappé comme le reste : c'est pour lui que `C4` a fait rendre à
## `buildings()` autre chose qu'à `completed()`, et `F1` est le consommateur annoncé.
func test_a_site_is_hit_like_anything_else() -> void:
	var report := _resolve(PLAIN_DEFENSE + WALL_HP + FARM_HP + 1)
	assert_int(report.damaged()[SITE]).is_equal(1)

## Et quand il tombe, il est rapporté **à part**. `DESIGN.md` 3.2 veut qu'un chantier
## détruit la veille de la vague soit une perte qui se raconte ; recouper la liste après
## coup demanderait la ville d'avant, que plus personne ne tient.
func test_a_fallen_site_is_reported_as_interrupted() -> void:
	var report := _resolve(PLAIN_DEFENSE + WALL_HP + FARM_HP + FARM_HP)
	assert_array(report.interrupted()).is_equal([SITE])
	assert_array(report.destroyed()).contains([SITE])

## Un bâtiment achevé qui tombe n'est **pas** un chantier interrompu. Le cas est écrit
## parce que c'est l'erreur qu'on ferait en confondant les deux listes.
func test_a_finished_building_never_counts_as_interrupted() -> void:
	assert_array(_resolve(PLAIN_DEFENSE + WALL_HP).interrupted()).is_empty()

## Une brèche plus grosse que le village ne creuse pas sous la carte. L'excédent est perdu,
## ce qui est le comportement d'un bouchon et non une règle à défendre.
func test_the_breach_never_spends_more_than_the_village_has() -> void:
	var report := _resolve(PLAIN_DEFENSE + 500)
	assert_int(report.destroyed().size()).is_equal(_make_city().count())
	assert_int(report.damaged()[HEART]).is_equal(HEART_HP)

## Un bâtiment frappé sans tomber n'entre pas dans les détruits, et son compte de points
## est celui qu'il a **vraiment** pris.
func test_a_building_that_survives_is_not_destroyed() -> void:
	var report := _resolve(PLAIN_DEFENSE + WALL_HP - 1)
	assert_array(report.destroyed()).is_empty()
	assert_int(report.damaged()[WALL]).is_equal(WALL_HP - 1)

# --- Ce que la brèche emporte ---------------------------------------------------------

## Sous le seuil, personne ne tombe. Une escarmouche qui passe de justesse casse du bois,
## pas des gens.
func test_a_small_breach_takes_nobody() -> void:
	assert_array(_resolve(PLAIN_DEFENSE + BREACH_PER_CASUALTY - 1).lost()).is_empty()

## **Les moins aguerris tombent d'abord.** Thématique — les bleus tombent — et mécanique :
## la piste Combat protège celui qui l'a montée, et l'investissement d'un roguelite n'est
## pas effacé par un tirage.
func test_the_greenest_fall_first() -> void:
	var mixed := _force({&"ana": 2.0, &"bo": 1.0})
	var report := InstantCombatResolver.resolve(_city, mixed,
		_wave(_defense_of(mixed) + BREACH_PER_CASUALTY), _balance)
	assert_array(report.lost()).is_equal([&"bo"])

## Il ne tombe jamais plus de monde qu'il n'y en avait sur la ligne.
func test_no_more_fall_than_stood() -> void:
	assert_int(_resolve(PLAIN_DEFENSE + 500).lost().size()).is_equal(SLOTS)

## Un homme resté au village est en sécurité. `DESIGN.md` 3.6 parle des effectifs
## **engagés**, et c'est le revers exact de « il ne défend rien ».
func test_a_man_left_at_the_village_is_safe() -> void:
	var crowd := _force({&"ana": 1.0, &"bo": 1.0, &"cyd": 1.0, &"dag": 1.0})
	var report := InstantCombatResolver.resolve(_city, crowd,
		_wave(PLAIN_DEFENSE + 500), _balance)
	assert_array(report.lost()).not_contains([&"cyd", &"dag"])

# --- Ce que la brèche vole ------------------------------------------------------------

## Le pillage suit la brèche, et rien d'autre.
func test_the_plunder_follows_the_breach() -> void:
	assert_int(_resolve(PLAIN_DEFENSE + 4).plunder()) \
		.is_equal(4 * PLUNDER_PER_BREACH)

## Une vague contenue ne vole rien : elle n'est jamais entrée.
func test_a_held_wave_steals_nothing() -> void:
	assert_int(_resolve(PLAIN_DEFENSE).plunder()).is_equal(0)

## Un village qu'une vague précédente a rasé encaisse quand même : il n'y a plus rien à
## casser, mais les hommes meurent et la réserve se vide. Le cas est écrit parce que c'est
## la boucle sur les bâtiments qui pourrait avaler le reste en sortant trop tôt.
func test_a_village_with_nothing_left_still_bleeds() -> void:
	var razed := CitySnapshot.empty()
	var report := InstantCombatResolver.resolve(razed, _plain_force(),
		_wave(SLOTS * PER_FIGHTER + BREACH_PER_CASUALTY), _balance)
	assert_dict(report.damaged()).is_empty()
	assert_int(report.lost().size()).is_equal(1)
	assert_int(report.plunder()).is_equal(BREACH_PER_CASUALTY * PLUNDER_PER_BREACH)

# --- Ce que la ligne vaut -------------------------------------------------------------

## La famille créditée vient de `data/balance/` et n'est écrite nulle part dans le code.
## `DESIGN.md` 3.4 pose que la liste des familles n'est pas close ; le Combat y entre comme
## la Construction à `I1`, sans une ligne de GDScript pour l'énumérer.
func test_the_line_earns_the_family_from_data() -> void:
	for line in _resolve(PLAIN_DEFENSE + 4).work():
		assert_str(String(line.family())).is_equal(String(COMBAT))

## Une ligne de défense n'a **pas** de cellule : on ne défend pas le village *en* une case.
## C'est le troisième producteur de `WorkLine` du projet et le premier pour lequel la
## question ne se pose pas.
func test_a_line_of_the_wall_has_no_cell() -> void:
	for line in _resolve(PLAIN_DEFENSE + 4).work():
		assert_vector(line.cell()).is_equal(WorkLine.NO_CELL)

## Un mort a tenu la ligne, donc il figure au journal. Ce qu'il advient de son XP se décide
## à l'application — `SkillResolver` saute un ouvrier que le roster ne connaît plus —, et
## pas ici : le résolveur rapporte qui s'est battu, pas qui a survécu.
func test_the_fallen_are_still_on_the_work_log() -> void:
	var report := _resolve(PLAIN_DEFENSE + 500)
	assert_array(report.fighters()).contains(report.lost())

## Personne sur la ligne, aucun journal. Un village qui ne défend que par ses murs ne
## distribue aucune XP, ce qui est juste et non un oubli.
func test_an_undefended_village_pays_nobody() -> void:
	var report := InstantCombatResolver.resolve(_city, CombatForce.empty(),
		_wave(WALL_DEFENSE + 4), _balance)
	assert_array(report.work()).is_empty()

# --- data/ ----------------------------------------------------------------------------

## Le contrôle de vacuité, sur le motif de `production_block_test.gd` : sans lui, toute
## cette suite passerait le jour où un réenregistrement viderait la colonne **Déf.** de
## `data/`, puisqu'elle travaille sur des bâtiments fabriqués à la main.
##
## Il ne fige aucun chiffre — quel bâtiment défend et de combien est une question de
## `DESIGN.md` 4.1, pas de ce fichier. Il exige seulement que la colonne existe encore.
func test_at_least_one_building_of_data_declares_a_defense() -> void:
	assert_bool(_data_declares(func(data: BuildingData) -> bool: return data.defense > 0)) \
		.override_failure_message("aucun bâtiment de data/ ne déclare de défense") \
		.is_true()

## Même motif pour les places de déploiement : la borne de `DESIGN.md` 3.6 ne veut rien
## dire si aucun bâtiment ne peut la relever, et le run entier se jouerait à trois hommes
## sans que rien ne le signale.
func test_at_least_one_building_of_data_opens_a_deployment_slot() -> void:
	assert_bool(_data_declares(
			func(data: BuildingData) -> bool: return data.deployment_slots > 0)) \
		.override_failure_message("aucun bâtiment de data/ n'ouvre de place de déploiement") \
		.is_true()

# --- fabrique -------------------------------------------------------------------------

## Un bâtiment de `data/` satisfait-il ce prédicat ?
func _data_declares(predicate: Callable) -> bool:
	for id in GameDatabase.list_building_ids():
		if predicate.call(GameDatabase.get_building(id)):
			return true
	return false

## Résout le village de référence contre une vague de cette puissance, deux bleus sur la
## ligne.
func _resolve(power: int) -> DamageReport:
	return InstantCombatResolver.resolve(_city, _plain_force(), _wave(power), _balance)

func _defense_of(force: CombatForce) -> int:
	return InstantCombatResolver.defense_of(_city, force, _balance)

func _wave(power: int) -> WaveDef:
	var wave := WaveDef.new()
	wave.id = &"test_wave"
	wave.label = "Vague d'essai"
	wave.power = power
	return wave

## Deux bleus, ce que le village de référence déploie exactement.
func _plain_force() -> CombatForce:
	return _force({&"ana": 1.0, &"bo": 1.0})

func _force(multipliers: Dictionary) -> CombatForce:
	var units: Array[CombatUnit] = []
	for id in multipliers:
		units.append(CombatUnit.create(id, multipliers[id]))
	return CombatForce.create(units)

## Le village de référence. `reversed` le repose à l'envers, ce qui doit ne rien changer.
func _make_city(reversed := false) -> CitySnapshot:
	var placed: Array[BuildingSnapshot] = [
		_placed(_wall(), WALL),
		_placed(_farm(), FARM),
		_placed(_farm(), SITE, false),
		_placed(_heart(), HEART)]
	if reversed:
		placed.reverse()
	return CitySnapshot.create(placed)

## Le village de référence, plus ce bâtiment.
func _city_with(extra: BuildingSnapshot) -> CitySnapshot:
	var placed := _make_city().buildings()
	placed.append(extra)
	return CitySnapshot.create(placed)

func _only(building: BuildingSnapshot) -> Array[BuildingSnapshot]:
	var placed: Array[BuildingSnapshot] = [building]
	return placed

## Un bâtiment posé, achevé par défaut. Un chantier se déclare par `complete = false`, ce
## qui laisse ses crans à zéro.
func _placed(data: BuildingData, anchor: Vector2i, complete := true,
		damage := 0) -> BuildingSnapshot:
	var progress := data.build_actions if complete else 0
	return BuildingSnapshot.create(data, anchor, 0, 0, progress, damage)

func _wall_site() -> BuildingSnapshot:
	return _placed(_wall(), WALL, false)

func _keep_site() -> BuildingSnapshot:
	return _placed(_keep(), KEEP, false)

func _wall() -> BuildingData:
	var data := _building(&"wall", WALL_HP)
	data.defense = WALL_DEFENSE
	return data

func _farm() -> BuildingData:
	return _building(&"farm", FARM_HP)

func _heart() -> BuildingData:
	var data := _building(&"heart", HEART_HP)
	data.build_actions = 0
	return data

func _keep() -> BuildingData:
	var data := _building(&"keep", FARM_HP)
	data.deployment_slots = KEEP_SLOTS
	return data

## Un bâtiment 1×1 en chantier de trois crans. Le Cœur ramène le sien à zéro : un bâtiment
## qui ne réclame aucune action est achevé dès la pose, sans chemin particulier.
func _building(id: StringName, hit_points: int) -> BuildingData:
	var data := BuildingData.new()
	data.id = id
	data.hit_points = hit_points
	data.build_actions = SITE_ACTIONS
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	data.footprint = cells
	return data

func _make_balance() -> CombatBalance:
	var balance := CombatBalance.new()
	balance.base_deployment_slots = SLOTS
	balance.defense_per_fighter = PER_FIGHTER
	balance.combat_skill_family = COMBAT
	balance.breach_per_casualty = BREACH_PER_CASUALTY
	balance.plunder_per_breach = PLUNDER_PER_BREACH
	return balance
