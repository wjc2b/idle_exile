class_name EquipIcon
extends Control

## 没有图标素材，所以用代码画剪影：100x100 归一化坐标，按控件尺寸缩放。
## 空槽用暗金色幽灵态，装备后用稀有度颜色填充。

const GHOST := Color(0.52, 0.44, 0.30, 0.55)

var kind := "head"
var fill := Color(0.72, 0.66, 0.54)
var ghost := false

var _s := 1.0
var _o := Vector2.ZERO
var _main := Color.WHITE
var _line := Color.WHITE


func set_kind(value: String) -> void:
	if kind == value:
		return
	kind = value
	queue_redraw()


func set_visual(value: Color, is_ghost: bool) -> void:
	fill = value
	ghost = is_ghost
	queue_redraw()


func _draw() -> void:
	_s = minf(size.x, size.y) / 100.0
	_o = (size - Vector2(100.0, 100.0) * _s) * 0.5
	_main = GHOST if ghost else fill
	_line = _main.darkened(0.55)
	if ghost:
		_line = Color(0.38, 0.32, 0.22, 0.45)

	match kind:
		"head":
			_head()
		"body":
			_body()
		"legs":
			_legs()
		"main_hand":
			_sword()
		"off_hand":
			_shield()
		"ring":
			_ring()
		"amulet":
			_amulet()


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _head() -> void:
	var pts: Array[Vector2] = []
	for i in range(13):
		var a := PI + PI * float(i) / 12.0
		pts.append(_p(50.0 + 27.0 * cos(a), 60.0 + 27.0 * sin(a)))
	pts.append(_p(77.0, 76.0))
	pts.append(_p(23.0, 76.0))
	draw_colored_polygon(PackedVector2Array(pts), _main)
	draw_rect(Rect2(_p(30.0, 62.0), Vector2(40.0, 9.0) * _s), _line)
	draw_line(_p(50.0, 34.0), _p(50.0, 62.0), _line, 2.0 * _s)
	draw_line(_p(33.0, 76.0), _p(67.0, 76.0), _line, 3.0 * _s)


func _body() -> void:
	draw_colored_polygon(PackedVector2Array([
		_p(32.0, 30.0), _p(40.0, 22.0), _p(60.0, 22.0), _p(68.0, 30.0),
		_p(71.0, 46.0), _p(67.0, 84.0), _p(33.0, 84.0), _p(29.0, 46.0),
	]), _main)
	draw_line(_p(50.0, 22.0), _p(50.0, 44.0), _line, 2.0 * _s)
	draw_line(_p(29.0, 68.0), _p(71.0, 68.0), _line, 5.0 * _s)
	draw_rect(Rect2(_p(46.0, 64.0), Vector2(8.0, 8.0) * _s), _line)


func _legs() -> void:
	draw_rect(Rect2(_p(33.0, 18.0), Vector2(34.0, 11.0) * _s), _main)
	draw_rect(Rect2(_p(35.0, 27.0), Vector2(13.0, 56.0) * _s), _main)
	draw_rect(Rect2(_p(52.0, 27.0), Vector2(13.0, 56.0) * _s), _main)
	draw_line(_p(33.0, 30.0), _p(67.0, 30.0), _line, 2.0 * _s)
	draw_line(_p(35.0, 64.0), _p(48.0, 64.0), _line, 2.0 * _s)
	draw_line(_p(52.0, 64.0), _p(65.0, 64.0), _line, 2.0 * _s)


func _sword() -> void:
	draw_colored_polygon(PackedVector2Array([
		_p(50.0, 6.0), _p(58.0, 24.0), _p(58.0, 60.0), _p(42.0, 60.0), _p(42.0, 24.0),
	]), _main)
	draw_line(_p(50.0, 12.0), _p(50.0, 58.0), _line, 1.5 * _s)
	draw_rect(Rect2(_p(29.0, 60.0), Vector2(42.0, 7.0) * _s), _main)
	draw_rect(Rect2(_p(45.0, 67.0), Vector2(10.0, 18.0) * _s), _main)
	draw_circle(_p(50.0, 88.0), 6.0 * _s, _main)


func _shield() -> void:
	draw_colored_polygon(PackedVector2Array([
		_p(50.0, 8.0), _p(80.0, 20.0), _p(78.0, 50.0), _p(50.0, 88.0),
		_p(22.0, 50.0), _p(20.0, 20.0),
	]), _main)
	draw_polyline(PackedVector2Array([
		_p(50.0, 20.0), _p(70.0, 28.0), _p(68.0, 48.0), _p(50.0, 74.0),
		_p(32.0, 48.0), _p(30.0, 28.0), _p(50.0, 20.0),
	]), _line, 2.0 * _s)
	draw_line(_p(50.0, 24.0), _p(50.0, 72.0), _line, 3.0 * _s)
	draw_line(_p(32.0, 40.0), _p(68.0, 40.0), _line, 3.0 * _s)


func _ring() -> void:
	draw_arc(_p(50.0, 62.0), 21.0 * _s, 0.0, TAU, 32, _main, 7.0 * _s)
	draw_circle(_p(50.0, 28.0), 11.0 * _s, _main)
	draw_circle(_p(50.0, 28.0), 4.5 * _s, _line)
	draw_line(_p(43.0, 38.0), _p(47.0, 46.0), _main, 3.0 * _s)
	draw_line(_p(57.0, 38.0), _p(53.0, 46.0), _main, 3.0 * _s)


func _amulet() -> void:
	draw_arc(_p(50.0, 6.0), 36.0 * _s, 0.22 * PI, 0.78 * PI, 24, _main, 3.5 * _s)
	draw_colored_polygon(PackedVector2Array([
		_p(50.0, 40.0), _p(61.0, 56.0), _p(50.0, 76.0), _p(39.0, 56.0),
	]), _main)
	draw_circle(_p(50.0, 56.0), 6.0 * _s, _line)
