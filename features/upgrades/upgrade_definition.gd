class_name UpgradeDefinition
extends RefCounted

var id: StringName = &""
var title: String = ""
var description: String = ""
var costs: Array[int] = []
var prerequisite_id: StringName = &""
var prerequisite_rank := 0
var graph_position := Vector2.ZERO


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


func has_prerequisite() -> bool:
	return prerequisite_id != &"" and prerequisite_rank > 0


func prerequisite_met(purchased_rank: int) -> bool:
	return not has_prerequisite() or purchased_rank >= prerequisite_rank
