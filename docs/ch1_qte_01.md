# CH1-QTE-01 首单火候与品质闭环

料理台打开烹饪弹窗后，玩家先看到菜名与材料需求。点击“开始烹饪”才会一次扣除岩鬃肉和岩盐；开始前可取消，开始后按钮锁定且不能重试。指针按配方配置从左到右再返回，起锅时读取实际位置：中央精准区为 3 星，外围良好区为 2 星，其余为 1 星；完整往返无人操作自动结算 1 星。

首单配方 `salt_grilled_rockmane` 当前参数：往返 3.6 秒，精准区总宽度 0.16，良好区总宽度 0.38（指针坐标范围 -1 至 1）。品质写入 `prepared_dishes`，同名料理按 1/2/3 星分别计数；交付时奖励分别为 10/12/15 声望，制作本身不奖励，重复交付幂等。

`first_order_cooking` 保存状态为 `idle`、`active` 或 `locked`。退出重进时未锁定的 `active` 状态迁移为 1 星 `locked` 成品，已锁定品质原样保留；旧档无星成品按 1 星迁移，旧的 20 声望凭证视为已结算，不重复发放。

专项数据验收：

```powershell
& 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tools/tests/ch1_qte_01_suite.tscn --quit-after 10
```

图形验收应在隔离 `user://` 目录执行餐厅主场景，分别在精准区、良好区、外围区起锅，确认弹窗结果、订单卡品质、前台顾客评价与 10/12/15 声望反馈；同时检查开始前取消、缺料拒绝、重复起锅/交付幂等、弹窗期间输入不穿透和关闭后玩家控制恢复。

本票的等价 GUI 输入验收由 `ch1_qte_01_suite` 通过按钮 `pressed` 信号执行，并在 `output/ch1_qte_01/1152x648/` 与 `output/ch1_qte_01/1280x720/` 保存开始、进行中和三档结果截图。绿区绘制和判定均使用归一化总宽度：精准区边界为 ±0.08，良好区边界为 ±0.19；边界包含在高档区域。

餐厅场景的真实输入链路由 `tools/tests/ch1_qte_01_input.tscn` 验收：隔离存档准备取料阶段后，用真实 `E` 事件进入料理台，再以 `Viewport.push_input`/`Input.parse_input_event` 发送鼠标移动和左键按下/释放，指针按自然时间运行，最后再用 `E` 在前台交付。该链路在 1152×648 和 1280×720 各通过 21 项检查，证据位于 `output/ch1_qte_01/input_1152x648/` 与 `output/ch1_qte_01/input_1280x720/`。组件级固定指针检查仍保留在 `ch1_qte_01_suite`，不替代餐厅链路证据。

图形链路重跑示例（两次分别替换分辨率和输出目录）：

```powershell
$env:APPDATA = $isolatedRoot; $env:LOCALAPPDATA = $isolatedRoot
& 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path . --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --scene res://tools/tests/ch1_qte_01_input.tscn --quit-after 1800 -- --output-dir=output/ch1_qte_01/input_1280x720
```
