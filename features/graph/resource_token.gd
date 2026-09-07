class_name ResourceToken
extends Sprite2D

signal arrived

var _points: PackedVector2Array = PackedVector2Array()
var _speed := 220.0
var _traveled := 0.0
var _length := 0.0


func begin(
		points: PackedVector2Array,
		speed: float,
		icon: Texture2D,
		token_size: float,
		delay: float
) -> void:
	_points = points
	_speed = maxf(speed, 1.0)
	texture = icon
	centered = true
	z_index = 20
	_fit_size(token_size)
	_length = _polyline_length(_points)
	set_process(false)
	visible = false
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
	visible = true
	if _points.size() < 2 or _length <= 0.0:
		if not _points.is_empty():
			position = _points[_points.size() - 1]
		arrived.emit()
		queue_free()
		return
	position = _points[0]
	set_process(true)


func _process(delta: float) -> void:
	_traveled += _speed * delta
	if _traveled >= _length:
		position = _points[_points.size() - 1]
		set_process(false)
		arrived.emit()
		queue_free()
		return
	position = _point_at_distance(_points, _traveled)


func _fit_size(token_size: float) -> void:
	if texture == null or token_size <= 0.0:
		return
	var tex_size := texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return
	scale = Vector2.ONE * (token_size / longest)


func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


func _point_at_distance(points: PackedVector2Array, distance: float) -> Vector2:
	var remaining := distance
	for i in range(1, points.size()):
		var from_point := points[i - 1]
		var to_point := points[i]
		var segment := from_point.distance_to(to_point)
		if remaining <= segment or i == points.size() - 1:
			if segment <= 0.0:
				return to_point
			return from_point.lerp(to_point, remaining / segment)
		remaining -= segment
	return points[points.size() - 1]
