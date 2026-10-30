extends "res://tools/previews/fenshui_borrow_lightning.gd"
## 启动器先复制用户卡住档到隔离目录，真实load_data后检查恢复与再次重启。
var runtime_environment: Dictionary = {}
var restored_state: Dictionary = {}
var saved_state: Dictionary = {}

func _scene_check(_effects: Node) -> void:
 runtime_environment={"display_backend":DisplayServer.get_name(),"startup_no_focus":ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"unfocusable":get_window().unfocusable,"has_focus":get_window().has_focus(),"native_focus_verified":false}
 print("旧档环境观测：",JSON.stringify(runtime_environment))
 if runtime_environment.display_backend=="headless":
  _check(_verify_isolation(),"无头恢复使用隔离环境")
  _check(runtime_environment.startup_no_focus==true,"无头测试保留启动前不可聚焦配置")
 else:
  _check(get_window().unfocusable,"原生旧档测试窗口不可聚焦")
  _check(not get_window().has_focus(),"原生旧档测试窗口没有桌面焦点")
  runtime_environment.native_focus_verified=get_window().unfocusable and not get_window().has_focus()
 var before: Dictionary=Run.snapshot(sm)
 restored_state=_checkpoint(before)
 var id: String=Rules.IDS[1]
 var fish_hp: float=before.combat.actors[id].hp
 var bag: Dictionary=before.bag.duplicate(true)
 var satiety: float=before.satiety
 _check(Run.valid(before),"真实load_data后的旧停顿档已合法")
 _check(before.combat.actors[id].has("fs_aim") and before.combat.actors[id].has("fs_origin") and before.combat.actors[id].has("fs_hit"),"旧停顿阶段补齐字段")
 var elapsed: float=before.combat.elapsed
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 # 只驱动Godot内部方向动作，保持原档位置和数值。
 Input.action_press("ui_left")
 await get_tree().create_timer(0.2).timeout
 Input.action_release("ui_left")
 await get_tree().create_timer(0.9).timeout
 maze.capture_flow.set_process(false)
 var after: Dictionary=Run.snapshot(sm)
 _check(Run.valid(after) and after.combat.elapsed>elapsed+0.5,"真实重启后战斗继续推进")
 _check(after.combat.actors[id].hp==fish_hp,"恢复已放电状态不重复电伤鱼")
 _check(after.bag==bag and after.satiety==satiety,"重启不发奖励不重复扣费")
 _check(sm.save(),"兼容字段随原事务保存，允许再次重启")
 saved_state=_checkpoint(Run.snapshot(sm))
 _report_and_quit()

func _checkpoint(run: Dictionary) -> Dictionary:
 var hp: Dictionary={}
 var phases: Dictionary={}
 for id in Rules.IDS:
  var actor: Dictionary=run.combat.actors[id]
  hp[id]=actor.hp
  phases[id]={"phase":actor.get("fs_phase","idle"),"remaining":actor.get("fs_left",0.0)}
 return {"hero_hp":run.combat.hp,"monster_hp":hp,"bag":run.bag.duplicate(true),"satiety":run.satiety,"elapsed":run.combat.elapsed,"phases":phases}

func _report_and_quit() -> void:
 var report:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"environment":runtime_environment,"native_focus_verified":runtime_environment.get("native_focus_verified",false),"restored_state":restored_state,"saved_state":saved_state},"\t"))
 print("旧档恢复：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)
