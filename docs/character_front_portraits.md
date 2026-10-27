# 五位既有角色正面立绘接入

2026-10-26，目标工作区 F:/maze_code。

芽芽、铁山、萨莉亚、叮当、御风统一使用用户提供三视图中的正面人物，资源位于 assets/ui/character_details/*_front.png。保留原人物像素及服装比例，去除纸面背景和独立装饰。角色配置通过 detail_portrait 指向这些资源；卡牌、详情和芽芽/铁山入队蒙层共用 portrait_path 与 party_character_face，无需另设蒙层图片。小头像、数值和技能未修改。

验收：tools/tests/full_body_cards.tscn 三分辨率146项通过；tools/tests/card_art_12_party_scene.tscn 双分辨率51项通过，覆盖真实餐厅入队、双卡展开、长按E防穿透、继续对白与取消后恢复输入。截图及报告位于 output/front_portraits/verified 和 output/front_portraits/party_verified。正式存档指纹未变。

编辑器导入通过，无项目错误；环境存在系统证书读取和编辑器设置目录写权限警告。

可复用结论：大卡立绘入口为 character_progression.gd 的 portrait_path；入队蒙层与详情共用同一路径。以后替换该路径时需要复查两处截图。原图分辨率有限，放大后保留原图柔和质感。
