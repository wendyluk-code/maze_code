# 声望与金币图标

使用内置 imagegen 生成，透明 PNG，各 1254×1254 像素。

- reputation.png：声望，橙金五角星徽章与短缎带。
- gold.png：金币，圆形金色钱币与菱形压纹。
- preview.html：左上角布局与 32、40、48 像素明暗背景预览，数值为示例。

本次交付为图标设计素材；游戏场景和脚本未接入。预览复用现有餐厅背景、zcool_kuail.ttf 字体及 SproutTheme 的奶油色与深棕色。建议显示尺寸 40–48 像素，等比缩放，图标与数值间隔 8 像素。图标各有透明留白，接入时按完整画布对齐。

## 验收记录

- 两张图片均为带透明通道的 PNG，1254×1254 像素，四周留白透明。
- 已检查 32、40、48 像素的明暗背景静态校样，星章与圆形金币可辨；推荐 40–48 像素。
- 校样：../../../output/hud_icon_design/size_check.png。校样只用于检查缩放，原始素材未改动。
- preview.html 已生成；内置浏览器因本地文件 URL 安全策略拒绝打开，页面渲染未验证。它是设计排列示意，不是实际游戏运行截图。
- 本次未修改游戏脚本或场景，未运行游戏交互验收。后续接入需检查实际场景中的位置、遮挡和数值变化。

## 生成提示词

### 声望

Use case: stylized-concept. Asset type: production-ready small HUD icon for a cozy hand-painted fantasy restaurant game. Create ONE isolated icon, square 1024x1024 canvas, actual transparent background. Centered with an approximately 8% transparent margin on all sides; silhouette fills 84% of canvas. Warm hand-painted gouache game illustration with gently irregular clean thick dark walnut brown #5b3b20 outlines, restrained flat shading, soft cream upper-left highlight, crisp silhouette. Must remain immediately legible at 32px and 48px. Favor very few broad shapes and no tiny detail. Not pixel art, not photorealistic, not glossy 3D, no glow, no drop shadow outside silhouette, no letters, no numbers, no watermark, no surrounding ornaments, no scene, no panel. Subject: reputation icon, a chunky five-point warm amber-orange star-shaped award badge. A single large softly rounded five-point star is the dominant unmistakable silhouette, small pair of short muted terracotta ribbon tails peek below it. Star face warm #eda64c with lower-right burnt-orange shade and one simple inset star-shaped bevel line, pale cream light on upper-left. Broad tips, compact shape, friendly and welcoming. No circular backing, no wreath, no extra stars.

### 金币

Use case: stylized-concept. Asset type: production-ready small HUD icon for a cozy hand-painted fantasy restaurant game. Create ONE isolated icon, square 1024x1024 canvas, actual transparent background. Centered with an approximately 8% transparent margin on all sides; silhouette fills 84% of canvas. Warm hand-painted gouache game illustration with gently irregular clean thick dark walnut brown #5b3b20 outlines, restrained flat shading, soft cream upper-left highlight, crisp silhouette. Must remain immediately legible at 32px and 48px. Favor very few broad shapes and no tiny detail. Not pixel art, not photorealistic, not glossy 3D, no glow, no drop shadow outside silhouette, no letters, no numbers, no watermark, no surrounding ornaments, no scene, no panel. Subject: money icon, ONE round gold coin viewed almost straight-on with just a slim darker thickness visible on lower-right edge. Dominant unmistakable circular silhouette, golden yellow #f2c64e face, ochre orange rim, a simple recessed circular inner rim and ONE bold small diamond lozenge embossed in center, pale cream short curved highlight at upper-left. Clean round coin with subtle handmade contour. No star emblem, no currency letters, no coin stack.

