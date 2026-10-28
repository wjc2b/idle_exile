class_name Num
extends RefCounted

## 数值与时间的显示格式化：1.2K / 3.4M / 1小时23分

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx"]
## 超过这个量级就退回科学计数法，避免 int64 溢出后显示成负数。
const SAFE_LIMIT := 1.0e15


static func fmt(value: float) -> String:
	if is_nan(value):
		return "?"
	if is_inf(value):
		return "∞"
	var magnitude := absf(value)
	var sign_text := "-" if value < 0.0 else ""
	if magnitude < 1000.0:
		return sign_text + str(int(round(magnitude)))
	if magnitude >= SAFE_LIMIT:
		return "%s%.2e" % [sign_text, magnitude]
	var index := 0
	while magnitude >= 1000.0 and index < SUFFIXES.size() - 1:
		magnitude /= 1000.0
		index += 1
	var suffix := SUFFIXES[index]
	if magnitude < 10.0:
		return "%s%.2f%s" % [sign_text, magnitude, suffix]
	if magnitude < 100.0:
		return "%s%.1f%s" % [sign_text, magnitude, suffix]
	return "%s%d%s" % [sign_text, int(round(magnitude)), suffix]


static func fmt_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var days := total / 86400
	var hours := (total % 86400) / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if days > 0:
		return "%d天%d小时" % [days, hours]
	if hours > 0:
		return "%d小时%d分" % [hours, minutes]
	if minutes > 0:
		return "%d分%d秒" % [minutes, secs]
	return "%d秒" % secs


static func fmt_rate(per_second: float) -> String:
	return "%s/秒" % fmt(per_second)
