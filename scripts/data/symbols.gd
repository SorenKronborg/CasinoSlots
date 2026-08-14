class_name Symbols
extends RefCounted

## Authoritative symbol ordering. The index of each entry is used directly as
## the strip value, the SymbolSet array index, and the SlotMath count-vector
## index, so reordering this enum invalidates every authored resource.
enum Kind {
	HEART,
	COIN,
	BAR,
	SEVEN,
	DIAMOND,
	WILD,
	JACKPOT,
}


static func count() -> int:
	return Kind.size()


static func name_of(kind: int) -> String:
	var names: Array = Kind.keys()
	if kind < 0 or kind >= names.size():
		return "UNKNOWN(%d)" % kind
	return String(names[kind])
