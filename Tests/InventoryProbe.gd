extends SceneTree

## 装备格逻辑自检：双戒指落位/替换、同部位替换、卸下、属性聚合、
## 存档往返，以及 v3 旧档（武器/护甲/戒指/护符）迁移。
## 用法：Godot --headless --path . --script res://Tests/InventoryProbe.gd

var _failed := 0


func _init() -> void:
	randomize()
	_test_ring_slots()
	_test_full_kit()
	_test_stats_aggregate()
	_test_save_roundtrip()
	_test_legacy_migration()
	# UI 测试要等一帧才有 root，用 deferred 跑最后一段。
	_test_key_toggle.call_deferred()


func _finish() -> void:
	if _failed > 0:
		print("inventory probe: %d 项失败" % _failed)
		quit(1)
		return
	print("inventory probe: 全部通过")
	quit()


func _test_key_toggle() -> void:
	await process_frame
	print("[I 键开关角色页]")
	var c := Character.new()
	c.init_class("warrior")
	var battle := CombatSystem.new()
	battle.setup(c, 1)

	var ui := MainUI.new()
	ui.character = c
	ui.combat = battle
	root.add_child(ui)
	ui._show_tab(1)
	_check("默认在战斗页", ui._current_tab == 1)

	var press_i := InputEventKey.new()
	press_i.keycode = KEY_I
	press_i.pressed = true
	ui._unhandled_key_input(press_i)
	_check("按 I 打开角色页", ui._current_tab == MainUI.TAB_CHARACTER)

	ui._unhandled_key_input(press_i)
	_check("再按 I 回到战斗页", ui._current_tab == 1)

	ui._unhandled_key_input(press_i)
	var press_esc := InputEventKey.new()
	press_esc.keycode = KEY_ESCAPE
	press_esc.pressed = true
	ui._unhandled_key_input(press_esc)
	_check("Esc 关闭角色页", ui._current_tab == 1)

	var release := InputEventKey.new()
	release.keycode = KEY_I
	release.pressed = false
	ui._unhandled_key_input(release)
	_check("松开按键不切换", ui._current_tab == 1)

	ui.queue_free()

	# 拖放契约：装备格只接受同部位，背包格不是落点。
	var slot_scene: PackedScene = load("res://Screens/ui/Character/EquipmentSlot.tscn")
	var head_cell: ItemSlotView = slot_scene.instantiate()
	head_cell.configure("equip", "head", "head")
	root.add_child(head_cell)
	var ring_item := _item("ring", 5.0)
	_check("头盔格拒绝戒指", not head_cell._can_drop_data(Vector2.ZERO, {"item": ring_item}))
	_check("头盔格接受同部位", head_cell._can_drop_data(Vector2.ZERO, {"item": _item("head", 5.0)}))

	var bag_scene: PackedScene = load("res://Screens/ui/Character/IntentorySlot.tscn")
	var bag_cell: ItemSlotView = bag_scene.instantiate()
	bag_cell.configure("bag", "", "")
	root.add_child(bag_cell)
	bag_cell.set_item(ring_item)
	_check("背包格不是拖放目标", not bag_cell._can_drop_data(Vector2.ZERO, {"item": ring_item}))
	_check("背包格能给出拖拽物品", bag_cell.item == ring_item)
	head_cell.queue_free()
	bag_cell.queue_free()

	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


func _item(slot: String, damage: float) -> Item:
	var item := Item.new()
	item.slot = slot
	item.base_name = "%s测试" % GameData.slot_name(slot)
	item.rarity = 2
	item.item_level = 10
	var affix: Dictionary = {"id": "dmg_flat", "stat": "damage", "mode": "flat", "value": damage}
	item.affixes.append(affix)
	return item


func _test_ring_slots() -> void:
	print("[双戒指]")
	_check("戒指类型有两个格子", GameData.equip_keys_for("ring").size() == 2)

	var c := Character.new()
	c.init_class("warrior")
	var r1 := _item("ring", 10.0)
	var r2 := _item("ring", 20.0)
	c.equip(r1)
	c.equip(r2)
	_check("第一只进戒指 I", c.equipped_at("ring1") == r1)
	_check("第二只进戒指 II", c.equipped_at("ring2") == r2)

	var r3 := _item("ring", 30.0)
	c.equip(r3)
	_check("第三只替换较弱的那只（戒指 I）", c.equipped_at("ring1") == r3)
	_check("被换下的戒指回背包", c.inventory.has(r1) and c.inventory.size() == 1)

	var weak := _item("ring", 1.0)
	c.equip(weak)
	_check("更弱的戒指替换最弱格（戒指 II）", c.equipped_at("ring2") == weak)
	_check("换下的是那只 20 的", c.inventory.has(r2))


func _test_full_kit() -> void:
	print("[七个部位]")
	var c := Character.new()
	c.init_class("mage")
	var head := _item("head", 5.0)
	var body := _item("body", 5.0)
	var main := _item("main_hand", 5.0)
	var off := _item("off_hand", 5.0)
	var amulet := _item("amulet", 5.0)
	var kit: Array[Item] = [head, body, main, off, amulet]
	for it in kit:
		c.equip(it)
	_check("五个单格部位各就各位", c.equipment.size() == 5)
	_check("主手是那把剑", c.equipped_at("main_hand") == main)
	_check("副手是那面盾", c.equipped_at("off_hand") == off)

	var amulet2 := _item("amulet", 50.0)
	c.equip(amulet2)
	_check("同部位替换进背包", c.equipped_at("amulet") == amulet2 and c.inventory.has(amulet))

	_check("卸下成功", c.unequip("head") and c.equipped_at("head") == null)
	_check("卸下后进背包", c.inventory.has(head))
	_check("空槽卸下返回 false", not c.unequip("head"))

	# 拖放走 equip_at：部位不符必须拒绝，符合同意。
	var ring := _item("ring", 5.0)
	c.add_item(ring)
	_check("拖到错误部位被拒绝", not c.equip_at("head", ring))
	_check("被拒绝的物品留在背包", c.inventory.has(ring))
	_check("拖到指定戒指格成功", c.equip_at("ring2", ring) and c.equipped_at("ring2") == ring)
	_check("装上后离开背包", not c.inventory.has(ring))


func _test_stats_aggregate() -> void:
	print("[属性聚合]")
	var c := Character.new()
	c.init_class("warrior")
	var before := c.stats().value("damage")
	var slots: Array[String] = ["head", "body", "legs", "main_hand", "off_hand", "ring", "ring", "amulet"]
	for slot in slots:
		c.equip(_item(slot, 10.0))
	_check("8 件装备全部计入属性", is_equal_approx(c.stats().value("damage"), before + 80.0))
	_check("战力评分随装备上升", c.equipped_score() > 0.0)


func _test_save_roundtrip() -> void:
	print("[存档往返]")
	var c := Character.new()
	c.init_class("ranger")
	for slot in ["head", "body", "legs", "main_hand", "off_hand", "ring", "ring", "amulet"]:
		c.equip(_item(slot, 7.0))
	c.add_item(_item("main_hand", 3.0))

	var restored := Character.from_dict(c.to_dict())
	_check("装备格数量一致", restored.equipment.size() == 8)
	_check("双戒指都还在", restored.equipped_at("ring1") != null and restored.equipped_at("ring2") != null)
	_check("下装也在", restored.equipped_at("legs") != null)
	_check("背包数量一致", restored.inventory.size() == c.inventory.size())
	_check("等级与职业保留", restored.class_id == "ranger" and restored.level == c.level)


func _test_legacy_migration() -> void:
	print("[v3 旧档迁移]")
	var legacy := {
		"class_id": "ranger",
		"level": 12,
		"equipment": {
			"weapon": {"slot": "weapon", "base_name": "短弓", "rarity": 2, "item_level": 10, "upgrade": 1, "affixes": []},
			"armor": {"slot": "armor", "base_name": "皮甲", "rarity": 1, "item_level": 9, "upgrade": 0, "affixes": []},
			"ring": {"slot": "ring", "base_name": "铜戒", "rarity": 0, "item_level": 8, "upgrade": 0, "affixes": []},
			"amulet": {"slot": "amulet", "base_name": "圣徽", "rarity": 3, "item_level": 11, "upgrade": 0, "affixes": []},
		},
		"inventory": [],
	}
	var c := Character.from_dict(legacy)
	_check("武器 → 主手", c.equipped_at("main_hand") != null)
	_check("护甲 → 身体", c.equipped_at("body") != null)
	_check("旧戒指 → 戒指 I", c.equipped_at("ring1") != null)
	_check("项链保留", c.equipped_at("amulet") != null)
	_check("物品部位也被迁移", c.equipped_at("main_hand").slot == "main_hand")
	_check("新格子默认空着", c.equipped_at("off_hand") == null and c.equipped_at("ring2") == null)
