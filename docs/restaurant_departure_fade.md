# 普通经营统一渐隐离场

2026-11-05，已直接接入 F:/maze_code。仅增量修改 customer_flow 的经营演出；第一章铁山、奖励、处罚和菜单账务保持原实现。

## 原因与修正

旧 leaving 分支只有 cycle 且 outcome=served 渐隐；其余分支使用 exit_path 向右移动，旧档无 outcome 同样进入旧路径。所有经营离场现统一保留原反馈后，原地切站姿并渐隐0.35秒，再保存 departed 并释放座位。候客、等水、等菜超时和错菜先显示原2.2秒表情气泡。主动结束/时间到直接渐隐。接单继续前台渐隐后座位渐显。离场保存失败保留透明状态，仅重试事务；不重新显现、重复反馈或重复奖惩。进食每帧等待后校验eating阶段，避免打烊后旧回调继续切帧。

## 主目录验证

统一运行 tools/tests/restaurant_service_cycle_run.ps1 -Scene <场景> -OutputRoot <目录>，使用隔离存档及真实Godot窗口。

| 场景 | 输出 | 结果 |
| --- | --- | --- |
| restaurant_departure_fade.tscn | output/departure_fade_verified | 390项通过 |
| restaurant_departure_interrupt.tscn | output/departure_fade_interrupt | 42项通过 |
| restaurant_rest05b.tscn | output/departure_fade_business_regression | 645项通过 |

最终三轮正式存档均不变、无意外引擎错误，仅系统证书环境警告。双尺寸1152×648与1280×720覆盖正常用餐、错菜、三种超时、主动结束、时间到、旧订单迁移、离场读档与保存失败、前台/座位渐隐渐显及铁山。中断专项覆盖进食和换座过程中打烊。已查看错菜反馈/渐隐/消失截图。

历史证据保留：departure_fade_before 因夹具继承了迷宫Catalog同名常量无法解析而超时，改独立Guests别名；departure_fade_baseline重现异常右移，但夹具busy也阻止了正常farewell推进，不将这组正常餐后失败作为生产证据；departure_fade_final仅旧档夹具未先执行迁移的4项失败，补生产迁移后verified全过。早期正式存档变化未回写，最后三轮指纹均稳定。

## 复用边界

离场只做显示和持久阶段推进；份额、罚款和奖励已由业务事务结清。保存失败不得通过重置alpha重演离场。新增顾客状态、异步演出或保存重试时，应复验原地位置、透明度中间值、终态移除及旧异步回调失效。
