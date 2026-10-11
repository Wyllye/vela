// Ruído de valor e fBm usados por vários shaders.
float vela_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vela_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(vela_hash(i), vela_hash(i + vec2(1.0, 0.0)), u.x),
		mix(vela_hash(i + vec2(0.0, 1.0)), vela_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float vela_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vela_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}
