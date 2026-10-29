# 雷鳗独立膜与岸行动作候选来源

本票没有新生图或改写主体。膜源为D:/workspace/代号：料理迷宫/output/fenshui-assets/eel-shield-atlas，原交付说明、acceptance.json、三动作prompt.txt和generation-log.jsonl保留于该目录。来源已批准48帧复用。复制前核对本工作树主体摘要与原验收源图记录一致，复制后核对膜摘要一致。

| 生产文件 | SHA-256 |
| --- | --- |
| assets/monsters/thunder_eel/shield_idle.png | 3e78781faed862c6cef0d9f8d3ce18c704a69c7d24d0974933b1dee77049dd5f |
| assets/monsters/thunder_eel/shield_swim.png | 0784e22e0bc41e4fd716ed5266395542c8f85fc59e136870848c5859535ccb01 |
| assets/monsters/thunder_eel/shield_attack.png | 673746818afa9d38162a46f1e1d9e1de435031faca07491190f0fc38162debde |

图集512×512、四行四列、单格128，行序右下/左下/右上/左上，列序对应主体四帧，三动作共48帧。idle/swim已烘焙0.55透明度，attack已烘焙0.4，代码正常显示不再重复乘；凝膜只按阶段做0至1渐显。

岸行候选沿现有审阅的去水纹、贴地短距蜿蜒方案：使用原swim主体，不改体型，逐帧读取不透明脚底位置并贴到地面，帧间0.32秒；水中原0.18秒节奏不变。四向16帧受控预览为output/eel-shore-20261030/eel-final-flow/shore-four-direction-preview.png。它是本票实际节点的动作审阅材料，不代表四条方向路径或用户最终观感验收。

新膜使用Image.load_from_file读取PNG，不运行编辑器导入；实际工程运行已验证，导出包包含与加载尚未验证。若来源否决岸行观感，再按原飞书风格原文与完整已确认提示词补对应动作，不重画已有合格主体。
