class_name GameData
extends RefCounted

## 全部静态配置：职业、技能、天赋、词条、稀有度、槽位。
## 调平衡基本只需要动这个文件。

const CLASSES := {
	"warrior": {
		"name": "战士",
		"tagline": "铁壁 · 重击",
		"desc": "血厚甲高，靠重击与撕裂把敌人磨死。容错最高，适合第一次玩。",
		"portrait": "res://Assets/Portraits/warrior.png",
		"base": {"damage": 7.0, "health": 90.0, "armor": 6.0, "crit": 0.05, "crit_mult": 1.5},
		"growth": {"damage": 1.6, "health": 12.0, "armor": 1.2},
		"skills": ["heavy_strike", "rend", "war_cry", "bloodthirst", "cleave"],
		"talents": ["iron_will", "heavy_mastery", "battle_trance"],
	},
	"ranger": {
		"name": "游侠",
		"tagline": "疾风 · 暴击",
		"desc": "出手快、暴击高，靠速射与毒箭堆叠伤害。脆，但滚雪球最快。",
		"portrait": "res://Assets/Portraits/ranger.png",
		"base": {"damage": 6.0, "health": 70.0, "armor": 3.0, "crit": 0.12, "crit_mult": 1.6},
		"growth": {"damage": 1.4, "health": 9.0, "armor": 0.8},
		"skills": ["quick_shot", "poison_arrow", "aim", "evade", "volley"],
		"talents": ["precision", "ranger_speed", "venom"],
	},
	"mage": {
		"name": "法师",
		"tagline": "烈焰 · 奥术",
		"desc": "单发伤害最高，靠火球与陨石爆发。血最少，被摸到就危险。",
		"portrait": "res://Assets/Portraits/mage.png",
		"base": {"damage": 9.0, "health": 60.0, "armor": 2.0, "crit": 0.07, "crit_mult": 1.8},
		"growth": {"damage": 2.4, "health": 7.0, "armor": 0.6},
		"skills": ["fireball", "meteor", "arcane_power", "lifesteal_ward", "frost_nova"],
		"talents": ["arcane_mastery", "mana_shield", "ignite"],
	},
}

## kind: strike（瞬发伤害）/ dot（持续伤害）/ heal（回血）/ buff（临时增益）
const SKILLS := {
	"heavy_strike": {"name": "重斩", "cd": 3.0, "kind": "strike", "mult": 2.2, "desc": "造成 220% 攻击伤害"},
	"rend": {"name": "撕裂", "cd": 6.0, "kind": "dot", "mult": 0.45, "ticks": 3, "interval": 1.0, "desc": "3 秒内每秒造成 45% 攻击伤害"},
	"war_cry": {"name": "战吼", "cd": 12.0, "kind": "buff", "stat": "damage_mult", "value": 0.30, "duration": 6.0, "desc": "6 秒内伤害 +30%"},
	"bloodthirst": {"name": "嗜血", "cd": 9.0, "kind": "heal", "value": 0.18, "desc": "立即恢复 18% 生命"},
	"cleave": {"name": "横扫", "cd": 4.0, "kind": "strike", "mult": 1.5, "desc": "造成 150% 攻击伤害"},

	"quick_shot": {"name": "速射", "cd": 1.6, "kind": "strike", "mult": 1.1, "desc": "造成 110% 攻击伤害"},
	"poison_arrow": {"name": "毒箭", "cd": 5.0, "kind": "dot", "mult": 0.35, "ticks": 4, "interval": 1.0, "desc": "4 秒内每秒造成 35% 攻击伤害"},
	"aim": {"name": "瞄准", "cd": 10.0, "kind": "buff", "stat": "crit", "value": 0.25, "duration": 5.0, "desc": "5 秒内暴击率 +25%"},
	"evade": {"name": "闪避", "cd": 8.0, "kind": "heal", "value": 0.12, "desc": "立即恢复 12% 生命"},
	"volley": {"name": "箭雨", "cd": 6.0, "kind": "strike", "mult": 1.8, "desc": "造成 180% 攻击伤害"},

	"fireball": {"name": "火球术", "cd": 2.5, "kind": "strike", "mult": 2.6, "desc": "造成 260% 攻击伤害"},
	"meteor": {"name": "陨石术", "cd": 7.0, "kind": "dot", "mult": 0.60, "ticks": 4, "interval": 1.0, "desc": "4 秒内每秒造成 60% 攻击伤害"},
	"arcane_power": {"name": "奥术强化", "cd": 12.0, "kind": "buff", "stat": "damage_mult", "value": 0.40, "duration": 6.0, "desc": "6 秒内伤害 +40%"},
	"lifesteal_ward": {"name": "生命汲取", "cd": 9.0, "kind": "heal", "value": 0.20, "desc": "立即恢复 20% 生命"},
	"frost_nova": {"name": "冰霜新星", "cd": 5.0, "kind": "strike", "mult": 1.3, "desc": "造成 130% 攻击伤害"},
}

## mode: flat（直接加数值）/ increased（百分比加成，可叠加）
const TALENTS := {
	"iron_will": {"name": "钢铁意志", "max": 3, "stat": "health", "mode": "increased", "value": 0.10, "desc": "生命上限 +10%"},
	"heavy_mastery": {"name": "重击专精", "max": 3, "stat": "damage", "mode": "increased", "value": 0.09, "desc": "攻击 +9%"},
	"battle_trance": {"name": "战斗专注", "max": 3, "stat": "armor", "mode": "flat", "value": 3.0, "desc": "护甲 +3"},

	"precision": {"name": "精准", "max": 3, "stat": "crit", "mode": "flat", "value": 0.04, "desc": "暴击率 +4%"},
	"ranger_speed": {"name": "游侠之速", "max": 3, "stat": "cdr", "mode": "flat", "value": 0.06, "desc": "技能冷却 -6%"},
	"venom": {"name": "淬毒", "max": 3, "stat": "damage", "mode": "increased", "value": 0.08, "desc": "攻击 +8%"},

	"arcane_mastery": {"name": "奥术精通", "max": 3, "stat": "damage", "mode": "increased", "value": 0.12, "desc": "攻击 +12%"},
	"mana_shield": {"name": "法力护盾", "max": 3, "stat": "armor", "mode": "flat", "value": 4.0, "desc": "护甲 +4"},
	"ignite": {"name": "炽焰", "max": 3, "stat": "crit_mult", "mode": "flat", "value": 0.15, "desc": "暴击伤害 +15%"},
}

const RARITIES := [
	{"id": 0, "name": "普通", "color": Color(0.76, 0.78, 0.82), "affixes": 0, "weight": 55.0},
	{"id": 1, "name": "精良", "color": Color(0.46, 0.80, 0.52), "affixes": 1, "weight": 28.0},
	{"id": 2, "name": "稀有", "color": Color(0.40, 0.66, 0.96), "affixes": 2, "weight": 12.0},
	{"id": 3, "name": "史诗", "color": Color(0.76, 0.46, 0.96), "affixes": 3, "weight": 4.0},
	{"id": 4, "name": "传说", "color": Color(0.96, 0.72, 0.30), "affixes": 4, "weight": 1.0},
]

const SLOTS := {
	"weapon": {"name": "武器", "bases": ["长剑", "战斧", "短弓", "法杖"]},
	"armor": {"name": "护甲", "bases": ["皮甲", "锁子甲", "法袍"]},
	"ring": {"name": "戒指", "bases": ["铜戒", "银戒", "符文戒"]},
	"amulet": {"name": "护符", "bases": ["兽牙护符", "星辰吊坠", "圣徽"]},
}

## 词条池。flat 类的数值随物品等级指数增长，百分比类保持区间（避免后期失控）。
const AFFIXES := [
	{"id": "dmg_flat", "name": "攻击", "stat": "damage", "mode": "flat", "min": 2.0, "max": 5.0, "scale": 1.0},
	{"id": "hp_flat", "name": "生命", "stat": "health", "mode": "flat", "min": 8.0, "max": 20.0, "scale": 1.0},
	{"id": "armor_flat", "name": "护甲", "stat": "armor", "mode": "flat", "min": 1.0, "max": 4.0, "scale": 1.0},
	{"id": "dmg_pct", "name": "攻击加成", "stat": "damage", "mode": "increased", "min": 0.04, "max": 0.09, "scale": 0.0},
	{"id": "hp_pct", "name": "生命加成", "stat": "health", "mode": "increased", "min": 0.04, "max": 0.09, "scale": 0.0},
	{"id": "crit", "name": "暴击率", "stat": "crit", "mode": "flat", "min": 0.01, "max": 0.03, "scale": 0.0},
	{"id": "crit_dmg", "name": "暴击伤害", "stat": "crit_mult", "mode": "flat", "min": 0.06, "max": 0.16, "scale": 0.0},
	{"id": "lifesteal", "name": "吸血", "stat": "lifesteal", "mode": "flat", "min": 0.01, "max": 0.03, "scale": 0.0},
	{"id": "cdr", "name": "冷却缩减", "stat": "cdr", "mode": "flat", "min": 0.01, "max": 0.03, "scale": 0.0},
]

const MAX_SKILL_SLOTS := 4
const MAX_INVENTORY := 40
const MAX_UPGRADE := 10
const UPGRADE_COST_BASE := 4
const UPGRADE_POWER := 1.10
const MATERIAL_NAME := "强化石"

## 金币出口：换强化石，保证两种货币都有用。
const EXCHANGE_GOLD := 200
const EXCHANGE_MATERIALS := 10


static func class_ids() -> Array:
	return CLASSES.keys()


static func rarity_data(rarity: int) -> Dictionary:
	return RARITIES[clampi(rarity, 0, RARITIES.size() - 1)]


static func skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})


static func talent(talent_id: String) -> Dictionary:
	return TALENTS.get(talent_id, {})


static func stat_label(stat: String) -> String:
	match stat:
		"damage":
			return "攻击"
		"health":
			return "生命"
		"armor":
			return "护甲"
		"crit":
			return "暴击率"
		"crit_mult":
			return "暴击伤害"
		"lifesteal":
			return "吸血"
		"cdr":
			return "冷却缩减"
		_:
			return stat


static func format_affix(affix: Dictionary) -> String:
	var stat: String = affix.get("stat", "")
	var value: float = float(affix.get("value", 0.0))
	if affix.get("mode", "flat") == "increased":
		return "%s +%.1f%%" % [stat_label(stat), value * 100.0]
	if stat == "crit" or stat == "lifesteal" or stat == "cdr":
		return "%s +%.1f%%" % [stat_label(stat), value * 100.0]
	if stat == "crit_mult":
		return "%s +%.0f%%" % [stat_label(stat), value * 100.0]
	return "%s +%.0f" % [stat_label(stat), value]
