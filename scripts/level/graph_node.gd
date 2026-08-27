class_name GraphNodeView
extends Button

signal node_pressed(id: StringName)
signal node_completed(id: StringName)

const SIZE := Vector2(72, 72)
const _STYLE_OPEN := Color(1, 0.85, 0.2, 1)
const _STYLE_OPEN_HOVER := Color(1, 0.92, 0.4, 1)
const _STYLE_OPEN_PRESSED := Color(0.92, 0.72, 0.12, 1)
const _STYLE_LOCKED := Color(0.55, 0.55, 0.55, 1)
const _STYLE_COMPLETE := Color(0.38, 0.78, 0.4, 1)

var node_id: StringName
var is_start: bool = false
var coin_cost: int = 10
var paid: int = 0
var board_position: Vector2 = Vector2.ZERO


func setup(data: GraphNodeData) -> void:
	node_id = data.id
	is_start = data.is_start
	coin_cost = data.coin_cost
	paid = 0
	board_position = data.position
	custom_minimum_size = SIZE
	size = SIZE
	place(Vector2.ZERO)
	_refresh_label()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func place(offset: Vector2) -> void:
	position = board_position + offset - SIZE * 0.5


func center() -> Vector2:
	return position + size * 0.5


func is_paid() -> bool:
	return paid >= coin_cost


func add_coin() -> void:
	if is_paid():
		return
	paid += 1
	_refresh_label()
	if is_paid():
		node_completed.emit(node_id)


func set_clickable(clickable: bool) -> void:
	disabled = not clickable


## reachable: the incoming lock is open (or this is the start). Colour does not
## depend on whether the player currently has a coin.
func apply_state(reachable: bool) -> void:
	if is_paid():
		disabled = true
		_paint(_STYLE_COMPLETE, _STYLE_COMPLETE, _STYLE_COMPLETE, _STYLE_COMPLETE)
		add_theme_color_override("font_disabled_color", Color(0.08, 0.22, 0.1, 1))
		return
	disabled = not reachable
	_paint(_STYLE_OPEN, _STYLE_OPEN_HOVER, _STYLE_OPEN_PRESSED, _STYLE_LOCKED)
	add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.35, 1))


func _paint(normal: Color, hover: Color, pressed: Color, locked: Color) -> void:
	add_theme_stylebox_override("normal", _circle(normal))
	add_theme_stylebox_override("hover", _circle(hover))
	add_theme_stylebox_override("pressed", _circle(pressed))
	add_theme_stylebox_override("disabled", _circle(locked))


func _circle(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(3)
	box.border_color = Color(0.15, 0.15, 0.15, 1)
	box.set_corner_radius_all(36)
	return box


func _refresh_label() -> void:
	text = "%d/%d" % [paid, coin_cost]


func _on_pressed() -> void:
	node_pressed.emit(node_id)
