class_name CombatSystem
extends RefCounted

## 自动战斗：玩家与敌人各自按固定间隔出手。
## 不含任何节点/渲染依赖，所以离线结算可以直接把 tick() 循环调用。

const PLAYER_ATTACK_INTERVAL := 1.0
const ENEMY_ATTACK_INTERVAL := 1.3
const RESPAWN_TIME := 2.5
const WAVE_PENALTY := 3
const DAMAGE_VARIANCE := 0.08
const KILL_HEAL_RATIO := 0.08

var player: PlayerState
var enemy: EnemyState
var kills := 0
var player_timer := 0.0
var enemy_timer := 0.0
var respawn_timer := 0.0
var dead := false

var _events: Array[String] = []


func setup(target: PlayerState, start_wave: int = 1) -> void:
	player = target
	enemy = EnemyState.new(start_wave)
	player.hp = clampf(player.hp, 1.0, player.max_hp())


## 取走这一帧产生的日志，调用方负责显示。
func drain_events() -> Array[String]:
	var out: Array[String] = _events.duplicate()
	_events.clear()
	return out


func tick(delta: float) -> void:
	if player == null or enemy == null:
		return
	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_revive()
		return

	player_timer += delta
	enemy_timer += delta

	while player_timer >= PLAYER_ATTACK_INTERVAL:
		player_timer -= PLAYER_ATTACK_INTERVAL
		_player_attack()
		if dead:
			break

	while not dead and enemy.hp > 0.0 and enemy_timer >= ENEMY_ATTACK_INTERVAL:
		enemy_timer -= ENEMY_ATTACK_INTERVAL
		_enemy_attack()


func _player_attack() -> void:
	var damage := _roll_damage(player.attack(), enemy.defense())
	enemy.hp -= damage
	if enemy.hp <= 0.0:
		_kill_enemy()
	else:
		_events.append("你对 %s 造成 %s 伤害" % [enemy.display_name(), Num.fmt(damage)])


func _enemy_attack() -> void:
	var damage := _roll_damage(enemy.attack(), player.defense())
	player.hp -= damage
	if player.hp <= 0.0:
		player.hp = 0.0
		dead = true
		respawn_timer = RESPAWN_TIME
		_events.append("[color=#e06b64]你被 %s 击败，倒退 %d 波[/color]" % [enemy.display_name(), WAVE_PENALTY])
	else:
		_events.append("%s 对你造成 %s 伤害" % [enemy.display_name(), Num.fmt(damage)])


func _kill_enemy() -> void:
	var cleared_wave := enemy.wave
	var reward := enemy.gold_reward()
	var exp_gain := enemy.exp_reward()

	kills += 1
	player.gold += reward
	player.gold_earned += reward
	player.hp = minf(player.max_hp(), player.hp + player.max_hp() * KILL_HEAL_RATIO)
	_events.append("[color=#8fd1a8]击败 %s，+%s 金币[/color]" % [enemy.display_name(), Num.fmt(reward)])

	var levels := player.gain_exp(exp_gain)
	if levels > 0:
		player.hp = player.max_hp()
		_events.append("[color=#e8c65f]升级！等级 %d，生命已回满[/color]" % player.level)

	enemy = EnemyState.new(cleared_wave + 1)
	player_timer = 0.0
	enemy_timer = 0.0


func _revive() -> void:
	dead = false
	respawn_timer = 0.0
	var target_wave := maxi(1, enemy.wave - WAVE_PENALTY)
	player.hp = player.max_hp()
	enemy = EnemyState.new(target_wave)
	player_timer = 0.0
	enemy_timer = 0.0
	_events.append("[color=#8fd1a8]你在 %d 波重新集结[/color]" % target_wave)


func _roll_damage(attack_value: float, defense_value: float) -> float:
	var raw := maxf(1.0, attack_value - defense_value)
	return raw * randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
