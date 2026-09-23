class_name SiloNote
extends LevelNote

@export var resource_capacity: int = 10

var collected: int = 0
var _displayed_remaining := -1


func _ready() -> void:
	text = ""
	_refresh_amount()


func help_text() -> String:
	return tr("Silo Note Help") % resource_capacity


func remaining_capacity() -> int:
	return maxi(resource_capacity - collected, 0)


func accepts_repeating_resources() -> bool:
	return true


func feed_leftover(amount: int) -> Vector2i:
	if amount <= 0 or resource_capacity <= 0:
		return Vector2i.ZERO
	collected += amount
	var prestige := int(collected / resource_capacity)
	collected %= resource_capacity
	_refresh_amount()
	return Vector2i(amount, prestige)


func _refresh_amount() -> void:
	var remaining := maxi(resource_capacity - collected, 0)
	var decreased := _displayed_remaining >= 0 and remaining < _displayed_remaining
	_displayed_remaining = remaining
	var amount_label := %DepositAmount as Label
	amount_label.text = str(remaining)
	if decreased:
		CounterPulse.play(amount_label)
