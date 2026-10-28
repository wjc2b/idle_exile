extends SceneTree

## 数值探针：不开窗口，直接按固定步长跑 60 分钟战斗，
## 每 5 分钟（游戏内）打印一次波次/等级/属性，用来检查曲线有没有卡死或爆炸。
## 用法：Godot --headless --path . --script res://Tests/SimulateProbe.gd

const DT := 0.2
const TOTAL_MINUTES := 60.0
const REPORT_EVERY_MINUTES := 5.0


func _init() -> void:
	randomize()
	var player := PlayerState.new()
	var combat := CombatSystem.new()
	combat.setup(player, 1)

	var steps := int(TOTAL_MINUTES * 60.0 / DT)
	var report_step := int(REPORT_EVERY_MINUTES * 60.0 / DT)
	var bought := 0

	print("分钟   波次  等级  金币      攻击   防御   生命   击杀")
	for i in steps:
		combat.tick(DT)
		combat.drain_events()
		bought += _spend_gold(player)
		if (i + 1) % report_step == 0:
			_print_row(float(i + 1) * DT, player, combat)

	_print_row(TOTAL_MINUTES * 60.0, player, combat)
	print("累计购买强化次数：%d" % bought)
	quit()


func _spend_gold(player: PlayerState) -> int:
	var bought := 0
	for kind in ["atk", "hp", "def", "atk", "hp"]:
		if player.buy_upgrade(kind):
			bought += 1
	return bought


func _print_row(seconds: float, player: PlayerState, combat: CombatSystem) -> void:
	print("%5.1f  %4d  %3d  %-8s  %-6s %-6s %-6s %d" % [
		seconds / 60.0,
		combat.enemy.wave,
		player.level,
		Num.fmt(player.gold),
		Num.fmt(player.attack()),
		Num.fmt(player.defense()),
		Num.fmt(player.max_hp()),
		combat.kills,
	])
