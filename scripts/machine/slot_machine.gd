class_name SlotMachine
extends Control

## Drives a row of reels. The outcome of a spin is drawn before any animation
## starts, so the reels are pure presentation: payouts stay auditable and any
## result can be forced for testing.

@export var reel_scene: PackedScene
@export var symbol_set: SymbolSet
@export var pay_table: PayTable

## Only used when nobody injected a RunState, so the machine scene still runs on
## its own. In the game, Game owns the state and hands it over.
@export var upgrade_tree: UpgradeTree

## Reels before upgrades. Raising this is the only change needed to widen the
## machine; upgrades add to it from here.
@export_range(1, 20) var reel_count := 3
@export var cell_px := 96

## Seconds the first reel cruises before stopping; each subsequent reel adds
## `stagger`. Keep the total spread near a second, or a wide machine spends most
## of the spin waiting.
@export var base_cruise_time := 0.85
@export var stagger := 0.28

@export var starting_credits := RunState.STARTING_CREDITS

## Stake before upgrades multiply it.
@export var bet := 1

## Debug override: when it holds one strip index per reel, those indices are used
## instead of the RNG. Reaching a jackpot animation by spinning normally is not
## practical at 1-in-2370.
@export var forced_stops := PackedInt32Array()

## The wallet and the upgrades bought with it. Assign before the machine enters
## the tree; it falls back to a fresh state of its own otherwise.
var state: RunState

@onready var _reel_row: HBoxContainer = %ReelRow
@onready var _payout_slot: PayoutSlot = %PayoutSlot
@onready var _credits_label: Label = %CreditsLabel
@onready var _win_label: Label = %WinLabel
@onready var _spin_button: Button = %SpinButton
@onready var _auto_button: Button = %AutoButton
@onready var _auto_timer: Timer = %AutoTimer

var _strip := PackedInt32Array()
var _strip_texture: Texture2D
var _reels: Array[Reel] = []
var _line := PackedInt32Array()
var _pending := 0
var _has_spun := false

## Whether the last spin lost. Holds are only on the table after a loss.
var _holds_offered := false
var _rebuild_after_spin := false
var _rng := RandomNumberGenerator.new()

## Stake and payout scale actually in force, after upgrades.
var _bet := 1
var _payout_multiplier := 1

## At least one reel must always turn, so holding every reel is never allowed.
var _max_holds: int:
	get:
		return maxi(0, _reels.size() - 1)


func _ready() -> void:
	_rng.randomize()
	if state == null:
		state = RunState.new(upgrade_tree, starting_credits)
	state.credits_changed.connect(_on_credits_changed)
	state.upgrades_changed.connect(_apply_upgrades)

	if not _validate_configuration():
		return

	_strip = StripBuilder.build_strip()
	_strip_texture = StripBuilder.build_texture(_strip, symbol_set, cell_px)

	_spin_button.pressed.connect(spin)
	_auto_button.toggled.connect(_on_auto_toggled)
	_auto_timer.timeout.connect(_on_auto_timeout)
	_win_label.text = ""
	_apply_upgrades()


func _unhandled_input(event: InputEvent) -> void:
	# The focused button consumes ui_accept first, so this cannot double-fire.
	if event.is_action_pressed("ui_accept"):
		spin()
		accept_event()


func spin() -> void:
	if _pending > 0:
		return
	if not state.spend(_bet):
		_win_label.text = "Out of credits"
		_auto_button.button_pressed = false
		return

	_auto_timer.stop()

	_win_label.text = ""

	for reel in _reels:
		reel.clear_highlight()
		reel.set_hold_available(false)

	# Held reels keep whatever they last landed on, so _line already holds the
	# right symbol for them and evaluation needs no special case.
	var turning: Array[int] = []
	for i in _reels.size():
		if not _reels[i].is_held():
			turning.append(i)

	_pending = turning.size()
	for slot in turning.size():
		var index: int = turning[slot]
		_reels[index].spin(_draw_stop(index), base_cruise_time + float(slot) * stagger)


func _draw_stop(reel_index: int) -> int:
	if reel_index < forced_stops.size():
		return posmod(forced_stops[reel_index], _strip.size())
	return _rng.randi_range(0, _strip.size() - 1)


func _on_reel_landed(reel_index: int, symbol: int) -> void:
	_line[reel_index] = symbol
	_pending -= 1
	if _pending > 0:
		return

	# Holds are the consolation for a losing spin. Offering them on a win would
	# let the player keep the paying line and collect on it again.
	_holds_offered = not _evaluate()

	# A hold buys exactly one spin, then the player chooses again.
	for reel in _reels:
		reel.release_hold()
	_has_spun = true
	_refresh_hold_availability()

	if _rebuild_after_spin:
		_rebuild_after_spin = false
		_apply_upgrades()

	_queue_auto_spin()


## The gap between automatic spins is a timer rather than an immediate call, so
## the player can read the result and reach the hold buttons.
func _queue_auto_spin() -> void:
	if not _auto_button.button_pressed:
		return
	if not state.can_afford(_bet):
		_win_label.text = "Out of credits"
		_auto_button.button_pressed = false
		return
	_auto_timer.start()


func _on_auto_toggled(pressed: bool) -> void:
	if pressed:
		_queue_auto_spin()
	else:
		# Any spin already turning finishes; only the next one is cancelled.
		_auto_timer.stop()


func _on_auto_timeout() -> void:
	if _auto_button.button_pressed:
		spin()


## Holds stay locked until a losing spin has completed, and the cap closes off
## the remaining reels once it is reached. Already-held reels stay pressable so a
## choice can be undone.
func _refresh_hold_availability() -> void:
	var held := 0
	for reel in _reels:
		if reel.is_held():
			held += 1
	var at_cap := held >= _max_holds
	var offered := _has_spun and _holds_offered and _pending == 0
	for reel in _reels:
		reel.set_hold_available(offered and (reel.is_held() or not at_cap))


func _on_hold_toggled(_reel_index: int, _held: bool) -> void:
	_refresh_hold_availability()


## Pays out the line and returns whether it won anything.
func _evaluate() -> bool:
	var result := pay_table.evaluate(_line, _bet)
	if result.is_empty():
		_win_label.text = "No win"
		return false

	var win := int(result["win"]) * _payout_multiplier
	var rule: PayRule = result["rule"]
	var positions: PackedInt32Array = result["positions"]

	state.award(win)
	_payout_slot.burst(win, _bet)
	_win_label.text = "%s  ·  +%d" % [_describe(rule, positions.size()), win]

	# One visible symbol per reel, so highlighting the reel is the same thing as
	# highlighting the winning symbol.
	for i in _reels.size():
		if positions.has(i):
			_reels[i].flash_win()
		else:
			_reels[i].dim()
	return true


func _describe(rule: PayRule, matched: int) -> String:
	var label := symbol_set.display_name_of(rule.symbol) if symbol_set != null \
			else Symbols.name_of(rule.symbol)
	return "%d x %s" % [matched, label]


## Folds whatever the player owns into the machine. Called on every purchase, so
## it has to be safe to run repeatedly and cheap when nothing changed.
func _apply_upgrades() -> void:
	var effects := state.effects()
	_bet = maxi(1, bet * effects.bet_multiplier)
	_payout_multiplier = maxi(1, effects.payout_multiplier)

	# The upgrade is meant to add the button, so it does not exist before then
	# rather than sitting there greyed out.
	_auto_button.visible = effects.has(&"auto_spin")
	if not _auto_button.visible:
		_auto_button.button_pressed = false

	var wanted := maxi(1, reel_count + effects.extra_reels)
	if wanted != _reels.size():
		# Freeing reels mid-spin would leave their landing signals unfired and
		# _pending would never reach zero, so a wider machine waits for the
		# spin the player opened the upgrades screen on top of.
		if _pending > 0:
			_rebuild_after_spin = true
		else:
			_build_reels(wanted)

	_refresh_credits()
	_refresh_hold_availability()


func _build_reels(count: int) -> void:
	for child in _reel_row.get_children():
		# Freeing is deferred, so the child has to leave the row now or it still
		# counts as a reel for the rest of the frame.
		_reel_row.remove_child(child)
		child.queue_free()
	_reels.clear()

	_line = PackedInt32Array()
	_line.resize(count)

	for i in count:
		var reel: Reel = reel_scene.instantiate()
		_reel_row.add_child(reel)
		reel.setup(i, _strip, _strip_texture, cell_px)
		reel.landed.connect(_on_reel_landed)
		reel.hold_toggled.connect(_on_hold_toggled)
		_reels.append(reel)
		_line[i] = reel.current_symbol()


func _on_credits_changed(_credits: int) -> void:
	_refresh_credits()


func _refresh_credits() -> void:
	_credits_label.text = "Credits %d    Bet %d" % [state.credits, _bet]


func _validate_configuration() -> bool:
	var problems := PackedStringArray()
	if reel_scene == null:
		problems.append("reel_scene is not assigned")
	if symbol_set == null:
		problems.append("symbol_set is not assigned")
	else:
		problems.append_array(symbol_set.validate())
	if pay_table == null:
		problems.append("pay_table is not assigned")
	if state.tree != null:
		problems.append_array(state.tree.validate())

	if problems.is_empty():
		return true

	for problem in problems:
		push_error("SlotMachine: %s" % problem)
	_win_label.text = "Configuration error - see output"
	_spin_button.disabled = true
	return false
