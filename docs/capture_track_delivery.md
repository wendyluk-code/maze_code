# 捕获节点切图接入（2026-10-19）

已接入目标工作区 `F:\maze_code`。基线 HEAD 为 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`，保留已有未提交改动，无提交或远端推送。

四个节点、绿色绳结完成边框及编织绳来自确认稿切图，位于 `assets/ui/capture/track/`。原稿保存在 `output/capture_icon_design/track_approved.png`；`tools/slice_capture_track.ps1` 可重复裁切。复用 `capture_visuals.gd` 的 Track 组件和原弹窗，内部图标和两种边框分别为透明素材，完成时只替换边框，不叠加未完成边框；当前节点整框轻微呼吸缩放，连接绳按原比例重复铺设。

更新规则：绿色进度到达节点即换绿框，阈值依次为0、1/3、2/3、1，不等待阶段结束。完成边框不代表随机捕获结果，最终结果仍由原结算流程处理。修改阶段映射或图标布局后需重新验收。

验收：`pwsh -NoProfile -File tools/tests/capture_attempt_run.ps1 -Mode flow -OutputRoot output/capture_track_final`，185项、0失败；覆盖1152×648与1280×720、四种魔物、四阶段边框、真实J输入、成功/超时、扣费防重、保存重试及读档。各阶段截图已人工检查，见该目录下 screenshots。正式存档指纹未改变。

启动检查：同脚本 `-Mode smoke -OutputRoot output/capture_track_smoke` 通过。环境仍报告系统证书读取失败；导入检查另有安装目录编辑器设置写入警告，无游戏脚本或资源错误。

首次集成发现纹理区域绘制参数顺序错误，已修正并复验通过；截图发现绳索拉伸过细，已改为按比例铺设，最终185项验收对应调整后的代码。

## 边框分层修正
四个内部 icon、pending_frame.png 与 completed_frame.png 已独立裁切。每次绘制仅选择一张边框，完成状态替换未完成状态；奶油底填充独立绘制。镇压角色的内部奶油色使用连通背景剔除保留。最终复验：output/capture_frame_layers_verified，185项通过、0失败，双分辨率状态截图已检查，正式存档未改变；仅既有系统证书环境警告。
