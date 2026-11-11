extends "res://tools/tests/b03_baseline.gd"
const EXPECT={"slime":[14,3,20],"snail":[28,5,35],"beetle":[21,4,35],"lizard":[84,8,150],"silverfish":[20,4,25],"thunder_eel":[30,5,40],"wind_frog":[96,6,120],"mimic_crab":[28,5,35],"blind_scorpion":[22,4,30],"rockmane":[120,8,150]}
func _run() -> void:
 sm=get_node("/root/SaveManager");tm=get_node("/root/TutorialManager")
 _check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_b02_balance_isolated","双重隔离")
 if failures: get_tree().quit(1);return
 var run:=_new_run(TEAMS.story,10,1)
 for kind in EXPECT:
  _check(Combat.STATS[kind].hp==EXPECT[kind][0],kind+"批准生命")
  _check(Combat.STATS[kind].attack==EXPECT[kind][1],kind+"批准攻击")
  _check(Combat.Balance.EXPERIENCE[kind]==EXPECT[kind][2],kind+"批准每人经验")
 for region in ["fenshui","salt_pool"]: Run.ensure_region(run,region)
 for row in Run.monsters_for(run):
  _check(run.combat.actors[row.id].hp==EXPECT[row.kind][0],row.id+"真实出发生命")
 var hp: float=run.combat.hp
 Combat.Frog.hurt(run,Vector2(100,100),Vector2(120,100))
 _check(hp-run.combat.hp==Skills.incoming_damage(run,6),"巨蛙实际攻击6")
 hp=run.combat.hp
 Combat.Rock.hurt(run,Vector2(100,100),Vector2(120,100))
 _check(hp-run.combat.hp==Skills.incoming_damage(run,8),"岩鬃兽实际攻击8")
 _frog_return()
 _xp_transactions()
 if _arg("--mode=")=="matrix":
  for team in TEAMS:
   for region in ["maze_entry","fenshui","salt_pool"]:
    for kind in ({"maze_entry":["snail","lizard"],"fenshui":["thunder_eel","wind_frog"],"salt_pool":["blind_scorpion","rockmane"]}[region]):
     for level in {"maze_entry":[1,5],"fenshui":[6,10],"salt_pool":[11,15]}[region]:
      _regional_battle(team,region,kind,level)
 if _arg("--mode=")=="scene":await _scene_sample()
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples,"battles":battles,"user_dir":OS.get_user_data_dir()},"\t"))
 get_tree().quit(1 if failures else 0)

func _frog_return() -> void:
 var run:=_new_run(TEAMS.story,10,1)
 Run.ensure_region(run,"fenshui")
 var a: Dictionary=run.combat.actors[Combat.Frog.Config.ID]
 a.hp=1;a.frog_phase="active";a.mode="return"
 a.position=Combat.pack(Combat.Frog.Config.HOME)
 run.combat.frog_unlocked=false
 Combat.Frog.advance(run,Combat.Frog.Config.Roads.SPAWN,0.1)
 _check(a.hp==96 and a.frog_phase=="dormant","巨蛙返巢恢复原版生命96")

func _regional_battle(team: String,region: String,kind: String,level: int) -> void:
 var run:=_new_run(TEAMS[team],level,1)
 Run.ensure_region(run,region)
 run.combat.frog_unlocked=true
 var terrain=Combat.terrain(region)
 var target: Dictionary={}
 for row in Run.monsters_for(run):
  if row.kind==kind:target=row;break
 _check(not target.is_empty(),"实战目标存在 "+kind)
 if target.is_empty():return
 var point: Vector2=target.position
 var placed:=false
 for radius in [70.0,110.0,150.0,190.0]:
  for index in 32:
   var candidate: Vector2=target.position+Vector2.RIGHT.rotated(TAU*index/32)*radius
   if terrain.is_walkable(candidate) and Skills.Tide.visible_line(candidate,target.position,region):
    point=candidate;placed=true;break
  if placed:break
 _check(placed,"合法实战站位 "+team+kind)
 if not placed:return
 run.combat.hero=Combat.pack(point)
 var slot:=1
 for index in TEAMS[team].size():
  if TEAMS[team][index] not in ["ahong","chengyan"]:slot=index+1;break
 Skills.select(run,slot)
 var total:=0
 for id in TEAMS[team]:total+=int(Growth.record(sm,id).attack)
 _check(run.combat.attack==total,"保留全队攻击 "+team+str(level))
 var initial_hp: float=run.combat.hp
 var elapsed:=0.0
 while elapsed<60 and run.combat.hp>0 and run.combat.actors[target.id].hp>0:
  point=Combat.vec(run.combat.hero)
  var at:=Combat.vec(run.combat.actors[target.id].position)
  var aim:=point.direction_to(at)
  Skills.attack(run,point,Vector2.RIGHT if aim.is_zero_approx() else aim)
  Combat.advance(run,point,1.0/30.0)
  elapsed+=1.0/30.0
 battles.append({"team":team,"region":region,"level":level,"kind":kind,"seconds":elapsed,"team_attack":total,"team_hp":initial_hp,"hp_lost":initial_hp-run.combat.hp,"remaining_hp":run.combat.actors[target.id].hp,"killed":run.combat.actors[target.id].hp<=0,"dead":run.combat.hp<=0,"throws":run.combat.throws,"hits":run.combat.hits,"policy":"一星四人队；第一名主动角色原地持续攻击；其他魔物保留；60秒封顶；不覆盖生命攻击"})
 _check(Combat.valid(run.combat),"实战状态合法 "+team+kind)

func _scene_sample() -> void:
 var run:=_new_run(TEAMS.story,5,1)
 var row: Dictionary={}
 for entry in Run.monsters_for(run):
  if entry.kind=="snail":row=entry;break
 var point: Vector2=row.position
 for index in 32:
  var candidate: Vector2=row.position+Vector2.RIGHT.rotated(TAU*index/32)*90
  if Roads.is_walkable(candidate) and Skills.Tide.visible_line(candidate,row.position,"maze_entry"):
   point=candidate;break
 sm.data[sm.MAZE_STATE_KEY].position=Combat.pack(point)
 sm.data[Run.KEY].combat.hero=Combat.pack(point)
 sm.save()
 var maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze);get_tree().current_scene=maze
 await get_tree().create_timer(0.8).timeout
 await _shot_b03("b02_scene_before")
 maze.capture_flow.window_focused=true
 await _send_key(KEY_1)
 var stop:=Time.get_ticks_msec()+18000
 while Time.get_ticks_msec()<stop and not maze.capture_flow.dialog.visible and not maze.capture_flow.attempt.visible:
  maze.capture_flow.window_focused=true
  var at:=Combat.vec(Run.snapshot(sm).combat.actors[row.id].position)
  await _mouse_at(maze.get_viewport().get_canvas_transform()*at)
  await get_tree().create_timer(0.12).timeout
 await get_tree().create_timer(0.7).timeout
 await _shot_b03("b02_scene_after")
 var after:=Run.snapshot(sm)
 _check(after.combat.actors[row.id].hp<28,"实际场景输入造成新生命目标伤害",{"hp":after.combat.actors[row.id].hp})
 _check(after.combat.actors[row.id].hp<=0,"实际场景击败28生命砖壳蜗牛")
 samples.append({"scene":"maze_entry","target":row.id,"hp":after.combat.actors[row.id].hp,"growth":sm.data[Growth.KEY].duplicate(true)})
 maze.queue_free();await get_tree().process_frame
 GameAudio.set_world_music(&"")

func _xp_transactions() -> void:
 for kind in EXPECT:
  var run:=_new_run(TEAMS.story,11,1)
  var region: String="maze_entry" if kind in ["slime","snail","beetle","lizard"] else ("fenshui" if kind in ["silverfish","thunder_eel","wind_frog"] else "salt_pool")
  if region!="maze_entry":
   _check(Run.change_region(sm,region,Combat.terrain(region).SPAWN).success,"经验样本真实跨区 "+kind)
  run=Run.snapshot(sm)
  var target: Dictionary={}
  for row in Run.monsters_for(run):
   if row.kind==kind:target=row;break
  var point: Vector2=Combat.terrain(region).SPAWN
  for radius in [40.0,70.0,100.0]:
   var found:=false
   for index in 32:
    var candidate: Vector2=target.position+Vector2.RIGHT.rotated(TAU*index/32)*radius
    if Combat.terrain(region).is_walkable(candidate):point=candidate;found=true;break
   if found:break
  # 事务夹具仅把目标置为最后1点生命；不作为平衡耗时样本。
  for id in run.monsters:run.monsters[id].status="skipped"
  run.monsters[target.id].status="alive"
  run.combat.actors[target.id].hp=1
  if kind=="wind_frog":
   run.combat.actors[target.id].frog_phase="warning"
   run.combat.actors[target.id].frog_left=1.0
  run.combat.hero=Combat.pack(point)
  Skills.Tide.open(run,target.position,1,10,Vector2.RIGHT)
  sm.data[Run.KEY]=run
  sm.data[sm.MAZE_STATE_KEY].position=Combat.pack(point)
  var path: String=sm._active_save_path
  var before: Dictionary=sm.data.duplicate(true)
  sm._active_save_path=""
  var failed:=Run.combat_tick(sm,point,0.01)
  _check(not failed.success and sm.data==before,"经验与致死事务保存失败回滚 "+kind)
  sm._active_save_path=path
  var result:=Run.combat_tick(sm,point,0.01)
  _check(result.success and Run.snapshot(sm).combat.actors[target.id].hp<=0,"实际致死推进 "+kind,result)
  for id in TEAMS.story:
   _check(Growth.record(sm,id).exp==EXPECT[kind][2],"每名队员批准经验 "+kind+" "+id,{"actual":Growth.record(sm,id).exp})
  _check(Run.combat_tick(sm,point,0.01).success,"重复推进成功 "+kind)
  for id in TEAMS.story:_check(Growth.record(sm,id).exp==EXPECT[kind][2],"同生命只发一次 "+kind+" "+id)
  _check(sm.save(),"经验保存 "+kind)
  sm.load_data()
  _check(Run.snapshot(sm).monsters[target.id].get("experience_generation",-1)==0 and Growth.record(sm,"yaya").exp==EXPECT[kind][2],"经验与回执读档一致 "+kind)
