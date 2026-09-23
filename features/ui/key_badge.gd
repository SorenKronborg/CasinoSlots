class_name KeyBadge
extends PanelContainer


func show_key(key_id: String, available: bool) -> void:
	visible = key_id != ""
	if not visible:
		return
	%KeyLabel.text = key_id
	modulate = Color.WHITE if available else Color(0.45, 0.45, 0.45, 1)
