class_name UpgradeCatalog
extends RefCounted

const EXTRA_WHEEL := &"extra_wheel"
const PRESTIGE_INCOME := &"prestige_income"
const COIN_INCOME := &"coin_income"
const EXTRA_SPIN := &"extra_spin"
const RESOURCE_SILO := &"resource_silo"
const SILO_CAPACITY_COST := 3
const SILO_CAPACITY_RANKS := 5


static func all_upgrades() -> Array[UpgradeDefinition]:
	return [
		_extra_wheel(),
		_prestige_income(),
		_coin_income(),
		_extra_spin(),
		_resource_silo(),
		_silo_capacity(GameResources.CHERRY, "Cherry Silo", Vector2(560, 400)),
		_silo_capacity(GameResources.BELL, "Bell Silo", Vector2(560, 480)),
		_silo_capacity(GameResources.WATERMELON, "Watermelon Silo", Vector2(560, 560)),
		_silo_capacity(GameResources.DIAMOND, "Diamond Silo", Vector2(560, 640)),
	]


static func by_id(upgrade_id: StringName) -> UpgradeDefinition:
	for upgrade in all_upgrades():
		if upgrade.id == upgrade_id:
			return upgrade
	return null


static func silo_capacity_id(resource_id: StringName) -> StringName:
	for upgrade in all_upgrades():
		if upgrade.resource_id == resource_id:
			return upgrade.id
	return &""


static func _extra_wheel() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = EXTRA_WHEEL
	upgrade.title = "Extra Wheel"
	upgrade.description = "Adds an extra wheel to your slot machine."
	upgrade.costs = [5]
	upgrade.prerequisite_id = EXTRA_SPIN
	upgrade.prerequisite_rank = 5
	upgrade.graph_position = Vector2(560, 310)
	return upgrade


static func _prestige_income() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = PRESTIGE_INCOME
	upgrade.title = "Prestige Income"
	upgrade.description = "Whenever you receive prestige you will receive +1."
	upgrade.costs = [3]
	upgrade.prerequisite_id = COIN_INCOME
	upgrade.prerequisite_rank = 3
	upgrade.graph_position = Vector2(560, 90)
	return upgrade


static func _coin_income() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = COIN_INCOME
	upgrade.title = "Coin Income"
	upgrade.description = "Whenever you receive coins you will get +1."
	upgrade.costs = [1, 3, 5]
	upgrade.graph_position = Vector2(80, 90)
	return upgrade


static func _extra_spin() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = EXTRA_SPIN
	upgrade.title = "Extra Spin"
	upgrade.description = "Adds 1 more spin each time you enter a level."
	upgrade.costs = [1, 3, 5, 7, 10]
	upgrade.graph_position = Vector2(80, 310)
	return upgrade


static func _resource_silo() -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = RESOURCE_SILO
	upgrade.title = "Resource Silo"
	upgrade.description = "Adds a silo for each resource beside the wheel. Leftover resources are stored there."
	upgrade.costs = [5]
	upgrade.graph_position = Vector2(80, 500)
	return upgrade


static func _silo_capacity(resource_id: StringName, title: String, position: Vector2) -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = StringName("silo_%s" % resource_id)
	upgrade.title = title
	upgrade.description = "Increases %s silo storage by 1." % String(resource_id)
	upgrade.costs = _repeated_cost(SILO_CAPACITY_COST, SILO_CAPACITY_RANKS)
	upgrade.prerequisite_id = RESOURCE_SILO
	upgrade.prerequisite_rank = 1
	upgrade.resource_id = resource_id
	upgrade.graph_position = position
	return upgrade


static func _repeated_cost(cost: int, purchases: int) -> Array[int]:
	var costs: Array[int] = []
	for _purchase in purchases:
		costs.append(cost)
	return costs
