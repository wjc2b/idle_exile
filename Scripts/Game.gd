extends Control

## 挂机主控：持有玩家/战斗状态，驱动 tick、刷新界面、自动存档与离线结算。
## 场景里只需要一个挂了这个脚本的 Control 节点。

const MainUIScript := preload("res://Scripts/UI/MainUI.gd")

const SAVE_INTERVAL := 10.0
const UI_INTERVAL := 0.1
const OFFLINE_STEP := 0.25
const MIN_OFFLINE_SECONDS := 60.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const STATUS_HOLD := 3.0
const RESET_CONFIRM_WINDOW := 3.0

var player: PlayerState
var combat: CombatSystem
var playtime := 0.0

var ui: MainUI

var _save_timer := 0.0
var _ui_timer := 0.0
var _status_timer := 0.0
var _reset_window := 0.0
var _reset_armed := false
var _running := false


func _ready() -> void:
	randomize()

	player = PlayerState.new()
	combat = CombatSystem.new()
	combat.setup(player, 1)

	ui = MainUIScript.new()
	ui.player = player
	ui.combat = combat
	add_child(ui)
	ui.buy_requested.connect(_on_buy_requested)
	ui.save_requested.connect(_on_save_requested)
	ui.reset_requested.connect(_on_reset_requested)

	var data := SaveSystem.load_game()
	if data.is_empty():
		ui.push_log("[color=#8fd1a8]你被放逐到这片荒原，第 1 波敌人正在靠近。[/color]")
	else:
		_restore(data)

	_running = true
	ui.refresh(_stats())
	_save_game(false)


func _process(delta: float) -> void:
	if not _running:
		return

	playtime += delta
	combat.tick(delta)
	for event in combat.drain_events():
		ui.push_log(event)

	_ui_timer += delta
	if _ui_timer >= UI_INTERVAL:
		_ui_timer = 0.0
		ui.refresh(_stats())

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_save_game(false)

	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			ui.set_status("")

	if _reset_armed:
		_reset_window -= delta
		if _reset_window <= 0.0:
			_reset_armed = false
			ui.set_status("")


func _exit_tree() -> void:
	if _running:
		_save_game(false)


func _stats() -> Dictionary:
	return {
		"kills": combat.kills,
		"gold_earned": player.gold_earned,
		"playtime": playtime,
	}


func _save_game(notify: bool) -> void:
	if SaveSystem.save_game(player, combat, playtime) and notify:
		ui.set_status("已保存 · %s" % Time.get_time_string_from_system())
		_status_timer = STATUS_HOLD


func _restore(data: Dictionary) -> void:
	var player_data: Dictionary = data.get("player", {})
	player.apply_dict(player_data)
	combat.kills = maxi(0, int(data.get("kills", 0)))

	var wave := maxi(1, int(data.get("enemy_wave", 1)))
	combat.setup(player, wave)
	combat.enemy.hp = clampf(
		float(data.get("enemy_hp", combat.enemy.max_hp())), 1.0, combat.enemy.max_hp()
	)
	combat.dead = bool(data.get("dead", false))
	combat.respawn_timer = maxf(0.0, float(data.get("respawn_timer", 0.0)))
	combat.player_timer = clampf(
		float(data.get("player_timer", 0.0)), 0.0, CombatSystem.PLAYER_ATTACK_INTERVAL
	)
	combat.enemy_timer = clampf(
		float(data.get("enemy_timer", 0.0)), 0.0, CombatSystem.ENEMY_ATTACK_INTERVAL
	)
	playtime = maxf(0.0, float(data.get("playtime", 0.0)))

	ui.push_log("[color=#9ab4d0]读取存档：等级 %d，第 %d 波[/color]" % [player.level, combat.enemy.wave])
	_apply_offline(data)


func _apply_offline(data: Dictionary) -> void:
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at <= 0.0:
		return
	var elapsed := Time.get_unix_time_from_system() - saved_at
	if elapsed < MIN_OFFLINE_SECONDS:
		return
	elapsed = minf(elapsed, MAX_OFFLINE_SECONDS)

	var gold_before := player.gold
	var kills_before := combat.kills
	var level_before := player.level

	var steps := int(elapsed / OFFLINE_STEP)
	for i in steps:
		combat.tick(OFFLINE_STEP)
	combat.drain_events()
	playtime += elapsed

	ui.push_log("[color=#e8c65f]离线结算 %s[/color]" % Num.fmt_time(elapsed))
	ui.push_log("获得 %s 金币，击杀 %d 个，等级 %d → %d" % [
		Num.fmt(player.gold - gold_before),
		combat.kills - kills_before,
		level_before,
		player.level,
	])


func _on_buy_requested(kind: String) -> void:
	if player.buy_upgrade(kind):
		ui.push_log("[color=#8fd1a8]%s 提升到 %d 级[/color]" % [
			MainUI.UPGRADE_LABELS.get(kind, kind),
			player.upgrade_level(kind),
		])
		ui.refresh(_stats())
		_save_game(false)


func _on_save_requested() -> void:
	_save_game(true)


func _on_reset_requested() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_window = RESET_CONFIRM_WINDOW
		ui.set_status("再点一次「重置记录」确认清空存档")
		return

	_reset_armed = false
	_reset_window = 0.0
	SaveSystem.delete_save()

	player = PlayerState.new()
	combat = CombatSystem.new()
	combat.setup(player, 1)
	playtime = 0.0
	_ui_timer = 0.0
	_save_timer = 0.0
	_status_timer = 0.0

	ui.player = player
	ui.combat = combat
	ui.clear_log()
	ui.push_log("[color=#8fd1a8]存档已重置，第 1 波敌人正在靠近。[/color]")
	ui.set_status("")
	ui.refresh(_stats())
	_save_game(false)
