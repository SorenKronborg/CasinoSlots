class_name LevelGraph
extends Control

const TOKEN_SCENE := preload("res://features/graph/resource_token.tscn")

signal node_clicked(node_id: String)
signal prestige_earned(amount: int)

@export var token_size := 28.0
@export var token_speed := 275.0
@export var token_spacing := 36.0

var _notes_by_id: Dictionary = {}
var _links: Array[LevelGraphLink] = []
var _graph_links: Array[LevelGraphLink] = []
var _note_order: Array[LevelNote] = []
var _resource_icons: Dictionary = {}
var _in_flight: Dictionary = {}


class Delivery:
	var resource: StringName = &""
	var target: Node
	var points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_collect()
	for note in _note_order:
		note.pressed.connect(_on_node_pressed.bind(note.note_id()))
	_refresh_links()
	_refresh_node_access()
	resized.connect(_refresh_links)
	_refresh_links.call_deferred()


func set_resource_icons(icons: Dictionary) -> void:
	_resource_icons = icons
	for link in _links:
		link.set_resource_icons(icons)


func deposit_into(node_id: String, available_coins: int) -> Vector2i:
	if not _notes_by_id.has(node_id):
		return Vector2i.ZERO
	var note := _notes_by_id[node_id] as LevelNote
	return note.deposit(available_coins)


func apply_resources(gained: Dictionary) -> void:
	_refresh_links()
	var deliveries: Array[Delivery] = []
	var planned: Dictionary = {}
	for resource in gained:
		var resource_id := resource as StringName
		var remaining := int(gained[resource])
		while remaining > 0:
			var lock := _next_lock_for(resource_id, planned)
			if lock == null:
				break
			remaining -= _plan_into_lock(lock, resource_id, remaining, planned, deliveries)
		_plan_into_silos(resource_id, remaining, planned, deliveries)
	for target in planned:
		_in_flight[target] = int(_in_flight.get(target, 0)) + int(planned[target])
	_play_deliveries(deliveries)


func _next_lock_for(resource: StringName, planned: Dictionary) -> LevelGraphLock:
	var reachable := _reachable_ids(planned)
	for link in _graph_links:
		if not bool(reachable.get(link.from_id(), false)):
			continue
		var lock := _front_lock(link, planned)
		if lock != null and lock.unlock_resource == resource:
			return lock
	return null


func _front_lock(link: LevelGraphLink, planned: Dictionary) -> LevelGraphLock:
	for lock in link.locks():
		if lock.collected + _incoming(lock, planned) < lock.unlock_cost:
			return lock
	return null


func _plan_into_lock(
		lock: LevelGraphLock,
		resource: StringName,
		remaining: int,
		planned: Dictionary,
		deliveries: Array[Delivery]
) -> int:
	var extra := _incoming(lock, planned)
	var used := mini(remaining, lock.unlock_cost - lock.collected - extra)
	_add_deliveries(resource, lock, used, _path_to_lock(lock), planned, deliveries)
	return used


func _plan_into_silos(
		resource: StringName,
		remaining: int,
		planned: Dictionary,
		deliveries: Array[Delivery]
) -> void:
	var reachable := _reachable_ids(planned)
	for note in _note_order:
		if remaining <= 0:
			return
		if not bool(reachable.get(note.note_id(), false)):
			continue
		var free_space := note.remaining_capacity() - _incoming(note, planned)
		if free_space <= 0:
			continue
		var used := mini(remaining, free_space)
		_add_deliveries(resource, note, used, _path_to_note(note), planned, deliveries)
		remaining -= used


func _add_deliveries(
		resource: StringName,
		target: Node,
		amount: int,
		path: PackedVector2Array,
		planned: Dictionary,
		deliveries: Array[Delivery]
) -> void:
	if amount <= 0:
		return
	planned[target] = int(planned.get(target, 0)) + amount
	for _i in amount:
		var delivery := Delivery.new()
		delivery.resource = resource
		delivery.target = target
		delivery.points = path
		deliveries.append(delivery)


func _incoming(target: Node, planned: Dictionary) -> int:
	return int(_in_flight.get(target, 0)) + int(planned.get(target, 0))


func _play_deliveries(deliveries: Array[Delivery]) -> void:
	if deliveries.is_empty():
		return
	var spawned_on_target: Dictionary = {}
	for delivery in deliveries:
		var index := int(spawned_on_target.get(delivery.target, 0))
		spawned_on_target[delivery.target] = index + 1
		var delay := 0.0
		if token_speed > 0.0:
			delay = float(index) * token_spacing / token_speed
		var token := TOKEN_SCENE.instantiate() as ResourceToken
		%Tokens.add_child(token)
		token.arrived.connect(
				_on_token_arrived.bind(delivery.target, delivery.resource),
				CONNECT_ONE_SHOT
		)
		var icon: Texture2D = _resource_icons.get(delivery.resource) as Texture2D
		token.begin(delivery.points, token_speed, icon, token_size, delay)


func _on_token_arrived(target: Node, resource: StringName) -> void:
	if not is_instance_valid(target):
		return
	_in_flight[target] = maxi(int(_in_flight.get(target, 0)) - 1, 0)
	if int(_in_flight[target]) <= 0:
		_in_flight.erase(target)
	var lock := target as LevelGraphLock
	if lock != null:
		lock.contribute(resource, 1)
	var note := target as LevelNote
	if note != null:
		var fed: Vector2i = note.feed_leftover(1)
		if fed.y > 0:
			prestige_earned.emit(fed.y)
	_refresh_node_access()


func _path_to_lock(lock: LevelGraphLock) -> PackedVector2Array:
	var owner_link := lock.get_parent() as LevelGraphLink
	if owner_link == null:
		return PackedVector2Array()
	var chain := _links_to_owner(_flow_start_id(), owner_link)
	var points := PackedVector2Array()
	for i in chain.size():
		var link_points := _link_points_in_graph(chain[i])
		if i == chain.size() - 1:
			link_points = _polyline_until(link_points, _to_graph_local(lock.global_position))
		_append_polyline(points, link_points)
	return points


func _path_to_note(note: LevelNote) -> PackedVector2Array:
	var final_link := _link_into(note.note_id())
	if final_link == null:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for link in _links_to_owner(_flow_start_id(), final_link):
		_append_polyline(points, _link_points_in_graph(link))
	return points


func _link_into(node_id: String) -> LevelGraphLink:
	for link in _graph_links:
		if link.to_id() == node_id:
			return link
	return null


func _flow_start_id() -> String:
	for link in _graph_links:
		if not link.from_is_note():
			return link.from_id()
	return ""


func _links_to_owner(start_id: String, owner_link: LevelGraphLink) -> Array[LevelGraphLink]:
	if start_id == "" or start_id == owner_link.from_id():
		return [owner_link]
	var visited: Dictionary = {start_id: true}
	var came_via: Dictionary = {}
	var queue: Array[String] = [start_id]
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		if node_id == owner_link.from_id():
			break
		for link in _graph_links:
			if link.from_id() != node_id:
				continue
			var to_id := link.to_id()
			if to_id == "" or visited.get(to_id, false):
				continue
			visited[to_id] = true
			came_via[to_id] = link
			queue.append(to_id)
	var reversed: Array[LevelGraphLink] = []
	var cursor := owner_link.from_id()
	while came_via.has(cursor):
		var via: LevelGraphLink = came_via[cursor]
		reversed.append(via)
		cursor = via.from_id()
	reversed.reverse()
	reversed.append(owner_link)
	return reversed


func _link_points_in_graph(link: LevelGraphLink) -> PackedVector2Array:
	link.refresh()
	var line := link.get_node_or_null("Line") as Line2D
	var points := PackedVector2Array()
	if line == null:
		return points
	for point in line.points:
		points.append(_to_graph_local(link.to_global(point)))
	return points


func _to_graph_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _append_polyline(into: PackedVector2Array, extra: PackedVector2Array) -> void:
	for i in extra.size():
		var point := extra[i]
		if not into.is_empty() and i == 0 and into[into.size() - 1].distance_to(point) < 1.0:
			continue
		into.append(point)


func _polyline_until(points: PackedVector2Array, target: Vector2) -> PackedVector2Array:
	var trimmed := PackedVector2Array()
	if points.is_empty():
		trimmed.append(target)
		return trimmed
	trimmed.append(points[0])
	for i in range(1, points.size()):
		var from_point := points[i - 1]
		var to_point := points[i]
		var along := to_point - from_point
		var length_sq := along.length_squared()
		if length_sq <= 0.0001:
			continue
		var t := (target - from_point).dot(along) / length_sq
		if t >= 0.0 and t <= 1.0:
			trimmed.append(from_point.lerp(to_point, t))
			return trimmed
		trimmed.append(to_point)
	trimmed.append(target)
	return trimmed


func _collect() -> void:
	_notes_by_id.clear()
	_note_order.clear()
	_links.clear()
	_graph_links.clear()
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
		if link.is_graph_link():
			_graph_links.append(link)


func _reachable_ids(planned: Dictionary = {}) -> Dictionary:
	var reachable: Dictionary = {}
	var has_incoming: Dictionary = {}
	for link in _graph_links:
		if link.to_id() == "":
			continue
		has_incoming[link.to_id()] = true
	var queue: Array[String] = []
	for link in _graph_links:
		if link.from_is_note():
			continue
		var start_id := link.from_id()
		if start_id == "" or reachable.get(start_id, false):
			continue
		reachable[start_id] = true
		queue.append(start_id)
	for note in _note_order:
		var node_id := note.note_id()
		if has_incoming.get(node_id, false):
			continue
		reachable[node_id] = true
		queue.append(node_id)
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		for link in _graph_links:
			if link.from_id() != node_id or _front_lock(link, planned) != null:
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
