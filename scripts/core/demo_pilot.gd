class_name DemoPilot
extends ScriptedInput
## Piloto automático da demo gravada da Câmara das Lanternas: corre, pula da
## borda e vai quicando de lanterna em lanterna (pogo), usando o Passo de Ren
## e o Sopro quando a próxima lanterna está longe. Só serve para a demo.

var player: Player
var lanterns: Array = []
var exit_x := 61 * 32.0
var ledge_x := 9 * 32.0
var _jumped_off := false
var _dashed := false
var _air_jumped := false
var _jump_hold := 0.0


func poll() -> void:
	var p := player
	var now := {}
	for a in ACTIONS:
		now[a] = false
	var c := p.body.center()
	var feet := p.body.pos.y + p.body.size.y
	if c.x < exit_x + 40.0:
		now[&"move_right"] = true
	if p.grounded:
		_dashed = false
		_air_jumped = false
	if not _jumped_off and p.grounded and p.body.pos.x + p.body.size.x > ledge_x - 6.0:
		_jump_hold = 0.24
		_jumped_off = true
	var target: Lantern = null
	var best := INF
	for l in lanterns:
		var dx: float = l.hit_rect().get_center().x - c.x
		if dx > -26.0 and dx < best:
			best = dx
			target = l
	if not p.grounded and target != null:
		var r: Rect2 = target.hit_rect()
		var dx := r.get_center().x - c.x
		var below := r.position.y - feet
		if p.vel.y < -480.0:
			_dashed = false
			_air_jumped = false
		if not _dashed and p.dash_ready and p.vel.y > -140.0 and dx > 170.0:
			now[&"dash"] = true
			_dashed = true
		if not _air_jumped and p.air_jumps_left > 0 and p.vel.y > 150.0 and below < 30.0 and dx > 50.0:
			_jump_hold = 0.2
			_air_jumped = true
		if absf(dx) < 36.0 and below > -16.0 and below < 80.0 and p.vel.y > -60.0:
			now[&"move_down"] = true
			now[&"move_right"] = absf(dx) > 8.0 and dx > 0.0
			if p.attack_cd_t <= 0.0:
				now[&"attack"] = true
	if _jump_hold > 0.0:
		now[&"jump"] = true
		_jump_hold -= dt
	for a in ACTIONS:
		_apply(a, enabled and bool(now[a]), false, false)
	move = Vector2(
		float(int(held(&"move_right")) - int(held(&"move_left"))),
		float(int(held(&"move_down")) - int(held(&"move_up"))))
	time += dt
