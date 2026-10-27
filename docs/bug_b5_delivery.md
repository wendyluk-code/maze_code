# B5 盐池周期白色蒙层修复交付

本票独立工作树实现与验证通过；未合入 F:/maze_code，最终集成由来源主会话执行。

- 目录：C:/Users/KSG/.codex/worktrees/e906/maze_code
- 分支：codex/bug-b5
- 基线：codex/bugfix-baseline-20261022，d50be15f12f00326df408cd4c389445abf4c0c93
- 来源：01a163b4-c5e2-7720-b326-a59c64b5b1b5，hostId=local
- 写入范围：scripts/maze/salt_ground_effects.gd、tools/tests/bug_b5*、本文。

## 问题与最小修复

真实盐池场景中的 SaltGroundEffects 创建额外 Sprite2D，使用 salt_glare.gdshader 每10秒绘制一轮白色覆盖。脚印是独立的 _draw 绘制路径。

删除额外反光精灵、遮罩构造及其 elapsed 计时。脚印生成、4秒寿命、绘制代码保持原样；地形、盐地50%/土路100%移动、地图、场景、存档和 ui_layer.gd 均未修改。原着色器文件保持原样，但生产节点不再引用它。

## 实际验证

命令均在本工作树执行，Godot 4.7.2，OpenGL Compatibility，隔离 APPDATA/LOCALAPPDATA。每次正式存档 JSON 哈希前后相同。

```powershell
./tools/tests/bug_b5_run.ps1 -Mode flow -OutputRoot output/bug_b5/red_final
./tools/tests/bug_b5_run.ps1 -Mode flow -OutputRoot output/bug_b5/green2
./tools/tests/bug_b5_run.ps1 -Mode import -OutputRoot output/bug_b5/import_verified
./tools/tests/bug_b5_run.ps1 -Mode smoke -OutputRoot output/bug_b5/smoke
```

red_final 使用基线生产脚本与最终测试用例，33项中仅两分辨率的蒙层断言失败；运行后已恢复修复脚本。green2 为同用例修复版，33/33通过。两种分辨率为1152×648与1280×720，真实场景每0.5秒采样，共21帧，覆盖完整10秒，修复后额外白色样本峰值均为0。角色、UI动画冻结避免像素比较误报，地面效果用真实0.5秒定时推进。此像素断言采样视口内部，非所有地图位置的穷举；生产代码已取消整个覆盖层。

- 实际玩家物理处理测量土路6.5、盐地3.25，回土路恢复6.5。
- 玩家盐地位移65像素生成脚印，推进3秒仍存在，再推进1.01秒全部消失，分别有截图。脚印年龄使用手动delta推进，未声称OS手动操作。
- 地图可打开并保留截图。
- 编辑器导入复验及主入口5帧启动：退出码0，无项目脚本或资源错误。

截图与报告均位于本工作树 output/bug_b5/：

- red_final/screenshots/cycle_08_1152x648.png：原蒙层。
- green2/screenshots/cycle_08_1152x648.png：修复同周期。
- green2/screenshots/footprints_created_1280x720.png：脚印生成。
- green2/screenshots/footprints_fading_1280x720.png：渐隐。
- green2/screenshots/footprints_expired_1280x720.png：消失。
- green2/screenshots/map_1280x720.png：地图。
- 各目录 report.json、summary.json、stdout.log、stderr.log 保留完整证据。

## 已披露的中间失败与边界

首次全新工作树导入先报缺少字体缓存；生成缓存后 import_verified 复验通过。首次测试起始怪物处于战斗导致传送被拒，依照既有测试清空夹具战斗后进入盐池。最初像素比较计入待机动画产生183/187个样本误报；冻结无关动画后，基线仍失败而修复版通过，未放宽像素阈值。

运行日志中的系统证书读取失败，以及编辑器向 Steam 安装目录写设置失败，单独记录在 summary.environment_errors，不是项目通过项。未关闭用户游戏、未使用正式存档、未推送或合入主工作区。

现有 salt_pool_flow.gd 的旧反光断言依赖已删除的 elapsed，语义已与本票要求冲突；按票据不改此文件。本票独立用例代替该旧反光验收，不声称旧整套脚本通过。

## 可复用知识及重审条件

已验证盐池蒙层与脚印为同节点下两个独立渲染路径，删除反光精灵不影响脚印。适用于当前 SaltGroundEffects 实现；若将来修改该节点、脚印寿命、地图比例或地形倍率，应重新运行本票用例。图形像素对照应冻结无关动画，并用同测试在基线证明红灯，避免把角色动画误判为地面变化。
