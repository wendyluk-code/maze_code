extends "res://tools/tests/fenshui_player_hurt_flow.gd"

const MAPS={"maze_entry":"maze_entry","fenshui":"maze_fenshui","salt_pool":"maze_salt_pool","moss_pool":"maze_moss_pool","waterkeeper_cottage":"maze_waterkeeper_cottage"}
# 第二只蟹远离盐晶，避免挥斧采矿弹窗正常暂停后续受击用例。
const TARGETS={"maze_entry":"snail_1","fenshui":"fenshui_silverfish_1","salt_pool":"salt_pool_mimic_crab_2"}
var map_baseline: Dictionary
var hit_point:=Vector2.ZERO

func battle() -> void:
 for region in MAPS:
  if _arg("--phase=")=="salt" and region!="salt_pool": continue
  await open_map(region)
  if failures: return
  _check(maze.player.combat_controller==maze.capture_flow.player_combat,"正常入口由角色持有唯一共用模块："+region)
  _check(maze.capture_flow.locked_target_id.is_empty(),"换图不带入旧锁定："+region)
  if not TARGETS.has(region):
   _check(await until_true(func(): return state().combat.cooldown<=0.000001,1.3),"无怪地图沿原规则等待入场冷却："+region)
   await key(KEY_TAB)
   _check(maze.capture_flow.locked_target_id.is_empty(),"无怪地图Tab不创造目标："+region)
   var count: int=state().combat.throws
   await key(KEY_SPACE)
   await click()
   _check(state().combat.throws==count+1,"无怪地图可正常空挥："+region)
   _check(await until_true(func(): return state().combat.action_left<=0.0 and state().combat.shots.is_empty(),1.5),"空挥按原时间结束并清理弹体："+region)
   continue
  var id: String=TARGETS[region]
  for slot in [0,1,2]:
   await attack_case(region,id,slot)
   if failures: return
  if region!="fenshui":
   for facing in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
    await hurt_case(region,id,facing)
    if failures: return
  else:
   for facing in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
    await begin_hurt("water",facing)
    var visual: Node=maze.capture_flow.player_hurt_visual
    _check(visual.refined_pose and visual.pose.visible and not maze.player.body.visible,"分水庭正常入口持续四向痛态："+str(facing))
    _check(await until_true(func(): return not visual.active(),1.1),"分水庭四向硬直恢复："+str(facing))
  if failures: return
  await picture(region+"_normal")
 await open_map("salt_pool")
 for slot in [0,1,2]:
  await attack_case("salt_pool",Run.Catalog.Rock.ID,slot)
  if failures: return
 await hurt_case("salt_pool",Run.Catalog.Rock.ID,Vector2.UP)
 if failures: return
 await picture("salt_pool_rockmane_actual_hurt")

func open_map(region: String) -> void:
 if is_instance_valid(maze):
  maze.queue_free()
  await get_tree().process_frame
 sm.data=entry_snapshot.duplicate(true)
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 var spawn: Vector2=sm.maze_terrain(region).SPAWN
 _check(Run.change_region(sm,region,spawn).success,"原探索事务切图："+region)
 maze=load("res://scenes/"+MAPS[region]+".tscn").instantiate()
 viewport.add_child(maze)
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"正常地图可交互："+region)
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(false)
 map_baseline=sm.data.duplicate(true)
 maze.capture_flow.set_process(true)

func arrange(region: String,id: String,distance: float=45.0) -> void:
 maze.capture_flow.set_process(false)
 sm.data=map_baseline.duplicate(true)
 var c: Dictionary=sm.data[Run.KEY].combat
 for key in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[key].status="alive" if key==id else "skipped"
 var at: Vector2=Run.Combat.vec(c.actors[id].position)
 var terrain=sm.maze_terrain(region)
 hit_point=Vector2.INF
 for angle in 16:
  var point:=at+Vector2.RIGHT.rotated(TAU*angle/16.0)*distance
  if terrain.is_walkable(point) and Run.Combat.Skills.clear_line(point,at,region):
   hit_point=point
   break
 _check(hit_point.is_finite(),"从原道路找合法实战站位："+region)
 if not hit_point.is_finite(): return
 c.hero=Run.Combat.pack(hit_point)
 c.cooldown=0.0
 c.action=""
 c.action_left=0.0
 c.axe_pending=false
 c.shots=[]
 c.hurt_recovery_left=0.0
 c.actors[id].cooldown=1.0
 if region=="fenshui":
  var a: Dictionary=c.actors[id]
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  Run.Combat.Silverfish.phase(a,"recover",2.5)
 maze.player.position=hit_point
 maze.camera.snap_to_target()
 maze.capture_flow.combat_time=0.0
 maze.capture_flow.locked_target_id=""
 maze.capture_flow.player_hurt_visual.clear()
 maze.capture_flow.axe_hitstop.configure(70)
 maze.capture_flow.axe_hitstop.configure_ranged(50)
 for monster in maze.capture_flow.monsters.values():
  if monster.hit_visual!=null: monster.hit_visual.clear()
 _check(Run.valid(state()),"实战检查点满足原状态校验："+region)

func attack_case(region: String,id: String,slot: int) -> void:
 arrange(region,id)
 if failures: return
 await key(KEY_SPACE if slot==0 else (KEY_1 if slot==1 else KEY_2))
 var selected: int=state().combat.selected
 await key(KEY_TAB)
 _check(maze.capture_flow.locked_target_id==id and state().combat.selected==selected,"Tab锁怪而非切换招式："+region+str(slot))
 _check(maze.capture_flow.target_marker.visible,"锁定沿用已认可倒三角："+region)
 await key(KEY_Q)
 _check(maze.capture_flow.locked_target_id.is_empty() and not maze.capture_flow.target_marker.visible,"Q立即清理锁定和标记："+region)
 await key(KEY_TAB)
 var visual: Node=maze.capture_flow.monsters[id].hit_visual
 var received: int=visual.received
 var hp: float=state().combat.actors[id].hp
 maze.capture_flow.set_process(true)
 await click()
 _check(await until_true(func(): return visual.received>received,1.2),"真实左键与原弹道产生实际命中图："+region+str(slot))
 _check(state().combat.actors[id].hp<hp,"实际伤害不由显示伪造："+region)
 _check(maze.capture_flow.axe_hitstop.paused(id),"实际命中触发目标局部停顿："+region+str(slot))
 maze.capture_flow.set_process(false)
 await picture(region+"_hit_"+str(slot))

func hurt_case(region: String,id: String,facing: Vector2) -> void:
 arrange(region,id,24.0)
 if failures: return
 var c: Dictionary=sm.data[Run.KEY].combat
 c.actors[id].mode="windup"
 c.actors[id].windup=0.01
 if region=="salt_pool": c.actors[id].attack_aim=Run.Combat.pack(Run.Combat.vec(c.actors[id].position).direction_to(hit_point))
 if id==Run.Catalog.Rock.ID:
  c.actors[id].mode="chase"
  c.actors[id].rock_phase="charge"
  c.actors[id].rock_left=0.01
  c.actors[id].rock_aim=c.actors[id].attack_aim.duplicate()
 maze.player.facing=facing
 var hp: float=c.hp
 var visual: Node=maze.capture_flow.player_hurt_visual
 var received: int=visual.received
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return visual.received>received,0.8),"普通怪真实近战触发玩家受击："+region,{"before":c,"after":state().combat,"hero":str(maze.player.position),"protected":Run.Combat.protected(Run.Catalog.find(id),hit_point),"paused":maze.capture_flow.combat_paused(),"focus":maze.capture_flow.window_focused,"flow_busy":maze.capture_flow.busy,"maze_busy":maze._busy,"input_locked":maze.player.input_locked,"physics":maze.player.is_physics_processing(),"confirmation":maze.confirmation.visible,"map":maze.map_ui.expanded,"retry":maze.capture_flow.save_retry_delay})
 _check(state().combat.hp<hp and visual.kind=="physical","普通物理伤害不冒充鱼/电/水："+region)
 Input.action_press("ui_right")
 _check(await until_true(func(): return visual.age>=0.25,0.7),"受击真实时钟推进到持痛："+region)
 var position_before: Vector2=maze.player.position
 var throws: int=state().combat.throws
 await click()
 await get_tree().create_timer(0.08).timeout
 _check(maze.player.position.distance_to(position_before)<0.1 and state().combat.throws==throws,"持续持键和左键在硬直内不能走攻："+region+str(facing))
 _check(visual.pose.visible and not maze.player.body.visible and not visual.effect.visible,"四向身体持续痛态，无不匹配接触图："+region+str(facing))
 Input.action_release("ui_right")
 if facing==Vector2.UP: await picture(region+"_hurt_back")
 _check(await until_true(func(): return not visual.active(),0.7),"600毫秒后正常恢复："+region)
 _check(maze.player.body.visible,"恢复后没有人物隐藏残留："+region)
