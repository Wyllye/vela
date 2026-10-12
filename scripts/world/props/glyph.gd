class_name AuraGlyph
extends Node2D
## Escrita em aura: o que os monges escreveram para não ser lido à luz da vela.
## Sem Gyo é quase nada — um tremor no ar para quem presta atenção. Com os
## olhos de aura (ou depois que a onda do En passa), as letras se escrevem
## sozinhas, da esquerda para a direita, e o texto aparece na tela.
##
## Os dados vêm do JSON da sala ("aura"): chave do texto, autor (a cor da
## aura de quem escreveu) e tamanho em tiles (glifo pequeno ou parede inteira).

const MONK := Color("d9d2ff")
const ABBESS := Color("ffd6f0")

var text_key := ""
var author := "monge"
var color := MONK
## Tamanho da escrita em px (o centro é a origem do nó).
var size := Vector2(48, 40)
var wall := false
## 0..1: quanto está revelada agora (vem da AuraLayer da sala).
var reveal := 0.0
var read := false
var layer: AuraLayer
var _t := 0.0
var _strokes: Array = []
var _seal := Vector2.ZERO


func setup(entry: Dictionary, seed_value: int) -> void:
	text_key = str(entry.get("text", ""))
	author = str(entry.get("author", "monge"))
	color = ABBESS if author == "abadessa" else MONK
	var w := float(entry.get("w", 0))
	var h := float(entry.get("h", 0))
	wall = w > 1.5 or h > 1.5
	if wall:
		size = Vector2(w * 32.0 - 12.0, h * 32.0 - 10.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if wall:
		_seal = Vector2(-size.x * 0.5 + 12.0, -size.y * 0.5 + 12.0)
		_strokes = _script(rng, Rect2(-size.x * 0.5 + 30.0, -size.y * 0.5 + 4.0, size.x - 36.0, size.y - 8.0))
	else:
		_seal = Vector2(0, -8)
		_strokes = _script(rng, Rect2(-22, 9, 44, 16))


func _ready() -> void:
	material = FX.additive()
	light_mask = 0
	z_index = 2


## Linhas de uma escrita cursiva inventada: palavras feitas de laços e ganchos.
func _script(rng: RandomNumberGenerator, area: Rect2) -> Array:
	var out := []
	var lines := maxi(1, int(area.size.y / 15.0))
	for li in lines:
		var y := area.position.y + (li + 0.5) * area.size.y / lines
		var x := area.position.x + rng.randf_range(0.0, 6.0)
		while x < area.end.x - 8.0:
			var word := PackedVector2Array([Vector2(x, y + rng.randf_range(-1.0, 1.0))])
			for letter in rng.randi_range(2, 5):
				var lw := rng.randf_range(4.5, 7.5)
				match rng.randi() % 4:
					0:  # laço
						word.append(Vector2(x + lw * 0.3, y - 5.5))
						word.append(Vector2(x + lw * 0.65, y - 2.0))
						word.append(Vector2(x + lw * 0.4, y + 0.5))
					1:  # haste alta
						word.append(Vector2(x + lw * 0.2, y - 8.0))
						word.append(Vector2(x + lw * 0.35, y + 1.0))
					2:  # gancho para baixo
						word.append(Vector2(x + lw * 0.5, y + 4.5))
						word.append(Vector2(x + lw * 0.8, y - 1.5))
					_:  # onda
						word.append(Vector2(x + lw * 0.33, y - 3.0))
						word.append(Vector2(x + lw * 0.66, y + 2.0))
				x += lw
				word.append(Vector2(x, y + rng.randf_range(-1.0, 1.0)))
			if x > area.end.x:
				break
			out.append(word)
			x += rng.randf_range(5.0, 9.0)
	return out


func _process(delta: float) -> void:
	_t += delta
	if layer != null and is_instance_valid(layer):
		reveal = layer.reveal_at(global_position)
	queue_redraw()


func _draw() -> void:
	# escondida: só um tremor no ar
	var hidden_a := 0.035 + 0.035 * (0.5 + 0.5 * sin(_t * 1.3))
	var k := clampf(reveal, 0.0, 1.0)
	var hexa := PackedVector2Array()
	var sr := 12.0 if not wall else 9.0
	for i in 7:
		var ang := -PI / 2.0 + i * TAU / 6.0 + _t * 0.15
		hexa.append(_seal + Vector2(cos(ang), sin(ang)) * sr)
	draw_polyline(hexa, Color(color, hidden_a * 1.4 + 0.75 * k), 1.3, true)
	if k < 0.02:
		for st in _strokes.slice(0, 3):
			draw_polyline(st, Color(color, hidden_a), 1.0, true)
		return
	# brilho de fundo
	draw_circle(_seal, sr * 2.2, Color(color, 0.06 * k))
	if wall:
		draw_rect(Rect2(-size * 0.5, size), Color(color, 0.025 * k))
	# as letras se escrevem da esquerda para a direita
	var left := -size.x * 0.5
	for st: PackedVector2Array in _strokes:
		var start_k := clampf((st[0].x - left) / maxf(size.x, 1.0), 0.0, 1.0) * 0.6
		var wk := clampf((k - start_k) / 0.4, 0.0, 1.0)
		if wk <= 0.0:
			continue
		var n := maxi(2, int(ceil(st.size() * wk)))
		var part := st.slice(0, n)
		var flick := 0.85 + 0.15 * sin(_t * 4.0 + st[0].x * 0.3 + st[0].y)
		draw_polyline(part, Color(color, 0.22 * wk), 3.2, true)
		draw_polyline(part, Color(color.lightened(0.2), (0.8 if not read else 0.6) * wk * flick), 1.2, true)
