class_name SaveSystem
extends RefCounted

## 存档读写：单个 JSON 文件，字段平铺，方便手改与后续迁移。

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_game(player: PlayerState, combat: CombatSystem, playtime: float) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"playtime": playtime,
		"player": player.to_dict(),
		"kills": combat.kills,
		"dead": combat.dead,
		"respawn_timer": combat.respawn_timer,
		"player_timer": combat.player_timer,
		"enemy_timer": combat.enemy_timer,
	}
	if combat.enemy != null:
		data["enemy_wave"] = combat.enemy.wave
		data["enemy_hp"] = combat.enemy.hp

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取存档: %s" % SAVE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档内容不是合法 JSON 对象，将按新档处理")
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) > SAVE_VERSION:
		push_warning("存档版本高于当前游戏版本")
	return data


static func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.remove("save.json")
