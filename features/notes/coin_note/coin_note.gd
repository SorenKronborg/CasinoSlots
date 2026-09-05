class_name CoinNote
extends LevelNote

@export var coin_capacity: int = 10
@export var prestige_reward: int = 1

var collected: int = 0
var _prestige_awarded := false


func _ready() -> void:
	text = ""
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
