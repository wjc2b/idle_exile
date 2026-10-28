class_name PlayerState
extends RefCounted

## 玩家的纯数据：等级、经验、金币、当前生命与三项强化等级。
## 所有派生数值（攻击/防御/生命上限）都由等级 + 强化等级算出来，方便改平衡。

const BASE_ATTACK := 5.0
const BASE_DEFENSE := 0.0
const BASE_HP := 50.0

const ATTACK_PER_LEVEL := 1.5
const DEFENSE_PER_LEVEL := 0.5
const HP_PER_LEVEL := 8.0

const UPGRADE_ATTACK := 2.0
const UPGRADE_DEFENSE := 1.0
const UPGRADE_HP := 12.0

## 强化是"固定值 + 乘算"：基础部分吃掉前期，乘算部分保证后期追得上指数增长的敌人。
const ATTACK_MULT := 1.10
const DEFENSE_MULT := 1.08
const HP_MULT := 1.10

## 每次购买的价格 = COST_BASE * COST_GROWTH ^ 已购买次数
const COST_BASE := {"atk": 12.0, "def": 18.0, "hp": 15.0}
const COST_GROWTH := 1.15

const EXP_BASE := 50.0
const EXP_GROWTH := 1.28

var level := 1
var exp := 0.0
var gold := 0.0
var gold_earned := 0.0
var hp := BASE_HP

var attack_level := 0
var defense_level := 0
var hp_level := 0


func max_hp() -> float:
	var flat := BASE_HP + HP_PER_LEVEL * (level - 1) + UPGRADE_HP * hp_level
	return flat * pow(HP_MULT, hp_level)


func attack() -> float:
	var flat := BASE_ATTACK + ATTACK_PER_LEVEL * (level - 1) + UPGRADE_ATTACK * attack_level
	return flat * pow(ATTACK_MULT, attack_level)


func defense() -> float:
	var flat := BASE_DEFENSE + DEFENSE_PER_LEVEL * (level - 1) + UPGRADE_DEFENSE * defense_level
	return flat * pow(DEFENSE_MULT, defense_level)


func exp_to_next() -> float:
	return EXP_BASE * pow(EXP_GROWTH, level - 1)


func upgrade_level(kind: String) -> int:
	match kind:
		"atk":
			return attack_level
		"def":
			return defense_level
		"hp":
			return hp_level
		_:
			return 0


func upgrade_cost(kind: String) -> float:
	if not COST_BASE.has(kind):
		return INF
	return floorf(COST_BASE[kind] * pow(COST_GROWTH, upgrade_level(kind)))


func upgrade_effect(kind: String) -> String:
	match kind:
		"atk":
			return "+%.0f%% 攻击" % ((ATTACK_MULT - 1.0) * 100.0)
		"def":
			return "+%.0f%% 防御" % ((DEFENSE_MULT - 1.0) * 100.0)
		"hp":
			return "+%.0f%% 生命上限" % ((HP_MULT - 1.0) * 100.0)
		_:
			return ""


func can_afford(kind: String) -> bool:
	return gold >= upgrade_cost(kind)


func buy_upgrade(kind: String) -> bool:
	if not can_afford(kind):
		return false
	if not COST_BASE.has(kind):
		return false
	gold -= upgrade_cost(kind)
	match kind:
		"atk":
			attack_level += 1
		"def":
			defense_level += 1
		"hp":
			hp_level += 1
		_:
			return false
	return true


## 返回升级了几级，方便调用方记录日志。
func gain_exp(amount: float) -> int:
	exp += amount
	var gained := 0
	while exp >= exp_to_next():
		exp -= exp_to_next()
		level += 1
		gained += 1
		hp = max_hp()
	return gained


func to_dict() -> Dictionary:
	return {
		"level": level,
		"exp": exp,
		"gold": gold,
		"gold_earned": gold_earned,
		"hp": hp,
		"attack_level": attack_level,
		"defense_level": defense_level,
		"hp_level": hp_level,
	}


func apply_dict(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", level)))
	exp = maxf(0.0, float(data.get("exp", exp)))
	gold = maxf(0.0, float(data.get("gold", gold)))
	gold_earned = maxf(0.0, float(data.get("gold_earned", gold_earned)))
	attack_level = maxi(0, int(data.get("attack_level", attack_level)))
	defense_level = maxi(0, int(data.get("defense_level", defense_level)))
	hp_level = maxi(0, int(data.get("hp_level", hp_level)))
	hp = clampf(float(data.get("hp", max_hp())), 0.0, max_hp())
