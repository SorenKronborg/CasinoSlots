class_name LevelGraph
extends Control

signal node_clicked(node_id: String)

var _notes_by_id: Dictionary = {}
var _links: Array[LevelGraphLink] = []
var _note_order: Array[LevelNote] = []


func _ready() -> void:
	_collect()
	for note in _note_order:
		note.pressed.connect(_on_node_pressed.bind(note.note_id()))
	_refresh_links()
	_refresh_node_access()
	resized.connect(_refresh_links)


func set_resource_icons(icons: Dictionary) -> void:
	for link in _links:
		link.set_resource_icons(icons)


func deposit_into(node_id: String, available_coins: int) -> Vector2i:
	if not _notes_by_id.has(node_id):
		return Vector2i.ZERO
	var note := _notes_by_id[node_id] as LevelNote
	return note.deposit(available_coins)


func apply_resources(gained: Dictionary) -> int:
	var leftover_total := 0
	for resource in gained:
		var remaining := int(gained[resource])
		if remaining <= 0:
			continue
		for link in _links:
			remaining = link.contribute(resource, remaining)
		leftover_total += remaining
	var prestige := 0
	var reachable := _reachable_ids()
	for note in _note_order:
		if not bool(reachable.get(note.note_id(), false)):
			continue
		var fed: Vector2i = note.feed_leftover(leftover_total)
		leftover_total -= fed.x
		prestige += fed.y
		if leftover_total <= 0:
			break
	_refresh_node_access()
	return prestige


func _collect() -> void:
	_notes_by_id.clear()
	_note_order.clear()
	_links.clear()
	for child in %Nodes.get_children():
		var note := child as LevelNote
		if note == null:
			continue
		_note_order.append(note)
		_notes_by_id[note.note_id()] = note
	for child in %Edges.get_children():
		var link := child as LevelGraphLink
		if link == null:
			continue
		_links.append(link)


func _reachable_ids() -> Dictionary:
	var reachable: Dictionary = {}
	var has_incoming: Dictionary = {}
	for link in _links:
		if link.to_id() == "":
			continue
		has_incoming[link.to_id()] = true
	var queue: Array[String] = []
	for note in _note_order:
		var node_id := note.note_id()
		if has_incoming.get(node_id, false):
			continue
		reachable[node_id] = true
		queue.append(node_id)
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		for link in _links:
			if not link.is_fully_unlocked() or link.from_id() != node_id:
				continue
			var to_id := link.to_id()
			if to_id == "" or reachable.get(to_id, false):
				continue
			reachable[to_id] = true
			queue.append(to_id)
	return reachable


func _refresh_node_access() -> void:
	var reachable := _reachable_ids()
	for note in _note_order:
		note.set_reachable(bool(reachable.get(note.note_id(), false)))


func _refresh_links() -> void:
	for link in _links:
		link.refresh()


func _on_node_pressed(node_id: String) -> void:
	node_clicked.emit(node_id)
