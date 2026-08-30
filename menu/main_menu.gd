extends Control

@export var idle_game_scene: PackedScene


func _ready() -> void:
	%NewGame.text = tr("New Game")
	%LoadGame.text = tr("Load Game")
	%Options.text = tr("Options")
	%Quit.text = tr("Quit")


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_packed(idle_game_scene)
