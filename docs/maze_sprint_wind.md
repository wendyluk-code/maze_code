# 迷宫加速风线修复（2026-11-05）

目标 F:/maze_code；分支 master，HEAD 1f426fbb12829fac854fe612694609d9a4b80f15。保留当前用户改动，尤其 maze_player.gd 中已有角色移动音频接入。

根因：餐厅 player_map.gd 已挂载 sprint_wind.gd，迷宫此前只调整步频和倾斜，没有风线节点。

修正：迷宫挂载同一 SprintWind 组件。组件新增可选 active_provider（实际加速状态回调），迷宫读取 sprinting 与战斗暂停状态；默认仍沿用餐厅的Shift判断。迷宫风线按0.85/相机缩放适配，与人物显示比例一致。实际位移检测、四条淡色风线、淡入淡出均复用餐厅实现。未修改速度、体力、音频或餐厅输入规则。

验收：
- tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/maze_sprint_wind.tscn -OutputRoot output/maze_sprint_wind_20261105
  双分辨率33项通过，无项目错误。覆盖普通行走、真实Shift移动风线、比例、松键、停步、体力耗尽、输入锁。截图已目检：maze_shift_wind_1280x720.png。
- tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/restaurant_sprint.tscn -OutputRoot output/restaurant_sprint_wind_20261105
  135项功能检查通过，但退出有6个ObjectDB实例及3个资源未释放，运行器因此判失败；未证明该退出问题与基线是否一致，不宣称完整餐厅回归通过。另有Unicode NUL诊断。
- 两轮正式存档指纹均未变化；系统根证书读取失败单列为环境告警。

本次迷宫功能已通过相关实际场景验收。餐厅退出资源清理问题仍保留在上述日志，未扩大范围修复。
复用知识：有体力限制的加速视觉必须读取实际加速状态，不能只检查Shift，否则耗尽后仍会显示；共用绘制组件需按角色镜头比例适配。
