class_name KeyCardNote
extends LevelNote

@export var key_id := "A"
@export var coin_capacity := 10

var collected := 0
var _displayed_remaining := -1


func _ready() -> void:
	text = ""
	%KeyLetter.text = key_id
	_refresh_deposit()


func is_captured() -> bool:
	return coin_capacity > 0 and collected >= coin_capacity


func granted_key() -> String:
	return key_id if is_captured() else ""


func deposit(available: int) -> Vector2i:
	if disabled or is_captured() or available <= 0 or coin_capacity <= 0:
		return Vector2i.ZERO
	collected += 1
	var prestige := 0
	if is_captured():
		prestige = 1
		show_completed()
		captured.emit(self)
	_refresh_deposit()
	return Vector2i(1, prestige)


func help_text() -> String:
	return tr("Key Card Note Help") % [coin_capacity, key_id]


func _refresh_deposit() -> void:
	var remaining := maxi(coin_capacity - collected, 0)
	var decreased := _displayed_remaining >= 0 and remaining < _displayed_remaining
	_displayed_remaining = remaining
	var amount_label := %DepositAmount as Label
	amount_label.text = str(remaining)
	if decreased:
		CounterPulse.play(amount_label)
