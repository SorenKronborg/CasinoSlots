class_name GraphEdgeView
extends Control

const LOCK_TEXTURE := preload("res://assets/icons/lock.svg")

var edge_id: StringName
var from_id: StringName
var to_id: StringName
var locked: bool = true
var lock_symbol: int = 0
var lock_amount: int = 10
var remaining: int = 10
var _in_flight: int = 0

var _line: Line2D
var _lock_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(0.12, 0.12, 0.12, 1)
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_line)
	_lock_button = Button.new()
	_lock_button.custom_minimum_size = Vector2(56, 40)
	_lock_button.focus_mode = Control.FOCUS_NONE
	_lock_button.icon = LOCK_TEXTURE
	_lock_button.expand_icon = true
	_lock_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_button.add_theme_font_size_override("font_size", 12)
	add_child(_lock_button)


func setup(data: GraphEdgeData, from_center: Vector2, to_center: Vector2) -> void:
	edge_id = data.id
	from_id = data.from_id
	to_id = data.to_id
	lock_symbol = data.lock_symbol
	lock_amount = data.lock_amount
	remaining = data.lock_amount
	if _line == null:
		await ready
	_lock_button.icon = Symbols.texture(lock_symbol)
	_refresh_label()
	set_endpoints(from_center, to_center)
	set_locked(data.locked)


func set_endpoints(from_center: Vector2, to_center: Vector2) -> void:
	if _line == null:
		return
	_line.points = PackedVector2Array([from_center, to_center])
	var midpoint := from_center.lerp(to_center, 0.5)
	_lock_button.position = midpoint - _lock_button.custom_minimum_size * 0.5


func set_locked(value: bool) -> void:
	locked = value
	if _lock_button:
		_lock_button.visible = locked
	if _line:
		_line.default_color = Color(0.12, 0.12, 0.12, 1) if locked else Color(0.35, 0.7, 0.3, 1)


func lock_center_global() -> Vector2:
	if _lock_button == null:
		return global_position
	return _lock_button.get_global_rect().get_center()


func open_capacity() -> int:
	return remaining - _in_flight


func reserve(amount: int) -> int:
	var taken := mini(amount, open_capacity())
	_in_flight += taken
	return taken


func apply_payment(amount: int) -> int:
	var taken := mini(amount, remaining)
	remaining -= taken
	_in_flight = maxi(_in_flight - taken, 0)
	_refresh_label()
	return taken


func _refresh_label() -> void:
	if _lock_button:
		_lock_button.text = str(remaining)
