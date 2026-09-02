class_name LevelGraph
extends Control

signal node_clicked(node_id: String)

@export var default_node_scene: PackedScene
@export var edge_scene: PackedScene

var _nodes_by_id: Dictionary = {}
var _edges: Array[LevelGraphEdge] = []


func load_definition(definition: LevelDefinition) -> void:
	_clear()
	if definition == null:
		return
	for spec in definition.nodes:
		_add_node(spec)
	for spec in definition.edges:
		_add_edge(spec)
	_refresh_node_access()
	call_deferred("_layout_graph")


func set_resource_icons(icons: Dictionary) -> void:
	for edge in _edges:
		var texture: Variant = icons.get(edge.unlock_resource)
		edge.set_resource_icon(texture as Texture2D)


func deposit_into(node_id: String, available_coins: int) -> Vector2i:
	if not _nodes_by_id.has(node_id):
		return Vector2i.ZERO
	var node := _nodes_by_id[node_id] as LevelGraphNode
	return node.deposit(available_coins)


func apply_resources(gained: Dictionary) -> void:
	for resource in gained:
		var remaining := int(gained[resource])
		if remaining <= 0:
			continue
		for edge in _edges:
			remaining = edge.contribute(resource, remaining)
			if remaining <= 0:
				break
	_refresh_node_access()


func _ready() -> void:
	resized.connect(_layout_graph)


func _clear() -> void:
	_nodes_by_id.clear()
	_edges.clear()
	for child in %Edges.get_children():
		child.queue_free()
	for child in %Nodes.get_children():
		child.queue_free()


func _add_node(spec: LevelNodeSpec) -> void:
	var scene := spec.node_scene if spec.node_scene != null else default_node_scene
	var node := scene.instantiate() as LevelGraphNode
	node.setup(spec)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.pressed.connect(_on_node_pressed.bind(spec.id))
	%Nodes.add_child(node)
	_nodes_by_id[spec.id] = node


func _add_edge(spec: LevelEdgeSpec) -> void:
	if not _nodes_by_id.has(spec.from_id) or not _nodes_by_id.has(spec.to_id):
		push_warning("Edge '%s' -> '%s' skipped: unknown node id" % [spec.from_id, spec.to_id])
		return
	var edge := edge_scene.instantiate() as LevelGraphEdge
	%Edges.add_child(edge)
	edge.setup(_nodes_by_id[spec.from_id], _nodes_by_id[spec.to_id], spec)
	_edges.append(edge)


func _refresh_node_access() -> void:
	var reachable: Dictionary = {}
	var has_incoming: Dictionary = {}
	for edge in _edges:
		has_incoming[edge.to_id] = true
	var queue: Array[String] = []
	for node_id in _nodes_by_id:
		if has_incoming.get(node_id, false):
			continue
		reachable[node_id] = true
		queue.append(node_id)
	while not queue.is_empty():
		var node_id: String = queue.pop_front()
		for edge in _edges:
			if edge.locked or edge.from_id != node_id:
				continue
			if reachable.get(edge.to_id, false):
				continue
			reachable[edge.to_id] = true
			queue.append(edge.to_id)
	for node_id in _nodes_by_id:
		var node := _nodes_by_id[node_id] as LevelGraphNode
		node.disabled = not bool(reachable.get(node_id, false))
		node.focus_mode = Control.FOCUS_NONE if node.disabled else Control.FOCUS_ALL


func _layout_graph() -> void:
	for node in _nodes_by_id.values():
		var graph_node := node as LevelGraphNode
		graph_node.position = graph_node.normalized_position * size - graph_node.size * 0.5
	for edge in %Edges.get_children():
		(edge as LevelGraphEdge).refresh()


func _on_node_pressed(node_id: String) -> void:
	node_clicked.emit(node_id)
