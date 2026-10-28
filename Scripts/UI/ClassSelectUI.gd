class_name ClassSelectUI
extends Control

## 开局界面：三张职业卡，选完才进入构筑/挂机。

signal class_chosen(class_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build_theme()
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	column.add_child(UITheme.label("被放逐者", 44, UITheme.GOLD))
	column.add_child(UITheme.label("选择你的出身。职业决定基础属性、可用技能与天赋方向，之后可以随时调整技能槽与天赋。", 18, UITheme.DIM, true))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	column.add_child(spacer)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)

	for class_id in GameData.CLASSES.keys():
		cards.add_child(_build_card(str(class_id)))

	column.add_child(UITheme.label("提示：先选职业，进游戏后在「构筑」页分配天赋、调整技能槽，再去「战斗」页开始挂机刷宝。", 15, UITheme.DIM, true))


func _build_card(class_id: String) -> Control:
	var data: Dictionary = GameData.CLASSES[class_id]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_spacing(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 26)
	padding.add_theme_constant_override("margin_top", 24)
	padding.add_theme_constant_override("margin_right", 26)
	padding.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(padding)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	padding.add_child(box)

	box.add_child(UITheme.label(str(data.get("name", "")), 36, UITheme.TEXT))
	box.add_child(UITheme.label(str(data.get("tagline", "")), 18, UITheme.GOLD))
	box.add_child(UITheme.label(str(data.get("desc", "")), 15, UITheme.DIM, true))

	var base: Dictionary = data.get("base", {})
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 20)
	stats.add_theme_constant_override("v_separation", 4)
	box.add_child(stats)
	for key in ["damage", "health", "armor"]:
		stats.add_child(UITheme.label(GameData.stat_label(str(key)), 16, UITheme.DIM))
		stats.add_child(UITheme.label(Num.fmt(float(base.get(key, 0.0))), 16, UITheme.TEXT))

	box.add_child(HSeparator.new())
	box.add_child(UITheme.label("可用技能", 15, UITheme.DIM))
	var skill_names: Array[String] = []
	for skill_id in data.get("skills", []):
		skill_names.append(str(GameData.skill(str(skill_id)).get("name", skill_id)))
	box.add_child(UITheme.label(" · ".join(skill_names), 15, UITheme.TEXT, true))

	box.add_child(UITheme.label("天赋方向", 15, UITheme.DIM))
	var talent_names: Array[String] = []
	for talent_id in data.get("talents", []):
		talent_names.append(str(GameData.talent(str(talent_id)).get("name", talent_id)))
	box.add_child(UITheme.label(" · ".join(talent_names), 15, UITheme.TEXT, true))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var button := Button.new()
	button.text = "选择 %s" % data.get("name", "")
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 20)
	UITheme.style_button(button)
	button.pressed.connect(_on_choose.bind(class_id))
	box.add_child(button)

	return panel


func cards_spacing(panel: Control) -> void:
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_choose(class_id: String) -> void:
	class_chosen.emit(class_id)
