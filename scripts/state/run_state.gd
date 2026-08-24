class_name RunState
extends RefCounted

signal changed

var coins: int = 0
var prestige: int = 0
var symbols: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	symbols.resize(Symbols.COUNT)


func apply_payout(payout: SlotPayout) -> void:
	coins += payout.coins
	changed.emit()


func try_spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	changed.emit()
	return true


func add_prestige(amount: int = 1) -> void:
	prestige += amount
	changed.emit()
