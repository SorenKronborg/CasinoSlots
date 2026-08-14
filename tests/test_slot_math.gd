extends SceneTree

## Payout maths verification. No addon dependency, so it runs as:
##
##   godot --headless --script tests/test_slot_math.gd
##
## Exits non-zero on failure, which makes it usable as a CI gate. Every change to
## a strip count or a payout moves the RTP, often in ways that are not intuitive,
## so this is worth running on every such change.

const PAY_TABLE_PATH := "res://resources/paytables/default.tres"
const REEL_COUNT := 3

## Intended return per machine width. The 4-wide machine is the fourth_reel
## upgrade, and it is deliberately generous: three of a kind is far easier to
## reach across four reels, so the player wins in the long run.
const RTP_BANDS := {
	3: [0.90, 0.96],
	4: [2.80, 2.95],
}

var _failures := 0


func _initialize() -> void:
	var table: PayTable = load(PAY_TABLE_PATH)
	if table == null:
		push_error("could not load %s" % PAY_TABLE_PATH)
		quit(1)
		return

	var strip := StripBuilder.build_strip()

	_test_strip(strip)
	_test_probabilities(strip)
	_report_paytable(table)
	var rtp := _test_rtp(strip, table)
	_test_matches_brute_force(strip, table, rtp)
	_test_widths(strip, table)

	print("")
	if _failures == 0:
		print("all checks passed")
	else:
		print("%d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_strip(strip: PackedInt32Array) -> void:
	print("== strip ==")
	var expected_length := 0
	for kind in StripBuilder.DEFAULT_COUNTS:
		expected_length += int(StripBuilder.DEFAULT_COUNTS[kind])
	_check(strip.size() == expected_length,
			"strip length is %d, expected %d" % [strip.size(), expected_length])

	for kind in StripBuilder.DEFAULT_COUNTS:
		var wanted := int(StripBuilder.DEFAULT_COUNTS[kind])
		var found := 0
		for symbol in strip:
			if symbol == int(kind):
				found += 1
		_check(found == wanted, "%s appears %d times, expected %d"
				% [Symbols.name_of(int(kind)), found, wanted])

	# The builder interleaves rather than shuffles, so no symbol should ever sit
	# next to itself. Clumps look cheap while the reel is spinning.
	var adjacent := 0
	for i in strip.size():
		if strip[i] == strip[(i + 1) % strip.size()]:
			adjacent += 1
	_check(adjacent == 0, "%d adjacent duplicate pair(s) on the strip" % adjacent)


func _test_probabilities(strip: PackedInt32Array) -> void:
	print("")
	print("== per-reel probability ==")
	var probabilities := SlotMath.reel_probabilities(strip)
	var total := 0.0
	for p in probabilities:
		total += p
	_check(is_equal_approx(total, 1.0), "probabilities sum to %.6f, expected 1.0" % total)

	var wilds := probabilities[Symbols.Kind.WILD]
	for kind in Symbols.count():
		if kind == Symbols.Kind.WILD:
			continue
		var effective := probabilities[kind] + wilds
		print("  %-8s p=%.4f  with wilds q=%.4f  q^%d=%.6f"
				% [Symbols.name_of(kind), probabilities[kind], effective, REEL_COUNT,
				pow(effective, REEL_COUNT)])


func _report_paytable(table: PayTable) -> void:
	print("")
	print("== paytable ==")
	_check(table.is_count_only(),
			"every rule must be any_position for the exact analysis to apply")
	for rule in table.rules:
		print("  %s" % rule.describe())


func _test_rtp(strip: PackedInt32Array, table: PayTable) -> float:
	print("")
	print("== exact analysis ==")
	var result := SlotMath.analyse(REEL_COUNT, strip, table)
	var rtp := float(result["rtp"])
	print("  outcomes enumerated: %d" % int(result["outcomes"]))
	print("  RTP:            %.4f" % rtp)
	print("  hit frequency:  %.4f" % float(result["hit_frequency"]))

	_check_band(REEL_COUNT, rtp)
	return rtp


## Cross-checks the multinomial enumeration against the naive L^N brute force,
## which is still cheap at three reels. This is what proves the two independent
## implementations agree; past four reels only the multinomial one is viable.
func _test_matches_brute_force(strip: PackedInt32Array, table: PayTable, exact_rtp: float) -> void:
	print("")
	print("== brute-force cross-check ==")
	if REEL_COUNT != 3:
		print("  skipped: the nested loops below assume three reels")
		return
	var length := strip.size()
	var combinations := 0
	var total_win := 0
	var line := PackedInt32Array()
	line.resize(REEL_COUNT)

	for a in length:
		line[0] = strip[a]
		for b in length:
			line[1] = strip[b]
			for c in length:
				line[2] = strip[c]
				var result := table.evaluate(line, 1)
				total_win += int(result.get("win", 0))
				combinations += 1

	var brute_rtp := float(total_win) / float(combinations)
	print("  combinations:   %d" % combinations)
	print("  RTP:            %.4f" % brute_rtp)
	_check(absf(brute_rtp - exact_rtp) < 0.0001,
			"brute force RTP %.6f disagrees with exact %.6f" % [brute_rtp, exact_rtp])


## Every width the machine can reach through upgrades, so adding a reel cannot
## quietly change the return without this failing.
func _test_widths(strip: PackedInt32Array, table: PayTable) -> void:
	print("")
	print("== machine widths ==")
	var widths: Array = RTP_BANDS.keys()
	widths.sort()
	for width in widths:
		var reels := int(width)
		var result := SlotMath.analyse(reels, strip, table)
		var rtp := float(result["rtp"])
		print("  %d reels: RTP %.4f  hit %.4f  outcomes %d"
				% [reels, rtp, float(result["hit_frequency"]), int(result["outcomes"])])
		_check_band(reels, rtp)

		var weighted := _weighted_rtp(reels, strip, table)
		_check(absf(weighted - rtp) < 0.0001,
				"%d reels: weighted enumeration %.6f disagrees with exact %.6f"
				% [reels, weighted, rtp])


## Second opinion on the multinomial walk: enumerate symbol tuples weighted by
## their per-reel probability. That is 7^N lines rather than the 40^N strip
## positions the brute force above needs, so it stays cheap past three reels.
func _weighted_rtp(reels: int, strip: PackedInt32Array, table: PayTable) -> float:
	var line := PackedInt32Array()
	line.resize(reels)
	return _walk_weighted(0, 1.0, line, SlotMath.reel_probabilities(strip), table)


func _walk_weighted(depth: int, weight: float, line: PackedInt32Array,
		probabilities: PackedFloat64Array, table: PayTable) -> float:
	if depth == line.size():
		return weight * float(table.evaluate(line, 1).get("win", 0))

	var total := 0.0
	for symbol in probabilities.size():
		if probabilities[symbol] <= 0.0:
			continue
		line[depth] = symbol
		total += _walk_weighted(depth + 1, weight * probabilities[symbol], line,
				probabilities, table)
	return total


func _check_band(width: int, rtp: float) -> void:
	if not RTP_BANDS.has(width):
		return
	var band: Array = RTP_BANDS[width]
	_check(rtp >= float(band[0]) and rtp <= float(band[1]),
			"%d reels: RTP %.4f is outside the intended %.2f-%.2f band"
			% [width, rtp, float(band[0]), float(band[1])])


func _check(condition: bool, failure_message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % failure_message)
