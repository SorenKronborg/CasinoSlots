class_name LevelGraphNode
extends Button

var node_id: String = ""
var normalized_position: Vector2 = Vector2(0.5, 0.5)


func setup(spec: LevelNodeSpec) -> void:
	node_id = spec.id
	normalized_position = spec.normalized_position
	text = spec.label
