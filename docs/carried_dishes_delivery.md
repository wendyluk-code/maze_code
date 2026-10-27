# 烹饪成品随身显示

## 2026-10-21：确认后的棕色圆底

携带组件为每个真实食材、料理图标绘制棕色圆底（#a87950），直径24世界像素，边框1世界像素（#946239）；图标最长边26世界像素，不裁切，可轻微超框。底板直接绘于图标下方，随图标列表刷新，不新增库存状态。复用现有26像素图标和28像素纵排间距。

主工作区验收入口 `tools/tests/carried_dishes_run.ps1`：`flow` 输出至 `output/carried_icons_brown_flow`，双分辨率35项通过、0失败，包含材料截图、真实烹饪、左右朝向、读档及交单失败/成功；`smoke` 与 `import` 分别输出至 `output/carried_icons_brown_smoke`、`output/carried_icons_brown_import`，无项目错误，正式存档指纹均未变化。证书读取及引擎目录编辑器设置写入提示仍为环境限制。实机截图已检查，食材和料理均显示圆底。变更图标大小或圆底比例后重新检查实际场景，不能只以放大预览代替验收。

目标工作区：`F:\maze_code`。在已有用户改动上增量实现，未提交或推送。

`scripts/ui/components/carried_material_icons.gd` 复用原携料图标样式，从真实库存读取配方成品。烹饪完成显示对应料理；左右朝向切换侧边，正背面保留上次位置。材料与成品共用图标列，不维护第二套库存。

`scripts/ui/restaurant_hud.gd` 在料理结果确认后关闭界面、恢复移动，不再立即自动交付。玩家到吧台交互完成交付后，已消耗的成品图标随库存移除。交付失败回滚时保留；读档从实际库存恢复。

## 集成验收

在目标工作区运行：

```powershell
& tools/tests/carried_dishes_run.ps1 -Mode flow -OutputRoot 'F:/maze_code/output/carried_dishes_final'
& tools/tests/carried_dishes_run.ps1 -Mode smoke -OutputRoot 'F:/maze_code/output/carried_dishes_smoke'
& tools/tests/carried_dishes_run.ps1 -Mode import -OutputRoot 'F:/maze_code/output/carried_dishes_import_final'
```

双分辨率1152×648、1280×720，35项检查通过，0失败。实际餐厅场景覆盖取料、打开锅、小游戏产出、E确认结果、移动恢复、左右位置、读档、吧台交付保存失败保留及成功消失。所有运行正式存档指纹不变。截图位于 `output/carried_dishes_final/screenshots`。

首次编辑器检查报告 `cooking_modal.gd:278` 类型推断错误；随后核验该处已为显式布尔类型，未覆盖该文件的其他改动。最终编辑器及场景重验无项目错误。环境仍报告系统证书读取失败、引擎目录编辑器设置无法写入；与本次功能无关，原始输出保留于各目录。

稳定约定：携物图标只读真实库存，不能在结果弹窗关闭时清除；成功交单才消耗对应成品。今后变更库存、配方目录或交付入口时，重新执行该集成验收。
