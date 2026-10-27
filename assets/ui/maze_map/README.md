# 迷宫地图图标

## 圆形视图去字地图

`shallow_floor_no_labels.png` 由内置 `image_gen` 编辑 `assets/maps/shallow_floor.png` 生成（输出 `exec-14013c08-089f-4c13-a06c-20b6c11e4664.png`）。仅供圆形视图去除原图内嵌地名牌，展开图仍使用原图。运行时仅混合十二块名牌范围及8像素柔边，避免生成图片在其他地形处的变化影响原坐标映射。原图与编辑图均为1672×941。

完整编辑提示词：

> Use case: precise-object-edit. Edit this exact top-down hand-painted game map. Remove ALL twelve dark rounded location nameplates AND ALL Chinese lettering printed on them: 守水人小屋, 青苔池, 盐池, 树根庭院, 分水庭, 污水池, 浅滩, 水轮工坊, 枯水渠, 旧城长廊, 入口, 下一层. Seamlessly inpaint ONLY each small nameplate footprint with the underlying adjacent terrain, road, water or forest, matching the same soft painted style. Especially reconnect the cream footpath behind the entrance and old corridor labels. Preserve BOTH golden door pictograms, the small cabin, purple crystals, water wheel pictogram, bridge planks, and every non-text feature. Preserve exact original map layout, scale, crop, orientation and original 1672x941 wide aspect ratio, without adding margins or changing coastlines, road geometry, lakes, terrain or lighting. The result is the SAME complete map, no location labels or dark nameplates anywhere. Absolutely no text, letters, numbers, border, additional icons or labels. Do not redraw the map or simplify its details.

## 图标

`chest_gold.png` 是用户于2026-10-11确认保留的宝箱轮廓。由内置 `image_gen` 生成透明 PNG，原文件为 `exec-03e07ded-03a4-43e4-baf8-5e1a51e3808a.png`。项目保留生成透明度，绘制时由 `maze_map_icon.gdshader` 统一为纯金色，不使用源图的色彩变化，不加描边和投影。

采用规格：单枚扁平宝箱图标，正视角、圆顶宽箱体、中央方形锁扣、箱盖与箱身之间透明缝隙；暖金纯色、透明背景，无文字、徽章和环境。小地图与展开地图共用同一资源。

`player_direction.png` 是用户确认采用的手绘卡通方向标，由内置 `image_gen` 参考实际游戏截图编辑生成，原文件为 `exec-0a3bfbe7-0d3a-4d96-a134-0a730d6d4850.png`。保留金黄明暗分面、米白描边、浅棕短投影和透明背景，替代此前未采用的写实金属候选。源图尖端朝上，绘制旋转补偿四分之一圈，使它与角色朝向一致。圆形小地图绘制区域23像素，展开地图48像素（含透明留白）；共用带多级缩小纹理的缓存，减少缩小和转向时的锯齿。

本次方向标编辑的完整提示词：

> Use case: style-transfer. Image 1 is the EDIT TARGET: an upward-pointing player direction arrow. Image 2 is STYLE REFERENCE ONLY: the actual cozy hand-painted 2D fantasy game, its matte warm cream UI and soft cartoon scenery. Redesign ONLY the isolated arrow to fit image 2. Preserve its clearly readable north-facing triangular arrow silhouette with a shallow bottom V notch, symmetrical front view, centered. Remove the realistic metal rendering entirely. Make a charming hand-drawn 2D cartoon UI sprite with a matte honey-yellow main fill, one simple muted ochre shaded side plane and a small pale butter-yellow plane: ONLY three broad flat color areas suggesting subtle thickness, no realistic bevel, no metallic reflection, no gloss, no smooth gradient, no specular glints. Slightly softened corners and a restrained handmade contour, not rough or noisy. A moderately thin warm-white/ivory outline around the silhouette, plus a very short subtle muted brown offset shadow for readability, no black halo or heavy ambient occlusion. Compact broad shape, crisp readable at 24-32 pixels, visually lightweight like the game's existing painted interface. Entire icon including shadow fits inside canvas with generous transparent padding. TRUE transparent background. Output ONLY one arrow sprite. Do not include the game screenshot, map, text, labels, frame, circle, stars, extra objects or a presentation sheet.
