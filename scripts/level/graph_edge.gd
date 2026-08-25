class_name GraphEdgeView
extends Control

var edge_id: StringName
var from_id: StringName
var to_id: StringName
var locked: bool = true
var lock_symbols: PackedInt32Array = PackedInt32Array()
var remaining: PackedInt32Array = PackedInt32Array()
var _in_flight: PackedInt32Array = PackedInt32Array()

var _line: Line2D
var _lock_panel: PanelContainer
var _requirement_labels: Array[Label] = []
var _requirement_views: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(0.12, 0.12, 0.12, 1)
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_line)
	_lock_panel = PanelContainer.new()
	_lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.96, 0.96, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.25, 0.25, 0.25, 1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(5)
	_lock_panel.add_theme_stylebox_override("panel", style)
	add_child(_lock_panel)


func setup(data: GraphEdgeData, from_center: Vector2, to_center: Vector2) -> void:
	edge_id = data.id
	from_id = data.from_id
	to_id = data.to_id
	if _line == null:
		await ready
	lock_symbols = PackedInt32Array([data.lock_symbol])
	remaining = PackedInt32Array([data.lock_amount])
	if data.lock_symbol_2 >= 0 and data.lock_amount_2 > 0:
		lock_symbols.append(data.lock_symbol_2)
		remaining.append(data.lock_amount_2)
	_in_flight.resize(lock_symbols.size())
	_build_requirements()
	set_endpoints(from_center, to_center)
	set_locked(data.locked)


func _build_requirements() -> void:
	for child in _lock_panel.get_children():
		child.queue_free()
	_requirement_labels.clear()
	_requirement_views.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_lock_panel.add_child(row)
	for index in lock_symbols.size():
		var requirement := HBoxContainer.new()
		requirement.add_theme_constant_override("separation", 2)
		row.add_child(requirement)
		var icon := TextureRect.new()
		icon.texture = Symbols.texture(lock_symbols[index])
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		requirement.add_child(icon)
		var label := Label.new()
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
		label.add_theme_font_size_override("font_size", 12)
		requirement.add_child(label)
		_requirement_labels.append(label)
		_requirement_views.append(requirement)
	_refresh_labels()


func set_endpoints(from_center: Vector2, to_center: Vector2) -> void:
	if _line == null:
		return
	_line.points = PackedVector2Array([from_center, to_center])
	var midpoint := from_center.lerp(to_center, 0.5)
	_lock_panel.reset_size()
	_lock_panel.position = midpoint - _lock_panel.size * 0.5


func set_locked(value: bool) -> void:
	locked = value
	if _lock_panel:
		_lock_panel.visible = locked
	if _line:
		_line.default_color = Color(0.12, 0.12, 0.12, 1) if locked else Color(0.35, 0.7, 0.3, 1)


func lock_center_global(kind: int) -> Vector2:
	var index := lock_symbols.find(kind)
	if index >= 0 and index < _requirement_views.size():
		return _requirement_views[index].get_global_rect().get_center()
	if _lock_panel == null:
		return global_position
	return _lock_panel.get_global_rect().get_center()


func open_capacity(kind: int) -> int:
	var index := lock_symbols.find(kind)
	if index < 0:
		return 0
	return remaining[index] - _in_flight[index]


func reserve(kind: int, amount: int) -> int:
	var index := lock_symbols.find(kind)
	if index < 0:
		return 0
	var taken := mini(amount, open_capacity(kind))
	_in_flight[index] += taken
	return taken


func apply_payment(kind: int, amount: int) -> int:
	var index := lock_symbols.find(kind)
	if index < 0:
		return 0
	var taken := mini(amount, remaining[index])
	remaining[index] -= taken
	_in_flight[index] = maxi(_in_flight[index] - taken, 0)
	_refresh_labels()
	return taken


func is_fully_paid() -> bool:
	for amount in remaining:
		if amount > 0:
			return false
	return true


func _refresh_labels() -> void:
	for index in _requirement_labels.size():
		_requirement_labels[index].text = str(remaining[index])
