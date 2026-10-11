// Pedra do terreno: cor pela distância até a borda (textura 1 px por tile,
// filtrada) + ruído de rocha, estratos e rachaduras. A luz 2D age por cima.
shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"

uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform vec2 room_px = vec2(1280.0, 720.0);
uniform vec4 edge_color : source_color = vec4(0.29, 0.34, 0.40, 1.0);
uniform vec4 mid_color : source_color = vec4(0.145, 0.176, 0.22, 1.0);
uniform vec4 deep_color : source_color = vec4(0.043, 0.055, 0.075, 1.0);
uniform vec2 offset = vec2(0.0);

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	float d = texture(dist_tex, world / room_px).r * 8.0;
	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.5, 1.6, d));
	col = mix(col, deep_color.rgb, smoothstep(1.6, 4.0, d));
	vec2 p = world + offset;
	float n = vela_fbm(p * 0.028);
	float strata = vela_fbm(vec2(p.x * 0.005, p.y * 0.055));
	float grain = vela_noise(p * 0.5);
	col *= 0.80 + 0.34 * n;
	col += (strata - 0.5) * 0.06;
	col *= 0.95 + 0.07 * grain;
	float crack = 1.0 - smoothstep(0.0, 0.018, abs(vela_fbm(p * 0.011 + 3.7) - 0.5));
	col *= 1.0 - crack * 0.45 * smoothstep(0.7, 1.8, d);
	COLOR = vec4(col, 1.0) * COLOR;
}
