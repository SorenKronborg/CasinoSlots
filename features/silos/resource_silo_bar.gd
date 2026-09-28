class_name ResourceSiloBar
extends HBoxContainer

const TANK_SCENE := preload("res://features/silos/resource_silo_tank.tscn")
const ICON_SIZE := 20.0

var _icons: Dictionary = {}
var _tanks: Dictionary = {}
var _incoming: Dictionary = {}


func _ready() -> void:
	visible = GameState.has_resource_silos()
	if not visible:
		return
	for resource_id in GameResources.all():
		_add_column(resource_id)
		_refresh_tank(resource_id, false)


func set_icons(icons: Dictionary) -> void:
	for resource_id in _icons:
		var icon := _icons[resource_id] as TextureRect
		icon.texture = icons.get(resource_id) as Texture2D


func tank_center(resource_id: StringName) -> Vector2:
	var tank := _tanks.get(resource_id) as ResourceSiloTank
	if tank == null:
		return get_global_rect().get_center()
	return tank.get_global_rect().get_center()


func note_incoming(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_incoming[resource_id] = int(_incoming.get(resource_id, 0)) + amount
	_refresh_tank(resource_id, false)


func refresh_resource(resource_id: StringName) -> void:
	_refresh_tank(resource_id, true)


func note_arrived(resource_id: StringName) -> void:
	var still_flying := int(_incoming.get(resource_id, 0)) - 1
	if still_flying <= 0:
		_incoming.erase(resource_id)
	else:
		_incoming[resource_id] = still_flying
	_refresh_tank(resource_id, true)


func _add_column(resource_id: StringName) -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var tank := TANK_SCENE.instantiate() as ResourceSiloTank
	column.add_child(tank)
	tank.setup(GameResources.color_of(resource_id))
	add_child(column)
	_icons[resource_id] = icon
	_tanks[resource_id] = tank


func _refresh_tank(resource_id: StringName, animate: bool) -> void:
	var tank := _tanks.get(resource_id) as ResourceSiloTank
	if tank == null:
		return
	var shown := GameState.silo_stored(resource_id) - int(_incoming.get(resource_id, 0))
	tank.set_fill(shown, GameState.silo_capacity(resource_id), animate)
