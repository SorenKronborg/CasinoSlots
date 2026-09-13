extends Control

@export_file("*.tscn") var idle_game_scene_path: String
@export var card_scene: PackedScene

const CARD_SIZE := Vector2(320, 64)
const CONNECTION_WIDTH := 5.0
const ARROW_LENGTH := 14.0
const ARROW_HALF_HEIGHT := 9.0
const LOCKED_COLOR := Color(0.28, 0.3, 0.28, 1)
const UNLOCKED_COLOR := Color(1, 0.85, 0.1, 1)

var _connection_lines: Dictionary = {}
var _connection_arrows: Dictionary = {}

func _ready() -> void:
	%Back.text = tr("Back")
	_build_cards()
	_build_connections()
	refresh()


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
		card.size = CARD_SIZE
		card.setup(upgrade)
		card.purchased.connect(refresh)


func _build_connections() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		if not upgrade.has_prerequisite():
			continue
		var prerequisite := UpgradeCatalog.by_id(upgrade.prerequisite_id)
		if prerequisite == null:
			continue
		var from_point := prerequisite.graph_position + Vector2(CARD_SIZE.x, CARD_SIZE.y * 0.5)
		var to_point := upgrade.graph_position + Vector2(0, CARD_SIZE.y * 0.5)
		var line := Line2D.new()
		line.width = CONNECTION_WIDTH
		line.antialiased = true
		line.points = PackedVector2Array([from_point, to_point - Vector2(ARROW_LENGTH, 0)])
		%Connections.add_child(line)
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			to_point,
			to_point - Vector2(ARROW_LENGTH, ARROW_HALF_HEIGHT),
			to_point - Vector2(ARROW_LENGTH, -ARROW_HALF_HEIGHT),
		])
		%Connections.add_child(arrow)
		_connection_lines[upgrade.id] = line
		_connection_arrows[upgrade.id] = arrow


func _refresh_connections() -> void:
	for upgrade in UpgradeCatalog.all_upgrades():
		if not upgrade.has_prerequisite():
			continue
		var unlocked := GameState.is_upgrade_unlocked(upgrade.id)
		var color := UNLOCKED_COLOR if unlocked else LOCKED_COLOR
		var line := _connection_lines.get(upgrade.id) as Line2D
		var arrow := _connection_arrows.get(upgrade.id) as Polygon2D
		if line != null:
			line.default_color = color
		if arrow != null:
			arrow.color = color


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)
