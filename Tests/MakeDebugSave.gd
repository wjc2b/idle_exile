extends SceneTree

## 生成一个"玩了几分钟"的调试存档，方便直接看主界面（构筑/战斗/背包）。
## 用法：Godot --headless --path . --script res://Tests/MakeDebugSave.gd [职业id] [分钟]

func _init() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	var class_id := "warrior"
	if args.size() > 0:
		class_id = str(args[0])
	var minutes := 4.0
	if args.size() > 1:
		minutes = float(args[1])

	var character := Character.new()
	character.init_class(class_id)
	var combat := CombatSystem.new()
	combat.setup(character, 1)

	var steps := int(minutes * 60.0 / 0.25)
	for i in range(steps):
		combat.tick(0.25)
		combat.drain_events()
		var killed := combat.consume_kills()
		for k in range(killed):
			character.materials += 2
			var item := ItemGenerator.roll_item(combat.wave)
			var target := character.equip_key_for(item)
			var current: Item = character.equipped_at(target)
			if current == null or item.score() > current.score():
				character.equip(item)
			else:
				character.add_item(item)
		if killed > 0:
			combat.refresh_stats()

	while character.talent_points_left() > 0:
		var allocated := false
		for talent_id in character.talent_ranks.keys():
			if character.allocate_talent(str(talent_id)):
				allocated = true
				break
		if not allocated:
			break
	combat.refresh_stats()

	SaveSystem.save_game(character, combat, minutes * 60.0)
	print("debug save: class=%s wave=%d level=%d inventory=%d" % [
		class_id, combat.wave, character.level, character.inventory.size(),
	])
	quit()
