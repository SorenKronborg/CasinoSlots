class_name ClockHud
extends PanelContainer

var _time_label: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.2, 0.2, 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	_time_label = Label.new()
	_time_label.text = "3:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	_time_label.add_theme_font_size_override("font_size", 22)
	add_child(_time_label)


func set_time_left(seconds: float) -> void:
	if _time_label == null:
		return
	var remaining := maxi(0, floori(seconds))
	_time_label.text = "%d:%02d" % [remaining / 60, remaining % 60]
