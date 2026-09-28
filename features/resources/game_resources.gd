class_name GameResources
extends RefCounted

const CHERRY := &"cherry"
const BELL := &"bell"
const WATERMELON := &"watermelon"
const DIAMOND := &"diamond"

const _CHERRY_COLOR := Color("#c62828")
const _BELL_COLOR := Color("#f9a825")
const _WATERMELON_COLOR := Color("#2e7d32")
const _DIAMOND_COLOR := Color("#1e88e5")


static func all() -> Array[StringName]:
	return [CHERRY, BELL, WATERMELON, DIAMOND]


static func color_of(resource_id: StringName) -> Color:
	match resource_id:
		CHERRY:
			return _CHERRY_COLOR
		BELL:
			return _BELL_COLOR
		WATERMELON:
			return _WATERMELON_COLOR
		DIAMOND:
			return _DIAMOND_COLOR
		_:
			return Color.WHITE
