class_name LockDelivery
extends RefCounted

## One batch of winnings routed to a single lock: how many icons should fly
## there, and which lock on which edge they pay into on arrival.

var edge: GraphEdgeView
var lock_index: int
var kind: int
var count: int


func _init(target: GraphEdgeView = null, index: int = 0, resource_kind: int = 0, amount: int = 0) -> void:
	edge = target
	lock_index = index
	kind = resource_kind
	count = amount
