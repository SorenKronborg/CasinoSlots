class_name SlotPayout
extends RefCounted

var coins: int = 0
var symbols: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	symbols.resize(Symbols.COUNT)


static func from_spin(landed: Array[int]) -> SlotPayout:
	var counts := PackedInt32Array()
	counts.resize(Symbols.COUNT)
	for symbol in landed:
		counts[symbol] += 1
	var result := SlotPayout.new()
	for kind in Symbols.COUNT:
		match counts[kind]:
			1:
				result.symbols[kind] = 1
			2:
				result.symbols[kind] = 3
				result.coins += 3
			3:
				result.symbols[kind] = 10
				result.coins += 3
			4:
				result.symbols[kind] = 50
				result.coins += 50
	return result
