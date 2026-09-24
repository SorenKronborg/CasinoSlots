class_name LevelGraph
extends Control

signal node_clicked(node_id: String)
signal prestige_earned(amount: int, from_global_position: Vector2)
signal coin_stolen(amount: int)

const TOKEN_SCENE := preload("res://features/graph/resource_token.tscn")
const FIREWALL_ATTACK_ICON := preload("res://assets/icons/firewall_attack.svg")
const FIREWALL_ATTACK_COUNT := 3
const FIREWALL_ATTACK_SIZE := 22.0
const FIREWALL_ATTACK_SPEED_SCALE := 0.85
const COLLISION_DISTANCE := 18.0

@export var token_size := 28.0
@export var token_speed := 275.0
@export var token_spacing := 36.0

var _notes_by_id: Dictionary = {}
var _links: Array[LevelGraphLink] = []
var _graph_links: Array[LevelGraphLink] = []
var _note_order: Array[LevelNote] = []
var _resource_icons: Dictionary = {}
var _in_flight: Dictionary = {}
var _owned_keys: Dictionary = {}
var _firewalls: Array[LevelGraphFirewall] = []
var _active_resource_tokens: Dictionary = {}
var _active_attacks: Dictionary = {}


class Delivery:
	var resource: StringName = &""
	var target: Node
	var segments: Array[PackedVector2Array] = []
	var stage := 0


func _ready() -> void:
	_collect()
	for note in _note_order:
		note.pressed.connect(_on_node_pressed.bind(note.note_id()))
		note.captured.connect(_on_note_captured)
	_connect_locks()
	_refresh_links()
	_refresh_graph_state()
	resized.connect(_on_graph_resized)
	_on_graph_resized.call_deferred()


func notes() -> Array[LevelNote]:
	return _note_order


func set_resource_icons(icons: Dictionary) -> void:
	_resource_icons = icons
	for link in _links:
		link.set_resource_icons(icons)
	for firewall in _firewalls:
		firewall.set_resource_icon(icons.get(firewall.vulnerable_resource) as Texture2D)


func deposit_into(node_id: String, available_coins: int) -> int:
	if not _notes_by_id.has(node_id):
		return 0
	var note := _notes_by_id[node_id] as LevelNote
	var spent_and_earned := note.deposit(available_coins)
	if spent_and_earned.y > 0:
		prestige_earned.emit(spent_and_earned.y, _note_center_global(note))
	return spent_and_earned.x


func _note_center_global(note: LevelNote) -> Vector2:
	return note.get_global_rect().get_center()


func apply_resources(gained: Dictionary) -> void:
	_refresh_links()
	var deliveries: Array[Delivery] = []
	var planned: Dictionary = {}
	for resource in gained:
		var resource_id := resource as StringName
		var remaining := int(gained[resource])
		while remaining > 0:
			var firewall := _next_firewall_for(resource_id, planned)
			if firewall == null:
				break
			remaining -= _plan_into_firewall(
					firewall, resource_id, remaining, planned, deliveries
			)
		while remaining > 0:
			var lock := _next_lock_for(resource_id, planned)
			if lock == null:
				break
			remaining -= _plan_into_lock(lock, resource_id, remaining, planned, deliveries)
		_plan_into_silos(resource_id, remaining, planned, deliveries)
	for target in planned:
		_in_flight[target] = int(_in_flight.get(target, 0)) + int(planned[target])
	_play_deliveries(deliveries)


func launch_firewall_attacks() -> void:
	for firewall in _firewalls:
		if not firewall.is_active() or not firewall.visible:
			continue
		var note := firewall.host_note()
		if note == null or not note.visible:
			continue
		var path := _path_to_note(note, {})
		path.reverse()
		for index in FIREWALL_ATTACK_COUNT:
			_spawn_firewall_attack(
					firewall,
					path,
					float(index) * token_spacing / maxf(token_speed, 1.0)
			)


func _spawn_firewall_attack(
		firewall: LevelGraphFirewall,
		path: PackedVector2Array,
		delay: float
) -> void:
	var attack := TOKEN_SCENE.instantiate() as ResourceToken
	%Tokens.add_child(attack)
	_active_attacks[attack] = firewall
	attack.arrived.connect(_on_attack_arrived.bind(attack), CONNECT_ONE_SHOT)
	attack.cancelled.connect(_on_attack_cancelled.bind(attack), CONNECT_ONE_SHOT)
	attack.begin(
			path,
			token_speed * FIREWALL_ATTACK_SPEED_SCALE,
			FIREWALL_ATTACK_ICON,
			FIREWALL_ATTACK_SIZE,
			delay
	)


func _on_attack_arrived(attack: ResourceToken) -> void:
	_active_attacks.erase(attack)
	coin_stolen.emit(1)


func _on_attack_cancelled(attack: ResourceToken) -> void:
	_active_attacks.erase(attack)


func _process(_delta: float) -> void:
	for attack_node in _active_attacks.keys():
		var attack := attack_node as ResourceToken
		if attack == null or not is_instance_valid(attack) or not attack.is_travelling():
			continue
		var firewall := _active_attacks.get(attack) as LevelGraphFirewall
		if firewall == null:
			continue
		for token_node in _active_resource_tokens.keys():
			var token := token_node as ResourceToken
			if token == null or not is_instance_valid(token) or not token.is_travelling():
				continue
			if token.resource_id == firewall.vulnerable_resource:
				continue
			if token.global_position.distance_to(attack.global_position) > COLLISION_DISTANCE:
				continue
			token.cancel()
			attack.cancel()
			break


func _next_firewall_for(
		resource: StringName,
	planned: Dictionary
) -> LevelGraphFirewall:
	var reachable := _reachable_ids(planned)
	for firewall in _firewalls:
		var note := firewall.host_note()
		if note == null or not bool(reachable.get(note.note_id(), false)):
			continue
		if firewall.can_accept(resource) and firewall.remaining() > _incoming(firewall, planned):
			return firewall
	return null


func _plan_into_firewall(
		firewall: LevelGraphFirewall,
		resource: StringName,
	remaining: int,
	planned: Dictionary,
	deliveries: Array[Delivery]
) -> int:
	var note := firewall.host_note()
	if note == null:
		return 0
	var segments := _segments_to_note(note, planned)
	var multiplier := _segment_multiplier(segments)
	var free_space := firewall.remaining() - _incoming(firewall, planned)
	var used := mini(remaining, ceili(float(free_space) / float(multiplier)))
	_add_deliveries(
			resource,
			firewall,
			used,
			used * multiplier,
			segments,
			planned,
			deliveries
	)
	return used


func _next_lock_for(resource: StringName, planned: Dictionary) -> LevelGraphLock:
	var reachable := _reachable_ids(planned)
	for link in _graph_links:
		if not bool(reachable.get(link.from_id(), false)):
			continue
		if _is_opening(link):
			continue
		var lock := _front_lock(link, planned)
		if lock != null and lock.can_accept(resource):
			return lock
	return null


func _connect_locks() -> void:
	for link in _links:
		for lock in link.locks():
			lock.unlock_finished.connect(_on_lock_finished.bind(lock))


func _is_opening(link: LevelGraphLink) -> bool:
	for lock in link.locks():
		if lock.is_unlocking():
			return true
	return false


func _front_lock(link: LevelGraphLink, planned: Dictionary) -> LevelGraphLock:
	for lock in link.locks():
		if not lock.is_locked() and not lock.is_unlocking():
			continue
		if not lock.can_accept(lock.unlock_resource):
			return lock
		if lock.collected + _incoming(lock, planned) < lock.unlock_cost:
			return lock
	return null


func _frontier_lock(link: LevelGraphLink) -> LevelGraphLock:
	for lock in link.locks():
		if lock.is_locked():
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
	var free_space := lock.unlock_cost - lock.collected - extra
	var segments := _segments_to_lock(lock, planned)
	var multiplier := _segment_multiplier(segments)
	var used := mini(remaining, ceili(float(free_space) / float(multiplier)))
	_add_deliveries(resource, lock, used, used * multiplier, segments, planned, deliveries)
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
		var segments := _segments_to_note(note, planned)
		var multiplier := _segment_multiplier(segments)
		var used := remaining
		if not note.accepts_repeating_resources():
			var free_space := note.remaining_capacity() - _incoming(note, planned)
			if free_space <= 0:
				continue
			used = mini(remaining, ceili(float(free_space) / float(multiplier)))
		_add_deliveries(
				resource,
				note,
				used,
				used * multiplier,
				segments,
				planned,
				deliveries
		)
		remaining -= used


func _add_deliveries(
		resource: StringName,
		target: Node,
		source_amount: int,
		final_amount: int,
		segments: Array[PackedVector2Array],
		planned: Dictionary,
		deliveries: Array[Delivery]
) -> void:
	if source_amount <= 0 or segments.is_empty():
		return
	planned[target] = int(planned.get(target, 0)) + final_amount
	for _i in source_amount:
		var delivery := Delivery.new()
		delivery.resource = resource
		delivery.target = target
		delivery.segments = segments
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
		_spawn_delivery_stage(delivery, delay)


func _spawn_delivery_stage(delivery: Delivery, delay: float = 0.0) -> void:
	if delivery.stage < 0 or delivery.stage >= delivery.segments.size():
		return
	var token := TOKEN_SCENE.instantiate() as ResourceToken
	%Tokens.add_child(token)
	_active_resource_tokens[token] = delivery
	token.arrived.connect(
			_on_delivery_token_arrived.bind(token, delivery),
			CONNECT_ONE_SHOT
	)
	token.cancelled.connect(
			_on_delivery_token_cancelled.bind(token, delivery),
			CONNECT_ONE_SHOT
	)
	var icon: Texture2D = _resource_icons.get(delivery.resource) as Texture2D
	token.begin(
			delivery.segments[delivery.stage],
			token_speed,
			icon,
			token_size,
			delay,
			delivery.resource
	)


func _on_delivery_token_arrived(token: ResourceToken, delivery: Delivery) -> void:
	_active_resource_tokens.erase(token)
	_on_delivery_stage_arrived(delivery)


func _on_delivery_token_cancelled(token: ResourceToken, delivery: Delivery) -> void:
	_active_resource_tokens.erase(token)
	_remove_in_flight(delivery.target, _delivery_weight(delivery))


func _delivery_weight(delivery: Delivery) -> int:
	var weight := 1
	var stages_left := delivery.segments.size() - delivery.stage - 1
	for _stage in maxi(stages_left, 0):
		weight *= 2
	return weight


func _on_delivery_stage_arrived(delivery: Delivery) -> void:
	if delivery.stage >= delivery.segments.size() - 1:
		_on_token_arrived(delivery.target, delivery.resource)
		return
	for child_index in 2:
		var child := Delivery.new()
		child.resource = delivery.resource
		child.target = delivery.target
		child.segments = delivery.segments
		child.stage = delivery.stage + 1
		var delay := float(child_index) * token_spacing / maxf(token_speed, 1.0)
		_spawn_delivery_stage(child, delay)


func _on_token_arrived(target: Node, resource: StringName) -> void:
	if not is_instance_valid(target):
		return
	_remove_in_flight(target, 1)
	var lock := target as LevelGraphLock
	if lock != null:
		lock.contribute(resource, 1)
	var firewall := target as LevelGraphFirewall
	if firewall != null:
		firewall.contribute(resource, 1)
	var note := target as LevelNote
	if note != null:
		var fed: Vector2i = note.feed_leftover(1)
		if fed.y > 0:
			prestige_earned.emit(fed.y, _note_center_global(note))
	_refresh_graph_state()


func _remove_in_flight(target: Node, amount: int) -> void:
	_in_flight[target] = maxi(int(_in_flight.get(target, 0)) - amount, 0)
	if int(_in_flight[target]) <= 0:
		_in_flight.erase(target)


func _path_to_note(note: LevelNote, planned: Dictionary) -> PackedVector2Array:
	var final_link := _link_into(note.note_id(), planned)
	if final_link == null:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for link in _links_to_owner(_flow_start_id(), final_link, planned):
		_append_polyline(points, _link_points_in_graph(link))
	return points


func _segments_to_lock(lock: LevelGraphLock, planned: Dictionary) -> Array[PackedVector2Array]:
	var owner_link := lock.get_parent() as LevelGraphLink
	if owner_link == null:
		return []
	var chain := _links_to_owner(_flow_start_id(), owner_link, planned)
	var final_points := _link_points_in_graph(owner_link)
	final_points = _polyline_until(final_points, _to_graph_local(lock.global_position))
	return _segments_for_chain(chain, final_points)


func _segments_to_note(note: LevelNote, planned: Dictionary) -> Array[PackedVector2Array]:
	var final_link := _link_into(note.note_id(), planned)
	if final_link == null:
		return []
	var chain := _links_to_owner(_flow_start_id(), final_link, planned)
	return _segments_for_chain(chain, _link_points_in_graph(final_link))


func _segments_for_chain(
		chain: Array[LevelGraphLink],
		final_link_points: PackedVector2Array
) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	for index in chain.size():
		var link := chain[index]
		var link_points := final_link_points if index == chain.size() - 1 \
				else _link_points_in_graph(link)
		_append_polyline(current, link_points)
		var passed_note := _notes_by_id.get(link.to_id()) as LevelNote
		var ends_at_target := index == chain.size() - 1
		if passed_note == null or ends_at_target or passed_note.resource_multiplier() <= 1:
			continue
		segments.append(current)
		current = PackedVector2Array([current[current.size() - 1]])
	if not current.is_empty():
		segments.append(current)
	return segments


func _segment_multiplier(segments: Array[PackedVector2Array]) -> int:
	var multiplier := 1
	for _stage in maxi(segments.size() - 1, 0):
		multiplier *= 2
	return multiplier


func _link_into(node_id: String, planned: Dictionary) -> LevelGraphLink:
	var closed_fallback: LevelGraphLink = null
	for link in _graph_links:
		if link.to_id() != node_id:
			continue
		if _is_open(link, planned):
			return link
		if closed_fallback == null:
			closed_fallback = link
	return closed_fallback


func _is_open(link: LevelGraphLink, planned: Dictionary) -> bool:
	return _front_lock(link, planned) == null


func _flow_start_id() -> String:
	for link in _graph_links:
		if not link.from_is_note():
			return link.from_id()
	return ""


func _links_to_owner(
		start_id: String,
		owner_link: LevelGraphLink,
		planned: Dictionary
) -> Array[LevelGraphLink]:
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
			if link.from_id() != node_id or not _is_open(link, planned):
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
	_firewalls.clear()
	for child in %Nodes.get_children():
		var note := child as LevelNote
		if note == null:
			continue
		_note_order.append(note)
		_notes_by_id[note.note_id()] = note
		var firewall := note.firewall()
		if firewall != null:
			_firewalls.append(firewall)
			firewall.defeated.connect(_on_firewall_defeated)
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
			if _is_opening(link):
				continue
			var to_id := link.to_id()
			if to_id == "" or reachable.get(to_id, false):
				continue
			reachable[to_id] = true
			queue.append(to_id)
	return reachable


func _refresh_graph_state() -> void:
	_refresh_key_access()
	var reachable := _reachable_ids()
	for note in _note_order:
		note.set_reachable(bool(reachable.get(note.note_id(), false)))
	_refresh_visibility()


func _refresh_key_access() -> void:
	for note in _note_order:
		note.set_key_access(_has_key(note.required_key))
	for link in _links:
		for lock in link.locks():
			lock.set_key_access(_has_key(lock.required_key))


func _has_key(key_id: String) -> bool:
	return key_id == "" or bool(_owned_keys.get(key_id, false))


func _refresh_visibility() -> void:
	var visible_notes: Dictionary = {}
	var visible_links: Dictionary = {}
	var frontier_by_link: Dictionary = {}
	var queue := _visibility_seeds(visible_notes)
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		for link in _graph_links:
			if link.from_id() != node_id:
				continue
			visible_links[link] = true
			var frontier := _frontier_lock(link)
			if frontier != null:
				frontier_by_link[link] = frontier
				continue
			var to_id := link.to_id()
			if to_id == "" or visible_notes.get(to_id, false):
				continue
			visible_notes[to_id] = true
			queue.append(to_id)
	for note in _note_order:
		note.visible = bool(visible_notes.get(note.note_id(), false))
	for link in _links:
		link.set_graph_visible(
				bool(visible_links.get(link, false)),
				frontier_by_link.get(link) as LevelGraphLock
		)


func _visibility_seeds(visible_notes: Dictionary) -> Array[String]:
	var has_incoming: Dictionary = {}
	var queue: Array[String] = []
	for link in _graph_links:
		if link.to_id() != "":
			has_incoming[link.to_id()] = true
		if link.from_is_note():
			continue
		var start_id := link.from_id()
		if start_id != "" and not queue.has(start_id):
			queue.append(start_id)
	for note in _note_order:
		var node_id := note.note_id()
		if has_incoming.get(node_id, false):
			continue
		visible_notes[node_id] = true
		queue.append(node_id)
	return queue


func _refresh_links() -> void:
	for link in _links:
		link.refresh()


func _on_graph_resized() -> void:
	_refresh_links()
	_refresh_visibility()


func _on_lock_finished(lock: LevelGraphLock) -> void:
	prestige_earned.emit(1, lock.global_position)
	_refresh_graph_state()


func _on_note_captured(note: LevelNote) -> void:
	var key_id := note.granted_key()
	if key_id != "":
		_owned_keys[key_id] = true
	_refresh_graph_state()


func _on_firewall_defeated(_firewall: LevelGraphFirewall) -> void:
	_refresh_graph_state()


func _on_node_pressed(node_id: String) -> void:
	node_clicked.emit(node_id)
