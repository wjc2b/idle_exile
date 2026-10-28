class_name ItemGenerator
extends RefCounted

## 掉落生成：稀有度按波次加权，词条数量由稀有度决定，flat 词条随物品等级放大。
## 想改掉落手感基本只动这里和 GameData.RARITIES / AFFIXES。

const RARITY_SHIFT := 0.012
## 装备数值增长必须慢于敌人血量增长（1.09），否则玩家会滚雪球到数值爆炸；
## 慢一点则形成"越来越吃力"的挂机曲线。
const FLAT_SCALE := 1.06


static func roll_item(wave: int) -> Item:
	var item := Item.new()
	var slot := _random_slot()
	item.slot = slot
	var bases: Array = GameData.SLOTS[slot].get("bases", ["物品"])
	item.base_name = str(bases[randi() % bases.size()])
	item.item_level = maxi(1, wave)
	item.rarity = roll_rarity(wave)

	var count := int(GameData.rarity_data(item.rarity).get("affixes", 0))
	var used: Array[String] = []
	for i in count:
		var affix := _roll_affix(item.item_level, used)
		if affix.is_empty():
			continue
		item.affixes.append(affix)
		used.append(str(affix.get("id", "")))
	return item


static func roll_rarity(wave: int) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for i in GameData.RARITIES.size():
		var base := float(GameData.RARITIES[i].get("weight", 1.0))
		var shifted := base * pow(1.0 + RARITY_SHIFT * float(maxi(0, wave - 1)), float(i))
		weights.append(shifted)
		total += shifted

	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0


static func _random_slot() -> String:
	var slots: Array = GameData.SLOTS.keys()
	return str(slots[randi() % slots.size()])


static func _roll_affix(item_level: int, used: Array[String]) -> Dictionary:
	var pool: Array = []
	for affix in GameData.AFFIXES:
		if used.has(str(affix.get("id", ""))):
			continue
		pool.append(affix)
	if pool.is_empty():
		return {}

	var picked: Dictionary = pool[randi() % pool.size()]
	var low := float(picked.get("min", 0.0))
	var high := float(picked.get("max", 0.0))
	var value := randf_range(low, high)
	if float(picked.get("scale", 0.0)) > 0.0:
		value *= pow(FLAT_SCALE, float(item_level - 1))

	return {
		"id": picked.get("id", ""),
		"stat": picked.get("stat", ""),
		"mode": picked.get("mode", "flat"),
		"value": value,
	}
