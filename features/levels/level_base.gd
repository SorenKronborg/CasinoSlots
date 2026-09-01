class_name LevelBase
extends Control

const STARTING_SPINS := 50

@export var level_definition: LevelDefinition
@export_file("*.tscn") var idle_game_scene_path: String

var level_prestige := 0
var spins_remaining := STARTING_SPINS


func _ready() -> void:
	%Back.text = tr("Back")
	%LevelGraph.load_definition(level_definition)
	%SlotMachine.spin_started.connect(_on_spin_started)
	%SlotMachine.spin_finished.connect(_on_spin_finished)
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)


func _on_spin_started() -> void:
	spins_remaining = max(spins_remaining - 1, 0)
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_spin_finished(_results: Array[int]) -> void:
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _refresh_hud() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(level_prestige)
	%SpinsLabel.text = tr("Spins")
	%SpinsValue.text = str(spins_remaining)
