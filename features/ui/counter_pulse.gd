class_name CounterPulse
extends RefCounted

const PEAK_SCALE := 3.0
const GROW_SECONDS := 0.07
const SHRINK_SECONDS := 0.11


static func play(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	var existing: Variant = control.get_meta("counter_pulse_tween", null)
	if existing is Tween:
		(existing as Tween).kill()
	control.scale = Vector2.ONE
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE * PEAK_SCALE, GROW_SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, SHRINK_SECONDS).set_ease(Tween.EASE_IN_OUT)
	control.set_meta("counter_pulse_tween", tween)
