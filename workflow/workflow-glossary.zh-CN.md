# 项目术语

- 战斗参数覆盖：combat_tuning，按组和字段保存用户选择范围内已存在技能的参数快照。定义见concepts/combat-tuning.zh-CN.md；面板、保存接口和Godot共用字段定义。允许解释为重新启动时读取的参数覆盖，禁止称为运行中自动热更新或正式存档。候选独有字段不路由到正式保存，训练开关也不保存。

- 怪物共用战斗结算：MonsterCombat（纯状态怪物战斗类），定义见concepts/monster-combat.zh-CN.md。集中基础属性、初始字段、共同可攻击资格、玩家伤害/受击/命中及局部停顿接入，沿用原探索事务。不代替怪物独立招式、地形、环境伤害、角色输入或编辑器，不另存生命；锁定、自动瞄准与真实攻击共用资格，仍各守原视口/射程限制。
  网页只读monster_combat中kinds为支持的种类，eligible为当前图可攻击编号；不接受控制，也不以观测字段存在代替实战通过。

- 角色共用战斗控制：PlayerCombatController（玩家持有的运行时战斗协调类），PlayerCombatRules（模拟与场景共用的正常区域能力判断）。定义见concepts/player-combat-controller.zh-CN.md。正常五图共用锁定、攻击及反馈安装，capture_flow兼容入口转发，不新存锁定或重复结算伤害；特殊剧情与旧试玩保留原规则。角色受击、锁定和地图脚底占位不可互相代替。

- 玩家受击恢复：hurt_recovery_left（combat内可选玩家受击恢复剩余秒数，0—2秒，旧档缺失按0），定义见concepts/fenshui-player-hurt.zh-CN.md。普通受击默认600毫秒、巨蛙落地默认900毫秒，实际以相应已保存参数为准；盐池岩鬃兽击飞撞硬障碍可刷新为2秒，撞怪只阻挡。暂停主动移动/新攻击并取消未完成攻击，保留原击退、已发投射物及已结算伤害；不是无敌、全局暂停或按动画可见性控制输入。

- 玩家受击显示：player_hurt_feedback（成功战斗事务返回的玩家受击显示事件数组），定义见concepts/fenshui-player-hurt.zh-CN.md。区分fish鱼撞、electric电击、water水枪、slam落地砸击及physical普通物理伤害；只跟随实际扣血且保存成功，不写存档。正常五图复用已认可四向人物痛态；physical不套水电接触图。显示不改变伤害、方向、位移或无敌，控制恢复由原战斗状态负责，不把作者预览当游戏验收。

- 分水庭飞行道具显示：只读原战斗弹体并派生认可的图、短尾和残影，不新增命中；水枪按内容前端挂点并随已行距离揭出尾部。具体尺寸口径、模式边界及复验见concepts/fenshui-projectile-visual.zh-CN.md。

- 分水庭局域网网页试玩：独立浏览器体验，不是静态预览；fenshuiStatus是页面只读运行观测，不接受控制命令。定义见concepts/fenshui-web-trial.zh-CN.md。

- 巨蛙水中回血（旧称巨蛙静水恢复）：frog_heal_quiet（连续水中未受有效攻击秒数），定义见concepts/fenshui-heal-hit-feedback.zh-CN.md。水中连续2秒未受有效攻击后恢复，交战中同样生效；不要求脱战或回中央，不表示离线补时或瞬间满血。旧名称不再用来推导“仅待机回血”。
- 分水庭真实命中显示事件：hit_feedback，定义见concepts/fenshui-heal-hit-feedback.zh-CN.md。仅成功事务返回，不写存档；protected表示本次命中仍被水保护，不是独立护盾生命。受保护的有效命中同样显示，不做身体挤压或全身白闪。2026-11-05改用用户确认的水彩原PNG三格，替代程序笔触；锅铲/芽芽/铁山全格宽度候选标定42/42/54世界单位，鱼鳗蛙同招式同大。不继承身体体型、额外1.4倍、受击挤压或旋转；时长、原预览展开淡出、层级及巨蛙高度纯平移保留。不得把历史48/58/100身体宽度倍率继续套在新原图上，程序通过不代替美术终验。

- 巨蛙最高点反击窗口：沿本跳时长中点前后各0.10秒，0.8秒跳跃对应起跳后0.30至0.50秒。定义见concepts/wind-frog-counter.zh-CN.md。按实际玩家命中时刻判断，不按按键时刻；窗外仍按原规则扣血但不打翻，环境电不能代替反击，不扩大攻击范围或改变跳跃轨迹。

- 迷宫脚底占位（原分水庭脚底占位）：fenshui_bodies（脚底占位辅助），定义见concepts/fenshui-body-occupancy.zh-CN.md。常规迷宫按当前区域的紧凑地面椭圆阻止存活角色互穿，枯水渠、分水庭、盐池已有局部检查，剧情对练和fs01_trial保留例外；允许旧重叠向外恢复，不代表保护膜碰撞、空中轨迹墙、推人或完整图片碰撞。

- 目标锁定显示消费者：target_lock_marker，定义见concepts/monster-target-lock.zh-CN.md视觉章节。仅绘制已确认的倒三角，消费场景锁定结果与动作锚点；不自行选敌、不接收输入、不写存档，预览认可与实机验收分开。

- 分水庭回水冒汗表现：真实回水时的纯视觉反馈，定义见 concepts/fenshui-return-water-visual.zh-CN.md。鱼鳗绑定 returning（回水）及 forming（入水收尾）；巨蛙仅 return（返回）腾空越岸到落水，不包含全水域归位。不得解释为新增恐惧、加速、离岸玩法或正式生图完成。

- 迷宫目标锁定：locked_target_id（当前场景锁定魔物编号，空值表示未锁定）；定义见concepts/monster-target-lock.zh-CN.md。玩家主动选择保持目标，未锁定时仍沿用原自动瞄准；正常五图由角色模块统一持有，非存档字段，不代表增程、跟踪或自动追击。剧情对练及特殊试玩保持原按键路由。

- 巨蛙四向整合显示字段：frog_facing（已提交显示朝向，0右前/1左前/2右后/3左后）；frog_spit_left（真实吐水后的释放/收势剩余显示时间，0—0.28秒）。定义见concepts/wind-frog-counter.zh-CN.md四向整套候选章节。仅作用于巨蛙身体和同向胜利/捕获，不是新增攻击硬直、重发水团或改捕获规则；旧档缺失可推导/回退，不能据此称美术终验或原生画面问题已解决。

- 巨蛙正式反击：frog_phase新增toppling（失衡翻落）、exposed（露腹弱点）、recovering（连续起身）；frog_air_duration为本跳时长，frog_counter_from为受击位置，frog_form_left为回水凝膜剩时，frog_wet记录上次水中状态。定义见concepts/wind-frog-counter.zh-CN.md。仅正式分水庭，实际玩家命中触发，环境电不能代替反击，不包含脱战回血。draw_direction_pose（指定方向连续姿态）与set_frog_motion_direction（完整动作方向设置）当前接受0右前、1左前、2右后、3左后完整18姿态；默认自动四向，固定方向仅保留核对入口。norm为每段原图参考宽度，透明画布大小不参与体型校准；body_center表示供保护膜使用的主体中心，新三向按原Alpha>=0.5定位口径处理极淡边缘，原右前保留原锚点，不删像素或逐帧拉伸。旧单向及关键姿态章节为历史，不覆盖当前候选能力；美术与最终集中验收另核。

- 命中停顿：axe_hitstop（沿用旋斧局部时钟标识）；定义见concepts/fenshui-axe-hitstop.zh-CN.md。铁山停当前挥斧与目标；远程只停锅铲／芽芽真实命中的目标，ranged_duration为远程配置秒数，ranged_left为各目标剩余秒数，ranged_step为当前步消耗秒数。正常五图自动采用远程50／铁山70毫秒，原隔离对照仍保留；旧特殊试玩和剧情对练不自动安装。不得解读为全局暂停、额外眩晕、所有技能默认或性能长帧修复；巨蛙身体暂停不连带暂停已经离体的水团。

- 分水庭局部范围借电：electric_serial（已结算放电序号）、electric_left（鱼或巨蛙破膜剩余秒数）、discharge（已结算释放阶段）；完整定义见concepts/fenshui-area-lightning.zh-CN.md。仅正式分水庭局部直线浅水区域，巨蛙受电不触发反击；禁止解读为单体连线、全池导电、盾生命或奖励凭证。125/1.2为已确认首版试调，不是最终平衡结论。

- 雷鳗岸水阶段：eel_phase（阶段）、eel_left（剩余秒数）、eel_origin（最后完整水中位置）、eel_path（已走过的合法短段）；定义见concepts/thunder-eel-shore.zh-CN.md。仅正式分水庭雷鳗，不扩为试玩、其他怪物或通用寻路；55世界像素只为首轮试调，不宣称平衡或路径已通过。

- 银鳞鱼岸水阶段：fish_phase（阶段）、fish_left（剩余秒数）、fish_origin（本次水中起点）、fish_aim（锁定方向）、fish_hit（本次已命中）；定义与范围见concepts/silverfish-shore.zh-CN.md。仅用于正式分水庭银鳞鱼，不代表试玩fs_phase、雷鳗、巨蛙或新的通用战斗框架；不得以字段存在代替行为验收。

- 分水庭v4低缓石台：原七处岛体改为玩家可直接进入的干地，定义见concepts/fenshui-terrain-v4.zh-CN.md。LOW_ISLANDS为已确认七台索引，air_walkable保留巨蛙空中避岛，island_blocks按消费者区分低台与高岛；不表示全岛删除或新增蛙岸上落点。

- 分水庭水体显示：定义见concepts/fenshui-water-visual.zh-CN.md。water-mask是由正式地形烘焙的显示遮罩，不是网页颜色估算或新的战斗判定；immersion是纯显示浸没量，foot_y是逻辑脚底的显示裁切参考，不写玩家位置。允许背景微流与人物足部显示，禁止据此修改速度、碰撞、伤害或水陆规则。

- 分水庭电鳗力竭：定义见concepts/thunder-eel-exhaustion.zh-CN.md。eel_discharges为单只已完成放电次数，exhausted为第三次完成后的4秒无膜禁行动阶段；旧档缺次数视为0，恢复沿原forming成泡，不回血。允许用于正式电鳗状态、保护与显示，禁止把蓄力、命中次数、全场放电序号或网页演示间隔当成完成计数或生产参数。

- 芽芽连发（旧称种子五连发）：定义见concepts/yaya-seed-burst.zh-CN.md。seed_remaining为剩余颗数，seed_wait为下一颗等待秒数，seed_damage为本轮单颗整数伤害。burst_count为每轮颗数，burst_interval为逐颗秒数，burst_damage_scale为单颗百分比，burst_cooldown为整轮最短间隔。四项仅8777候选，不能正式保存；024默认3发，5发仅历史，不表示固定不可调。锁定时逐颗瞄准锁定对象，脱锁才按当前朝向扫射；已发弹体不追踪，不据此宣称正式游戏已采用。

