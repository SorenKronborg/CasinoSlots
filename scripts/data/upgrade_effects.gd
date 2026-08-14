class_name UpgradeEffects
extends RefCounted

## Everything the owned upgrades add up to. The machine reads this instead of
## asking which upgrades exist, so buying a numeric upgrade never touches the
## machine's code.

var bet_multiplier := 1
var payout_multiplier := 1
var extra_reels := 0
var unlocked: Dictionary = {}


static func of(upgrades: Array[UpgradeData]) -> UpgradeEffects:
	var effects := UpgradeEffects.new()
	for upgrade in upgrades:
		if upgrade == null:
			continue
		effects.bet_multiplier *= maxi(1, upgrade.bet_multiplier)
		effects.payout_multiplier *= maxi(1, upgrade.payout_multiplier)
		effects.extra_reels += upgrade.extra_reels
		for flag in upgrade.unlocks:
			effects.unlocked[flag] = true
	return effects


func has(flag: StringName) -> bool:
	return unlocked.has(flag)
