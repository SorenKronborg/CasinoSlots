class_name Winnings
extends RefCounted

const DEFAULT_PATH := "res://resources/slot/winnings.csv"

class Rule:
	var id: String = ""
	var symbol: StringName = &""
	var count: int = 0
	var coins: int = 0
	var resource: StringName = &""
	var resource_amount: int = 0


class Result:
	var coins: int = 0
	var resources: Dictionary = {}
	var matched_ids: PackedStringArray = []


var _rules: Array[Rule] = []


func _init(path: String = DEFAULT_PATH) -> void:
	_load_csv(path)


func evaluate(reel_symbols: Array[StringName]) -> Result:
	var counts: Dictionary = {}
	for symbol in reel_symbols:
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	var result := Result.new()
	for rule in _rules:
		if int(counts.get(rule.symbol, 0)) != rule.count:
			continue
		result.coins += rule.coins
		result.resources[rule.resource] = int(result.resources.get(rule.resource, 0)) + rule.resource_amount
		result.matched_ids.append(rule.id)
	return result


func _load_csv(path: String) -> void:
	_rules.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open winnings table: %s" % path)
		return
	var header := file.get_csv_line()
	var columns: Dictionary = {}
	for i in header.size():
		columns[String(header[i])] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or (row.size() == 1 and String(row[0]).strip_edges() == ""):
			continue
		if String(row[0]) == "id":
			continue
		var rule := Rule.new()
		rule.id = _cell(row, columns, "id")
		rule.symbol = StringName(_cell(row, columns, "symbol"))
		rule.count = int(_cell(row, columns, "count"))
		rule.coins = int(_cell(row, columns, "coins"))
		rule.resource = StringName(_cell(row, columns, "resource"))
		rule.resource_amount = int(_cell(row, columns, "resource_amount"))
		_rules.append(rule)


func _cell(row: PackedStringArray, columns: Dictionary, name: String) -> String:
	if not columns.has(name):
		return ""
	var index := int(columns[name])
	if index < 0 or index >= row.size():
		return ""
	return String(row[index]).strip_edges()
