class_name CombatPilot
extends ScriptedInput
## Piloto automático da demo de combate (GIF do README): enfrenta o Eco mais
## perto com o cajado, quica nos que estão embaixo, mira para cima nas
## Mariposas, abre o Ren quando eles se juntam e pula as investidas do Vigia.
## Só serve para a demo e para testar o combate rodando sozinho.

var player: Player
var ecos: Array = []
var _ren_hold := 0.0
var _ren_cool := 0.0
var _jump_hold := 0.0


func poll() -> void:
	var p := player
	var now := {}
	for a in ACTIONS:
		now[a] = false
	var c := p.body.center()
	_ren_cool -= dt
	var target: Eco = null
	var best := 460.0
	var near := 0
	for e in ecos:
		if not is_instance_valid(e) or not e.alive():
			continue
		var d: float = e.body.center().distance_to(c)
		if d < 150.0:
			near += 1
		if d < best:
			best = d
			target = e
	if near >= 2 and p.aura > 35.0 and not p.ren and _ren_cool <= 0.0:
		_ren_hold = 0.55
		_ren_cool = 3.0
	if target != null:
		var to := target.body.center() - c
		var dir := 1 if to.x >= 0.0 else -1
		var key := &"move_right" if dir > 0 else &"move_left"
		# investida do Vigia vindo na direção dela: pula por cima
		if target is Vigia and target.s == Vigia.S.CHARGE and absf(to.x) < 170.0 and target.facing == -dir and p.grounded:
			_jump_hold = 0.22
		if absf(to.x) > 40.0 or absf(to.y) > 60.0:
			now[key] = true
		if p.attack_cd_t <= 0.0 and p.attack_t <= 0.0:
			if to.y > 24.0 and absf(to.x) < 38.0 and not p.grounded:
				now[&"move_down"] = true
				now[&"attack"] = true
			elif to.y < -36.0 and absf(to.x) < 46.0:
				now[&"move_up"] = true
				now[&"attack"] = true
			elif absf(to.x) < 66.0 and absf(to.y) < 44.0:
				now[key] = true
				now[&"attack"] = true
		# Mariposa pairando alta: pula para alcançar
		if to.y < -70.0 and absf(to.x) < 90.0 and p.grounded and _jump_hold <= 0.0:
			_jump_hold = 0.25
	if _ren_hold > 0.0:
		now[&"ren"] = true
		_ren_hold -= dt
	if _jump_hold > 0.0:
		now[&"jump"] = true
		_jump_hold -= dt
	for a in ACTIONS:
		_apply(a, enabled and bool(now[a]), false, false)
	move = Vector2(
		float(int(held(&"move_right")) - int(held(&"move_left"))),
		float(int(held(&"move_down")) - int(held(&"move_up"))))
	time += dt
