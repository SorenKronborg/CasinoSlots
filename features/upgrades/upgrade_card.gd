class_name UpgradeCard
extends Button

signal purchased

var upgrade: UpgradeDefinition

@onready var _title: Label = %Title
@onready var _price_row: HBoxContainer = %PriceRow
@onready var _price: Label = %Price
@onready var _tooltip: PanelContainer = %Tooltip
@onready var _tooltip_text: Label = %TooltipText


func setup(definition: UpgradeDefinition) -> void:
	upgrade = definition
	mouse_entered.connect(_show_tooltip)
	mouse_exited.connect(_hide_tooltip)
	pressed.connect(_on_pressed)
	_hide_tooltip()
	refresh()


func refresh() -> void:
	if upgrade == null:
		return
	_title.text = tr(upgrade.title)
	_tooltip_text.text = upgrade.description
	var rank := GameState.rank_of(upgrade.id)
	if upgrade.is_maxed(rank):
		_price_row.visible = false
		disabled = true
		return
	var cost := upgrade.next_cost(rank)
	_price.text = str(cost)
	_price_row.visible = true
	disabled = false


func _on_pressed() -> void:
	if not GameState.try_purchase(upgrade.id):
		refresh()
		return
	purchased.emit()


func _show_tooltip() -> void:
	if upgrade == null:
		return
	_tooltip_text.text = upgrade.description
	_tooltip.visible = true


func _hide_tooltip() -> void:
	_tooltip.visible = false
