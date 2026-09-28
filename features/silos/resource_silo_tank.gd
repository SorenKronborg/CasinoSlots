class_name ResourceSiloTank
extends Panel

const TANK_SIZE := Vector2(34, 64)
const BORDER := 3.0
const FILL_SECONDS := 0.16

var _color := Color.WHITE
var _shown_ratio := 0.0
var _fill_tween: Tween

@onready var _fill: ColorRect = $Fill
@onready var _amount: Label = $Amount


func _ready() -> void:
	custom_minimum_size = TANK_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place_fill)
	_apply_style()
	_place_fill()


func setup(color: Color) -> void:
	_color = color
	if is_node_ready():
		_apply_style()


func set_fill(stored: int, capacity: int, animate: bool) -> void:
	var shown := maxi(stored, 0)
	var room := maxi(capacity, 0)
	_amount.text = "%d/%d" % [shown, room]
	var ratio := 0.0
	if room > 0:
		ratio = clampf(float(shown) / float(room), 0.0, 1.0)
	_animate_ratio(ratio, animate)


func _apply_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.BLACK
	box.border_color = _color
	box.set_border_width_all(int(BORDER))
	add_theme_stylebox_override("panel", box)
	_fill.color = _color


func _animate_ratio(ratio: float, animate: bool) -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	if not animate:
		_set_shown_ratio(ratio)
		return
	_fill_tween = create_tween()
	_fill_tween.tween_method(_set_shown_ratio, _shown_ratio, ratio, FILL_SECONDS)


func _set_shown_ratio(ratio: float) -> void:
	_shown_ratio = ratio
	_place_fill()


func _place_fill() -> void:
	var inner_height := maxf(size.y - BORDER * 2.0, 0.0)
	var fill_height := inner_height * _shown_ratio
	_fill.anchor_left = 0.0
	_fill.anchor_right = 1.0
	_fill.anchor_top = 1.0
	_fill.anchor_bottom = 1.0
	_fill.offset_left = BORDER
	_fill.offset_right = -BORDER
	_fill.offset_bottom = -BORDER
	_fill.offset_top = -BORDER - fill_height
	_fill.visible = fill_height > 0.0
