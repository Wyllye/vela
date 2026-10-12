class_name GameUI
extends CanvasLayer
## Interface: tela de título, HUD da vela (aura e gotas), nome da área,
## inscrições, aviso de descanso, cartão de lição (Ten, Zetsu, Ren), cartão de
## fim de etapa, pausa com controles e depuração (F3).
## Tudo montado em código para ficar fácil de ajustar.

const VIEW := Vector2(1280, 720)
const INK := Color("ece3cf")
const MUTED := Color("9aa6b4")

var font_title: Font
var font_body: Font
var font_italic: Font

var fade: ColorRect
var title_root: Control
var area_root: Control
var insc_root: Control
var insc_label: Label
var rest_label: Label
var end_root: Control
var pause_root: Control
var pause_music: Label
var debug_label: Label
var end_card_visible := false
var hud: NenHud
var lesson_root: Control
var lesson_visible := false
var _lesson_name: Label
var _lesson_sub: Label
var _lesson_desc: Label
var _lesson_hint: Label
var _lesson_continue: Label
var _hud_tween: Tween

var _title_prompt: Label
var _title_t := 0.0
var _area_tween: Tween
var _insc_tween: Tween
var _rest_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_title = _font("res://assets/fonts/Cinzel-Variable.ttf", 600)
	font_body = _font("res://assets/fonts/CormorantGaramond-Variable.ttf", 500)
	font_italic = _font("res://assets/fonts/CormorantGaramond-Italic-Variable.ttf", 500)
	_build_hud()
	_build_inscription()
	_build_area_title()
	_build_rest_prompt()
	_build_lesson()
	_build_end_card()
	_build_title()
	_build_pause()
	_build_debug()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = VIEW
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


func _process(delta: float) -> void:
	_title_t += delta
	if title_root.visible and _title_prompt:
		_title_prompt.modulate.a = 0.45 + 0.4 * (0.5 + 0.5 * sin(_title_t * 2.2))
	if lesson_visible and _lesson_continue.visible:
		_lesson_continue.modulate.a = 0.45 + 0.4 * (0.5 + 0.5 * sin(_title_t * 2.2))


# ---------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------

func _font(path: String, weight: int, spacing := 0) -> Font:
	var base: Font = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	fv.spacing_glyph = spacing
	return fv


func _label(text: String, font: Font, size: int, color: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	var f := font
	if spacing != 0:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = spacing
		f = fv
	ls.font = f
	ls.font_size = size
	ls.font_color = color
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.55)
	ls.shadow_offset = Vector2(0, 2)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _full_rect(c: Control) -> void:
	c.position = Vector2.ZERO
	c.size = VIEW
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place(l: Label, y: float, h: float = 80.0) -> void:
	l.position = Vector2(0, y - h * 0.5)
	l.size = Vector2(VIEW.x, h)


func _soft_backdrop(rect: Rect2, alpha: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = FX.glow_texture()
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = rect.position
	tr.size = rect.size
	tr.modulate = Color(0, 0, 0, alpha)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _build_title() -> void:
	title_root = Control.new()
	_full_rect(title_root)
	add_child(title_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.55)
	_full_rect(dim)
	title_root.add_child(dim)
	var flame := TitleFlame.new()
	flame.position = Vector2(VIEW.x * 0.5, 220)
	title_root.add_child(flame)
	var title := _label(tr("TITLE_GAME"), font_title, 132, INK, 30)
	_place(title, 335, 160)
	title_root.add_child(title)
	var orn := Ornament.new()
	orn.position = Vector2(VIEW.x * 0.5, 420)
	orn.width = 360.0
	title_root.add_child(orn)
	var sub := _label(tr("TITLE_SUB").to_upper(), font_title, 20, MUTED, 14)
	_place(sub, 452, 40)
	title_root.add_child(sub)
	_title_prompt = _label(tr("TITLE_PRESS"), font_italic, 30, INK)
	_place(_title_prompt, 575, 50)
	title_root.add_child(_title_prompt)
	var build := _label(tr("TITLE_BUILD"), font_body, 18, Color(MUTED, 0.8), 2)
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.position = Vector2(VIEW.x - 520, VIEW.y - 52)
	build.size = Vector2(490, 30)
	title_root.add_child(build)
	var credit := _label("Jogo de fã · sistema de habilidades inspirado no Nen de Hunter x Hunter (Yoshihiro Togashi)", font_italic, 17, Color(MUTED, 0.65))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credit.position = Vector2(30, VIEW.y - 52)
	credit.size = Vector2(760, 30)
	title_root.add_child(credit)
	title_root.visible = false


func _build_area_title() -> void:
	area_root = Control.new()
	_full_rect(area_root)
	area_root.modulate.a = 0.0
	add_child(area_root)
	area_root.add_child(_soft_backdrop(Rect2(240, 150, 800, 220), 0.55))
	var top := Ornament.new()
	top.position = Vector2(VIEW.x * 0.5, 212)
	top.width = 440.0
	area_root.add_child(top)
	var name_l := _label("", font_title, 52, INK, 10)
	name_l.name = "Name"
	_place(name_l, 262, 80)
	area_root.add_child(name_l)
	var sub := _label("", font_italic, 26, MUTED, 2)
	sub.name = "Sub"
	_place(sub, 312, 40)
	area_root.add_child(sub)


func _build_inscription() -> void:
	insc_root = Control.new()
	_full_rect(insc_root)
	insc_root.modulate.a = 0.0
	add_child(insc_root)
	insc_root.add_child(_soft_backdrop(Rect2(140, 40, 1000, 250), 0.65))
	var orn := Ornament.new()
	orn.position = Vector2(VIEW.x * 0.5, 92)
	orn.width = 220.0
	orn.small = true
	insc_root.add_child(orn)
	insc_label = _label("", font_italic, 31, INK)
	insc_label.label_settings.line_spacing = 2.0
	insc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insc_label.position = Vector2(190, 110)
	insc_label.size = Vector2(900, 120)
	insc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	insc_root.add_child(insc_label)


func _build_rest_prompt() -> void:
	rest_label = _label("↑   " + tr("REST_PROMPT"), font_italic, 26, INK)
	_place(rest_label, 600, 40)
	rest_label.modulate.a = 0.0
	add_child(rest_label)


func _build_hud() -> void:
	hud = NenHud.new()
	hud.font = _font("res://assets/fonts/Cinzel-Variable.ttf", 600)
	hud.position = Vector2(46, 34)
	hud.modulate.a = 0.0
	add_child(hud)


func _build_lesson() -> void:
	lesson_root = Control.new()
	_full_rect(lesson_root)
	lesson_root.visible = false
	add_child(lesson_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.5)
	_full_rect(dim)
	lesson_root.add_child(dim)
	lesson_root.add_child(_soft_backdrop(Rect2(140, 120, 1000, 480), 0.7))
	_lesson_name = _label("", font_title, 108, INK, 24)
	_place(_lesson_name, 232, 150)
	lesson_root.add_child(_lesson_name)
	var orn := Ornament.new()
	orn.position = Vector2(VIEW.x * 0.5, 318)
	orn.width = 420.0
	lesson_root.add_child(orn)
	_lesson_sub = _label("", font_italic, 32, MUTED, 3)
	_place(_lesson_sub, 356, 50)
	lesson_root.add_child(_lesson_sub)
	_lesson_desc = _label("", font_body, 27, INK)
	_lesson_desc.label_settings.line_spacing = 3.0
	_lesson_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson_desc.position = Vector2(200, 392)
	_lesson_desc.size = Vector2(880, 100)
	lesson_root.add_child(_lesson_desc)
	_lesson_hint = _label("", font_title, 21, Color(1.0, 0.84, 0.58), 4)
	_place(_lesson_hint, 522, 36)
	lesson_root.add_child(_lesson_hint)
	_lesson_continue = _label(tr("LESSON_CONTINUE"), font_italic, 23, Color(MUTED, 0.9))
	_place(_lesson_continue, 610, 36)
	lesson_root.add_child(_lesson_continue)


func _build_end_card() -> void:
	end_root = Control.new()
	_full_rect(end_root)
	end_root.visible = false
	add_child(end_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.6)
	_full_rect(dim)
	end_root.add_child(dim)
	var t := _label(tr("END_TITLE"), font_title, 56, INK, 8)
	_place(t, 270, 90)
	end_root.add_child(t)
	var orn := Ornament.new()
	orn.position = Vector2(VIEW.x * 0.5, 326)
	orn.width = 380.0
	end_root.add_child(orn)
	var s := _label(tr("END_SUB"), font_italic, 30, MUTED)
	_place(s, 362, 50)
	end_root.add_child(s)
	var n := _label(tr("END_NEXT"), font_body, 25, INK)
	_place(n, 440, 40)
	end_root.add_child(n)
	var c := _label(tr("END_CONTINUE"), font_italic, 23, Color(MUTED, 0.9))
	_place(c, 560, 40)
	end_root.add_child(c)


func _build_pause() -> void:
	pause_root = Control.new()
	_full_rect(pause_root)
	pause_root.visible = false
	add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.72)
	_full_rect(dim)
	pause_root.add_child(dim)
	var t := _label(tr("PAUSE_TITLE"), font_title, 46, INK, 8)
	_place(t, 120, 70)
	pause_root.add_child(t)
	var orn := Ornament.new()
	orn.position = Vector2(VIEW.x * 0.5, 166)
	orn.width = 300.0
	pause_root.add_child(orn)
	var rows := [
		["CTRL_MOVE", "CTRL_MOVE_KEYS"],
		["CTRL_JUMP", "CTRL_JUMP_KEYS"],
		["CTRL_ATTACK", "CTRL_ATTACK_KEYS"],
		["CTRL_DASH", "CTRL_DASH_KEYS"],
		["CTRL_ZETSU", "CTRL_ZETSU_KEYS"],
		["CTRL_REN", "CTRL_REN_KEYS"],
	]
	var y := 206.0
	for row in rows:
		var a := _label(tr(row[0]), font_body, 25, INK)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.position = Vector2(0, y - 18)
		a.size = Vector2(VIEW.x * 0.5 - 24, 36)
		pause_root.add_child(a)
		var b := _label(tr(row[1]), font_body, 25, MUTED)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(VIEW.x * 0.5 + 24, y - 18)
		b.size = Vector2(VIEW.x * 0.5 - 24, 36)
		pause_root.add_child(b)
		y += 44.0
	pause_music = _label("", font_italic, 24, MUTED)
	_place(pause_music, 500, 36)
	pause_root.add_child(pause_music)
	var dbg := _label(tr("PAUSE_DEBUG"), font_italic, 24, MUTED)
	_place(dbg, 538, 36)
	pause_root.add_child(dbg)
	var back := _label(tr("PAUSE_RESUME"), font_italic, 26, INK)
	_place(back, 610, 36)
	pause_root.add_child(back)
	refresh_pause()


func _build_debug() -> void:
	debug_label = Label.new()
	debug_label.position = Vector2(14, 10)
	debug_label.size = Vector2(520, 260)
	var ls := LabelSettings.new()
	ls.font_size = 14
	ls.font_color = Color(0.75, 1.0, 0.8)
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.8)
	debug_label.label_settings = ls
	debug_label.visible = false
	add_child(debug_label)


# ---------------------------------------------------------------------------
# API usada pelo Main
# ---------------------------------------------------------------------------

func fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(fade, "color:a", alpha, time)
	await tw.finished


func show_title() -> void:
	title_root.visible = true
	title_root.modulate.a = 1.0


func hide_title() -> void:
	var tw := create_tween()
	tw.tween_property(title_root, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): title_root.visible = false)


func show_area_title(area: String, sub: String) -> void:
	(area_root.get_node("Name") as Label).text = area.to_upper()
	(area_root.get_node("Sub") as Label).text = sub
	if _area_tween and _area_tween.is_valid():
		_area_tween.kill()
	_area_tween = create_tween()
	_area_tween.tween_property(area_root, "modulate:a", 1.0, 1.1)
	_area_tween.tween_interval(2.8)
	_area_tween.tween_property(area_root, "modulate:a", 0.0, 1.6)


func show_inscription(text: String) -> void:
	insc_label.text = text
	if _insc_tween and _insc_tween.is_valid():
		_insc_tween.kill()
	_insc_tween = create_tween()
	_insc_tween.tween_property(insc_root, "modulate:a", 1.0, 0.45)


func hide_inscription() -> void:
	if _insc_tween and _insc_tween.is_valid():
		_insc_tween.kill()
	_insc_tween = create_tween()
	_insc_tween.tween_property(insc_root, "modulate:a", 0.0, 0.35)


func show_rest_prompt(on: bool, meditate := false) -> void:
	if on:
		rest_label.text = "↑   " + tr("MEDITATE_PROMPT" if meditate else "REST_PROMPT")
	var target := 1.0 if on else 0.0
	if is_equal_approx(rest_label.modulate.a, target):
		return
	if _rest_tween and _rest_tween.is_valid():
		if (_rest_tween.get_meta("to", -1.0) as float) == target:
			return
		_rest_tween.kill()
	_rest_tween = create_tween()
	_rest_tween.set_meta("to", target)
	_rest_tween.tween_property(rest_label, "modulate:a", target, 0.3)


func show_end_card() -> void:
	end_root.visible = true
	end_root.modulate.a = 0.0
	end_card_visible = true
	create_tween().tween_property(end_root, "modulate:a", 1.0, 1.4)


func hide_end_card() -> void:
	end_card_visible = false
	var tw := create_tween()
	tw.tween_property(end_root, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): end_root.visible = false)


func show_hud(on: bool, time := 0.6) -> void:
	if _hud_tween and _hud_tween.is_valid():
		_hud_tween.kill()
	_hud_tween = create_tween()
	_hud_tween.tween_property(hud, "modulate:a", 1.0 if on else 0.0, time)


## Cartão de lição: nome da técnica, o que ela faz e o botão.
func show_lesson(lesson: String) -> void:
	var k := lesson.to_upper()
	_lesson_name.text = tr("LESSON_%s_NAME" % k).to_upper()
	_lesson_sub.text = tr("LESSON_%s_SUB" % k)
	_lesson_desc.text = tr("LESSON_%s_DESC" % k)
	_lesson_hint.text = tr("LESSON_%s_HINT" % k)
	_lesson_continue.visible = false
	lesson_root.visible = true
	lesson_root.modulate.a = 0.0
	lesson_visible = true
	var tw := create_tween()
	tw.tween_property(lesson_root, "modulate:a", 1.0, 0.9)


func show_lesson_continue() -> void:
	_lesson_continue.visible = true


func hide_lesson() -> void:
	lesson_visible = false
	var tw := create_tween()
	tw.tween_property(lesson_root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): lesson_root.visible = false)


func set_paused(on: bool) -> void:
	refresh_pause()
	pause_root.visible = on


func refresh_pause() -> void:
	if pause_music:
		pause_music.text = tr("PAUSE_MUSIC") % (tr("PAUSE_ON") if Game.music_on else tr("PAUSE_OFF"))


func set_debug_visible(on: bool) -> void:
	debug_label.visible = on


func update_debug(p: Player, fps: float, room_id: String) -> void:
	debug_label.text = "FPS %d   sala %s\nestado %s   t=%.2f\npos (%.1f, %.1f)   vel (%.0f, %.0f)\nchão %s   coyote %.2f   buffer %.2f\ndash %s   pulos no ar %d   parede %d %s\nolhar %d   respawns %d\ngotas %d/%d   aura %.0f/%.0f   %s%s%s   invenc %.2f" % [
		fps, room_id, Player.State.keys()[p.state], p.state_time,
		p.body.pos.x, p.body.pos.y, p.vel.x, p.vel.y,
		p.grounded, p.coyote_t, p.jump_buffer_t,
		p.dash_ready, p.air_jumps_left, p.wall_dir, "deslizando" if p.wall_sliding else "",
		p.look, p.hurt_count,
		p.vitality, p.vitality_max, p.aura, p.aura_cap(),
		"vazando " if p.is_leaking() else "", "ZETSU " if p.zetsu else "", "REN " if p.ren else "", p.invuln_t]


# ---------------------------------------------------------------------------

## Linha ornamental com losango central (título, nome da área, inscrições).
class Ornament extends Node2D:
	var width := 300.0
	var small := false

	func _draw() -> void:
		var c := Color(GameUI.INK, 0.55)
		var hw := width * 0.5
		var gap := 14.0 if not small else 9.0
		draw_line(Vector2(-hw, 0), Vector2(-gap, 0), c, 1.2, true)
		draw_line(Vector2(gap, 0), Vector2(hw, 0), c, 1.2, true)
		var s := 6.0 if not small else 4.5
		var hex := PackedVector2Array()
		for i in 7:
			var a := -PI / 2.0 + i * TAU / 6.0
			hex.append(Vector2(cos(a), sin(a)) * s)
		draw_polyline(hex, c, 1.3, true)
		draw_circle(Vector2(-hw, 0), 1.8, c)
		draw_circle(Vector2(hw, 0), 1.8, c)


## Chama da tela de título.
class TitleFlame extends Node2D:
	var _t := 0.0
	var _glow: Sprite2D

	func _ready() -> void:
		_glow = FX.make_glow(Color(1.0, 0.75, 0.42, 0.55), 260.0)
		_glow.position = Vector2(0, -10)
		add_child(_glow)
		material = FX.additive()

	func _process(delta: float) -> void:
		_t += delta
		_glow.modulate.a = 0.45 + 0.08 * sin(_t * 3.1)
		queue_redraw()

	func _draw() -> void:
		var f := 0.9 + 0.06 * sin(_t * 8.7) + 0.04 * sin(_t * 21.0)
		FX.draw_flame(self, Vector2(0, 26), 52.0 * f, 22.0, sin(_t * 1.7) * 0.06,
			Color(1.0, 0.7, 0.35, 0.85), Color(1.0, 0.9, 0.7, 0.9), Color(1, 1, 1, 0.95))
		draw_line(Vector2(0, 26), Vector2(1, 40), Color(0.16, 0.14, 0.12), 3.0, true)
