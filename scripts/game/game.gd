class_name Game
extends Control

@onready var _level: LevelGraph = %LevelGraph
@onready var _slots: SlotMachine = %SlotMachine
@onready var _flight: ResourceFlight = %ResourceFlight

const MATCH_SECONDS := 180.0

var _state := RunState.new()
var _time_left := MATCH_SECONDS


func _ready() -> void:
	_level.bind_run_state(_state)
	_level.node_completed.connect(_on_node_completed)
	_slots.spin_resolved.connect(_on_spin_resolved)
	_level.set_time_left(_time_left)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_level.set_time_left(_time_left)


func _on_node_completed(_id: StringName) -> void:
	_state.add_prestige(1)


func _on_spin_resolved(symbols: Array[int]) -> void:
	var payout := SlotPayout.from_spin(symbols)
	_state.apply_payout(payout)
	var origin := _slots.payout_origin()
	for kind in Symbols.COUNT:
		var amount: int = payout.symbols[kind]
		if amount <= 0:
			continue
		var deliveries: Array[LockDelivery] = _level.allocate_winnings(kind, amount)
		for delivery in deliveries:
			var edge := delivery.edge
			var delivery_kind := delivery.kind
			_flight.fly(delivery_kind, delivery.count, origin, edge.lock_center_global(delivery_kind), func() -> void:
				_level.credit_lock(edge, delivery_kind, 1)
			)
