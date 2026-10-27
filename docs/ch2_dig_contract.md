# 第二章首段挖掘点

本次已确认范围：截图四个红圈全部放置闪光挖掘点，每处木材×3，每个存档各领取一次，成功领取后闪光与提示消失。不是剧情任务，不推进盐池任务、章节或声望。

## 点位与资源

配置在 `data/maze/entry_dig_sites.gd`，坐标采用1222×1287原地图空间。永久ID不随美术或坐标调整改变。

| ID | 位置 | 坐标 |
| --- | --- | --- |
| entry_dig_west_fork | 截图左上黑圈 | 953, 310 |
| entry_dig_northeast | 右上路边 | 988, 565 |
| entry_dig_inner_path | 内侧支路 | 782, 891 |
| entry_dig_south_bend | 截图右下黑圈 | 923, 1211 |

`generated_assets/tree_stump_4_white_sparkles_256.gif` 的40帧逐帧RGBA解码为 `assets/props/dig_site/twinkle_atlas.png` 和 `twinkle_frames.tres`，保留256×256画布、每帧80毫秒、无限循环与透明度；不裁剪、缩放或移动帧内树桩及四颗白色四角星，原文件不改。场景仍使用原有0.18倍显示缩放与点位。复现命令 `python tools/tests/ch2_dig_convert.py`，转换记录中的 `rgba_roundtrip_exact` 表示解码后PNG像素与GIF各帧完全一致。木材图标直接引用用户 `generated_assets/wood_logs_pixel_256.png`，仅用纹理区域去除透明留白。

## 交互与存档

合法道路站位距离52像素内，宝箱和挖掘点共同选最近有效目标，只显示一个共用E图标。两者相邻时先领取当前目标，关闭弹窗后另一个才可重新交互。按E或鼠标点击图标调用同一入口；奖励弹窗复用 `loot_modal.gd` 的有类型 `Array[Dictionary]` 物品列表，显示“木材”“×3”，不在点击“收下”时发奖。其他E组件保持原样。

`SaveManager.claim_exploration_dig_site` 检查ID、第一章完成态、当前区域、道路和距离；将 `inventory.wood`、`claimed_dig_sites` 及当前位置一次性原子保存。只有成功后隐藏闪光并显示弹窗；失败完整回滚内存，原文件不变，恢复移动且可重试。重复领取、重播和非法奖励状态不写盘不发奖。旧档缺字段按木材0、未领取处理，不补发奖励；未知字段与未知领取ID保留。每个存档独立，往返餐厅、退出读档都不刷新。

木材存入携带库存，当前餐厅仓库与烹饪界面仍是食材用途；本项不新增材料背包、木材配方或资源刷新系统。

## 验收与重新检查条件

- `tools/tests/ch2_dig_run.ps1 -Mode state`：旧档、领取×3、重复、真实写盘失败、重载、切档、坏数据、溢出与重播。
- `tools/tests/ch2_dig_run.ps1 -Mode flow`：1152×648和1280×720真实渲染及输入沿路到四点、邻近宝箱仲裁、动画、键鼠领取、模态输入隔离、标题选档及餐厅往返。
- `tools/tests/ch2_chest_run.ps1 -Mode state/flow`：宝箱存档及原有五箱流程回归。

测试启动器使用隔离用户目录，并比较正式JSON存档前后指纹。改道路、点位或半径后重跑可达性与仲裁；改存档字段后重跑旧档及回滚；改弹窗或输入后重跑两分辨率流程。失败记录和修正结果保存在 `output/ch2_dig`。
