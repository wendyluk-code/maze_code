# SKILL-01 交付记录

- 状态：执行任务已停止写入。主会话完成内容审查，将最终差异合入 `F:\maze_code\skills\restaurant-order`，并安装到 `C:\Users\KSG\.codex\skills\restaurant-order`。安装文件与主目录源文件SHA256一致；源文本与执行任务已校验版本一致，仅Git换行转换不同。
- 工作目录：`C:\Users\KSG\.codex\worktrees\a9f6\maze_code`
- 基线：`a600570f586a33549508cf636a00d6a5775c13af`；独占分支 `codex/restaurant-order-skill`；最终交付提交 `1a94fafe0af690b8f82746956d199985ee0030c7`。初次共享Git引用权限失败已通过正式提权解决。
- 文件：`skills/restaurant-order/SKILL.md`、`skills/restaurant-order/references/current-implementation.md`、`skills/restaurant-order/agents/openai.yaml`、本文件。
- 输入清单：角色/素材来源与显示名；料理；触发与循环；对白偏好；新菜配方、奖励与任务决定。工程参数由代理读取适配。
- 流程摘要：盘点基线→素材边界→真实订单闭环→配置轮转风险→按需任务登记→复用 UI 与双分辨率/读档/重复交付/失败回滚验收。
- 案例推演：男01/女05/绿发男08替换只需角色身份、素材、对白决定，不新增配方；新增点单需补齐缺失的料理、奖励和出现规则，轮转与持久化技术方案由代理核验。以上为桌面推演，未实际新增顾客或新配方。
- 校验：使用隔离临时目录安装 PyYAML，并设置 PYTHONUTF8=1 运行 quick_validate.py，结果 `Skill is valid!`。
- 已知限制：本票据未修改游戏代码，未运行 Godot 场景；NPC-01 的真实场景证据属于前置知识，不是本技能新案例的实跑证据。
