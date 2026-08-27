class_name GraphEdgeView
extends Control

signal lock_clicked(id: StringName)

const _COLOR_BLOCKED := Color(0.12, 0.12, 0.12, 1)
const _COLOR_OPEN := Color(0.35, 0.7, 0.3, 1)
## Edges run straight along one axis and turn corners with a quarter circle.
const CORNER_RADIUS := 54.0
const ARC_STEPS := 10
const LINE_STEPS := 40
## Below this the two circles count as lined up, and the edge stays straight.
const AXIS_EPSILON := 2.0
## Clear space between two locks sitting on the same edge.
const LOCK_GAP := 16.0

var edge_id: StringName
var from_id: StringName
var to_id: StringName
var locked: bool = true
## The locks on this edge, ordered from the source circle outwards. Only the
## first unpaid one takes resources; anything behind it stays hidden.
var lock_symbols: PackedInt32Array = PackedInt32Array()
var totals: PackedInt32Array = PackedInt32Array()
var remaining: PackedInt32Array = PackedInt32Array()
## How many locks deep this edge sits from the start node, used to pay the
## nearest locks first.
var depth: int = 0
## Player-chosen target: prioritized locks are filled before all others.
var prioritized: bool = false
var _in_flight: PackedInt32Array = PackedInt32Array()

var _line: Line2D
var _lock_panels: Array[PanelContainer] = []
var _lock_labels: Array[Label] = []
var _from_center: Vector2 = Vector2.ZERO
var _to_center: Vector2 = Vector2.ZERO
var _path: PackedVector2Array = PackedVector2Array()
var _path_length: float = 0.0
## Where each lock sits along the path, as a share of its total length.
var _lock_offsets: PackedFloat32Array = PackedFloat32Array()
var _style_idle: StyleBoxFlat
var _style_priority: StyleBoxFlat
var _style_opened: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = _COLOR_BLOCKED
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_line)
	_style_idle = _make_style(Color(0.96, 0.96, 0.96, 0.96), Color(0.25, 0.25, 0.25, 1))
	_style_priority = _make_style(Color(0.44, 0.85, 0.45, 0.98), Color(0.11, 0.42, 0.14, 1))
	_style_opened = _make_style(Color(0.82, 0.9, 0.82, 0.9), Color(0.35, 0.7, 0.3, 1))


func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(7)
	style.set_content_margin_all(5)
	return style


func setup(data: GraphEdgeData, from_center: Vector2, to_center: Vector2) -> void:
	edge_id = data.id
	from_id = data.from_id
	to_id = data.to_id
	if _line == null:
		await ready
	lock_symbols = data.lock_symbols.duplicate()
	totals = data.lock_amounts.duplicate()
	totals.resize(lock_symbols.size())
	remaining = totals.duplicate()
	_in_flight = PackedInt32Array()
	_in_flight.resize(lock_symbols.size())
	_build_locks()
	set_endpoints(from_center, to_center)
	set_locked(data.locked)


func _build_locks() -> void:
	for panel in _lock_panels:
		panel.queue_free()
	_lock_panels.clear()
	_lock_labels.clear()
	for index in lock_symbols.size():
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _style_idle)
		panel.gui_input.connect(_on_lock_gui_input.bind(panel))
		add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Symbols.texture(lock_symbols[index])
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		_lock_panels.append(panel)
		_lock_labels.append(label)
	_refresh_locks()


func set_endpoints(from_center: Vector2, to_center: Vector2) -> void:
	if _line == null:
		return
	_from_center = from_center
	_to_center = to_center
	_rebuild_path()
	_place_locks()
	_update_line()


## Lays the locks out end to end around the middle of the edge, measuring the
## room each one actually needs so a chain of them never overlaps.
func _place_locks() -> void:
	_lock_offsets = PackedFloat32Array()
	_lock_offsets.resize(_lock_panels.size())
	if _lock_panels.is_empty() or _path_length <= 0.0:
		return
	var runs_sideways := absf(_to_center.x - _from_center.x) >= absf(_to_center.y - _from_center.y)
	var extents := PackedFloat32Array()
	var needed := LOCK_GAP * float(_lock_panels.size() - 1)
	for panel in _lock_panels:
		panel.reset_size()
		var extent: float = panel.size.x if runs_sideways else panel.size.y
		extents.append(extent)
		needed += extent
	var cursor := maxf((_path_length - needed) * 0.5, 0.0)
	for index in _lock_panels.size():
		cursor += extents[index] * 0.5
		var along := clampf(cursor / _path_length, 0.0, 1.0)
		_lock_offsets[index] = along
		_lock_panels[index].position = _point_at(along) - _lock_panels[index].size * 0.5
		cursor += extents[index] * 0.5 + LOCK_GAP


## Circles that share a row or column are joined by a straight run. Everything
## else takes the long leg first, then rounds off into the short one with a
## quarter circle, so the board reads like drawn track rather than diagonals.
func _rebuild_path() -> void:
	_path = PackedVector2Array([_from_center])
	var delta := _to_center - _from_center
	if absf(delta.x) < AXIS_EPSILON or absf(delta.y) < AXIS_EPSILON:
		_path.append(_to_center)
		_measure_path()
		return
	var radius := minf(CORNER_RADIUS, minf(absf(delta.x), absf(delta.y)))
	var step := Vector2(signf(delta.x), signf(delta.y)) * radius
	var corner: Vector2
	var arc_start: Vector2
	var arc_end: Vector2
	if absf(delta.x) >= absf(delta.y):
		corner = Vector2(_to_center.x, _from_center.y)
		arc_start = corner - Vector2(step.x, 0.0)
		arc_end = corner + Vector2(0.0, step.y)
	else:
		corner = Vector2(_from_center.x, _to_center.y)
		arc_start = corner - Vector2(0.0, step.y)
		arc_end = corner + Vector2(step.x, 0.0)
	var center := arc_start + arc_end - corner
	_path.append(arc_start)
	_append_arc(center, arc_start, arc_end)
	_path.append(_to_center)
	_measure_path()


func _append_arc(center: Vector2, from_point: Vector2, to_point: Vector2) -> void:
	var start_angle := (from_point - center).angle()
	var sweep := wrapf((to_point - center).angle() - start_angle, -PI, PI)
	var radius := (from_point - center).length()
	for step in range(1, ARC_STEPS):
		var angle := start_angle + sweep * float(step) / float(ARC_STEPS)
		_path.append(center + Vector2.RIGHT.rotated(angle) * radius)
	_path.append(to_point)


func _measure_path() -> void:
	_path_length = 0.0
	for index in range(1, _path.size()):
		_path_length += _path[index].distance_to(_path[index - 1])


## Walks the path by distance so locks sit evenly spaced no matter how much of
## the edge is straight and how much is corner.
func _point_at(along: float) -> Vector2:
	if _path.size() < 2:
		return _from_center
	var target := _path_length * clampf(along, 0.0, 1.0)
	var travelled := 0.0
	for index in range(1, _path.size()):
		var span := _path[index] - _path[index - 1]
		var length := span.length()
		if travelled + length >= target:
			var into := 0.0 if length <= 0.0 else (target - travelled) / length
			return _path[index - 1] + span * into
		travelled += length
	return _path[_path.size() - 1]


func set_locked(value: bool) -> void:
	locked = value
	if _line:
		_line.default_color = _COLOR_BLOCKED if locked else _COLOR_OPEN
	_refresh_locks()
	_update_line()


## The lock currently taking resources, or -1 when every lock here is paid off.
func active_lock_index() -> int:
	for index in remaining.size():
		if remaining[index] > 0:
			return index
	return -1


## Whether the far side of this edge has been opened up. An edge is passable
## only once every lock on it is open.
func is_passable() -> bool:
	return not locked


func is_fully_paid() -> bool:
	return active_lock_index() < 0


func lock_center_global(index: int) -> Vector2:
	if index < 0 or index >= _lock_panels.size():
		return global_position
	return _lock_panels[index].get_global_rect().get_center()


func open_capacity(kind: int) -> int:
	var index := active_lock_index()
	if index < 0 or lock_symbols[index] != kind:
		return 0
	return remaining[index] - _in_flight[index]


func reserve(kind: int, amount: int) -> int:
	var index := active_lock_index()
	if index < 0 or lock_symbols[index] != kind:
		return 0
	var taken := mini(amount, open_capacity(kind))
	_in_flight[index] += taken
	return taken


func apply_payment(index: int, amount: int) -> int:
	if index < 0 or index >= remaining.size():
		return 0
	var taken := mini(amount, remaining[index])
	remaining[index] -= taken
	_in_flight[index] = maxi(_in_flight[index] - taken, 0)
	_refresh_locks()
	_update_line()
	return taken


## Only the lock that can currently take resources responds to clicks.
func set_selectable(value: bool) -> void:
	var active := active_lock_index()
	for index in _lock_panels.size():
		var panel := _lock_panels[index]
		var enabled := value and index == active
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW


func set_prioritized(value: bool) -> void:
	prioritized = value
	_refresh_locks()


## Locks past the active one are still hidden, so the player only ever sees the
## next thing standing in the way.
func _refresh_locks() -> void:
	var active := active_lock_index()
	for index in _lock_panels.size():
		var panel := _lock_panels[index]
		_lock_labels[index].text = "%d/%d" % [totals[index] - remaining[index], totals[index]]
		panel.visible = locked and index <= maxi(active, 0)
		if remaining[index] <= 0:
			panel.add_theme_stylebox_override("panel", _style_opened)
		elif index == active and prioritized:
			panel.add_theme_stylebox_override("panel", _style_priority)
		else:
			panel.add_theme_stylebox_override("panel", _style_idle)


## While a lock still blocks the way, the line stops where it meets that lock so
## the player never sees track leading to a circle that is still hidden.
func _update_line() -> void:
	if _line == null:
		return
	var limit := 1.0
	var blocker := Rect2()
	var index := active_lock_index()
	if not is_passable() and index >= 0 and index < _lock_offsets.size():
		limit = _lock_offsets[index]
		blocker = Rect2(_lock_panels[index].position, _lock_panels[index].size)
	var points := PackedVector2Array()
	for step in LINE_STEPS + 1:
		var along := float(step) / float(LINE_STEPS)
		if along > limit:
			break
		var point := _point_at(along)
		if blocker.has_area() and blocker.has_point(point):
			break
		points.append(point)
	if points.size() < 2:
		points = PackedVector2Array([_from_center, _point_at(limit)])
	_line.points = points


func _on_lock_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		panel.accept_event()
		lock_clicked.emit(edge_id)
