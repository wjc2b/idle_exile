class_name ItemSlotView
extends PanelContainer

## 装备格 / 背包格的通用视图，挂在 EquipmentSlot.tscn 与 IntentorySlot.tscn 的根节点上。
## 图标优先用 res://Assets/Items/<部位>.png，没有素材时退回 EquipIcon 画的剪影。
## 右键：背包里装备 / 身上卸下；左键：选中；背包格可以拖到装备格。

signal right_clicked(view: ItemSlotView)
signal selected(view: ItemSlotView)
signal item_dropped(view: ItemSlotView, item: Item)

const ICON_DIR := "res://Assets/Items/"

var slot_kind := "bag"   # bag / equip
var slot_key := ""       # 装备格：head / ring1 ...
var item_type := ""      # 这个格子接受的物品部位
var item: Item = null

var _icon_rect: TextureRect
var _fallback: EquipIcon
var _count_label: Label
var _name_label: Label
var _selected := false


func _ready() -> void:
	_ensure_nodes()
	_refresh()


## 供外部在入树前设置格子信息。
func configure(kind: String, key: String, type_id: String) -> void:
	slot_kind = kind
	slot_key = key
	item_type = type_id
	if is_inside_tree():
		_ensure_nodes()
		_refresh()


func set_item(new_item: Item) -> void:
	item = new_item
	if is_inside_tree():
		_ensure_nodes()
		_refresh()


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply_style()


func _ensure_nodes() -> void:
	var control := get_node_or_null("Control") as Control
	if control != null:
		# 场景里的 Control 铺满整格，必须让它把鼠标事件放给外面的 PanelContainer。
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _icon_rect == null:
		_icon_rect = find_child("Icon", true, false) as TextureRect
		if _icon_rect == null:
			_icon_rect = find_child("TextureRect", true, false) as TextureRect
		if _icon_rect != null:
			_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _count_label == null:
		_count_label = find_child("Label", true, false) as Label
		if _count_label != null:
			_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_count_label.add_theme_font_size_override("font_size", 13)
			# 场景里放在右下角，这里挪到右上角，把底部让给物品名。
			_count_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			_count_label.offset_left = -34
			_count_label.offset_top = 3
			_count_label.offset_right = -5
			_count_label.offset_bottom = 21
			_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if _fallback == null and control != null:
		_fallback = EquipIcon.new()
		_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(_fallback)
		_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fallback.offset_left = 6
		_fallback.offset_top = 6
		_fallback.offset_right = -6
		_fallback.offset_bottom = -22

	if _name_label == null and control != null:
		_name_label = UITheme.label("", 12, UITheme.TEXT)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.clip_text = true
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(_name_label)
		_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_name_label.offset_left = 3
		_name_label.offset_top = -21
		_name_label.offset_right = -3
		_name_label.offset_bottom = -3

	mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh() -> void:
	var kind := item.slot if item != null else item_type
	var texture_path := ICON_DIR + kind + ".png"
	var has_texture := item != null and ResourceLoader.exists(texture_path)

	if _icon_rect != null:
		_icon_rect.visible = has_texture
		_icon_rect.texture = load(texture_path) if has_texture else null
		_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _fallback != null:
		_fallback.visible = not has_texture
		_fallback.set_kind(kind)
		if item != null:
			_fallback.set_visual(item.rarity_data().get("color", UITheme.TEXT), false)
		else:
			_fallback.set_visual(UITheme.FRAME_GOLD, true)

	if _count_label != null:
		_count_label.text = "+%d" % item.upgrade if (item != null and item.upgrade > 0) else ""
		_count_label.add_theme_color_override("font_color", UITheme.GOLD)

	if _name_label != null:
		if item != null:
			_name_label.text = item.base_name
			_name_label.add_theme_color_override("font_color", item.rarity_data().get("color", UITheme.TEXT))
		elif slot_kind == "equip":
			_name_label.text = str(GameData.equip_slot(slot_key).get("name", ""))
			_name_label.add_theme_color_override("font_color", Color(0.40, 0.38, 0.34))
		else:
			_name_label.text = ""

	tooltip_text = _tooltip_text()
	_apply_style()


func _apply_style() -> void:
	var bg := Color(0.030, 0.028, 0.036)
	var border := UITheme.FRAME_DIM
	if item != null:
		var rarity: Color = item.rarity_data().get("color", UITheme.FRAME_GOLD)
		border = UITheme.FRAME_GOLD.lerp(rarity, 0.45)
		bg = Color(0.046, 0.042, 0.050)
	if _selected:
		border = UITheme.GOLD

	var style := UITheme.panel_style(bg, border)
	style.set_border_width_all(2 if _selected else 1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


func _tooltip_text() -> String:
	if item == null:
		if slot_kind != "equip":
			return ""
		return "空着的%s。\n把同部位的装备拖进来，或右键背包里的装备。" % str(GameData.equip_slot(slot_key).get("name", slot_key))
	var lines: Array[String] = [
		item.full_name(),
		"部位：%s    战力 %s" % [item.slot_name(), Num.fmt(item.score())],
	]
	for affix in item.affix_values():
		lines.append("· " + GameData.format_affix(affix))
	if item.affixes.is_empty():
		lines.append("（无词条）")
	lines.append("右键卸下" if slot_kind == "equip" else "右键装备，或拖到身上的格子里")
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		if item != null:
			right_clicked.emit(self)
		accept_event()
	elif mouse.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_kind != "bag" or item == null:
		return null

	var preview := PanelContainer.new()
	var color: Color = item.rarity_data().get("color", UITheme.TEXT)
	preview.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.07, 0.07, 0.08), color))
	preview.add_child(UITheme.label(item.full_name(), 15, color))
	set_drag_preview(preview)

	return {"item": item}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if slot_kind != "equip" or item_type == "":
		return false
	if typeof(data) != TYPE_DICTIONARY or not data.has("item"):
		return false
	var dropped: Item = data["item"]
	return dropped != null and dropped.slot == item_type


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(self, data["item"])
