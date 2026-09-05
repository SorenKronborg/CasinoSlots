class_name SiloNote
extends LevelNote

@export var resource_capacity: int = 10
@export var prestige_reward: int = 1

var collected: int = 0
var _prestige_awarded := false


func _ready() -> void:
	text = ""
	_refresh_amount()


func is_full() -> bool:
	return resource_capacity > 0 and collected >= resource_capacity


func feed_leftover(amount: int) -> Vector2i:
	if disabled or is_full() or amount <= 0 or resource_capacity <= 0:
		return Vector2i.ZERO
	var needed := maxi(resource_capacity - collected, 0)
	var used := mini(amount, needed)
	collected += used
	var prestige := 0
	if is_full() and not _prestige_awarded:
		_prestige_awarded = true
		prestige = prestige_reward
	_refresh_amount()
	return Vector2i(used, prestige)


func _refresh_amount() -> void:
	%DepositAmount.text = "%s/%s" % [collected, resource_capacity]
