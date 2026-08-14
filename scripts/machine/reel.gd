class_name Reel
extends VBoxContainer

## One reel column: a single quad whose shader scrolls a vertical symbol strip,
## with its hold button underneath. The entire visual state of the wheel is the
## scroll offset, measured in whole strip cycles.

signal landed(reel_index: int, symbol: int)
signal hold_toggled(reel_index: int, held: bool)

## Scroll rate while cruising, in symbols per second.
@export var symbols_per_second := 45.0
@export var accel_time := 0.22
@export var decel_time := 0.55

## Least amount of strip the reel must cover, in whole revolutions. Without a
## floor, a stop that happens to sit just past the cruise makes for a noticeably
## shorter spin than one that just misses it.
@export_range(0.0, 6.0, 0.5) var minimum_revolutions := 1.0

## Small bounce past the stop position before settling, in symbols. This is
## where most of the mechanical feel comes from.
@export var overshoot_symbols := 0.25
@export var settle_time := 0.16

## Vertical smear in symbol cells while at full speed.
@export var blur_strength := 2.2

var reel_index := 0

@onready var _symbol: ColorRect = %Symbol
@onready var _hold_button: Button = %HoldButton

var _strip := PackedInt32Array()
var _shader_material: ShaderMaterial
var _offset := 0.0
var _blur := 0.0
var _target_index := 0
var _tween: Tween

## Scroll position in whole strip cycles. Tweened, so it needs to be a real
## property rather than a plain variable.
var offset: float:
	set(value):
		_offset = value
		if _shader_material != null:
			_shader_material.set_shader_parameter("y_offset", value)
	get:
		return _offset

var blur_amount: float:
	set(value):
		_blur = value
		if _shader_material != null:
			_shader_material.set_shader_parameter("blur", value)
	get:
		return _blur


func setup(index: int, strip: PackedInt32Array, strip_texture: Texture2D, cell_px: int) -> void:
	reel_index = index
	_strip = strip
	_symbol.custom_minimum_size = Vector2(cell_px, cell_px)
	_hold_button.toggled.connect(_on_hold_toggled)

	# ShaderMaterial is a Resource, so every instance of this scene shares the
	# same one. Without duplicating it all reels write the same y_offset and
	# spin in perfect lockstep.
	var shared := _symbol.material as ShaderMaterial
	if shared == null:
		push_error("Reel %d has no ShaderMaterial" % index)
		return
	_shader_material = shared.duplicate() as ShaderMaterial
	_symbol.material = _shader_material

	_shader_material.set_shader_parameter("strip", strip_texture)
	_shader_material.set_shader_parameter("n_rows", float(strip.size()))

	# Start each reel on a different symbol so an idle machine does not look
	# like one image repeated.
	_target_index = randi() % maxi(1, strip.size())
	offset = float(_target_index) / float(maxi(1, strip.size()))
	blur_amount = 0.0


func is_spinning() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func current_symbol() -> int:
	if _strip.is_empty():
		return 0
	return _strip[_target_index]


## Spins to `target_index`, cruising for at least `cruise_time_min` seconds
## before the stop begins. Staggering that value is what makes the reels settle
## one after another.
func spin(target_index: int, cruise_time_min: float) -> void:
	if _strip.is_empty():
		push_error("Reel %d has no strip" % reel_index)
		return

	var length := _strip.size()
	var step := 1.0 / float(length)
	_target_index = posmod(target_index, length)

	# Everything below is in cycles per second, so phase distances can be chosen
	# to make the velocity continuous across each handoff.
	var cruise := symbols_per_second * step
	var start := fposmod(_offset, 1.0)

	# Quadratic ease-in covers half the distance a constant rate would, so this
	# distance makes the ramp end at exactly the cruise speed.
	var accel_end := start + cruise * accel_time * 0.5

	# Cubic ease-out starts at three times its average rate, so this distance
	# makes the stop begin at exactly the cruise speed.
	var decel_distance := cruise * decel_time / 3.0

	# The stop has to land on the chosen symbol, so pick the earliest congruent
	# position that still leaves room for the requested cruise.
	var earliest := accel_end + cruise * cruise_time_min + decel_distance
	var stop_at := earliest + fposmod(float(_target_index) * step - earliest, 1.0)
	while stop_at - start < minimum_revolutions:
		stop_at += 1.0

	var decel_start := stop_at - decel_distance
	var cruise_time := maxf(0.0, (decel_start - accel_end) / cruise)
	var overshoot := stop_at + overshoot_symbols * step

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "offset", accel_end, accel_time).from(start) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "blur_amount", blur_strength, accel_time)

	_tween.tween_property(self, "offset", decel_start, cruise_time) \
			.set_trans(Tween.TRANS_LINEAR)

	_tween.tween_property(self, "offset", overshoot, decel_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "blur_amount", 0.0, decel_time * 0.75)

	_tween.tween_property(self, "offset", stop_at, settle_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(_on_landed)


## Highlighting targets the symbol rather than the whole column, so the hold
## button underneath keeps its own colours.
func flash_win() -> void:
	var tween := create_tween()
	tween.tween_property(_symbol, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.12)
	tween.tween_property(_symbol, "modulate", Color.WHITE, 0.28)


func dim() -> void:
	var tween := create_tween()
	tween.tween_property(_symbol, "modulate", Color(0.45, 0.45, 0.5, 1.0), 0.2)


func clear_highlight() -> void:
	_symbol.modulate = Color.WHITE


func is_held() -> bool:
	return _hold_button.button_pressed


## Whether the player is allowed to change this reel's hold right now.
func set_hold_available(available: bool) -> void:
	_hold_button.disabled = not available


func release_hold() -> void:
	# set_pressed_no_signal avoids re-entering the machine's cap bookkeeping for
	# a change the machine itself initiated.
	_hold_button.set_pressed_no_signal(false)
	_refresh_hold_text()


func _on_hold_toggled(pressed: bool) -> void:
	_refresh_hold_text()
	hold_toggled.emit(reel_index, pressed)


func _refresh_hold_text() -> void:
	_hold_button.text = "HELD" if _hold_button.button_pressed else "HOLD"


func _on_landed() -> void:
	# Fold the offset back into a single cycle. Left unbounded it grows by a few
	# cycles every spin and loses float precision over a long session.
	offset = fposmod(_offset, 1.0)
	blur_amount = 0.0
	landed.emit(reel_index, _strip[_target_index])
