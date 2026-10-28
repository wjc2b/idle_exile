class_name EnemyState
extends RefCounted

## 按波次缩放的敌人。金币/经验与血量同阶增长，否则会正反馈爆炸。

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

const HP_BASE := 20.0
const HP_GROWTH := 1.09
const ATTACK_BASE := 4.0
const ATTACK_GROWTH := 1.08
const ARMOR_PER_WAVE := 1.0
const GOLD_BASE := 5.0
const GOLD_GROWTH := 1.09
const EXP_BASE := 4.0
const EXP_GROWTH := 1.09

var wave := 1
var hp := 0.0


func _init(start_wave: int = 1) -> void:
	wave = maxi(1, start_wave)
	hp = max_hp()


func max_hp() -> float:
	return HP_BASE * pow(HP_GROWTH, float(wave - 1))


func attack() -> float:
	return ATTACK_BASE * pow(ATTACK_GROWTH, float(wave - 1))


func armor() -> float:
	return ARMOR_PER_WAVE * float(wave - 1)


func gold_reward() -> float:
	return GOLD_BASE * pow(GOLD_GROWTH, float(wave - 1))


func exp_reward() -> float:
	return EXP_BASE * pow(EXP_GROWTH, float(wave - 1))


func display_name() -> String:
	var base := NAMES[(wave - 1) % NAMES.size()]
	if wave % 10 == 0:
		return "精英 · " + base
	return base
