class_name Item
extends RefCounted

## 一件装备：槽位 + 基础名 + 稀有度 + 词条 + 强化等级。

var slot := "weapon"
var base_name := "长剑"
var rarity := 0
var item_level := 1
var upgrade := 0
var affixes: Array[Dictionary] = []


func rarity_data() -> Dictionary:
	return GameData.rarity_data(rarity)


func display_name() -> String:
	if upgrade > 0:
		return "+%d %s" % [upgrade, base_name]
	return base_name


func full_name() -> String:
	return "【%s】%s" % [rarity_data().get("name", ""), display_name()]


func slot_name() -> String:
	return GameData.SLOTS.get(slot, {}).get("name", slot)


## 强化加成：每级让词条数值乘 1.1
func power_multiplier() -> float:
	return pow(GameData.UPGRADE_POWER, upgrade)


func affix_values() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for affix in affixes:
		var copy := affix.duplicate()
		if copy.get("mode", "flat") == "flat":
			copy["value"] = float(copy.get("value", 0.0)) * power_multiplier()
		else:
			copy["value"] = float(copy.get("value", 0.0)) * power_multiplier()
		out.append(copy)
	return out


func apply_to(block: StatBlock) -> void:
	for affix in affix_values():
		var stat: String = affix.get("stat", "")
		var value: float = float(affix.get("value", 0.0))
		if stat == "":
			continue
		if affix.get("mode", "flat") == "increased":
			block.add_increased(stat, value)
		else:
			block.add_flat(stat, value)


## 粗略战力评分，用于背包里比较两件装备谁更强。
func score() -> float:
	var total := 1.0
	for affix in affix_values():
		var stat: String = affix.get("stat", "")
		var value: float = float(affix.get("value", 0.0))
		match stat:
			"damage":
				total += value * (1.0 if affix.get("mode") == "flat" else 120.0)
			"health":
				total += value * (0.12 if affix.get("mode") == "flat" else 90.0)
			"armor":
				total += value * 1.4
			"crit":
				total += value * 500.0
			"crit_mult":
				total += value * 160.0
			"lifesteal":
				total += value * 400.0
			"cdr":
				total += value * 300.0
	return total


func upgrade_cost() -> int:
	if upgrade >= GameData.MAX_UPGRADE:
		return 0
	return GameData.UPGRADE_COST_BASE * (upgrade + 1)


func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"base_name": base_name,
		"rarity": rarity,
		"item_level": item_level,
		"upgrade": upgrade,
		"affixes": affixes.duplicate(true),
	}


static func from_dict(data: Dictionary) -> Item:
	var item := Item.new()
	item.slot = str(data.get("slot", "weapon"))
	item.base_name = str(data.get("base_name", "物品"))
	item.rarity = int(data.get("rarity", 0))
	item.item_level = maxi(1, int(data.get("item_level", 1)))
	item.upgrade = clampi(int(data.get("upgrade", 0)), 0, GameData.MAX_UPGRADE)
	for affix in data.get("affixes", []):
		if affix is Dictionary and affix.has("stat"):
			item.affixes.append(affix)
	return item
