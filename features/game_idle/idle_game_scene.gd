extends Control

@export var upgrades_scene: PackedScene


func _ready() -> void:
	%Upgrades.text = tr("Upgrades")
	%Mission1.text = tr("Mission 1")
	%Mission2.text = tr("Mission 2")
	%Mission3.text = tr("Mission 3")
	%Mission4.text = tr("Mission 4")


func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_packed(upgrades_scene)
