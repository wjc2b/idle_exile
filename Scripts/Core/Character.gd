class_name Character
extends RefCounted

## 一个角色：职业、等级、天赋分配、技能槽、装备与背包。
## 属性一律由 stats() 现算，改装备/天赋后调用 refresh 即可生效。

var class_id := ""
var level := 1
var exp := 0.0
var gold := 0.0
var gold_earned := 0.0
var materials := 0
var talent_ranks: Dictionary = {}
var skill_slots: Array[String] = []
var equipment: Dictionary = {}
var inventory: Array[Item] = []


func is_created() -> bool:
	return class_id != ""


func class_data() -> Dictionary:
	return GameData.CLASSES.get(class_id, {})


func class_display() -> String:
	return str(class_data().get("name", "未选择"))


func init_class(id: String) -> void:
	class_id = id
	level = 1
	exp = 0.0
	gold = 0.0
	gold_earned = 0.0
	materials = 0
	talent_ranks.clear()
	skill_slots.clear()
	equipment.clear()
	inventory.clear()

	var data := class_data()
	for talent_id in data.get("talents", []):
		talent_ranks[talent_id] = 0
	for skill_id in data.get("skills", []):
		if skill_slots.size() >= GameData.MAX_SKILL_SLOTS:
			break
		skill_slots.append(str(skill_id))


func base_stats() -> Dictionary:
	var data := class_data()
	var base: Dictionary = data.get("base", {})
	var growth: Dictionary = data.get("growth", {})
	var out := {}
	for key in base:
		var value := float(base[key])
		if growth.has(key):
			value += float(growth[key]) * float(level - 1)
		out[key] = value
	return out


func stats() -> StatBlock:
	var block := StatBlock.new()
	var base := base_stats()
	for key in base:
		block.add_flat(str(key), float(base[key]))

	for talent_id in talent_ranks:
		var rank := int(talent_ranks[talent_id])
		if rank <= 0:
			continue
		var data := GameData.talent(str(talent_id))
		if data.is_empty():
			continue
		var amount := float(data.get("value", 0.0)) * float(rank)
		if data.get("mode", "flat") == "increased":
			block.add_increased(str(data.get("stat", "")), amount)
		else:
			block.add_flat(str(data.get("stat", "")), amount)

	for slot in equipment:
		var item: Item = equipment[slot]
		if item != null:
			item.apply_to(block)

	return block


func max_health() -> float:
	return maxf(1.0, stats().value("health"))


func damage() -> float:
	return stats().value("damage")


func armor() -> float:
	return stats().value("armor")


func crit_chance() -> float:
	return clampf(stats().value("crit"), 0.0, 0.75)


func crit_multiplier() -> float:
	# 职业基础值本身就记在 crit_mult 上（1.5 起），这里不再叠默认值，否则会翻一倍。
	return maxf(1.0, stats().value("crit_mult"))


func lifesteal() -> float:
	return clampf(stats().value("lifesteal"), 0.0, 0.5)


func cooldown_reduction() -> float:
	return clampf(stats().value("cdr"), 0.0, 0.6)


func exp_to_next() -> float:
	return 50.0 * pow(1.22, float(level - 1))


func gain_exp(amount: float) -> int:
	exp += amount
	var gained := 0
	while exp >= exp_to_next():
		exp -= exp_to_next()
		level += 1
		gained += 1
	return gained


## 天赋点：每升一级得 1 点，1 级就有 1 点可以先点。
func talent_points_total() -> int:
	return maxi(0, level)


func talent_points_spent() -> int:
	var total := 0
	for rank in talent_ranks.values():
		total += int(rank)
	return total


func talent_points_left() -> int:
	return talent_points_total() - talent_points_spent()


func talent_rank(talent_id: String) -> int:
	return int(talent_ranks.get(talent_id, 0))


func can_allocate(talent_id: String) -> bool:
	if not talent_ranks.has(talent_id):
		return false
	var data := GameData.talent(talent_id)
	if data.is_empty():
		return false
	if talent_rank(talent_id) >= int(data.get("max", 1)):
		return false
	return talent_points_left() > 0


func allocate_talent(talent_id: String) -> bool:
	if not can_allocate(talent_id):
		return false
	talent_ranks[talent_id] = talent_rank(talent_id) + 1
	return true


func available_skills() -> Array:
	return class_data().get("skills", [])


func set_skill_slot(index: int, skill_id: String) -> bool:
	if index < 0 or index >= GameData.MAX_SKILL_SLOTS:
		return false
	if not available_skills().has(skill_id):
		return false
	for i in range(skill_slots.size()):
		if i != index and skill_slots[i] == skill_id:
			return false
	while skill_slots.size() <= index:
		skill_slots.append("")
	skill_slots[index] = skill_id
	return true


## 某件物品应该落到哪个格子：先填空位，两个戒指都满了再替换评分较低的那只。
func equip_key_for(item: Item) -> String:
	if item == null:
		return ""
	var keys := GameData.equip_keys_for(item.slot)
	if keys.is_empty():
		return ""
	for key in keys:
		if equipment.get(key) == null:
			return key
	var worst: String = keys[0]
	var worst_score := INF
	for key in keys:
		var current: Item = equipment.get(key)
		var current_score := current.score() if current != null else -INF
		if current_score < worst_score:
			worst_score = current_score
			worst = key
	return worst


func equipped_at(key: String) -> Item:
	return equipment.get(key)


## 某个部位上最好的一件（戒指有两格时取强的），用于背包里做对比。
func equipped_for_slot(slot: String) -> Item:
	var best: Item = null
	for key in GameData.equip_keys_for(slot):
		var current: Item = equipment.get(key)
		if current == null:
			continue
		if best == null or current.score() > best.score():
			best = current
	return best


func equip(item: Item) -> bool:
	if item == null:
		return false
	return equip_at(equip_key_for(item), item)


## 放进指定格子（拖放用）。部位不符直接拒绝，返回 false。
func equip_at(key: String, item: Item) -> bool:
	if item == null or key == "":
		return false
	var entry := GameData.equip_slot(key)
	if entry.is_empty() or str(entry.get("type", "")) != item.slot:
		return false
	remove_item(item)
	var old: Item = equipment.get(key)
	if old != null:
		if inventory.size() < GameData.MAX_INVENTORY:
			inventory.append(old)
		else:
			materials += _sell_value(old)
	equipment[key] = item
	return true


func unequip(key: String) -> bool:
	var item: Item = equipment.get(key)
	if item == null:
		return false
	if inventory.size() >= GameData.MAX_INVENTORY:
		return false
	equipment.erase(key)
	inventory.append(item)
	return true


func add_item(item: Item) -> bool:
	if item == null:
		return false
	if inventory.size() >= GameData.MAX_INVENTORY:
		materials += _sell_value(item)
		return false
	inventory.append(item)
	return true


func remove_item(item: Item) -> bool:
	var index := inventory.find(item)
	if index < 0:
		return false
	inventory.remove_at(index)
	return true


func upgrade_item(item: Item) -> bool:
	if item == null or item.upgrade >= GameData.MAX_UPGRADE:
		return false
	var cost := item.upgrade_cost()
	if materials < cost:
		return false
	materials -= cost
	item.upgrade += 1
	return true


func equipped_score() -> float:
	var total := 0.0
	for slot in equipment:
		var item: Item = equipment[slot]
		if item != null:
			total += item.score()
	return total


func _sell_value(item: Item) -> int:
	return 1 + item.rarity + item.upgrade


func to_dict() -> Dictionary:
	var items := []
	for item in inventory:
		items.append(item.to_dict())
	var gear := {}
	for slot in equipment:
		var item: Item = equipment[slot]
		if item != null:
			gear[slot] = item.to_dict()
	return {
		"class_id": class_id,
		"level": level,
		"exp": exp,
		"gold": gold,
		"gold_earned": gold_earned,
		"materials": materials,
		"talent_ranks": talent_ranks.duplicate(true),
		"skill_slots": skill_slots.duplicate(),
		"equipment": gear,
		"inventory": items,
	}


static func from_dict(data: Dictionary) -> Character:
	var character := Character.new()
	character.class_id = str(data.get("class_id", ""))
	if character.class_id == "" or not GameData.CLASSES.has(character.class_id):
		return character

	character.level = maxi(1, int(data.get("level", 1)))
	character.exp = maxf(0.0, float(data.get("exp", 0.0)))
	character.gold = maxf(0.0, float(data.get("gold", 0.0)))
	character.gold_earned = maxf(0.0, float(data.get("gold_earned", 0.0)))
	character.materials = maxi(0, int(data.get("materials", 0)))

	var ranks: Dictionary = data.get("talent_ranks", {})
	for talent_id in character.class_data().get("talents", []):
		character.talent_ranks[talent_id] = maxi(0, int(ranks.get(talent_id, 0)))

	character.skill_slots.clear()
	for skill_id in data.get("skill_slots", []):
		character.skill_slots.append(str(skill_id))
	while character.skill_slots.size() < GameData.MAX_SKILL_SLOTS:
		character.skill_slots.append("")

	var gear: Dictionary = data.get("equipment", {})
	for raw_key in gear:
		if not (gear[raw_key] is Dictionary):
			continue
		var key := GameData.normalize_equip_key(str(raw_key))
		character.equipment[key] = Item.from_dict(gear[raw_key])

	for entry in data.get("inventory", []):
		if entry is Dictionary:
			character.inventory.append(Item.from_dict(entry))

	return character
