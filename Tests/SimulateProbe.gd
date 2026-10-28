extends SceneTree

## 数值探针：不开窗口，三个职业各自跑 30 分钟自动战斗，
## 自动捡装备（更好就换）、自动点天赋，打印推进曲线。
## 用法：Godot --headless --path . --script res://Tests/SimulateProbe.gd

const DT := 0.25
const MINUTES := 30.0


func _init() -> void:
	randomize()
	print("职业  分钟  波次  等级  击杀   攻击     生命      护甲   装备分")
	for class_id in GameData.CLASSES.keys():
		_run_class(str(class_id))
	print("完成")
	quit()


func _run_class(class_id: String) -> void:
	var character := Character.new()
	character.init_class(class_id)
	var combat := CombatSystem.new()
	combat.setup(character, 1)

	var steps := int(MINUTES * 60.0 / DT)
	var report_every := int(10.0 * 60.0 / DT)

	for i in steps:
		combat.tick(DT)
		combat.drain_events()

		var killed := combat.consume_kills()
		if killed > 0:
			for k in range(killed):
				_handle_drop(character, combat.wave)
			while _spend_talent(character):
				pass
			combat.refresh_stats()

		if (i + 1) % report_every == 0:
			_print_row(character, combat, float(i + 1) * DT / 60.0)

	_print_row(character, combat, MINUTES)


func _handle_drop(character: Character, wave: int) -> void:
	var item := ItemGenerator.roll_item(wave)
	var current: Item = character.equipment.get(item.slot)
	if current == null or item.score() > current.score():
		character.equip(item)
	else:
		character.add_item(item)


func _spend_talent(character: Character) -> bool:
	for talent_id in character.talent_ranks.keys():
		if character.allocate_talent(str(talent_id)):
			return true
	return false


func _print_row(character: Character, combat: CombatSystem, minutes: float) -> void:
	print("%-6s %5.1f  %4d  %4d  %5d  %-8s  %-9s %-6s %-6s" % [
		character.class_display(),
		minutes,
		combat.wave,
		character.level,
		combat.kills,
		Num.fmt(character.stats().value("damage")),
		Num.fmt(character.max_health()),
		Num.fmt(character.armor()),
		Num.fmt(character.equipped_score()),
	])
