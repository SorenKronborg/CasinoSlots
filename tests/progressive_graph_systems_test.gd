extends SceneTree

const COIN_NOTE_SCENE := preload("res://features/notes/coin_note/coin_note.tscn")
const CONSUME_NOTE_SCENE := preload("res://features/notes/silo_note/silo_note.tscn")
const KEY_NOTE_SCENE := preload("res://features/notes/key_card_note/key_card_note.tscn")
const FIREWALL_SCENE := preload("res://features/graph/firewall/level_graph_firewall.tscn")
const LOCK_SCENE := preload("res://features/graph/level_graph_lock.tscn")
const LEVEL_ONE_SCENE := preload("res://features/levels/level_1/level_01.tscn")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_multiplier_note()
	await _test_repeating_consume_note()
	await _test_key_card_and_gate()
	await _test_firewall_damage()
	await _test_initial_frontier_visibility()
	if _failures == 0:
		print("Progressive graph systems: all checks passed")
	quit(_failures)


func _test_multiplier_note() -> void:
	var note := COIN_NOTE_SCENE.instantiate() as CoinNote
	note.coin_capacity = 2
	get_root().add_child(note)
	await process_frame
	note.set_reachable(true)
	_check(note.deposit(1) == Vector2i(1, 0), "First coin should not capture note")
	_check(note.deposit(1) == Vector2i(1, 1), "Capture should award one prestige")
	_check(note.resource_multiplier() == 2, "Captured note should multiply by two")
	note.queue_free()
	await process_frame


func _test_repeating_consume_note() -> void:
	var note := CONSUME_NOTE_SCENE.instantiate() as SiloNote
	note.resource_capacity = 3
	get_root().add_child(note)
	await process_frame
	_check(note.feed_leftover(2) == Vector2i(2, 0), "Partial cycle should not pay")
	_check(note.feed_leftover(1) == Vector2i(1, 1), "Full cycle should pay once")
	_check(note.remaining_capacity() == 3, "Consume counter should reset")
	_check(note.feed_leftover(3) == Vector2i(3, 1), "Second cycle should pay again")
	note.queue_free()
	await process_frame


func _test_key_card_and_gate() -> void:
	var key_note := KEY_NOTE_SCENE.instantiate() as KeyCardNote
	key_note.coin_capacity = 1
	key_note.key_id = "B"
	get_root().add_child(key_note)
	await process_frame
	key_note.set_reachable(true)
	_check(key_note.deposit(1) == Vector2i(1, 1), "Key capture should pay prestige")
	_check(key_note.granted_key() == "B", "Captured key note should grant key B")
	var lock := LOCK_SCENE.instantiate() as LevelGraphLock
	lock.required_key = "B"
	lock.unlock_resource = &"bell"
	get_root().add_child(lock)
	await process_frame
	lock.set_key_access(false)
	_check(not lock.can_accept(&"bell"), "Key-gated lock should reject resources")
	lock.set_key_access(true)
	_check(lock.can_accept(&"bell"), "Owned key should enable normal lock requirement")
	key_note.queue_free()
	lock.queue_free()
	await process_frame


func _test_firewall_damage() -> void:
	var firewall := FIREWALL_SCENE.instantiate() as LevelGraphFirewall
	firewall.vulnerable_resource = &"diamond"
	firewall.required_amount = 2
	get_root().add_child(firewall)
	await process_frame
	_check(firewall.contribute(&"bell", 1) == 1, "Wrong resource should be returned")
	_check(firewall.remaining() == 2, "Wrong resource should not damage firewall")
	_check(firewall.contribute(&"diamond", 2) == 0, "Vulnerable resource should be used")
	_check(firewall.remaining() == 0, "Enough vulnerable resources should defeat firewall")
	firewall.queue_free()
	await process_frame


func _test_initial_frontier_visibility() -> void:
	var level := LEVEL_ONE_SCENE.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	var nodes := level.get_node("Layout/TopField/LevelGraph/Nodes")
	var edges := level.get_node("Layout/TopField/LevelGraph/Edges")
	_check(not nodes.get_node("left1").visible, "Note beyond initial lock should be hidden")
	_check(edges.get_node("LinkSpinLeft").visible, "Edge leading to initial lock should show")
	level.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
