// Vinheta e granulação de filme por cima do jogo (abaixo da interface).
shader_type canvas_item;

uniform float vignette = 0.62;
uniform float grain = 0.03;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.004, 0.012, 1.0);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	c.x *= 1.5;
	float va = smoothstep(0.32, 1.0, length(c)) * vignette;
	float g = h(floor(FRAGCOORD.xy) + vec2(fract(TIME * 7.13) * 911.0, fract(TIME * 3.7) * 557.0));
	vec3 gc = vec3(step(0.5, g));
	float ga = grain * abs(g - 0.5) * 2.0;
	float a = va + ga * (1.0 - va);
	vec3 col = (vignette_color.rgb * va * (1.0 - ga) + gc * ga) / max(a, 0.0001);
	COLOR = vec4(col, a);
}
