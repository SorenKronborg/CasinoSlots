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

@export var unlock_resource: StringName = &""
@export var unlock_cost: int = 10

var collected: int = 0

var _displayed_remaining := -1
var _unlocking := false

@onready var _sprite: Sprite2D = $Lock
@onready var _requirement: Control = $Requirement
@onready var _closed_scale: Vector2 = _sprite.scale


func _ready() -> void:
	visible = is_locked()
	_refresh_requirement()


func is_locked() -> bool:
	return collected < unlock_cost


func is_unlocking() -> bool:
	return _unlocking


func set_resource_icon(texture: Texture2D) -> void:
	%Icon.texture = texture
	%Icon.visible = texture != null


func contribute(resource: StringName, amount: int) -> int:
	if not is_locked() or amount <= 0 or resource != unlock_resource:
		return amount
	var needed := maxi(unlock_cost - collected, 0)
	var used := mini(amount, needed)
	collected += used
	_refresh_requirement()
	if not is_locked():
		_play_unlock()
	return amount - used


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
