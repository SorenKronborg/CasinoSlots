class_name UpgradeCard
extends PanelContainer

## One row in the upgrades list. It renders whatever state the run is in and asks
## to buy; RunState decides whether that is allowed.

signal buy_requested(id: StringName)

@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _buy_button: Button = %BuyButton

var _upgrade: UpgradeData


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)


func setup(upgrade: UpgradeData) -> void:
	_upgrade = upgrade
	_title.text = upgrade.title if not upgrade.title.is_empty() else String(upgrade.id)
	_description.text = upgrade.description


func refresh(state: RunState) -> void:
	if _upgrade == null:
		return

	if state.owns(_upgrade.id):
		_buy_button.text = "OWNED"
		_buy_button.disabled = true
		modulate = Color(1.0, 1.0, 1.0, 0.65)
		return

	modulate = Color.WHITE
	if not state.tree.is_available(_upgrade.id, state.purchased()):
		var prerequisite := state.tree.find(_upgrade.requires)
		var label := prerequisite.title if prerequisite != null else String(_upgrade.requires)
		_buy_button.text = "Needs %s" % label
		_buy_button.disabled = true
		return

	_buy_button.text = "Buy  %d" % _upgrade.cost
	_buy_button.disabled = not state.can_afford(_upgrade.cost)


func _on_buy_pressed() -> void:
	if _upgrade != null:
		buy_requested.emit(_upgrade.id)
