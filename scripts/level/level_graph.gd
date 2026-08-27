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
		edge.lock_clicked.connect(_on_lock_clicked)
		_edges[edge_data.id] = edge
	_assign_depths()


## Walks outward from the start node so every edge knows which layer it is in.
func _assign_depths() -> void:
	var node_depth: Dictionary = {}
	var frontier: Array[StringName] = []
	for node: GraphNodeView in _nodes.values():
		if node.is_start:
			node_depth[node.node_id] = 0
			frontier.append(node.node_id)
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		for edge: GraphEdgeView in _edges.values():
			if edge.from_id != current or node_depth.has(edge.to_id):
				continue
			node_depth[edge.to_id] = int(node_depth[current]) + 1
			frontier.append(edge.to_id)
	for edge: GraphEdgeView in _edges.values():
		edge.depth = int(node_depth.get(edge.from_id, 0)) + 1


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
		node.apply_state(_is_reachable(node))
	for edge: GraphEdgeView in _edges.values():
		var selectable := can_receive_resources(edge)
		edge.set_selectable(selectable)
		if not selectable and edge.prioritized:
			edge.set_prioritized(false)
	if _hud:
		_hud.refresh(_run_state)


## True while this lock still needs something and every lock leading into it
## has already been opened.
func can_receive_resources(edge: GraphEdgeView) -> bool:
	if not edge.locked or edge.is_fully_paid():
		return false
	for other: GraphEdgeView in _edges.values():
		if other.to_id == edge.from_id and other.locked:
			return false
	return true


## A lock only accepts resources once every lock leading into it has been
## opened. Paying the source circle is not a prerequisite.
func is_lock_open_for(kind: int, edge: GraphEdgeView) -> bool:
	return can_receive_resources(edge) and edge.open_capacity(kind) > 0


## Reserves as much of a win as the open locks can still take. Locks the player
## marked as priority are filled first, then the ones closest to the start.
## Anything left over has nowhere to go and is dropped by the caller.
func allocate_winnings(kind: int, amount: int) -> Array[LockDelivery]:
	var deliveries: Array[LockDelivery] = []
	var candidates: Array[GraphEdgeView] = []
	for edge: GraphEdgeView in _edges.values():
		if is_lock_open_for(kind, edge):
			candidates.append(edge)
	candidates.sort_custom(func(a: GraphEdgeView, b: GraphEdgeView) -> bool:
		if a.prioritized != b.prioritized:
			return a.prioritized
		return a.depth < b.depth
	)
	var leftover := amount
	for edge in candidates:
		if leftover <= 0:
			break
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
	return _is_reachable(node)


func _is_reachable(node: GraphNodeView) -> bool:
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


func _on_lock_clicked(edge_id: StringName) -> void:
	var edge: GraphEdgeView = _edges.get(edge_id)
	if edge == null or not can_receive_resources(edge):
		return
	edge.set_prioritized(not edge.prioritized)
