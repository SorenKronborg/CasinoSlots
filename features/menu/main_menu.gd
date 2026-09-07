extends Control

const HOVER_SCALE := 1.15
const HOVER_SECONDS := 0.5

@export var idle_game_scene: PackedScene
@export var options_scene: PackedScene

var _hover_tweens: Dictionary = {}


func _ready() -> void:
	%NewGame.text = tr("New Game")
	%ContinueGame.text = tr("Continue Game")
	%ContinueGame.disabled = not GameState.has_save()
	%Options.text = tr("Options")
	%Quit.text = tr("Quit")
	for child in $Center/Buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		button.resized.connect(_center_pivot.bind(button))
		button.mouse_entered.connect(_tween_menu_button.bind(button, true))
		button.mouse_exited.connect(_tween_menu_button.bind(button, false))
		_center_pivot(button)


func _center_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _tween_menu_button(button: Button, hovering: bool) -> void:
	if hovering and button.disabled:
		return
	var existing: Variant = _hover_tweens.get(button)
	if existing is Tween:
		(existing as Tween).kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var target := Vector2.ONE * HOVER_SCALE if hovering else Vector2.ONE
	tween.tween_property(button, "scale", target, HOVER_SECONDS)
	_hover_tweens[button] = tween


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
