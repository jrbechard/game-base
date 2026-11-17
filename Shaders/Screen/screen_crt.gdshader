shader_type canvas_item;
render_mode unshaded;

// ===========================================================================
//  Unified CRT shader for Ever Blue.
//  - is_pointer = false : screen pass. Samples the curved back buffer, supports
//    pixelation, opaque output.
//  - is_pointer = true  : pointer pass. Samples its own sprite atlas (flat),
//    silhouette alpha preserved. Pixelation snaps to the screen's virtual grid
//    in screen space, so the cursor's chunky cells match the screen's.
//  Curvature drives sampling and scanlines. The phosphor mask is keyed to
//  physical screen pixels (FRAGCOORD) in BOTH modes, so the cells stay a uniform
//  grid across the curved frame and the screen/pointer lattices stay aligned.
// ===========================================================================

// Mode
uniform bool is_pointer = false;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

// CRT
uniform float curvature            : hint_range(5.0, 20.0)  = 12.0;
uniform float overscan             : hint_range(1.0, 1.5)   = 1.1;
uniform float vignette_multiplier  : hint_range(0.0, 1.0)   = 0.5;
uniform float scanline_opacity     : hint_range(0.0, 1.0)   = 0.1;
uniform float scanline_lightness   : hint_range(0.9, 1.1)   = 1.05;
uniform float scanline_count       : hint_range(1.0, 200.0) = 108.0;

// Chromatic Aberration
uniform float aberration_x : hint_range(-10.0, 10.0) = 2.0;
uniform float aberration_y : hint_range(-10.0, 10.0) = 0.0;

// Halation
uniform float halation_threshold : hint_range(0.0, 1.0)  = 0.6;
uniform float halation_intensity : hint_range(0.0, 2.0)  = 0.4;
uniform float halation_radius    : hint_range(0.0, 10.0) = 3.0;
uniform vec3  halation_color     : source_color          = vec3(1.0, 0.3, 0.1);

// Pixelation (virtual resolution) — drives the screen pass and, in screen
// space, the pointer pass.
uniform bool  pixelate_enabled = false;
uniform vec2  virtual_resolution = vec2(427.0, 240.0); // 16:9 @ 240p

// Phosphor mask (luminance-preserving). Masks 1-5 are the discrete patterns
// ported from Harrison Allen's CRT V4; mask 6 is an analytic staggered slot
// mask with rounded cells.
uniform int mask_type : hint_enum(
	"Dots:1",
	"Aperture Grille:2",
	"Wide Grille:3",
	"Wide Soft Grille:4",
	"Slot Mask:5",
	"Slot Rounded:6",
	"Null:0") = 6;
uniform float mask_cell_size       : hint_range(1.0, 8.0)  = 3.0; // px per column (width)
uniform float mask_cell_aspect     : hint_range(0.25, 4.0) = 1.0; // >1 = taller cells
uniform float mask_roundness       : hint_range(0.0, 1.0)  = 1.0; // 0 = rect, 1 = capsule
uniform float mask_stagger         : hint_range(0.0, 1.0)  = 0.5; // vertical offset, alt cols
uniform float mask_brightness      : hint_range(0.0, 1.0)  = 1.0; // lower = keep highlights
uniform float phosphor_intensity   : hint_range(0.0, 1.0)  = 0.5; // 0 = off, 1 = full mask
uniform float phosphor_glow        : hint_range(0.0, 2.0)  = 0.6; // additive bleed amount
uniform float phosphor_glow_radius : hint_range(0.5, 4.0)  = 1.5; // bloom spread (cells)

// Global
uniform float effect_intensity : hint_range(0.0, 1.0) = 1.0;


// ---------- helpers ----------

// Snap a UV to the centre of its virtual-resolution cell (or pass through).
vec2 snap_uv(vec2 uv) {
	if (!pixelate_enabled) {
		return uv;
	}
	return (floor(uv * virtual_resolution) + 0.5) / virtual_resolution;
}

vec3 srgb_to_linear(vec3 col) {
	return mix(
		pow((col + 0.055) / 1.055, vec3(2.4)),
		col / 12.92,
		lessThan(col, vec3(0.04045))
	);
}

vec3 linear_to_srgb(vec3 col) {
	return mix(
		(pow(col, vec3(1.0 / 2.4)) * 1.055) - 0.055,
		col * 12.92,
		lessThan(col, vec3(0.0031318))
	);
}

// Signed distance to a rounded box centred at the origin, half-size b, radius r.
float rounded_box_sdf(vec2 p, vec2 b, float r) {
	vec2 d = abs(p) - (b - r);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Returns rgb = which subpixels are lit, w = average brightness of the pattern.
vec4 generate_mask(vec2 fragcoord) {
	switch (mask_type) {
		case 1: { // Dots
			vec3 pattern[4] = {vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0,0,0)};
			ivec2 ic = ivec2(fragcoord);
			return vec4(pattern[(ic.y * 2 + ic.x) % 4], 0.25);
		}
		case 2: { // Aperture Grille
			vec3 pattern[2] = {vec3(0,1,0), vec3(1,0,1)};
			return vec4(pattern[int(fragcoord.x) % 2], 0.5);
		}
		case 3: { // Wide Grille
			vec3 pattern[4] = {vec3(1,0,0), vec3(0,1,0), vec3(0,0,1), vec3(0,0,0)};
			return vec4(pattern[int(fragcoord.x) % 4], 0.25);
		}
		case 4: { // Wide Soft Grille
			vec3 pattern[4] = {
				vec3(1.0, 0.125, 0.0),
				vec3(0.125, 1.0, 0.125),
				vec3(0.0, 0.125, 1.0),
				vec3(0.125, 0.0, 0.125)};
			return vec4(pattern[int(fragcoord.x) % 4], 0.3125);
		}
		case 5: { // Slot Mask
			vec3 pattern[16] = {
				vec3(1,0,1), vec3(0,1,0), vec3(1,0,1), vec3(0,1,0),
				vec3(0,0,1), vec3(0,1,0), vec3(1,0,0), vec3(0,0,0),
				vec3(1,0,1), vec3(0,1,0), vec3(1,0,1), vec3(0,1,0),
				vec3(1,0,0), vec3(0,0,0), vec3(0,0,1), vec3(0,1,0)
			};
			ivec2 ic = ivec2(fragcoord) % 4;
			return vec4(pattern[ic.y * 4 + ic.x], 0.375);
		}
		case 6: { // Slot Rounded (analytic: staggered RGB capsules)
			float hx = 0.38; // half column width (gap between columns = 1 - 2*hx)
			float hy = 0.45; // half cell height (gap between stacked cells = 1 - 2*hy)

			float col = floor(fragcoord.x);
			int   ci  = int(mod(col, 3.0));
			vec3  chan = vec3(float(ci == 0), float(ci == 1), float(ci == 2));

			// Brick stagger: shift every other column vertically.
			float ys = (mod(col, 2.0) >= 1.0) ? mask_stagger : 0.0;

			vec2  local = vec2(fract(fragcoord.x) - 0.5, fract(fragcoord.y + ys) - 0.5);
			float r     = mask_roundness * min(hx, hy);
			float sdf   = rounded_box_sdf(local, vec2(hx, hy), r);
			float cov   = 1.0 - smoothstep(-0.06, 0.06, sdf);

			float w = clamp((2.0 * hx) * (2.0 * hy) / 3.0, 0.05, 1.0);
			return vec4(chan * cov, w);
		}
		default: // Null
			return vec4(0.5);
	}
}

// Luminance preservation: dim by the mask average, then push the over-bright
// remainder into the unlit subpixels so highlights stay bright and unsaturated.
vec3 apply_mask(vec3 linear_color, vec2 fragcoord) {
	vec4 m = generate_mask(fragcoord);
	linear_color *= mix(m.w, 1.0, mask_brightness);
	vec3 target_color = linear_color / m.w;
	vec3 primary_col  = clamp(target_color, 0.0, 1.0);
	vec3 highlights   = target_color - primary_col;
	highlights /= 1.0 / m.w - 1.0;
	primary_col *= m.rgb;
	primary_col += highlights * (1.0 - m.rgb);
	return primary_col;
}

// 4-tap supersample of the phosphor across one screen pixel's footprint in
// mask space. Softens the cells and kills shimmer. With a screen-space
// (FRAGCOORD) lattice the derivative is constant, so this is uniform AA.
vec3 apply_mask_aa(vec3 linear_color, vec2 coord) {
	vec2 dx = dFdx(coord) * 0.25;
	vec2 dy = dFdy(coord) * 0.25;
	return 0.25 * (
		apply_mask(linear_color, coord + dx + dy) +
		apply_mask(linear_color, coord - dx + dy) +
		apply_mask(linear_color, coord + dx - dy) +
		apply_mask(linear_color, coord - dx - dy)
	);
}

// Wide bloom of the phosphor: a 3x3 gaussian spread of the mask, so bright cells
// bleed into their neighbours. Same per-pixel colour at every tap, so it reads
// as a glow across regions of similar colour rather than smearing edges.
vec3 phosphor_bloom(vec3 linear_color, vec2 coord, float radius) {
	vec3  sum  = vec3(0.0);
	float wsum = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2  d = vec2(float(x), float(y));
			float w = exp(-0.5 * dot(d, d));
			sum  += apply_mask(linear_color, coord + d * radius) * w;
			wsum += w;
		}
	}
	return sum / wsum;
}


void fragment() {

	// ===== CRT WARP (shared) =====
	// Built from SCREEN_UV in both modes so curvature and scanlines share one
	// warped frame of reference. (The phosphor lattice does NOT use this — it's
	// screen-space, see below.)
	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	vec2 warp_input  = centered_uv / overscan;
	vec2 uv_offset   = warp_input.yx / curvature;
	vec2 warped_uv   = warp_input + warp_input * uv_offset * uv_offset;
	vec2 final_uv    = clamp((warped_uv + 1.0) / 2.0, 0.0, 1.0);
	final_uv = mix(SCREEN_UV, final_uv, effect_intensity);

	vec2 screen_res = vec2(textureSize(SCREEN_TEXTURE, 0));

	vec3  color;
	vec3  raw_rgb;
	float out_alpha;

	if (is_pointer) {
		// ===== POINTER SOURCE: own sprite atlas, geometrically flat =====
		vec2 tps = TEXTURE_PIXEL_SIZE;

		// Screen-space pixelation: snap to the SAME virtual grid the screen pass
		// uses, then map the snapped screen position back into atlas UV through
		// the sprite's local derivatives, so the cursor's chunky cells match the
		// screen's in size and grid. Assumes the sprite isn't rotated.
		vec2 sample_uv = UV;
		if (pixelate_enabled) {
			vec2 snap_screen = (floor(SCREEN_UV * virtual_resolution) + 0.5) / virtual_resolution;
			vec2 d_screen    = snap_screen - SCREEN_UV;
			// dUV / dSCREEN_UV per axis (diagonal Jacobian for an axis-aligned sprite).
			float jx = dFdx(UV).x / dFdx(SCREEN_UV).x;
			float jy = dFdy(UV).y / dFdy(SCREEN_UV).y;
			sample_uv = UV + vec2(jx * d_screen.x, jy * d_screen.y);
		}

		vec2 ca = vec2(aberration_x * tps.x, aberration_y * tps.y);

		vec4 s_r = texture(TEXTURE, sample_uv + ca);
		vec4 s_g = texture(TEXTURE, sample_uv);
		vec4 s_b = texture(TEXTURE, sample_uv - ca);

		color     = vec3(s_r.r, s_g.g, s_b.b);
		raw_rgb   = s_g.rgb;
		out_alpha = s_g.a; // un-offset alpha keeps CA inside the silhouette

		// Halation over the pointer's own texture, masked by blurred alpha.
		// Based on sample_uv so the glow follows the pixelated cursor.
		vec4 blurred = vec4(0.0);
		float total  = 0.0;
		for (int x = -3; x <= 3; x++) {
			for (int y = -3; y <= 3; y++) {
				vec2 offset = vec2(float(x), float(y)) * halation_radius * tps;
				blurred    += texture(TEXTURE, sample_uv + offset);
				total      += 1.0;
			}
		}
		blurred /= total;

		float luma   = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
		float bright = max(luma - halation_threshold, 0.0) / (1.0 - halation_threshold);
		color       += halation_color * bright * halation_intensity * blurred.a;
	} else {
		// ===== SCREEN SOURCE: curved back buffer, optional pixelation =====
		vec2 src_size   = pixelate_enabled ? virtual_resolution : screen_res;
		vec2 pixel_size = 1.0 / src_size;
		vec2 ca         = vec2(aberration_x * pixel_size.x, aberration_y * pixel_size.y);

		raw_rgb   = texture(SCREEN_TEXTURE, snap_uv(final_uv)).rgb;
		out_alpha = 1.0;

		color.r = texture(SCREEN_TEXTURE, snap_uv(final_uv + ca)).r;
		color.g = texture(SCREEN_TEXTURE, snap_uv(final_uv)).g;
		color.b = texture(SCREEN_TEXTURE, snap_uv(final_uv - ca)).b;

		// Halation over the screen.
		vec4 blurred = vec4(0.0);
		float total  = 0.0;
		for (int x = -3; x <= 3; x++) {
			for (int y = -3; y <= 3; y++) {
				vec2 offset = vec2(float(x), float(y)) * halation_radius * pixel_size;
				blurred    += texture(SCREEN_TEXTURE, snap_uv(final_uv + offset));
				total      += 1.0;
			}
		}
		blurred /= total;

		float luma   = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
		float bright = max(luma - halation_threshold, 0.0) / (1.0 - halation_threshold);
		color       += halation_color * bright * halation_intensity;
	}

	// ===== SCANLINES (shared, curved) =====
	vec3 scanlines = vec3(
		sin(warped_uv.y * scanline_count * 8.0) * scanline_opacity
		+ scanline_lightness
	);
	color *= scanlines;

	// ===== VIGNETTE (shared) =====
	vec3 vignette = vec3(
		length(pow(abs(centered_uv), vec2(4.0)) / 3.0)
	);
	color -= vignette * vignette_multiplier;

	// ===== PHOSPHOR MASK + LUMINANCE PRESERVATION =====
	// Flat physical mask: keyed to FRAGCOORD so the cells stay a uniform grid
	// across the whole curved frame and don't stretch at the edges. cell_aspect
	// stretches the lattice vertically (>1 = taller cells). phosphor_glow is an
	// ADDITIVE bloom in linear light — bright cells bleed into their neighbours
	// and fill the gaps with light rather than black.
	vec2 cell = vec2(mask_cell_size, mask_cell_size * mask_cell_aspect);
	vec2 mask_coord = FRAGCOORD.xy / cell;

	color       = max(color, vec3(0.0)); // vignette can push below 0 -> guard pow()
	vec3 lin    = srgb_to_linear(color);
	vec3 sharp  = apply_mask_aa(lin, mask_coord);
	vec3 glow   = phosphor_bloom(lin, mask_coord, phosphor_glow_radius);
	vec3 masked = sharp + glow * phosphor_glow; // additive bleed
	lin         = mix(lin, masked, phosphor_intensity);
	color       = linear_to_srgb(lin);

	// ===== GLOBAL BLEND =====
	COLOR = vec4(mix(raw_rgb, color, effect_intensity), out_alpha);
}
