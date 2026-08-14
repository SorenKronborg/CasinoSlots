shader_type canvas_item;

// Renders one visible cell of a tall vertical symbol strip. The whole reel is a
// single quad; scrolling is a UV offset, and repeat_enable makes the strip wrap
// seamlessly without any extra geometry.

// No mipmaps: minified levels of a tall strip atlas bleed neighbouring cells
// into each other, and the reel is never drawn small enough to need them.
uniform sampler2D strip : repeat_enable, filter_linear;

// Number of symbol cells in the strip texture. Driven from strip.size() so it
// can never disagree with the logical reel.
uniform float n_rows = 40.0;

// Scroll position measured in whole strip cycles.
uniform float y_offset = 0.0;

// Vertical smear in cells, scaled by reel speed. Without this the reel reads as
// a scrolling spreadsheet rather than a spinning drum.
uniform float blur = 0.0;

const int TAPS = 7;

void fragment() {
	vec2 uv = vec2(UV.x, UV.y / n_rows + y_offset);

	if (blur < 0.001) {
		COLOR = texture(strip, uv);
	} else {
		// Spread the taps across `blur` cells worth of strip, centred on uv.
		float span = blur / n_rows;
		float step_size = span / float(TAPS - 1);
		vec4 sum = vec4(0.0);
		for (int i = 0; i < TAPS; i++) {
			float t = float(i) - float(TAPS - 1) * 0.5;
			sum += texture(strip, vec2(uv.x, uv.y + t * step_size));
		}
		COLOR = sum / float(TAPS);
	}
}
