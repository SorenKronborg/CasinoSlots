class_name SymbolSet
extends Resource

## Symbols in Symbols.Kind order. The ordering is load-bearing rather than
## cosmetic, so it is checked rather than trusted.
@export var symbols: Array[SymbolData] = []


## Returns a list of human-readable problems; empty means the set is usable.
## Deliberately not an assert(), since assertions are stripped from release
## builds and an ordering desync pays out wrongly without ever crashing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var names: Array = Symbols.Kind.keys()
	if symbols.size() != names.size():
		problems.append("expected %d symbols, found %d" % [names.size(), symbols.size()])
	for i in mini(symbols.size(), names.size()):
		var entry := symbols[i]
		if entry == null:
			problems.append("slot %d (%s) is empty" % [i, names[i]])
			continue
		if entry.id != StringName(names[i]):
			problems.append("slot %d should be %s but holds '%s'" % [i, names[i], entry.id])
		if entry.texture == null:
			problems.append("%s has no texture" % names[i])
	return problems


func data(kind: int) -> SymbolData:
	if kind < 0 or kind >= symbols.size():
		return null
	return symbols[kind]


func texture_of(kind: int) -> Texture2D:
	var entry := data(kind)
	return entry.texture if entry != null else null


func display_name_of(kind: int) -> String:
	var entry := data(kind)
	if entry == null or entry.display_name.is_empty():
		return Symbols.name_of(kind)
	return entry.display_name
