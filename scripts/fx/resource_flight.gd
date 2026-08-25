class_name ResourceFlight
extends CanvasLayer

const TOKEN_SIZE := Vector2(26, 26)
const ICON_SIZE := Vector2(20, 20)
const FLIGHT_TIME := 0.55
const STAGGER := 0.05


func fly(kind: int, count: int, from_global: Vector2, to_global: Vector2, arrived: Callable) -> void:
	for i in count:
		var token := PanelContainer.new()
		token.custom_minimum_size = TOKEN_SIZE
		token.size = TOKEN_SIZE
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.z_index = 20
		token.pivot_offset = TOKEN_SIZE * 0.5
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.96)
		style.set_border_width_all(2)
		style.border_color = Color(1, 0.78, 0.18, 1)
		style.set_corner_radius_all(13)
		style.set_content_margin_all(3)
		token.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.texture = Symbols.texture(kind)
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.add_child(icon)
		var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		token.global_position = from_global - TOKEN_SIZE * 0.5 + jitter
		add_child(token)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(i) * STAGGER)
		tween.tween_property(token, "global_position", to_global - TOKEN_SIZE * 0.5, FLIGHT_TIME) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(token, "scale", Vector2(0.75, 0.75), FLIGHT_TIME)
		tween.tween_callback(func() -> void:
			arrived.call()
			token.queue_free()
		)
