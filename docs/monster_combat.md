# 怪物共用战斗模块与编辑器对接

## 当前交付

MonsterCombat是scripts/maze/monster_combat.gd中的纯状态类，供现有十种魔物复用。角色仍持有输入和锁定控制；怪物类集中基础属性、共同可攻击资格、玩家命中结算、受击字段及远程卡肉接入。不是把十种招式合成同一个AI，也不要求每个地图重新挂一套控制节点。

本轮沿模块设计技能选择小接口隐藏共用结算，保留既有调用入口和专属规则；只迁移实现，不重做素材或重新平衡。主区最终15组2328项、真实网页24项通过，8451为N。具体版本与边界见output/monster-combat-20261107/review.md；最终落地水花截图的局部矩形接缝尚未定位，不把功能通过等同于视觉无瑕。

## 接口及唯一来源

| 接口或来源 | 调用与责任 |
| --- | --- |
| MonsterCombat.STATS / fresh_actor(kind, point) | 十种魔物基础属性及原演员字段；Combat.STATS和fresh_actor保留兼容转发，没有另存属性副本 |
| MonsterCombat.eligible(run, id) | 玩家实际命中、主动锁定、自动瞄准和原最近目标共用资格；调用方继续检查视口、射程、遮挡和弹体生命代 |
| MonsterCombat.impact(run, id, amount, weapon, contact, direction, feedback, clock, source) | 完整玩家命中入口；接受原探索状态、实际接触点/方向和原局部时钟。source是远程弹体原出发点，省略时用玩家位置；事件在外层事务成功后发布 |
| TeamAttack.damage / impact / protected_slime | 现有兼容入口转发；damage为旧调用方已确认命中的直接伤害入口，不替代完整资格检查，不给新代码用来绕过impact |
| MonsterCombat.hit / clear_hit / valid_hit | 原受击字段的唯一纯状态实现；旧Combat入口兼容转发，包括原玩家击退工具，不新增玩家规则 |
| CaptureRun | 唯一生命、经验、捕获及保存事务；伤害失败回滚，命中事件和内存停顿不泄漏；没有新的死亡状态表 |

基础属性仍在原字段、单位和数值下工作。STATS迁移时与冻结M逐项相等。银鳞鱼windup/recover/hurt及反馈参数继续读取SilverfishEditor和data/maze/silverfish_editor.json，不因共用STATS而覆盖现有编辑参数。

## 已有独立政策

- 银鳞鱼岸水冲刺、搁浅、回水和保护由silverfish_combat负责。
- 电鳗放电、三次释放后力竭、短距离上岸和成泡由thunder_eel_combat负责。
- 巨蛙跳跃/反击/回血/水炮由wind_frog_combat及wind_frog_counter负责；最高点前后各0.10秒、落地同电鳗125水域和原回血规则不改。
- 岩鬃兽咆哮及地形追击由rockmane_combat负责。
- 其他普通怪原追击及攻击推进仍在combat_simulation；它与以上招式读取同一基础属性和玩家命中入口。
- 借电、巨蛙落地伤同图鱼鳗仍走原环境结算，不变成玩家攻击，不触发玩家反击或新增卡肉。

## 编辑器接入约束

编辑器调用既有TeamAttack/Combat转发入口仍兼容；需要显示有效目标时改用MonsterCombat.eligible，不复制一套资格。基础参数的源码归属已移至MonsterCombat.STATS；本轮没有新增编辑器写回协议、热更新机制或可调参数，不可只改Combat常量影子副本。

怪物专属参数继续路由到原政策类；不得把巨蛙特殊阶段或护膜策略简化成所有怪物的统一硬直。四向痛态、42/42/54固定命中尺寸和50/70毫秒局部卡肉仍按角色交付文档；角色600/900毫秒恢复不属于MonsterCombat的可编辑怪物硬直。

8777及output/combat-feel-runtime本轮不改。编辑器原任务停写及预算状态不因接收接口而自动恢复。

## 验收范围

tools/tests/monster_combat_state.tscn检查冻结M对照、十种魔物三招真实命中、共同资格、教学保命、受击字段、失败保存/恢复、同目标多弹、击杀经验与捕获接续。沿用原场景检查五图角色、Tab/Q、四向持痛、巨蛙反击/回血/范围及电鳗力竭。网页使用实际局域网入口、正常连续播放和专用无界面浏览器，不接管系统输入。

不承诺全部历史测试或编辑器已接入，不把纯状态通过当画面验收。主区整库导入与软件渲染警告沿前轮限制另列，新版stage严格导入和实际网页必须各自通过。

写作规则审查：已完成（本文）。
