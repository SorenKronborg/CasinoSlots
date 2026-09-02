class_name SlotMachine
extends HBoxContainer

signal spin_started
signal spin_finished(results: Array[int])

@export var symbols: Array[Texture2D] = []
@export var spin_duration := 2.0
@export var tick_interval := 0.08

var _can_spin := true
var _spinning := false
var _reels: Array[SlotReel] = []


func _ready() -> void:
	%Spin.text = tr("Spin")
	for child in %Reels.get_children():
		var reel := child as SlotReel
		if reel == null:
			continue
		reel.setup(symbols)
		_reels.append(reel)
	_refresh_spin_button()


func is_spinning() -> bool:
	return _spinning


func set_can_spin(value: bool) -> void:
	_can_spin = value
	_refresh_spin_button()


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
	var results: Array[int] = []
	for _i in _reels.size():
		results.append(randi() % symbols.size())
	var elapsed := 0.0
	while elapsed < spin_duration:
		for reel in _reels:
			reel.show_random()
		await get_tree().create_timer(tick_interval).timeout
		if not is_inside_tree():
			return
		elapsed += tick_interval
	for i in _reels.size():
		_reels[i].show_index(results[i])


func _current_results() -> Array[int]:
	var results: Array[int] = []
	for reel in _reels:
		results.append(reel.current_index())
	return results
