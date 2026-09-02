class_name LevelGraphNode
extends Button

var node_id: String = ""
var normalized_position: Vector2 = Vector2(0.5, 0.5)
var coin_capacity: int = 0
var prestige_reward: int = 0
var collected: int = 0
var _prestige_awarded := false


func setup(spec: LevelNodeSpec) -> void:
	node_id = spec.id
	normalized_position = spec.normalized_position
	text = ""
	coin_capacity = spec.coin_capacity
	prestige_reward = spec.prestige_reward
	collected = 0
	_prestige_awarded = false
	_refresh_deposit()


func is_full() -> bool:
	return coin_capacity > 0 and collected >= coin_capacity


func deposit(available: int) -> Vector2i:
	if disabled or is_full() or available <= 0 or coin_capacity <= 0:
		return Vector2i.ZERO
	collected += 1
	var prestige := 0
	if is_full() and not _prestige_awarded:
		_prestige_awarded = true
		prestige = prestige_reward
	_refresh_deposit()
	return Vector2i(1, prestige)


func _refresh_deposit() -> void:
	%DepositAmount.text = "%s/%s" % [collected, coin_capacity]
