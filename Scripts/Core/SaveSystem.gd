class_name SaveSystem
extends RefCounted

## 存档 v4：角色（职业/天赋/技能槽/装备/背包）+ 战斗进度。
## 装备从第 4 版起分 7 个格子（头/身/主手/副手/双戒/项链），旧档在读档时自动迁移。
## 单个 JSON 文件，字段平铺，方便手改与排查。

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 4


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_game(character: Character, combat: CombatSystem, playtime: float) -> bool:
	if character == null or not character.is_created():
		return false
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"playtime": playtime,
		"character": character.to_dict(),
		"wave": combat.wave,
		"kills": combat.kills,
		"player_hp": combat.player_hp,
		"dead": combat.dead,
		"respawn_timer": combat._respawn_timer,
		"basic_timer": combat._basic_timer,
		"enemy_timer": combat._enemy_timer,
	}
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
		push_warning("存档内容不是合法 JSON，将按新档处理")
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) > SAVE_VERSION:
		push_warning("存档版本高于当前游戏版本")
	return data


static func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("save.json")
