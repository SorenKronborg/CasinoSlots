class_name SlotReel
extends PanelContainer

var _symbols: Array[Texture2D] = []
var _index: int = 0

@onready var _symbol: TextureRect = $Symbol


func setup(symbols: Array[Texture2D]) -> void:
	_symbols = symbols
	if _symbols.is_empty():
		return
	show_index(0)


func show_index(index: int) -> void:
	if _symbols.is_empty():
		return
	_index = wrapi(index, 0, _symbols.size())
	_symbol.texture = _symbols[_index]


func show_random() -> int:
	if _symbols.is_empty():
		return 0
	show_index(randi() % _symbols.size())
	return _index


func current_index() -> int:
	return _index
