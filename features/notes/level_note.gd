class_name LevelNote
extends Button


func note_id() -> String:
	return String(name)


func set_reachable(reachable: bool) -> void:
	disabled = not reachable
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL


func deposit(_available: int) -> Vector2i:
	return Vector2i.ZERO


func feed_leftover(_amount: int) -> Vector2i:
	return Vector2i.ZERO
