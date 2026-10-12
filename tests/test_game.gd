extends "res://tests/test_base.gd"
## Estado global: o hit-stop precisa sempre soltar o jogo.

const GameScript := preload("res://scripts/autoload/game.gd")


func test_hitstop_freezes_and_always_releases() -> void:
	var g: Node = GameScript.new()
	var t0 := 5000000
	g.hitstop(0.05, t0)
	check(Engine.time_scale == 0.0, "o impacto congela o jogo")
	g.update_hitstop(t0 + 16000)
	g.update_hitstop(t0 + 33000)
	check(Engine.time_scale == 0.0, "ainda congelado antes do prazo")
	g.update_hitstop(t0 + 50000)
	check(Engine.time_scale == 1.0, "solta no prazo")
	# dois impactos seguidos: vale o que termina por último
	g.hitstop(0.05, t0 + 100000)
	g.hitstop(0.08, t0 + 110000)
	g.hitstop(0.02, t0 + 115000)
	g.update_hitstop(t0 + 160000)
	check(Engine.time_scale == 0.0, "o impacto mais longo manda")
	g.update_hitstop(t0 + 190000)
	check(Engine.time_scale == 1.0, "e solta no fim dele")
	# nunca passa do teto
	g.hitstop(5.0, t0 + 300000)
	g.update_hitstop(t0 + 300000 + int(GameScript.MAX_HITSTOP * 1000000.0))
	check(Engine.time_scale == 1.0, "nenhum hit-stop dura mais que %.1f s" % GameScript.MAX_HITSTOP)
	Engine.time_scale = 1.0
	g.free()
