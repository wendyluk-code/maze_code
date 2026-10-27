# 实现定位与验收

2026-10-27核对的工作区基线提交为 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`，当时有大量未提交/未跟踪实现；提交本身不代表这些实现均已入库。其他开发者先核对文件存在和Git状态，缺文件回报依赖缺口。本清单不证明全部游戏资源已经共享。

以下代码路径相对仓库根；简写文件名沿同一行注明的目录查找。用 `rg -n 'region_id|fenshui|salt_pool' scripts data scenes` 查区域分支，用 `rg --files docs tools/tests` 查最新记录。历史文档先追踪开头修订链接；当前实现优先，但候选代码不等于已验证。

## 三张地图的参考边界

| 区域 | 数据入口（均在 `data/maze/`） | 复用边界 |
| --- | --- | --- |
| 枯水渠 `maze_entry` | `entry_roads.gd`、`entry_map_projection.gd`、`capture_catalog.gd` | 史莱姆、砖壳蜗牛、剑甲虫、石化蜥蜴；布局版本、随机配额、首遇保护和首史莱姆规则有专属语义，不能给新图沿用首区清场 |
| 分水庭 `fenshui` | `fenshui_roads.gd`、`fenshui_projection.gd`、`fenshui_encounters.gd`、`fenshui_boss.gd` | 鱼鳗水域巡游已取消旧85像素出生圈；巨蛙可跨岸路、起落点留水；御风保护和资源避让需保留 |
| 盐池 `salt_pool` | `salt_pool_roads.gd`、`salt_pool_projection.gd`、`salt_pool_encounters.gd`、`salt_boss.gd` | 盐地减速，盲水蝎水属性不意味着可入池水；拟态蟹与真宝箱分开；岩鬃兽已改中央出生、绕障和扇形咆哮 |

先读 `docs/boss_combat_repair.md` 和 `docs/fenshui_swimming.md`：巨蛙西侧混合水怪追击仍未通过，320像素单跳及路径是候选实现，不能当通用已验证方案。`docs/map02_wind_frog.md` 的隐藏出水/中央范围和 `docs/map04_salt_boss_mining.md` 的北侧冲撞是历史行为。本技能不授权顺便修这些遗留问题。

## 地图接入不是只添场景

| 路径 | 核对内容 |
| --- | --- |
| `scenes/maze_entry.tscn`、`scenes/maze_fenshui.tscn`、`scenes/maze_salt_pool.tscn` | 共享 `scripts/maze/maze_entry.gd`，由 `region_id` 区分区域 |
| `scripts/maze/maze_entry.gd` | 背景、路标、交互目的地、确认框、`travel_region`（跨区域移动）、资源生成和区域效果 |
| `data/maze/region_routes.gd` | 来源、出生和返回点；共享脚本仍有区域分支，登记路由不等于接通所有出口 |
| `scripts/save_manager.gd` | `maze_exploration_state`（探索恢复）、区域场景选择、`maze_terrain`（地形选择）、允许区域及位置记录；检查全部调用方 |
| `data/maze/*_roads.gd`、`scripts/maze/maze_player.gd`、`scripts/maze/maze_camera.gd` | 世界尺寸、可走区域、脚底半径、速度、镜头边界；玩家、怪物、弹道和空中路径分别验证 |
| `data/maze/*projection.gd`、`scripts/ui/components/maze_map.gd`、`scripts/ui/components/maze_map_view.gd` | 世界到总图坐标、迷雾和标记、小图与展开图共享规则 |

换图读 `docs/salt_pool_integration.md`、`docs/fenshui_map_alignment.md`：底图、碰撞、速度区、出生/返回点和投影一起校准。当前存在青苔池连接，旧文档“左侧不新增跨区”只是当时范围，不能据此删当前连接。

## 怪物、奖励与资源

- `data/maze/capture_catalog.gd`：`rows` 是区域/本趟演员列表，`capture_kinds` 是全局捕获种类。新增种类检查 `active`（区域激活判断）、身份前缀、奖励查询和全局失败计数，不只改贴图和局部列表。
- `scripts/maze/combat_simulation.gd`：创建/校验演员、推进战斗、地形选择；新增阶段同时核对恢复校验与攻击入口。
- `scripts/maze/capture_run.gd`：区域首次补入、付费捕获、随机结果、奖励与保存失败整体回滚。旧版缺新区域可迁移，已初始化集合缺演员属于损坏，不能当首次到访重新抽奖。
- `scripts/maze/` 下 `capture_flow.gd`、`capture_monster.gd`、`team_attack.gd`：状态到显示、朝向动作、攻击与受击反馈。特殊行为再读同目录 `water_spacing.gd`、`wind_frog_combat.gd`、`frog_water_path.gd`、`rockmane_combat.gd`、`rockmane_path.gd`。
- 动作读 `docs/monster_animation_direction.md`、`docs/monster_shadow_alignment.md`：行序、统一比例、逐帧接地点；图集切换检查体型跳变，白闪状态还需证明实际渲染帧可见。
- 食材/食谱查 `scripts/maze/capture_recipes.gd`、`scripts/cooking/recipe_catalog.gd`。当前捕获食材经探索暂存袋结算到 `warehouse_stock`（仓库库存），与 `inventory`（手持库存）不同，新奖励先确认去向。

资源读 `data/maze/region_resources.gd`、`scripts/maze/region_harvest.gd`、`scripts/maze/salt_crystals.gd`、`docs/map05_food_loop.md`。永久宝箱、每趟植物、每日盐晶不共用重置策略。盐晶按北京时间本机时间，不是服务器可信时间；多弹命中按同次攻击去重，JSON恢复的数字类型需规范化。资源中心不可走不必改碰撞，应验证是否能从合法站位进入交互半径。

界面从 `docs/ui_component_library.md` 定位并复用 `destination_confirmation`（目的地确认）、`capture_dialog`（捕获入口）、`capture_attempt_modal`（捕获操作）、`loot_modal`（奖励弹窗）、`feedback_toast`（短暂提示）；验证距离显隐、确认/取消、暂停及输入恢复。

## 验收矩阵

| 改动 | 真实行为 | 参考入口（在 `tools/tests/`） |
| --- | --- | --- |
| 地图/连接 | 前图进入、确认/取消、返回点、战斗锁、存盘失败；岸线窄路与速度；大小图独立地标；重进安全点 | `salt_pool_flow.tscn`、`fenshui_map_alignment.tscn`、`salt_map_connectivity.gd` |
| 普通怪 | 合法出生、可达；混合怪巡游/追击/回位；命中/闪避；捕获成功/失败/放弃、经验和实际入库 | `map01_flow.tscn`、`map03_flow.tscn`、`guard_remove_capture.tscn` |
| 首领 | 与普通怪同场、多侧远端追击、障碍窄路、锁向/预警/受击反馈；剧情前后两态 | `fenshui_swimming.tscn`；按 `docs/boss_combat_repair.md` 查现行盐池专项，旧冲撞测试不能直接沿用 |
| 存档/目录 | 旧档补入一次；缺记录拒绝；攻击/腾空/付费阶段跨进程恢复；跨图不重扣不重奖；全种类计数保留 | `map01_restart.tscn`、`map02_restart.tscn`、`map03_restart.tscn`、`map04_restart.tscn`、`map01_pity_compat.tscn` |
| 资源/料理 | 距离、重复领取、保存失败、放弃/下一趟/跨日；捕获→入库→烹饪→使用（仅授权链） | `map04_contract.tscn`、`map05_flow.tscn`、`map05_chain.tscn` |
| 素材/界面 | 拼图/循环预览、方向与比例、逐帧阴影、双分辨率遮挡、弹窗关闭后输入 | `monster_direction_flow.tscn`、`monster_shadow_acceptance.tscn`及本票真实截图 |

测试先读再用，既有入口不等于覆盖新图。连通采样说明精度；设置节点位置不证明真实追击可达。参考现有1152×648和1280×720双分辨率，适配目标有变随需求更新。

读 `tools/tests/combat_02_run.ps1` 和目标场景参数。当前支持 `-ProjectRoot`、`-Godot`、`-OutputRoot`、`-ProfileRoot`、`-ScenePath`，单次引擎等待240秒。重启专项需分别查脚本的阶段环境变量，多个进程共用独立测试存档；不能把内置重启模式当所有专项协议。

```powershell
# 在目标仓库根运行，先将变量设为本机已核验的Godot可执行文件路径。
& ./tools/tests/combat_02_run.ps1 -Mode flow -ProjectRoot (Get-Location).Path -Godot $godotExe -ScenePath res://tools/tests/salt_pool_flow.tscn -OutputRoot output/new_map/flow
# 仅示范已有盐池入口；新图替换为本票真实场景验收入口。
```

用独立输出与隔离存档，检查实际存档路径及正式档前后指纹。失败保留证据，其他进程可能写正式档时不回写/恢复用户档，也不把功能通过称为保护检查通过。导入/启动依项目最低验收，证书/编辑器目录告警与脚本/资源错误分列。

## 稳定知识与复查

复用的是分离地形合法性、全局种类与区域演员、奖励事务、素材锚点和真实场景验收的方法，不是旧坐标、数量或通过次数。底图、身体半径、动作图集、区域目录或状态字段变更后复查相应证据。本技能来自代码与历史报告交叉核对，编写时未重跑游戏测试，不继承旧报告的完成声明。
