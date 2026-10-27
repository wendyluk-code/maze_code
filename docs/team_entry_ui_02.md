# TEAM-ENTRY-UI-02：迷宫入口选人与探索准备

## 边界与基线

本票仅改入口展示及其验收，不改角色资产、生产数值、捕获规则、技能内容、存档契约或体力事务。基线 `codex/team-entry-ui-02-base` 对应 `df3f82ec1ae7b8a694c3f6eb095de94b5a6785cb`，开发分支 `codex/team-entry-ui-02`。主场景核验为 `scenes/start_screen.tscn`，引擎实际为 Godot 4.7.2。批准稿为 `output/team_entry_redesign/` 下的 team、selection、zero_satiety 三张 v7 图片；正式界面使用容器和真实数据，无新增生图。

## 玩家行为与复用

入口直接显示“探索准备”。四个横排方形头像槽点击进入选人页，姓名可查看既有真实角色详情；空槽只显示加号。基础战力来自选中角色成长记录，饱腹度只合计当前值，不显示上限。零饱腹精确显示“当前队伍饱腹度为0，无法捕获任何食材。”，仍允许进入。空队、异常角色记录和不足20体力沿用既有门禁。

选人页使用食谱页同款 `TabBar`（原生页签栏）样式，提供全部、草、土、雷、水、风、火过滤。拥有名单仍来自 `SaveManager.departure_state().party`。每行对齐显示角色、基础战力、个人当前饱腹／上限、`SproutButton`（主题操作按钮）入队选择态；头像与姓名打开 `character_details_modal.gd`（真实角色详情）。悬停或选中背景覆盖整行。长名单在 `ScrollContainer`（原生滚动容器）内滚动，末尾显示“- 已经到底了 -”，无匹配角色有空态。奶油框外底部保留当前队伍四缩略槽、“最多携带4名角色”和“确认”。该确认只返回准备页；取消入口不保存草稿。

准备页下半部为基础属性、队伍属性、技能加成三列。标题与正文顶部对齐；数值独立行对齐。技能按真实阶位逐项展示完整内容，自动换行，独立滚动条仅在内容溢出时显示，解锁数量与正文右边界对齐。面板居中，尺寸随视口约束，1280×720 与1152×648均实际验证。

外观复用 `SproutTheme.thin_panel_style()`（奶油细边框）、`SproutButton`、`modal_style.gd`（统一遮罩与关闭叉号）、`resource_counter.gd`（原20体力消耗行）。普通确认模式恢复原父容器、文案和样式，兼容普通目的地确认。

## 区域推荐与属性图

`region_recommendations()`（区域推荐推导）只读 `capture_catalog.gd.all()` 的当前首区魔物配置，按各属性可克制的魔物数量降序推荐，最多两项。第二名或其他名次并列时，按配置 `ELEMENTS` 的现有稳定顺序：火、草、土、雷、水、风。首区四土、三水、三风，因此显示草、雷。空配置不显示伪推荐；推荐不影响入场资格。未来增加其他区域时须改用该入口对应区域配置，不能把首区推荐直接复制过去。

`team_entry_element_chart.gd`（入口属性关系图）只读当前选中队伍元素。节点按火→草→土→雷→水→风→火排列；高亮已拥有节点及其指向克制目标的箭头。雷在捕获配置中为 `thunder`，角色派系和图片中为 `lightning`，仅显示层做双向资源映射，不改生产规则。

正例：只选铁山时仅土节点及土→雷箭头高亮；选草、土、雷、水四名夹具角色时四节点及四条出向箭头高亮。反例：把雷画成克土，或始终高亮草土，或按推荐限制入场。

## 可重复验收

本票入口复用 `team_entry_01_run.ps1`（既有隔离运行器），仅新增可选 `TestScene`（验收场景）参数，默认仍为旧验收场景。本票测试继承旧145项真实流程，增加筛选、空态、布局与长列表夹具。四人及24名角色只存在于测试子类的只读查询覆盖中，不注入 `Progression.CHARACTERS`，不写生产名单或生产存档。

```powershell
& tools/tests/team_entry_ui_02_run.ps1 -Mode flow -OutputRoot output/team_entry_ui_02/final_flow_polished
& tools/tests/team_entry_ui_02_run.ps1 -Mode resume -OutputRoot output/team_entry_ui_02/final_resume -ProfileRoot output/team_entry_ui_02/final_flow_polished/profile
& tools/tests/team_entry_ui_02_run.ps1 -Mode import -OutputRoot output/team_entry_ui_02/final_import
& tools/tests/team_entry_ui_02_run.ps1 -Mode smoke -OutputRoot output/team_entry_ui_02/final_smoke
```

在合入后的目标工作区运行上述命令，或显式传入 `-ProjectRoot F:/maze_code`。每次进程隔离 `APPDATA` 和 `LOCALAPPDATA`，对比正式目录所有JSON存档的SHA256（文件指纹）。输出包含 `summary.json`（命令、进程结果、环境警告、存档指纹结论）、`report.json`（逐项断言）、标准输出/错误日志及截图。

覆盖：双分辨率真实餐厅E入口、鼠标头像/姓名详情、选择与取消、0/1/4人、第五人拒绝、当前饱腹合计、零饱腹允许、四属性实时图、推荐最多两项且无门禁、24人列表滚轮到底、24项长技能滚轮到末尾、Tab/左右筛选与焦点限制、逐层Esc/关闭按钮、遮罩隔离、恢复实际移动、普通通行确认、单人/双人真实入场缩略头像、记忆恢复、保存失败回滚和独立进程恢复。

## 证据与维护条件

首轮旧流程145项全通过。扩展首轮223项中6项失败：测试只推送滚轮按下、未推送松开，后续点击未生效，选人页未关闭，技能滚动及后续过滤失去前提。单变量补齐滚轮松开并添加“确认已关闭选人页”断言后227项全部通过。该失败属于验收输入生成，不修改生产输入规则；失败原始日志保留于 `flow_extended`，修正证据于 `flow_extended_retry1`。最终证据以 `final_*` 目录为准。

稳定约束：入口只维护选择草稿，记忆与体力必须在真实入场事务成功后统一保存；展示不能提前写记忆。只读UI夹具应覆盖查询接口，不污染角色常量。等价鼠标测试必须成对推送按下与松开，并在跨页操作后断言当前页面。修改入口层级、拥有名单来源、角色记录、捕获属性顺序、存档事务或技能滚动布局后重跑本票及相关真实场景验收。

执行任务只提交本票增量；最终目标 `F:/maze_code` 的合入与集成验收由来源主会话负责。

最终本工作树验收：`final_flow_polished` 227项全通过，`final_resume` 4项全通过，`final_import` 编辑器导入与 `final_smoke` 主场景烟测退出码均为0，无项目脚本或资源错误。独立恢复使用前一轮已通过的 `final_flow/profile`（仅后续入队按钮选中外观与测试数值读取调整，存档事务无改动）。四轮正式存档指纹均一致。最终流程保存33张双分辨率实际截图；重点为 `reference_team`、`filter_grass_selected`、`filter_empty`、`zero_food`、`fixture_four_elements`、`fixture_list_end`、`fixture_skills_end`、`maze_one` 与 `maze_two`。

环境限制单列：各运行出现 Windows 根证书库读取警告；编辑器导入另有引擎安装目录 `editor_settings-4.7.tres` 无写权限警告。两者不掩盖项目错误。当前生产只有芽芽、铁山，四角色四属性与24人长名单由隔离UI夹具验证；真实迷宫入场验证生产单人/双人，不凭夹具声称已添加生产四人队伍。未在本执行任务写入或验收 `F:/maze_code`，该步骤留给来源主会话。

## 同票视觉复审修正（R1）

来源主会话复审指出三列详情可见顶部不齐、到底文案缺两侧短线。修正统一三列标题高度28像素、标题下间距20像素；基础数值行、属性图和技能列表使用同一内容起点。属性图半径上限77像素且顶部锚定，剩余高度只在底部留白，不再把图形纵向重新居中。技能通过 `team_entry_skill_list.gd`（入口技能列表）逐项排版，条目之间为独立细线，全文依旧自动换行和滚动；列表末尾通过居中横向容器排列165像素短线、文案、165像素短线。

`r1_final_flow` 的233项检查全部通过，保留双分辨率33张实际截图，正式存档指纹一致。报告直接记录三列详情起点：1152×648均为y=344；1280×720均为y=368。`reference_team_1152x648.png` 和 `reference_team_1280x720.png` 为无辅助线的实际界面证据；`fixture_list_end_1152x648.png` 和1280版本验证到底文案及两侧短线整体可见。新增断言检查三列同高、真实技能分隔线节点、两侧等长短线。业务、存档与进入流程未改变。

本节证据优先于前文首次交付截图。复验可继续使用同一运行器并将输出目录设为 `output/team_entry_ui_02/r1_final_flow`。

R1导入检查：首轮 `r1_import` 在重建507项资源缓存时记录4次 `get_multiple_md5` 的 `f.is_null()` 错误，未隐藏为环境警告。缓存重建完成后保持代码不变再运行 `r1_import_retry1`，项目错误为空且退出0；具体首轮文件来源未由引擎日志给出，因此不声称已经定位资源根因。证书及编辑器设置目录权限警告仍单列。R1流程使用的真实场景/资源均已通过实际渲染验收，最终主场景烟测见 `r1_smoke`。
