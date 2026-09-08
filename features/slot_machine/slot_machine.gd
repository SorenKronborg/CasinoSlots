class_name SlotMachine
extends Control

signal spin_started
signal spin_finished(results: Array[StringName])

@export var symbols: Array[Texture2D] = []
@export var symbol_ids: Array[StringName] = [&"cherry", &"bell", &"seven", &"watermelon", &"diamond"]
@export var spin_duration := 2.0
@export var tick_interval := 0.08

var _can_spin := true
var _spinning := false
var _reels: Array[SlotReel] = []


func _ready() -> void:
	%Spin.text = tr("Spin")
	_configure_reels()
	_refresh_spin_button()


func symbol_icon_map() -> Dictionary:
	var icons := {}
	var ids_left := symbol_ids.duplicate()
	for texture in symbols:
		if ids_left.is_empty():
			break
		var symbol_id: StringName = ids_left.pop_front()
		icons[symbol_id] = texture
	return icons


func is_spinning() -> bool:
	return _spinning


func set_can_spin(value: bool) -> void:
	_can_spin = value
	_refresh_spin_button()


func _configure_reels() -> void:
	var extra := get_node_or_null("%Reel4") as SlotReel
	if extra != null and not GameState.has_extra_wheel():
		extra.visible = false
	_reels.clear()
	for child in %Reels.get_children():
		var reel := child as SlotReel
		if reel == null or not reel.visible:
			continue
		reel.setup(symbols)
		_reels.append(reel)


func _refresh_spin_button() -> void:
	%Spin.disabled = _spinning or not _can_spin


func _on_spin_pressed() -> void:
	if _spinning or not _can_spin or _reels.is_empty() or symbols.is_empty():
		return
	_spinning = true
	_refresh_spin_button()
	spin_started.emit()
	await _play_spin()
	if not is_inside_tree():
		return
	_spinning = false
	_refresh_spin_button()
	spin_finished.emit(_current_results())


func _play_spin() -> void:
	var chosen: Dictionary = {}
	for reel in _reels:
		chosen[reel] = randi() % symbols.size()
	var elapsed := 0.0
	while elapsed < spin_duration:
		for reel in _reels:
			reel.show_random()
		await get_tree().create_timer(tick_interval).timeout
		if not is_inside_tree():
			return
		elapsed += tick_interval
	for reel in _reels:
		reel.show_index(int(chosen[reel]))


func _current_results() -> Array[StringName]:
	var results: Array[StringName] = []
	for reel in _reels:
		results.append(_symbol_id_at(reel.current_index()))
	return results


func _symbol_id_at(symbol_index: int) -> StringName:
	var walked := 0
	for symbol_id in symbol_ids:
		if walked == symbol_index:
			return symbol_id
		walked += 1
	return &""
