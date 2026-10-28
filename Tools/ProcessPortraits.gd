extends SceneTree

## 一次性资源处理工具：把带黑底的角色图处理成可用的头像。
##   1. 从四边向内泛洪，去掉与边缘连通的近黑背景（人物内部的深色不会被误伤）
##   2. 按不透明像素求包围盒并裁切
##   3. 横排多人物图自动按列空白切成多个头像
## 用法：Godot --headless --path . --script res://Tools/ProcessPortraits.gd

const BLACK_THRESHOLD := 0.05
const PADDING := 6
const OUT_DIR := "res://Assets/Portraits"

const SINGLE_SOURCE := "res://Assets/像素风严肃战士头像.png"
const SHEET_SOURCE := "res://Assets/三位像素奇幻角色肖像.png"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_cut_single(SINGLE_SOURCE, "warrior")

	var sheet := _load_rgba(SHEET_SOURCE)
	_clear_black_border(sheet)
	var segments := _column_segments(sheet)
	print("胸像横排切分：%d 段" % segments.size())
	var names := ["mage", "ranger", "wizard"]
	for i in range(segments.size()):
		var rect: Rect2i = segments[i]
		var piece := sheet.get_region(rect)
		var out_name: String = str(names[i]) if i < names.size() else "portrait_%d" % i
		_save(piece, out_name)
	quit()


func _cut_single(path: String, out_name: String) -> void:
	var image := _load_rgba(path)
	_clear_black_border(image)
	var box := _opaque_box(image)
	if box.size == Vector2i.ZERO:
		push_error("没有找到不透明区域: %s" % path)
		return
	_save(image.get_region(box), out_name)


func _load_rgba(path: String) -> Image:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("无法读取: %s" % path)
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, out_name: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, out_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("保存失败 %s (%d)" % [path, err])
		return
	print("已输出 %s  %dx%d" % [path, image.get_width(), image.get_height()])


func _clear_black_border(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var background := PackedByteArray()
	background.resize(width * height)
	for y in range(height):
		for x in range(width):
			var color := image.get_pixel(x, y)
			var bright := maxf(color.r, maxf(color.g, color.b))
			if bright <= BLACK_THRESHOLD:
				background[y * width + x] = 1

	var stack: PackedInt32Array = []
	for x in range(width):
		stack.append(x)
		stack.append((height - 1) * width + x)
	for y in range(height):
		stack.append(y * width)
		stack.append(y * width + width - 1)

	while stack.size() > 0:
		var index := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if background[index] == 0:
			continue
		background[index] = 0
		var x := index % width
		var y := index / width
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:
			stack.append(index - 1)
		if x < width - 1:
			stack.append(index + 1)
		if y > 0:
			stack.append(index - width)
		if y < height - 1:
			stack.append(index + width)


func _opaque_box(image: Image) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(
		maxi(0, min_x - PADDING),
		maxi(0, min_y - PADDING),
		mini(width, max_x + PADDING + 1) - maxi(0, min_x - PADDING),
		mini(height, max_y + PADDING + 1) - maxi(0, min_y - PADDING)
	)


## 横排图：按"整列都没有不透明像素"的空隙切段。
func _column_segments(image: Image) -> Array[Rect2i]:
	var width := image.get_width()
	var height := image.get_height()
	var filled := PackedByteArray()
	filled.resize(width)
	for x in range(width):
		for y in range(height):
			if image.get_pixel(x, y).a > 0.01:
				filled[x] = 1
				break

	var segments: Array[Rect2i] = []
	var start := -1
	for x in range(width):
		if filled[x] == 1 and start < 0:
			start = x
		elif filled[x] == 0 and start >= 0:
			segments.append(_segment_box(image, start, x - 1))
			start = -1
	if start >= 0:
		segments.append(_segment_box(image, start, width - 1))
	return segments


func _segment_box(image: Image, left: int, right: int) -> Rect2i:
	var min_y := image.get_height()
	var max_y := -1
	for x in range(left, right + 1):
		for y in range(image.get_height()):
			if image.get_pixel(x, y).a > 0.01:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var top := maxi(0, min_y - PADDING)
	var bottom := mini(image.get_height(), max_y + PADDING + 1)
	return Rect2i(left, top, right - left + 1, bottom - top)
