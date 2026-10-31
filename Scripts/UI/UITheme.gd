class_name UITheme
extends RefCounted

## 统一的配色、字体与常用控件工厂，让两个界面长得像同一款游戏。

const TEXT := Color(0.87, 0.89, 0.93)
const DIM := Color(0.58, 0.62, 0.70)
const GOLD := Color(0.93, 0.77, 0.36)
const DANGER := Color(0.88, 0.42, 0.40)
const OK := Color(0.50, 0.82, 0.58)
const BG := Color(0.043, 0.047, 0.060)
const PANEL := Color(0.086, 0.094, 0.118)
const PANEL_BORDER := Color(0.19, 0.21, 0.27)
const HP := Color(0.80, 0.30, 0.32)
const ENEMY_HP := Color(0.72, 0.36, 0.86)
const ACCENT_BAR := Color(0.36, 0.62, 0.92)

## 暗黑/流放之路那套青铜描边配色。
const FRAME_GOLD := Color(0.68, 0.53, 0.28)
const FRAME_DIM := Color(0.30, 0.25, 0.15)
const SLOT_BG := Color(0.030, 0.028, 0.036)


static func build_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"PingFang SC",
		"WenQuanYi Micro Hei",
		"sans-serif",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	result.default_font = font
	result.default_font_size = 18
	# 装备提示默认 18 号会糊住整个纸娃娃，单独调小。
	result.set_font_size("font_size", "TooltipLabel", 15)
	return result


static func panel_style(bg: Color = PANEL, border: Color = PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(8)
	return style


static func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color(0.14, 0.16, 0.21), Color(0.26, 0.29, 0.36)))
	button.add_theme_stylebox_override("hover", button_style(Color(0.18, 0.21, 0.27), GOLD))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.11, 0.13, 0.17), GOLD))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.10, 0.11, 0.14), Color(0.17, 0.18, 0.22)))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.43, 0.50))


static func label(content: String, size: int, color: Color, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func heading(content: String) -> Label:
	return label(content, 26, GOLD)


## 带左右细线的段落标题，比纯文字像"设计过"。
static func section_heading(content: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_rule())
	row.add_child(label(content, 21, FRAME_GOLD))
	row.add_child(_rule())
	return row


static func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.26, 0.21, 0.12)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


## 面板用：稍亮一点的青铜边框。
static func frame_style(bg: Color = PANEL, border: Color = Color(0.26, 0.21, 0.13)) -> StyleBoxFlat:
	var style := panel_style(bg, border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


static func progress(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 22)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)

	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.16, 0.17, 0.21)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", back)
	return bar
