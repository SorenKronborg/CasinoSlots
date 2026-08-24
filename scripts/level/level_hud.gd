class_name LevelHud
extends PanelContainer

const HEART_TEXTURE := preload("res://assets/icons/heart.png")
const COIN_TEXTURE := preload("res://assets/icons/coin.png")

var _coins_label: Label
var _prestige_label: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.2, 0.2, 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_coins_label = _add_stat(row, COIN_TEXTURE)
	_prestige_label = _add_stat(row, HEART_TEXTURE)
	refresh(null)


func refresh(state: RunState) -> void:
	if _coins_label == null:
		return
	if state == null:
		_coins_label.text = "0"
		_prestige_label.text = "0"
		return
	_coins_label.text = str(state.coins)
	_prestige_label.text = str(state.prestige)


func _add_stat(row: HBoxContainer, texture: Texture2D) -> Label:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = "0"
	label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	return label
