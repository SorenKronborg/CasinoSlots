class_name GraphNodeView
extends Button

signal node_pressed(id: StringName)
signal node_completed(id: StringName)

const SIZE := Vector2(72, 72)

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


func _refresh_label() -> void:
	text = "%d/%d" % [paid, coin_cost]


func _on_pressed() -> void:
	node_pressed.emit(node_id)
