class_name UpgradeData
extends Resource

## One purchasable upgrade. Effects are declared as modifiers rather than code,
## so an upgrade that only moves a number is a new row in the tree resource and
## nothing else. Only a genuinely new mechanic needs a new field here.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var cost: int = 0

## Upgrade that must already be owned. Empty means this is a root of the tree.
@export var requires: StringName = &""

## Stake multiplier. Because PayTable.evaluate() computes payout * bet, raising
## this scales the cost and the winnings together.
@export var bet_multiplier: int = 1

## Applied to winnings on top of the stake, for upgrades that pay more without
## costing more.
@export var payout_multiplier: int = 1

@export var extra_reels: int = 0

## Feature flags the machine checks, such as &"auto_spin".
@export var unlocks: Array[StringName] = []


func describe() -> String:
	return "%s (%d credits)" % [title if not title.is_empty() else String(id), cost]
