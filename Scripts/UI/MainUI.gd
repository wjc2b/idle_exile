class_name MainUI
extends Control

## 三页主界面：构筑（技能槽/天赋）、战斗（挂机与日志）、角色（背包场景，按 I 开关）。
## 角色页直接实例化 Screens/ui/Character/InventoryUI.tscn，布局在编辑器里改。

signal skill_slot_changed(index: int, skill_id: String)
signal talent_requested(talent_id: String)
signal equip_requested(item: Item)
signal equip_into_requested(item: Item, slot_key: String)
signal unequip_requested(slot_key: String)
signal upgrade_requested(item: Item)
signal save_requested
signal reset_requested
signal exchange_requested

const LOG_LIMIT := 200
const TAB_NAMES := ["构筑", "战斗", "角色"]
const TAB_CHARACTER := 2
const InventoryScene := preload("res://Screens/ui/Character/InventoryUI.tscn")

var character: Character
var combat: CombatSystem

var _built := false
var _build_dirty := true
var _inventory_dirty := true
var _current_tab := 1
## 关闭角色页时回到的那一页（最近一次看的非角色页）。
var _prev_tab := 1
var _log_lines := 0
## 打开时默认显示哪一页（0 构筑 / 1 战斗 / 2 角色），调试用 --tab=N 覆盖。
var initial_tab := 0

var _class_label: Label
var _level_label: Label
var _gold_label: Label
var _material_label: Label
var _talent_label: Label
var _exchange_button: Button

var _tab_buttons: Array[Button] = []
var _tabs: Array[Control] = []

var _skill_rows: VBoxContainer
var _skill_options: Array[OptionButton] = []
var _talent_box: VBoxContainer
var _talent_hint: Label

var _wave_label: Label
var _enemy_name: Label
var _enemy_bar: ProgressBar
var _enemy_text: Label
var _player_bar: ProgressBar
var _player_text: Label
var _buff_label: Label
var _log: RichTextLabel
var _kills_label: Label
var _gold_earned_label: Label
var _time_label: Label

var inventory_view: InventoryUI


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build_theme()
	_build_chrome()
	_show_tab(initial_tab)
	_built = true


## I 键开关角色页（背包），Esc 只负责关掉它。
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_I:
			toggle_character()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _current_tab == TAB_CHARACTER:
				_show_tab(_prev_tab)
				get_viewport().set_input_as_handled()


func toggle_character() -> void:
	if _current_tab == TAB_CHARACTER:
		_show_tab(_prev_tab)
	else:
		_show_tab(TAB_CHARACTER)


func mark_build_dirty() -> void:
	_build_dirty = true


func mark_inventory_dirty() -> void:
	_inventory_dirty = true


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


func refresh(stats: Dictionary) -> void:
	if not _built or character == null or combat == null:
		return

	_class_label.text = "放逐者 · %s" % character.class_display()
	_level_label.text = "等级 %d" % character.level
	_gold_label.text = "金币 %s" % Num.fmt(character.gold)
	_material_label.text = "%s %d" % [GameData.MATERIAL_NAME, character.materials]
	_talent_label.text = "天赋点 %d" % character.talent_points_left()
	if _exchange_button != null:
		_exchange_button.disabled = character.gold < GameData.EXCHANGE_GOLD

	var enemy := combat.enemy
	if enemy != null:
		_wave_label.text = "第 %d 波" % combat.wave
		_enemy_name.text = enemy.display_name()
		_enemy_bar.max_value = maxf(1.0, enemy.max_hp())
		_enemy_bar.value = clampf(enemy.hp, 0.0, enemy.max_hp())
		_enemy_text.text = "生命 %s / %s    护甲 %s" % [
			Num.fmt(maxf(enemy.hp, 0.0)),
			Num.fmt(enemy.max_hp()),
			Num.fmt(enemy.armor()),
		]

	var max_hp := combat.max_hp()
	_player_bar.max_value = max_hp
	_player_bar.value = clampf(combat.player_hp, 0.0, max_hp)
	var respawn_text := ""
	if combat.dead:
		respawn_text = "重生中 %.1f 秒" % combat._respawn_timer
	_player_text.text = "生命 %s / %s    %s" % [
		Num.fmt(maxf(combat.player_hp, 0.0)),
		Num.fmt(max_hp),
		respawn_text,
	]
	_buff_label.text = _buffs_text()

	_kills_label.text = str(stats.get("kills", 0))
	_gold_earned_label.text = Num.fmt(float(stats.get("gold_earned", 0.0)))
	_time_label.text = Num.fmt_time(float(stats.get("playtime", 0.0)))

	if _build_dirty:
		_build_dirty = false
		_rebuild_build_tab()
	if _inventory_dirty:
		_inventory_dirty = false
		if inventory_view != null:
			inventory_view.refresh()


func _buffs_text() -> String:
	var parts: Array[String] = []
	for buff in combat.active_buffs():
		parts.append("%s %.1fs" % [buff.get("name", ""), float(buff.get("remaining", 0.0))])
	return "  ·  ".join(parts)


func _build_chrome() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_build_header())

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	column.add_child(tabs_row)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = "角色 (I)" if i == TAB_CHARACTER else TAB_NAMES[i]
		button.custom_minimum_size = Vector2(120, 44)
		button.add_theme_font_size_override("font_size", 19)
		UITheme.style_button(button)
		button.pressed.connect(_show_tab.bind(i))
		tabs_row.add_child(button)
		_tab_buttons.append(button)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)

	_tabs.append(_build_build_tab())
	_tabs.append(_build_combat_tab())
	_tabs.append(_build_character_tab())
	for tab in _tabs:
		tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_child(tab)


func _build_header() -> Control:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.070, 0.078, 0.098)))
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_right", 16)
	padding.add_theme_constant_override("margin_bottom", 10)
	header.add_child(padding)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	padding.add_child(row)

	var avatar := _class_portrait(46.0)
	row.add_child(avatar)
	_class_label = UITheme.label("放逐者", 24, UITheme.GOLD)
	row.add_child(_class_label)
	_level_label = UITheme.label("等级 1", 18, UITheme.TEXT)
	row.add_child(_level_label)
	_gold_label = UITheme.label("金币 0", 18, UITheme.GOLD)
	row.add_child(_gold_label)
	_material_label = UITheme.label(GameData.MATERIAL_NAME + " 0", 18, UITheme.TEXT)
	row.add_child(_material_label)
	_talent_label = UITheme.label("天赋点 0", 18, UITheme.OK)
	row.add_child(_talent_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_exchange_button = Button.new()
	_exchange_button.text = "换%s (%s金)" % [GameData.MATERIAL_NAME, Num.fmt(GameData.EXCHANGE_GOLD)]
	_exchange_button.custom_minimum_size = Vector2(158, 38)
	_exchange_button.add_theme_font_size_override("font_size", 16)
	_exchange_button.tooltip_text = "%s 金币兑换 %d %s" % [
		Num.fmt(GameData.EXCHANGE_GOLD), GameData.EXCHANGE_MATERIALS, GameData.MATERIAL_NAME,
	]
	UITheme.style_button(_exchange_button)
	_exchange_button.pressed.connect(func(): exchange_requested.emit())
	row.add_child(_exchange_button)

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.custom_minimum_size = Vector2(88, 38)
	UITheme.style_button(save_button)
	save_button.pressed.connect(func(): save_requested.emit())
	row.add_child(save_button)

	var reset_button := Button.new()
	reset_button.text = "重开"
	reset_button.custom_minimum_size = Vector2(88, 38)
	UITheme.style_button(reset_button)
	reset_button.pressed.connect(func(): reset_requested.emit())
	row.add_child(reset_button)

	return header


func _class_portrait(height: float) -> TextureRect:
	var node := TextureRect.new()
	var path := ""
	if character != null:
		path = str(character.class_data().get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		node.texture = load(path)
	node.custom_minimum_size = Vector2(height, height)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node


func _build_build_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.add_theme_constant_override("margin_left", 4)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_right", 4)
	padding.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(padding)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	padding.add_child(box)

	box.add_child(UITheme.heading("技能槽"))
	box.add_child(UITheme.label("同一个技能只能放进一个槽位；技能会自动按冷却轮转释放。", 15, UITheme.DIM, true))
	_skill_rows = VBoxContainer.new()
	_skill_rows.add_theme_constant_override("separation", 8)
	box.add_child(_skill_rows)

	box.add_child(HSeparator.new())
	box.add_child(UITheme.heading("天赋"))
	_talent_hint = UITheme.label("", 15, UITheme.DIM)
	box.add_child(_talent_hint)
	_talent_box = VBoxContainer.new()
	_talent_box.add_theme_constant_override("separation", 8)
	box.add_child(_talent_box)

	box.add_child(HSeparator.new())
	box.add_child(UITheme.heading("装备"))
	box.add_child(UITheme.label(
		"装备与背包在「角色」页（按 I 打开）：左边 8 个部位，右边战利品；右键装备/卸下，也可以拖过去。",
		15, UITheme.DIM, true))

	return scroll


func _build_combat_tab() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 28)
	padding.add_theme_constant_override("margin_top", 20)
	padding.add_theme_constant_override("margin_right", 28)
	padding.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(padding)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	padding.add_child(box)

	_wave_label = UITheme.label("第 1 波", 24, UITheme.GOLD)
	box.add_child(_wave_label)
	_enemy_name = UITheme.label("", 34, UITheme.TEXT)
	box.add_child(_enemy_name)
	_enemy_bar = UITheme.progress(UITheme.ENEMY_HP)
	box.add_child(_enemy_bar)
	_enemy_text = UITheme.label("", 15, UITheme.DIM)
	box.add_child(_enemy_text)

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 16)
	box.add_child(player_row)
	player_row.add_child(_class_portrait(104.0))
	var player_info := VBoxContainer.new()
	player_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_info.add_theme_constant_override("separation", 6)
	player_row.add_child(player_info)
	_player_bar = UITheme.progress(UITheme.HP)
	player_info.add_child(_player_bar)
	_player_text = UITheme.label("", 15, UITheme.TEXT)
	player_info.add_child(_player_text)
	_buff_label = UITheme.label("", 15, UITheme.OK)
	player_info.add_child(_buff_label)

	box.add_child(HSeparator.new())
	box.add_child(UITheme.label("战斗日志", 15, UITheme.DIM))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 200)
	_log.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_log)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 30)
	box.add_child(footer)
	footer.add_child(UITheme.label("击杀", 15, UITheme.DIM))
	_kills_label = UITheme.label("0", 18, UITheme.TEXT)
	footer.add_child(_kills_label)
	footer.add_child(UITheme.label("累计金币", 15, UITheme.DIM))
	_gold_earned_label = UITheme.label("0", 18, UITheme.GOLD)
	footer.add_child(_gold_earned_label)
	footer.add_child(UITheme.label("游戏时长", 15, UITheme.DIM))
	_time_label = UITheme.label("0秒", 18, UITheme.TEXT)
	footer.add_child(_time_label)

	return panel


## 角色页：实例化编辑器里做好的背包界面，信号转成 MainUI 的统一出口。
func _build_character_tab() -> Control:
	inventory_view = InventoryScene.instantiate()
	inventory_view.character = character
	inventory_view.equip_requested.connect(func(item: Item): equip_requested.emit(item))
	inventory_view.equip_into_requested.connect(
		func(item: Item, key: String): equip_into_requested.emit(item, key))
	inventory_view.unequip_requested.connect(func(key: String): unequip_requested.emit(key))
	inventory_view.upgrade_requested.connect(func(item: Item): upgrade_requested.emit(item))
	return inventory_view


func _show_tab(index: int) -> void:
	var target := clampi(index, 0, _tabs.size() - 1)
	if target == TAB_CHARACTER:
		if _current_tab != TAB_CHARACTER:
			_prev_tab = _current_tab
		# 打开时重算一次，免得看到过期的背包。
		if inventory_view != null:
			inventory_view.refresh()
	_current_tab = target
	for i in range(_tabs.size()):
		_tabs[i].visible = i == _current_tab
	for i in range(_tab_buttons.size()):
		var active := i == _current_tab
		_tab_buttons[i].add_theme_color_override("font_color", UITheme.GOLD if active else UITheme.TEXT)


func _rebuild_build_tab() -> void:
	if character == null:
		return
	_clear_children(_skill_rows)
	_skill_options.clear()

	var skills: Array = character.available_skills()
	for i in range(GameData.MAX_SKILL_SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var tag := UITheme.label("槽位 %d" % (i + 1), 16, UITheme.DIM)
		tag.custom_minimum_size = Vector2(84, 0)
		row.add_child(tag)

		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size = Vector2(0, 40)
		option.add_theme_font_size_override("font_size", 16)
		UITheme.style_button(option)
		for skill_id in skills:
			var data := GameData.skill(str(skill_id))
			option.add_item(str(data.get("name", skill_id)))
		var current := ""
		if i < character.skill_slots.size():
			current = str(character.skill_slots[i])
		option.selected = maxi(0, skills.find(current))
		option.item_selected.connect(_on_skill_option_selected.bind(i))
		row.add_child(option)
		_skill_options.append(option)
		_skill_rows.add_child(row)

	_talent_hint.text = "可用天赋点 %d（每升 1 级得 1 点）" % character.talent_points_left()
	_clear_children(_talent_box)
	for talent_id in character.talent_ranks.keys():
		_talent_box.add_child(_build_talent_row(str(talent_id)))


func _build_talent_row(talent_id: String) -> Control:
	var data := GameData.talent(talent_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := UITheme.label(str(data.get("name", talent_id)), 18, UITheme.TEXT)
	name_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_label)

	var desc := UITheme.label(str(data.get("desc", "")), 15, UITheme.DIM)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	var rank := character.talent_rank(talent_id)
	var max_rank := int(data.get("max", 1))
	row.add_child(UITheme.label("%d / %d" % [rank, max_rank], 16, UITheme.GOLD if rank > 0 else UITheme.DIM))

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(46, 36)
	UITheme.style_button(plus)
	plus.disabled = not character.can_allocate(talent_id)
	plus.pressed.connect(_on_talent_pressed.bind(talent_id))
	row.add_child(plus)
	return row


func _clear_children(box: Node) -> void:
	if box == null:
		return
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _on_skill_option_selected(item_index: int, row: int) -> void:
	var skills: Array = character.available_skills()
	if item_index < 0 or item_index >= skills.size():
		return
	skill_slot_changed.emit(row, str(skills[item_index]))


func _on_talent_pressed(talent_id: String) -> void:
	talent_requested.emit(talent_id)
