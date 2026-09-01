extends Control

@export var upgrades_scene: PackedScene
@export var level_scene: PackedScene
@export var mission_1_definition: LevelDefinition
@export var mission_2_definition: LevelDefinition

var resources: Dictionary = {
	"prestige": 5,
}


func _ready() -> void:
	%Upgrades.text = tr("Upgrades")
	%Mission1.text = tr("Mission 1")
	%Mission2.text = tr("Mission 2")
	%Mission3.text = tr("Mission 3")
	%Mission4.text = tr("Mission 4")
	_refresh_resource_info()


func _refresh_resource_info() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(resources["prestige"])


func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_packed(upgrades_scene)


func _on_mission_1_pressed() -> void:
	_open_level(mission_1_definition)


func _on_mission_2_pressed() -> void:
	_open_level(mission_2_definition)


func _open_level(definition: LevelDefinition) -> void:
	var level := level_scene.instantiate() as LevelBase
	level.level_definition = definition
	var tree := get_tree()
	tree.root.add_child(level)
	tree.current_scene.queue_free()
	tree.current_scene = level
