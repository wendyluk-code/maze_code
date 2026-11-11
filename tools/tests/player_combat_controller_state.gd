extends "res://tools/tests/fenshui_ranged_hitstop_state.gd"

const SCENES={"maze_entry":"maze_entry","fenshui":"maze_fenshui","salt_pool":"maze_salt_pool","moss_pool":"maze_moss_pool","waterkeeper_cottage":"maze_waterkeeper_cottage"}
var slime_checkpoint: Dictionary
var slime_point:=Vector2.ZERO

func _scenarios() -> void:
 for region in SCENES:
  sm.data=baseline.duplicate(true)
  var run: Dictionary=sm.data[Run.KEY]
  Run.ensure_region(run,region)
  var terrain=sm.maze_terrain(region)
  var spawn: Vector2=terrain.SPAWN
  run.combat.hero=Run.Combat.pack(spawn)
  _check(sm.record_maze_location(region,spawn).success,"正常入口站位保存："+region)
  var maze: Node2D=load("res://scenes/"+SCENES[region]+".tscn").instantiate()
  get_tree().root.add_child(maze)
  maze.capture_flow.set_process(false)
  var controller: Node=maze.player.get("combat_controller")
  _check(is_instance_valid(controller),"角色持有共用控制模块："+region)
  if is_instance_valid(controller):
   _check(controller.get_parent()==maze.player and maze.capture_flow.player_combat==controller,"地图复用角色同一个模块："+region)
   _check(maze.capture_flow.target_lock_enabled(),"正常五图均启用主动锁定："+region)
   _check(maze.capture_flow.axe_hitstop!=null and is_equal_approx(maze.capture_flow.axe_hitstop.state.duration,0.07) and is_equal_approx(maze.capture_flow.axe_hitstop.state.ranged_duration,0.05),"正常五图共用50/70卡肉："+region)
   _check(maze.capture_flow.player_hurt_visual.refined_pose,"正常入口直接安装持续四向痛态："+region)
   _check(maze.capture_flow.skill_visual.flow==maze.capture_flow,"正常入口安装实际攻击显示："+region)
   var c: Dictionary=run.combat.duplicate(true)
   c.hp=10.0
   c.action="tieshan"
   c.action_left=0.4
   c.axe_pending=true
   var events: Array=[]
   Run.Combat.PlayerHurt.record(c,12.0,"physical",spawn,spawn+Vector2.LEFT,events)
   _check(events.size()==1 and is_equal_approx(c.hurt_recovery_left,0.6) and c.action_left==0.0 and not c.axe_pending,"普通真实扣血生成600毫秒恢复并取消未发攻击："+region)
   var before: Dictionary=c.duplicate(true)
   Run.Combat.PlayerHurt.record(c,10.0,"physical",spawn,spawn,events)
   _check(c==before and events.size()==1,"零伤不重置硬直或补发事件："+region)
  maze.free()

 # 旧试玩与剧情对练沿原路由，不因跨地图能力扩展而误开。
 var trial: Dictionary=baseline[Run.KEY].combat.duplicate(true)
 trial.fs01_trial=true
 _check(not Run.Combat.PlayerHurt.enabled(trial),"旧特殊试玩不新增硬直")
 trial.fs01_trial=false
 trial.lock_left=-1.0
 _check(not Run.Combat.PlayerHurt.enabled(trial),"剧情对练不新增正常探索硬直")
 _independent_sources()

func _independent_sources() -> void:
 for slot in [0,1,2]:
  var point:=_rock_reset(slot)
  if not point.is_finite(): return
  var id: String=Run.Catalog.Rock.ID
  var hp: float=Run.snapshot(sm).combat.actors[id].hp
  _check(Run.combat_attack(sm,point,point.direction_to(Run.Catalog.Rock.HOME)).success,"盐池三招真实攻击岩鬃兽："+str(slot))
  for i in 80:
   _check(Run.combat_tick(sm,point,0.01,Rect2(),false,timing).success,"岩鬃兽原事务推进："+str(slot))
   if Run.snapshot(sm).combat.actors[id].hp<hp: break
  var hit: Dictionary=Run.snapshot(sm).combat.duplicate(true)
  _check(hit.actors[id].hp<hp and timing.paused(id),"岩鬃兽实际扣血触发对应50/70毫秒停顿："+str(slot))
  _check(Run.combat_tick(sm,point,0.02,Rect2(),false,timing).success,"推进首领命中停顿事务")
  var held: Dictionary=Run.snapshot(sm).combat
  _check(held.actors[id].position==hit.actors[id].position and held.actors[id].hit_remaining==hit.actors[id].hit_remaining and held.actors[id].rock_left==hit.actors[id].rock_left,"岩鬃兽位移、击退和咆哮阶段不在卡肉后台走完")
  _check(held.elapsed>hit.elapsed and held.cooldown<hit.cooldown,"目标停顿不冻结全场或玩家冷却")
  for i in 32: Run.combat_tick(sm,point,0.01,Rect2(),false,timing)
  var after: Dictionary=Run.snapshot(sm).combat
  _check(not timing.paused(id) and after.actors[id].hit_remaining<=0.0 and after.actors[id].rock_left<hit.actors[id].rock_left and after.hits==hit.hits,"岩鬃兽卡肉后原速恢复且不重复伤害")
 var point:=_rock_reset(0,"charge")
 var c: Dictionary=sm.data[Run.KEY].combat
 c.actors[Run.Catalog.Rock.ID].rock_left=0.01
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 _check(not Run.combat_tick(sm,point,0.01,Rect2(),false,timing).success and sm.data==before,"咆哮保存失败不采用伤害或受击恢复")
 sm._active_save_path=path
 var result:=Run.combat_tick(sm,point,0.01,Rect2(),false,timing)
 c=Run.snapshot(sm).combat
 var events: Array=result.get("player_hurt_feedback",[])
 _check(result.success and c.hp<before[Run.KEY].combat.hp and events.size()==1 and events[0].kind=="physical" and is_equal_approx(c.hurt_recovery_left,0.6),"岩鬃兽真实咆哮成功事务发布普通600毫秒受击，不冒充水电")
 _check(sm.save(),"咆哮受击可保存")
 var left: float=c.hurt_recovery_left
 sm.load_data()
 _check(is_equal_approx(Run.snapshot(sm).combat.hurt_recovery_left,left),"读档保留剩余硬直，不重放完整时长")
 _slime_source(true)
 _slime_source(false)
 _slime_cast_clock()

func _rock_reset(slot: int, phase: String="rest") -> Vector2:
 # 本组只验证单次命中时钟；多发连发另由 yaya_burst_flow 验证。
 var tuning=Run.Combat.Skills.Tuning
 if not tuning.values.has("effect.yaya"): tuning.values["effect.yaya"]={}
 tuning.values["effect.yaya"]["burst_count"]=1
 sm.data=baseline.duplicate(true)
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 var run: Dictionary=sm.data[Run.KEY]
 Run.ensure_region(run,"salt_pool")
 for id in run.monsters: run.monsters[id].status="alive" if id==Run.Catalog.Rock.ID else "skipped"
 var point:=Vector2.INF
 for angle in 16:
  var candidate: Vector2=Run.Catalog.Rock.HOME+Vector2.RIGHT.rotated(TAU*angle/16.0)*40.0
  if Run.Combat.terrain("salt_pool").is_walkable(candidate) and Run.Combat.Skills.clear_line(candidate,Run.Catalog.Rock.HOME,"salt_pool"):
   point=candidate
   break
 _check(point.is_finite(),"岩鬃兽沿原地形布置合法实战站位")
 if not point.is_finite(): return point
 run.combat.hero=Run.Combat.pack(point)
 run.combat.cooldown=0.0
 run.combat.action_left=0.0
 var a: Dictionary=run.combat.actors[Run.Catalog.Rock.ID]
 a.mode="chase"
 a.rock_phase=phase
 a.rock_left=1.1
 a.rock_aim=Run.Combat.pack(Run.Catalog.Rock.HOME.direction_to(point))
 _check(sm.record_maze_location("salt_pool",point).success and Run.valid(Run.snapshot(sm)),"岩鬃兽检查点通过原探索校验")
 timing=load("res://scripts/maze/axe_hitstop.gd").new()
 timing.configure(70)
 timing.configure_ranged(50)
 _check(Run.combat_command(sm,"select",slot).success,"选择真实首领攻击招式")
 return point

func _slime_source(guarded: bool) -> void:
 sm.data=baseline.duplicate(true)
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 var run: Dictionary=sm.data[Run.KEY]
 Run.ensure_region(run,"maze_entry")
 # 分别覆盖原双人及单芽芽队伍；快照的比例防御不再把正攻击抵消为零。
 if not guarded:
  run.members=[run.members[0]]
  run.food_cursor=0
 var id:="slime_2"
 for key in run.monsters: run.monsters[key].status="alive" if key==id else "skipped"
 var a: Dictionary=run.combat.actors[id]
 var origin:=Run.Combat.vec(a.position)
 var point:=Vector2.INF
 for angle in 16:
  var candidate:=origin+Vector2.RIGHT.rotated(TAU*angle/16.0)*60.0
  if Roads.is_walkable(candidate) and Run.Combat.clear_line(origin,candidate,Roads.FOOT_RADIUS):
   point=candidate
   break
 _check(point.is_finite(),"史莱姆吐弹沿原道路建立合法站位")
 if not point.is_finite(): return
 run.combat.hero=Run.Combat.pack(point)
 run.combat.enemy_shots=[]
 a.mode="chase"
 a.cast=0.01
 a.cast_aim=Run.Combat.pack(origin.direction_to(point))
 a.skill_reuse=2.4
 _check(sm.record_maze_location("maze_entry",point).success and Run.valid(Run.snapshot(sm)),"真实吐弹检查点有效")
 var hp: float=run.combat.hp
 if not guarded:
  slime_checkpoint=sm.data.duplicate(true)
  slime_point=point
 var expected_damage:=maxi(1,ceili(3.0*maxf(0.25,20.0/(20.0+Run.Combat.Skills.defense(run)))))
 _check(Run.Combat.Skills.incoming_damage(run,3)==expected_damage,"吐弹对照采用快照比例防御，不更改怪物伤害")
 var events: Array=[]
 for i in 60:
  var result:=Run.combat_tick(sm,point,0.01)
  _check(result.success,"原吐弹实际推进")
  events.append_array(result.get("player_hurt_feedback",[]))
  if not events.is_empty(): break
 var c: Dictionary=Run.snapshot(sm).combat
 _check(is_equal_approx(c.hp,hp-expected_damage) and events.size()==1 and events[0].kind=="physical" and is_equal_approx(c.get("hurt_recovery_left",0.0),0.6),"史莱姆实际吐弹按队伍防御扣血并发布600毫秒普通受击："+("双人" if guarded else "单人"),{"before_hp":hp,"combat":c,"events":events,"point":str(point),"origin":str(origin)})

func _slime_cast_clock() -> void:
 if slime_checkpoint.is_empty(): return
 sm.data=slime_checkpoint.duplicate(true)
 var c: Dictionary=sm.data[Run.KEY].combat
 c.cooldown=0.0
 c.selected=0
 c.actors.slime_2.cast=0.65
 timing=load("res://scripts/maze/axe_hitstop.gd").new()
 timing.configure(70)
 timing.configure_ranged(50)
 _check(Run.combat_attack(sm,slime_point,slime_point.direction_to(Run.Combat.vec(c.actors.slime_2.position))).success,"真实锅铲命中正在蓄力的史莱姆")
 for i in 80:
  Run.combat_tick(sm,slime_point,0.01,Rect2(),false,timing)
  if timing.paused("slime_2"): break
 var hit: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check(timing.paused("slime_2") and hit.actors.slime_2.cast>0.0,"蓄力中实际命中触发目标停顿")
 _check(Run.combat_tick(sm,slime_point,0.02,Rect2(),false,timing).success,"推进史莱姆目标停顿")
 var after: Dictionary=Run.snapshot(sm).combat
 _check(is_equal_approx(after.actors.slime_2.cast,hit.actors.slime_2.cast) and after.actors.slime_2.skill_reuse<hit.actors.slime_2.skill_reuse,"史莱姆蓄力随身体卡肉，原技能冷却继续")
