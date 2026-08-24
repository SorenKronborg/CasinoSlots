class_name Reel
extends PanelContainer

signal landed(symbol: int)

@onready var _icon: TextureRect = %Icon

var _current: int = Symbols.Kind.CHERRY
var _spinning: bool = false


func _ready() -> void:
	_show(_current)


func is_spinning() -> bool:
	return _spinning


func current_symbol() -> int:
	return _current


func spin(target: int, duration: float) -> void:
	if _spinning:
		return
	_spinning = true
	var elapsed := 0.0
	var step := 0.06
	while elapsed < duration:
		_show(randi() % Symbols.COUNT)
		await get_tree().create_timer(step).timeout
		elapsed += step
		step = lerpf(0.05, 0.12, elapsed / duration)
	_show(target)
	_spinning = false
	landed.emit(_current)


func _show(kind: int) -> void:
	_current = kind
	_icon.texture = Symbols.texture(kind)
