class_name LockDelivery
extends RefCounted

## One batch of winnings routed to a single lock: how many icons should fly
## there, and which lock they pay into on arrival.

var edge: GraphEdgeView
var count: int


func _init(target: GraphEdgeView = null, amount: int = 0) -> void:
	edge = target
	count = amount
