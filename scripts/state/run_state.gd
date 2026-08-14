class_name RunState
extends RefCounted

## Everything a run accumulates: the wallet and the upgrades bought with it. The
## machine and the upgrades screen both work off this one object, so neither has
## to know the other exists.

const STARTING_CREDITS := 1000

signal credits_changed(credits: int)
signal upgrades_changed()

var tree: UpgradeTree

var _credits := STARTING_CREDITS
var _purchased: Array[StringName] = []

## Read-only from the outside: the wallet only moves through spend() and award(),
## so every change is one of those two and always reports itself.
var credits: int:
	get:
		return _credits


func _init(upgrade_tree: UpgradeTree = null, starting_credits := STARTING_CREDITS) -> void:
	tree = upgrade_tree
	_credits = starting_credits


func purchased() -> Array[StringName]:
	return _purchased.duplicate()


func owns(id: StringName) -> bool:
	return _purchased.has(id)


func can_afford(amount: int) -> bool:
	return _credits >= amount


func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	_credits -= amount
	credits_changed.emit(_credits)
	return true


func award(amount: int) -> void:
	if amount <= 0:
		return
	_credits += amount
	credits_changed.emit(_credits)


## Buys an upgrade, or returns false if the chain or the wallet says no. Both
## checks live here rather than in the UI, so a mis-wired button cannot hand out
## a free upgrade.
func purchase(id: StringName) -> bool:
	if tree == null or not tree.is_available(id, _purchased):
		return false
	var upgrade := tree.find(id)
	if not spend(upgrade.cost):
		return false
	_purchased.append(id)
	upgrades_changed.emit()
	return true


func effects() -> UpgradeEffects:
	var owned: Array[UpgradeData] = []
	if tree != null:
		for id in _purchased:
			var upgrade := tree.find(id)
			if upgrade != null:
				owned.append(upgrade)
	return UpgradeEffects.of(owned)
