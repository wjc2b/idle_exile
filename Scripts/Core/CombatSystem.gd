class_name CombatSystem
extends RefCounted

## 技能轮转式自动战斗。
## 角色属性只在 setup / refresh_stats 时聚合一次，离线模拟几十万次 tick 也不会卡。
## 不含任何节点依赖，纯逻辑，方便探针直接跑。

const BASIC_INTERVAL := 1.0
const ENEMY_INTERVAL := 1.3
const RESPAWN_TIME := 3.0
const WAVE_PENALTY := 3
const DAMAGE_VARIANCE := 0.06
const KILL_HEAL_RATIO := 0.05

var character: Character
var enemy: EnemyState
var wave := 1
var kills := 0
var player_hp := 0.0
var dead := false

var _stats: StatBlock
var _basic_timer := 0.0
var _enemy_timer := 0.0
var _respawn_timer := 0.0
var _cooldowns: Dictionary = {}
var _dots: Array[Dictionary] = []
var _buffs: Array[Dictionary] = []
var _events: Array[String] = []
var _pending_kills := 0
var _dot_reset := false


func setup(target: Character, start_wave: int = 1, hp: float = -1.0) -> void:
	character = target
	wave = maxi(1, start_wave)
	enemy = EnemyState.new(wave)
	refresh_stats()
	player_hp = clampf(hp if hp > 0.0 else max_hp(), 0.0, max_hp())
	_basic_timer = 0.0
	_enemy_timer = 0.0
	_respawn_timer = 0.0
	_cooldowns.clear()
	for skill_id in character.skill_slots:
		if str(skill_id) != "":
			_cooldowns[str(skill_id)] = 0.0
	_dots.clear()
	_buffs.clear()
	_pending_kills = 0
	dead = false


## 换装备/点天赋后必须调用，否则战斗仍在用旧属性。
func refresh_stats() -> void:
	if character == null:
		return
	_stats = character.stats()
	player_hp = minf(player_hp, max_hp())


func stats() -> StatBlock:
	return _stats


func max_hp() -> float:
	return maxf(1.0, _stats.value("health"))


func health_ratio() -> float:
	return clampf(player_hp / max_hp(), 0.0, 1.0)


func drain_events() -> Array[String]:
	var out: Array[String] = _events.duplicate()
	_events.clear()
	return out


## 取走本次结算以来击杀的敌人数，调用方据此掉落。
func consume_kills() -> int:
	var out := _pending_kills
	_pending_kills = 0
	return out


func active_buffs() -> Array[Dictionary]:
	return _buffs.duplicate()


func tick(delta: float) -> void:
	if character == null or enemy == null:
		return

	if _dot_reset:
		_dots.clear()
		_dot_reset = false

	if dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_revive()
		return

	_tick_buffs(delta)
	_tick_dots(delta)
	if dead:
		return

	_basic_timer += delta
	while _basic_timer >= BASIC_INTERVAL:
		_basic_timer -= BASIC_INTERVAL
		_hit(1.0)
		if dead or enemy.hp <= 0.0:
			break

	_tick_skills(delta)
	if dead:
		return

	_enemy_timer += delta
	while not dead and enemy.hp > 0.0 and _enemy_timer >= ENEMY_INTERVAL:
		_enemy_timer -= ENEMY_INTERVAL
		_enemy_attack()


func _tick_buffs(delta: float) -> void:
	for i in range(_buffs.size() - 1, -1, -1):
		_buffs[i]["remaining"] = float(_buffs[i]["remaining"]) - delta
		if float(_buffs[i]["remaining"]) <= 0.0:
			_buffs.remove_at(i)


func _tick_dots(delta: float) -> void:
	for i in range(_dots.size() - 1, -1, -1):
		var dot: Dictionary = _dots[i]
		dot["timer"] = float(dot["timer"]) - delta
		while float(dot["timer"]) <= 0.0 and int(dot["remaining"]) > 0:
			dot["timer"] = float(dot["timer"]) + float(dot["interval"])
			dot["remaining"] = int(dot["remaining"]) - 1
			_apply_raw_damage(float(dot["damage"]))
			if _dot_reset:
				return
			if dead or enemy.hp <= 0.0:
				return
		if int(dot["remaining"]) <= 0:
			_dots.remove_at(i)


func _tick_skills(delta: float) -> void:
	var cdr := clampf(_stats.value("cdr"), 0.0, 0.6)
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)

	for skill_id in character.skill_slots:
		var id := str(skill_id)
		if id == "" or not _cooldowns.has(id):
			continue
		if float(_cooldowns[id]) > 0.0:
			continue
		_cast(id, cdr)
		if dead or enemy.hp <= 0.0:
			return


func _cast(skill_id: String, cdr: float) -> void:
	var data := GameData.skill(skill_id)
	if data.is_empty():
		return
	var cooldown := float(data.get("cd", 1.0)) * (1.0 - cdr)
	_cooldowns[skill_id] = maxf(0.2, cooldown)
	var skill_name := str(data.get("name", skill_id))

	match str(data.get("kind", "strike")):
		"strike":
			var dealt := _hit(float(data.get("mult", 1.0)))
			_events.append("%s 造成 %s 伤害" % [skill_name, Num.fmt(dealt)])
		"dot":
			var ticks := int(data.get("ticks", 3))
			var interval := float(data.get("interval", 1.0))
			var per_tick := _compute_damage(float(data.get("mult", 0.5)))
			_dots.append({
				"remaining": ticks,
				"timer": interval,
				"interval": interval,
				"damage": per_tick,
			})
			_events.append("%s 造成持续伤害" % skill_name)
		"heal":
			var amount := max_hp() * float(data.get("value", 0.1))
			player_hp = minf(max_hp(), player_hp + amount)
			_events.append("%s 恢复 %s 生命" % [skill_name, Num.fmt(amount)])
		"buff":
			_buffs.append({
				"stat": str(data.get("stat", "damage_mult")),
				"value": float(data.get("value", 0.0)),
				"remaining": float(data.get("duration", 5.0)),
				"name": skill_name,
			})
			_events.append("%s 生效" % skill_name)


func _hit(mult: float) -> float:
	var dealt := _compute_damage(mult)
	_apply_raw_damage(dealt)
	return dealt


func _compute_damage(mult: float) -> float:
	var damage := _stats.value("damage") * mult * (1.0 + _buff_bonus("damage_mult"))
	var crit := clampf(_stats.value("crit") + _buff_bonus("crit"), 0.0, 0.95)
	if randf() < crit:
		damage *= maxf(1.0, _stats.value("crit_mult"))
	var mitigation := 100.0 / (100.0 + maxf(0.0, enemy.armor()))
	return maxf(1.0, damage * mitigation * randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE))


func _apply_raw_damage(amount: float) -> void:
	enemy.hp -= amount
	var steal := clampf(_stats.value("lifesteal"), 0.0, 0.5)
	if steal > 0.0:
		player_hp = minf(max_hp(), player_hp + amount * steal)
	if enemy.hp <= 0.0:
		_kill_enemy()


func _buff_bonus(stat: String) -> float:
	var total := 0.0
	for buff in _buffs:
		if str(buff.get("stat", "")) == stat:
			total += float(buff.get("value", 0.0))
	return total


func _kill_enemy() -> void:
	var cleared := enemy.wave
	var reward := enemy.gold_reward()
	character.gold += reward
	character.gold_earned += reward
	var levels := character.gain_exp(enemy.exp_reward())
	kills += 1
	_pending_kills += 1
	_events.append("[color=#8fd1a8]击败 %s，+%s 金币[/color]" % [enemy.display_name(), Num.fmt(reward)])
	if levels > 0:
		# 升级会改基础属性，必须重新聚合一次，否则挂机一整晚等级白涨。
		refresh_stats()
		player_hp = max_hp()
		_events.append("[color=#e8c65f]升级！等级 %d，天赋点 +%d[/color]" % [character.level, levels])
	player_hp = minf(max_hp(), player_hp + max_hp() * KILL_HEAL_RATIO)

	wave = cleared + 1
	enemy = EnemyState.new(wave)
	_dot_reset = true
	_basic_timer = 0.0
	_enemy_timer = 0.0


func _enemy_attack() -> void:
	var mitigation := 100.0 / (100.0 + maxf(0.0, _stats.value("armor")))
	var damage := enemy.attack() * mitigation * randf_range(0.94, 1.06)
	player_hp -= damage
	if player_hp <= 0.0:
		player_hp = 0.0
		dead = true
		_respawn_timer = RESPAWN_TIME
		_events.append("[color=#e06b64]你被 %s 击败，倒退 %d 波[/color]" % [enemy.display_name(), WAVE_PENALTY])
	else:
		_events.append("%s 对你造成 %s 伤害" % [enemy.display_name(), Num.fmt(damage)])


func _revive() -> void:
	dead = false
	_respawn_timer = 0.0
	wave = maxi(1, wave - WAVE_PENALTY)
	enemy = EnemyState.new(wave)
	player_hp = max_hp()
	_dots.clear()
	_buffs.clear()
	_basic_timer = 0.0
	_enemy_timer = 0.0
	_events.append("[color=#8fd1a8]你在第 %d 波重新集结[/color]" % wave)
