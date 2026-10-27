# MAP-01 主区失败计数兼容修正

主区在冻结基线后新增了按种类累计捕获失败次数的功能。`resolve` 用 `Catalog.TYPES` 重建计数字典，只包含首区四种；鱼鳗失败时访问缺键，首区随后结算还会丢失已有鱼鳗计数。来源主任务集成重启验收出现 `silverfish` 缺键及两项失败；在本工作树隔离副本完整复现。

新增 `Catalog.capture_kinds()` 返回已接入的六种普通怪，独立于当前到访地图。主区只需将 `resolve` 内 `for kind in Catalog.TYPES` 替换为 `for kind in Catalog.capture_kinds()`。准确单行补丁为 `tools/tests/map01_main_compat.patch`，已对主区只读 `git apply --check`。本分支没有主区新增计数实现，故不复制整份生产脚本；集成时必须同时应用目录函数与该单行补丁。

沿用用户当前契约：每种三次失败后下一次保底成功，仍支付一次饱腹；普通成功清自身计数，其他种类保留；放弃不计次，保存失败回滚。MAP-01原文“没有隐藏成功保底”仅指首次捕获无无条件保底，不否定后来新增的累计失败保底。

审查了生产代码全部 `PITY_KEY`、`failure_streak`、`Catalog.TYPES` 使用点，计数写入口仅此处；其余 `Catalog.TYPES` 遍历为旧测试枚举，不修改首区生成和物件避让。

隔离副本位于 `output/map01_revision`，包含主区当前脚本只读快照、相同红灯和单行修正后的绿灯：重启seed24项、restore10项通过；六种计数专项212项通过，包含跨趟读档、两种失败、第四次保底、扣费、保存失败回滚、重复结算和首区结算不丢区域计数。所有运行正式档指纹不变，仅证书环境告警。没有修改主区文件或发布。

主区增量集成后运行 `tools/tests/map01_pity_compat.tscn`，沿用 `combat_02_run.ps1 -Mode flow` 的显式隔离路径；清除测试环境 `MAP01_COMPAT_RUN` 后默认调用主区正式服务。在此原工作树复验时该环境变量指向 `res://output/map01_revision/compat_run.gd`。然后复跑原 `map01_restart.tscn` 两进程验收。新增区域种类时须同步统一列表并验证跨区域计数不丢失。
