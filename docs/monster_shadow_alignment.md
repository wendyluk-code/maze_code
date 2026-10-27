# 蜥蜴与蜗牛投影贴合

`scripts/maze/capture_monster.gd` 保留立绘裁切、尺寸、动画和地图位置，仅为蜥蜴、蜗牛修正投影位置。初始化时按每帧透明度不低于0.5的主体定位最低接地点，取底部7像素区域的横向中心，投影中心放在脚底上方2个世界像素，避免透明边缘杂点造成悬空。其余魔物投影行为保持原样。

主工作区验收命令：`tools/tests/monster_shadow_acceptance_run.ps1 -Mode flow -OutputRoot F:/maze_code/output/monster_shadow_final`。实际迷宫中的1只蜥蜴、3只蜗牛逐帧渲染，共16帧、40项检查通过，正式存档指纹不变。截图位于上述目录的 screenshots；仅出现系统证书读取环境警告。测试为观察投影隐藏主角并暂停遭遇，不修改玩家存档。更换动画素材、缩放或透明度阈值后须重新查看帧截图并验证贴合。
