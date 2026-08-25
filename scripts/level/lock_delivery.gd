class_name LockDelivery
extends RefCounted

## One batch of winnings routed to a single lock: how many icons should fly
## there, and which lock they pay into on arrival.

var edge: GraphEdgeView
var kind: int
var count: int


func _init(target: GraphEdgeView = null, resource_kind: int = 0, amount: int = 0) -> void:
	edge = target
	kind = resource_kind
	count = amount
