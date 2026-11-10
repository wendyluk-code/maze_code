# 分水庭玩家受击素材接入

这五张图来自用户已认可并交付的原视觉会话。程序只复制与按格取帧，没有生成新图、重绘、改色或改变源像素。它们用于怪物攻击玩家，不是玩家攻击魔物的命中特效。

| 正式文件 | 交付原文件 |
| --- | --- |
| fish.png | output/player-hurt-watercolor-sequences/fish-hit.png |
| electric.png | output/player-hurt-watercolor-sequences/electric-hit-v2.png |
| water.png | output/player-water-hit-sequence/water-hit.png |
| slam.png | output/player-hurt-watercolor-sequences/slam-hit.png |
| hero.png | output/hero-hurt-motion/candidate-v2.png |

原视觉会话为01a18b43-6b06-7a73-998c-ac6f50b764a2/local。用户在原会话明确同意全部交主会话集成，在本会话批准90分钟程序接入、实战验收、网页更新和回传。电击只使用v2透明稿，不使用早期白底稿。

五张原图均为1536×1024，3列2行，每格512×512。四种接触效果按30/35/45/45/40/35毫秒播放，共230毫秒。人物使用中间四姿态50/70/70/70毫秒，共260毫秒；演示首尾450/550毫秒待机不作为游戏延迟或输入锁。

沿原预览人物整格260高、脚底0.84格高标定，特效格锚点为(0.48,0.52)，躯干挂点为(-4,-79)，再按原正常人物显示及相机倍率换算。四种预览整格宽为鱼110、电142、水106、砸128；这是包含透明边缘的画布宽度，不是可见墨迹宽度，不按怪物体型或保护膜尺寸换算。左右来向只翻特效，砸击始终向下。

2026-11-06 K候选新增three_directions_v1.png，为output/hero-hurt-three-directions/atlas-v1.png的同字节副本，1448×1086，3行4列362格，行依次左/右/背；列为接触、峰值、持痛、恢复。正面仍沿原hero.png，不混镜像或重绘。每方向统一等比尺度和可见脚底，持续痛态由实际600/900毫秒硬直剩时驱动，最后100毫秒恢复；不延长230毫秒接触图。消费者不改玩家facing（逻辑朝向）、位置或输入处理；结束按当前战斗动作恢复显示。真实成功扣血才播，保存失败、打空和零伤不播，不写存档。范围与恢复契约见workflow/concepts/fenshui-player-hurt.zh-CN.md。

实机结果及限制见output/fenshui-player-hurt-20261104/review.md，截图页为同目录preview.html。浅色鱼撞笔触在浅围裙上的辨识度偏弱，已保留原图供视觉会话结合实机判断；程序没有自行加粗或提亮。

写作规则审查：已完成（本文）。
