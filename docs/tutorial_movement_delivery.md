# 教学按E后移动恢复

目标：`F:\maze_code`。基线 `master` / `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`，在已有用户改动之上增量修复，未提交或推送。

## 证据与修复

在真实餐厅打开仓库后触发首次来客教学，先关闭仓库再按E结束教学，修复前出现输入锁残留及W/A/S/D四向均不移动，证据在 `output/tutorial_movement_red_overlap`（13项中5项失败）。根因是HUD每次加锁都覆盖原输入快照，叠加流程关闭时恢复成“已锁定”。

`scripts/ui/restaurant_hud.gd` 改为配对锁计数，首个持有流程保存原状态，最后一次释放才恢复。`scripts/restaurant/customer_flow.gd` 将首次来客教学推迟到玩家空闲，退出时释放来客教学持有的锁。`scripts/ch2_exploration_guide.gd` 的餐厅说明也等待原业务结束，避免保存另一流程的暂时锁态。`scripts/player_map.gd` 在物理帧中检查输入锁，保留此前携料显示。

同一复现修复后13项全部通过（`output/tutorial_movement_overlap_fixed`）。对话仍连续、或后续还有捕获/烹饪/章末页面时保留锁；不得为恢复移动而强制清除其他业务锁。

## 验收

- `tools/tests/tutorial_movement_run.ps1 -Mode flow -OutputRoot F:/maze_code/output/tutorial_movement_complete`：246项、0失败。遍历第一章对白清单与第二章七段说明，以真实E关闭并输入WASD测量实际位移；包含连续对白、弹窗嵌套、来客教学和章末接续。逐条对白采用正式管理器的等价场景，后续自然流程另由下面两项覆盖。
- `tools/tests/ch2_guide_01_run.ps1 -Mode ch1 -OutputRoot F:/maze_code/output/tutorial_movement_ch1`：87项、0失败，真实接单、订单说明、料理教学及关闭恢复。
- `tools/tests/ch2_guide_01_run.ps1 -Mode flow -OutputRoot F:/maze_code/output/tutorial_movement_ch2_final`：337项、0失败，双分辨率走完食谱说明、迷宫战力、吸收、捕获、镇压、背包及返店说明。修正旧测试缺少首次来客确认和未等待背包镜头结束的时序，未跳过教学。
- `tools/tests/tutorial_movement_run.ps1 -Mode smoke -OutputRoot F:/maze_code/output/tutorial_movement_smoke`；同入口 `-Mode import -OutputRoot F:/maze_code/output/tutorial_movement_import`：启动及编辑器检查。

上述最终场景验收正式存档指纹一致。环境仍有系统证书读取失败，编辑器设置写入权限提示单独记录。旧全章视觉回归 `output/chapter_end_redesign/tutorial_movement_outro-report.json` 为199项中1项失败，失败项为门口高亮明暗采样，输入恢复项通过；本次未修改该高亮效果，不能将该旧套件称为全部通过。

早期第二章重跑及旧全章回归期间曾检测正式存档指纹变化，测试已验证使用隔离目录，变化来源未确认；后续最终各套验收指纹稳定，没有覆盖或回滚正式存档。当前正在运行的旧游戏实例不会自动加载脚本修复，需重新进入游戏。输入锁本身是运行时状态，不写入存档。

## 稳定知识

餐厅同一HUD的加锁/解锁必须配对，首次锁才记录状态；新说明应等待已有餐厅业务释放输入。跨场景说明结束按原业务状态恢复，不能一律设置“可移动”。新增教学、改变关闭回调或场景销毁顺序后重新执行本专项与对应自然流程。
