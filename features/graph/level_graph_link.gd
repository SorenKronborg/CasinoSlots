@tool
class_name LevelGraphLink
extends Node2D

@export var from_path: NodePath
@export var to_path: NodePath

var _frontier_lock: LevelGraphLock


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		refresh()


func from_id() -> String:
	return _note_id(from_path)


func to_id() -> String:
	return _note_id(to_path)


func is_graph_link() -> bool:
	return _note_at(to_path) is LevelNote


func from_is_note() -> bool:
	return _note_at(from_path) is LevelNote


func locks() -> Array[LevelGraphLock]:
	var result: Array[LevelGraphLock] = []
	for child in get_children():
		var lock := child as LevelGraphLock
		if lock != null:
			result.append(lock)
	return result


func set_resource_icons(icons: Dictionary) -> void:
	for lock in locks():
		var texture: Variant = icons.get(lock.unlock_resource)
		lock.set_resource_icon(texture as Texture2D)


func set_graph_visible(show_link: bool, frontier_lock: LevelGraphLock = null) -> void:
	visible = show_link
	_frontier_lock = frontier_lock
	if not show_link:
		return
	for lock in locks():
		lock.visible = lock == frontier_lock and (lock.is_locked() or lock.is_unlocking())
	refresh()


func refresh() -> void:
	var from_note := _note_at(from_path)
	var to_note := _note_at(to_path)
	if from_note == null or to_note == null:
		return
	var start := _note_center(from_note)
	var end := _note_center(to_note)
	var line := get_node_or_null("Line") as Line2D
	if line == null:
		return
	var placed := locks()
	var count := placed.size()
	for i in count:
		var t := float(i + 1) / float(count + 1)
		placed[i].position = start.lerp(end, t)
	var visible_end := end
	if not Engine.is_editor_hint() and _frontier_lock != null:
		visible_end = _frontier_lock.position
	line.points = PackedVector2Array([start, visible_end])


func _note_id(path: NodePath) -> String:
	var node := _note_at(path)
	if node == null:
		return ""
	var note := node as LevelNote
	if note != null:
		return note.note_id()
	return String(node.name)


func _note_at(path: NodePath) -> Control:
	if path.is_empty():
		return null
	return get_node_or_null(path) as Control


func _note_center(note: Control) -> Vector2:
	return to_local(note.global_position + note.size * 0.5)
