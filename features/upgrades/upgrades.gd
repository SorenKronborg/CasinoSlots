extends Control

@export_file("*.tscn") var idle_game_scene_path: String


func _ready() -> void:
	%Back.text = tr("Back")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)
