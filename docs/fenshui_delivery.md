# FS-01 分水庭接入交付

2026-10-22，在 `F:\maze_code` 的 `master` 本地增量实施，基线提交为 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`。未切分支、未提交、未推送。来源任务为 `01a1618b-cb99-71c3-a1a9-b7ee6f39217b`，来源主机会话仍负责审查与最终集成确认。

## 玩家行为

- 枯水渠石阵前侧点击“前往下一区域”并确认，进入分水庭右上道路。
- 道路移动倍率为 1，浅水为 0.65，与原冲刺 1.5 倍相乘；每次移动重新取地形倍率，上岸立即恢复。
- 植被岛和外围空洞不可走，分步移动避免大步穿越。其它地图出口只保留画面与行走范围，不切入相邻区域；右上入口可返回枯水渠。
- 同一趟探索保留队伍、生命、饱腹、携物、技能选择及原区怪物记录，不再扣进场体力。分水庭不生成怪物、宝箱、采集点或新任务。
- 复用原任务、技能栏、背包、体力、饱腹和地图；模态输入沿用既有锁定与恢复。区域位置保存后，重新启动直接恢复分水庭。

## 文件与实现边界

新增 `assets/maps/fenshui.png`、`data/maze/fenshui_roads.gd`、`data/maze/fenshui_projection.gd`、`scenes/maze_fenshui.tscn`，以及 `tools/tests/fenshui_flow.gd/.tscn`、`tools/tests/fenshui_restart.gd/.tscn`。

增量修改 `scripts/maze/maze_entry.gd`、`maze_player.gd`、`maze_camera.gd`、`capture_flow.gd`、`capture_run.gd`，`scripts/save_manager.gd`、`scripts/ui/components/maze_map.gd`、`maze_map_view.gd` 和组件库登记。`scripts/ui_layer.gd`、技能实现、插件未修改。

原图采用指定绿色苔地、宽水域版，复制前后 SHA-256 均为 `27CE26A1B8F31A57694779C393533A1E0508633097ABE9F2082FCCC6C273277C`。没有重新生图或修改原图像素。

总图截图显示地图原点约 `(15,14)`，显示尺寸 `1198×674`，红框 `(389,258)` 至 `(851,505)` 换算到 `1672×941` 图集约为 `(522,341)` 至 `(1167,685)`。采用 17 个地标的分片仿射映射（每片三角形线性对应），以右上道路、北侧道路、中心水域与各支路校准；方向使用当前位置附近的同一变换。小图和大图共用坐标与方向。分水庭新增揭示范围带 28 像素柔边。

分水庭无魔物推进复用原战斗模拟的技能与冲刺计时，临时屏蔽原区怪物后恢复其完整记录；原区怪物时钟不推进，不产生异地击杀、刷新或奖励。换区清理飞行物、受击位移和当前动作，保留资源和冷却。

## 并发改动保留

执行中另一任务修改了石阵阻挡：`POSITION=(70,714)`、`FRONT=(100,720)`、`BLOCK_X=94`、只允许前侧交互，以及旧后侧出生纠正。检测到后暂停重叠写入，来源任务确认写者停止并释放后继续。上述改动全部保留，返回枯水渠使用 `FRONT`；它们不归属于本票新增实现。

组件库同时收到角色详情与出口任务的追加，本票读取最新版后仅追加登记。原受影响文件副本和散列在 `output/fenshui/baseline/`、`baseline.json`；最终散列在 `final_hashes.json`。基线与最终差异中的上述并发内容不可归因或回退为 FS-01。

## 实际验收

执行器为 `tools/tests/combat_02_run.ps1`，Godot 为 `F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，实际版本 `4.7.2.stable.steam.ed1daf0bf`。执行器隔离 APPDATA/LOCALAPPDATA，并在每次运行前后比对正式存档 JSON 指纹。

| 产物目录 | 命令参数 | 结果 |
| --- | --- | --- |
| `output/fenshui/flow_final` | `-Mode flow -ScenePath res://tools/tests/fenshui_flow.tscn` | 1152×648、1280×720，171 项通过 |
| `output/fenshui/restart_seed` | `-Mode flow -ScenePath res://tools/tests/fenshui_restart.tscn -ProfileRoot output/fenshui/restart_profile` | 写入隔离档，9 项通过 |
| `output/fenshui/restart_restore` | 同上，另一个进程 | 39 项通过，整趟探索、水中位置、生命携物恢复；连续水→路→水 |
| `output/fenshui/skill_regression` | `-Mode flow -ScenePath res://tools/tests/combat_skill_01.tscn` | 既有技能双分辨率 193 项通过 |
| `output/fenshui/import_final` | `-Mode import` | 编辑器导入通过，无脚本/资源错误 |
| `output/fenshui/smoke_final` | `-Mode smoke` | 主场景无头启动通过 |

各命令还传入 `-OutputRoot` 为表中目录，完整参数、进程编号、结果和正式档指纹都在对应 `summary.json`。全部最终运行正式存档指纹不变。系统证书读取有环境告警，编辑器导入另有安装目录编辑器设置写入权限告警，未掩盖项目错误。

截图位于 `flow_final/screenshots/`：`01_kushui_sign`、`02_confirm`、`03_fenshui_spawn`、`04_water_hud`、`05_full_map`、`06_backpack`、`06b_tasks`、`07_restored`、`08_return_kushui`，均附两种分辨率后缀。已查看出生、水域HUD、大小地图、任务和回归场景截图。任务截图处于面板展开动画早期；功能断言和后续关闭输入已通过。

早期失败原样保留：首次导入发现 PackedVector2Array 不能用于该常量表达式；测试名称与内置 Projection 冲突；地形类需实例化才能调用反射方法，均已修正。`flow3` 的返回站位问题受并发石阵变更影响，障碍探针原本未穿过岛体，背包后UI断言早于下一帧刷新；分别改用前侧点、正确探针和两帧观察。`flow4` 在石阵新规则下使用了旧站位，`flow5` 仅剩UI观察时序，`flow6` 167项通过；最终增加真实鼠标按钮和任务展开检查后171项通过。没有将任何早期局部报告称为整体通过。

## 验证边界与复用知识

行走边界是按指定原图手工标注的多边形与岛体椭圆，不是逐像素语义识别；验收覆盖入口、中央水域、各方向、岛体/外围探针和大步越界，未穷举每个像素。底图、更换岛体轮廓或移动速度规则变化后应重做相应边界验收。

分水庭复用现有技能表现与规则；本票没有重新设计技能弹道碰撞或新增区域战斗。不开放其它相邻地图。今后为分水庭增加战斗时，须单独核验现有技能的旧区弹道范围、地形遮挡和怪物区域归属，不能仅放置旧区怪物。

区域必须同时驱动行走校验、镜头尺寸、保存校验、恢复场景和地图投影；只换背景会使位置被旧区域安全点覆盖。此结论由跨进程恢复与真实场景串联验证。新区域接入或保存结构变化后重新运行本票两个场景入口。
