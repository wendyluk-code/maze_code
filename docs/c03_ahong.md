# C03 阿轰：雷鸣足迹

主区集成结果：来源主会话已审查提交 `3e0d76b69bdb3156749aef2315068fb28e6f5214` 并增量合入 `F:/maze_code`，保留组件库其他任务记录。目标实际代码经独立项目名及用户目录隔离运行：`output/c03_ahong_target_final` 221项、`output/c02_jiaopopo_c03_target_regression` 270项、`output/c01_dingdang_c03_target_regression` 306项均通过。`target_import` 和 `target_water` 通过，已查看实景。`target_smoke` 仍因基线退出资源占用告警被严格运行器判失败；无新增脚本错误，未访问正式存档，未做全游戏回放。

本票实现真实编队后的战斗移动被动。基线为 `52b8fbb613397976803436951a101f2b3e451e60`（`codex/character-c02-jiaopopo`），执行分支为 `codex/character-c03-ahong`。独立工作区为 `C:/Users/KSG/.codex/worktrees/0c92/maze_code`，主工作区 `F:/maze_code` 由来源主会话负责合入与集成验收。本票不修改主工作区、正式存档、地图布局或基础属性公式。

## 玩家行为与已确认边界

- 阿轰在当趟队伍中即可生效，无需切换阿轰或攻击。当前区域活体追击、蓄力，或已有主动动作、飞行弹丸时视为战斗；与原跨区战斗门禁一致，并计入巨蛙水团。
- 战斗移动累计48像素，且距上次生成至少0.6秒时，在当前位置留下一枚雷印。静止只消耗时间，不补发积攒印记；距离比较容差为0.001像素，以兼容 Godot 二维坐标精度。冲刺不绕过时间门槛。
- 地面半径24像素、持续3秒、最多6枚；触碰麻痹0.4秒，同一目标生命代数3秒内不重复。超限移除最旧一枚。
- 2星地面持续4秒，3星半径30，4星麻痹0.5秒，5星最多8枚，6星水域带电2秒；其余数值不变。
- 水中印记使同一连通浅水域带电1秒，6星2秒。用户已明确选择：带电结束后水中印记消失，不保留后续局部麻痹。
- 大型怪物也麻痹。用户已确认暂停移动、蓄力、动作计时；巨蛙腾空停住，解除后续接。已发射弹丸继续飞行。显示动画同步冻结，水团与动作推进分开。
- 雷印不调用伤害、命中次数、普通击退或锁印消费接口，不改变主角速度。脱战、死亡、跨区、重入及探索结束清理；暂停不推进。

## 接入与复用

`ahong_trail.gd` 保存本趟雷印、距离、间隔和目标复用时钟；怪物字典上的 `ahong_stun` 保存麻痹剩余时间。`combat_simulation.gd` 在有阿轰时采用最多1/120秒小步，并按实际位移分配小步位置，避免一次推进越过印记触发点。原无阿轰烟区推进规则保持不变。

`CaptureRun`（探索事务入口）统一保存与失败回滚；字段改变进入原事务提交，不直接访问存档文件。状态校验拒绝非有限数、越界时长和损坏怪物集合。重新进入会在恢复事务中清理瞬时效果。

`ahong_water.gd` 只读取现有分水庭 `is_walkable` 和 `terrain_multiplier` 判定。四像素网格建立连通域，每条格间边逐像素复查，禁止跨干路、岛体或栅栏连接；查询点与网格之间也须全程为水。盐池可走区域的减速不能等同于浅水，枯水渠与青苔池不触发此传导。`ahong_water_cache.json` 保存离线推导的行程压缩结果，启动时校验道路及栅栏源码的SHA-256（内容摘要，忽略换行格式）与算法版本；失效时按当前地形重建。缓存只用于地形连通与绘制，不写存档或改变地图。首次完整推导实测3718毫秒，缓存解码实测9.602毫秒；30160个网格逐格比对一致。修改连通算法须提升 CACHE_VERSION，修改地形后用专属构建脚本重新生成缓存。地形若新增小于四像素的细通道，需要重新验证精度与连通性。

UI复用 `combat_skill_bar`、`character_details_modal` 和原 `show_toast`。仅阿轰槽键帽显示“被动”，点击打开原详情；数字键给出被动说明，不改变当前主动技能，Tab沿用可选主动技能循环。其他角色选择交互不变。详情显示“不造成伤害”和移动触发条件。

视觉复用 `assets/ui/factions/lightning.png`，沿用萨莉亚紫金配色；地面环、受控标记和浅水遮罩均由只读状态绘制，没有新增生图或动画素材。图层位于背景上、实体下，椒婆婆烟层原顺序保留。声音沿用既有移动与战斗音效。

## 实际验收证据

测试入口 `tools/tests/c03_ahong_run.ps1` 使用独立项目名 `maze_c03_ahong_isolated`，并把 APPDATA、LOCALAPPDATA 和测试存档目录指向每次运行的专属 profile。脚本起始校验实际 `user://` 根路径，不读取或比对正式存档。Godot可执行文件已核验，实际为4.7.2；`project.godot` 的当前正式入口为 `scenes/start_screen.tscn`，不沿用旧文档的餐厅主场景缓存。

| 实际命令 | 结果与证据 |
| --- | --- |
| `./tools/tests/c03_ahong_run.ps1 -RunName delivery` | 221项全部通过，`output/c03_ahong_delivery/report.json` |
| `./tools/tests/c02_jiaopopo_run.ps1 -RuntimeName c03_ahong_runtime -RunName c03_regression` | 270项全部通过，`output/c02_jiaopopo_c03_regression/report.json` |
| `./tools/tests/c01_dingdang_run.ps1 -RuntimeName c03_ahong_runtime -RunName c03_regression` | 306项全部通过，`output/c01_dingdang_c03_regression/report.json` |
| `./tools/tests/c03_ahong_run.ps1 -Import -RunName import_final` | 退出0，无项目脚本/资源错误；环境提示见下 |
| `./tools/tests/c03_ahong_run.ps1 -WaterCheck -RunName cache_verified2` | 按当前地形重新推导并与缓存逐格比对通过；`output/c03_ahong_cache_verified2/stdout.log` |
| `./tools/tests/c03_ahong_run.ps1 -Smoke -RunName smoke_final` | 引擎退出0，无脚本加载错误；严格运行器因基线退出占用告警判失败，未计为全绿 |

专项覆盖真实编队、真实方向键普通移动/冲刺、战斗与非战斗、原地与暂停、四种推进步长、1–6星、上限淘汰与过期、3秒间隔、无伤害/不消费锁印、全部普通怪物种类、巨蛙腾空与水团、岩鬃兽蓄力、实际地形同水域/异水域、脱战/死亡/重入/跨区、保存失败与跨区失败回滚、损坏数据安全拒绝、技能栏详情和输入恢复。

截图位于 `output/c03_ahong_delivery/`：`c03_keyboard_walk.png`、`c03_keyboard_sprint.png`、`c03_ground_marks.png`、`c03_paralyzed.png`、`c03_passive_details.png`、`c03_water_conduction.png`、`c03_frog_air_stun.png`。已检查真实枯水渠与分水庭图像，测试未改变世界地图。

失败与修正记录：首次导入缺字体缓存，完成导入后消失；首次专项因测试函数 `_seed` 与父类签名冲突退出，已改为专属函数名。随后恰好48像素的坐标精度失败由0.001像素容差修正；路外弹丸、跨区布局混用属于夹具问题，分别修正。真实向左方向键移动用例沿水平方向被原地图岸线挡住，只走约34像素，日志确认战斗时钟正常；改用实际道路的左下方向后通过，未改游戏碰撞。缓存核验首次直接比较JSON数值与整数构建值导致类型比较失败，统一JSON往返后核验通过，并另行比较实际解码的全部网格。所有失败证据保留于对应 `output/c03_ahong_*` 目录，不作为通过结果。

环境提示：系统根证书读取失败；编辑器无法写安装目录的 `editor_settings-4.7.tres`；基线启用的 `addons/audio_mixer/plugin.cfg` 不在此工作树中。未修改这些来源。首次导入出现的字体加载失败已在最终导入消除。无头主入口退出仍报告基线已有的2个对象、1个资源占用；严格运行器保留失败状态，未屏蔽或宣称该检查全绿。专项场景与两组回归未出现该退出占用。

## 交接与重新审查条件

本票独立工作树验收通过不代表目标主区完成。来源主会话必须审查增量差异，保留主区用户改动，合入 `F:/maze_code` 后重跑上述相关验收。没有运行全游戏或所有剧情回归，没有验证新地图或未来动态水闸。

可复用的已验证知识：巨蛙动作与水团原本共用推进函数，控制逻辑必须区分动作时钟和已发射弹丸；仅冻结业务状态不足以冻结 `capture_monster` 的独立显示时钟；盐池地面减速并不等同浅水。修改怪物阶段、地形判定、进入/退出事务或角色技能栏时，应复查本票相应场景与保存失败用例。
