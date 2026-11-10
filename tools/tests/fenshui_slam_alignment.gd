extends "res://tools/tests/fenshui_player_hurt_state.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"落地范围对齐使用隔离存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HURT_POINT).success,"公开入口建立分水庭")
 original=sm.data.duplicate(true)
 seed_attack("slam")
 var point:=Vector2(1140,450)
 var hp: float=state().combat.hp
 var result:=Run.combat_tick(sm,point,0.1)
 _check(result.success and Boss.line(Vector2(1040,450),point) and state().combat.hp<hp,"主浪内100世界像素处必须受到真实落地伤害",{"success":result.success,"before":hp,"after":state().combat.hp})
 if failures==0:
  sm.data=original.duplicate(true)
  seed_attack("slam",false)
  var c: Dictionary=sm.data[Run.KEY].combat
  var fish: Dictionary=c.actors[FISH_ID]
  fish.position=[1100.0,450.0]
  fish.fish_origin=fish.position.duplicate()
  fish.fish_aim=[0.0,1.0]
  fish.fish_hit=false
  Run.Combat.Silverfish.phase(fish,"idle",0.0)
  var eel: Dictionary=c.actors["fenshui_thunder_eel_2"]
  eel.position=[1150.0,450.0]
  eel.eel_origin=eel.position.duplicate()
  eel.eel_path=[]
  Run.Combat.ThunderEel.phase(eel,"idle",0.0)
  _check(Run.valid(state()),"同图鱼鳗范围检查点合法",{"fish":Run.Combat.Silverfish.valid(fish),"eel":Run.Combat.ThunderEel.valid(eel),"frog":preload("res://scripts/maze/wind_frog_combat.gd").valid(c.actors[Boss.ID]),"fish_water":Boss.water(Vector2(1100,450)),"eel_water":Boss.water(Vector2(1150,450))})
  var fish_hp: float=fish.hp
  var eel_hp: float=eel.hp
  result=Run.combat_tick(sm,HURT_POINT,0.1)
  _check(result.success and state().combat.actors[FISH_ID].hp<fish_hp and state().combat.actors["fenshui_thunder_eel_2"].hp<eel_hp,"落地沿真实事务同时伤到主浪内的鱼和电鳗",{"fish_before":fish_hp,"fish_after":state().combat.actors[FISH_ID].hp,"eel_before":eel_hp,"eel_after":state().combat.actors["fenshui_thunder_eel_2"].hp})
 if failures==0:
  range_and_recovery()
  monster_recovery()
 _finish()

func range_and_recovery() -> void:
 var connected:=0
 var blocked:=0
 for angle in [0.0,PI/4.0,PI/2.0,PI*0.75,PI,PI*1.25,PI*1.5,PI*1.75]:
  for distance in [100.0,124.0,126.0]:
   var point: Vector2=Vector2(1040,450)+Vector2.RIGHT.rotated(angle)*distance
   if not Boss.Roads.is_walkable(point): continue
   sm.data=original.duplicate(true)
   seed_attack("slam")
   var hp: float=state().combat.hp
   var shape:=preload("res://scripts/maze/fenshui_electric_area.gd").polygon(Vector2(1040,450),"slam-regression")
   var line: bool=preload("res://scripts/maze/fenshui_electric_area.gd").contains(shape,point)
   var result:=Run.combat_tick(sm,point,0.1)
   var expected: bool=line
   if line and expected: connected+=1
   if not line: blocked+=1
   _check(result.success and (state().combat.hp<hp)==expected,"真实落地各方向内外与岸水隔断",{"angle":angle,"distance":distance,"connected":line,"expected_hit":expected,"hp":state().combat.hp})
   var frog_hit: bool=state().combat.hp<hp
   sm.data=original.duplicate(true)
   seed_attack("electric")
   hp=state().combat.hp
   result=Run.combat_tick(sm,point,0.1)
   _check(result.success and (state().combat.hp<hp)==frog_hit,"同中心同目标真实电鳗放电与巨蛙落地命中一致",{"angle":angle,"distance":distance,"frog_hit":frog_hit,"eel_hit":state().combat.hp<hp})
 _check(connected>=4 and blocked>=1,"边界样例同时包含多方向水内与岸路阻断",{"connected":connected,"blocked":blocked})
 sm.data=original.duplicate(true)
 seed_attack("slam")
 var before: float=state().combat.hp
 _check(Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.hp<before,"真实落地首次伤害")
 var after: float=state().combat.hp
 _check(Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.hp==after,"同次落地恢复不重复伤害")
 _check(is_equal_approx(float(state().combat.hurt_recovery_left),0.8),"扩大范围仍沿玩家900毫秒恢复，不另增硬直")
 _check(sm.save(),"新范围伤害通过原入口保存")
 sm.load_data()
 _check(Run.valid(state()) and Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.hp==after,"读档接续落地不补砸一次")
 sm.data=original.duplicate(true)
 seed_attack("slam")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_left=0.4
 a.position=[970.0,450.0]
 before=state().combat.hp
 _check(Run.valid(state()) and Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.hp==before,"腾空接近玩家仍不伤人")
 sm.data=original.duplicate(true)
 seed_attack("slam")
 var old: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var failed:=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(not failed.success and sm.data==old and failed.get("player_hurt_feedback",[]).is_empty(),"范围伤害保存失败完整回滚且无假受击显示")
 sm._active_save_path=path
 _check(Run.combat_tick(sm,HURT_POINT,0.1).success,"恢复保存后重新结算同一次落地")

func seed_monsters() -> void:
 sm.data=original.duplicate(true)
 seed_attack("slam")
 var c: Dictionary=sm.data[Run.KEY].combat
 for id in [FISH_ID,"fenshui_thunder_eel_2"]:
  sm.data[Run.KEY].monsters[id].status="alive"
  var a: Dictionary=c.actors[id]
  a.position=[1100.0,450.0] if id==FISH_ID else [1150.0,450.0]
  a.cooldown=10.0
  if id==FISH_ID:
   a.fish_origin=a.position.duplicate()
   a.fish_aim=[0.0,1.0]
   a.fish_hit=false
   Run.Combat.Silverfish.phase(a,"idle",0.0)
  else:
   a.eel_origin=a.position.duplicate()
   a.eel_path=[]
   Run.Combat.ThunderEel.phase(a,"idle",0.0)

func monster_recovery() -> void:
 seed_monsters()
 var c: Dictionary=sm.data[Run.KEY].combat
 var hits: int=c.hits
 var result:=Run.combat_tick(sm,HURT_POINT,0.1)
 var fish_hp: float=state().combat.actors[FISH_ID].hp
 var eel_hp: float=state().combat.actors["fenshui_thunder_eel_2"].hp
 _check(result.success and fish_hp<20.0 and eel_hp<30.0 and state().combat.hits==hits,"环境砸击保留水中减伤且不冒充玩家命中")
 _check(Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.actors[FISH_ID].hp==fish_hp and state().combat.actors["fenshui_thunder_eel_2"].hp==eel_hp,"同次落地不会反复扣鱼鳗生命")
 _check(sm.save(),"鱼鳗范围伤害与落地阶段共同保存")
 sm.load_data()
 _check(Run.valid(state()) and Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.actors[FISH_ID].hp==fish_hp,"鱼鳗伤害读档不重放")
 for scenario in ["outside","captured","dead","return"]:
  seed_monsters()
  c=sm.data[Run.KEY].combat
  if scenario=="outside":
   c.actors[FISH_ID].position=[1166.0,450.0]
   c.actors[FISH_ID].fish_origin=c.actors[FISH_ID].position.duplicate()
   c.actors["fenshui_thunder_eel_2"].position=[1166.0,460.0]
   c.actors["fenshui_thunder_eel_2"].eel_origin=c.actors["fenshui_thunder_eel_2"].position.duplicate()
  elif scenario=="captured":
   sm.data[Run.KEY].monsters[FISH_ID].status="captured"
   sm.data[Run.KEY].monsters["fenshui_thunder_eel_2"].status="captured"
  elif scenario=="dead":
   c.actors[FISH_ID].hp=0.0
   c.actors["fenshui_thunder_eel_2"].hp=0.0
  else: c.actors[Boss.ID].mode="return"
  _check(Run.valid(state()),"范围排除检查点合法："+scenario)
  fish_hp=c.actors[FISH_ID].hp
  eel_hp=c.actors["fenshui_thunder_eel_2"].hp
  result=Run.combat_tick(sm,HURT_POINT,0.1)
  _check(result.success and state().combat.actors[FISH_ID].hp==fish_hp and state().combat.actors["fenshui_thunder_eel_2"].hp==eel_hp,"排除对象不额外受砸："+scenario)
 seed_monsters()
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 result=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(not result.success and sm.data==before,"玩家与鱼鳗范围伤害同事务失败完整回滚")
 sm._active_save_path=path
 _check(Run.combat_tick(sm,HURT_POINT,0.1).success and state().combat.actors[FISH_ID].hp<20.0,"恢复保存后鱼鳗范围攻击正常提交")
 seed_monsters()
 for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status="captured"
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"公开入口离开分水庭")
 for id in [Boss.ID,FISH_ID,"fenshui_thunder_eel_2"]: sm.data[Run.KEY].monsters[id].status="alive"
 fish_hp=state().combat.actors[FISH_ID].hp
 _check(Run.combat_tick(sm,Roads.SPAWN,0.1).success and state().combat.actors[FISH_ID].hp==fish_hp,"落地攻击不跨地图伤害鱼鳗")
