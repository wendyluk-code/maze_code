# 分水庭浅水白色波纹（2026-10-22）

用户确认效果图后直接在F:\maze_code增量接入。新增scripts/maze/shallow_water_ripples.gd，仅在支持浅水地形的maze_player安装。按实际移动距离每13世界像素生成一圈轻薄白色断弧，屏幕半径18至72像素、扁率0.30、0.9秒扩散淡出，最多6圈。波纹保留在脚步的世界位置并绘制于人物下方；停步和上岸不再生成，地图/失焦锁定冻结，换位清除，不写存档。不改变水速、冲刺、战斗、UI。

验证：output/fenshui_ripples/verified双分辨率47项通过，截图已检查；region_regression原分水庭171项通过；smoke主场景通过。编辑器import无项目错误，存在系统证书与编辑器设置目录权限告警。实际工具命令及隔离路径见各目录summary.json，执行器tools/tests/combat_02_run.ps1。

首轮视觉复核发现渲染帧与物理帧频率不同，零位移渲染帧使首圈反复生成；改为以真实移动状态保持步距累计后，最终效果疏落扩散。最终verified及smoke运行正式存档指纹不变。此前flow_final与import期间正式save.json有并发变化；测试报告确认user_dir为output下隔离目录且活动存档为chapter-ending-test.json，环境另有4个Godot进程，但不能据此确定写者。保留两次指纹失败记录，不将其写为通过，也未回退正式存档。

基线副本、散列在output/fenshui_ripples/baseline。新增tools/tests/fenshui_ripples.gd/.tscn。未提交，未修改ui_layer。改变地形接口、人物脚底、镜头倍率或暂停规则后复验。波纹为临时表现，不应序列化到经营档。