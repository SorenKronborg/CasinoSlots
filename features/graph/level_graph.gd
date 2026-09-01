class_name LevelGraph
extends Control

signal node_clicked(node_id: String)

@export var default_node_scene: PackedScene
@export var edge_scene: PackedScene

var _nodes_by_id: Dictionary = {}


func load_definition(definition: LevelDefinition) -> void:
	_clear()
	if definition == null:
		return
	for spec in definition.nodes:
		_add_node(spec)
	for spec in definition.edges:
		_add_edge(spec)
	call_deferred("_layout_graph")


func _ready() -> void:
	resized.connect(_layout_graph)


func _clear() -> void:
	_nodes_by_id.clear()
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
		return
	var edge := edge_scene.instantiate() as LevelGraphEdge
	%Edges.add_child(edge)
	edge.setup(_nodes_by_id[spec.from_id], _nodes_by_id[spec.to_id], spec.locked)


func _layout_graph() -> void:
	for node in _nodes_by_id.values():
		var graph_node := node as LevelGraphNode
		graph_node.position = graph_node.normalized_position * size - graph_node.size * 0.5
	for edge in %Edges.get_children():
		(edge as LevelGraphEdge).refresh()


func _on_node_pressed(node_id: String) -> void:
	node_clicked.emit(node_id)
