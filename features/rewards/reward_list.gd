extends Control

const ICON_SIZE := Vector2(28, 28)
const SYMBOL_COLUMN_WIDTH := 180.0
const COUNT_COLUMN_WIDTH := 96.0
const COIN_COLOR := Color(1, 0.85, 0.1, 1)
const RESOURCE_COLOR := Color(1, 1, 1, 1)
const MUTED_COLOR := Color(0.56, 0.58, 0.56, 1)
const EMPTY_MARK := "—"
const HEADER_FONT_SIZE := 18
const NAME_FONT_SIZE := 18
const COINS_FONT_SIZE := 20
const RESOURCE_FONT_SIZE := 15

@export var slot_machine_scene: PackedScene
@export var row_stripe: StyleBox
@export var row_plain: StyleBox
@export_file("*.tscn") var idle_game_scene_path: String


func _ready() -> void:
	%Title.text = tr("Reward List")
	%Hint.text = tr("Reward List Hint")
	%CoinsLegend.text = tr("Coins")
	%ResourcesLegend.text = tr("Resources")
	%Back.text = tr("Back")
	_build_table()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(idle_game_scene_path)


func _build_table() -> void:
	var winnings := Winnings.new()
	var rules := winnings.rules()
	var counts := _match_counts(rules)
	var icons := _symbol_icons()
	%Rows.add_child(_header_row(counts))
	var striped := true
	for symbol in _symbols_in_order(rules):
		%Rows.add_child(_symbol_row(symbol, icons.get(symbol) as Texture2D, counts, rules, striped))
		striped = not striped


func _match_counts(rules: Array[Winnings.Rule]) -> Array[int]:
	var counts: Array[int] = []
	for rule in rules:
		if not counts.has(rule.count):
			counts.append(rule.count)
	counts.sort()
	return counts


func _symbols_in_order(rules: Array[Winnings.Rule]) -> Array[StringName]:
	var symbols: Array[StringName] = []
	for rule in rules:
		if not symbols.has(rule.symbol):
			symbols.append(rule.symbol)
	return symbols


func _rule_for(rules: Array[Winnings.Rule], symbol: StringName, count: int) -> Winnings.Rule:
	for rule in rules:
		if rule.symbol == symbol and rule.count == count:
			return rule
	return null


func _header_row(counts: Array[int]) -> Control:
	var row := _row_panel(false)
	var cells := _row_cells(row)
	cells.add_child(_spacer(SYMBOL_COLUMN_WIDTH))
	for count in counts:
		cells.add_child(_cell_label("x%d" % count, MUTED_COLOR, HEADER_FONT_SIZE))
	return row


func _symbol_row(
		symbol: StringName,
		icon: Texture2D,
		counts: Array[int],
		rules: Array[Winnings.Rule],
		striped: bool
) -> Control:
	var row := _row_panel(striped)
	var cells := _row_cells(row)
	cells.add_child(_symbol_cell(symbol, icon))
	for count in counts:
		cells.add_child(_payout_cell(_rule_for(rules, symbol, count)))
	return row


func _row_panel(striped: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := row_stripe if striped else row_plain
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	return panel


func _row_cells(row: PanelContainer) -> HBoxContainer:
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 0)
	row.add_child(cells)
	return cells


func _symbol_cell(symbol: StringName, icon: Texture2D) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size.x = SYMBOL_COLUMN_WIDTH
	cell.add_theme_constant_override("separation", 10)
	var image := TextureRect.new()
	image.texture = icon
	image.custom_minimum_size = ICON_SIZE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell.add_child(image)
	var name_label := Label.new()
	name_label.text = tr(String(symbol).capitalize())
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", RESOURCE_COLOR)
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	cell.add_child(name_label)
	return cell


func _payout_cell(rule: Winnings.Rule) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = COUNT_COLUMN_WIDTH
	cell.add_theme_constant_override("separation", 0)
	if rule == null:
		cell.add_child(_cell_label(EMPTY_MARK, MUTED_COLOR, COINS_FONT_SIZE))
		return cell
	var coins_color := COIN_COLOR if rule.coins > 0 else MUTED_COLOR
	cell.add_child(_cell_label(_amount_text(rule.coins), coins_color, COINS_FONT_SIZE))
	cell.add_child(_cell_label(_amount_text(rule.resource_amount), RESOURCE_COLOR, RESOURCE_FONT_SIZE))
	return cell


func _amount_text(amount: int) -> String:
	return str(amount) if amount > 0 else EMPTY_MARK


func _cell_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = COUNT_COLUMN_WIDTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	return spacer


func _symbol_icons() -> Dictionary:
	if slot_machine_scene == null:
		return {}
	var machine := slot_machine_scene.instantiate() as SlotMachine
	if machine == null:
		return {}
	var icons := machine.symbol_icon_map()
	machine.free()
	return icons
