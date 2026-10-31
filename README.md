# scrollofexile

2D 挂机放置 RPG（Godot 4.6 / GDScript）。核心循环：

**选职业 → 构筑 build（技能槽 + 天赋 + 装备）→ 挂机刷宝 → 回构筑调整**

## 现在能玩什么

- **三个职业**：战士（铁壁/重击）、游侠（疾风/暴击）、法师（烈焰/奥术）。基础属性、可用技能、天赋方向都不同，各自有像素头像。
- **技能槽**：每个职业 5 个技能，任选 4 个装进槽位。技能按冷却自动轮转释放，有瞬发/持续伤害/回血/增益四类。
- **天赋**：每级 1 点，每个职业 3 条天赋，每条 3 级，直接改战斗属性。
- **自动战斗**：普攻 + 技能轮转，按技能倍率、暴击、敌人护甲结算；死亡倒退 3 波。
- **刷宝**：击杀掉落 8 个部位的装备（头/身/下装/主手/副手/双戒/项链），5 档稀有度、最多 4 条词条，不如身上装备的自动分解成强化石。
- **背包 / 装备界面**：按 `I` 打开。左边纸娃娃 8 个格子，右边 6×7 的背包格；右键装备或卸下，也可以把背包里的装备直接拖到对应部位。
- **强化**：装备最多 +10，每次 +10% 词条数值。
- **金币出口**：200 金币换 10 强化石。
- **存档 / 离线**：每 10 秒自动存档，关窗口也存；再次进入按离线时长结算（最多 8 小时）。

## 怎么跑

```powershell
# 编辑器
f:\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe --path .

# 无头验证（导入 + 跑 240 帧，抓脚本错误）
f:\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe --headless --path . --quit-after 240
```

> 新建脚本后如果报 `Identifier "Xxx" not declared`，先跑一次
> `--headless --editor --path . --quit` 让编辑器重建全局类缓存。

## 目录

```
Scripts/
  Data/GameData.gd      职业 / 技能 / 天赋 / 词条 / 稀有度 / 部位 —— 调平衡主要改这里
  Core/
    Character.gd        角色数据：等级、天赋分配、技能槽、装备（8 格）、背包
    StatBlock.gd        属性聚合：(基础 + flat) × (1 + increased) × more
    Item.gd             装备：部位、稀有度、词条、强化
    ItemGenerator.gd    掉落生成：稀有度加权、词条抽取
    CombatSystem.gd     技能轮转自动战斗（纯逻辑，无节点依赖）
    EnemyState.gd       按波次缩放的敌人
    SaveSystem.gd       存档 v4（JSON，旧档读入时自动迁移）
    Num.gd              数字与时长格式化
  UI/
    UITheme.gd          配色、字体、控件工厂
    ClassSelectUI.gd    选职业界面（含头像）
    MainUI.gd           构筑 / 战斗 / 角色三页（角色页只是宿主）
    InventoryUI.gd      背包界面主脚本：填格、选中、详情条、信号
    ItemSlotView.gd     单个装备/背包格：图标、右键、拖放、tooltip
    EquipIcon.gd        没有图标素材时用代码画的部位剪影
  Game.gd               主控：存档、离线结算、掉落、界面切换
Screens/
  ui/Character/
    InventoryUI.tscn    背包界面（编辑器里排的版）
    EquipmentSlot.tscn  装备格
    IntentorySlot.tscn  背包格
Assets/
  Portraits/            四个职业头像（透明底，由 Tools/ProcessPortraits.gd 生成）
Tools/
  ProcessPortraits.gd   把黑底角色图抠成透明头像：去黑底 → 裁包围盒 → 横排图自动切分
  CaptureWindow.ps1     只截游戏窗口客户区的截图脚本（不会把桌面/任务栏拍进去）
Tests/
  SimulateProbe.gd      三职业各跑 30 分钟的数值探针
  InventoryProbe.gd     装备格/双戒指/存档迁移/拖放契约/I 键开关的自检
  MakeDebugSave.gd      造一个"玩了几分钟"的存档，方便看界面
```

## 背包界面怎么改

界面是编辑器场景 `Screens/ui/Character/InventoryUI.tscn`，脚本只负责填数据，不改布局：

- 左边 `EquipmentPanel` 下的节点名 → 存档键的映射写在 `InventoryUI.EQUIP_NODES`，改名要同步。
- 右边 `InventoryGrid` 的格子数量就是背包容量，改格子记得同步 `GameData.MAX_INVENTORY`。
- 格子图标走 `res://Assets/Items/<部位>.png`（例如 `head.png`、`main_hand.png`、`ring.png`），
  有图就用图，没有就用 `EquipIcon.gd` 画的剪影。
- 物品名和强化等级（`+N`）由脚本写进格子里的 `Label` 与额外创建的名字标签。

## 头像素材

原始素材是两张纯黑底、无透明通道的像素图（`Assets/像素风严肃战士头像.png`、
`Assets/三位像素奇幻角色肖像.png`）。`Tools/ProcessPortraits.gd` 负责把它们变成可用头像：

1. 从四边泛洪，只去掉与边缘连通的近黑背景（人物内部的深色描边不会被吃掉）
2. 按不透明像素算包围盒裁切
3. 横排三人图按"整列无像素"的空隙自动切成三张

输出 `Assets/Portraits/{warrior,ranger,mage,wizard}.png`。重跑一次：

```powershell
f:\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe --headless --path . --script res://Tools/ProcessPortraits.gd
```

四个头像里 **wizard（蓝帽白须老者）目前没用上**，留给未来的第四个职业。
UI 里全部用 `TEXTURE_FILTER_NEAREST`，保证像素不被插值糊掉。

## 调平衡

| 想改什么 | 改哪里 |
| --- | --- |
| 职业基础属性、升级成长 | `GameData.CLASSES[*].base / growth` |
| 技能倍率、冷却、效果 | `GameData.SKILLS` |
| 天赋数值 | `GameData.TALENTS` |
| 词条区间、稀有度权重 | `GameData.AFFIXES` / `GameData.RARITIES` |
| 敌人血量/攻击/护甲/金币成长 | `EnemyState` 顶部常量 |
| 装备数值成长速度 | `ItemGenerator.FLAT_SCALE`（必须低于敌人血量成长 1.09） |
| 掉落率、强化石数量 | `Game.DROP_CHANCE` 等常量 |

改完跑探针看曲线：

```powershell
f:\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe --headless --path . --script res://Tests/SimulateProbe.gd
```

## 存档

`%APPDATA%\Godot\app_userdata\scrollofexile\save.json`，JSON，字段平铺，可以直接手改。
版本号在 `SaveSystem.SAVE_VERSION`，改结构时记得升版本。

## 已知缺口（下一步候选）

- **战斗还没有画面**：只有血条和日志，没有角色/敌人立绘与技能特效。头像已经接进选职业页、顶栏和战斗页，但战斗过程本身仍是纯文字（`Assets/Animations/` 里有现成的像素动画素材，还没拆帧接进战斗）。
- **没有声望/转生**：数值是一条曲线，挂久了会进入"升级越来越慢"的平台期，缺一个重开换永久加成的循环。
- **装备只靠随机词条**：没有套装、没有传奇特效。
- **没有多波敌人/关卡**：单一波次推进，缺 boss 与地图选择。
- **物品没有图标**：背包现在用的是代码画的部位剪影，等有美术素材再换成贴图（`Assets/Items/`）。
- **其余页面还是代码搭的**：构筑页 / 战斗页仍在 `MainUI.gd` 里拼，背包页已经改成编辑器场景。
