extends Node2D
var checks: Array=[]
func check(ok: bool, label: String) -> void:
 checks.append({"ok":ok,"name":label})
func _ready() -> void:
 var beast:=Node2D.new()
 add_child(beast)
 beast.add_child(Node2D.new())
 var visual=preload("res://scripts/maze/rockmane_roar_visual.gd").new()
 visual.monster=beast
 beast.add_child(visual)
 var actor:={"position":[800.0,425.0],"rock_phase":"rush","rock_left":0.3,"rock_aim":[1.0,0.0],"hp":120.0,"mode":"chase","rock_combo":false,"rock_chain_left":0}
 var combat:={"hp":36.0,"elapsed":1.0}
 visual.apply(actor,combat)
 var s: Dictionary=visual.snapshot()
 check(str(s.get("wave_source","")).ends_with("rockmane_roar_source.png"),"实际使用主会话原气流纹理")
 check(s.get("wave_visible",false),"仅真实释放阶段显示原图")
 for aim in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  actor.rock_aim=[aim.x,aim.y]
  actor.rock_phase="lunge"
  actor.position=[800.0,425.0]
  actor.rock_left=0.8
  visual.apply(actor,combat)
  for i in 40:
   var p: Vector2=Vector2(800,425)+aim*float(i+1)*4.0
   actor.position=[p.x,p.y]
   combat.elapsed+=0.02
   visual.apply(actor,combat)
  s=visual.snapshot()
  check(absf(float(s.get("trail_span",0))-90.0)<0.1,"真实路径保留90单位："+str(aim))
  check(not s.get("wave_visible",false),"冲撞时不残留咆哮纹理："+str(aim))
  var frozen: Dictionary=visual.snapshot()
  visual.apply(actor,combat)
  check(visual.snapshot().get("trail_points",[])==frozen.get("trail_points",[]),"相同战斗状态不漂移烟尘："+str(aim))
  actor.rock_phase="lunge_recover"
  visual.apply(actor,combat)
  check(float(visual.snapshot().get("trail_span",0))==0.0,"停止立即清除烟尘："+str(aim))
 actor.rock_phase="rush"
 actor.position=[494.0,260.0]
 var blocked_aim:=Vector2.RIGHT.rotated(3.0*PI/8.0)
 actor.rock_aim=[blocked_aim.x,blocked_aim.y]
 visual.apply(actor,combat)
 s=visual.snapshot()
 var area=preload("res://scripts/maze/rockmane_roar_area.gd")
 var reach: float=area.reach(Vector2(494,260),blocked_aim,area.RADIUS)
 check(reach<area.RADIUS,"真实水晶截断声波中心射线")
 check(visual.wave.polygon==s.shape,"原图多边形逐点使用真实判伤裁切")
 check(not area.contains(s.shape,blocked_aim*(reach+5.0)),"障碍后方不出现声波多边形")
 actor.rock_phase="charge"
 visual.apply(actor,combat)
 check(not visual.snapshot().get("wave_visible",false),"前摇保留原预警，不提前画释放图")
 visual.clear()
 check(float(visual.snapshot().get("trail_span",0))==0.0 and not visual.snapshot().get("wave_visible",false),"清理不残留纹理或烟尘")
 var failed:=0
 for c in checks:
  if not c.ok: failed+=1
 var report:={"passed":failed==0,"failed":failed,"checks":checks}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
   file.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 get_tree().quit(1 if failed>0 else 0)
