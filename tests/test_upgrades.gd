extends SceneTree

## Upgrade tree and wallet verification. No addon dependency, so it runs as:
##
##   godot --headless --script tests/test_upgrades.gd
##
## Exits non-zero on failure. This covers the rules that decide whether a player
## gets something for free, so it is worth running on every change to the tree.

const TREE_PATH := "res://resources/upgrades/default_tree.tres"

var _failures := 0


func _initialize() -> void:
	var tree: UpgradeTree = load(TREE_PATH)
	if tree == null:
		push_error("could not load %s" % TREE_PATH)
		quit(1)
		return

	_test_tree(tree)
	_test_wallet(tree)
	_test_purchase_order(tree)
	_test_affordability(tree)
	_test_effects(tree)

	print("")
	if _failures == 0:
		print("all checks passed")
	else:
		print("%d check(s) failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_tree(tree: UpgradeTree) -> void:
	print("== tree ==")
	var problems := tree.validate()
	for problem in problems:
		_check(false, problem)
	for upgrade in tree.upgrades:
		print("  %-14s %-14s requires %s"
				% [upgrade.id, "%d credits" % upgrade.cost,
				upgrade.requires if not upgrade.requires.is_empty() else "-"])


func _test_wallet(tree: UpgradeTree) -> void:
	print("")
	print("== wallet ==")
	var state := RunState.new(tree)
	_check(state.credits == 1000, "a new run starts with %d credits, expected 1000"
			% state.credits)

	var reported := []
	state.credits_changed.connect(func(credits: int) -> void: reported.append(credits))
	state.award(50)
	_check(state.credits == 1050, "award(50) left %d" % state.credits)
	_check(state.spend(50), "spend(50) was refused with 1050 credits")
	_check(state.credits == 1000, "spend(50) left %d" % state.credits)
	_check(reported == [1050, 1000], "credits_changed reported %s" % str(reported))
	_check(not state.spend(5000), "spending more than the balance was allowed")
	_check(state.credits == 1000, "a refused spend still moved the balance to %d"
			% state.credits)


func _test_purchase_order(tree: UpgradeTree) -> void:
	print("")
	print("== purchase order ==")
	var state := RunState.new(tree)

	_check(not state.purchase(&"auto_spin"), "auto_spin was bought before double_stake")
	_check(not state.purchase(&"fourth_reel"), "fourth_reel was bought out of order")
	_check(state.credits == 1000, "a refused purchase still charged %d credits"
			% (1000 - state.credits))
	_check(not state.purchase(&"nonexistent"), "an unknown upgrade was bought")

	_check(state.purchase(&"double_stake"), "double_stake could not be bought")
	_check(state.credits == 990, "double_stake left %d credits, expected 990"
			% state.credits)
	_check(not state.purchase(&"double_stake"), "double_stake was bought twice")
	_check(state.credits == 990, "the second purchase charged again")

	_check(state.purchase(&"auto_spin"), "auto_spin could not be bought after its prerequisite")
	_check(state.purchase(&"fourth_reel"), "fourth_reel could not be bought last")
	_check(state.credits == 765, "buying all three left %d credits, expected 765"
			% state.credits)
	_check(state.purchased() == [&"double_stake", &"auto_spin", &"fourth_reel"],
			"purchase order recorded as %s" % str(state.purchased()))


func _test_affordability(tree: UpgradeTree) -> void:
	print("")
	print("== affordability ==")
	var state := RunState.new(tree, 9)
	_check(not state.purchase(&"double_stake"), "a 10 credit upgrade was bought with 9")
	_check(state.credits == 9, "the refused purchase moved the balance to %d" % state.credits)

	state.award(1)
	_check(state.purchase(&"double_stake"), "10 credits was not enough for a 10 credit upgrade")
	_check(state.credits == 0, "the purchase left %d rather than 0" % state.credits)


func _test_effects(tree: UpgradeTree) -> void:
	print("")
	print("== effects ==")
	var state := RunState.new(tree)

	var effects := state.effects()
	_check(effects.bet_multiplier == 1, "a fresh run reports bet x%d" % effects.bet_multiplier)
	_check(effects.extra_reels == 0, "a fresh run reports %d extra reels" % effects.extra_reels)
	_check(not effects.has(&"auto_spin"), "a fresh run already has auto_spin")

	state.purchase(&"double_stake")
	effects = state.effects()
	_check(effects.bet_multiplier == 2, "double_stake reports bet x%d" % effects.bet_multiplier)

	state.purchase(&"auto_spin")
	effects = state.effects()
	_check(effects.has(&"auto_spin"), "auto_spin was not unlocked")

	state.purchase(&"fourth_reel")
	effects = state.effects()
	_check(effects.extra_reels == 1, "fourth_reel reports %d extra reels" % effects.extra_reels)
	_check(effects.bet_multiplier == 2, "owning everything reports bet x%d"
			% effects.bet_multiplier)
	print("  all owned: bet x%d, payout x%d, +%d reels, flags %s"
			% [effects.bet_multiplier, effects.payout_multiplier, effects.extra_reels,
			str(effects.unlocked.keys())])


func _check(condition: bool, failure_message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % failure_message)
