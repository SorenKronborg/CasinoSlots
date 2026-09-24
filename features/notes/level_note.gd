class_name LevelNote
extends Button

signal captured(note: LevelNote)

@export var required_key: String = ""

var _graph_reachable := false
var _key_available := true


func note_id() -> String:
	return String(name)


func set_reachable(reachable: bool) -> void:
	_graph_reachable = reachable
	_refresh_access()


func set_key_access(available: bool) -> void:
	_key_available = available or required_key == ""
	_refresh_key_badge()
	_refresh_access()


func _refresh_key_badge() -> void:
	var badge := get_node_or_null("KeyBadge") as KeyBadge
	if badge == null:
		return
	if is_deposit_blocked():
		badge.visible = false
		return
	badge.show_key(required_key, _key_available)


func _refresh_access() -> void:
	disabled = not _graph_reachable or not _key_available or is_deposit_blocked()
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


func is_captured() -> bool:
	return false


func resource_multiplier() -> int:
	return 1


func accepts_repeating_resources() -> bool:
	return false


func granted_key() -> String:
	return ""


func is_deposit_blocked() -> bool:
	var attached := firewall()
	return attached != null and attached.is_active()


func firewall() -> LevelGraphFirewall:
	for child in get_children():
		var attached := child as LevelGraphFirewall
		if attached != null:
			return attached
	return null


func help_text() -> String:
	return tr("Note Help")


func full_help_text() -> String:
	var lines: Array[String] = [help_text()]
	var attached := firewall()
	if attached != null and attached.is_active():
		lines.append(attached.help_text())
	elif required_key != "":
		lines.append(tr("Key Gate Help") % required_key)
	return "\n".join(lines)
