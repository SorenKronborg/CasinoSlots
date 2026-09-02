class_name LevelGraphEdge
extends Node2D

var from_node: Control
var to_node: Control
var from_id: String = ""
var to_id: String = ""
var locked: bool = false
var unlock_resource: StringName = &""
var unlock_cost: int = 0
var collected: int = 0


func setup(from: Control, to: Control, spec: LevelEdgeSpec) -> void:
	from_node = from
	to_node = to
	from_id = spec.from_id
	to_id = spec.to_id
	locked = spec.locked
	unlock_resource = spec.unlock_resource
	unlock_cost = spec.unlock_cost
	collected = 0
	_refresh_requirement()
	refresh()


func set_resource_icon(texture: Texture2D) -> void:
	%Icon.texture = texture
	%Icon.visible = texture != null


func contribute(resource: StringName, amount: int) -> int:
	if not locked or amount <= 0 or resource != unlock_resource:
		return amount
	var needed := maxi(unlock_cost - collected, 0)
	var used := mini(amount, needed)
	collected += used
	if collected >= unlock_cost:
		locked = false
		collected = unlock_cost
	_refresh_requirement()
	return amount - used


func _refresh_requirement() -> void:
	%LockCluster.visible = locked
	%Amount.text = "%s/%s" % [collected, unlock_cost]


func refresh() -> void:
	if from_node == null or to_node == null:
		return
	var start := from_node.position + from_node.size * 0.5
	var end := to_node.position + to_node.size * 0.5
	%Line.points = PackedVector2Array([start, end])
	%LockCluster.position = (start + end) * 0.5
