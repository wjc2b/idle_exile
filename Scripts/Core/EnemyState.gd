class_name EnemyState
extends RefCounted

## 按波次缩放的敌人。所有数值都是波次的指数函数，
## 想调难度只需要改这里的系数与增长率。

const NAMES: Array[String] = [
	"腐化的野狼",
	"巡逻的骷髅兵",
	"沼泽食尸鬼",
	"石肤傀儡",
	"暗影刺客",
	"被诅咒的树精",
	"深渊爬行者",
	"失落的骑士",
]

const HP_BASE := 18.0
const HP_GROWTH := 1.085
const ATTACK_BASE := 3.0
const ATTACK_GROWTH := 1.075
const DEFENSE_PER_WAVE := 0.5
const GOLD_BASE := 4.0
## 金币与经验必须和血量同阶增长，否则"杀得快→钱多→更强→杀得更快"会正反馈爆炸。
const GOLD_GROWTH := 1.085
const EXP_BASE := 3.0
const EXP_GROWTH := 1.085

var wave := 1
var hp := 0.0


func _init(start_wave: int = 1) -> void:
	wave = maxi(1, start_wave)
	hp = max_hp()


func scale() -> float:
	return pow(HP_GROWTH, wave - 1)


func max_hp() -> float:
	return HP_BASE * scale()


func attack() -> float:
	return ATTACK_BASE * pow(ATTACK_GROWTH, wave - 1)


func defense() -> float:
	return DEFENSE_PER_WAVE * (wave - 1)


func gold_reward() -> float:
	return GOLD_BASE * pow(GOLD_GROWTH, wave - 1)


func exp_reward() -> float:
	return EXP_BASE * pow(EXP_GROWTH, wave - 1)


func display_name() -> String:
	return NAMES[(wave - 1) % NAMES.size()]
