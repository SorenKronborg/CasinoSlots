class_name SlotMachine
extends PanelContainer

signal spin_resolved(symbols: Array[int])

const REEL_SCENE := preload("res://scenes/machine/reel.tscn")
const REEL_COUNT := 4
const STAGGER := 0.18
const BASE_SPIN_TIME := 0.7

@onready var _reel_row: HBoxContainer = %ReelRow
@onready var _spin_button: Button = %SpinButton

var _reels: Array[Reel] = []
var _pending: int = 0


func _ready() -> void:
	for i in REEL_COUNT:
		var reel: Reel = REEL_SCENE.instantiate()
		_reel_row.add_child(reel)
		reel.landed.connect(_on_reel_landed)
		_reels.append(reel)
	_spin_button.pressed.connect(spin)


func is_spinning() -> bool:
	return _pending > 0


func payout_origin() -> Vector2:
	return _reel_row.get_global_rect().get_center()


func spin() -> void:
	if is_spinning():
		return
	_spin_button.disabled = true
	_pending = REEL_COUNT
	for i in REEL_COUNT:
		var target := randi() % Symbols.COUNT
		_reels[i].spin(target, BASE_SPIN_TIME + float(i) * STAGGER)


func _on_reel_landed(_symbol: int) -> void:
	_pending -= 1
	if _pending > 0:
		return
	var symbols: Array[int] = []
	for reel in _reels:
		symbols.append(reel.current_symbol())
	_spin_button.disabled = false
	spin_resolved.emit(symbols)
