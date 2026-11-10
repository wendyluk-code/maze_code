extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
const HERO=Vector2(880,490)
const PHASES=["airborne","toppling","exposed","recovering"]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"巨蛙恢复使用隔离存档")
 if _arg("--phase=")=="seed": seed_phases()
 else: restore_phases()
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)

func state() -> Dictionary:
 return Run.snapshot(sm)

func actor() -> Dictionary:
 return state().combat.actors[Boss.ID]

func progress_to(phase: String, steps: int=300) -> bool:
 for i in steps:
  if actor().frog_phase==phase: return true
  if not Run.combat_tick(sm,HERO,0.02).success: return false
 return false

func seed_phases() -> void:
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HERO).success,"真实探索进入正式分水庭")
 _check(progress_to("airborne"),"不写阶段，自然进入腾空")
 var expected: Dictionary={}
 for phase in PHASES:
  sm._active_save_path="user://frog-working.json"
  if phase=="toppling":
   for i in 20:
    if actor().frog_phase=="airborne" and float(actor().frog_left)<=0.50: break
    _check(Run.combat_tick(sm,HERO,0.02).success,"真实推进至最高点附近再出手")
   var aim:=HERO.direction_to(Run.Combat.vec(actor().position))
   _check(Run.combat_attack(sm,HERO,aim).success and progress_to(phase,35),"真实攻击命中后保存翻落")
  elif phase!="airborne":
   _check(progress_to(phase),"自然计时进入保存阶段："+phase)
  if failures: return
  _check(Run.combat_tick(sm,HERO,0.06).success,"阶段已实际消耗部分剩时："+phase)
  sm._active_save_path="user://frog-"+phase+".json"
  _check(sm.save() and Run.valid(state()),"保存合法完整反击状态："+phase)
  expected[phase]=JSON.parse_string(JSON.stringify(state()))
  var before: Dictionary=sm.data.duplicate(true)
  sm._active_save_path=""
  var failed: Dictionary=Run.combat_tick(sm,HERO,0.5)
  _check(not failed.success and sm.data==before,"保存失败整体回滚生命位置阶段剩时："+phase)
  sm._active_save_path="user://frog-working.json"
 FileAccess.open("user://frog-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))

func restore_phases() -> void:
 var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://frog-expected.json"))
 _check(expected is Dictionary and expected.size()==4,"读取前一进程的四份阶段证据")
 if failures: return
 for phase in PHASES:
  sm._active_save_path="user://frog-"+phase+".json"
  sm.load_data()
  var before: Dictionary=state()
  _check(before==expected[phase] and Run.valid(before),"新进程完整恢复，无离线推进："+phase)
  if not Run.valid(before): continue
  sm._active_save_path="user://frog-restored-working.json"
  _check(Run.combat_tick(sm,HERO,0.02).success,"新进程正常继续战斗："+phase)
  var after: Dictionary=state()
  _check(after.combat.actors[Boss.ID].frog_left<before.combat.actors[Boss.ID].frog_left,"仅推进当前0.02秒，不重置阶段："+phase)
  _check(after.bag==before.bag and after.satiety==before.satiety and after.combat.actors[Boss.ID].hp==before.combat.actors[Boss.ID].hp,"恢复不重伤、不扣捕获费、不发奖励："+phase)
