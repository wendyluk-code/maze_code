# 人物携料显示与取货限制交付

## 后续更新：按已选食材匹配食谱

2026-10-19用户进一步确认：选中食材后动态筛选相容食谱，不按订单先后指定；必须选齐一份配方才能取出。当前行为以此更新为准，下文“三种多份任取”及其原88项测试为历史交付记录，不再作为当前取货规则验收入口。

增量修改 `scripts/save_manager.gd` 和 `scripts/ui/warehouse_modal.gd`，复用物品格的禁用属性，在仓库局部灰显不相容格子；减号可恢复可选范围。候选查询按玩家已收录配方核对种类、数量，完整配方校验同时用于按钮及实际事务，不新增提示文案。人物图标、三种上限和已有材料禁止再次领取继续保留。

当前验收：`tools/tests/warehouse_recipe_selection_run.ps1 -Mode flow -OutputRoot 'F:/maze_code/output/warehouse_recipe_selection_verify'`，双分辨率71项通过、0失败、正式存档未变；覆盖真实E/鼠标输入、灰显、数量上限、正反选择、取消恢复、完整取货、烹饪事务和读档。启动检查见 `output/warehouse_recipe_selection_smoke`，编辑器检查见 `output/warehouse_recipe_selection_import`。环境仍报告系统证书读取、引擎目录编辑器设置写入受限，项目错误单独核验。

一次验收启动前发现正式存档文件在枚举与计算指纹之间消失，脚本停止，未启动测试引擎；之后重新核验成功。最终隔离验收正式存档指纹相同。第一次场景测试被原有接单食谱教学截走输入，补上实际E确认后通过，失败记录位于 `output/warehouse_recipe_selection`。

稳定约定：候选食谱包含当前选择的全部材料且满足数量上限，不能仅用“与首个食材有共同配方”拼接互不相容的组合。完整领取要求材料及数量与某一候选配方完全一致；将来增加共用原料或调整配方数量时复跑该入口。

目标工作区：`F:\maze_code`。基线为 `master` 的 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`。直接在主工作区增量实现，未创建执行任务、提交或推送；保留原有未提交改动。

## 实际行为

- 料理材料图标纵排在人物侧边，朝左显示于右侧，朝右显示于左侧；正背面保留最近水平位置，初次进入默认左侧。
- 图标复用实际材料纹理及透明边界裁切组件，不使用概念图中的示意食材。不显示名称、数量或底板。
- 仓库单次最多三种，同种份数沿用原库存上限；携带料理材料时静默禁止再取。木材和料理成品不阻止取料。
- 普通取货和首单事务均校验限制；首单已有成功记录的重复调用仍只返回原回执，不增加物品。失败不扣库存。
- 图标从实际库存派生，烹饪消耗后移除，读档恢复；旧档超过三种时不删料，完整显示。
- 验收发现既有仓库网格将领取按钮挤出窗口，调整网格可视高度和面板高度，使底部操作保持可见。

## 文件

生产改动：`scripts/player_map.gd`、`scripts/ui/components/carried_material_icons.gd`、`scripts/save_manager.gd`、`scripts/ui/warehouse_modal.gd`。组件约定增量登记于 `docs/ui_component_library.md`。未修改 `scripts/ui_layer.gd`。

验收入口：`tools/tests/carried_materials_run.ps1`、同名 `.gd` 和 `.tscn`。所有测试使用独立用户目录，核对正式存档 JSON 指纹。

## 验证证据

实际引擎：`F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，版本4.7.2。

```powershell
& tools/tests/carried_materials_run.ps1 -Mode flow -OutputRoot 'F:/maze_code/output/carried_materials_final'
& tools/tests/carried_materials_run.ps1 -Mode smoke -OutputRoot 'F:/maze_code/output/carried_materials_smoke'
& tools/tests/carried_materials_run.ps1 -Mode import -OutputRoot 'F:/maze_code/output/carried_materials_import'
```

最终场景验收：1152×648及1280×720，共88项、0失败。覆盖鼠标选择、第四种拒绝、取消一种后改选、E打开、真实移动方向输入、前后保持、图标跟随、Esc恢复输入、读档重建、烹饪事务清空及再取、保存失败回滚、木材成品例外、首单兼容。烹饪消耗测试调用真实经营事务，未重跑完整烹饪小游戏。截图在 `output/carried_materials_final/screenshots`，逐项报告在同目录上级 `report.json`。

启动和编辑器检查均退出0，无项目脚本或资源错误；三次正式验收存档指纹均未变化。环境限制：系统证书读取失败；编辑器检查另报引擎安装目录的编辑器设置无写入权限，这些单独记录在 `summary.json` 的环境错误字段。

过程中修正了验收脚本的类型推断错误，隔离了首次来客教学对仓库输入的干扰，并用真实截图定位及修复领取按钮出屏问题。失败尝试保留在 `output/carried_materials_first`、`carried_materials_second`、`carried_materials_third`，不作为通过证据。

## 稳定约定与重新审查条件

“手上有货”的判定仅来自 `carried_ingredients()`，不要改成整个背包非空；图标组件只读，不维护第二套库存。若更改材料分类、人物高度、镜头倍率、仓库选择方式或烹饪扣料时机，重新执行上述场景验收。正例：木材12份且无原料可取货；反例：仍有一份岩盐时再取任意食材。修正时保持事务拒绝与界面静默规则一致。
