class_name MainUI
extends Control

## 纯代码构建的界面：三栏布局（角色 / 战斗 / 统计）。
## 不依赖任何 .tscn 结构，改动布局只改这里。

signal buy_requested(kind: String)
signal save_requested
signal reset_requested

const COLOR_TEXT := Color(0.87, 0.89, 0.93)
const COLOR_DIM := Color(0.58, 0.62, 0.70)
const COLOR_GOLD := Color(0.93, 0.77, 0.36)
const COLOR_DANGER := Color(0.88, 0.42, 0.40)
const COLOR_BG := Color(0.043, 0.047, 0.060)
const COLOR_PANEL := Color(0.086, 0.094, 0.118)
const COLOR_PANEL_BORDER := Color(0.19, 0.21, 0.27)
const COLOR_HP := Color(0.80, 0.30, 0.32)
const COLOR_EXP := Color(0.36, 0.62, 0.92)
const COLOR_ENEMY := Color(0.72, 0.36, 0.86)

const LOG_LIMIT := 200
const UPGRADE_LABELS := {"atk": "强化攻击", "def": "强化防御", "hp": "强化生命"}

var player: PlayerState
var combat: CombatSystem

var _level_label: Label
var _gold_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _exp_bar: ProgressBar
var _exp_text: Label
var _stat_values: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _wave_label: Label
var _enemy_name: Label
var _enemy_bar: ProgressBar
var _enemy_text: Label
var _enemy_stats: Label
var _respawn_label: Label
var _log: RichTextLabel
var _kills_label: Label
var _earned_label: Label
var _time_label: Label
var _status_label: Label

var _log_lines := 0
var _built := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()
	_build_layout()
	_built = true


func refresh(stats: Dictionary) -> void:
	if not _built or player == null or combat == null:
		return

	_level_label.text = "等级 %d" % player.level
	_gold_label.text = "金币 %s" % Num.fmt(player.gold)

	var max_hp := maxf(1.0, player.max_hp())
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampf(player.hp, 0.0, max_hp)
	_hp_text.text = "生命 %s / %s" % [Num.fmt(maxf(player.hp, 0.0)), Num.fmt(player.max_hp())]

	var need := maxf(1.0, player.exp_to_next())
	_exp_bar.max_value = need
	_exp_bar.value = clampf(player.exp, 0.0, need)
	_exp_text.text = "经验 %s / %s" % [Num.fmt(player.exp), Num.fmt(player.exp_to_next())]

	_stat_values["攻击"].text = Num.fmt(player.attack())
	_stat_values["防御"].text = Num.fmt(player.defense())
	_stat_values["生命上限"].text = Num.fmt(player.max_hp())
	_stat_values["每秒伤害"].text = Num.fmt(player.attack() / CombatSystem.PLAYER_ATTACK_INTERVAL)

	for kind in _upgrade_buttons.keys():
		var button: Button = _upgrade_buttons[kind]
		var cost := player.upgrade_cost(kind)
		button.text = "%s %s   ·   %s 金币" % [
			UPGRADE_LABELS.get(kind, kind),
			player.upgrade_effect(kind),
			Num.fmt(cost),
		]
		button.disabled = player.gold < cost

	var enemy := combat.enemy
	if enemy != null:
		_wave_label.text = "第 %d 波" % enemy.wave
		_enemy_name.text = enemy.display_name()
		var enemy_max := maxf(1.0, enemy.max_hp())
		_enemy_bar.max_value = enemy_max
		_enemy_bar.value = clampf(enemy.hp, 0.0, enemy_max)
		_enemy_text.text = "生命 %s / %s" % [Num.fmt(maxf(enemy.hp, 0.0)), Num.fmt(enemy.max_hp())]
		_enemy_stats.text = "攻击 %s    ·    防御 %s    ·    击杀奖励 %s 金币" % [
			Num.fmt(enemy.attack()),
			Num.fmt(enemy.defense()),
			Num.fmt(enemy.gold_reward()),
		]

	_respawn_label.text = "重生中 %.1f 秒" % combat.respawn_timer if combat.dead else ""

	_kills_label.text = str(stats.get("kills", 0))
	_earned_label.text = Num.fmt(float(stats.get("gold_earned", 0.0)))
	_time_label.text = Num.fmt_time(float(stats.get("playtime", 0.0)))


func push_log(line: String) -> void:
	if _log == null:
		return
	if _log_lines >= LOG_LIMIT:
		_log.clear()
		_log_lines = 0
		_log.append_text("[i][color=#6a7080]（较早的日志已省略）[/color][/i]\n")
	_log.append_text(line + "\n")
	_log_lines += 1


func clear_log() -> void:
	if _log == null:
		return
	_log.clear()
	_log_lines = 0


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _build_theme() -> Theme:
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
	return result


func _build_layout() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 22)
	margin.add_child(columns)

	_build_hero_column(columns)
	_build_battle_column(columns)
	_build_stats_column(columns)


func _build_hero_column(parent: Container) -> void:
	var box := _make_column(parent, 440.0)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	title_row.add_child(_heading("放逐者"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(gap)
	_level_label = _text("等级 1", 20, COLOR_TEXT)
	title_row.add_child(_level_label)

	_gold_label = _text("金币 0", 20, COLOR_GOLD)
	box.add_child(_gold_label)

	box.add_child(_text("生命", 15, COLOR_DIM))
	_hp_bar = _progress(COLOR_HP)
	box.add_child(_hp_bar)
	_hp_text = _text("", 15, COLOR_TEXT)
	box.add_child(_hp_text)

	box.add_child(_text("经验", 15, COLOR_DIM))
	_exp_bar = _progress(COLOR_EXP)
	box.add_child(_exp_bar)
	_exp_text = _text("", 15, COLOR_TEXT)
	box.add_child(_exp_text)

	box.add_child(HSeparator.new())
	box.add_child(_heading("属性"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for key in ["攻击", "防御", "生命上限", "每秒伤害"]:
		grid.add_child(_text(key, 17, COLOR_DIM))
		var value := _text("-", 17, COLOR_TEXT)
		grid.add_child(value)
		_stat_values[key] = value

	box.add_child(HSeparator.new())
	box.add_child(_heading("强化"))

	for kind in ["atk", "def", "hp"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 18)
		_style_button(button)
		button.pressed.connect(_on_upgrade_pressed.bind(kind))
		box.add_child(button)
		_upgrade_buttons[kind] = button

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	box.add_child(_hint("强化价格随购买次数按 %.0f%% 递增" % ((PlayerState.COST_GROWTH - 1.0) * 100.0)))


func _build_battle_column(parent: Container) -> void:
	var box := _make_column(parent, 0.0)

	var header := HBoxContainer.new()
	box.add_child(header)
	_wave_label = _text("第 1 波", 22, COLOR_GOLD)
	header.add_child(_wave_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	_respawn_label = _text("", 18, COLOR_DANGER)
	header.add_child(_respawn_label)

	_enemy_name = _text("", 34, COLOR_TEXT)
	box.add_child(_enemy_name)

	_enemy_bar = _progress(COLOR_ENEMY)
	box.add_child(_enemy_bar)
	_enemy_text = _text("", 15, COLOR_TEXT)
	box.add_child(_enemy_text)
	_enemy_stats = _text("", 15, COLOR_DIM)
	box.add_child(_enemy_stats)

	box.add_child(HSeparator.new())
	box.add_child(_text("战斗日志", 15, COLOR_DIM))

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 220)
	_log.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_log)


func _build_stats_column(parent: Container) -> void:
	var box := _make_column(parent, 400.0)
	box.add_child(_heading("统计"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	grid.add_child(_text("击杀", 17, COLOR_DIM))
	_kills_label = _text("0", 17, COLOR_TEXT)
	grid.add_child(_kills_label)
	grid.add_child(_text("累计金币", 17, COLOR_DIM))
	_earned_label = _text("0", 17, COLOR_TEXT)
	grid.add_child(_earned_label)
	grid.add_child(_text("游戏时长", 17, COLOR_DIM))
	_time_label = _text("0秒", 17, COLOR_TEXT)
	grid.add_child(_time_label)

	box.add_child(HSeparator.new())
	box.add_child(_heading("存档"))

	var save_button := Button.new()
	save_button.text = "立即保存"
	save_button.custom_minimum_size = Vector2(0, 48)
	save_button.add_theme_font_size_override("font_size", 18)
	_style_button(save_button)
	save_button.pressed.connect(_on_save_pressed)
	box.add_child(save_button)

	var reset_button := Button.new()
	reset_button.text = "重置记录"
	reset_button.custom_minimum_size = Vector2(0, 48)
	reset_button.add_theme_font_size_override("font_size", 18)
	_style_button(reset_button)
	reset_button.pressed.connect(_on_reset_pressed)
	box.add_child(reset_button)

	_status_label = _text("", 15, COLOR_DIM)
	box.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	box.add_child(_hint("自动保存间隔 10 秒，关闭窗口也会保存。离线最多结算 8 小时。"))
	box.add_child(_hint("当前为最小可玩版本：自动战斗 → 掉金币 → 强化属性 → 推进波次。"))


func _on_upgrade_pressed(kind: String) -> void:
	buy_requested.emit(kind)


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_reset_pressed() -> void:
	reset_requested.emit()


func _make_column(parent: Container, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	if width > 0.0:
		panel.custom_minimum_size = Vector2(width, 0)
	else:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 24)
	padding.add_theme_constant_override("margin_top", 22)
	padding.add_theme_constant_override("margin_right", 24)
	padding.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(padding)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	padding.add_child(box)
	return box


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(Color(0.14, 0.16, 0.21), Color(0.26, 0.29, 0.36)))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.18, 0.21, 0.27), COLOR_GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color(0.11, 0.13, 0.17), COLOR_GOLD))
	button.add_theme_stylebox_override("disabled", _button_box(Color(0.10, 0.11, 0.14), Color(0.17, 0.18, 0.22)))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.43, 0.50))


func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(10)
	return style


func _progress(fill_color: Color) -> ProgressBar:
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


func _heading(text: String) -> Label:
	return _text(text, 26, COLOR_GOLD)


func _text(content: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _hint(content: String) -> Label:
	var label := _text(content, 14, COLOR_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
