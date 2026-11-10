extends "res://tools/tests/fenshui_ranged_hitstop_state.gd"

var monster_rules: Script

func _scenarios() -> void:
 var path:="res://scripts/maze/monster_combat.gd"
 _check(ResourceLoader.exists(path),"共用怪物战斗模块存在")
 if not ResourceLoader.exists(path): return
 monster_rules=load(path)
 _check(monster_rules!=null,"怪物模块可加载，不依赖场景或单例")
 if monster_rules==null: return
 _catalog_and_compatibility()
 _eligibility()
 _all_attacks()
 _hit_fields()
 for slot in [0,1]:
  _remote_case(slot,50)
  _remote_save_failure(slot)
 _parallel_shots()
 _case(70)
 _miss()
 _save_failure()
 _death_transaction()

func _catalog_and_compatibility() -> void:
 var old=load("res://output/monster-combat-20261107/baseline/scripts/maze/team_attack.gd")
 var old_combat=load("res://output/monster-combat-20261107/baseline/scripts/maze/combat_simulation.gd")
 _check(monster_rules.STATS==old_combat.STATS,"十种魔物完整基础参数与冻结M一致")
 var run: Dictionary=baseline[Run.KEY].duplicate(true)
 Run.ensure_region(run,"maze_entry")
 Run.ensure_region(run,"salt_pool")
 Run.ensure_region(run,"fenshui")
 run.combat.frog_unlocked=true
 var kinds: Dictionary={}
 for row in Run.Catalog.rows(run.combat,true):
  if kinds.has(row.kind): continue
  kinds[row.kind]=true
  run.combat.region=str(row.get("region","maze_entry"))
  for amount in [0,1,8,200]:
   var before: Dictionary=run.duplicate(true)
   before.monsters[row.id].status="alive"
   var expected: Dictionary=before.duplicate(true)
   var actual: Dictionary=before.duplicate(true)
   old.damage(expected,row.id,amount)
   monster_rules.damage(actual,row.id,amount)
   _check(actual==expected,"十种魔物与冻结M同输入伤害/反击/受击字段一致：%s/%d" % [row.kind,amount],{"expected":expected.combat.actors[row.id],"actual":actual.combat.actors[row.id]})
  _check(monster_rules.fresh_actor(row.kind,row.position)==Run.Combat.fresh_actor(row.kind,row.position),"原演员初始字段保持："+row.kind)
 _check(kinds.size()==10,"覆盖当前十种魔物，不只鱼鳗蛙")
 var lesson: Dictionary=run.duplicate(true)
 lesson.combat.region="maze_entry"
 lesson.combat.slime_lesson={"enabled":true,"attack_read":true,"switch_read":false,"completed":false,"hits":0}
 var expected: Dictionary=lesson.duplicate(true)
 old.damage(expected,"slime_1",999)
 monster_rules.damage(lesson,"slime_1",999)
 _check(lesson==expected and lesson.combat.actors.slime_1.hp==1,"教学保命及命中计数不被共用模块绕过")

func _eligibility() -> void:
 var run: Dictionary=baseline[Run.KEY].duplicate(true)
 _check(monster_rules.eligible(run,ID),"正常存活当前图鱼可锁定及受击")
 for status in ["pending","captured","failed","skipped"]:
  var sample: Dictionary=run.duplicate(true)
  sample.monsters[ID].status=status
  _check(not monster_rules.eligible(sample,ID),"非存活状态拒绝选敌："+status)
 for change in ["dead","return","region","missing_actor","missing_monster"]:
  var sample: Dictionary=run.duplicate(true)
  if change=="dead": sample.combat.actors[ID].hp=0
  elif change=="return": sample.combat.actors[ID].mode="return"
  elif change=="region": sample.combat.region="maze_entry"
  elif change=="missing_actor": sample.combat.actors.erase(ID)
  elif change=="missing_monster": sample.monsters.erase(ID)
  _check(not monster_rules.eligible(sample,ID),"无效目标拒绝且不解引用缺项："+change)
  var before: Dictionary=sample.duplicate(true)
  var feedback: Array=[]
  monster_rules.impact(sample,ID,8,"hero",POINT,Vector2.RIGHT,feedback)
  _check(sample==before and feedback.is_empty(),"被拒绝目标不扣血/计数/发事件："+change)
 _check(not monster_rules.eligible(run,"not_a_monster"),"未知身份拒绝")
 var frog: String=Run.Catalog.Frog.ID
 run.monsters[frog].status="alive"
 run.combat.frog_unlocked=true
 run.combat.actors[frog].frog_phase="dormant"
 run.combat.actors[frog].hp=96
 _check(monster_rules.eligible(run,frog),"已解锁巨蛙水中满血待机可选")
 run.combat.actors[frog].frog_phase="emerging"
 _check(not monster_rules.eligible(run,frog),"旧出水阶段不误开")

func _all_attacks() -> void:
 var complete: Dictionary=baseline[Run.KEY].duplicate(true)
 for region in ["maze_entry","salt_pool","fenshui"]: Run.ensure_region(complete,region)
 var covered: Dictionary={}
 for row in Run.Catalog.rows(complete.combat,true):
  if covered.has(row.kind): continue
  covered[row.kind]=true
  var region: String=row.get("region","maze_entry")
  for slot in 3:
   sm.data=baseline.duplicate(true)
   sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
   var run: Dictionary=sm.data[Run.KEY]
   Run.ensure_region(run,region)
   for id in run.monsters: run.monsters[id].status="alive" if id==row.id else "skipped"
   var c: Dictionary=run.combat
   var a: Dictionary=c.actors[row.id]
   var point:=Vector2.INF
   var at:=Run.Combat.vec(a.position)
   for angle in 32:
    var candidate:=at+Vector2.RIGHT.rotated(TAU*angle/32.0)*45.0
    if sm.maze_terrain(region).is_walkable(candidate) and Run.Combat.Skills.clear_line(candidate,at,region):
     point=candidate
     break
   _check(point.is_finite(),"原地形真实攻击站位：%s/%d" % [row.kind,slot])
   if not point.is_finite(): continue
   if row.kind=="silverfish":
    a.fish_origin=a.position.duplicate()
    a.fish_aim=[0.0,1.0]
    a.fish_hit=false
    Fish.phase(a,"recover",2.5)
   c.cooldown=0.0
   c.action_left=0.0
   _check(sm.record_maze_location(region,point).success and Run.valid(run),"十种魔物实战检查点合法：%s/%d" % [row.kind,slot])
   timing=load("res://scripts/maze/axe_hitstop.gd").new()
   timing.configure(70)
   timing.configure_ranged(50)
   _check(Run.combat_command(sm,"select",slot).success,"十种魔物真实选择三招：%s/%d" % [row.kind,slot])
   var hp:=float(a.hp)
   var events: Array=[]
   _check(Run.combat_attack(sm,point,point.direction_to(at)).success,"十种魔物从原攻击入口出招：%s/%d" % [row.kind,slot])
   for i in 100:
    var result:=Run.combat_tick(sm,point,0.01,Rect2(),false,timing)
    _check(result.success,"三招真实事务推进：%s/%d" % [row.kind,slot])
    events.append_array(result.get("hit_feedback",[]))
    if Run.snapshot(sm).combat.actors[row.id].hp<hp: break
   var after: Dictionary=Run.snapshot(sm)
   _check(after.combat.actors[row.id].hp<hp and after.combat.hits==1,"三招经共用结算只命中一次：%s/%d" % [row.kind,slot])
   _check(events.size()==1 and events[0].id==row.id and timing.paused(row.id),"同事务发布命中及目标卡肉：%s/%d" % [row.kind,slot])
   _check(Run.valid(after),"真实命中后状态仍满足原存档规则：%s/%d" % [row.kind,slot])

func _hit_fields() -> void:
 var old=load("res://output/monster-combat-20261107/baseline/scripts/maze/combat_simulation.gd")
 for fields in [{},{"hit_remaining":0.12,"hit_velocity":[100.0,0.0],"flash_remaining":0.1},{"hit_remaining":0.0}]:
  _check(monster_rules.valid_hit(fields)==old._valid_hit(fields),"旧档缺省及正常受击字段校验保持")
 for key in ["hit_remaining","flash_remaining","hit_velocity"]:
  for invalid in [-1,"bad",NAN,1.0,[INF,0],[151.0,0]]:
   var fields: Dictionary={key:invalid}
   _check(monster_rules.valid_hit(fields)==old._valid_hit(fields),"损坏受击字段拒绝口径保持："+key+str(invalid))

func _death_transaction() -> void:
 _remote_reset(0,50)
 sm.data[Run.KEY].combat.actors[ID].hp=1.0
 _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"击杀从原真实锅铲入口发出")
 for i in 80:
  var result:=_tick(0.01)
  _check(result.success,"击杀正常探索事务推进")
  if Run.snapshot(sm).combat.actors[ID].hp<=0.0: break
 var run: Dictionary=Run.snapshot(sm)
 var hit_count: float=run.combat.hits
 _check(run.combat.actors[ID].hp==0.0 and not monster_rules.eligible(run,ID),"零生命立即失去锁定/自动瞄准资格")
 _check(not run.combat.actors[ID].has("hit_remaining") and run.combat.shots.is_empty(),"远程致死清击退及已命中弹体")
 _check(run.monsters[ID].get("experience_generation",-1)==run.monsters[ID].refresh_count,"击杀仍由原事务登记本生命代经验")
 _check(sm.save(),"击杀原状态可保存")
 sm.load_data()
 _check(Run.snapshot(sm).combat.actors[ID].hp==0.0 and Run.snapshot(sm).combat.hits==hit_count,"读档不复活或重放命中")
 _check(Run.defeat(sm,ID,POINT).success,"死亡后仍能进入原捕获流程")
 _check(Run.snapshot(sm).pending==ID and Run.snapshot(sm).monsters[ID].status=="pending","捕获状态仍唯一归原探索事务")
