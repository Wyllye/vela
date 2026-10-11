class_name GridBody
extends RefCounted
## Caixa de colisão (canto superior esquerdo + tamanho) usada pela LevelGrid.

var pos := Vector2.ZERO
var size := Vector2(22, 44)


func rect() -> Rect2:
	return Rect2(pos, size)


func center() -> Vector2:
	return pos + size * 0.5


func feet() -> Vector2:
	return pos + Vector2(size.x * 0.5, size.y)
