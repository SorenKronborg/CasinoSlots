class_name LevelNote
extends Button


func note_id() -> String:
	return String(name)


func set_reachable(reachable: bool) -> void:
	disabled = not reachable
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL


func show_completed() -> void:
	var fill := Color(0.06, 0.42, 0.14, 1)
	var border := Color(0.35, 0.9, 0.45, 1)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var current := get_theme_stylebox(style_name, "Button")
		if current is not StyleBoxFlat:
			continue
		var box := (current as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.bg_color = fill
		box.border_color = border
		add_theme_stylebox_override(style_name, box)


func deposit(_available: int) -> Vector2i:
	return Vector2i.ZERO


func remaining_capacity() -> int:
	return 0


func feed_leftover(_amount: int) -> Vector2i:
	return Vector2i.ZERO
