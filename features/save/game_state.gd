extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const DEFAULT_RESOURCES := {
	"prestige": 5,
}

var resources: Dictionary = DEFAULT_RESOURCES.duplicate()
var upgrade_ranks: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset() -> void:
	resources = DEFAULT_RESOURCES.duplicate()
	upgrade_ranks.clear()


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


func try_purchase(upgrade_id: StringName) -> bool:
	var upgrade := UpgradeCatalog.by_id(upgrade_id)
	if upgrade == null:
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
	return OK
