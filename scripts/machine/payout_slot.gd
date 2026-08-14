class_name PayoutSlot
extends Control

## The hole winnings come out of. One call per win; the coins are decoration and
## carry no state the machine needs back.
##
## Coins are plain sprites moved by hand rather than a particle system, so a
## burst is a countable number of coins with a known lifetime instead of an
## emission rate to tune, and the whole thing can be checked headlessly.

@export var coin_texture: Texture2D

## Rendered size of a coin, in pixels.
@export var coin_px := 26

## Ceiling on a single burst, and therefore on the pool.
@export_range(1, 64) var max_coins := 24

## Deliberately heavy. A slow arc lets coins drift outside the cabinet before
## they land, which reads as scattered debris rather than a payout.
@export var gravity := 1400.0
@export var speed_min := 340.0
@export var speed_max := 450.0

## Half-angle of the spray either side of straight up, in radians. Wide enough to
## fan across the tray, narrow enough that the arc peaks below the hold buttons.
@export var spread := 0.52

## Delay between coins. A payout is a stream rather than a single puff, and
## staggering also keeps the coins from overlapping into one clump.
@export var launch_interval := 0.045

@export var life_min := 0.7
@export var life_max := 0.95

## Fraction of a coin's life spent fading out.
@export_range(0.0, 1.0) var fade_fraction := 0.55

## How far below the slot a coin may fall before it is taken back, so coins
## vanish into the tray they came from instead of sinking through the cabinet.
@export var catch_depth := 24.0

@onready var _coin_layer: Node2D = %Coins
@onready var _lip: Panel = %Lip

var _coins: Array[Sprite2D] = []
var _velocities: Array[Vector2] = []
var _spins: PackedFloat64Array = PackedFloat64Array()
var _lives: PackedFloat64Array = PackedFloat64Array()
var _totals: PackedFloat64Array = PackedFloat64Array()

## Coins still waiting to be thrown, and the countdown to the next one.
var _queued := 0
var _next_launch := 0.0
var _rng := RandomNumberGenerator.new()


var _coin_scale := 1.0


func _ready() -> void:
	_rng.randomize()
	if coin_texture != null:
		_coin_scale = float(coin_px) / float(maxi(1, coin_texture.get_width()))
	set_process(false)


## Throws coins out of the hole. The count follows the win as a multiple of the
## stake, so raising the stake does not inflate every burst.
func burst(win: int, bet: int) -> void:
	if win <= 0:
		return

	var multiple := float(win) / float(maxi(1, bet))
	var count := clampi(3 + int(sqrt(multiple) * 2.5), 3, max_coins)

	# The first coin leaves immediately so the burst lines up with the win being
	# announced; the rest follow as a stream.
	_launch()
	_queued = count - 1
	_next_launch = launch_interval
	set_process(true)


## Coins thrown but not yet spent, including any still queued behind the stream.
func pending_coins() -> int:
	return _queued + active_coins()


func active_coins() -> int:
	var active := 0
	for i in _coins.size():
		if _coins[i].visible:
			active += 1
	return active


func pool_size() -> int:
	return _coins.size()


func _launch() -> void:
	var index := _take_coin()
	if index < 0:
		return

	# Spawning inside the mouth rather than above it means the first frames are
	# hidden behind the lip, so the coin rises into view out of the hole.
	var origin := Vector2(size.x * 0.5, _lip.position.y + _lip.size.y * 0.4)
	var coin := _coins[index]
	coin.position = origin + Vector2(_rng.randf_range(-1.0, 1.0) * size.x * 0.34, 0.0)
	coin.rotation = _rng.randf_range(0.0, TAU)
	coin.modulate.a = 1.0
	# A little size variance so a dense stream reads as depth rather than a wall.
	coin.scale = Vector2.ONE * _coin_scale * _rng.randf_range(0.82, 1.15)
	coin.visible = true

	var angle := -PI * 0.5 + _rng.randf_range(-spread, spread)
	_velocities[index] = Vector2.from_angle(angle) * _rng.randf_range(speed_min, speed_max)
	_spins[index] = _rng.randf_range(-8.0, 8.0)
	_totals[index] = _rng.randf_range(life_min, life_max)
	_lives[index] = _totals[index]


## An idle coin, or a new one while the pool is still under its ceiling.
func _take_coin() -> int:
	for i in _coins.size():
		if not _coins[i].visible:
			return i
	if _coins.size() >= max_coins:
		return -1

	var coin := Sprite2D.new()
	coin.texture = coin_texture
	coin.visible = false
	_coin_layer.add_child(coin)

	_coins.append(coin)
	_velocities.append(Vector2.ZERO)
	_spins.append(0.0)
	_lives.append(0.0)
	_totals.append(0.0)
	return _coins.size() - 1


func _process(delta: float) -> void:
	if _queued > 0:
		_next_launch -= delta
		# A loop rather than one per frame, so a long frame releases the coins it
		# owes instead of stretching the stream out.
		while _queued > 0 and _next_launch <= 0.0:
			_next_launch += launch_interval
			_queued -= 1
			_launch()

	var active := 0
	for i in _coins.size():
		var coin := _coins[i]
		if not coin.visible:
			continue

		_lives[i] -= delta
		if _lives[i] <= 0.0:
			coin.visible = false
			continue

		_velocities[i].y += gravity * delta
		coin.position += _velocities[i] * delta
		coin.rotation += _spins[i] * delta

		if _velocities[i].y > 0.0 and coin.position.y > size.y + catch_depth:
			coin.visible = false
			continue

		var fade := _totals[i] * fade_fraction
		coin.modulate.a = minf(1.0, _lives[i] / maxf(0.001, fade))
		active += 1

	# Nothing in the air and nothing owed, so stop costing frames until the next
	# win.
	if active == 0 and _queued == 0:
		set_process(false)
