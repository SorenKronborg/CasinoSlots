class_name PayRule
extends Resource

@export var symbol: Symbols.Kind = Symbols.Kind.HEART

## Minimum matching symbols required for this rule to pay.
@export_range(1, 20) var count: int = 3

## Multiplier applied to the bet.
@export var payout: int = 1

## true counts matches anywhere on the line (scatter style), false requires an
## unbroken run starting at the leftmost reel.
@export var any_position: bool = true

## Scatter-style bonus symbols normally opt out of wild substitution.
@export var wilds_substitute: bool = true


func describe() -> String:
	var prefix := "%dx %s" % [count, Symbols.name_of(symbol)]
	if not any_position:
		prefix += " (from left)"
	return "%s pays %d" % [prefix, payout]
