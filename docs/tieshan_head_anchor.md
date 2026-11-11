# 铁山首单气泡定位（2026-11-05）

目标 F:/maze_code；master，HEAD 1f426fbb12829fac854fe612694609d9a4b80f15。使用restaurant-order技能，仅修正既有铁山首单气泡，不更改订单、料理、任务或存档契约。保留工作区已有用户改动。

复现：旧fit_to_viewport在铁山移出镜头上方后仍把整个气泡向下推到屏幕上沿；尖角不再指向人物。定位复现两分辨率中锚点及出画检查失败。另发现未导入的cooking_stove.ogg导致场景脚本加载报错，隔离编辑器导入后消失。

修正：
- guest_placeholder.gd按当前AnimatedSprite2D的可见头部上段、翻转、偏移及坐标变换定位。
- tieshan_order_bubble.gd固定尖角锚点；出画隐藏绘制，顶端不足时仅移动主体并绘制连接头顶的侧尖角，E图标随主体。
- 旧交互测试同步使用主体偏移计算E的实际绘制位置，不删除边界检查。

实际验收：
tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/tieshan_head_anchor.tscn -OutputRoot output/tieshan_anchor_final
双分辨率、0.85/1.1缩放、出画、无成品拒绝、取料制作交单及隐藏共19项功能通过。退出仍报告2个资源未释放，运行器判失败；未证实与基线关系，不能称此命令整体通过。该轮正式存档指纹未变。

tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/tieshan_bubble_interaction.tscn -OutputRoot output/tieshan_anchor_interaction_final
31项全部通过，无项目错误，正式存档指纹未变。覆盖读档恢复、远处E不能交付、近距E选中及屏幕边界、锁定隐藏E、真实首单交单、成功隐藏。已目检定位实景截图。

环境：系统根证书读取失败单列环境告警。早期tieshan_anchor_fixed与tieshan_anchor_interaction轮次正式存档指纹变化，来源未确认；未回写或恢复用户存档，历史日志保留。近期成功轮不覆盖历史异常。

稳定知识：头顶标记的屏幕避让不能移动尖角锚点；人物出画后不应把气泡钉在屏幕边缘。铁山使用AnimatedSprite2D及自己的首单状态入口，不能直接套用普通营业Sprite2D数据读取方式。
