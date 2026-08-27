class_name Game
extends Control

@onready var _level: LevelGraph = %LevelGraph
@onready var _slots: SlotMachine = %SlotMachine
@onready var _flight: ResourceFlight = %ResourceFlight

const MATCH_SPINS := 50

var _state := RunState.new()
var _spins_left := MATCH_SPINS


func _ready() -> void:
	_level.bind_run_state(_state)
	_level.node_completed.connect(_on_node_completed)
	_level.coin_paid.connect(_on_coin_paid)
	_slots.spin_started.connect(_on_spin_started)
	_slots.spin_resolved.connect(_on_spin_resolved)
	_level.set_spins_left(_spins_left)


func _on_spin_started() -> void:
	_spins_left = maxi(_spins_left - 1, 0)
	_level.set_spins_left(_spins_left)
	if _spins_left <= 0:
		_slots.set_allow_spin(false)


func _on_node_completed(_id: StringName) -> void:
	_state.add_prestige(1)


func _on_coin_paid(node: GraphNodeView) -> void:
	_flight.fly_coin(1, _level.coin_origin(), node.center_global(), func() -> void:
		_level.credit_node(node)
	)


func _on_spin_resolved(symbols: Array[int]) -> void:
	var payout := SlotPayout.from_spin(symbols)
	if payout.coins > 0:
		_flight.fly_coin(payout.coins, _slots.coin_origin(), _level.coin_origin(), func() -> void:
			_state.add_coins(1)
		)
	var origin := _slots.payout_origin()
	for kind in Symbols.COUNT:
		var amount: int = payout.symbols[kind]
		if amount <= 0:
			continue
		var deliveries: Array[LockDelivery] = _level.allocate_winnings(kind, amount)
		for delivery in deliveries:
			var edge := delivery.edge
			var lock_index := delivery.lock_index
			_flight.fly(delivery.kind, delivery.count, origin, edge.lock_center_global(lock_index), func() -> void:
				_level.credit_lock(edge, lock_index, 1)
			)
