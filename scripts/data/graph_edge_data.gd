class_name GraphEdgeData
extends Resource

@export var id: StringName
@export var from_id: StringName
@export var to_id: StringName
@export var locked: bool = true
## The locks sitting on this edge, ordered from the source circle outwards.
## Each one must be paid off before the next starts taking resources, and the
## circle on the far side only opens once all of them are done. The two arrays
## run in parallel: one symbol and one amount per lock.
@export var lock_symbols: PackedInt32Array = PackedInt32Array([0])
@export var lock_amounts: PackedInt32Array = PackedInt32Array([10])
