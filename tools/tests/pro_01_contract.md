# PRO-01：序章与第一章入口契约

本票从 `247051d4cdd6d5cef6434cf8405ac4cf506b3b46` 实现。正式入口为
`scenes/prologue.tscn`，正式餐厅仍为 `scenes/restaurant_map_2d.tscn`。
本票没有修改第一章步骤、经营事务、卡牌或迷宫。

## 玩家可见行为

- 新档自动播放序章。画面铺满游戏视口，非 16:9 比例保留黑边以避免拉伸。
- “跳过序章”复用 Sprout Lands 的 `SproutButton`；鼠标、Esc、空格、Enter
  与视频自然结束共用一次性退出入口。在任何异步等待前锁定转场权。
- 黑幕淡入 0.5 秒，视频音量同时降至零；全黑至少呈现一帧后切换餐厅，
  淡出 0.5 秒。转场层跨场景存活，销毁前消费当前帧的缓冲输入，随后销毁，
  不设置场景暂停或玩家锁。
- 餐厅由现有 `TutorialGuide` 启动教程。新档首句是芽芽“……你终于醒了。”。
  对白期间现有教程暂时锁定移动属于正常行为；退出教程后锁、镜头和遮罩恢复。
- 缺失视频或 8 秒无播放进度会输出中文诊断并进入餐厅。目标餐厅装载失败则
  显示诊断和可重试按钮，不记录序章完成。存档写入失败保留原状态，仍可进入餐厅。

## 存档不变量

`prologue_done` 只表示已成功离开序章。仅在餐厅场景成功入树后，复用
`SaveManager.save()` 的临时文件与原子替换机制提交；失败完整回滚内存。
重复完成无额外写盘。不修改 `chapter_1_done`、`tutorial_done`、订单、奖励或库存。

旧档缺少序章字段或字段类型损坏时，从已校验的第一章稳定状态推断：
`awakened`、客人登场、真实经营步骤、`ready_to_depart` 或 `chapter_1_done`
视为已看序章。默认状态和仅有 `tutorial_done` 的旧兼容档仍播放序章。
已有合法布尔值保留。迁移与既有机制一致：读档只补内存字段，下一次正常保存
才落盘，不在读档阶段写回，也不重置旧进度。

开发参数 `--replay-prologue` 启动整次进程的预览副本：序章与随后第一章都可操作，
正式 `data` 和 `save.json` 不因重播改变。取消教程后依旧保持副本，直到退出游戏。
此时界面提示“序章重播 · 本次游戏不保存进度”。正常启动不受影响。

正例：完成序章后第一章仍未完成；旧档带真实库存时直接恢复制作引导；预览
推进检查点后正式文件散列不变。反例：仅跳过序章就补发声望、迁移时清空库存、
结束重播教程后恢复写正式存档，均违反本契约。

## 素材与替换

仅纳入 `assets/video/prologue/prologue_opening_zh.ogv`，165078246 字节。
第一版 SHA-256（文件指纹）：
`A16E800330CF73E704A91A7B6414176C4E14D4F4DF2655F6C1639BD10669F3FF`。
`.gitattributes` 只为该文件设置 Git LFS（大文件存储）规则；Git 索引应是
包含 `oid sha256:a16e800330cf73e704a91a7b6414176c4e14d4f4df2655f6c1639bd10669f3ff`
与 `size 165078246` 的指针。没有复制帧图，也没有重新编码视频。
未来可原位替换，但必须重新运行实际播放、自然结束与转场验收，并更新素材指纹。

## 可复现验收

```powershell
# 自动创建临时 APPDATA / LOCALAPPDATA，验证真实存档前后指纹。
& tools/tests/pro_01_run_isolated.ps1 -Import
& tools/tests/pro_01_run_isolated.ps1 -Visual
& tools/tests/ch1_life_pre_run_isolated.ps1
git diff --check
```

runner（验收启动脚本）要求 Godot 4.7.2。无头模式只验证迁移、原子提交、
编辑器解析和主入口冒烟；实际鼠标与播放必须使用 `-Visual`。
自然播放不用快进、跳转或伪造结束信号；内部等待上限 330 秒，外层进程上限
360 秒，超时仅停止该验收进程并保存失败摘要。竞态用例单独投递 `finished`
与跳过输入，不能替代完整自然播放。其余单进程上限 120 秒。

每次输出包括 JSON 检查报告、stdout/stderr（标准输出/错误日志）、真实渲染
PNG（播放画面、全黑转场、餐厅首句）和真实存档前后 SHA-256。
报告默认存于临时目录，也可用 `-OutputDir` 指定外部目录。

## 2026-09-23 本票验收证据

外部证据根目录：`C:/Users/KSG/AppData/Local/Temp/maze_pro_01_validation/`。

| 目录 | 实际结果 |
| --- | --- |
| `state-final` | editor-parse、runtime-smoke、迁移 67 项、原子提交 8 项通过 |
| `visual-final` | 鼠标、Esc、空格、Enter、竞态、旧档、缺资源、停滞、保存失败、重播全部通过 |
| `natural` | Vulkan 实际播放约 241.96 秒，1 次 finished、1 次转场、1 次餐厅进入，19 项通过 |
| `manual` | 可见窗口实际按钮退出，18 项通过；作为补充记录 |
| `race-final`、`race-fixed` | 持续按键曾复现淡出末帧输入泄漏；销毁前消费缓冲事件后同一场景通过 |
| `lifecycle` | 真实经营、8 种稳定阶段恢复、损坏存档、教程重播、保存失败及主入口冒烟共 13 模式通过 |
| `entry`、`entry-baseline` | 既有 CH1-02 均为 41 项中同一项失败，见下文 |

实际截图：`visual-final/mouse-playing.png`、`visual-final/mouse-black.png`、
`visual-final/mouse-restaurant.png`；自然结束证据另见 `natural/natural-restaurant.png`。
最终修复后完整复验目录为 `release-visual` 与 `release-lifecycle`，交付优先使用
其中的报告和截图。Windows 窗口捕获接口两次返回
`SetIsBorderRequired failed: 不支持此接口 (0x80004002)`；截图通过运行中的
Vulkan 视口帧缓冲取得，未使用无头渲染替代可见验收。
所有正式验收前后真实存档指纹均为
`2C8D97E3925231A102A33588E3128C9292955844FB1EDCD2DB5A57C97B7E77DC`。

CH1-02 的 `exit_reentry_starts_one_clean_flow` 仍要求苏醒检查点后重进回到
阶段 1，与当前持久化恢复行为冲突。只把 `SaveManager` 换回冻结基线，其他
输入与夹具保持一致，实际复现同一失败，之后立即恢复本票文件。相关教程和
夹具文件均未修改。当前 `CH1-LIFE-PRE` 的恢复验收全部通过。因此结论是
本票入口与生命周期通过，旧 CH1-02 套件尚有一个既有过时断言，不能宣称全库全绿。

开发中夹具还曾把 JSON 的整数与浮点读回差异误判为状态变化，以及把首句
教程合法的输入锁误判为残留；已修正比较方式和锁所有权断言。无头鼠标投递
不可作为可见界面验收，runner 已限制该模式。上述失败原始日志保留在外部证据中。

增强的持续重复输入实验曾发现真实问题：淡出末帧按键留在输入缓冲中，遮罩
释放后误推进首句。只新增销毁前的 `Input.flush_buffered_events()`，让现有
转场输入拦截器消费缓冲事件，同一可见场景随即通过；最终可见套件再次复验。

## 知识交接与边界

已验证：序章入口跨场景遮罩应独立于教程生命周期；完成状态在目标成功入树后
才提交；预览保护应覆盖整个进程，否则教程取消会重新暴露正式保存入口。
这些结论适用于当前 SaveManager / TutorialManager 接口。修改原子保存、教程
重播结束行为、主场景、视频编码或升级 Godot 时重新审查并重跑上述验收。

未验证：导出发行包、其他操作系统和其他 GPU；未单独录制音频。实际 Vulkan
播放进度与渲染画面已验证，音轨使用 VideoStreamPlayer 默认 Master 总线。
没有推送远程；后续集成/发布需要可取得 Git LFS 对象。
