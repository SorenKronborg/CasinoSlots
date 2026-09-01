extends Control

@export var idle_game_scene: PackedScene
@export var options_scene: PackedScene


func _ready() -> void:
	%NewGame.text = tr("New Game")
	%ContinueGame.text = tr("Continue Game")
	%ContinueGame.disabled = not GameState.has_save()
	%Options.text = tr("Options")
	%Quit.text = tr("Quit")


func _on_new_game_pressed() -> void:
	GameState.reset()
	get_tree().change_scene_to_packed(idle_game_scene)


func _on_continue_game_pressed() -> void:
	var err := GameState.load_game()
	if err != OK:
		push_error("Failed to continue game: %s" % error_string(err))
		%ContinueGame.disabled = not GameState.has_save()
		return
	get_tree().change_scene_to_packed(idle_game_scene)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_packed(options_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
