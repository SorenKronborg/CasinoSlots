class_name GraphEdgeData
extends Resource

@export var id: StringName
@export var from_id: StringName
@export var to_id: StringName
@export var locked: bool = true
@export var lock_symbol: int = 0
@export var lock_amount: int = 10
## Set to -1 for a lock with only one resource requirement.
@export var lock_symbol_2: int = -1
@export var lock_amount_2: int = 0
