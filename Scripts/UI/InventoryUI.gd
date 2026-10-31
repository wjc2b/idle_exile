class_name InventoryUI
extends Control

## 背包主脚本：驱动 Screens/ui/Character/InventoryUI.tscn。
## 左边 8 个装备格（绝对定位，节点名 → 存档键），右边 6x7 的格子装背包，
## 右键装备/卸下，拖动装备到左边的格子，格子悬停有完整词条提示。

signal equip_requested(item: Item)
signal equip_into_requested(item: Item, slot_key: String)
signal unequip_requested(slot_key: String)
signal upgrade_requested(item: Item)

## 场景里的格子节点名 → 存档里的装备键。改布局改名时同步这里。
const EQUIP_NODES := {
	"Head": "head",
	"Body": "body",
	"Legs": "legs",
	"MainHand": "main_hand",
	"OffHand": "off_hand",
	"LeftRing": "ring1",
	"RightRing": "ring2",
	"Amulet": "amulet",
}

@onready var _equipment_panel: Control = $CenterContainer/MainLayout/EquipmentPanel
@onready var _grid: GridContainer = $CenterContainer/MainLayout/MarginContainer/InventoryGrid

var character: Character

var _equip_views: Dictionary = {}
var _bag_views: Array[ItemSlotView] = []
var _selected: Item = null

var _detail_panel: PanelContainer
var _detail_box: HBoxContainer


func _ready() -> void:
	# 场景里的 EquipmentPanel 用默认样式，这里套上青铜边框，和格子统一。
	_equipment_panel.add_theme_stylebox_override("panel", UITheme.frame_style())
	_bind_slots()
	_build_detail()
	refresh()


## 与场景绑定：格子脚本、部位、槽位键。
func _bind_slots() -> void:
	for child in _equipment_panel.get_children():
		var key := str(EQUIP_NODES.get(String(child.name), ""))
		if key == "":
			continue
		var view := child as ItemSlotView
		if view == null:
			push_warning("%s 上没有挂 ItemSlotView 脚本" % child.name)
			continue
		var slot_type := str(GameData.equip_slot(key).get("type", ""))
		view.configure("equip", key, slot_type)
		view.selected.connect(_on_slot_selected)
		view.right_clicked.connect(_on_slot_right_clicked)
		view.item_dropped.connect(_on_slot_dropped)
		_equip_views[key] = view

	for child in _grid.get_children():
		var view := child as ItemSlotView
		if view == null:
			continue
		view.configure("bag", "", "")
		view.selected.connect(_on_slot_selected)
		view.right_clicked.connect(_on_slot_right_clicked)
		_bag_views.append(view)


## 把角色身上的装备和背包内容刷进格子。外部换装/掉落之后调用。
func refresh() -> void:
	if character == null:
		return

	for key in _equip_views:
		var view: ItemSlotView = _equip_views[key]
		view.set_item(character.equipped_at(key))

	for i in _bag_views.size():
		var bag_item: Item = character.inventory[i] if i < character.inventory.size() else null
		_bag_views[i].set_item(bag_item)

	if _selected != null and not _selection_alive():
		_selected = null

	_apply_selection()
	_update_detail()


func _apply_selection() -> void:
	for key in _equip_views:
		var view: ItemSlotView = _equip_views[key]
		view.set_selected(_selected != null and view.item == _selected)
	for view in _bag_views:
		view.set_selected(_selected != null and view.item == _selected)


func _on_slot_selected(view: ItemSlotView) -> void:
	_selected = view.item
	_apply_selection()
	_update_detail()


## 右键：身上的直接卸下，背包里的直接穿上（自动挑戒指空位）。
func _on_slot_right_clicked(view: ItemSlotView) -> void:
	if view.slot_kind == "equip":
		unequip_requested.emit(view.slot_key)
	elif view.item != null:
		equip_requested.emit(view.item)


## 拖到具体格子：按格子装，不自动挑位置。
func _on_slot_dropped(view: ItemSlotView, dropped: Item) -> void:
	if dropped != null and view.slot_key != "":
		equip_into_requested.emit(dropped, view.slot_key)


func _build_detail() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override(
		"panel", UITheme.panel_style(Color(0.030, 0.028, 0.034), UITheme.FRAME_DIM))
	_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_detail_panel.offset_left = 60
	_detail_panel.offset_right = -60
	_detail_panel.offset_top = -66
	_detail_panel.offset_bottom = -16
	add_child(_detail_panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 16)
	padding.add_theme_constant_override("margin_top", 8)
	padding.add_theme_constant_override("margin_right", 16)
	padding.add_theme_constant_override("margin_bottom", 8)
	_detail_panel.add_child(padding)

	_detail_box = HBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 18)
	padding.add_child(_detail_box)
	_detail_panel.visible = false


func _update_detail() -> void:
	if _detail_panel == null or _detail_box == null:
		return
	_clear(_detail_box)

	if _selected == null or character == null:
		_detail_panel.visible = false
		return
	_detail_panel.visible = true

	var item := _selected
	var color: Color = item.rarity_data().get("color", UITheme.TEXT)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	_detail_box.add_child(info)
	info.add_child(UITheme.label(item.full_name(), 16, color))

	var parts: Array[String] = []
	for affix in item.affix_values():
		parts.append(GameData.format_affix(affix))
	info.add_child(UITheme.label(" · ".join(parts) if not parts.is_empty() else "无词条", 13, UITheme.DIM))

	_detail_box.add_child(UITheme.label("战力 %s" % Num.fmt(item.score()), 14, UITheme.FRAME_GOLD))

	var equipped_key := _equipped_key_of(item)
	if equipped_key != "":
		var remove := _detail_button("卸下", 76)
		remove.pressed.connect(func(): unequip_requested.emit(equipped_key))
		_detail_box.add_child(remove)
	else:
		var equip := _detail_button("装备", 76)
		equip.pressed.connect(func(): equip_requested.emit(item))
		_detail_box.add_child(equip)

	var cost := item.upgrade_cost()
	var upgrade := _detail_button("强化 %d" % cost if cost > 0 else "满级", 104)
	upgrade.disabled = cost <= 0 or character.materials < cost
	upgrade.pressed.connect(func(): upgrade_requested.emit(item))
	_detail_box.add_child(upgrade)


func _detail_button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 34)
	button.add_theme_font_size_override("font_size", 14)
	UITheme.style_button(button)
	return button


func _equipped_key_of(item: Item) -> String:
	if character == null or item == null:
		return ""
	for key in character.equipment:
		if character.equipment[key] == item:
			return str(key)
	return ""


func _selection_alive() -> bool:
	if _selected == null:
		return false
	return _equipped_key_of(_selected) != "" or character.inventory.has(_selected)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
