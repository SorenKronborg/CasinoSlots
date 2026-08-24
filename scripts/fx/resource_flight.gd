class_name ResourceFlight
extends CanvasLayer

const ICON_SIZE := Vector2(32, 32)
const FLIGHT_TIME := 0.55
const STAGGER := 0.05


func fly(kind: int, count: int, from_global: Vector2, to_global: Vector2, arrived: Callable) -> void:
	for i in count:
		var icon := TextureRect.new()
		icon.texture = Symbols.texture(kind)
		icon.custom_minimum_size = ICON_SIZE
		icon.size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 20
		var jitter := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		icon.global_position = from_global - ICON_SIZE * 0.5 + jitter
		add_child(icon)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(i) * STAGGER)
		tween.tween_property(icon, "global_position", to_global - ICON_SIZE * 0.5, FLIGHT_TIME) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(icon, "scale", Vector2(0.7, 0.7), FLIGHT_TIME)
		tween.tween_callback(func() -> void:
			arrived.call()
			icon.queue_free()
		)
