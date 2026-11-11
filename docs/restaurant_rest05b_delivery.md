# REST05B 独立增量交付

基线 `f7c3e09f8a8275f1b9934562ad7fe2126a102d57`，分支 `codex/restaurant-day-settlement`，工作区 `C:\Users\KSG\.codex\worktrees\f3af\maze_code`。未写入目标 `F:\maze_code`；目标集成与最终验收由来源主会话负责。

## 实现与边界

新日逐份记录菜单来源；订单占用与实物消耗分开。超时补客、正确交付、误送实际菜、同菜乱序交付、手持/冷藏丢弃和打烊来源扣除均在原保存事务内更新。已有同菜成品、锅中及完整手持原料可用于开业，其余仓库预留仍需逐单选料。打烊剩余份额全部损耗，来源不符原子拒绝；旧营业无证据不追扣，下一日新账。

营业牌新增结束按钮，复用共用确认窗；取消恢复输入，保存失败留窗且状态不变，成功进入原结算动画。三种评价使用用户指定原文。奖励、扣罚、首章、迷宫、倒水冰度及生产音频未修改。验收退出辅助仅停止可选的 GameAudio（游戏音频单例）播放器并等待0.2秒。

## 实际验收

以下命令在本工作区运行：

```powershell
& tools/tests/restaurant_service_cycle_run.ps1 -Godot (Join-Path $PWD 'tools/godot_portable/godot.windows.opt.tools.64.exe') -Scene <场景> -OutputRoot <输出>
```

| 场景 | 输出 | 结果 |
| --- | --- | --- |
| `res://tools/tests/restaurant_rest05b.tscn` | `output/rest05b_04` | 645项，0失败 |
| `res://tools/tests/restaurant_rest05b_atomic.tscn` | `output/rest05b_atomic_01` | 25项，0失败 |
| `res://tools/tests/restaurant_rest05a.tscn` | `output/rest05b_a_regression` | 180项，0失败 |
| `res://tools/tests/restaurant_rest05b_ch1.tscn` | `output/rest05b_ch1_regression` | 87项，0失败 |

每轮退出码0、无意外引擎错误、正式存档指纹不变。系统证书读取错误单独归为环境警告。B含1152×648、1280×720真实餐厅E接单/上菜、仓库逐格选料、结束取消/保存失败重试、三种评价、次日以及零仓库原料现有冷藏成品菜单。烹饪在B走实际保存接口，首章87另覆盖原教学输入；B不重复烹饪小游戏专项。

额外25项覆盖出锅、交付、手持丢弃、冷藏取出/丢弃的保存失败全量回滚与重试。645项包含同菜乱序来源交换、误送优先备用同菜额度、五类来源、共享原料、额外库存保留、旧账、损坏账本拒绝及读档恢复。

截图在B输出目录，已查看 `rest05b_existing_menu_selected_1152x648.png`、`rest05b_manual_confirm_0_1152x648.png` 和三分支 `rest05b_result_sold_*`。早期02/03轮仅菜单测试布局未完成即滚动导致失败；03为645项中4个重复断言失败，正式档不变。等待两帧布局后再滚动的单变量修正于04全过；未改生产菜单绕过问题。

## 未运行与集成注意

本轮未重跑动画471项，入口为 `res://tools/tests/restaurant_settlement_animation.tscn`；主会话计划集成后运行。旧 `restaurant_rest05a_service_regression.tscn` 继承按来客计划耗尽结束的历史假设，本轮不作为新份额业务依据，B645替代其本票业务验证；不要为旧断言回退新规则。

未跟踪 `tools/previews/negative_settlement/` 保留且不提交。本票未改 `ui_layer.gd`、GameAudio或铁山并发文件；合入 SaveManager 和界面组件时应按增量保留主区改动。

## 稳定知识与重新审查条件

订单额度与实物来源必须分离：两份同菜可以乱序服务，来源交换保持另一顾客额度；不能通过取消另一订单掩盖绑定错误。仓库预留只限当日剩余菜单，锅中原料已扣；打烊不得再次扣仓库或清除额外库存。新增物品移动/销毁入口、配方共享原料、冰柜批次或存档迁移时，重新运行来源守恒、同菜乱序、全部回滚和实际营业专项。

## 主游戏目录最终集成

2026-11-05：执行任务停止写入后，主会话审查并将 f7c3e09..6aec0b7 增量合入 F:/maze_code，保留原有用户及并发音频改动，未推送。实际主目录运行以下入口（统一原restaurant_service_cycle_run.ps1）：

| 场景 | 主目录输出 | 通过项数 |
| --- | --- | --- |
| restaurant_rest05b.tscn | output/rest05b_main | 645 |
| restaurant_rest05b_atomic.tscn | output/rest05b_main_atomic | 25 |
| restaurant_rest05a.tscn | output/rest05b_main_arrival | 180 |
| ch2_guide_01_ch1.tscn | output/rest05b_main_ch1 | 87 |
| restaurant_settlement_animation.tscn | output/rest05b_main_animation | 471 |

合计1408项全部通过，各轮退出0、无意外引擎错误，正式存档指纹不变，仅系统证书环境警告。已检查主目录双尺寸结算与首客镂空截图。主目录动画测试增加退出音频清理；首章测试wrapper同样清理音频，未改生产音频或第一章逻辑。早期资源残留已由verbose定位为interaction_click.wav播放实例；正式存档早期变化记录未覆盖，用户退出游戏后最终各轮指纹稳定。

本票已在实际游戏工作区完成接入与相关集成验收。旧营业档继续明确兼容，下一日开始使用完整份额账本；不以最终通过掩盖早期失败记录。全量编辑器资源扫描未作为本票验收依据，实际场景集成证据见上表。
