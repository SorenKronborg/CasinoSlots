class_name UpgradeTree
extends Resource

## The catalogue of upgrades. Each entry names at most one prerequisite, which is
## all a branching tree needs: a chain is just the degenerate case.

@export var upgrades: Array[UpgradeData] = []


func find(id: StringName) -> UpgradeData:
	for upgrade in upgrades:
		if upgrade != null and upgrade.id == id:
			return upgrade
	return null


## Whether the prerequisite chain allows buying this now, ignoring cost.
func is_available(id: StringName, purchased: Array[StringName]) -> bool:
	var upgrade := find(id)
	if upgrade == null or purchased.has(id):
		return false
	return upgrade.requires.is_empty() or purchased.has(upgrade.requires)


## Returns a list of human-readable problems; empty means the tree is usable.
## A typo in an id silently makes an upgrade unreachable rather than failing
## loudly, so it is checked rather than trusted.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen: Dictionary = {}
	for i in upgrades.size():
		var upgrade := upgrades[i]
		if upgrade == null:
			problems.append("slot %d is empty" % i)
			continue
		if upgrade.id.is_empty():
			problems.append("slot %d has no id" % i)
			continue
		if seen.has(upgrade.id):
			problems.append("duplicate id '%s'" % upgrade.id)
		seen[upgrade.id] = true
		if upgrade.cost < 0:
			problems.append("'%s' has a negative cost" % upgrade.id)

	for upgrade in upgrades:
		if upgrade == null or upgrade.requires.is_empty():
			continue
		if find(upgrade.requires) == null:
			problems.append("'%s' requires unknown upgrade '%s'"
					% [upgrade.id, upgrade.requires])
		elif upgrade.requires == upgrade.id:
			problems.append("'%s' requires itself" % upgrade.id)
	return problems
