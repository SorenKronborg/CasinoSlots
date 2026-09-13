class_name SiloNote
extends LevelNote

@export var resource_capacity: int = 10
@export var prestige_reward: int = 1

var collected: int = 0
var _prestige_awarded := false
var _displayed_remaining := -1


func _ready() -> void:
	text = ""
	_refresh_amount()


func is_full() -> bool:
	return resource_capacity > 0 and collected >= resource_capacity


func help_text() -> String:
	return tr("Silo Note Help") % [resource_capacity, prestige_reward]


func remaining_capacity() -> int:
	return maxi(resource_capacity - collected, 0)


func feed_leftover(amount: int) -> Vector2i:
	if amount <= 0 or resource_capacity <= 0:
		return Vector2i.ZERO
	var used := mini(amount, remaining_capacity())
	collected += used
	var prestige := 0
	if is_full() and not _prestige_awarded:
		_prestige_awarded = true
		prestige = prestige_reward
		show_completed()
	_refresh_amount()
	return Vector2i(used, prestige)


func _refresh_amount() -> void:
	var remaining := maxi(resource_capacity - collected, 0)
	var decreased := _displayed_remaining >= 0 and remaining < _displayed_remaining
	_displayed_remaining = remaining
	var amount_label := %DepositAmount as Label
	amount_label.text = str(remaining)
	if decreased:
		CounterPulse.play(amount_label)
