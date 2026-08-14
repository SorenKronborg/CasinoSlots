class_name StripBuilder
extends RefCounted

## Builds the logical reel strip and its matching texture. Rarity is expressed
## purely as how many positions a symbol occupies on the strip, which is what
## makes the payout maths computable.

## Strip composition, keyed by Symbols.Kind. Totals 40 positions.
const DEFAULT_COUNTS := {
	Symbols.Kind.HEART: 10,
	Symbols.Kind.COIN: 9,
	Symbols.Kind.BAR: 8,
	Symbols.Kind.SEVEN: 6,
	Symbols.Kind.DIAMOND: 4,
	Symbols.Kind.WILD: 2,
	Symbols.Kind.JACKPOT: 1,
}


const MAX_REPAIR_PASSES := 8


## Spreads each symbol's occurrences evenly across the strip rather than
## shuffling. Random placement produces visible clumps of identical symbols
## while the reel is spinning, which looks cheap.
static func build_strip(counts: Dictionary = DEFAULT_COUNTS) -> PackedInt32Array:
	var entries: Array = []
	for kind in counts:
		var total: int = int(counts[kind])
		for i in total:
			# Fractional slot position; sorting by this interleaves the symbols.
			entries.append({"kind": int(kind), "key": (float(i) + 0.5) / float(total)})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["key"], b["key"]):
			return a["kind"] < b["kind"]
		return a["key"] < b["key"])

	var strip := PackedInt32Array()
	for entry in entries:
		strip.append(entry["kind"])
	return _separate_duplicates(strip)


## Even spreading still collides where the strip wraps, because the most common
## symbol's first and last entries end up adjacent. Local swaps fix that without
## disturbing the composition, so probabilities are unaffected.
static func _separate_duplicates(strip: PackedInt32Array) -> PackedInt32Array:
	var length := strip.size()
	if length < 3:
		return strip

	for _pass in MAX_REPAIR_PASSES:
		var collisions := _collision_count(strip)
		if collisions == 0:
			return strip
		for index in length:
			if strip[index] != strip[(index + 1) % length]:
				continue
			var target := (index + 1) % length
			for distance in range(2, length):
				var other := (target + distance) % length
				var candidate := strip.duplicate()
				candidate[target] = strip[other]
				candidate[other] = strip[target]
				var candidate_collisions := _collision_count(candidate)
				if candidate_collisions < collisions:
					strip = candidate
					collisions = candidate_collisions
					break

	if _collision_count(strip) > 0:
		push_warning("StripBuilder: could not fully separate identical neighbours; "
				+ "a symbol may occupy too much of the strip")
	return strip


static func _collision_count(strip: PackedInt32Array) -> int:
	var total := 0
	var length := strip.size()
	for i in length:
		if strip[i] == strip[(i + 1) % length]:
			total += 1
	return total


## Composites the strip into one tall texture, shared by every reel. n_rows is
## derived from strip.size() at the call site so the two cannot drift apart.
static func build_texture(strip: PackedInt32Array, symbol_set: SymbolSet, cell_px: int,
		padding := 0.12) -> ImageTexture:
	var atlas := Image.create_empty(cell_px, cell_px * strip.size(), false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	var cells := {}
	for row in strip.size():
		var kind := strip[row]
		if not cells.has(kind):
			cells[kind] = _render_cell(symbol_set.texture_of(kind), cell_px, padding)
		var cell: Image = cells[kind]
		atlas.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(0, row * cell_px))

	return ImageTexture.create_from_image(atlas)


## Scales one symbol to fit a square cell and centres it. Source icons are
## inconsistently sized (160-184px), so fitting is done per symbol.
static func _render_cell(texture: Texture2D, cell_px: int, padding: float) -> Image:
	var cell := Image.create_empty(cell_px, cell_px, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	if texture == null:
		push_warning("StripBuilder: symbol has no texture; leaving cell blank")
		return cell

	var source := texture.get_image()
	if source == null:
		push_warning("StripBuilder: texture has no image data; leaving cell blank")
		return cell

	source = source.duplicate()
	if source.is_compressed():
		source.decompress()
	# blit_rect requires both images to share a format.
	source.convert(Image.FORMAT_RGBA8)

	var inner := int(round(float(cell_px) * (1.0 - padding * 2.0)))
	var fit := minf(
		float(inner) / float(source.get_width()),
		float(inner) / float(source.get_height()))
	var width := maxi(1, int(round(float(source.get_width()) * fit)))
	var height := maxi(1, int(round(float(source.get_height()) * fit)))
	source.resize(width, height, Image.INTERPOLATE_LANCZOS)

	cell.blit_rect(source, Rect2i(Vector2i.ZERO, Vector2i(width, height)),
			Vector2i((cell_px - width) / 2, (cell_px - height) / 2))
	return cell
