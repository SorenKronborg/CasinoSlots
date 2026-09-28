extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3
const BASE_SILO_CAPACITY := 5
const DEFAULT_RESOURCES := {
	"prestige": 5,
}

var resources: Dictionary = DEFAULT_RESOURCES.duplicate()
var upgrade_ranks: Dictionary = {}
var silo_amounts: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset() -> void:
	resources = DEFAULT_RESOURCES.duplicate()
	upgrade_ranks.clear()
	silo_amounts.clear()


func prestige() -> int:
	return int(resources.get("prestige", 0))


func rank_of(upgrade_id: StringName) -> int:
	return int(upgrade_ranks.get(String(upgrade_id), 0))


func grant_prestige(base: int) -> int:
	if base <= 0:
		return 0
	if rank_of(UpgradeCatalog.PRESTIGE_INCOME) > 0:
		return base + 1
	return base


func coin_income_bonus() -> int:
	return rank_of(UpgradeCatalog.COIN_INCOME)


func extra_spin_bonus() -> int:
	return rank_of(UpgradeCatalog.EXTRA_SPIN)


func has_extra_wheel() -> bool:
	return rank_of(UpgradeCatalog.EXTRA_WHEEL) > 0


func has_resource_silos() -> bool:
	return rank_of(UpgradeCatalog.RESOURCE_SILO) > 0


func silo_capacity(resource_id: StringName) -> int:
	if not has_resource_silos():
		return 0
	return BASE_SILO_CAPACITY + rank_of(UpgradeCatalog.silo_capacity_id(resource_id))


func silo_stored(resource_id: StringName) -> int:
	return int(silo_amounts.get(String(resource_id), 0))


func store_silo_resources(resource_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var room := silo_capacity(resource_id) - silo_stored(resource_id)
	var accepted := mini(amount, maxi(room, 0))
	if accepted <= 0:
		return 0
	silo_amounts[String(resource_id)] = silo_stored(resource_id) + accepted
	return accepted


func withdraw_silo_resource(resource_id: StringName) -> bool:
	var stored := silo_stored(resource_id)
	if stored <= 0:
		return false
	silo_amounts[String(resource_id)] = stored - 1
	return true


func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	var upgrade := UpgradeCatalog.by_id(upgrade_id)
	if upgrade == null:
		return false
	if not upgrade.has_prerequisite():
		return true
	return upgrade.prerequisite_met(rank_of(upgrade.prerequisite_id))


func try_purchase(upgrade_id: StringName) -> bool:
	var upgrade := UpgradeCatalog.by_id(upgrade_id)
	if upgrade == null or not is_upgrade_unlocked(upgrade_id):
		return false
	var current_rank := rank_of(upgrade_id)
	if upgrade.is_maxed(current_rank):
		return false
	var cost := upgrade.next_cost(current_rank)
	if cost < 0 or prestige() < cost:
		return false
	if not spend_prestige(cost):
		return false
	upgrade_ranks[String(upgrade_id)] = current_rank + 1
	return true


func spend_prestige(amount: int) -> bool:
	if amount <= 0 or prestige() < amount:
		return false
	resources["prestige"] = prestige() - amount
	return true


func save_game() -> Error:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_to_save_dict(), "\t"))
	return OK


func load_game() -> Error:
	if not has_save():
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return ERR_INVALID_DATA
	return _apply_save_dict(parsed)


func _to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"resources": resources.duplicate(),
		"upgrade_ranks": upgrade_ranks.duplicate(),
		"silo_amounts": silo_amounts.duplicate(),
	}


func _apply_save_dict(data: Dictionary) -> Error:
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return ERR_INVALID_DATA
	var saved_resources: Variant = data.get("resources")
	resources = DEFAULT_RESOURCES.duplicate()
	if saved_resources is Dictionary:
		for key in resources:
			if saved_resources.has(key):
				resources[key] = saved_resources[key]
	upgrade_ranks.clear()
	var saved_ranks: Variant = data.get("upgrade_ranks")
	if saved_ranks is Dictionary:
		for upgrade_id in saved_ranks:
			upgrade_ranks[str(upgrade_id)] = int(saved_ranks[upgrade_id])
	silo_amounts.clear()
	var saved_silos: Variant = data.get("silo_amounts")
	if saved_silos is Dictionary:
		for resource_id in saved_silos:
			silo_amounts[str(resource_id)] = maxi(int(saved_silos[resource_id]), 0)
	return OK
