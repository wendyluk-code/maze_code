# 营业结算图表动画（2026-11-05）

主区接入进度：`af420a1..f069306` 已增量合入 `F:/maze_code`；`output/settlement_animation_main` 471项通过且正式存档指纹不变。原v11回归459项功能通过，但首次运行期间正式存档指纹变化，保留 `output/settlement_animation_main_regression`，未回写存档，另行复验。新教学和菜单损耗规则尚在后续票据中，不能以此片称整轮经营修改完成。

## 范围与状态

本片在 `af420a15a3aaade8bc6ffa07c80ff58e84c15ebf` 上，仅修改 `restaurant_day_chart.gd` 与 `restaurant_day_settlement.gd` 的展示。独立工作树验收通过后由来源主会话合入实际游戏目录并集成验收；本片不代表主区已经完成。

保留v11弹窗、真实历史来源、损耗列表、原评价和“明日准备”事务。复用 `SproutTheme`（主题）、`SproutModal`（模态窗）、资源图标和按钮；未增加素材或声音。未修改经营账务、顾客流程及后续三分支评价。未跟踪的负数静态预览目录保留，不随生产提交。

## 展示行为

- 打开后0.8秒内从零线展开。正柱向上，负柱向下；左侧金额/声望、图上数值和折线节点共享同一个线性进度，最终显示实际回执值。
- 轴范围由完整历史预先确定，播放中不变。零线始终标0；数据全部非正时不显示多余正刻度。零收入只有节点，不生成收入柱。
- 负数放在柱底外侧，声望负值加细引线。日期采用已确认负数预览的位置，为下方数值留空。短负柱用真实高度绘制，不以圆角最小尺寸放大。
- 最近六天仍只展示已有记录，单天只有节点，相邻已知日期之间才连线。
- 再次打开先停止并释放旧图表，再从零开始。确认成功停止动画；保存失败保留弹窗、输入锁和重试入口，动画不改变结算账目。

## 验证与证据

入口：`tools/tests/restaurant_settlement_animation.tscn`。在隔离存档中装载真实餐厅，分别用1152×648和1280×720窗口验收0/−3、180/−3、全零、正声望、两天、六天混合值及负金币。记录动画中途/结束截图，并测试动画中重复打开、真实点击确认失败与重试、输入恢复及账目不变。

```powershell
& tools/tests/restaurant_service_cycle_run.ps1 -Godot (Join-Path $PWD 'tools/godot_portable/godot.windows.opt.tools.64.exe') -Scene res://tools/tests/restaurant_settlement_animation.tscn -OutputRoot output/rest04_animation_02
```

结果：471项通过，0失败；正式存档指纹未变。仅有系统证书读取环境警告。截图和 `acceptance.json`、`runner-summary.json` 同目录。

原v11回归以相同运行器执行 `res://tools/tests/restaurant_settlement_v11.tscn`，输出 `output/rest04_animation_v11_regression`：459项通过，0失败，正式存档指纹未变。覆盖空/一/二/六天、旧档、真实烹饪交付和损耗事务、保存失败重试、铁山路径；仅同一系统证书环境警告。`git diff --check` 通过。

首轮 `output/rest04_animation_01` 保留失败证据：22条起始坐标断言错误使用浮点精确比较，改为误差比较；12条负数标签区域检查发现日期留空不足，采用已确认预览日期位置后复验通过。无账务或确认流程失败。

## 可复用结论与重验条件

同一线性轴上180与−3的高度比例必须是60:1。提高可读性应使用零线和柱端标签，不能给负柱设置会夸大数值的最小高度。节点使用单精度向量，验证坐标时应使用浮点误差比较。修改坐标范围、字号、日期位置、弹窗生命周期或保存确认事务后，需重跑双尺寸动画专项及结算回归。

主区复验：output/settlement_animation_main_regression_retry 的459项全部通过，正式存档指纹不变；首次变化记录继续保留。

最终经营规则合入后的主区复验：output/rest05b_main_animation 471项全通过，正式存档不变，无意外引擎错误；测试退出复用音频清理helper，生产动画不变。
