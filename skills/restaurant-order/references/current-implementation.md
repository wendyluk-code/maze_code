# 当前点单实现与复用规则

以下为截至2026-10-22的已确认规则；每次接单任务仍以当前代码和用户新要求为准。仓库路径均相对 `F:\maze_code`。

## 当前顾客及触发

| 顾客 | 订单（各1份） | 出现条件 |
| --- | --- | --- |
| 铁山，初始名“？？？” | 盐烤岩鬃肉 | 第一章剧情登场，独立教程流程 |
| 男01，显示名“冒险者”，内部 mage | 史莱姆糖块 | 第一章及收尾完成，在餐厅通过WASD累计实际移动满2秒 |
| 女05，显示名“冒险者”，内部 dingdang | 砖壳蜗牛刺身 | 接男01订单后，再进入迷宫并返回餐厅；接单前往返不计入 |
| 男08，深绿发，显示名“冒险者”，内部 half_elf | 石化蜥蜴脆皮串 | 女05交付结算、餐后对白和离场全部结束 |

三位冒险者各出现一次，跨天和读档不重置。移动时间只计实际位移，锁定、静止、方向键、被阻挡时不计；累计值保存。迷宫出发/返回标记与相关事务一起保存，失败回滚。新顾客不能仅按目录索引自动紧接上一位出现。

区分“接单”“交付结算”“餐后对白结束”“离场完成”，它们不是同一个事件。新触发应明确依赖哪个事件、先后关系及存档恢复；例如“接单之后首次返回”不能用全局曾到过迷宫代替。新角色的门槛由本次需求决定，不自动照搬男01/女05/男08的条件。

旧档已出现的顾客及已接订单保留；旧循环版本超额且未接单的前台顾客撤下。追加角色前核验旧序号，尤其超过三的历史循环序号，按新需求处理迁移，不能直接扩目录后假设所有旧档可触发。

## 对白与星级评价

普通冒险者接单模板为“请给我一份{料理名}。”。餐后对白读取本订单结算凭证中的实际交付星级，读档仍使用同一星级：

- 3星：真美味啊，下次还来！
- 2星：吃着还凑合，至少填饱肚子了。
- 1星：……怎么有股糊糊的味道，勉强能吃吧。

新普通顾客默认复用以上评价，用户可指定角色化台词。铁山首单保留独立餐后剧情，不用普通评价覆盖；其“再来一份”对白本身不创建第二订单。料理、配方与奖励读取 `scripts/cooking/recipe_catalog.gd`、`scripts/save_manager.gd` 的现值，换形象不改奖励。

## 头像、对白与等餐气泡

- 头像裁切贴紧头像框底部，去除下方透明留白；保持人物比例，尺寸按组件实际需求处理。参考裁切入口 `tools/npc_01_slice.py`，不把现有256头像、384动作单格硬编码为未来素材要求。
- 顾客对白复用公共 `DialogBox` 和 `modal_style.gd` 蒙层；蒙层绑定对白实际可见性，接单及餐后都覆盖。保持原对白宽度、底部位置和背包位置；对话锁与输入恢复沿用现有流程。
- 所有点单顾客坐下等餐时显示头顶料理气泡，包括铁山。复用 `scripts/ui/components/customer_order_bubble.gd`：米白底、棕色圆角描边、朝下尖头；尖头与主体连通，连接处没有横向描边。里面只放对应料理图标，无文字数字。
- 气泡跟随人物头顶，保留间距、避免遮脸或相邻重叠。图标复用 `recipe_catalog.item_texture()` 与 `bag_icon_display.texture()` 去透明边显示副本，不改变源素材。
- 气泡只读取状态：入座完成、等餐显示；上菜成功即隐藏，交付失败保留；进食、餐后和离场不显示。读档从订单阶段恢复，不另存显示标记。
- 普通顾客由 `scripts/restaurant/customer_flow.gd` 接入；铁山由 `scripts/guest_placeholder.gd` 的等待阶段及首单结算接入，`tutorial_manager.gd` 恢复其坐姿/餐后阶段。新角色先辨别使用哪条流程。
- 萨莉亚、叮当、御风旧素材、入场动画及对白模板保留：`CustomerCatalog.LEGACY_CUSTOMERS`、`legacy_customer()`、`customer_flow._frame(..., true)`。显示身份与持久化ID分离。

## 实现入口与验收选择

- `docs/restaurant_customers.md`、`docs/ui_component_library.md`：经营与界面约定。
- `scripts/restaurant/customer_catalog.gd`：当前及旧人物配置。
- `scripts/save_manager.gd`：`ensure_restaurant_customer()`、`record_customer_walk()`、`record_maze_location()`、`accept_restaurant_customer()`、`deliver_restaurant_customer()`、`advance_restaurant_customer()`、`customer_review()`；以及首单事务。
- `scripts/player_map.gd`：真实WASD位移计时；`scripts/maze/capture_run.gd` 的 `finish()`：生产迷宫返回结算，不能只测位置记录接口代替。
- `data/quests/catalog.json`、`docs/quests.md`：仅新增或改型任务时接入登记、迁移、未读与归档。

按改动选用并适配专项：

| 场景入口 | 覆盖范围 |
| --- | --- |
| `tools/tests/customer_timing.tscn` | WASD累计、中途读档、接单前后往返、返回保存失败、女05对白离场、星级评价 |
| `tools/tests/customer_bubble.tscn` | 三种料理气泡、入座、读档、交付失败/成功、蒙层及离场输入恢复 |
| `tools/tests/tieshan_bubble.tscn` | 铁山真实入座、首单事务、结算前后读档气泡 |
| `tools/tests/npc_portrait_layout.tscn` | 头像与对白布局；不能代替完整交互 |

以上场景可用隔离Godot运行器直接加载，分辨率至少检查1152×648和1280×720。`tools/tests/npc_01_run.ps1 -Mode startup` 为启动检查；编辑器检查可用 `-Mode editor -SkipBlenderFor2D`，禁用Blender仅限隔离2D验收。旧 `day1_customers`、`npc_01_scene`、`customer_once` 部分夹具仍假设连续来客或旧教程，运行前适配，不能将历史通过数当作当前新需求证据。三人同时坐下的气泡测试是兼容存档展示夹具，不证明当前正常来客时机。

保持测试存档隔离；如临时改变配置，在 finally 中恢复并核验指纹。正式存档前后指纹变化时检查即未通过，保留证据，不推断来源、不覆盖或回退用户存档。此前铁山专项13项通过，但随后一次启动检查的正式JSON存档指纹发生变化，来源未确认；这个历史异常不能被表述为存档保护检查通过。
