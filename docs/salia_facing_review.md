# 萨莉亚战斗与战后朝向修复检查点

目标 F:/maze_code，HEAD f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910，分支 codex/freezer-01，保留现有未提交改动。下文前半为历史检查点，后续进展见文末。

已修复：scripts/maze/yufeng_salia_encounter.gd 的独立人物朝向不再读取开场缓存 attention，改为主角当前位置。御风和萨莉亚战后对白及后续赠礼、告别使用当前主角位置确定左右面向，现有侧身待机素材不变。

实测：
tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/yf04_flow.tscn -OutputRoot output/yf_facing_dialog
双分辨率177项通过，无脚本或资源错误，正式存档指纹未变。tools/tests/yf04_flow.gd 增加战后主角左右位置与相反旧 attention、战后读档朝向验证；完整既有切磋、20%停战、赠礼和便当流程通过。目检 post_1152x648.png。日志另有“迷宫站位无效，恢复当前区域入口安全点”诊断，未作为脚本错误；左右面向测试采用显示用受控站位并在保存前恢复真实站位。

剩余：萨莉亚施法六帧 assets/characters/yf02/03_salia_cast/frame_00..05.png 本身是正面画，翻转无法获得侧面。现有 salia_idle_0.png 和 salia_walk_0.png 为朝右侧身，可用作身份和比例参考。已向用户展示完整改稿提示词，尚待确认，未生成或替换施法素材。使用 imagegen 技能和内置生图工具；沙箱 view_image 当前可能失败，可用提升的PowerShell读图转换小尺寸base64交给 image() 查看，原始素材已查看。图像生成前须按 AGENTS.md 第1.1节确认提示词，不重复确认已授权的战后代码修复。

待确认提示词：
以游戏现有萨莉亚侧身待机图为角色外观基准，参考旧六帧施法图的动作节奏，制作一张1536×1024、3列×2行的透明背景六帧动画图集，每格512×512。角色始终侧身朝右，视线与法杖指向右侧交战对象，不看镜头；保持紫色尖帽、棕色长卷发、紫色衣裙、金色法杖、原有手绘笔触与身体比例。六帧依次为准备、抬杖、蓄力、释放、回收、复位，动作连续，角色大小和脚底锚点一致，帽子和法杖完整留在格内。仅少量贴近杖尖的紫色电光，不画独立飞行弹丸、背景、文字、格线、地面或投影。交付透明图集并裁切为六张PNG，接入时按主角左右位置翻转，保留现有弹道特效。

接入注意：
- yufeng_salia_encounter.gd attach()加载03_salia_cast；_sync_visuals()在actor.cast>0时选择六帧。
- pose()依赖 data/maze/yf_sprite_layout.json 每张图的 rect/height。新素材需同步登记脚底锚点和统一身高，不能仅按每帧包围盒重新缩放造成跳动。
- 保存项目素材到项目目录，原生图保留；通过同一实际剧情场景补战斗中朝左/朝右及逐帧截图，不以替换成待机图冒充施法动画。

## 用户确认后接入侧身六帧（2026-10-27）

用户已明确确认上文完整改稿提示词及生成、裁切、接入范围。使用 imagegen 技能与内置 image_gen 工具，未使用CLI/API后备路径。参考原侧身待机图和旧正面施法图，重新生成准备、抬杖、蓄力、释放、回收、复位六帧。

最终生成源：exec-09786123-a34c-4b2d-a4ad-192519777039.png。原图复制到 assets/characters/yf02/03_salia_cast_side/source.png，六张标准化切片为 frame_00.png 至 frame_05.png，标准图集为 sheet.png。保留旧正面素材，运行时只将03_salia_cast加载源改为03_salia_cast_side，不改变御风或弹道素材。

生成的透明区域保留底色RGB，预览工具显示曾让背景看似不透明；实际alpha检查及白底合成确认透明。布局重试仍未严格满足等宽格线，最终按六个独立透明连通轮廓拆分，保留每个完整动作与电光，再统一0.62倍缩放、512×512画布与脚底(256,460)。不按每帧外框单独拉伸。data/maze/yf_sprite_layout.json新增六帧共同height=260.4和foot字段；pose仅在存在foot字段时使用显式脚底，其他素材维持原逻辑。

重现工具：tools/tests/salia_side_slice.ps1。该工具只处理透明轮廓分片及统一缩放，不绘制或替代施法原画。

提示词记录：
- 基础完整提示词见上文“待确认提示词”（现已确认）。
- 第二次仅要求保留六个侧身动作、修正真正透明alpha、严格3×2格、每格留32像素透明边、脚底y=460、杖端不超过x=475，移除背景及大范围光晕。
- 第三次仅针对布局：保持六动作与透明alpha，统一缩小至70%，人物站立身高约290，脚底每格y=420、双脚中心x=240，动作总宽不超过420，四边至少40像素透明留白，无文字格线地面投影。输出未严格遵循格线，采用上述无损轮廓拆分后标准化，不再继续生图。

验收：
- 隔离Godot编辑器导入退出0，日志 output/salia_side_import/import.log。
- tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/salia_side_cast.tscn -OutputRoot output/salia_side_cast_final：双分辨率145项通过，无脚本或资源错误，正式存档指纹未变。受控战斗阶段逐帧检查资源路径、左右翻转、脚底、统一缩放、透明角、恢复待机及战后双方朝向；这部分逐帧截图不是连续战斗录像。
- 首轮 output/salia_side_cast_v1 在新PNG尚未正式导入时出现加载失败，已完成编辑器导入后复验通过，保留原失败日志。
- 已目检1280×720朝左和朝右释放截图，没有正面转向、背景块或法杖裁断。
- output/salia_side_cast_final/salia_side_cast_preview.gif 由游戏内六帧截图裁切制作，准备和复位适当停留以便审阅；真实施法时长仍为0.48秒。生成入口 tools/tests/salia_side_preview.py。

可复用约定：生成多帧资源必须验证实际alpha、每帧轮廓完整和公共脚底；不能因透明像素RGB含底色就判断未透明。新增动作有不同抬杖高度时使用固定身体比例与显式脚底，避免用每帧外框独立缩放。替换素材、pose或朝向逻辑后重跑本专项和yf04_flow完整流程。
最终完整流程验收：tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/yf04_flow.tscn -OutputRoot output/salia_side_story_final，177项全部通过，无项目错误或环境告警，正式存档指纹未变。覆盖真实切磋推进、20%停战、战后双人面向主角、读档、赠礼与便当流程。侧身施法和战后朝向两项均已在 F:/maze_code 接入并通过相关集成验收。
