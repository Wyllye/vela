// Névoa animada: duas camadas de fBm se deslocando devagar.
shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.55, 0.66, 0.80, 1.0);
uniform float density = 0.22;
uniform float scale = 0.0022;
uniform vec2 drift = vec2(0.010, 0.003);
uniform float bottom_bias = 0.6;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos * scale + TIME * drift;
	float n = vela_fbm(p) * 0.6 + vela_fbm(p * 2.2 - TIME * drift * 1.6 + 4.0) * 0.4;
	float a = smoothstep(0.38, 0.86, n) * density;
	a *= mix(1.0, smoothstep(0.0, 1.0, UV.y), bottom_bias);
	COLOR = vec4(tint.rgb, a);
}
