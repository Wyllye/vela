class_name PlayerView
extends Node2D
## Desenha a Vela em código: batina de cera que pinga, capuz, olhos de brasa,
## pavio com chama de aura, cajado de anéis e o rastro do golpe.
## Animação procedural: molas de squash/stretch, inclinação, barra atrasada.
## Origem = pés; desenhado olhando para a direita e espelhado pela escala.

const WAX := Color("ebe0ca")
const WAX_SHADE := Color("bfae94")
const WAX_DEEP := Color("8f7f68")
const HOOD_IN := Color("0b0d12")
const EYE := Color("ffd88f")
const WICK := Color("2a2420")
const STAFF := Color("5e4e36")
const STAFF_HI := Color("8a7448")
const FEET := Color("2b2622")
const OUTLINE := Color("2c2620")

var player: Player
## Cor da aura (muda depois da Adivinhação da Água, Etapa 4).
var aura := Color("ffc56a")

var t := 0.0
var sq := Vector2.ONE
var sq_v := Vector2.ZERO
var lean := 0.0
var cloak := Vector2.ZERO
var cloak_v := Vector2.ZERO
var blink := 0.0
var next_blink := 2.6
var run_phase := 0.0
var ring_a := 0.0
var ring_v := 0.0
var flame_boost := 0.0
var wake := 1.0
var hurt_flash := 0.0
var bob := 0.0

var flame: FlameNode
var flame_glow: Sprite2D
var flame_light: PointLight2D
var embers: CPUParticles2D
var slide_dust: CPUParticles2D
var _eyes: Eyes
var _slash: Slash


func _ready() -> void:
	player = get_parent() as Player
	player.fx.connect(_on_fx)
	# a mola/escala muda a cada frame de render; a posição vem interpolada do pai
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	flame_glow = FX.make_glow(Color(aura, 0.55), 70.0)
	add_child(flame_glow)
	flame = FlameNode.new()
	flame.outer = Color(aura, 1.0)
	flame.inner = Color(1.0, 0.86, 0.55, 1.0)
	flame.core = Color(1.0, 0.97, 0.88, 1.0)
	add_child(flame)
	_eyes = Eyes.new()
	_eyes.view = self
	add_child(_eyes)
	_slash = Slash.new()
	_slash.view = self
	add_child(_slash)

	flame_light = FX.make_light(aura.lerp(Color(1, 0.9, 0.75), 0.5), 300.0, 1.15)
	flame_light.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.add_child.call_deferred(flame_light)

	embers = CPUParticles2D.new()
	embers.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	embers.amount = 10
	embers.lifetime = 0.9
	embers.local_coords = false
	embers.texture = FX.dot_texture()
	embers.material = FX.additive()
	embers.direction = Vector2.UP
	embers.spread = 30.0
	embers.initial_velocity_min = 12.0
	embers.initial_velocity_max = 34.0
	embers.gravity = Vector2(0, -22)
	embers.scale_amount_min = 0.06
	embers.scale_amount_max = 0.12
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(aura.lightened(0.3), 0.9), Color(aura, 0.0)])
	embers.color_ramp = ramp
	player.add_child.call_deferred(embers)

	slide_dust = CPUParticles2D.new()
	slide_dust.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	slide_dust.amount = 14
	slide_dust.lifetime = 0.45
	slide_dust.emitting = false
	slide_dust.local_coords = false
	slide_dust.texture = FX.dot_texture()
	slide_dust.direction = Vector2.UP
	slide_dust.spread = 25.0
	slide_dust.initial_velocity_min = 20.0
	slide_dust.initial_velocity_max = 60.0
	slide_dust.gravity = Vector2(0, 120)
	slide_dust.scale_amount_min = 0.06
	slide_dust.scale_amount_max = 0.14
	slide_dust.color = Color(0.8, 0.82, 0.86, 0.6)
	player.add_child.call_deferred(slide_dust)


func _on_fx(ev: StringName, data: Dictionary) -> void:
	match ev:
		&"jump":
			_kick(Vector2(0.78, 1.26))
		&"wall_jump":
			_kick(Vector2(0.8, 1.24))
			ring_v += 5.0
		&"air_jump":
			_kick(Vector2(0.8, 1.24))
			flame_boost = 1.0
		&"land":
			var k := clampf(float(data.get("speed", 0.0)) / 900.0, 0.15, 1.0)
			_kick(Vector2(1.0 + 0.38 * k, 1.0 - 0.32 * k))
			ring_v += 4.0 * k
		&"dash":
			_kick(Vector2(1.36, 0.78))
			flame_boost = 0.7
		&"pogo":
			_kick(Vector2(0.82, 1.2))
			ring_v += 10.0
			flame_boost = 0.9
		&"attack":
			ring_v += 7.0
		&"wall_hit", &"strike":
			ring_v += 9.0
		&"hurt":
			hurt_flash = 1.0
			_kick(Vector2(1.3, 0.75))
		&"wall_slide":
			slide_dust.emitting = bool(data.get("on", false))
		&"intro_land":
			wake = 0.0
		&"respawn_teleport":
			_kick(Vector2(0.7, 1.3))
			flame_boost = 1.0


func _kick(s: Vector2) -> void:
	sq = s
	sq_v = Vector2.ZERO


func _process(delta: float) -> void:
	t += delta
	var p := player
	var st := p.state
	# molas
	sq_v += (-(sq - Vector2.ONE) * 420.0 - sq_v * 21.0) * delta
	sq += sq_v * delta
	var lean_target := clampf(p.vel.x / p.tuning.run_speed, -1.3, 1.3) * (0.085 if p.grounded else 0.05)
	if st == Player.State.DASH:
		lean_target = p.dash_dir * 0.18
	lean = lerpf(lean, lean_target, 1.0 - exp(-14.0 * delta))
	var cloak_target := Vector2(-p.vel.x * p.facing * 0.014, -p.vel.y * 0.0075).clamp(Vector2(-8, -7), Vector2(6, 4))
	if p.wall_sliding:
		cloak_target = Vector2(2.0, -5.0)
	cloak_v += ((cloak_target - cloak) * 160.0 - cloak_v * 13.0) * delta
	cloak += cloak_v * delta
	# passos e balanço do corpo
	if p.grounded and absf(p.vel.x) > 30.0:
		run_phase += absf(p.vel.x) * delta * 0.042
		bob = -absf(sin(run_phase * PI)) * 2.2
	else:
		bob = lerpf(bob, sin(t * 2.2) * 0.6 if p.grounded else 0.0, 1.0 - exp(-10.0 * delta))
	# anéis do cajado (pêndulo)
	ring_v += (-ring_a * 120.0 - ring_v * 7.0 - p.vel.x * 0.004 * p.facing) * delta
	ring_a = clampf(ring_a + ring_v * delta, -0.9, 0.9)
	# piscar
	next_blink -= delta
	if next_blink <= 0.0:
		blink = 1.0
		next_blink = randf_range(2.2, 5.0)
	blink = move_toward(blink, 0.0, delta * 9.0)
	flame_boost = move_toward(flame_boost, 0.0, delta * 1.8)
	hurt_flash = move_toward(hurt_flash, 0.0, delta * 3.0)
	if st == Player.State.WAKE:
		wake = clampf(p.state_time / (Player.WAKE_TIME * 0.8), 0.0, 1.0)
	elif st != Player.State.INTRO_FALL:
		wake = move_toward(wake, 1.0, delta * 3.0)

	scale = Vector2(p.facing * sq.x, sq.y)
	rotation = lean
	modulate = Color(1, 1, 1).lerp(Color(1.6, 1.4, 1.2), hurt_flash)
	visible = not (st == Player.State.RESPAWN and p.state_time < Player.RESPAWN_BLACK + 0.05)
	_update_flame()
	queue_redraw()
	_eyes.queue_redraw()
	_slash.queue_redraw()


func _flame_base() -> Vector2:
	return Vector2(2.6, -55.0 + bob)


func _update_flame() -> void:
	var p := player
	var weak := 1.0
	if p.state == Player.State.INTRO_FALL:
		weak = 0.45
	elif p.state == Player.State.WAKE:
		weak = lerpf(0.45, 1.0, wake)
	var local_vx := p.vel.x * p.facing
	flame.position = _flame_base()
	flame.height = (14.0 + flame_boost * 8.0) * weak * (1.0 + clampf(p.vel.y * 0.0005, -0.25, 0.35))
	flame.width = (6.6 + flame_boost * 2.0) * lerpf(0.7, 1.0, weak)
	flame.tilt = clampf(-local_vx * 0.0011, -0.5, 0.5)
	flame_glow.position = _flame_base() + Vector2(0, -6)
	flame_glow.modulate.a = (0.5 + flame_boost * 0.3) * weak
	flame.visible = visible
	flame_glow.visible = visible
	var world_flame := transform * (_flame_base() + Vector2(0, -6))
	if is_instance_valid(flame_light):
		flame_light.position = world_flame
		flame_light.energy = (1.15 + flame_boost * 0.9) * weak * (0.94 + 0.06 * sin(t * 11.0))
		flame_light.visible = visible
	if is_instance_valid(embers):
		embers.position = world_flame
		embers.emitting = visible
	if is_instance_valid(slide_dust):
		slide_dust.position = Vector2(p.wall_dir * (p.body.size.x * 0.5), -26.0)


# ===========================================================================
# Desenho
# ===========================================================================

func _draw() -> void:
	var p := player
	var lying := 1.0 - wake
	if lying > 0.001:
		draw_set_transform(Vector2(-6.0 * lying, -2.0 * lying), -1.45 * lying, Vector2.ONE)
	elif p.wall_sliding:
		draw_set_transform(Vector2(-2.5, 0), 0.0, Vector2.ONE)
	elif p.state == Player.State.REST:
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.12, 0.86))
	if p.grounded and lying < 0.5:
		_draw_shadow()
	_draw_feet()
	_draw_robe()
	_draw_hood()
	_draw_staff()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shadow() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 2.6 - 0.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))


func _draw_feet() -> void:
	var step := sin(run_phase * PI)
	var moving := player.grounded and absf(player.vel.x) > 30.0
	var f1 := Vector2(4.0 + (step * 3.5 if moving else 0.0), -2.0 - (maxf(step, 0.0) * 2.0 if moving else 0.0))
	var f2 := Vector2(-3.5 - (step * 3.5 if moving else 0.0), -2.0 - (maxf(-step, 0.0) * 2.0 if moving else 0.0))
	if not player.grounded:
		f1 = Vector2(3.5, -3.0 + cloak.y * 0.3)
		f2 = Vector2(-3.0, -1.5 + cloak.y * 0.3)
	for f in [f2, f1]:
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0
			pts.append(f + Vector2(cos(a) * 3.6, sin(a) * 2.2))
		draw_colored_polygon(pts, FEET)


func _robe_points() -> PackedVector2Array:
	var b := bob
	var cx := cloak.x
	var cy := cloak.y
	return PackedVector2Array([
		Vector2(8.0, -29.5 + b),
		Vector2(11.2, -19.0 + b),
		Vector2(13.0 + cx * 0.55, -6.0 + cy * 0.5),
		Vector2(10.0 + cx * 0.7, -2.4 + cy * 0.6),
		Vector2(6.5 + cx * 0.8, -5.0 + cy * 0.7),
		Vector2(3.0 + cx * 0.88, -1.6 + cy * 0.8),
		Vector2(-1.0 + cx * 0.95, -4.6 + cy * 0.9),
		Vector2(-5.0 + cx, -2.0 + cy),
		Vector2(-9.0 + cx * 1.05, -4.4 + cy),
		Vector2(-13.2 + cx * 1.12, -5.0 + cy * 1.05),
		Vector2(-11.6 + cx * 0.35, -18.0 + b),
		Vector2(-8.0, -30.5 + b),
	])


func _draw_robe() -> void:
	var pts := _smooth_closed(_robe_points(), 3)
	var cols := PackedColorArray()
	for q in pts:
		var k := clampf((q.x + 10.0) / 18.0, 0.0, 1.0)
		var c := WAX_SHADE.lerp(WAX, k)
		if q.y > -7.0:
			c = c.lerp(WAX_DEEP, 0.25)
		cols.append(c)
	draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(OUTLINE, 0.5), 1.2, true)
	# dobra da batina
	draw_line(Vector2(1.5, -26.0 + bob), Vector2(2.5 + cloak.x * 0.6, -6.0 + cloak.y * 0.6), Color(WAX_SHADE, 0.7), 1.2, true)
	# braço da frente e mão
	draw_line(Vector2(6.0, -27.0 + bob), _hand(), Color(WAX_SHADE, 1.0), 4.2, true)
	draw_circle(_hand(), 2.7, WAX, true, -1.0, true)


func _hood_center() -> Vector2:
	return Vector2(2.0, -38.5 + bob)


func _draw_hood() -> void:
	var c := _hood_center()
	var r := 10.6
	var tip := Vector2(-10.0 + cloak.x * 0.25, -48.5 + bob + cloak.y * 0.15)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var tip_added := false
	for i in 28:
		var a := TAU * i / 28.0
		var deg := rad_to_deg(a)
		if deg > 186.0 and deg < 264.0:
			if not tip_added:
				pts.append(tip)
				cols.append(WAX_SHADE)
				tip_added = true
			continue
		var q := c + Vector2(cos(a), sin(a)) * r
		pts.append(q)
		cols.append(WAX_SHADE.lerp(WAX, clampf((q.x + 6.0) / 14.0, 0.0, 1.0)))
	draw_polygon(pts, cols)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(OUTLINE, 0.5), 1.2, true)
	# abertura do rosto
	var face := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		face.append(Vector2(5.4, -37.6 + bob) + Vector2(cos(a) * 6.0, sin(a) * 7.3))
	draw_colored_polygon(face, HOOD_IN)
	# pavio
	draw_polyline(PackedVector2Array([Vector2(1.0, -48.6 + bob), Vector2(1.8, -52.4 + bob), _flame_base() + Vector2(0, 1.0)]), WICK, 1.8, true)


func _hand() -> Vector2:
	return Vector2(9.2, -21.5 + bob)


func _staff_angle() -> float:
	var p := player
	var idle := deg_to_rad(-84.0)
	if p.state == Player.State.DASH:
		return deg_to_rad(-12.0)
	if p.attack_t <= 0.0:
		if p.wall_sliding:
			return deg_to_rad(-70.0)
		return idle
	var k := 1.0 - p.attack_t / p.tuning.attack_time
	var ka := clampf(k / (p.tuning.attack_active / p.tuning.attack_time), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - ka, 3.0)
	var a0 := -150.0
	var a1 := 35.0
	match p.attack_dir:
		-1:
			a0 = 30.0
			a1 = -195.0
		1:
			a0 = -40.0
			a1 = 140.0
	var a := lerpf(a0, a1, e)
	if k > 0.6:
		a = lerpf(a1, -84.0, (k - 0.6) / 0.4)
	return deg_to_rad(a)


func _draw_staff() -> void:
	var h := _hand()
	var ang := _staff_angle()
	var u := Vector2(cos(ang), sin(ang))
	var n := Vector2(-u.y, u.x)
	var bottom := h - u * 20.0
	var top := h + u * 38.0
	draw_line(bottom, top, STAFF, 2.5, true)
	draw_line(bottom + n * 0.7, top + n * 0.7, Color(STAFF_HI, 0.55), 0.9, true)
	var head := top + u * 4.0
	draw_arc(head, 3.8, 0.0, TAU, 20, STAFF_HI, 1.4, true)
	for s in [-1.0, 1.0]:
		var ring_pos: Vector2 = top + u * 2.4 + n * 3.8 * s
		var hang: Vector2 = Vector2(0, 2.2).rotated(ring_a * s)
		draw_arc(ring_pos + hang, 1.7, 0.0, TAU, 12, STAFF_HI, 1.0, true)
	# mão por cima do cajado
	draw_circle(h, 2.7, WAX, true, -1.0, true)


func _smooth_closed(pts: PackedVector2Array, samples: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in samples:
			var tt := float(s) / samples
			var t2 := tt * tt
			var t3 := t2 * tt
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## Olhos de brasa (aditivos, sem sombra).
class Eyes extends Node2D:
	var view: PlayerView

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		var v := view
		var p := v.player
		if not v.visible:
			return
		var lying := 1.0 - v.wake
		if lying > 0.001:
			draw_set_transform(Vector2(-6.0 * lying, -2.0 * lying), -1.45 * lying, Vector2.ONE)
		elif p.wall_sliding:
			draw_set_transform(Vector2(-2.5, 0), 0.0, Vector2.ONE)
		var closed := v.blink
		if p.state == Player.State.INTRO_FALL or (p.state == Player.State.WAKE and v.wake < 0.55):
			closed = 1.0
		var open := 1.0 - closed
		var y := -38.2 + v.bob
		for x in [3.6, 7.6]:
			draw_circle(Vector2(x, y), 3.2, Color(v.aura, 0.12 * open + 0.02))
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				pts.append(Vector2(x + cos(a) * 1.1, y + sin(a) * maxf(2.0 * open, 0.3)))
			draw_colored_polygon(pts, Color(PlayerView.EYE, 0.95))


## Rastro do golpe do cajado (meia-lua aditiva).
class Slash extends Node2D:
	var view: PlayerView

	func _ready() -> void:
		material = FX.additive()
		light_mask = 0

	func _draw() -> void:
		var p := view.player
		if p.attack_t <= 0.0:
			return
		var k := 1.0 - p.attack_t / p.tuning.attack_time
		if k > 0.62:
			return
		var ka := clampf(k / (p.tuning.attack_active / p.tuning.attack_time), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - ka, 3.0)
		var center := Vector2(6, -25)
		var a0 := -115.0
		var a1 := 55.0
		var r_out := 40.0
		match p.attack_dir:
			-1:
				center = Vector2(2, -38)
				a0 = 25.0
				a1 = -205.0
			1:
				center = Vector2(2, -8)
				a0 = -15.0
				a1 = 195.0
		var a_cur := lerpf(a0, a1, e)
		var fade := 1.0 - clampf((k - 0.3) / 0.32, 0.0, 1.0)
		var col := Color.WHITE.lerp(view.aura, 0.35)
		var steps := 18
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var cols_o := PackedColorArray()
		var cols_i := PackedColorArray()
		for i in range(steps + 1):
			var s := float(i) / steps
			var a := deg_to_rad(lerpf(a0, a_cur, s))
			var thick := 15.0 * sin(PI * clampf(s * 0.92 + 0.08, 0.0, 1.0))
			outer.append(center + Vector2(cos(a), sin(a)) * r_out)
			inner.append(center + Vector2(cos(a), sin(a)) * (r_out - thick))
			var alpha := pow(s, 1.6) * 0.85 * fade
			cols_o.append(Color(col, alpha))
			cols_i.append(Color(col, alpha * 0.25))
		var pts := outer.duplicate()
		var cols := cols_o.duplicate()
		for i in range(steps, -1, -1):
			pts.append(inner[i])
			cols.append(cols_i[i])
		draw_polygon(pts, cols)
