class_name Upgrades
extends Control

## The upgrades screen. It renders the tree and forwards purchases to RunState;
## it does not decide what an upgrade does, and it does not decide what closing
## means either.

signal closed

const CARD_SCENE := "res://scenes/upgrades/upgrade_card.tscn"

## Assign before the screen enters the tree.
var state: RunState

@onready var _credits_label: Label = %CreditsLabel
@onready var _card_list: VBoxContainer = %CardList
@onready var _return_button: Button = %ReturnButton

var _cards: Array[UpgradeCard] = []


func _ready() -> void:
	_return_button.pressed.connect(_close)
	_return_button.grab_focus()

	if state == null:
		push_error("Upgrades: no RunState was assigned")
		return

	state.credits_changed.connect(_on_credits_changed)
	state.upgrades_changed.connect(_refresh)
	_build_cards()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		accept_event()


func _build_cards() -> void:
	var card_scene: PackedScene = load(CARD_SCENE)
	for upgrade in state.tree.upgrades:
		if upgrade == null:
			continue
		var card: UpgradeCard = card_scene.instantiate()
		_card_list.add_child(card)
		card.setup(upgrade)
		card.buy_requested.connect(_on_buy_requested)
		_cards.append(card)


## Every card is refreshed rather than just the one bought, because one purchase
## unlocks its successors and can price the rest out of reach.
func _refresh() -> void:
	_credits_label.text = "Credits %d" % state.credits
	for card in _cards:
		card.refresh(state)


func _on_credits_changed(_credits: int) -> void:
	_refresh()


func _on_buy_requested(id: StringName) -> void:
	state.purchase(id)


func _close() -> void:
	closed.emit()
