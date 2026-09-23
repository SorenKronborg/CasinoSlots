class_name BaseLevel
extends Control

const STARTING_SPINS := 25
const HEART_SPEED_SCALE := 1.5
const HEART_SIZE := 24.0
const HEART_SPACING := 34.0

@export var heart_scene: PackedScene
@export var heart_icon: Texture2D
@export_file("*.tscn") var idle_game_scene_path: String

var level_prestige := 0
var level_coins := 0
var spins_remaining := STARTING_SPINS

var _winnings := Winnings.new()
var _prestige_in_flight := 0
var _help_on := false
var _hovered_note: LevelNote


func _ready() -> void:
	spins_remaining = STARTING_SPINS + GameState.extra_spin_bonus()
	%Back.text = tr("Back")
	%Help.text = tr("Help")
	var graph := %LevelGraph as LevelGraph
	graph.set_resource_icons(%SlotMachine.symbol_icon_map())
	graph.node_clicked.connect(_on_node_clicked)
	graph.prestige_earned.connect(_on_prestige_earned)
	graph.coin_stolen.connect(_on_coin_stolen)
	%SlotMachine.spin_started.connect(_on_spin_started)
	%SlotMachine.spin_finished.connect(_on_spin_finished)
	for note in graph.notes():
		note.mouse_entered.connect(_on_note_help_entered.bind(note))
		note.mouse_exited.connect(_on_note_help_exited.bind(note))
	_hide_help_tooltip()
	_refresh_hud()
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_back_pressed() -> void:
	_bank_prestige()
	get_tree().change_scene_to_file(idle_game_scene_path)


func _on_spin_started() -> void:
	spins_remaining = maxi(spins_remaining - 1, 0)
	_refresh_hud()
	%SlotMachine.set_can_spin(false)


func _on_node_clicked(node_id: String) -> void:
	var graph := %LevelGraph as LevelGraph
	var coins_spent := graph.deposit_into(node_id, level_coins)
	if coins_spent > 0:
		_play_coin_sound()
	level_coins -= coins_spent
	_refresh_hud()


func _play_coin_sound() -> void:
	var player := %CoinSound as AudioStreamPlayer
	player.stop()
	player.play()


func _on_spin_finished(results: Array[StringName]) -> void:
	var payout: Winnings.Result = _winnings.evaluate(results)
	if payout.coins > 0:
		level_coins += payout.coins + GameState.coin_income_bonus()
	_refresh_hud()
	var graph := %LevelGraph as LevelGraph
	graph.launch_firewall_attacks()
	graph.apply_resources(payout.resources)
	%SlotMachine.set_can_spin(spins_remaining > 0)


func _on_coin_stolen(amount: int) -> void:
	level_coins = maxi(level_coins - amount, 0)
	_refresh_hud()


func _on_prestige_earned(amount: int, from_global_position: Vector2) -> void:
	var earned := GameState.grant_prestige(amount)
	if earned <= 0:
		return
	_prestige_in_flight += earned
	_send_hearts_to_counter(earned, from_global_position)


func _send_hearts_to_counter(count: int, from_global_position: Vector2) -> void:
	var flights := %PrestigeFlights as Node2D
	var speed := (%LevelGraph as LevelGraph).token_speed * HEART_SPEED_SCALE
	var path := PackedVector2Array([
		_to_flight_local(from_global_position),
		_to_flight_local(_prestige_counter_center()),
	])
	for index in count:
		var heart := heart_scene.instantiate() as ResourceToken
		flights.add_child(heart)
		heart.arrived.connect(_on_heart_arrived, CONNECT_ONE_SHOT)
		heart.begin(path, speed, heart_icon, HEART_SIZE, float(index) * HEART_SPACING / speed)


func _on_heart_arrived() -> void:
	_prestige_in_flight = maxi(_prestige_in_flight - 1, 0)
	level_prestige += 1
	_refresh_hud()


func _prestige_counter_center() -> Vector2:
	return (%PrestigeValue as Label).get_global_rect().get_center()


func _to_flight_local(global_point: Vector2) -> Vector2:
	var flights := %PrestigeFlights as Node2D
	return flights.get_global_transform().affine_inverse() * global_point


func _bank_prestige() -> void:
	var total := level_prestige + _prestige_in_flight
	if total <= 0:
		return
	GameState.resources["prestige"] = int(GameState.resources.get("prestige", 0)) + total
	level_prestige = 0
	_prestige_in_flight = 0


func _refresh_hud() -> void:
	%PrestigeLabel.text = tr("Prestige")
	%PrestigeValue.text = str(level_prestige)
	%CoinsLabel.text = tr("Coins")
	%CoinsValue.text = str(level_coins)
	%SpinsLabel.text = tr("Spins")
	%SpinsValue.text = str(spins_remaining)


func _on_help_toggled(pressed: bool) -> void:
	_help_on = pressed
	if _help_on and _hovered_note != null:
		_show_help_tooltip(_hovered_note)
		return
	_hide_help_tooltip()


func _on_note_help_entered(note: LevelNote) -> void:
	_hovered_note = note
	if _help_on:
		_show_help_tooltip(note)


func _on_note_help_exited(note: LevelNote) -> void:
	if _hovered_note != note:
		return
	_hovered_note = null
	_hide_help_tooltip()


func _show_help_tooltip(note: LevelNote) -> void:
	var tooltip := %HelpTooltip as PanelContainer
	%HelpTooltipText.text = note.full_help_text()
	tooltip.reset_size()
	tooltip.visible = true
	_follow_mouse_with_tooltip()
	set_process(true)


func _hide_help_tooltip() -> void:
	%HelpTooltip.visible = false
	set_process(false)


func _process(_delta: float) -> void:
	_follow_mouse_with_tooltip()


func _follow_mouse_with_tooltip() -> void:
	var tooltip := %HelpTooltip as PanelContainer
	var tooltip_size := tooltip.size
	var mouse := get_global_mouse_position()
	var pos := Vector2(mouse.x + 16.0, mouse.y - tooltip_size.y - 12.0)
	if pos.y < 8.0:
		pos.y = mouse.y + 20.0
	pos.x = clampf(pos.x, 8.0, maxf(size.x - tooltip_size.x - 8.0, 8.0))
	tooltip.global_position = pos
