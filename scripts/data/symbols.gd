class_name Symbols
extends Object

enum Kind { CHERRY, WATERMELON, BELL, SEVEN, STAR }

const COUNT := 5

const PATHS: PackedStringArray = [
	"res://assets/icons/cherry.svg",
	"res://assets/icons/watermelon.svg",
	"res://assets/icons/bell.svg",
	"res://assets/icons/seven.svg",
	"res://assets/icons/star.png",
]


static func texture(kind: int) -> Texture2D:
	return load(PATHS[kind]) as Texture2D
