class_name Game
extends Node

## Owns the run: the wallet, the upgrades bought with it, and navigation between
## the machine and the screens layered on top of it. The machine itself knows
## nothing about those screens.

const UPGRADES_SCENE := "res://scenes/upgrades/upgrades.tscn"

@export var upgrade_tree: UpgradeTree

@onready var _upgrades_button: Button = %UpgradesButton
@onready var _overlay_layer: CanvasLayer = $OverlayLayer

var _state: RunState
var _upgrades: Upgrades


func _enter_tree() -> void:
	# A parent enters the tree before its children are ready, which is what makes
	# it safe to hand the state over before the machine builds itself from it.
	_state = RunState.new(upgrade_tree)
	$SlotMachine.state = _state


func _ready() -> void:
	_upgrades_button.pressed.connect(_open_upgrades)


func _open_upgrades() -> void:
	if _upgrades != null:
		return

	_upgrades = load(UPGRADES_SCENE).instantiate() as Upgrades
	_upgrades.state = _state
	# Pausing is what stops a spacebar press behind the overlay from spinning,
	# and it freezes any spin already in flight rather than letting reels land
	# out of sight.
	_upgrades.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_upgrades.closed.connect(_close_upgrades)
	_overlay_layer.add_child(_upgrades)
	get_tree().paused = true


func _close_upgrades() -> void:
	if _upgrades == null:
		return

	get_tree().paused = false
	_upgrades.queue_free()
	_upgrades = null
	_upgrades_button.grab_focus()
