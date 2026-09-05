class_name LevelGraphLock
extends Node2D

@export var unlock_resource: StringName = &""
@export var unlock_cost: int = 10

var collected: int = 0


func _ready() -> void:
	_refresh_requirement()


func is_locked() -> bool:
	return collected < unlock_cost


func set_resource_icon(texture: Texture2D) -> void:
	%Icon.texture = texture
	%Icon.visible = texture != null


func contribute(resource: StringName, amount: int) -> int:
	if not is_locked() or amount <= 0 or resource != unlock_resource:
		return amount
	var needed := maxi(unlock_cost - collected, 0)
	var used := mini(amount, needed)
	collected += used
	_refresh_requirement()
	return amount - used


func _refresh_requirement() -> void:
	visible = is_locked()
	%Amount.text = "%s/%s" % [collected, unlock_cost]
