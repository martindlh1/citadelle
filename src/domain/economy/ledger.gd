class_name Ledger
extends RefCounted
## La réserve : ce que la ville possède, sous un plafond commun.
##
## État interne de l'Économie, comme CityState l'est de Construction et HeightGrid du
## Terrain. Il ne connaît pas le catalogue de data/commodities/ : les identifiants lui
## arrivent en argument, et c'est GameDatabase qui refuse au démarrage un .tres qui en
## nommerait un inconnu.
##
## Le plafond est **commun à toutes les ressources** — cent unités partagées entre le
## bois, la pierre et la nourriture. Tranché à E1, voir DESIGN.md 3.3.
##
## C'est ce choix qui donne à cette classe sa seule vraie logique. Quand une récolte
## déborde, il faut décider **laquelle** de ses ressources entre, et la réponse ne peut
## pas être « la première venue » : l'ordre des clés vient de l'ordre de pose des
## bâtiments, donc deux villes identiques bâties dans un ordre différent perdraient des
## choses différentes, sans que rien à l'écran ne l'explique. La répartition est donc
## **proportionnelle à ce que le dépôt apporte**, et le même écrêtage sert quand la
## capacité baisse — un entrepôt détruit par une vague.
##
## Invariant : aucune clé ne porte la valeur zéro. La réserve contient ce qu'elle a.

## Ce que la réserve contient. Ordre d'insertion, jamais trié.
var _amounts: Dictionary[StringName, int] = {}

## Capacité commune courante.
var _capacity: int

## Réserve vide de cette capacité.
static func create(capacity: int) -> Ledger:
	assert(capacity >= 0, "capacité négative : %d" % capacity)
	var ledger := Ledger.new()
	ledger._capacity = capacity
	return ledger

## Réserve garnie de ce stock, écrêté à cette capacité s'il la dépasse.
static func from_stock(stock: Dictionary[StringName, int], capacity: int) -> Ledger:
	var ledger := Ledger.create(capacity)
	ledger.deposit(stock)
	return ledger

## Capacité commune, entrepôts compris.
func capacity() -> int:
	return _capacity

## Total détenu, toutes ressources confondues. C'est ce que le plafond limite.
func total() -> int:
	var sum := 0
	for resource in _amounts:
		sum += _amounts[resource]
	return sum

## Place restante avant le plafond. Jamais négative.
func free_space() -> int:
	return maxi(_capacity - total(), 0)

## La réserve est-elle pleine ?
func is_full() -> bool:
	return free_space() == 0

## Quantité détenue de cette ressource. Zéro pour une ressource jamais reçue.
func amount(resource: StringName) -> int:
	if not _amounts.has(resource):
		return 0
	return _amounts[resource]

## Tout ce qui est détenu. Copie : l'état interne ne sort jamais.
func amounts() -> Dictionary[StringName, int]:
	return _amounts.duplicate()

## Change la capacité et rend ce que l'opération a fait perdre.
##
## L'abaisser sous le stock courant écrête, et la perte se répartit par la même règle
## proportionnelle qu'un dépôt qui déborde : détruire un entrepôt ne doit pas vider une
## ressource en particulier.
func set_capacity(capacity: int) -> int:
	assert(capacity >= 0, "capacité négative : %d" % capacity)
	_capacity = capacity
	var held := total()
	if held <= _capacity:
		return 0
	var kept := _shares(_amounts.duplicate(), _capacity)
	_amounts.clear()
	for resource in kept:
		if kept[resource] > 0:
			_amounts[resource] = kept[resource]
	return held - _capacity

## Ajoute cette quantité et rend ce que le plafond a fait perdre.
##
## Une seule ressource : il n'y a rien à répartir, ce qui entre est ce qui tient.
func add(resource: StringName, quantity: int) -> int:
	assert(quantity >= 0, "ajout négatif de %s : %d" % [resource, quantity])
	var stored := mini(quantity, free_space())
	if stored > 0:
		_amounts[resource] = amount(resource) + stored
	return quantity - stored

## Dépose ce lot et rend ce qui est réellement entré, par ressource.
##
## Ce qui a débordé se lit en soustrayant le retour du lot déposé. Les ressources qui
## n'ont rien obtenu ne figurent pas dans le retour, de sorte qu'il se lise comme la
## liste de ce qui est entré.
##
## Quand le lot dépasse la place restante, chaque ressource reçoit une part
## proportionnelle à ce qu'elle apportait. Le reste de la division va aux plus grosses
## parts fractionnaires, à égalité par identifiant : la règle est entièrement
## déterminée par les quantités, jamais par l'ordre des clés.
func deposit(bundle: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var stored: Dictionary[StringName, int] = {}
	var asked := 0
	for resource in bundle:
		assert(bundle[resource] >= 0,
			"dépôt négatif de %s : %d" % [resource, bundle[resource]])
		asked += bundle[resource]
	if asked == 0:
		return stored
	var room := free_space()
	var granted := bundle if asked <= room else _shares(bundle, room)
	for resource in granted:
		if granted[resource] > 0:
			_amounts[resource] = amount(resource) + granted[resource]
			stored[resource] = granted[resource]
	return stored

## La réserve couvre-t-elle ce coût, ressource par ressource ?
##
## Aucune conversion : manquer d'une seule ressource suffit à refuser, quel que soit
## l'excédent des autres.
func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for resource in cost:
		assert(cost[resource] >= 0, "coût négatif en %s : %d" % [resource, cost[resource]])
		if amount(resource) < cost[resource]:
			return false
	return true

## Paie ce coût. Rend faux et ne mute rien si la réserve ne le couvre pas.
##
## Tout ou rien : une dépense partielle laisserait la ville avec un bâtiment à moitié
## payé et rien pour le dire. C'est la même forme que PlacementResult — un refus est un
## résultat normal, pas un incident.
func spend(cost: Dictionary[StringName, int]) -> bool:
	if not can_afford(cost):
		return false
	for resource in cost:
		if cost[resource] > 0:
			_reduce(resource, cost[resource])
	return true

## Retire jusqu'à cette quantité et rend ce qui a pu être pris.
##
## Partiel à dessein, contrairement à spend() : c'est le chemin de l'upkeep, où manger
## la moitié de sa ration est précisément ce qui définit la famine. Rendre faux ici
## aurait laissé la nourriture intacte un soir de disette.
func take(resource: StringName, quantity: int) -> int:
	assert(quantity >= 0, "retrait négatif de %s : %d" % [resource, quantity])
	var taken := mini(quantity, amount(resource))
	if taken > 0:
		_reduce(resource, taken)
	return taken

## Retire `total` unités réparties **au prorata** de ce que chaque ressource pèse, et rend
## ce qui a réellement été pris.
##
## Le pendant exact de l'écrêtage d'un dépôt, et volontairement la même règle : une vague
## ne choisit pas ce qu'elle emporte, et deux réserves identiques rangées dans un ordre
## différent doivent perdre la même chose. C'est ce que E1 exige déjà de la répartition
## d'une récolte qui déborde.
##
## Elle existe parce que le Combat ne peut pas répondre à cette question. Un DamageReport
## dit combien la vague emporte, jamais quoi : lui faire calculer les parts demanderait
## qu'il voie le stock, donc le contenu d'un interne de l'Économie, et la règle de
## dépendance de CLAUDE.md l'interdit. « Ce que la réserve perd quand on lui prend N » est
## une question de la réserve, et elle se pose ici.
##
## Neutre de tout combat, jusque dans son nom : un événement de 3.7 ou un troc lui
## poseront la même question.
##
## Prendre plus que le total disponible vide simplement la réserve — un pillage n'a pas
## à savoir ce qu'il y avait.
func take_share(total: int) -> Dictionary[StringName, int]:
	assert(total >= 0, "retrait négatif : %d" % total)
	var taken: Dictionary[StringName, int] = {}
	if total <= 0 or _amounts.is_empty():
		return taken
	if total >= self.total():
		taken = amounts()
		_amounts.clear()
		return taken
	var shares := _shares(amounts(), total)
	for resource in shares:
		if shares[resource] <= 0:
			continue
		taken[resource] = shares[resource]
	for resource in taken:
		_reduce(resource, taken[resource])
	return taken

## Retire une quantité connue disponible, en tenant l'invariant « aucune clé à zéro ».
func _reduce(resource: StringName, quantity: int) -> void:
	var left := amount(resource) - quantity
	assert(left >= 0, "retrait de %d %s sur %d" % [quantity, resource, amount(resource)])
	if left == 0:
		_amounts.erase(resource)
	else:
		_amounts[resource] = left

## Répartit `room` unités entre les ressources de `bundle`, proportionnellement à ce
## que chacune y pèse.
##
## Le reste de la division entière va aux plus grosses parts fractionnaires ; à
## fractions égales, l'identifiant tranche. Deux appels sur les mêmes quantités rendent
## donc toujours la même chose, quel que soit l'ordre des clés.
func _shares(bundle: Dictionary[StringName, int], room: int) -> Dictionary[StringName, int]:
	var shares: Dictionary[StringName, int] = {}
	var asked := 0
	for resource in bundle:
		asked += bundle[resource]
	if asked <= 0 or room <= 0:
		return shares
	var granted := 0
	for resource in bundle:
		var share: int = bundle[resource] * room / asked
		shares[resource] = share
		granted += share
	var left := room - granted
	for resource in _remainder_order(bundle, room, asked):
		if left <= 0:
			break
		shares[resource] += 1
		left -= 1
	return shares

## Ressources triées par part fractionnaire décroissante, puis par identifiant.
##
## Le tri se fait sur String(...) et non sur le StringName : comparer deux StringName
## compare leurs pointeurs internes, ce qui donne un ordre stable le temps d'une session
## et différent à la suivante — un piège direct pour le déterminisme.
func _remainder_order(bundle: Dictionary[StringName, int], room: int,
		asked: int) -> Array[StringName]:
	var order: Array[StringName] = []
	order.assign(bundle.keys())
	order.sort_custom(func(first: StringName, second: StringName) -> bool:
		var left: int = (bundle[first] * room) % asked
		var right: int = (bundle[second] * room) % asked
		if left != right:
			return left > right
		return String(first) < String(second))
	return order
