class_name LevelGraphLock
extends Node2D

signal unlock_finished

const FLASH_COLOR := Color(1, 0.97, 0.6, 1)
const POP_SCALE := 1.5
const POP_SECONDS := 0.16
const OPEN_TILT_DEGREES := -24.0
const OPEN_SECONDS := 0.34
const HOLD_SECONDS := 0.3
const FADE_SECONDS := 1.15
const FADE_RISE := 26.0
const FADE_SCALE := 0.7
const REFUSED_TINT := Color(1, 0.3, 0.28, 1)

@export var unlock_resource: StringName = &""
@export var unlock_cost: int = 10
@export var required_key: String = ""

var collected: int = 0

var _displayed_remaining := -1
var _unlocking := false
var _key_available := true
var _refused := false

@onready var _sprite: Sprite2D = $Lock
@onready var _requirement: Control = $Requirement
@onready var _refuse_toggle: Button = $RefuseToggle
@onready var _closed_scale: Vector2 = _sprite.scale


func _ready() -> void:
	_refuse_toggle.pressed.connect(_on_refuse_toggle_pressed)
	set_key_access(required_key == "")
	visible = is_locked()
	_refresh_requirement()


func is_locked() -> bool:
	return not _key_available or collected < unlock_cost


func is_refused() -> bool:
	return _refused


func set_refused(refused: bool) -> void:
	if _refused == refused:
		return
	_refused = refused
	_refresh_refused_tint()


func is_unlocking() -> bool:
	return _unlocking


func set_resource_icon(texture: Texture2D) -> void:
	%Icon.texture = texture
	%Icon.visible = texture != null


func set_key_access(available: bool) -> void:
	_key_available = available or required_key == ""
	var badge := get_node_or_null("KeyBadge") as KeyBadge
	if badge != null:
		badge.show_key(required_key, _key_available)


func can_accept(resource: StringName) -> bool:
	if _refused or not _key_available or not is_locked():
		return false
	return resource == unlock_resource


func contribute(resource: StringName, amount: int) -> int:
	if not can_accept(resource) or amount <= 0:
		return amount
	var needed := maxi(unlock_cost - collected, 0)
	var used := mini(amount, needed)
	collected += used
	_refresh_requirement()
	if not is_locked():
		_play_unlock()
	return amount - used


func _on_refuse_toggle_pressed() -> void:
	if _unlocking:
		return
	set_refused(not _refused)


func _refresh_refused_tint() -> void:
	var tint := REFUSED_TINT if _refused else Color.WHITE
	_sprite.modulate = tint
	_requirement.modulate = tint


func _refresh_requirement() -> void:
	var remaining := maxi(unlock_cost - collected, 0)
	var decreased := _displayed_remaining >= 0 and remaining < _displayed_remaining
	_displayed_remaining = remaining
	var amount_label := %Amount as Label
	amount_label.text = str(remaining)
	if decreased:
		CounterPulse.play(amount_label)


func _play_unlock() -> void:
	_unlocking = true
	var tween := create_tween().set_parallel(true)
	_add_opening_steps(tween)
	_add_vanishing_steps(tween)
	tween.finished.connect(_finish_unlock)


func _add_opening_steps(tween: Tween) -> void:
	tween.tween_property(_sprite, "scale", _closed_scale * POP_SCALE, POP_SECONDS) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate", FLASH_COLOR, POP_SECONDS)
	tween.tween_property(_requirement, "modulate:a", 0.0, POP_SECONDS)
	tween.chain() \
			.tween_property(_sprite, "rotation", deg_to_rad(OPEN_TILT_DEGREES), OPEN_SECONDS) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", _closed_scale, OPEN_SECONDS)


func _add_vanishing_steps(tween: Tween) -> void:
	tween.chain().tween_interval(HOLD_SECONDS)
	tween.chain().tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - FADE_RISE, FADE_SECONDS)
	tween.tween_property(_sprite, "scale", _closed_scale * FADE_SCALE, FADE_SECONDS)


func _finish_unlock() -> void:
	_unlocking = false
	visible = false
	unlock_finished.emit()
