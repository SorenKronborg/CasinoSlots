class_name SlotMath
extends RefCounted

## Exact payout maths for a scatter-counting machine.
##
## Because a win depends only on how many of each symbol appeared, an outcome is
## fully described by a count vector across symbols. The number of those is
## C(reels + symbols - 1, symbols - 1) -- 56 for three reels, 8008 for ten --
## so every outcome can be enumerated with its multinomial probability. That is
## exact rather than sampled, and it handles wild substitution and
## only-highest-pays correctly, unlike the L^N combination brute force which
## becomes infeasible past four reels.

const MAX_FACTORIAL := 32

static var _factorials: PackedFloat64Array = PackedFloat64Array()


## Probability of each symbol appearing on a single reel, indexed by
## Symbols.Kind. Derived from the strip, so rarity always matches what the
## player actually sees.
static func reel_probabilities(strip: PackedInt32Array) -> PackedFloat64Array:
	var probabilities := PackedFloat64Array()
	probabilities.resize(Symbols.count())
	probabilities.fill(0.0)
	if strip.is_empty():
		return probabilities
	for symbol in strip:
		if symbol >= 0 and symbol < probabilities.size():
			probabilities[symbol] += 1.0
	for i in probabilities.size():
		probabilities[i] /= float(strip.size())
	return probabilities


## Returns {rtp, hit_frequency, outcomes}. RTP is the fraction of each bet
## returned to the player over infinite play.
static func analyse(reel_count: int, strip: PackedInt32Array, table: PayTable) -> Dictionary:
	if not table.is_count_only():
		push_warning("SlotMath: table contains positional rules, which cannot be "
				+ "resolved from symbol counts; those rules are ignored")

	var probabilities := reel_probabilities(strip)
	var counts := PackedInt32Array()
	counts.resize(probabilities.size())
	counts.fill(0)

	var accumulator := {"rtp": 0.0, "hit": 0.0, "outcomes": 0}
	_walk(0, reel_count, 1.0, counts, probabilities, table, accumulator)

	# The walk divides by each k! as it goes, so multiplying by reels! here turns
	# the accumulated products into multinomial probabilities.
	var scale := _factorial(reel_count)
	return {
		"rtp": float(accumulator["rtp"]) * scale,
		"hit_frequency": float(accumulator["hit"]) * scale,
		"outcomes": int(accumulator["outcomes"]),
	}


static func _walk(symbol: int, remaining: int, weight: float, counts: PackedInt32Array,
		probabilities: PackedFloat64Array, table: PayTable, accumulator: Dictionary) -> void:
	if symbol == probabilities.size() - 1:
		# Last symbol takes whatever reels are left, so the vector is complete.
		counts[symbol] = remaining
		var leaf := weight * pow(probabilities[symbol], remaining) / _factorial(remaining)
		var payout := best_payout(counts, table)
		accumulator["rtp"] = float(accumulator["rtp"]) + leaf * float(payout)
		if payout > 0:
			accumulator["hit"] = float(accumulator["hit"]) + leaf
		accumulator["outcomes"] = int(accumulator["outcomes"]) + 1
		return

	for taken in remaining + 1:
		counts[symbol] = taken
		_walk(symbol + 1, remaining - taken,
				weight * pow(probabilities[symbol], taken) / _factorial(taken),
				counts, probabilities, table, accumulator)


## Highest payout awarded for a given count vector. Comparing across every rule
## gives only-highest-pays for free, and because payouts escalate with count the
## maximum also picks the highest tier each symbol reached.
static func best_payout(counts: PackedInt32Array, table: PayTable) -> int:
	var wilds := counts[Symbols.Kind.WILD]
	var best := 0
	for rule in table.rules:
		if rule == null or not rule.any_position:
			continue
		var matched := counts[rule.symbol]
		if rule.wilds_substitute and rule.symbol != Symbols.Kind.WILD:
			matched += wilds
		if matched >= rule.count and rule.payout > best:
			best = rule.payout
	return best


static func _factorial(n: int) -> float:
	if _factorials.is_empty():
		_factorials.resize(MAX_FACTORIAL + 1)
		_factorials[0] = 1.0
		for i in range(1, MAX_FACTORIAL + 1):
			_factorials[i] = _factorials[i - 1] * float(i)
	if n < 0 or n > MAX_FACTORIAL:
		push_error("SlotMath: factorial out of range: %d" % n)
		return 1.0
	return _factorials[n]
