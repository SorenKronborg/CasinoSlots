class_name UpgradeCatalog
extends RefCounted

const EXTRA_WHEEL := &"extra_wheel"
const PRESTIGE_INCOME := &"prestige_income"
const COIN_INCOME := &"coin_income"
const EXTRA_SPIN := &"extra_spin"


static func all_upgrades() -> Array[UpgradeDefinition]:
	return [
		_extra_wheel(),
		_prestige_income(),
		_coin_income(),
		_extra_spin(),
	]


static func by_id(upgrade_id: StringName) -> UpgradeDefinition:
	for upgrade in all_upgrades():
		if upgrade.id == upgrade_id:
			return upgrade
	return null


static func _extra_wheel() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = EXTRA_WHEEL
	upgrade.title = "Extra Wheel"
	upgrade.description = "Adds an extra wheel to your slot machine."
	upgrade.costs = [5]
	return upgrade


static func _prestige_income() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = PRESTIGE_INCOME
	upgrade.title = "Prestige Income"
	upgrade.description = "Whenever you receive prestige you will receive +1."
	upgrade.costs = [3]
	return upgrade


static func _coin_income() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = COIN_INCOME
	upgrade.title = "Coin Income"
	upgrade.description = "Whenever you receive coins you will get +1."
	upgrade.costs = [1, 3, 5]
	return upgrade


static func _extra_spin() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = EXTRA_SPIN
	upgrade.title = "Extra Spin"
	upgrade.description = "Adds 1 more spin each time you enter a level."
	upgrade.costs = [1, 3, 5, 7, 10]
	return upgrade
