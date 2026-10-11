// Feixe de luz vindo de cima (aditivo), com faixas que respiram.
shader_type canvas_item;
render_mode blend_add;

uniform vec4 color : source_color = vec4(0.72, 0.84, 1.0, 1.0);
uniform float intensity = 0.2;
uniform float seed = 0.0;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = clamp(1.0 - UV.y, 0.0, 1.0);
	float bands = 0.62 + 0.38 * sin(UV.x * 21.0 + seed + TIME * 0.35) * sin(UV.x * 7.3 - TIME * 0.23 + seed * 1.7);
	float breathe = 0.86 + 0.14 * sin(TIME * 0.6 + seed);
	float a = pow(across, 1.7) * pow(along, 1.25) * bands * breathe * intensity;
	COLOR = vec4(color.rgb, a);
}
