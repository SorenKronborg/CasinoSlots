class_name LevelGraph
extends PanelContainer

signal node_clicked(id: StringName)
signal node_completed(id: StringName)

const NODE_SCENE := preload("res://scenes/level/graph_node.tscn")
const EDGE_SCENE := preload("res://scenes/level/graph_edge.tscn")

@export var definition: LevelDefinition

@onready var _edges_layer: Control = %EdgesLayer
@onready var _nodes_layer: Control = %NodesLayer
@onready var _hud: LevelHud = %Hud
@onready var _clock: ClockHud = %ClockHud

var _nodes: Dictionary = {}
var _edges: Dictionary = {}
var _run_state: RunState


func _ready() -> void:
	if definition == null:
		push_warning("LevelGraph has no LevelDefinition.")
		return
	_build()
	_nodes_layer.resized.connect(_layout_board)
	_layout_board()
	_refresh()


func set_time_left(seconds: float) -> void:
	if _clock:
		_clock.set_time_left(seconds)


func bind_run_state(state: RunState) -> void:
	if _run_state != null and _run_state.changed.is_connected(_refresh):
		_run_state.changed.disconnect(_refresh)
	_run_state = state
	if _run_state != null:
		_run_state.changed.connect(_refresh)
	_refresh()


func unlock_edge(edge_id: StringName) -> void:
	var edge: GraphEdgeView = _edges.get(edge_id)
	if edge == null:
		push_warning("Unknown edge: %s" % String(edge_id))
		return
	edge.set_locked(false)
	_refresh()


func try_pay_node(id: StringName) -> void:
	var node: GraphNodeView = _nodes.get(id)
	if node == null or node.is_paid() or not _can_pay(node):
		return
	if _run_state == null or not _run_state.try_spend_coins(1):
		return
	node.add_coin()


func _build() -> void:
	for node_data in definition.nodes:
		var node: GraphNodeView = NODE_SCENE.instantiate()
		_nodes_layer.add_child(node)
		node.setup(node_data)
		node.node_pressed.connect(_on_node_pressed)
		node.node_completed.connect(_on_node_completed)
		_nodes[node_data.id] = node
	for edge_data in definition.edges:
		var from_node: GraphNodeView = _nodes.get(edge_data.from_id)
		var to_node: GraphNodeView = _nodes.get(edge_data.to_id)
		if from_node == null or to_node == null:
			push_warning("Edge %s references a missing node." % String(edge_data.id))
			continue
		var edge: GraphEdgeView = EDGE_SCENE.instantiate()
		_edges_layer.add_child(edge)
		edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		edge.setup(edge_data, from_node.center(), to_node.center())
		_edges[edge_data.id] = edge


## Keeps the authored layout centred in whatever space the panel gets, so the
## same LevelDefinition reads well at any window size.
func _layout_board() -> void:
	if _nodes.is_empty():
		return
	var bounds := Rect2()
	var first := true
	for node: GraphNodeView in _nodes.values():
		if first:
			bounds = Rect2(node.board_position, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(node.board_position)
	var offset := (_nodes_layer.size - bounds.size) * 0.5 - bounds.position
	for node: GraphNodeView in _nodes.values():
		node.place(offset)
	for edge: GraphEdgeView in _edges.values():
		var from_node: GraphNodeView = _nodes.get(edge.from_id)
		var to_node: GraphNodeView = _nodes.get(edge.to_id)
		if from_node != null and to_node != null:
			edge.set_endpoints(from_node.center(), to_node.center())


func _refresh() -> void:
	for node: GraphNodeView in _nodes.values():
		node.set_clickable(_can_pay(node))
	if _hud:
		_hud.refresh(_run_state)


func is_lock_open_for(kind: int, edge: GraphEdgeView) -> bool:
	## Locks accept resources immediately; paying the source circle is no longer
	## a prerequisite.
	return edge.locked and edge.open_capacity(kind) > 0


## Reserves as much of a win as the open locks can still take. Anything left
## over has nowhere to go and is simply dropped by the caller.
func allocate_winnings(kind: int, amount: int) -> Array[LockDelivery]:
	var deliveries: Array[LockDelivery] = []
	var leftover := amount
	for edge: GraphEdgeView in _edges.values():
		if leftover <= 0:
			break
		if not is_lock_open_for(kind, edge):
			continue
		var taken := edge.reserve(kind, leftover)
		if taken <= 0:
			continue
		deliveries.append(LockDelivery.new(edge, kind, taken))
		leftover -= taken
	return deliveries


func credit_lock(edge: GraphEdgeView, kind: int, amount: int) -> void:
	if edge == null:
		return
	edge.apply_payment(kind, amount)
	if edge.is_fully_paid() and edge.locked:
		unlock_edge(edge.edge_id)


func _can_pay(node: GraphNodeView) -> bool:
	if node.is_paid():
		return false
	if _run_state == null or _run_state.coins < 1:
		return false
	if node.is_start:
		return true
	for edge: GraphEdgeView in _edges.values():
		if edge.to_id == node.node_id and not edge.locked:
			return true
	return false


func _on_node_pressed(id: StringName) -> void:
	node_clicked.emit(id)
	try_pay_node(id)


func _on_node_completed(id: StringName) -> void:
	node_completed.emit(id)
	_refresh()
