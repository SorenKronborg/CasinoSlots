class_name LevelGraphEdge
extends Node2D

var from_node: Control
var to_node: Control
var locked: bool = false


func setup(from: Control, to: Control, is_locked: bool) -> void:
	from_node = from
	to_node = to
	locked = is_locked
	%Lock.visible = locked
	refresh()


func refresh() -> void:
	if from_node == null or to_node == null:
		return
	var start := from_node.position + from_node.size * 0.5
	var end := to_node.position + to_node.size * 0.5
	%Line.points = PackedVector2Array([start, end])
	%Lock.position = (start + end) * 0.5
