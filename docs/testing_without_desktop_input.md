# 当前主线自动测试不接管桌面输入

适用于通过 combat_02_run.ps1 启动、继承 ch1_qte_03_input.gd 共用输入助手的当前小屋和园圃自动化测试。内部点击仍经过真实界面的悬停和按下/松开处理，不直接调用按钮业务函数。

测试子进程使用 GODOT_EDITOR_CUSTOM_FEATURES（Godot的编辑器构建自定义功能环境变量）加入 maze_automated_test（本项目自动测试标记）。project.godot 只在该标记存在时启用 display/window/size/no_focus（窗口不可获取焦点），配置在创建窗口前生效。未带该环境变量的正常试玩保持原有焦点和输入行为；不改正在运行的窗口。

共用输入助手通过 Viewport.push_input（向游戏内部画面注入事件）发送鼠标移动、点击和按键，不使用 warp_mouse（移动真实鼠标）、系统鼠标模式切换或操作系统输入注入。渲染测试继续放副屏；无窗口检查保留 --headless。此范围之外的历史测试脚本尚未统一迁移，不能据此声称全仓库测试均不操作桌面鼠标。

专项入口：tools/tests/desktop_independent_input.tscn。无窗口验证证明内部悬停、点击和键盘路径，不代替Windows原生窗口的焦点检查；两者分别运行、分别记录。

本次验证记录位于 output/desktop-independent-input-20261028/：headless-final 的7项内部输入检查通过，normal-config-report.json 的2项检查确认正常启动不启用不可聚焦配置；原生副屏专项9项通过，检查窗口不可聚焦且没有桌面焦点。园圃主线164项、小屋往返主线194项回归通过，三个有窗口专项均无脚本错误且正式存档指纹未变。此前的失败记录保留，没有用通过结果覆盖。

复跑原生专项：运行 tools/tests/combat_02_run.ps1，传入 -Mode flow、-ScenePath res://tools/tests/desktop_independent_input.tscn、实际 -Godot 路径和新的 -OutputRoot。启动器会为子进程加入测试标记并指定副屏。无窗口专项可直接以 --headless 运行同一场景，传入隔离存档环境和 --report=输出文件；--normal-config=true 检查不带测试标记时的默认配置。

边界：原生专项验证了本机当前窗口的不可聚焦状态及测试时没有桌面焦点，并结合启动前配置核对；未对整个启动过程做操作系统级逐毫秒焦点采样。此次改动不操作已经运行的其他窗口，也不替主线继续素材制作、玩法实现或预览启动。
