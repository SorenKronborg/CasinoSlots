extends Control

@export_file("*.tscn") var idle_game_scene_path: String
@export var card_scene: PackedScene

const CONNECTION_WIDTH := 3.0
const ARROW_LENGTH := 14.0
const ARROW_HALF_HEIGHT := 9.0
const LOCKED_COLOR := Color(0.28, 0.3, 0.28, 1)
const UNLOCKED_COLOR := Color(1, 0.85, 0.1, 1)

var _cards_by_id: Dictionary = {}
var _connection_lines: Dictionary = {}
var _connection_arrows: Dictionary = {}


func _ready() -> void:
	%Back.text = tr("Back")
	_build_cards()
	_build_connections()
	refresh()
	_refresh_connections.call_deferred()


func refresh() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(GameState.prestige())
	for child in %Cards.get_children():
		var card := child as UpgradeCard
		if card == null:
			continue
		card.refresh()
	_refresh_connections()


func _build_cards() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		var card := card_scene.instantiate() as UpgradeCard
		%Cards.add_child(card)
		card.position = upgrade.graph_position
		card.setup(upgrade)
		card.purchased.connect(refresh)
		_cards_by_id[upgrade.id] = card


func _build_connections() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		if not upgrade.has_prerequisite() or not _cards_by_id.has(upgrade.prerequisite_id):
			continue
		var line := Line2D.new()
		line.width = CONNECTION_WIDTH
		line.antialiased = true
		%Connections.add_child(line)
		var arrow := Polygon2D.new()
		%Connections.add_child(arrow)
		_connection_lines[upgrade.id] = line
		_connection_arrows[upgrade.id] = arrow


func _refresh_connections() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		if _connection_lines.has(upgrade.id):
			_draw_connection(upgrade)


func _draw_connection(upgrade: UpgradeDefinition) -> void:
	var from_card := _cards_by_id[upgrade.prerequisite_id] as UpgradeCard
	var to_card := _cards_by_id[upgrade.id] as UpgradeCard
	var from_point := from_card.position + Vector2(from_card.size.x, from_card.size.y * 0.5)
	var to_point := to_card.position + Vector2(0.0, to_card.size.y * 0.5)
	var color := UNLOCKED_COLOR if GameState.is_upgrade_unlocked(upgrade.id) else LOCKED_COLOR
	var line := _connection_lines[upgrade.id] as Line2D
	line.default_color = color
	line.points = PackedVector2Array([from_point, to_point - Vector2(ARROW_LENGTH, 0.0)])
	var arrow := _connection_arrows[upgrade.id] as Polygon2D
	arrow.color = color
	arrow.polygon = PackedVector2Array([
		to_point,
		to_point - Vector2(ARROW_LENGTH, ARROW_HALF_HEIGHT),
		to_point - Vector2(ARROW_LENGTH, -ARROW_HALF_HEIGHT),
	])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)
