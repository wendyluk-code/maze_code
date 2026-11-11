extends "res://tools/tests/fenshui_frog_counter.gd"
const Frames=preload("res://scripts/maze/wind_frog_frames.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"四向时序验证隔离存档")
 for direction in 4:
  var run:=fresh_frog()
  var a: Dictionary=run.combat.actors[Boss.ID]
  var target:=Boss.HOME+Vector2(-45 if direction in [1,3] else 45,-35 if direction in [2,3] else 35)
  _check(Boss.water(target),"四侧玩家前置位于真实水域")
  for i in 100:
   Frog.advance(run,target,0.02)
   if a.frog_phase=="airborne": break
  _check(a.get("frog_facing",-1)==direction,"正常锁向保存实际四侧朝向："+str(direction))
  Combat.Skills.damage(run,Boss.ID,1)
  var locked: Variant=a.get("frog_facing")
  a.hit_velocity=[-100.0,100.0]
  Frog.advance(run,target,0.1)
  _check(a.get("frog_facing")==locked and a.frog_phase=="toppling","受击后翻落保向，不跟击退向量转身")
 var run:=fresh_frog()
 var a: Dictionary=run.combat.actors[Boss.ID]
 var fired:=false
 var point:=HERO
 for i in 400:
  if a.mode=="windup": point=HERO+Vector2(40,20)
  Frog.advance(run,point,0.02)
  if not a.frog_shots.is_empty():
   fired=true
   break
 _check(fired,"未被反击的正常起跳落地后实际吐出水团")
 _check(is_equal_approx(float(a.get("frog_spit_left",0.0)),0.28),"真实发射当刻开始0.28秒释放收势显示")
 if fired:
  var old: Vector2=Frog.vec(a.frog_shots[0].position)
  Frog.advance(run,point,0.02,0.02)
  _check(is_equal_approx(float(a.get("frog_spit_left",0.0)),0.28) and not a.frog_shots.is_empty() and Frog.vec(a.frog_shots[0].position).distance_to(old)>0,"局部停顿冻结身体显示，不冻结离体水团")
  Frog.advance(run,point,0.14)
  _check(is_equal_approx(float(a.get("frog_spit_left",0.0)),0.14),"收势显示消耗身体时间，不新增攻击硬直")
 for sample in [[1.2,15],[1.05,16],[0.91,17],[0.7,0]]:
  _check(Frames.pose({"frog_phase":"landing","frog_left":sample[0]})==sample[1],"普通落地采用撑地恢复而非失衡露腹："+str(sample[0]))
 for field in ["frog_facing","frog_spit_left"]:
  for bad in ["1",-1,4,NAN]:
   var broken:=a.duplicate(true)
   broken[field]=bad
   _check(not Frog.valid(broken),"损坏显示字段拒绝："+field+"/"+str(bad))
 var old:=a.duplicate(true)
 old.erase("frog_facing")
 old.erase("frog_spit_left")
 _check(Frog.valid(old),"旧档缺可选显示字段仍可恢复，不补发攻击")
 _finish()
