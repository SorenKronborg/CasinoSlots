class_name UpgradeCard
extends Button

signal purchased

var upgrade: UpgradeDefinition

@onready var _title: Label = %Title
@onready var _rank: Label = %Rank
@onready var _price_row: HBoxContainer = %PriceRow
@onready var _price: Label = %Price
@onready var _tooltip: PanelContainer = %Tooltip
@onready var _tooltip_text: Label = %TooltipText

const AVAILABLE_COLOR := Color.WHITE
const UNAVAILABLE_COLOR := Color(0.42, 0.44, 0.42, 1)
const COMPLETED_COLOR := Color(0.45, 0.9, 0.55, 1)


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
	_rank.text = "%d/%d" % [rank, upgrade.max_rank()]
	if upgrade.is_maxed(rank):
		_price_row.visible = false
		disabled = true
		modulate = COMPLETED_COLOR
		return
	var cost := upgrade.next_cost(rank)
	_price.text = str(cost)
	_price_row.visible = true
	var available := GameState.is_upgrade_unlocked(upgrade.id)
	var affordable := GameState.prestige() >= cost
	disabled = not available or not affordable
	modulate = AVAILABLE_COLOR if not disabled else UNAVAILABLE_COLOR


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
