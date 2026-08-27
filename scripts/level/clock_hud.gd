class_name ClockHud
extends PanelContainer

var _spins_label: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.2, 0.2, 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	_spins_label = Label.new()
	_spins_label.text = "50 spins"
	_spins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spins_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	_spins_label.add_theme_font_size_override("font_size", 18)
	add_child(_spins_label)


func set_spins_left(count: int) -> void:
	if _spins_label == null:
		return
	var remaining := maxi(0, count)
	_spins_label.text = "%d %s" % [remaining, "spin" if remaining == 1 else "spins"]
