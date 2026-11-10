extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const HERO=Vector2(1090,450)

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"静水恢复跨进程使用隔离存档")
 if _arg("--phase=")=="seed": seed_checkpoints()
 else: restore_checkpoints()
 _finish()

func seed_checkpoints() -> void:
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HERO).success,"真实探索建立水中交战恢复检查点")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.hp=48.0
 a.position=[1040.0,450.0]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.frog_phase="active"
 a.mode="chase"
 a.frog_left=1.2
 a.cooldown=10.0
 _check(Run.valid(state()),"跨进程检查点为合法非中央水中交战")
 var expected: Dictionary={}
 for phase in ["quiet","healing"]:
  sm._active_save_path="user://heal-working.json"
  for i in (3 if phase=="quiet" else 2):
   _check(Run.combat_tick(sm,HERO,0.5).success,"真实推进水中交战恢复阶段："+phase)
  sm._active_save_path="user://heal-"+phase+".json"
  _check(sm.save() and Run.valid(state()),"保存静水恢复阶段："+phase)
  expected[phase]=JSON.parse_string(JSON.stringify(actor()))
 FileAccess.open("user://heal-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))

func restore_checkpoints() -> void:
 var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://heal-expected.json"))
 _check(expected is Dictionary and expected.size()==2,"读取前一进程的安静及回血两份证据")
 if failures: return
 for phase in ["quiet","healing"]:
  sm._active_save_path="user://heal-"+phase+".json"
  sm.load_data()
  _check(actor()==expected[phase] and Run.valid(state()),"新进程恢复完整阶段，不离线补时或补血："+phase)
  sm._active_save_path="user://heal-resumed.json"
  _check(Run.combat_tick(sm,HERO,0.1).success,"新进程仅推进当前0.1秒："+phase)
  _check(is_equal_approx(float(actor().hp),48.0 if phase=="quiet" else 57.6),"恢复后仅增加本次允许的真实生命："+phase)
  _check(is_equal_approx(float(actor().frog_heal_quiet),1.6 if phase=="quiet" else 2.0),"恢复后安静时间续接而不重置："+phase)
