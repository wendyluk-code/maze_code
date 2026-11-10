extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const EEL="fenshui_thunder_eel_1"
var recovery_hp:=0.0
var recovery_increased:=false
var recovery_changes: Array=[]

func eel() -> Dictionary:
 return state().combat.actors[EEL]

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"电鳗力竭真实七怪入口完成")
 var monster: Node=maze.capture_flow.monsters[EEL]
 _check(monster.get("exhaustion_visual")!=null,"正式电鳗安装已认可力竭表现，而非独立网页覆盖")
 if failures: return
 # 仅设合法测试起始站位，保留七怪和自然计数；不写次数、阶段、冷却或生命。
 maze.player.position=Vector2(500,550)
 maze.camera.snap_to_target()
 var history: Array=[]
 var previous:=""
 var end:=Time.get_ticks_msec()+16000
 while Time.get_ticks_msec()<end and eel().get("eel_phase","")!="exhausted":
  var phase: String=eel().get("eel_phase","")
  if phase!=previous:
   history.append({"phase":phase,"count":eel().get("eel_discharges",0),"time":state().combat.elapsed})
   previous=phase
  await get_tree().process_frame
 _check(eel().get("eel_phase","")=="exhausted" and eel().get("eel_discharges",0)==3,"正常七怪战斗中自然完成三次后力竭",{"history":history,"eel":eel(),"hero":state().combat.hero})
 if failures: return
 var hp: float=eel().hp
 var serial: int=state().combat.electric_serial
 await picture("natural-break")
 _check(not monster.membrane.visible and not Eel.shielded(state().combat,EEL),"实际画面破泡与伤害保护一致取消")
 # 活体会被capture_flow下一帧正常重显；此项单独受控检查隐藏事件清理。
 maze.capture_flow.set_process(false)
 monster.hide()
 await get_tree().process_frame
 _check(not monster.exhaustion_visual.visible and not monster.exhaustion_visual.is_visible_in_tree(),"受控隐藏事件立即清理活动力竭图层")
 monster.show()
 maze.capture_flow.set_process(true)
 await get_tree().create_timer(0.25).timeout
 var cell_width: float=monster.body.region_rect.size.x
 _check(monster.body.scale.y<float(monster.config.width)/cell_width*0.85,"力竭低伏按认可原姿态轻微形变，不影响逻辑体积")
 await picture("natural-exhausted")
 await key(KEY_SPACE)
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==EEL: break
 _check(maze.capture_flow.locked_target_id==EEL,"实际Tab锁定力竭电鳗")
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and not Run.Combat.PlayerHurt.recovering(state().combat),1.0),"沿原玩家冷却和受击恢复等待可出手")
 var hits: int=state().combat.hits
 var target_hp: float=eel().hp
 await click()
 _check(await until_true(func(): return eel().hp<target_hp,1.0),"4秒输出窗口内真实锅铲命中电鳗")
 _check(state().combat.hits==hits+1 and eel().hp==target_hp-3.0,"真实玩家3点攻击在力竭期间完整扣3点，不按水膜减伤")
 hp=eel().hp
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实原地图暂停电鳗战斗")
 var before: Dictionary=eel().duplicate(true)
 var scale_before: Vector2=monster.body.scale
 await get_tree().create_timer(0.25).timeout
 _check(eel()==before and monster.body.scale==scale_before,"暂停冻结力竭剩时和低伏喘息")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"关闭地图恢复电鳗战斗")
 recovery_hp=hp
 recovery_increased=false
 recovery_changes=[]
 _check(await until_true(func():
  sample_recovery_health()
  return eel().eel_phase=="forming",5.0),"4秒结束后自然进入原成泡恢复")
 await picture("natural-recover")
 _check(not Eel.shielded(state().combat,EEL) and not monster.membrane.visible,"恢复先抬身，成泡完成前仍不减伤")
 _check(await until_true(func():
  sample_recovery_health()
  return eel().eel_phase!="forming",2.0),"沿原1秒成泡后恢复行动")
 # 七怪实战包含已确认的巨蛙砸伤鱼鳗，不能把新增真实伤害误判成电鳗回血。
 # 持续逐帧检查生命从不增加；无其他攻击的精确生命保持由state案独立验证。
 _check(eel().eel_discharges==0 and not recovery_increased and Eel.shielded(state().combat,EEL),"混战恢复清零、重新保护且全程没有回血",{"before_hp":hp,"actual_hp":eel().hp,"changes":recovery_changes,"phase":eel().eel_phase,"count":eel().eel_discharges,"shielded":Eel.shielded(state().combat,EEL)})
 _check(state().combat.electric_serial==serial,"力竭和恢复期间不补发放电")
 await picture("natural-restored")
 _check(Run.valid(state()) and maze.capture_flow.monsters.size()==7,"完整七怪场景仍有效，不为演示清怪")
 var denied:=Run.change_region(sm,"maze_entry",Roads.SPAWN)
 _check(not denied.success and denied.get("reason","")=="in_combat","仍在交战时沿原规则禁止传送，不为验收放宽")
 maze.capture_flow.set_process(false)
 sm.data=entry_snapshot.duplicate(true)
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"恢复原非交战检查点后合法离图")
 monster.sync_action(state().combat.actors[EEL],state().combat)
 await get_tree().process_frame
 await get_tree().process_frame
 _check(not monster.exhaustion_visual.visible,"离图清理专用力竭表现")
 trace.append({"natural_eel_phases":history,"scope":"合法起始站位后的正常连续七怪战斗，未写入次数或力竭阶段"})
 var old: WeakRef=weakref(monster.exhaustion_visual)
 maze.queue_free()
 await get_tree().process_frame
 _check(old.get_ref()==null,"正式场景销毁不残留力竭节点")

func sample_recovery_health() -> void:
 var hp:=float(eel().hp)
 if hp>recovery_hp: recovery_increased=true
 if not is_equal_approx(hp,recovery_hp):
  var frog: Dictionary=state().combat.actors[Run.Catalog.Frog.ID]
  recovery_changes.append({"before":recovery_hp,"after":hp,"eel_phase":eel().eel_phase,"frog_phase":frog.frog_phase,"frog_position":frog.position.duplicate(),"player_hits":state().combat.hits,"time":state().combat.elapsed})
 recovery_hp=hp
