extends Node
const Monster=preload("res://scripts/maze/capture_monster.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
const Flow=preload("res://scripts/maze/capture_flow.gd")
const Rock=preload("res://scripts/maze/rockmane_combat.gd")
var checks: Array=[]
func _ready() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void: checks.append({"name":name,"passed":ok})
func run() -> void:
 var world:=Node2D.new()
 get_tree().root.add_child(world)
 var player:=Node2D.new()
 player.name="Player"
 world.add_child(player)
 var player_body:=Sprite2D.new()
 player_body.name="Body"
 var solid:=Image.create(32,64,false,Image.FORMAT_RGBA8)
 solid.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(solid)
 player_body.texture=texture
 player_body.position=Vector2(0,-40)
 player.add_child(player_body)
 var info:=Label.new()
 info.size=Vector2(60,40)
 info.position=Vector2(-30,-113)
 player.add_child(info)
 var beast:=Monster.new()
 beast.config=Boss.row()
 world.add_child(beast)
 beast.set_process(false)
 var flow:=Flow.new()
 flow.power_label=info
 flow.monsters={Boss.ID:beast}
 var actor: Dictionary={"hp":120.0,"mode":"chase","position":[850.0,425.0],"velocity":[0.0,0.0],"windup":0.0,"rock_phase":"lunge","rock_left":0.1,"rock_aim":[1.0,1.0]}
 for dy in [12.0,-90.0,-65.0,-35.0,-12.0,12.0]:
  player.position=beast.position+Vector2(0,dy)
  var before: Dictionary=actor.duplicate(true)
  beast.sync_action(actor,{"hp":36.0})
  flow._layout_combat_labels()
  check((beast.get_index()<player.get_index())==(dy>0),"按脚底前后绘制："+str(dy))
  check(not beast.label.get_global_rect().grow(2).intersects(info.get_global_rect().grow(2)),"近身标签分离："+str(dy))
  check(not beast.label.get_global_rect().intersects(player_body.get_global_transform()*player_body.get_rect()),"兽血条不压玩家身体："+str(dy))
  check(actor==before,"层次与标签不写战斗状态")
  if dy==-12.0 or dy==12.0:
   check(beast.body.self_modulate.a<1.0 if dy<0 else is_equal_approx(beast.body.self_modulate.a,1.0),"后方紧贴可见、前方恢复不透明："+str(dy))
 var padding:=Image.create(200,200,false,Image.FORMAT_RGBA8)
 padding.fill(Color.TRANSPARENT)
 padding.fill_rect(Rect2i(92,0,16,16),Color.WHITE)
 player_body.texture=ImageTexture.create_from_image(padding)
 player.position=beast.position+Vector2(0,-12)
 beast.sync_action(actor,{"hp":36.0})
 check(is_equal_approx(beast.body.self_modulate.a,1.0),"仅透明留白相交时不得淡化")
 player_body.texture=texture
 var directions: Array=[Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]
 for row in 4:
  actor.rock_aim=[directions[row].x,directions[row].y]
  for phase in Rock.LUNGE_DURATIONS:
   actor.rock_phase=phase
   for frame in 4:
    actor.rock_left=float(Rock.LUNGE_DURATIONS[phase])*(1.0-(float(frame)+0.1)/4.0)
    var before: Dictionary=actor.duplicate(true)
    beast.sync_action(actor,{"hp":36.0})
    var expected: int=3 if phase=="stunned" else (3-frame if phase=="lunge_recover" else frame)
    check(beast.facing==row and beast.frame_index()==expected,"四向真实时序：%d/%s/%d"%[row,phase,frame])
    check(beast.body.scale.is_equal_approx(Vector2.ONE*0.875) and beast.body.offset.is_equal_approx(Vector2(-96,-158.016)),"1.4倍168格宽与脚底不变")
    check(actor==before,"动作不改状态")
 player.position=beast.position+Vector2(150,80)
 beast.sync_action(actor,{"hp":36.0})
 flow._layout_combat_labels()
 check(is_equal_approx(beast.body.self_modulate.a,1.0),"离开重叠恢复不透明")
 check(is_zero_approx(beast.combat_label_offset),"远离恢复原标签锚点")
 player.z_index=2
 beast.position=Vector2(400,170)
 player.position=beast.position+Vector2(0,-12)
 flow._layout_combat_labels()
 check(beast.label.get_global_rect().position.y>=28,"上沿保留完整血条与锁定标记空间")
 beast._draw_frame(beast.frame_index())
 check(beast.label.get_global_rect().position.y>=28,"动画刷新不撤销上沿避让")
 check(not beast.label.get_global_rect().intersects(info.get_global_rect()),"上沿回退仍避让玩家信息条")
 player.position=beast.position+Vector2(0,-12)
 var index:=beast.get_index()
 beast.sync_action(actor,{"hp":36.0})
 check(beast.get_index()==index and beast.z_index==0 and player.z_index==2,"不同绘制层不改既有层级")
 check(is_equal_approx(beast.body.self_modulate.a,1.0),"不同绘制层不额外淡化")
 player.z_index=0
 actor.hp=0.0
 beast.sync_action(actor,{"hp":36.0})
 check(beast.action=="defeated" and is_equal_approx(beast.body.self_modulate.a,1.0),"死亡清除冲撞姿态与遮挡淡化")
 var failures:=checks.filter(func(c): return not c.passed).size()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
   file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("READABILITY ",checks.size()," checks; failures=",failures)
 flow.free()
 world.queue_free()
 get_tree().quit(1 if failures else 0)
