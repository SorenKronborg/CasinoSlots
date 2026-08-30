extends Control

@export_file("*.tscn") var main_menu_scene_path: String


func _ready() -> void:
	_apply_texts()


func _apply_texts() -> void:
	%English.text = tr("English")
	%French.text = tr("French")
	%German.text = tr("German")
	%Back.text = tr("Back")


func _on_english_pressed() -> void:
	_set_locale("en")


func _on_french_pressed() -> void:
	_set_locale("fr")


func _on_german_pressed() -> void:
	_set_locale("de")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)


func _set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_apply_texts()
