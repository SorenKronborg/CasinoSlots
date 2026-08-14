class_name SymbolData
extends Resource

## Presentation only. Payouts live in PayTable so there is a single place to
## reason about money.

@export var id: StringName = &""
@export var display_name: String = ""
@export var texture: Texture2D
@export var land_sfx: AudioStream
