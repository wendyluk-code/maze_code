# HOME-01 角色详情页无文字素材

本票仅交付图片与可重复裁切工具，不实现界面或经营规则。基线 `master` / `8d468218563d173fbbae90a42170c1e13a26da60`；独占分支 `codex/home-detail-assets`。所选项目 `7c3963e8-2c05-4bd9-9992-d9dc706e8cf4` 已成功创建本工作树，`project_binding_verified=true`。

## 来源与复现

批准稿位于 `C:/Users/KSG/.codex/generated_images/01a14365-dae8-72a0-8527-9795eb16ff01/`：属性稿 `exec-34d06468-7900-4f40-b1da-eb19c0f5b3aa.png`，技能稿 `exec-b73c7303-fbdd-4837-8203-1856f3aeb032.png`。补充绿色突破稿 `exec-8bf352e5-abc5-43cb-8250-ffce931f2605.png`。三图均为1672×941；精确 SHA-256（内容校验值）、每张切片来源坐标、处理方式、尺寸与九宫格边距位于 `assets/ui/character_details/slices.json`。坐标为原图像素，右边和下边不包含。

运行 `python tools/slice_character_details.py --attributes <属性稿路径> --skills <技能稿路径> --breakthrough <绿色突破稿路径>`，需要 Pillow。默认路径对应本机批准稿；原稿未复制进仓库。全部处理为确定性裁切、无字区域拼接与透明蒙版，未调用生图。

## 开发接入清单

所有下列图片位于 `assets/ui/character_details/`，均为 RGBA PNG（含透明通道的图片）。

| 用途 | 图片 | 接入方式 |
| --- | --- | --- |
| 无字纸面 | `paper_tile.png`、`paper_panel.png` | 后者使用 `NinePatchRect`（九宫格控件），边距左25、上33、右25、下25；前者作为内层纸纹。不要把整个面板等比拉伸当正式布局。 |
| 属性／技能页签 | `tab_selected.png`、`tab_idle.png` | 两个页签共用两种状态底板；各叠加真实文字。九宫格左右82/65、上下8。 |
| 六星 | `star_lit.png`、`star_dim.png` | 固定创建六个等尺寸图标，按实际星阶选择亮／暗；不能通过固定六星整图表示状态。 |
| 三属性图标 | `attack.png`、`satiety.png`、`recovery.png` | 分别表示攻击、饱腹上限、恢复；等比显示，数值与标签由字体渲染。 |
| 技能状态 | `lock.png`、`skill_gift.png` | 锁含圆形徽章底，不附带解锁等级文字。礼物来自批准稿首技能，不代表所有技能的固定图标。 |
| 技能行 | `skill_row_active.png`、`skill_row_locked.png` | 九宫格左右20、上下8；标题、正文、解锁条件作为独立文字层；右侧可叠加叶饰。 |
| 经验条 | `progress_track.png`、`progress_fill.png` | 轨道边距12/8/36/8，填充20/8/20/8；填充裁剪宽度依真实比例变化，经验数字独立叠加。 |
| 突破按钮 | `breakthrough_active.png`、`breakthrough_base.png`、`gold.png` | 绿色用于可突破、灰褐色用于金币不足；左右50、上下12；叠加金币、动作与费用文字。该图不决定交互状态。 |
| 细分隔与叶饰 | `divider.png`、`leaf_decoration.png` | 已去纸底，暖金透明装饰；分隔中央星形应保持比例，可拆左右线进行伸缩。 |

**突破交互以最新确认规则为准：未到突破等级时完全隐藏；需要突破时才显示。** 不得因批准稿有灰色按钮而在低等级显示禁用按钮。可用／不可用判断属于后续实现，不由本票素材推断。

姓名、属性、技能、等级、数值、技能标题与正文、经验、费用都必须使用 Godot 真实字体渲染。图片不含这些文字。角色沿用现有角色组件与立绘，本票未裁切角色。

已阅读 `docs/ui_component_library.md` 与 `scripts/ui/components/sprout_theme.gd`：字体沿用 `SproutTheme.FONT_CN` 对应的 `assets/ui/zcool_kuail.ttf`；按钮输入行为复用原生按钮／现有组件。金币直接复制 `assets/ui/hud_currency/gold.png`，像素一致；开发也可直接引用原路径。现有组件没有批准稿详情页纸面皮肤，因此本票只增加独立纹理，不修改共享组件。

## 验收与限制

`output/home_detail_assets/contact_sheet.png` 展示全部20张素材的棋盘格透明边缘；已逐格查看，修正过纸面右上角夹带关闭按钮、蒸汽间纸底及按钮尾部文字残片。装饰通过原图色差提取透明度；不是保留原纸色的矩形裁片。

`output/home_detail_assets/assembly_no_text.png` 为无字组合示意，展示六星、页签、属性、经验条及按钮的组合方式；空白角色区留给游戏现有角色。此图为素材示意，不是 Godot 实际界面验收。`checks.json` 保存各图尺寸、通道范围与校验值。

选中页签使用无字绿色纸纹二维扩展与羽化拼接；突破按钮使用无字宽片柔化拼接及右弧边镜像，已去除首轮水平拖影与方角接缝。未选中页签及技能行采用干净竖条延展，纸纹有方向性；纸面由无字边框组合，不能视为原整张设计稿的像素级复原。绿色突破底板来自主会话补充批准稿，灰色底板保留供金币不足状态使用。后续实现应在真实尺寸审阅纹理和文字叠加效果。本票不运行游戏、不导入场景、不写主工作区；视觉交互和主工作区集成由来源主会话在实现票据完成后验收。

稳定交接知识：本切片的坐标只适用于记录校验值的三张1672×941批准稿；更换稿件、尺寸、蒙版或九宫格边距后，必须重新生成并逐格审查透明边缘与文字残留。项目实际主场景为 `scenes/start_screen.tscn`，与旧缓存不同；本票未修改入口。

## 2026-10-16 视觉修复版（替代旧纸面和页签接入）

旧256像素纸面拼接和窄条横向拓展不再用于正式详情。新增 paper_background_v2.png 保留完整无字花叶纸面、分栏和姓名牌；tab_selected_v2.png / tab_idle_v2.png 从无字素材表独立裁切，坐标见 slices_v2.json，裁切工具 tools/slice_character_details_v2.py。两角色新增透明高清详情立绘，旧256像素头像仍保留给原角色簿。本轮通过 imagegen 修复原批准稿后接入，未将任何文字烘焙进图片；不是对原稿的逐像素复制。纹理使用无损导入和多级缩小采样。

纸面源 exec-6e82b741-393d-49a4-8614-c4cb27be4b14.png，芽芽源 exec-1e9c13e6-16d8-41a5-b079-97fd7ad6faf3.png，铁山源 exec-6e664f7c-19f8-49ed-b570-82f60cdaa9d0.png，页签源 exec-15dd6745-4532-4462-8716-00caf328006c.png，均位于原批准稿同一 generated_images 目录。项目用图已复制进 assets/ui/character_details，运行时不依赖该外部目录。

旧进度条包含绿色残片，旧技能行角部不完整，故这两种简单几何边界由原生抗锯齿样式绘制；旧图片仅作为历史产物保留，正式页不再加载。突破按钮保留已有皮肤，改为完整缩放避免圆角受九宫格挤压。

右上角吊牌移除版：paper_background_v3.png，由内置imagegen编辑paper_background_v2.png，提示词为：仅移除右上角圆形吊牌及挂绳，补齐被遮挡的纸面、金色边框和相邻花叶；其余构图、尺寸、纹理与透明背景保持不变，不增加任何文字或符号。源输出exec-1af8dd5e-4ae4-41a7-8446-06ddca920941.png，已复制到项目资源目录。独立关闭按钮由游戏字体绘制，图片不含叉号。

2026-10-17 派系图标：assets/ui/factions/fire.png、grass.png、earth.png、lightning.png、water.png、wind.png，来源设计稿 output/faction_icons_sheet_v1.png。图标采用金币/声望同款厚涂连续色块和深棕描边，已切为512×512透明PNG；原始设计稿仅作审阅证据，不由运行时读取。
