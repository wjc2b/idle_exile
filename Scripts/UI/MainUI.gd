class_name MainUI
extends Control

## 三页主界面：构筑（技能槽/天赋/装备）、战斗（挂机与日志）、背包（战利品）。
## 全部用代码搭，改布局只改这个文件。

signal skill_slot_changed(index: int, skill_id: String)
signal talent_requested(talent_id: String)
signal equip_requested(item: Item)
signal unequip_requested(slot: String)
signal upgrade_requested(item: Item)
signal save_requested
signal reset_requested
signal exchange_requested

const LOG_LIMIT := 200
const TAB_NAMES := ["构筑", "战斗", "背包"]

var character: Character
var combat: CombatSystem

var _built := false
var _build_dirty := true
var _inventory_dirty := true
var _current_tab := 0
var _log_lines := 0
## 打开时默认显示哪一页（0 构筑 / 1 战斗 / 2 背包），调试用 --tab=N 覆盖。
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
var _equip_box: VBoxContainer

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

var _inventory_box: VBoxContainer
var _inventory_hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build_theme()
	_build_chrome()
	_show_tab(initial_tab)
	_built = true


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
		_rebuild_inventory()


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
		button.text = TAB_NAMES[i]
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
	_tabs.append(_build_inventory_tab())
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
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 8)
	box.add_child(_equip_box)

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
	player_row.add_theme_constant_override("separation", 14)
	box.add_child(player_row)
	var hp_tag := UITheme.label("你的生命", 16, UITheme.DIM)
	hp_tag.custom_minimum_size = Vector2(96, 0)
	player_row.add_child(hp_tag)
	_player_bar = UITheme.progress(UITheme.HP)
	_player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_row.add_child(_player_bar)
	_player_text = UITheme.label("", 15, UITheme.TEXT)
	box.add_child(_player_text)
	_buff_label = UITheme.label("", 15, UITheme.OK)
	box.add_child(_buff_label)

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


func _build_inventory_tab() -> Control:
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
	box.add_theme_constant_override("separation", 10)
	padding.add_child(box)

	_inventory_hint = UITheme.label("", 15, UITheme.DIM, true)
	box.add_child(_inventory_hint)
	_inventory_box = VBoxContainer.new()
	_inventory_box.add_theme_constant_override("separation", 8)
	box.add_child(_inventory_box)

	return scroll


func _show_tab(index: int) -> void:
	_current_tab = clampi(index, 0, _tabs.size() - 1)
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

	_clear_children(_equip_box)
	for slot in GameData.SLOTS.keys():
		_equip_box.add_child(_build_equip_row(str(slot)))


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


func _build_equip_row(slot: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slot_label := UITheme.label(str(GameData.SLOTS[slot].get("name", slot)), 16, UITheme.DIM)
	slot_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(slot_label)

	var item: Item = character.equipment.get(slot)
	if item == null:
		var empty := UITheme.label("（空）", 16, UITheme.DIM)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(empty)
		return row

	var color: Color = item.rarity_data().get("color", UITheme.TEXT)
	var name_label := UITheme.label(item.full_name(), 17, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	row.add_child(UITheme.label("战力 %s" % Num.fmt(item.score()), 15, UITheme.DIM))

	var cost := item.upgrade_cost()
	var upgrade := Button.new()
	upgrade.text = "强化 (%d)" % cost if cost > 0 else "已满"
	upgrade.custom_minimum_size = Vector2(118, 36)
	UITheme.style_button(upgrade)
	upgrade.disabled = cost <= 0 or character.materials < cost
	upgrade.pressed.connect(_on_upgrade_pressed.bind(item))
	row.add_child(upgrade)

	var remove := Button.new()
	remove.text = "卸下"
	remove.custom_minimum_size = Vector2(80, 36)
	UITheme.style_button(remove)
	remove.pressed.connect(_on_unequip_pressed.bind(slot))
	row.add_child(remove)
	return row


func _rebuild_inventory() -> void:
	_clear_children(_inventory_box)
	_inventory_hint.text = "背包 %d / %d。装备从挂机掉落里来，稀有度越高词条越多。%s 用于强化装备。" % [
		character.inventory.size(),
		GameData.MAX_INVENTORY,
		GameData.MATERIAL_NAME,
	]
	if character.inventory.is_empty():
		_inventory_box.add_child(UITheme.label("背包是空的，去「战斗」页刷一会儿。", 16, UITheme.DIM))
		return

	for item in character.inventory:
		_inventory_box.add_child(_build_item_row(item))


func _build_item_row(item: Item) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.075, 0.082, 0.102), item.rarity_data().get("color", UITheme.PANEL_BORDER)))
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 18)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_right", 18)
	padding.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(padding)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	padding.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	info.add_child(UITheme.label("%s  %s" % [item.slot_name(), item.full_name()], 18, item.rarity_data().get("color", UITheme.TEXT)))

	var affix_parts: Array[String] = []
	for affix in item.affix_values():
		affix_parts.append(GameData.format_affix(affix))
	if affix_parts.is_empty():
		info.add_child(UITheme.label("无词条", 14, UITheme.DIM))
	else:
		info.add_child(UITheme.label(" · ".join(affix_parts), 14, UITheme.DIM, true))

	var equipped: Item = character.equipment.get(item.slot)
	var compare_text := "战力 %s" % Num.fmt(item.score())
	if equipped != null:
		compare_text += "    当前 %s（%s）" % [Num.fmt(equipped.score()), _delta_text(item.score() - equipped.score())]
	info.add_child(UITheme.label(compare_text, 14, UITheme.DIM))

	var equip_button := Button.new()
	equip_button.text = "装备"
	equip_button.custom_minimum_size = Vector2(84, 40)
	UITheme.style_button(equip_button)
	equip_button.pressed.connect(_on_equip_pressed.bind(item))
	row.add_child(equip_button)

	var upgrade_cost := item.upgrade_cost()
	var upgrade_button := Button.new()
	upgrade_button.text = "强化 %d" % upgrade_cost if upgrade_cost > 0 else "已满"
	upgrade_button.custom_minimum_size = Vector2(100, 40)
	UITheme.style_button(upgrade_button)
	upgrade_button.disabled = upgrade_cost <= 0 or character.materials < upgrade_cost
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(item))
	row.add_child(upgrade_button)

	return panel


func _delta_text(delta: float) -> String:
	if delta > 0.5:
		return "↑+%s" % Num.fmt(delta)
	if delta < -0.5:
		return "↓%s" % Num.fmt(delta)
	return "持平"


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


func _on_equip_pressed(item: Item) -> void:
	equip_requested.emit(item)


func _on_unequip_pressed(slot: String) -> void:
	unequip_requested.emit(slot)


func _on_upgrade_pressed(item: Item) -> void:
	upgrade_requested.emit(item)
