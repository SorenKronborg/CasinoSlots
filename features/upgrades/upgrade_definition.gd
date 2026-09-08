class_name UpgradeDefinition
extends RefCounted

var id: StringName = &""
var title: String = ""
var description: String = ""
var costs: Array[int] = []


func max_rank() -> int:
	return costs.size()


func next_cost(purchased_rank: int) -> int:
	var remaining_to_skip := purchased_rank
	for cost in costs:
		if remaining_to_skip <= 0:
			return cost
		remaining_to_skip -= 1
	return -1


func is_maxed(purchased_rank: int) -> bool:
	return purchased_rank >= max_rank()
