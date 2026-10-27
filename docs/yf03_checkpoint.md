# YF-03 历史未验证检查点

本文件记录2026-10-25历史暂停点。2026-10-26恢复后的实际结果见 [YF-03赠礼与便当](yf03_bento.md)，下文的未运行状态仅适用于旧检查点。

历史状态：未完成，禁止合入主目录。已写实现和测试脚本，但资源导入阻断，未通过脚本编译、功能、视觉或集成验收。此文不是完成交接，也不将下述设计当作已验证稳定知识。

## 基线与边界

- 来源任务 `01a16d55-4249-74d2-a4d9-cc656154f30d`，本任务 `01a17128-cb4a-7091-be62-0dbdd2eb8c3d`，hostId=`local`。
- 项目 `7c3963e8-2c05-4bd9-9992-d9dc706e8cf4`，来源确认显式项目创建成功，`project_binding_verified=true`。
- 工作树 `C:/Users/KSG/.codex/worktrees/8f71/maze_code`，分支 `codex/yf-03`。
- 原基线 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`，冻结生产快照 `ad458f31987ad42ea321b47afcdfffca8ba6248e`。2773项源前后及目标SHA-256一致，清单为 `output/yf03/snapshot.json`。
- 原快照 `688e1fc` 漏暂存主目录已有的两个根文件删除 `render_yaya_cards.ps1/.py`；仅暂存两处删除后修订快照，未暂存实现。最终实现增量不含二者。
- 主目录未写入、未提交、未合入。只允许主会话在本票验收后增量合入，禁止合入整个快照。
- 主会话补充授权 `combat_simulation.gd` 生命扣减一处 `maxi` 改 `maxf`，以及食谱页隐藏探索料理未确认金币的最小显示兼容。

## 已写但未验证的行为

`bento_store.gd`（便当事务）将三份三星料理、三道配方及 `gift_reward`（待展示奖励）一起提交；保存失败恢复完整内存。永久 `bento_v1`（便当状态）存放赠礼凭证、入口资格及五维格子，旧档缺字段只读为空，坏字段拒绝操作。不存在待领取库存，也不写背包或冰柜。

演出沿用版本2事件记录，新增 `gift_reward`、`bento_unlock`（解锁蒙层）、`bento_fly`（飞入）、`farewell`（告别第0/1句）、`fade`（渐隐）。解锁蒙层进入场景后才保存入口资格；飞入完成再保存告别，渐隐结束再保存done。领奖阶段缺少真实凭证/料理/食谱会锁住并显示异常提示，不补发、不假展示、不前进。严格使用已确认两句告别。

食用由同一事务同时标记已食用和写入本趟 `run.bento`（探索效果）。攻击直接进入团队总攻击，防御进入实际伤害扣减。回血保存累计已付量与经过的有效秒数，保留小数生命；接在原有普通/安静区域战斗推进后，开始食用禁止战斗，已吃后的恢复在战斗继续，暂停/弹窗/离线不推进。结束探索清理已食格和加成，未食用保留。后票装配不得重新占用本趟已食格或重叠已存在维度效果。

入口与背包同64像素按钮、56像素图标，位于迷宫背包右侧及餐厅菜谱右侧。便当页复用主题、通用确认、奖励蒙层及飞入动画；五格上三下二，详情有料理图、名字、星级、实际效果和常显滚动条。已食用使用绘制空盘并保留名字效果。餐厅只查看/丢弃；装配由BENTO-01继续。食谱页探索分类不显示未确认售价。银鳞鱼肉材料目录无图片，缺图未拿成品冒充。批准源素材仅复制到 `assets/ui/bento`，未修改源图。

## 实际执行及阻断证据

已执行：初始Git核验、分支创建、快照复制哈希检查、隔离快照本地提交、`git diff --check`。首次分支创建因共享Git元数据在F盘权限失败，沙箱提权后成功；不是业务失败。初始 `python` 不在PATH，改用内置Python绝对路径后复制成功。

资源导入同失败族共三次，均未通过，正式存档指纹三次不变：

1. `tools/tests/yf03_run.ps1 -Mode import -EvidenceRoot output/yf03/first`，当时使用 `--headless --editor --quit`。
2. 同命令，EvidenceRoot为 `output/yf03/compiled`。
3. `tools/tests/yf03_run.ps1 -Mode import -EvidenceRoot output/yf03/import_wait`，改用 `--headless --import`。

三处各有 `import/summary.json`、stdout/stderr、正式存档前后指纹。编辑器扫描完成但 `.godot/imported` 文件数为0，报字体和封面缓存不存在；日志同时出现 `Blender path is invalid or not set`。项目已有 `assets/models/restaurant/restaurant.blend`，隔离APPDATA缺少Blender路径。系统证书告警另列，不能掩盖资源错误。尚无功能报告或实景截图。

来源已提供且本任务已用Test-Path核实本机路径：`F:/Blender Foundation/Blender 5.2/blender.exe`。只准备了隔离 `output/yf03/blender_ready/import/profile/Godot/editor_settings-4.7.tres`，内容为EditorSettings资源及 `filesystem/import/blender/blender_path` 单项；没有修改生产project.godot，也没有启动第四次导入。

## 同一任务恢复步骤

须先取得来源转达的“允许额外一次单变量导入”确认。预算按已消耗主动时间接续，不重新宣称完整90分钟预算。

```powershell
& tools/tests/yf03_run.ps1 -Mode import -EvidenceRoot output/yf03/blender_ready
```

该额外实验只改变隔离编辑器的Blender路径。若仍失败，保存证据回报，不继续无授权重试。若成功，先修正首次编译暴露的问题并遵守同失败族上限，然后依次运行：

```powershell
& tools/tests/yf03_run.ps1 -Mode flow -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode edges -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode seed -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode restore -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode sparring -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode regression -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode skills -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode backpack -EvidenceRoot output/yf03/verified
& tools/tests/yf03_run.ps1 -Mode smoke -EvidenceRoot output/yf03/verified
```

运行器复制引擎避免Steam自包含目录，APPDATA隔离、正式档指纹比对，单进程240秒超时。上述全未运行；测试脚本本身也未编译。实际可视测试后还须目检1152×648与1280×720奖励、解锁飞入、两句告别、渐隐、五格已食前后及餐厅页，修正布局和输入问题，完善测试中发现的遗漏。已有YF02原flow以gift_pending结束的断言不再适用，本票 `yf03_sparring` 保留完整真实左键切磋，只改末端为gift_reward与接续锁，不改既有测试文件。

仍须补验：真实鼠标单份/全部食用与丢弃确认取消；奖励、解锁、飞入、两句对白、渐隐各保存失败恢复；实际战斗中回血、切图、20秒结束及上限；坏档提示和未发奖；白虎及背包回归。测试目前部分使用信号和组件方法驱动，不能冒充全部真实鼠标验收。禁止以静态阅读或现有脚本数量声称完成。

完成运行验证后再更新本说明和组件库为实际结果，重新生成最终提交、二进制补丁及文件清单，停止写入并主动通知来源主会话。当前仅为未验证检查点，不形成新的已验证跨会话知识。
