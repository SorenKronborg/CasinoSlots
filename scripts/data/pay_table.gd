class_name PayTable
extends Resource

@export var rules: Array[PayRule] = []


## Returns {} for a losing line, otherwise {win, rule, positions}. Only the
## single highest-paying rule is awarded, which is the standard slot convention.
func evaluate(line: PackedInt32Array, bet: int) -> Dictionary:
	var best := {}
	for rule in rules:
		if rule == null:
			continue
		var hits := matching_positions(rule, line)
		if hits.is_empty():
			continue
		var win := rule.payout * bet
		if best.is_empty() or win > int(best["win"]):
			best = {"win": win, "rule": rule, "positions": hits}
	return best


## Reels that satisfy the rule, or an empty array if the threshold is not met.
func matching_positions(rule: PayRule, line: PackedInt32Array) -> PackedInt32Array:
	var hits := PackedInt32Array()
	if rule.any_position:
		for i in line.size():
			if _matches(line[i], rule):
				hits.append(i)
	else:
		for i in line.size():
			if not _matches(line[i], rule):
				break
			hits.append(i)
	if hits.size() < rule.count:
		return PackedInt32Array()
	return hits


func _matches(symbol: int, rule: PayRule) -> bool:
	if symbol == rule.symbol:
		return true
	if not rule.wilds_substitute:
		return false
	# A wild rule already matched by identity above; wilds do not stand in for
	# themselves when counting toward some other symbol.
	return symbol == Symbols.Kind.WILD and rule.symbol != Symbols.Kind.WILD


## True when every rule can be resolved from symbol counts alone, which is what
## SlotMath.exact_rtp() requires.
func is_count_only() -> bool:
	for rule in rules:
		if rule != null and not rule.any_position:
			return false
	return true
