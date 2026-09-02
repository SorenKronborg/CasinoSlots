class_name LevelBase
extends Control

const STARTING_SPINS := 50

@export var level_definition: LevelDefinition
@export_file("*.tscn") var idle_game_scene_path: String

var level_prestige := 0
var level_coins := 0
var spins_remaining := STARTING_SPINS

var _winnings := Winnings.new()


func _ready() -> void:
	%Back.text = tr("Back")
	%LevelGraph.load_definition(level_definition)
	%LevelGraph.set_resource_icons(%SlotMachine.symbol_icon_map())
	%LevelGraph.node_clicked.connect(_on_node_clicked)
	%SlotMachine.spin_started.connect(_on_spin_started)
	%SlotMachine.spin_finished.connect(_on_spin_finished)
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)


func _on_spin_started() -> void:
	spins_remaining = maxi(spins_remaining - 1, 0)
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_node_clicked(node_id: String) -> void:
	var graph := %LevelGraph as LevelGraph
	var result: Vector2i = graph.deposit_into(node_id, level_coins)
	level_coins -= result.x
	level_prestige += result.y
	_refresh_hud()


func _on_spin_finished(results: Array[StringName]) -> void:
	var payout: Winnings.Result = _winnings.evaluate(results)
	level_coins += payout.coins
	%LevelGraph.apply_resources(payout.resources)
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _refresh_hud() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(level_prestige)
	%CoinsLabel.text = tr("Coins")
	%CoinsValue.text = str(level_coins)
	%SpinsLabel.text = tr("Spins")
	%SpinsValue.text = str(spins_remaining)
