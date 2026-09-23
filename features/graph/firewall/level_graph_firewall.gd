class_name LevelGraphFirewall
extends Control

signal defeated(firewall: LevelGraphFirewall)

@export var vulnerable_resource: StringName = &"cherry"
@export var required_amount := 10

var collected := 0
var _displayed_remaining := -1
var _defeating := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_requirement()


func is_active() -> bool:
	return collected < required_amount or _defeating


func remaining() -> int:
	return maxi(required_amount - collected, 0)


func can_accept(resource: StringName) -> bool:
	return not _defeating and remaining() > 0 and resource == vulnerable_resource


func contribute(resource: StringName, amount: int) -> int:
	if amount <= 0 or not can_accept(resource):
		return amount
	var used := mini(amount, remaining())
	collected += used
	_refresh_requirement()
	if remaining() <= 0:
		_play_defeat()
	return amount - used


func set_resource_icon(texture: Texture2D) -> void:
	%VulnerableIcon.texture = texture
	%VulnerableIcon.visible = texture != null


func host_note() -> LevelNote:
	return get_parent() as LevelNote


func help_text() -> String:
	return tr("Firewall Help") % [required_amount, tr(String(vulnerable_resource).capitalize())]


func _refresh_requirement() -> void:
	var amount := remaining()
	var decreased := _displayed_remaining >= 0 and amount < _displayed_remaining
	_displayed_remaining = amount
	var amount_label := %Amount as Label
	amount_label.text = str(amount)
	if decreased:
		CounterPulse.play(amount_label)


func _play_defeat() -> void:
	_defeating = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 0.95, 0.55, 1), 0.18)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.65)
	tween.tween_property(self, "scale", Vector2.ONE * 0.45, 0.65)
	tween.finished.connect(_finish_defeat)


func _finish_defeat() -> void:
	_defeating = false
	visible = false
	defeated.emit(self)
