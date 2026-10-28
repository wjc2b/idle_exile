class_name StatBlock
extends RefCounted

## 三段式属性聚合：
##   最终值 = (基础值 + flat) * (1 + increased) * more
## flat 用来吃等级与固定装备数值，increased 是同类百分比相加（不会爆炸），
## more 是独立乘区（后期留给自己，暂时没人用）。

var _flat: Dictionary = {}
var _increased: Dictionary = {}
var _more: Dictionary = {}


func add_flat(stat: String, value: float) -> void:
	_flat[stat] = float(_flat.get(stat, 0.0)) + value


func add_increased(stat: String, value: float) -> void:
	_increased[stat] = float(_increased.get(stat, 0.0)) + value


func add_more(stat: String, value: float) -> void:
	_more[stat] = float(_more.get(stat, 1.0)) * value


func flat(stat: String) -> float:
	return float(_flat.get(stat, 0.0))


func increased(stat: String) -> float:
	return float(_increased.get(stat, 0.0))


func value(stat: String, base: float = 0.0) -> float:
	var total := (base + flat(stat)) * (1.0 + increased(stat))
	return total * float(_more.get(stat, 1.0))


func summary() -> Dictionary:
	var keys := {}
	for key in _flat:
		keys[key] = true
	for key in _increased:
		keys[key] = true
	var out := {}
	for key in keys:
		out[key] = value(key)
	return out
