# REST-3执行交付记录

## 状态与基线

执行范围实现已提交为独立候选；目标工作区 `F:\maze_code` 的合入与集成验收由来源主会话继续，整体任务未完成。本执行任务未向主工作区写入、未推送。

工作目录：`C:\Users\KSG\.codex\worktrees\0923\maze_code`。
独占分支：`codex/restaurant-three-seat-service`。
来源起点：`1f426fbb12829fac854fe612694609d9a4b80f15`。
本地快照基线：`036aed31566ebbab4cfd46e44db816b34a0cf3df`。

基线得到主会话明确授权：仅记录复制来的源码、素材和既有测试，排除本地引擎、缓存、输出。起始状态证据为 `output/rest3/start-status.txt`、`start-head.txt`、`start-untracked.txt`。只交付基线之后的提交，不能合入整个基线或整文件覆盖主区脏改动。

## 本票增量

恢复原三座与前台，保留地图和其他道具尺寸位置。前台近距离E接单再落座，满三座不刷新，前台最多一位。候客40秒、等水40秒、料理100秒、间隔12秒；行走不扣耐心，最后20%才预警。六种反馈使用现有表情、原瞳孔及头发动效，2.2秒后可见路径离场；出门并保存成功才释放座位。误上水和不达标水继续料理，奖惩及物品按确认规则原子保存。

保留甘露水最新3秒加冰、超过8秒损坏、取出暂停规则。原 `scripts/ui_layer.gd`（界面距离提示）没有修改。未触碰迷宫、角色成长、插件、导入资源和主地图素材。

旧六座兼容经主会话确认：前三位映射三座，多余最多三位保存在旧档已接单待入座记录；暂停耐心，腾座后恢复原阶段。迁移不改ID、奖励、扣罚，不把未接单客提前接单。读档与保存失败测试覆盖等待、进食、已扣罚离场及三座加前台客混合情况。

原 `chapter_layout.gd` 使用标量数组构建二维向量数组，实际得到全零轮廓。最小引擎实验见 `output/rest3/probe.gd`；本票改为显式 `Vector2`（二维向量），并验证原吧台上菜站位。该修复也恢复第一章原交互轮廓。

## 验收证据

所有经营测试均由 `tools/tests/restaurant_service_cycle_run.ps1` 指定本工作树与独立用户目录启动。未使用旧六座/旧冰度断言判定本票。

| 命令或模式 | 证据目录 | 实际结果 |
| --- | --- | --- |
| `-Scene res://tools/tests/restaurant_three_seat.tscn` | `output/rest3/final` | 500项通过，含事务、双分辨率三座、全部反馈离场、迁移与铁山；正式档指纹一致。此轮先于反馈文字避让补丁，该补丁另有下列专项。 |
| 同场景 `-Mode service` | `output/rest3/service1` | 30项通过；实际菜单、前台E、倒水、冰镇、仓库取料、烹饪、指定上菜、离场与提前打烊；正式档指纹一致。 |
| 同场景 `-Mode clock` | `output/rest3/clock1` | 14项通过；真实十秒与40秒候客计时、一次扣罚；正式档指纹一致。 |
| 同场景 `-Mode migration` | `output/rest3/migration_mixed` | 最终46项通过；六座迁移、暂停耐心、保存失败、重载、进食/离场恢复及保留未接单客；正式档指纹一致。 |
| 同场景 `-Mode feedback` | `output/rest3/feedback_verified` | 213项功能检查通过，无非预期脚本错误；1152×648、1280×720文字无遮挡及实际六反馈路径。但正式档指纹变化，运行器因此标失败。 |
| `tools/tests/tutorial_checkpoint_run.ps1 -OutputRoot output/rest3/chapter1_verified` | 同左目录 | 31项功能检查通过，无脚本错误；新档可见对白、移动、前台E、保存失败检查点、首单及收尾恢复。但正式档指纹变化，运行器标失败。 |
| 上一命令加 `-Resume` | 同左 `resume-*` | 独立进程续档5项通过，正式档指纹一致。 |
| `tools/tests/npc_01_run.ps1 -Mode editor -SkipBlenderFor2D` | `output/npc_01/editor1280.log` | 编辑器检查通过。临时禁用Blender导入后恢复 `project.godot`，SHA256一致，正式档指纹一致。 |
| `tools/tests/npc_01_run.ps1 -Mode startup` | `output/npc_01/startup1280.log` | 无头启动通过，配置及正式档指纹一致。 |

引擎为启动前确认存在的 `F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，实际版本4.7.2。成功日志中的系统证书读取警告单独列为环境问题。

已查看三座、前台接单、六状态反馈与离场截图。最新前台避让：`output/rest3/feedback_verified/front_timeout_feedback_1152x648.png` 和1280×720同名后缀；其余状态在相同目录。完整服务截图在 `service1`，首章在 `chapter1_verified`。

历史失败保留：`run1` 的元数据缺失、等待夹具未限帧、零向量吧台轮廓已修正；首次导入缺少字体缓存，导入完成后编辑器通过。`feedback_final` 的测试节点接口错误、`feedback_final2` 的局部类型推断错误已修正，最后反馈专项功能全过。`migration1` 用JSON字符串比较而受字段顺序影响，改为JSON值比较后复验通过。不得将历史失败日志删除或写成首轮通过。

## 限制与主会话下一步

1. 多个测试窗口检测到正式存档指纹变化；不推断变化来源，没有回写正式档。`run1`、`feedback_final`、`feedback_final2`、`feedback_verified`、`chapter1`、`chapter1_verified`均保留各自结果。主会话已知另有活动任务，仍须在目标集成时处理该保护项，不能声称所有存档保护门禁已通过。
2. 人物复用现有站姿沿路径移动，未新增完整侧身/走路逐帧素材。
3. 未在主目录进行集成；主会话须审查相对 `036aed3` 的增量，保留并发用户改动，合入后运行上述相关场景。

## 可复用知识

Godot脚本中的 `PackedVector2Array([数字,数字,...])` 不等于场景文本中的扁平坐标写法；运行时数组元素必须为 `Vector2`，否则该项目引擎实测变为全零。更改交互多边形时同时核验实际非零坐标、合法站位与真实E目标。引擎版本或构造接口变化时重新验证，不将此处实测外推到所有序列化格式。

## 主工作区集成验收（2026-11-04）

已将036aed3..5e7fb1c及5e7fb1c..09be348的本票增量合入F:/maze_code，未合入快照基线。场景保留主区最新unique_id、冰柜可编辑布局与道具调整，仅替换行走脚本、隐藏六座覆盖、恢复三个座位锚点；组件库文档采用增量追加保留并发内容。

主区实际运行：restaurant_three_seat默认531项全过（output/rest3_main_final）；service完整流程40项全过（output/rest3_main_service_verified），包含最新余水落完、结果翻入可点击、公共冰镇E提示；第一章31项与跨进程Resume5项全过（output/rest3_main_chapter）。以上主区运行正式存档前后指纹一致。查看实际等水超时反馈截图，原三座、独立前台与用户最新冰柜布局同屏正常。主区首轮service5项失败源于夹具过早点击新版倒水结果，原任务增量修正为实际状态等待后全过，历史日志output/rest3_main_service保留。独立工作树阶段若干正式存档指纹变化的来源仍未确认，不回写、不抹除记录。

最终边界：人物沿路径移动使用现有素材，尚无新增完整行走逐帧动画。没有推送远端。
