extends Control

## Title screen. Only New Game is functional; the rest are present but disabled
## until there is a save system and an options screen to point them at.

const GAME_SCENE := "res://scenes/game/game.tscn"

@onready var _new_game_button: Button = %NewGameButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	# Gives the menu keyboard and gamepad navigation from the first frame.
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
