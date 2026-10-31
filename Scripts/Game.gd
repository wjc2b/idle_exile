extends Control

## 主控：存档、离线结算、掉落、以及三个界面的切换。
## 场景结构只有一个挂本脚本的 Control，界面全部由 UI 脚本在代码里搭。

const MainUIScript := preload("res://Scripts/UI/MainUI.gd")
const ClassSelectScript := preload("res://Scripts/UI/ClassSelectUI.gd")

const SAVE_INTERVAL := 10.0
const UI_INTERVAL := 0.1
const OFFLINE_STEP := 0.25
const MIN_OFFLINE_SECONDS := 60.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const DROP_CHANCE := 0.55
const MATERIAL_DROP_MIN := 1
const MATERIAL_DROP_MAX := 2

var character: Character
var combat: CombatSystem
var playtime := 0.0

var ui: MainUI
var class_select: ClassSelectUI

var _save_timer := 0.0
var _ui_timer := 0.0
var _running := false


func _ready() -> void:
	randomize()
	var data := SaveSystem.load_game()
	if data.is_empty():
		_show_class_select()
		return

	var loaded := Character.from_dict(data.get("character", {}))
	if not loaded.is_created():
		_show_class_select()
		return

	character = loaded
	combat = CombatSystem.new()
	combat.setup(character, maxi(1, int(data.get("wave", 1))), float(data.get("player_hp", -1.0)))
	combat.kills = maxi(0, int(data.get("kills", 0)))
	combat.dead = bool(data.get("dead", false))
	combat._respawn_timer = maxf(0.0, float(data.get("respawn_timer", 0.0)))
	combat._basic_timer = clampf(float(data.get("basic_timer", 0.0)), 0.0, CombatSystem.BASIC_INTERVAL)
	combat._enemy_timer = clampf(float(data.get("enemy_timer", 0.0)), 0.0, CombatSystem.ENEMY_INTERVAL)
	playtime = maxf(0.0, float(data.get("playtime", 0.0)))

	_show_main_ui()
	_apply_offline(data)
	_running = true
	ui.refresh(_stats())
	_save_game(false)


func _process(delta: float) -> void:
	if not _running or combat == null:
		return

	playtime += delta
	combat.tick(delta)
	for event in combat.drain_events():
		ui.push_log(event)

	_grant_kills()

	_ui_timer += delta
	if _ui_timer >= UI_INTERVAL:
		_ui_timer = 0.0
		ui.refresh(_stats())

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_save_game(false)


func _exit_tree() -> void:
	if _running:
		_save_game(false)


func _show_class_select() -> void:
	class_select = ClassSelectScript.new()
	add_child(class_select)
	class_select.class_chosen.connect(_on_class_chosen)


func _on_class_chosen(class_id: String) -> void:
	character = Character.new()
	character.init_class(class_id)
	combat = CombatSystem.new()
	combat.setup(character, 1)

	if class_select != null:
		class_select.queue_free()
		class_select = null

	playtime = 0.0
	_show_main_ui()
	_running = true
	ui.refresh(_stats())
	_save_game(false)


func _show_main_ui() -> void:
	ui = MainUIScript.new()
	ui.character = character
	ui.combat = combat

	# 调试用：--tab=1 直接打开战斗页，方便截图与验证。
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--tab="):
			ui.initial_tab = int(text.substr(6))

	add_child(ui)
	ui.skill_slot_changed.connect(_on_skill_slot_changed)
	ui.talent_requested.connect(_on_talent_requested)
	ui.equip_requested.connect(_on_equip_requested)
	ui.equip_into_requested.connect(_on_equip_into_requested)
	ui.unequip_requested.connect(_on_unequip_requested)
	ui.upgrade_requested.connect(_on_upgrade_requested)
	ui.save_requested.connect(func(): _save_game(true))
	ui.reset_requested.connect(_on_reset_requested)
	ui.exchange_requested.connect(_on_exchange_requested)


func _stats() -> Dictionary:
	return {
		"kills": combat.kills,
		"gold_earned": character.gold_earned,
		"materials": character.materials,
		"playtime": playtime,
	}


func _grant_kills() -> void:
	var killed := combat.consume_kills()
	var level_before := character.level
	for i in range(killed):
		var cleared_wave := maxi(1, combat.wave - 1)
		character.materials += randi_range(MATERIAL_DROP_MIN, MATERIAL_DROP_MAX)
		if randf() >= DROP_CHANCE:
			continue
		var item := ItemGenerator.roll_item(cleared_wave)
		var target_key := character.equip_key_for(item)
		var equipped: Item = character.equipped_at(target_key)
		if equipped != null and item.score() <= equipped.score():
			# 不如身上的装备（戒指比的是两只里差的那只），直接熔成强化石，避免背包被垃圾塞满。
			character.materials += 1 + item.rarity
			ui.push_log("[color=#6a7080]分解 %s（+%d %s）[/color]" % [
				item.full_name(), 1 + item.rarity, GameData.MATERIAL_NAME,
			])
			continue
		var auto_sold := not character.add_item(item)
		ui.push_log("[color=#%s]掉落：%s%s[/color]" % [
			item.rarity_data().get("color", Color.WHITE).to_html(false),
			item.full_name(),
			"（背包已满，转为强化石）" if auto_sold else "",
		])
		ui.mark_inventory_dirty()
	if killed > 0:
		ui.mark_inventory_dirty()
	if character.level != level_before:
		# 升级解锁天赋点，构筑页的 + 按钮要立刻可用。
		ui.mark_build_dirty()


func _apply_offline(data: Dictionary) -> void:
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at <= 0.0:
		return
	var elapsed := Time.get_unix_time_from_system() - saved_at
	if elapsed < MIN_OFFLINE_SECONDS:
		return
	elapsed = minf(elapsed, MAX_OFFLINE_SECONDS)

	var gold_before := character.gold
	var kills_before := combat.kills
	var level_before := character.level

	var steps := int(elapsed / OFFLINE_STEP)
	for i in range(steps):
		combat.tick(OFFLINE_STEP)
	combat.drain_events()
	_grant_kills()
	playtime += elapsed

	ui.push_log("[color=#e8c65f]离线结算 %s[/color]" % Num.fmt_time(elapsed))
	ui.push_log("获得 %s 金币，击杀 %d 个，等级 %d → %d" % [
		Num.fmt(character.gold - gold_before),
		combat.kills - kills_before,
		level_before,
		character.level,
	])


func _save_game(notify: bool) -> void:
	if combat == null or character == null:
		return
	if SaveSystem.save_game(character, combat, playtime) and notify:
		ui.push_log("[color=#6a7080]已保存[/color]")


func _on_skill_slot_changed(index: int, skill_id: String) -> void:
	if character.set_skill_slot(index, skill_id):
		combat.refresh_stats()
		ui.refresh(_stats())
		_save_game(false)


func _on_talent_requested(talent_id: String) -> void:
	if character.allocate_talent(talent_id):
		combat.refresh_stats()
		ui.mark_build_dirty()
		ui.refresh(_stats())
		_save_game(false)


func _on_equip_requested(item: Item) -> void:
	if character.equip(item):
		_refresh_after_gear()


func _on_equip_into_requested(item: Item, slot_key: String) -> void:
	if character.equip_at(slot_key, item):
		_refresh_after_gear()


func _on_unequip_requested(slot: String) -> void:
	if character.unequip(slot):
		_refresh_after_gear()


## 换装/强化之后统一走这里：重算战斗属性、刷新左右两栏并落盘。
func _refresh_after_gear() -> void:
	combat.refresh_stats()
	ui.mark_build_dirty()
	ui.mark_inventory_dirty()
	ui.refresh(_stats())
	_save_game(false)


func _on_upgrade_requested(item: Item) -> void:
	if character.upgrade_item(item):
		_refresh_after_gear()


func _on_exchange_requested() -> void:
	if character.gold < GameData.EXCHANGE_GOLD:
		return
	character.gold -= GameData.EXCHANGE_GOLD
	character.materials += GameData.EXCHANGE_MATERIALS
	ui.push_log("[color=#8fd1a8]兑换：%s 金币 → %d %s[/color]" % [
		Num.fmt(GameData.EXCHANGE_GOLD), GameData.EXCHANGE_MATERIALS, GameData.MATERIAL_NAME,
	])
	ui.mark_inventory_dirty()
	ui.refresh(_stats())
	_save_game(false)


func _on_reset_requested() -> void:
	SaveSystem.delete_save()
	if ui != null:
		ui.queue_free()
		ui = null
	_running = false
	character = null
	combat = null
	_show_class_select()
