# START-02 存档管理交付

状态：**用户已确认手动验收完成，并授权合并**（2026-09-28）。执行任务报告自动化检查 260 项 / 0 失败；下文保留交付时的捕获阻断历史。手动验收依据为用户明确反馈，不声称代理完成了操作系统输入验收，也不补写用户未提供的逐项结果。

工作目录：`C:\Users\KSG\.codex\worktrees\77ae\maze_code`。
分支：`codex/start-02-save-management-exec`。
基线及当前 HEAD：`ef3a772ea80b2130f661b1ed654125b52792360a`（`master`）。启动时为干净的分离头指针，随后创建独占分支。`core.longpaths=true`。没有提交、推送或合并；提交哈希：无。

## 行为与修改范围

- `scripts/save_manager.gd`：新增 `rename_save_slot`（重命名存档）、`delete_save_slot`（删除存档），共用路径校验。重命名读取原 JSON，只修改名称元数据，复用原子替换；成功后才同步活动档名称。坏档拒绝重命名，仍保留诊断条目。删除成功后若为活动档，清空活动路径并禁止自动保存复活；没有自动选择其他档。
- `scripts/ui/save_selection_modal.gd`：选择后可重命名或删除；编辑、确认、取消在同一遮罩内完成。删除默认焦点为取消。Esc、取消按钮及关闭按钮均有取消路径。错误保留弹窗及所选档案。
- `scripts/start_screen.gd`：进入存档管理时清除转场失败后的“已准备新游戏”缓存，防止管理删除之后继续使用旧缓存。
- 新增 `tools/tests/start_02*`、本文和 `output/start_02/`。未修改场景、餐厅、教程、经营事务或正式用户存档。Godot 导入造成的范围外 `.import` / `.uid` 已恢复或移除。

## 证据链

1. 基线列表只有选择和载入，无管理入口；新增管理 API 与弹窗状态。真实存档文件测试证明名称持久化、内容和路径保持一致，重复操作不产生额外写入或删除。
2. 以同名 `.tmp` 目录阻止原子写入，以外部 `FileShare.None` 独占文件锁阻止读取/删除。实际操作返回失败，原档字节、内存数据、活动路径保持一致。
3. 首轮界面事件测试发现 LineEdit 消费 Esc，取消未回列表。把 Esc 处理提前到弹窗 `_input`；随后发现测试在容器完成帧末布局前定位按钮，改为等待 150ms 再定位。两个分辨率最终均 23 项、0 失败。
4. 初次 START-01 回归因工作树中的视频是 LFS 指针报“no video stream”。执行 `git lfs checkout assets/video/prologue/prologue_opening_zh.ogv` 恢复基线对象后通过。序章重播原 runner 在无头模式不能完成其鼠标退出路径；本票新增 runner 对该用例启用真实渲染器后 22 项通过，未改生产序章或原测试。

## 实际命令与结果

以下命令均在本工作树运行，Godot 为 `F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`，版本输出为 4.7.2。

| 命令 | 结果与产物 |
| --- | --- |
| `git status --short --branch`、`git rev-parse HEAD` | 启动干净，HEAD 等于冻结提交 |
| `./tools/tests/start_02_run.ps1` | 状态 23 项 / 0 失败；新进程及文件锁 7 项 / 0 失败；同时执行编辑器检查、默认入口启动 |
| `./tools/tests/start_02_ui_run.ps1 -Modes visual-manage-1152,visual-manage-1280` | 1152×648 与 1280×720 各 23 项 / 0 失败；输入投递至 Viewport（视口），不是操作系统真实鼠标键盘 |
| `./tools/tests/start_02_regression.ps1 -Modes state,restart,visual-new-1152,visual-continue-1280,prologue-migration,prologue-atomic,prologue-old,prologue-replay,lifecycle` | 首轮重播受无头模式限制，已记录原因；其前面的用例通过 |
| `./tools/tests/start_02_regression.ps1 -Modes prologue-replay,lifecycle` | 调整本票 runner 渲染方式后，重播 22 / 0、生命周期 16 / 0 |
| `git diff --check` | 通过 |

START-01 及扩展回归最终报告：state 22、restart 3、visual-new-1152 19、visual-continue-1280 16、prologue-migration 67、prologue-atomic 8、prologue-old 11、prologue-replay 22、lifecycle 16，合计 **184 项 / 0 失败**。其中场景输入属于既有 Viewport 测试。

日志及 JSON：`output/start_02/state.json`、`restart.json`、`editor.*.log`、`smoke.*.log`；UI 为 `output/start_02/ui/`，回归为 `output/start_02/regression/`。`latest-run.json` 只列最后一次 runner 调用，以各用例 JSON 为完整计数依据。所有测试隔离 APPDATA、LOCALAPPDATA，并核验 `user://` 位于隔离目录。

代表截图：

- `output/start_02/ui/visual-manage-1152-renamed.png`
- `output/start_02/ui/visual-manage-1280-delete-confirmation.png`
- `output/start_02/ui/visual-manage-1152-broken-rename.png`
- `output/start_02/ui/visual-manage-1280-write-failed.png`

## 交付时未运行验收与风险（历史记录）

真实 Windows 界面已由隔离 GUI runner 启动并枚举到唯一标题，但 computer-use 的首次截图返回 `FrameArrived timed out: timed out waiting on channel`，刷新窗口并激活后的恢复截图返回 `window capture timed out: timed out waiting on channel`。按技能恢复限制停止继续输入。GUI 测试进程已停止。

因此尚未完成两个分辨率下的操作系统真实鼠标/键盘选择、编辑、确认、取消、删除及重启后可见列表检查。下一步：恢复 Windows 捕获能力后运行 `./tools/tests/start_02_run.ps1 -Gui -Resolution 1152x648 -Label 1152`，完成操作并关闭，再以 `1280x720` 和 `1280` 启动同一隔离目录验证重启；该 runner 为每次实际释放输入保存截图和状态 JSON。不要改用正式用户数据。

仅测试单进程管理；不承诺多个游戏进程同时修改同一存档时的并发控制。名称限制为去除首尾空白后的 1–40 字，禁止换行和制表符；重命名不改变文件路径。坏档可删除，但不能在无法解析内容时重命名。重复删除报告不存在并保持状态。

## 调用方与稳定知识

已检索所有脚本中的 SaveManager 调用。存档选择/创建仅由开始界面调用；新增管理仅由存档弹窗调用。现有餐厅、序章、教程、出发面板、仓库面板的事务方法签名保持不变；`save()` 在成功删除活动档后明确失败，直到显式新建或载入。生命周期、迁移和重播回归覆盖这一兼容边界。

本环境未提供知识交接技能。可复用且已验证的知识：管理名称应改元数据而不是文件路径；删除活动档必须阻止自动保存复活；LineEdit 内的 Esc 需在 GUI 消费之前处理；Container 重新显示后的测试输入需等待布局完成。适用边界为本项目单进程 Godot 4.7.2；更换引擎、存档格式、并发模型或弹窗组件时重新审查。


## 用户验收与合并接收

2026-09-28，来源会话用户明确表示“我手动验收完了，合并代码把”，授权将当前 START-02 检查点合入 master。以用户手动验收替代此前未完成的代理操作系统输入补验；自动化证据与代理能力限制分别保留，不混淆证据来源。

合并仅接收本票三个生产文件、新增验收脚本、本文及相关报告。不接收隔离存档、进程标识、导入副作用或主工作区未提交改动；不推送远端。合并后的准确提交与主工作区保护检查结果由来源会话报告。
